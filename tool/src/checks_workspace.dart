import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final class ChecksPackage {
  const ChecksPackage({
    required this.path,
    required this.isFlutter,
    required this.hasTests,
  });
  final String path;
  final bool isFlutter;
  final bool hasTests;
}

String formatChecksPlanLine(ChecksPackage pkg) =>
    '${pkg.isFlutter ? 'flutter' : 'dart'}\t${pkg.path}\t${pkg.hasTests}';

List<ChecksPackage> buildChecksPlan(String rootDir) => [
  for (final dir in _memberDirs(rootDir))
    ChecksPackage(
      path: dir,
      isFlutter: _isFlutter(_pubspec(rootDir, dir)),
      hasTests: _hasTests(Directory(p.join(rootDir, dir, 'test'))),
    ),
];

List<String> buildCodegenPlan(String rootDir) => [
  if (_declaresBuildRunner(_pubspec(rootDir, '.'))) '.',
  for (final dir in _memberDirs(rootDir))
    if (_declaresBuildRunner(_pubspec(rootDir, dir))) dir,
];

List<String> _memberDirs(String rootDir) {
  final workspace = _pubspec(rootDir, '.')['workspace'];
  if (workspace is! YamlList) {
    throw StateError('Root pubspec.yaml must contain a workspace list.');
  }
  return [for (final m in workspace) m.toString()];
}

YamlMap _pubspec(String rootDir, String dir) =>
    loadYaml(File(p.join(rootDir, dir, 'pubspec.yaml')).readAsStringSync())
        as YamlMap;

bool _isFlutter(YamlMap pubspec) {
  final env = pubspec['environment'];
  if (env is YamlMap && env.containsKey('flutter')) return true;
  for (final section in ['dependencies', 'dev_dependencies']) {
    final deps = pubspec[section];
    if (deps is YamlMap) {
      for (final v in deps.values) {
        if (v is YamlMap && v['sdk'] == 'flutter') return true;
      }
    }
  }
  return false;
}

bool _declaresBuildRunner(YamlMap pubspec) {
  for (final section in ['dependencies', 'dev_dependencies']) {
    final deps = pubspec[section];
    if (deps is YamlMap && deps.containsKey('build_runner')) return true;
  }
  return false;
}

bool _hasTests(Directory testDir) =>
    testDir.existsSync() &&
    testDir
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.endsWith('_test.dart'));
