import 'package:yaml/yaml.dart';

const String _allMembersSentinel = '*_all_members';

/// Parsed view of docs/reference/package_graph.yaml for IDE-time rules.
/// Tolerant by design: [tryParse] returns null on any structural problem —
/// a broken graph must degrade rules, never crash the analyzer host. The
/// strict, loud loader lives in tool/src/graph.dart.
final class PackageGraph {
  const PackageGraph({
    required this.kinds,
    required this.allowed,
    required this.allowsAll,
    required this.banned,
    required this.pure,
  });

  final Map<String, String> kinds;
  final Map<String, List<String>> allowed;
  final Set<String> allowsAll;
  final Map<String, String> banned;
  final Set<String> pure;

  static PackageGraph? tryParse(String yamlSource) {
    try {
      final root = loadYaml(yamlSource);
      if (root is! YamlMap) return null;
      final rawPackages = root['packages'];
      if (rawPackages is! YamlMap) return null;

      final kinds = <String, String>{};
      final allowed = <String, List<String>>{};
      final allowsAll = <String>{};
      for (final entry in rawPackages.entries) {
        final name = entry.key.toString();
        final value = entry.value;
        if (value is! YamlMap) return null;
        if (value['kind'] == null) return null;
        kinds[name] = value['kind'].toString();
        final deps = value['allowed_dependencies'];
        if (deps is String && deps == _allMembersSentinel) {
          allowsAll.add(name);
          allowed[name] = const [];
        } else if (deps is YamlList) {
          allowed[name] = [for (final d in deps) d.toString()];
        } else {
          allowed[name] = const [];
        }
      }
      final banned = <String, String>{
        if (root['banned_packages'] is YamlMap)
          for (final e in (root['banned_packages'] as YamlMap).entries)
            e.key.toString(): e.value.toString(),
      };
      final pure = <String>{
        if (root['pure_dart_packages'] is YamlList)
          for (final p in root['pure_dart_packages'] as YamlList) p.toString(),
      };
      return PackageGraph(
        kinds: kinds,
        allowed: allowed,
        allowsAll: allowsAll,
        banned: banned,
        pure: pure,
      );
    } on Object {
      return null;
    }
  }
}
