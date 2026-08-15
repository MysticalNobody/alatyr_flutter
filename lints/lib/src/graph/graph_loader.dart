import 'dart:io';

import 'package:path/path.dart' as p;

import 'package_graph.dart';

const String _graphRelativePath = 'docs/reference/package_graph.yaml';

/// Per-root cache of the parsed package graph. Any failure caches null so
/// rules silently disable instead of crashing the analyzer.
final class GraphLoader {
  GraphLoader._();

  static final GraphLoader instance = GraphLoader._();

  final Map<String, String?> _rootByDirectory = {};
  final Map<String, PackageGraph?> _graphByRoot = {};

  PackageGraph? graphFor(String filePath) {
    final dir = p.dirname(p.normalize(filePath));
    final root = _rootByDirectory.putIfAbsent(dir, () => _findRoot(dir));
    if (root == null) return null;
    return _graphByRoot.putIfAbsent(root, () => _load(root));
  }

  String? _findRoot(String startDir) {
    for (final known in _graphByRoot.keys) {
      if (p.isWithin(known, startDir) || known == startDir) return known;
    }
    var dir = startDir;
    for (var i = 0; i < 40; i++) {
      if (File(p.join(dir, _graphRelativePath)).existsSync()) return dir;
      final parent = p.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
    return null;
  }

  PackageGraph? _load(String root) {
    try {
      return PackageGraph.tryParse(
        File(p.join(root, _graphRelativePath)).readAsStringSync(),
      );
    } on Object {
      return null;
    }
  }

  void clearForTesting() {
    _rootByDirectory.clear();
    _graphByRoot.clear();
  }
}
