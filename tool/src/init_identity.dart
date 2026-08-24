import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The placeholder identity, derived from the app shell so that tool/ never
/// spells it (test/template_identity_test.dart keeps tool/ token-free).
final class TemplateIdentity {
  const TemplateIdentity({
    required this.packageName,
    required this.bundleId,
    required this.org,
    required this.displayName,
    required this.workspaceName,
  });
  final String packageName;
  final String bundleId;
  final String org;
  final String displayName;
  final String workspaceName;
}

final _applicationId = RegExp(
  r'^\s*applicationId\s*=\s*"([^"]+)"\s*$',
  multiLine: true,
);
final _displayName = RegExp(
  r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>',
);

/// Reads a file init cannot work without. A missing one is a `StateError`
/// naming the path, never a raw `PathNotFoundException`.
String _read(String rootDir, String rel) {
  final file = File(p.join(rootDir, rel));
  if (!file.existsSync()) {
    throw StateError(
      '$rel not found — init expects the full platform set of the template',
    );
  }
  return file.readAsStringSync();
}

/// The `name:` of a pubspec. A missing key must not become the literal
/// string "null" (which would silently become the derived identity).
String _pubspecName(String rootDir, String rel) {
  final yaml = loadYaml(_read(rootDir, rel));
  final name = yaml is YamlMap ? yaml['name'] : null;
  if (name == null || name.toString().trim().isEmpty) {
    throw StateError(
      '$rel has no "name:" key — init cannot derive an identity',
    );
  }
  return name.toString();
}

/// Package names of the workspace members declared in the root
/// `pubspec.yaml`, so init can refuse a `--name` that collides with one.
/// Members whose pubspec is missing or nameless are skipped: this list only
/// makes an error message possible, it is not a validation of the workspace.
List<String> workspaceMemberNames(String rootDir) {
  final pubspec = File(p.join(rootDir, 'pubspec.yaml'));
  // A missing root pubspec is deriveIdentity's error to report, after the
  // arguments have been validated.
  if (!pubspec.existsSync()) {
    return const [];
  }
  final root = loadYaml(pubspec.readAsStringSync());
  final members = root is YamlMap ? root['workspace'] : null;
  if (members is! YamlList) {
    return const [];
  }
  final names = <String>[];
  for (final member in members) {
    final rel = p.join(member.toString(), 'pubspec.yaml');
    if (!File(p.join(rootDir, rel)).existsSync()) {
      continue;
    }
    try {
      names.add(_pubspecName(rootDir, rel));
    } on StateError {
      continue;
    }
  }
  return names;
}

TemplateIdentity deriveIdentity(String rootDir) {
  String read(String rel) => _read(rootDir, rel);

  final workspaceName = _pubspecName(rootDir, 'pubspec.yaml');
  final graph = loadYaml(read('docs/reference/package_graph.yaml'));
  final packages = graph is YamlMap ? graph['packages'] : null;
  if (packages is! YamlMap) {
    throw StateError(
      'docs/reference/package_graph.yaml has no "packages:" map — init cannot find the app_root',
    );
  }
  final appRoots = [
    for (final e in packages.entries)
      if ((e.value as YamlMap)['kind'] == 'app_root') e.key.toString(),
  ];
  if (appRoots.length != 1) {
    throw StateError(
      'package_graph.yaml must have exactly one app_root, found $appRoots',
    );
  }
  final appPubspecName = _pubspecName(rootDir, 'app/pubspec.yaml');
  if (appPubspecName != appRoots.single) {
    throw StateError(
      'app/pubspec.yaml name "$appPubspecName" != graph app_root "${appRoots.single}"',
    );
  }
  final gradle = read('app/android/app/build.gradle.kts');
  final bundleId =
      _applicationId.firstMatch(gradle)?.group(1) ??
      (throw StateError(
        'applicationId not found in app/android/app/build.gradle.kts',
      ));
  final org = bundleId.substring(0, bundleId.lastIndexOf('.'));
  final plist = read('app/ios/Runner/Info.plist');
  final displayName =
      _displayName.firstMatch(plist)?.group(1) ??
      (throw StateError(
        'CFBundleDisplayName not found in app/ios/Runner/Info.plist',
      ));
  return TemplateIdentity(
    packageName: appRoots.single,
    bundleId: bundleId,
    org: org,
    displayName: displayName,
    workspaceName: workspaceName,
  );
}
