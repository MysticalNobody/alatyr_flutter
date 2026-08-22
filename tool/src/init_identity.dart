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

TemplateIdentity deriveIdentity(String rootDir) {
  String read(String rel) => File(p.join(rootDir, rel)).readAsStringSync();

  final workspaceName = (loadYaml(read('pubspec.yaml')) as YamlMap)['name']
      .toString();
  final graph = loadYaml(read('docs/reference/package_graph.yaml')) as YamlMap;
  final appRoots = [
    for (final e in (graph['packages'] as YamlMap).entries)
      if ((e.value as YamlMap)['kind'] == 'app_root') e.key.toString(),
  ];
  if (appRoots.length != 1) {
    throw StateError(
      'package_graph.yaml must have exactly one app_root, found $appRoots',
    );
  }
  final appPubspecName = (loadYaml(read('app/pubspec.yaml')) as YamlMap)['name']
      .toString();
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
