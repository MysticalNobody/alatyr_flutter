import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'graph.dart';

/// Package names imported/exported by [dartSource], directive-aware:
/// skips comments and string literals, follows conditional URIs.
List<String> collectPackageImports(String dartSource) => [
  for (final d in _directives(dartSource)) ..._packagesOf(d.uris),
];

final class _Directive {
  _Directive(this.line, this.col, this.uris);
  final int line;
  final int col;
  final List<String> uris;
}

Iterable<String> _packagesOf(List<String> uris) sync* {
  for (final uri in uris) {
    if (uri.startsWith('package:')) {
      yield uri.substring('package:'.length).split('/').first;
    }
  }
}

List<_Directive> _directives(String src) {
  final out = <_Directive>[];
  var i = 0, line = 1, col = 1;
  void advance([int n = 1]) {
    for (var k = 0; k < n && i < src.length; k++) {
      if (src[i] == '\n') {
        line++;
        col = 1;
      } else {
        col++;
      }
      i++;
    }
  }

  bool at(String s) => src.startsWith(s, i);

  void skipLineComment() {
    while (i < src.length && src[i] != '\n') {
      advance();
    }
  }

  void skipBlockComment() {
    advance(2);
    var depth = 1;
    while (i < src.length && depth > 0) {
      if (at('/*')) {
        depth++;
        advance(2);
      } else if (at('*/')) {
        depth--;
        advance(2);
      } else {
        advance();
      }
    }
  }

  /// Consumes a string literal, returns its contents (null for interpolated
  /// complexity we don't need - directive URIs are always simple).
  String? readString() {
    final raw = at('r');
    if (raw) advance();
    for (final quote in ["'''", '"""', "'", '"']) {
      if (at(quote)) {
        advance(quote.length);
        final start = i;
        while (i < src.length && !at(quote)) {
          if (!raw && src[i] == r'\') advance();
          advance();
        }
        final value = src.substring(start, i);
        advance(quote.length);
        return value;
      }
    }
    return null;
  }

  bool atKeyword(String kw) {
    if (!at(kw)) return false;
    final after = i + kw.length;
    final before = i - 1;
    final wordChar = RegExp(r'[A-Za-z0-9_$]');
    if (before >= 0 && wordChar.hasMatch(src[before])) return false;
    if (after < src.length && wordChar.hasMatch(src[after])) return false;
    return true;
  }

  bool startsStringLiteral() => at("'") || at('"') || at("r'") || at('r"');

  const whitespace = ' \t\r\n';

  /// Skips insignificant tokens (whitespace and comments) so callers can
  /// probe what "really" comes next in the source.
  void skipWhitespaceAndComments() {
    while (i < src.length) {
      if (whitespace.contains(src[i])) {
        advance();
      } else if (at('//')) {
        skipLineComment();
      } else if (at('/*')) {
        skipBlockComment();
      } else {
        break;
      }
    }
  }

  while (i < src.length) {
    if (at('//')) {
      skipLineComment();
      continue;
    }
    if (at('/*')) {
      skipBlockComment();
      continue;
    }
    if (at("'") || at('"') || at("r'") || at('r"')) {
      readString();
      continue;
    }
    if (atKeyword('import') || atKeyword('export')) {
      final dLine = line, dCol = col;
      advance(6); // both keywords are 6 chars
      skipWhitespaceAndComments();
      // `import`/`export` are built-in identifiers, not reserved words, so
      // they're legal as enum members, method names, or method-call
      // targets (`enum X { import, export }`, `Future<void> export() {}`,
      // `service.import(path)`). A real directive is always immediately
      // followed (module whitespace/comments) by its URI string literal;
      // anything else means this was never a directive - abandon it
      // without swallowing more source, and resume normal scanning right
      // where we are (past the keyword, past any whitespace/comments).
      if (!startsStringLiteral()) {
        continue;
      }
      final uris = <String>[];
      while (i < src.length && src[i] != ';') {
        if (at("'") || at('"') || at("r'") || at('r"')) {
          final uri = readString();
          if (uri != null) uris.add(uri);
        } else {
          advance();
        }
      }
      out.add(_Directive(dLine, dCol, uris));
      continue;
    }
    advance();
  }
  return out;
}

List<String> validateImports({
  required String rootDir,
  String graphPath = 'docs/reference/package_graph.yaml',
}) {
  final violations = <String>[];
  final graph = loadPackageGraph(
    File(p.join(rootDir, graphPath)).readAsStringSync(),
    sourcePath: graphPath,
  );
  final rootPubspec =
      loadYaml(File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  final members = <String, String>{}; // name -> dir
  for (final m in rootPubspec['workspace'] as YamlList? ?? YamlList()) {
    final dir = m.toString();
    final pubspec =
        loadYaml(File(p.join(rootDir, dir, 'pubspec.yaml')).readAsStringSync())
            as YamlMap;
    members[pubspec['name'].toString()] = dir;
  }
  final secretIdent = RegExp(
    r'(token|secret|password|credential)',
    caseSensitive: false,
  );
  final declaration = RegExp(
    r'^\s*(?:final|const|var|late|String|int|double|bool|Object)\??\s+'
    r'([A-Za-z_$][A-Za-z0-9_$]*)',
  );

  for (final entry in members.entries) {
    final name = entry.key;
    final node = graph.packages[name];
    if (node == null) {
      // Defense in depth: verify_dependencies.dart is the primary check for
      // graph/workspace drift, but verify_imports.dart must not go silent
      // on its own just because a member is missing from the graph - the
      // banned-package scan below still runs for it, and this makes the
      // gap loud rather than silently skipping every import rule.
      violations.add(
        '${entry.value}/pubspec.yaml:1:1: workspace member '
        '"$name" is missing from the package graph',
      );
    }
    final isPure = node != null && graph.pureDartPackages.contains(name);
    for (final scope in ['lib', 'test']) {
      final dir = Directory(p.join(rootDir, entry.value, scope));
      if (!dir.existsSync()) continue;
      final inLib = scope == 'lib';
      for (final file
          in dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart'))) {
        final relPath = p
            .relative(file.path, from: rootDir)
            .replaceAll(r'\', '/');
        final src = file.readAsStringSync();
        for (final d in _directives(src)) {
          for (final pkg in _packagesOf(d.uris)) {
            final banReason = graph.bannedPackages[pkg];
            if (banReason != null) {
              violations.add(
                '$relPath:${d.line}:${d.col}: import of banned package '
                '"$pkg" - $banReason',
              );
            }
            if (node == null) {
              // Without a graph node we have no allowed_dependencies edges
              // and no purity classification to check against - the banned
              // scan above (which needs neither) is all that applies.
              continue;
            }
            if (inLib && isPure && pkg.startsWith('flutter')) {
              violations.add(
                '$relPath:${d.line}:${d.col}: pure Dart package '
                '"$name" imports "$pkg"',
              );
            }
            if (inLib && members.containsKey(pkg) && pkg != name) {
              final allowed =
                  node.allowsAllMembers ||
                  node.allowedDependencies.contains(pkg);
              if (!allowed) {
                violations.add(
                  '$relPath:${d.line}:${d.col}: import of member '
                  '"$pkg" is not an allowed edge for "$name"',
                );
              }
            }
          }
          if (node != null && inLib && isPure) {
            for (final uri in d.uris.where((u) => u.startsWith('dart:ui'))) {
              violations.add(
                '$relPath:${d.line}:${d.col}: pure Dart package '
                '"$name" imports "$uri"',
              );
            }
          }
        }
        if (inLib && name == 'data_local') {
          final lines = src.split('\n');
          for (var li = 0; li < lines.length; li++) {
            final m = declaration.firstMatch(lines[li]);
            if (m != null && secretIdent.hasMatch(m.group(1)!)) {
              violations.add(
                '$relPath:${li + 1}:1: secret-shaped identifier '
                '"${m.group(1)}" in data_local - runtime secrets belong in '
                'data_secure (spec invariant 4)',
              );
            }
          }
        }
      }
    }
  }
  return violations;
}
