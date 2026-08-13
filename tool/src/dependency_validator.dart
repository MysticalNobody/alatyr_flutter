import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'graph.dart';

List<String> validateDependencies({
  required String rootDir,
  String graphPath = 'docs/reference/package_graph.yaml',
}) {
  final violations = <String>[];
  final graphFile = File(p.join(rootDir, graphPath));
  final graph = loadPackageGraph(
    graphFile.readAsStringSync(),
    sourcePath: graphFile.path,
  );

  final rootPubspec =
      loadYaml(File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync())
          as YamlMap;
  final memberPaths = [
    for (final m in rootPubspec['workspace'] as YamlList? ?? YamlList())
      m.toString(),
  ];

  final membersByName = <String, String>{}; // name -> dir
  for (final memberPath in memberPaths) {
    final pubspecFile = File(p.join(rootDir, memberPath, 'pubspec.yaml'));
    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    membersByName[pubspec['name'].toString()] = memberPath;
  }

  for (final name in membersByName.keys) {
    if (!graph.packages.containsKey(name)) {
      violations.add(
        '${membersByName[name]}/pubspec.yaml: '
        'workspace member "$name" is missing from the package graph',
      );
    }
  }
  for (final name in graph.packages.keys) {
    if (!membersByName.containsKey(name)) {
      violations.add('$graphPath: graph entry "$name" has no workspace member');
    }
  }

  for (final entry in membersByName.entries) {
    final name = entry.key;
    final node = graph.packages[name];
    if (node == null) continue;
    final pubspecPath = p.join(entry.value, 'pubspec.yaml');
    final pubspec =
        loadYaml(File(p.join(rootDir, pubspecPath)).readAsStringSync())
            as YamlMap;
    final isPure = graph.pureDartPackages.contains(name);

    for (final section in ['dependencies', 'dev_dependencies']) {
      final deps = pubspec[section];
      if (deps is! YamlMap) continue;
      for (final dep in deps.entries) {
        final depName = dep.key.toString();
        final banReason = graph.bannedPackages[depName];
        if (banReason != null) {
          violations.add('$pubspecPath: "$depName" is banned - $banReason');
        }
        if (isPure && (depName == 'flutter' || depName == 'flutter_test')) {
          violations.add(
            '$pubspecPath: pure Dart package "$name" declares "$depName"',
          );
        }
        if (membersByName.containsKey(depName)) {
          final allowed =
              node.allowsAllMembers ||
              node.allowedDependencies.contains(depName);
          if (!allowed) {
            violations.add(
              '$pubspecPath: dependency on member "$depName" is '
              'not allowed by the package graph',
            );
          }
          if (isPure && !graph.pureDartPackages.contains(depName)) {
            violations.add(
              '$pubspecPath: pure Dart package "$name" depends on '
              'non-pure member "$depName"',
            );
          }
        }
      }
    }
  }
  return violations;
}
