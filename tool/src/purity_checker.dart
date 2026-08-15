import 'dart:collection';
import 'dart:convert';

/// The `dart pub deps --json` node name for the Flutter SDK. Its presence
/// in a resolved dependency closure is the ground truth for "requires
/// Flutter" - unlike name-based heuristics (e.g. "starts with flutter_"),
/// it catches plugins with unrelated names (e.g. `shared_preferences`).
const String _flutterSdkPackage = 'flutter';

/// Checks whether any package in [purePackages] transitively resolves to
/// the Flutter SDK, using the RESOLVED dependency graph from
/// `dart pub deps --json` ([pubDepsJson]) rather than package-name
/// heuristics.
///
/// [pubDepsJson] must decode to a map with a `packages` list; each entry
/// is expected to carry `name` (String) and `dependencies` (List of
/// String, direct + dev merged - the shape `dart pub deps --json` emits).
/// Anything else on an entry is ignored.
///
/// Returns one message per pure package that either:
///  - transitively depends on `flutter` (message includes the shortest
///    offending path, e.g. `app_core -> shared_preferences -> flutter`), or
///  - is missing from the JSON entirely (fail closed: a pure package the
///    resolved graph doesn't know about cannot be vouched for, so it's a
///    loud violation rather than a silent pass).
///
/// Pure function: no I/O, no process spawning. Deterministic - neighbor
/// lists are sorted before the BFS runs, so the shortest-path message is
/// stable across runs even when multiple equal-length paths exist.
List<String> purityViolations({
  required String pubDepsJson,
  required Set<String> purePackages,
}) {
  final decoded = jsonDecode(pubDepsJson);
  final adjacency = _adjacencyFrom(decoded);

  final violations = <String>[];
  final sortedPure = purePackages.toList()..sort();
  for (final pure in sortedPure) {
    if (!adjacency.containsKey(pure)) {
      violations.add(
        '$pure: missing from `dart pub deps --json` output - transitive '
        'purity cannot be verified (fail closed)',
      );
      continue;
    }
    final path = _shortestPathToFlutter(pure, adjacency);
    if (path != null) {
      violations.add(
        '$pure: transitively requires the Flutter SDK via '
        '${path.join(' -> ')}',
      );
    }
  }
  return violations;
}

/// Builds a name -> sorted-neighbor-names adjacency map from the decoded
/// `dart pub deps --json` payload.
Map<String, List<String>> _adjacencyFrom(Object? decoded) {
  final adjacency = <String, List<String>>{};
  if (decoded is! Map) return adjacency;
  final packages = decoded['packages'];
  if (packages is! List) return adjacency;
  for (final entry in packages) {
    if (entry is! Map) continue;
    final name = entry['name'];
    if (name is! String) continue;
    final rawDeps = entry['dependencies'];
    final deps = <String>[
      if (rawDeps is List)
        for (final d in rawDeps) d.toString(),
    ]..sort();
    adjacency[name] = deps;
  }
  return adjacency;
}

/// Breadth-first shortest path from [start] to the `flutter` node, or null
/// if `flutter` isn't reachable. [adjacency] neighbor lists must already
/// be sorted for the result to be deterministic.
List<String>? _shortestPathToFlutter(
  String start,
  Map<String, List<String>> adjacency,
) {
  if (start == _flutterSdkPackage) return const [_flutterSdkPackage];

  final visited = <String>{start};
  final parent = <String, String>{};
  final queue = Queue<String>()..add(start);

  while (queue.isNotEmpty) {
    final current = queue.removeFirst();
    for (final next in adjacency[current] ?? const <String>[]) {
      if (!visited.add(next)) continue;
      parent[next] = current;
      if (next == _flutterSdkPackage) {
        final path = <String>[_flutterSdkPackage];
        var node = current;
        while (node != start) {
          path.add(node);
          node = parent[node]!;
        }
        path.add(start);
        return path.reversed.toList();
      }
      queue.add(next);
    }
  }
  return null;
}
