import 'package:yaml/yaml.dart';

// Mirrored by the tolerant IDE-side parser:
// lints/lib/src/graph/package_graph.dart — keep schema changes in sync.
const String allMembersSentinel = '*_all_members';

final class GraphFormatException implements Exception {
  GraphFormatException(this.message);
  final String message;
  @override
  String toString() => 'GraphFormatException: $message';
}

final class PackageNode {
  const PackageNode({
    required this.kind,
    required this.allowedDependencies,
    required this.allowsAllMembers,
  });
  final String kind;
  final List<String> allowedDependencies;
  final bool allowsAllMembers;
}

final class PackageGraph {
  const PackageGraph({
    required this.packageKinds,
    required this.bannedPackages,
    required this.pureDartPackages,
    required this.packages,
  });
  final List<String> packageKinds;
  final Map<String, String> bannedPackages;
  final Set<String> pureDartPackages;
  final Map<String, PackageNode> packages;
}

PackageGraph loadPackageGraph(String yamlSource, {required String sourcePath}) {
  final root = loadYaml(yamlSource);
  if (root is! YamlMap) {
    throw GraphFormatException('$sourcePath: top level must be a map');
  }
  final kinds = [
    for (final k in _req<YamlList>(root, 'package_kinds', sourcePath))
      k.toString(),
  ];
  final banned = <String, String>{
    for (final e in _req<YamlMap>(root, 'banned_packages', sourcePath).entries)
      e.key.toString(): e.value.toString(),
  };
  final pure = {
    for (final k in _req<YamlList>(root, 'pure_dart_packages', sourcePath))
      k.toString(),
  };
  final rawPackages = _req<YamlMap>(root, 'packages', sourcePath);
  final packages = <String, PackageNode>{};
  for (final entry in rawPackages.entries) {
    final name = entry.key.toString();
    final value = entry.value;
    if (value is! YamlMap) {
      throw GraphFormatException('$sourcePath: packages.$name must be a map');
    }
    final kind = value['kind']?.toString();
    if (kind == null || !kinds.contains(kind)) {
      throw GraphFormatException(
        '$sourcePath: packages.$name has unknown kind "$kind"',
      );
    }
    final rawDeps = value['allowed_dependencies'];
    final allowsAll = rawDeps is String && rawDeps == allMembersSentinel;
    final deps = _parseAllowedDependencies(
      rawDeps,
      allowsAll: allowsAll,
      name: name,
      sourcePath: sourcePath,
    );
    packages[name] = PackageNode(
      kind: kind,
      allowedDependencies: deps,
      allowsAllMembers: allowsAll,
    );
  }
  for (final entry in packages.entries) {
    for (final dep in entry.value.allowedDependencies) {
      if (!packages.containsKey(dep)) {
        throw GraphFormatException(
          '$sourcePath: packages.${entry.key} allows unknown package "$dep"',
        );
      }
    }
  }
  for (final name in pure) {
    if (!packages.containsKey(name)) {
      throw GraphFormatException(
        '$sourcePath: pure_dart_packages lists unknown package "$name"',
      );
    }
  }
  return PackageGraph(
    packageKinds: kinds,
    bannedPackages: banned,
    pureDartPackages: pure,
    packages: packages,
  );
}

T _req<T>(YamlMap map, String key, String sourcePath) {
  final value = map[key];
  if (value is! T) {
    throw GraphFormatException('$sourcePath: "$key" missing or wrong type');
  }
  return value;
}

List<String> _parseAllowedDependencies(
  Object? rawDeps, {
  required bool allowsAll,
  required String name,
  required String sourcePath,
}) {
  if (allowsAll) return const <String>[];
  if (rawDeps is YamlList) {
    return [for (final d in rawDeps) d.toString()];
  }
  throw GraphFormatException(
    '$sourcePath: packages.$name.allowed_dependencies must be a '
    'list or "$allMembersSentinel"',
  );
}
