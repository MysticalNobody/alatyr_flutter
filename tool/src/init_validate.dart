final class InitArgumentException implements Exception {
  InitArgumentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The product identity init writes.
final class InitTarget {
  const InitTarget({
    required this.name,
    required this.org,
    required this.displayName,
    required this.bundleIdSnake,
    required this.bundleIdCamel,
    required this.workspaceName,
  });
  final String name;
  final String org;
  final String displayName;

  /// Android applicationId/namespace, Linux APPLICATION_ID: `org.name`.
  final String bundleIdSnake;

  /// iOS/macOS PRODUCT_BUNDLE_IDENTIFIER: `org.camelName` (no underscores,
  /// exactly what `flutter create` generates).
  final String bundleIdCamel;
  final String workspaceName;
}

const _dartKeywords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'function',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'of',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'while',
  'with',
  'yield',
};
// Package names flutter create refuses (they shadow SDK dependencies).
const _flutterReserved = {'flutter', 'flutter_test', 'collection', 'meta'};
const _javaKeywords = {
  'abstract',
  'assert',
  'boolean',
  'break',
  'byte',
  'case',
  'catch',
  'char',
  'class',
  'const',
  'continue',
  'default',
  'do',
  'double',
  'else',
  'enum',
  'extends',
  'final',
  'finally',
  'float',
  'for',
  'goto',
  'if',
  'implements',
  'import',
  'instanceof',
  'int',
  'interface',
  'long',
  'native',
  'new',
  'package',
  'private',
  'protected',
  'public',
  'return',
  'short',
  'static',
  'strictfp',
  'super',
  'switch',
  'synchronized',
  'this',
  'throw',
  'throws',
  'transient',
  'try',
  'void',
  'volatile',
  'while',
  'true',
  'false',
  'null',
};
// Windows refuses these as file or directory names, and the name plus every
// org segment becomes an Android package directory.
const _windowsReserved = {
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
};
final _name = RegExp(r'^[a-z][a-z0-9_]*$');
// No underscores: the org goes verbatim into Apple bundle identifiers.
final _orgSegment = RegExp(r'^[a-z][a-z0-9]*$');
// The display name lands in Dart strings, XML, JSON, YAML, C++ and a Windows
// resource script without escaping: letters, digits, spaces, dots, hyphens.
final _displayName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 .-]*$');
// The URL lands inside a markdown link in the generated README: no spaces,
// no parentheses or angle brackets that would break the link syntax.
final _templateUrl = RegExp(r'^https?://[^\s()<>]+$');

/// Validates `--template-url`. Empty or malformed is an argument error, not
/// a dead link in the generated README.
void validateTemplateUrl(String url) {
  if (!_templateUrl.hasMatch(url)) {
    throw InitArgumentException(
      '--template-url "$url" must be a http(s) URL without spaces, parentheses or angle brackets',
    );
  }
}

/// The target may not reuse the placeholder's own tokens. The rewrite is a
/// whole-token replacement and its postcondition scans the tree for the
/// placeholder afterwards, so such a target either corrupts the output (an
/// org that EXTENDS the placeholder org is matched a second time and doubled)
/// or makes that scan report a false "identity survived" - and the scan runs
/// after the deletions, the directory moves and every rewrite. Refusing here
/// keeps the failure an argument error, before anything is touched.
void validateNotPlaceholder({
  required InitTarget to,
  required String placeholderOrg,
  required String placeholderPackageName,
  required String placeholderDisplayName,
  required String placeholderWorkspaceName,
}) {
  if (to.org == placeholderOrg) {
    throw InitArgumentException(
      '--org "${to.org}" is the template\'s own org: the rewrite would leave it '
      'in place and then report it as a surviving placeholder. Pick a different org.',
    );
  }
  if (to.org.startsWith('$placeholderOrg.')) {
    throw InitArgumentException(
      '--org "${to.org}" extends the template\'s org "$placeholderOrg": the whole-token '
      'rewrite would match it twice and produce a doubled identifier. Pick an org that '
      'does not start with "$placeholderOrg.".',
    );
  }
  if (to.name == placeholderPackageName) {
    throw InitArgumentException(
      '--name "${to.name}" is the template\'s own package name; pick a different name',
    );
  }
  if (to.displayName == placeholderDisplayName) {
    throw InitArgumentException(
      '--display-name "${to.displayName}" is the template\'s own display name; pick a different one',
    );
  }
  if (to.workspaceName == placeholderWorkspaceName) {
    throw InitArgumentException(
      '--name "${to.name}" yields the template\'s own workspace name '
      '"$placeholderWorkspaceName"; pick a different name',
    );
  }
}

InitTarget validateTarget({
  required String name,
  required String org,
  String? displayName,
  List<String> workspaceMembers = const [],
}) {
  if (!_name.hasMatch(name)) {
    throw InitArgumentException(
      '--name "$name" must be lowercase_with_underscores starting with a letter (a Dart package name)',
    );
  }
  if (_dartKeywords.contains(name)) {
    throw InitArgumentException('--name "$name" is a Dart keyword');
  }
  if (_flutterReserved.contains(name)) {
    throw InitArgumentException('--name "$name" shadows a Flutter SDK package');
  }
  if (workspaceMembers.contains(name)) {
    throw InitArgumentException(
      '--name "$name" is already a package in this workspace (${workspaceMembers.join(', ')})',
    );
  }
  final segments = org.split('.');
  if (segments.length < 2 || !segments.every(_orgSegment.hasMatch)) {
    throw InitArgumentException(
      '--org "$org" must be a reverse domain of lowercase letters and digits, e.g. com.example (no underscores: Apple bundle ids)',
    );
  }
  for (final segment in [...segments, name]) {
    if (_javaKeywords.contains(segment)) {
      throw InitArgumentException(
        "'$segment' is a Java keyword and cannot be an Android package segment",
      );
    }
    if (_windowsReserved.contains(segment)) {
      throw InitArgumentException(
        "'$segment' is a Windows reserved device name and cannot be a package directory",
      );
    }
  }
  final display = displayName ?? titleCase(name);
  if (!_displayName.hasMatch(display)) {
    throw InitArgumentException(
      '--display-name "$display" may contain only letters, digits, spaces, dots and hyphens, and must not start with a space',
    );
  }
  return InitTarget(
    name: name,
    org: org,
    displayName: display,
    bundleIdSnake: '$org.$name',
    bundleIdCamel: '$org.${camelCase(name)}',
    workspaceName: '${name}_workspace',
  );
}

/// `my_app` -> `myApp` (flutter create's UTI rule).
String camelCase(String snake) {
  final parts = snake.split('_').where((s) => s.isNotEmpty).toList();
  return [
    parts.first,
    for (final p in parts.skip(1)) '${p[0].toUpperCase()}${p.substring(1)}',
  ].join();
}

/// `my_app` -> `My App` (flutter create's default display name).
String titleCase(String snake) => snake
    .split('_')
    .where((s) => s.isNotEmpty)
    .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
    .join(' ');
