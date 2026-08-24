import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'init_identity.dart';
import 'init_validate.dart';

final class InitPostconditionException implements Exception {
  InitPostconditionException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class InitReport {
  final rewritten = <String>[];
  final deleted = <String>[];
  final movedDirs = <String>[];
  final changedDartFiles = <String>[];

  /// Tracked paths init deliberately left alone: symlinks, whose target may
  /// live outside the checkout.
  final skipped = <String>[];
}

/// Paths init removes (see docs/workflow/instantiation.md): the init
/// machinery plus its template-only tests and documentation.
const templateOnlyPaths = [
  'tool/init.dart',
  'tool/src/init_identity.dart',
  'tool/src/init_validate.dart',
  'tool/src/init_rewrite.dart',
  'tool/template_smoke.sh',
  'test/init_identity_test.dart',
  'test/init_validate_test.dart',
  'test/init_rewrite_test.dart',
  'test/init_cli_test.dart',
  'test/fixtures/init',
  'test/template_identity_test.dart',
  'docs/workflow/instantiation.md',
];

/// Files whose prose must keep the placeholder: ADRs record decisions.
bool _neverRewrite(String rel) => rel.startsWith('docs/adr/');

/// Apple projects get the camelCase bundle id, everything else the snake one.
bool _isApple(String rel) =>
    rel.startsWith('app/ios/') || rel.startsWith('app/macos/');

InitReport runInit({
  required String rootDir,
  required TemplateIdentity from,
  required InitTarget to,
  required List<String> trackedFiles,
  String? templateUrl,
}) {
  final report = InitReport();

  // 1. Delete template-only paths first so they are never rewritten.
  for (final rel in templateOnlyPaths) {
    final path = p.join(rootDir, rel);
    if (Directory(path).existsSync()) {
      Directory(path).deleteSync(recursive: true);
      report.deleted.add(rel);
    } else if (File(path).existsSync()) {
      File(path).deleteSync();
      report.deleted.add(rel);
    }
  }
  final deletedPrefixes = templateOnlyPaths;
  bool wasDeleted(String rel) =>
      deletedPrefixes.any((d) => rel == d || rel.startsWith('$d/'));

  // 2. Whole-token replacement in file contents. Order matters: the bundle id
  //    (and its slashed path form) before the bare org, the org before the
  //    name. Boundaries: not preceded/followed by [A-Za-z0-9_]; the org may
  //    not be preceded by '.' either (a longer reverse-domain that merely
  //    ends with the org is left alone).
  for (final rel in trackedFiles) {
    if (wasDeleted(rel) || _neverRewrite(rel)) continue;
    final path = p.join(rootDir, rel);
    // A symlink's target may live outside the checkout: following it would
    // rewrite a file init was never asked to touch.
    if (FileSystemEntity.isLinkSync(path)) {
      report.skipped.add(rel);
      continue;
    }
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    if (bytes.take(1024).contains(0)) continue; // binary
    final before = utf8.decode(bytes, allowMalformed: true);
    final newId = _isApple(rel) ? to.bundleIdCamel : to.bundleIdSnake;
    // Marked blocks go first: prose about the template machinery is removed
    // whole, so the token pass below never rewrites it into a paragraph
    // that calls the NEW identity "the placeholder".
    var after = _stripTemplateOnlyBlocks(before, rel);
    after = _replaceToken(after, from.bundleId, newId, noDotBefore: true);
    after = _replaceToken(
      after,
      from.bundleId.replaceAll('.', '/'),
      to.bundleIdSnake.replaceAll('.', '/'),
    );
    after = _replaceToken(after, from.org, to.org, noDotBefore: true);
    after = _replaceToken(after, from.workspaceName, to.workspaceName);
    after = _replaceToken(after, from.packageName, to.name);
    after = _replaceToken(after, from.displayName, to.displayName);
    if (after != before) {
      file.writeAsStringSync(after);
      report.rewritten.add(rel);
      if (rel.endsWith('.dart')) {
        report.changedDartFiles.add(rel);
      }
    }
  }

  // 3. Descriptions are product text, not token soup.
  _rewriteDescriptions(rootDir, to, report);

  // 4. Package directories follow the Android package.
  final movedTargets = <String>[];
  for (final base in [
    'app/android/app/src/main/kotlin',
    'app/android/app/src/androidTest/java',
  ]) {
    final oldDir = p.join(rootDir, base, from.bundleId.replaceAll('.', '/'));
    final newDir = p.join(rootDir, base, to.bundleIdSnake.replaceAll('.', '/'));
    if (!Directory(oldDir).existsSync()) {
      continue;
    }
    Directory(newDir).createSync(recursive: true);
    movedTargets.add(newDir);
    for (final entity in Directory(oldDir).listSync()) {
      entity.renameSync(p.join(newDir, p.basename(entity.path)));
    }
    _pruneEmpty(Directory(oldDir), stopAt: p.join(rootDir, base));
    report.movedDirs.add(
      '$base/${from.bundleId.replaceAll('.', '/')} -> $base/${to.bundleIdSnake.replaceAll('.', '/')}',
    );
  }

  // 5. README stubs (the template README is about the template).
  File(
    p.join(rootDir, 'README.md'),
  ).writeAsStringSync(_rootReadme(to, templateUrl));
  File(p.join(rootDir, 'app', 'README.md')).writeAsStringSync(_appReadme(to));

  // 6. Postcondition: no placeholder token survives in any tracked file
  //    that still exists (binaries included - decoded tolerantly), except
  //    the ADRs that record the placeholder on purpose.
  final survivors = <String>[];
  void scan(String rel, File file) {
    final text = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    for (final token in [
      from.bundleId,
      from.org,
      from.packageName,
      from.displayName,
      from.workspaceName,
    ]) {
      if (text.contains(token)) {
        survivors.add('$rel: $token');
      }
    }
  }

  for (final rel in trackedFiles) {
    if (wasDeleted(rel) || _neverRewrite(rel)) continue;
    final path = p.join(rootDir, rel);
    if (FileSystemEntity.isLinkSync(path)) continue;
    final file = File(path);
    if (!file.existsSync()) continue;
    scan(rel, file);
  }
  // The moved Kotlin/androidTest targets are new, untracked paths: without
  // this pass a token surviving a move would never be scanned.
  for (final dir in movedTargets) {
    if (!Directory(dir).existsSync()) continue;
    for (final entity in Directory(
      dir,
    ).listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      scan(p.relative(entity.path, from: rootDir), entity);
    }
  }
  if (survivors.isNotEmpty) {
    throw InitPostconditionException(
      'placeholder identity survived init:\n${survivors.join('\n')}',
    );
  }
  return report;
}

/// Whole-line markers around prose that documents the template machinery
/// (the Instantiation walkthrough, the docs index entry for the page init
/// deletes). The block, markers included, is removed from every rewritten
/// file — deletion, not token replacement, is what such prose needs.
const _templateOnlyBegin = '<!-- template-only:begin -->';
const _templateOnlyEnd = '<!-- template-only:end -->';

/// Anything that even resembles a marker. A typo'd variant (say, the
/// comment syntax without spaces) matches neither the whole-line strip nor
/// an exact-string check — it would be neither stripped nor flagged, the
/// one silent failure mode this mechanism cannot afford.
final _templateOnlyMarkerish = RegExp('template-only:(begin|end)');

/// Removes `<!-- template-only:begin/end -->` blocks. Markers must be whole
/// lines and properly paired: a half-marked block would ship half-stripped
/// docs, so imbalance — or anything marker-like that survives the strip —
/// is an [InitPostconditionException], never a silent keep. When the
/// removal would leave two adjacent blank lines, one is dropped with it.
String _stripTemplateOnlyBlocks(String text, String rel) {
  if (!_templateOnlyMarkerish.hasMatch(text)) {
    return text;
  }
  final kept = <String>[];
  var inBlock = false;
  var justClosed = false;
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed == _templateOnlyBegin) {
      if (inBlock) {
        throw InitPostconditionException('nested $_templateOnlyBegin in $rel');
      }
      inBlock = true;
      justClosed = false;
      continue;
    }
    if (trimmed == _templateOnlyEnd) {
      if (!inBlock) {
        throw InitPostconditionException(
          '$_templateOnlyEnd without $_templateOnlyBegin in $rel',
        );
      }
      inBlock = false;
      justClosed = true;
      continue;
    }
    if (inBlock) {
      continue;
    }
    if (justClosed &&
        trimmed.isEmpty &&
        kept.isNotEmpty &&
        kept.last.trim().isEmpty) {
      justClosed = false;
      continue;
    }
    justClosed = false;
    kept.add(line);
  }
  if (inBlock) {
    throw InitPostconditionException('unclosed $_templateOnlyBegin in $rel');
  }
  final result = kept.join('\n');
  if (_templateOnlyMarkerish.hasMatch(result)) {
    throw InitPostconditionException(
      'inline or malformed template-only marker in $rel (markers must be '
      'exactly "$_templateOnlyBegin" / "$_templateOnlyEnd", each on its own '
      'line)',
    );
  }
  return result;
}

String _replaceToken(
  String text,
  String from,
  String to, {
  bool noDotBefore = false,
}) {
  final before = noDotBefore ? r'(?<![A-Za-z0-9_.])' : r'(?<![A-Za-z0-9_])';
  return text.replaceAll(
    RegExp('$before${RegExp.escape(from)}(?![A-Za-z0-9_])'),
    to,
  );
}

void _rewriteDescriptions(String rootDir, InitTarget to, InitReport report) {
  final description = '${to.displayName} Flutter app.';
  void edit(String rel, Pattern pattern, String replacement) {
    final file = File(p.join(rootDir, rel));
    if (!file.existsSync()) {
      return;
    }
    final before = file.readAsStringSync();
    final after = before.replaceFirst(pattern, replacement);
    if (after != before) {
      file.writeAsStringSync(after);
      if (!report.rewritten.contains(rel)) {
        report.rewritten.add(rel);
      }
    }
  }

  edit(
    'app/pubspec.yaml',
    RegExp(r'^description: .*$', multiLine: true),
    'description: $description',
  );
  edit(
    'pubspec.yaml',
    RegExp(r'^description: .*$', multiLine: true),
    'description: ${to.displayName} workspace root.',
  );
  // patrol's ios.bundle_id must equal the iOS PRODUCT_BUNDLE_IDENTIFIER
  // (camelCase); the generic pass wrote the snake id because app/pubspec.yaml
  // is not under app/ios/.
  // (Dart's replaceFirst has no group references; match only the value.)
  final snakeId = RegExp.escape(to.bundleIdSnake);
  edit(
    'app/pubspec.yaml',
    RegExp('(?<=^\\s+bundle_id:\\s)$snakeId(?=\\s*\$)', multiLine: true),
    to.bundleIdCamel,
  );
  edit(
    'app/web/index.html',
    RegExp(r'<meta name="description" content="[^"]*">'),
    '<meta name="description" content="$description">',
  );
  edit(
    'app/web/manifest.json',
    RegExp(r'"description": "[^"]*"'),
    '"description": "$description"',
  );
}

void _pruneEmpty(Directory dir, {required String stopAt}) {
  var current = dir;
  while (p.normalize(current.path) != p.normalize(stopAt) &&
      current.existsSync() &&
      current.listSync().isEmpty) {
    current.deleteSync();
    current = current.parent;
  }
}

/// The CLI's documented format step, separated so the fixture
/// tests can prove it is needed and sufficient.
ProcessResult formatChangedDart({
  required String rootDir,
  required List<String> files,
  required String dartExecutable,
}) => Process.runSync(dartExecutable, [
  'format',
  ...files,
], workingDirectory: rootDir);

/// The canonical template URL, the default `--template-url`. Lives here
/// (template-only code) and not in any shipped doc requirement: an
/// instantiated copy carries it only as the README backlink.
const alatyrTemplateUrl = 'https://github.com/MysticalNobody/alatyr_flutter';

String _rootReadme(InitTarget to, String? templateUrl) {
  final origin =
      '[the Alatyr Flutter template](${templateUrl ?? alatyrTemplateUrl})';
  return '''
# ${to.displayName}

Flutter app generated from $origin. The architecture, the workflow and the
quality gate are documented in [docs/README.md](docs/README.md); coding
agents start at [AGENTS.md](AGENTS.md). Machine prerequisites (Flutter via
fvm, platform SDKs, coreutils) are listed in
[docs/workflow/getting-started.md](docs/workflow/getting-started.md).

```bash
fvm install
fvm flutter pub get
tool/checks.sh
```
''';
}

String _appReadme(InitTarget to) =>
    '''
# ${to.displayName}

The app shell: `lib/main.dart` boots the composition root in
`lib/bootstrap/`, which wires the feature modules and the base packages with
manual constructor injection and assembles the router from module routes.
''';
