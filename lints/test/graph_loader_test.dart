import 'dart:io';

import 'package:alatyr_lints/src/graph/graph_loader.dart';
import 'package:test/test.dart';

const _outerGraph = '''
packages:
  outer_pkg: { kind: base, allowed_dependencies: [] }
''';

const _innerGraph = '''
packages:
  inner_pkg: { kind: base, allowed_dependencies: [] }
''';

void main() {
  setUp(() {
    GraphLoader.instance.clearForTesting();
  });

  tearDown(() {
    GraphLoader.instance.clearForTesting();
  });

  test('(a) finds the graph walking up from a nested lib dir', () {
    final tempDir = Directory.systemTemp.createTempSync();
    try {
      final graphDir = Directory('${tempDir.path}/docs/reference');
      graphDir.createSync(recursive: true);
      File(
        '${graphDir.path}/package_graph.yaml',
      ).writeAsStringSync(_outerGraph);

      final libFile = File('${tempDir.path}/packages/my_pkg/lib/src/file.dart');
      libFile.createSync(recursive: true);

      final graph = GraphLoader.instance.graphFor(libFile.path);
      expect(graph, isNotNull);
      expect(graph!.kinds, contains('outer_pkg'));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    '(b) nested tree with own graph gets ITS OWN graph when outer root cached first',
    () {
      final outerTemp = Directory.systemTemp.createTempSync();
      final innerTemp = Directory('${outerTemp.path}/inner');
      innerTemp.createSync();
      try {
        // Create outer graph
        final outerGraphDir = Directory('${outerTemp.path}/docs/reference');
        outerGraphDir.createSync(recursive: true);
        File(
          '${outerGraphDir.path}/package_graph.yaml',
        ).writeAsStringSync(_outerGraph);

        // Create inner graph
        final innerGraphDir = Directory('${innerTemp.path}/docs/reference');
        innerGraphDir.createSync(recursive: true);
        File(
          '${innerGraphDir.path}/package_graph.yaml',
        ).writeAsStringSync(_innerGraph);

        // Cache outer graph first by accessing a file in outer
        final outerFile = File(
          '${outerTemp.path}/packages/outer_pkg/lib/file.dart',
        );
        outerFile.createSync(recursive: true);
        final outerGraph = GraphLoader.instance.graphFor(outerFile.path);
        expect(outerGraph, isNotNull);
        expect(outerGraph!.kinds, contains('outer_pkg'));

        // Now access a file in inner tree - should get inner graph, not outer
        final innerFile = File(
          '${innerTemp.path}/packages/inner_pkg/lib/file.dart',
        );
        innerFile.createSync(recursive: true);
        final innerGraph = GraphLoader.instance.graphFor(innerFile.path);
        expect(innerGraph, isNotNull);
        expect(innerGraph!.kinds, contains('inner_pkg'));
        expect(innerGraph.kinds, isNot(contains('outer_pkg')));
      } finally {
        outerTemp.deleteSync(recursive: true);
      }
    },
  );

  test('(c) missing graph → null', () {
    final tempDir = Directory.systemTemp.createTempSync();
    try {
      final libFile = File('${tempDir.path}/packages/my_pkg/lib/file.dart');
      libFile.createSync(recursive: true);

      final graph = GraphLoader.instance.graphFor(libFile.path);
      expect(graph, isNull);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('(d) malformed graph file → null (stays null on second call)', () {
    final tempDir = Directory.systemTemp.createTempSync();
    try {
      final graphDir = Directory('${tempDir.path}/docs/reference');
      graphDir.createSync(recursive: true);
      File(
        '${graphDir.path}/package_graph.yaml',
      ).writeAsStringSync('- invalid\n- yaml list');

      final libFile = File('${tempDir.path}/packages/my_pkg/lib/file.dart');
      libFile.createSync(recursive: true);

      // First call - should return null
      final graph1 = GraphLoader.instance.graphFor(libFile.path);
      expect(graph1, isNull);

      // Second call - should still return null (cached)
      final graph2 = GraphLoader.instance.graphFor(libFile.path);
      expect(graph2, isNull);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('(e) clearForTesting resets', () {
    final tempDir = Directory.systemTemp.createTempSync();
    try {
      final graphDir = Directory('${tempDir.path}/docs/reference');
      graphDir.createSync(recursive: true);
      File(
        '${graphDir.path}/package_graph.yaml',
      ).writeAsStringSync(_outerGraph);

      final libFile = File('${tempDir.path}/packages/my_pkg/lib/file.dart');
      libFile.createSync(recursive: true);

      // Load the graph
      var graph = GraphLoader.instance.graphFor(libFile.path);
      expect(graph, isNotNull);

      // Clear
      GraphLoader.instance.clearForTesting();

      // Delete the graph file
      File('${graphDir.path}/package_graph.yaml').deleteSync();

      // Reload - should return null since graph file is gone and cache is cleared
      graph = GraphLoader.instance.graphFor(libFile.path);
      expect(graph, isNull);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('rootFor returns the directory holding the graph, null outside', () {
    GraphLoader.instance.clearForTesting();
    final tempDir = Directory.systemTemp.createTempSync();
    try {
      Directory('${tempDir.path}/docs/reference').createSync(recursive: true);
      File(
        '${tempDir.path}/docs/reference/package_graph.yaml',
      ).writeAsStringSync(_outerGraph);
      final libFile = File('${tempDir.path}/packages/a/lib/x.dart')
        ..createSync(recursive: true);
      expect(GraphLoader.instance.rootFor(libFile.path), tempDir.path);
      expect(GraphLoader.instance.rootFor('/nonexistent/x/lib/y.dart'), isNull);
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  });
}
