import 'package:alatyr_lints/src/graph/package_graph.dart';
import 'package:alatyr_lints/src/graph/path_resolver.dart';
import 'package:test/test.dart';

const _graph = '''
package_kinds: [base, app_root]
banned_packages: {}
pure_dart_packages: []
packages:
  app_core: { kind: base, allowed_dependencies: [] }
  alatyr_starter: { kind: app_root, allowed_dependencies: "*_all_members" }
''';

void main() {
  final g = PackageGraph.tryParse(_graph)!;

  test('packages/<name> resolves to the package name', () {
    expect(
      graphKeyForPath(
        filePath: '/r/packages/app_core/lib/src/x.dart',
        graph: g,
      ),
      'app_core',
    );
  });

  test('app/ resolves to the single app_root package', () {
    expect(
      graphKeyForPath(filePath: '/r/app/lib/main.dart', graph: g),
      'alatyr_starter',
    );
  });

  test('packages wins over a later app segment', () {
    expect(
      graphKeyForPath(
        filePath: '/r/packages/app_core/lib/app/y.dart',
        graph: g,
      ),
      'app_core',
    );
  });

  test('unknown locations resolve to null', () {
    expect(graphKeyForPath(filePath: '/r/tool/x.dart', graph: g), isNull);
    expect(
      graphKeyForPath(filePath: '/r/packages/ghost/lib/g.dart', graph: g),
      isNull,
    );
  });

  test('windows separators are normalized', () {
    expect(
      graphKeyForPath(filePath: r'C:\r\packages\app_core\lib\x.dart', graph: g),
      'app_core',
    );
  });
}
