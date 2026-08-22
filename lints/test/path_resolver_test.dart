import 'package:alatyr_lints/src/graph/package_graph.dart';
import 'package:alatyr_lints/src/graph/path_resolver.dart';
import 'package:test/test.dart';

const _graph = '''
package_kinds: [base, app_root]
banned_packages: {}
pure_dart_packages: []
packages:
  app_core: { kind: base, allowed_dependencies: [] }
  data_local: { kind: base, allowed_dependencies: [] }
  demo_app: { kind: app_root, allowed_dependencies: "*_all_members" }
''';

void main() {
  final g = PackageGraph.tryParse(_graph)!;
  String? key(String filePath, {String root = '/r'}) =>
      graphKeyForPath(filePath: filePath, graph: g, root: root);

  test('packages/<name> resolves to the package name', () {
    expect(key('/r/packages/app_core/lib/src/x.dart'), 'app_core');
  });

  test('app/ resolves to the single app_root package', () {
    expect(key('/r/app/lib/main.dart'), 'demo_app');
  });

  test(
    'a nested "packages/<key>" dir inside a package does not reattribute',
    () {
      // Left-to-right this already worked by luck (first match wins); anchored
      // resolution makes it a guarantee: only segments[0..1] below root count.
      expect(
        key('/r/packages/app_core/lib/packages/data_local/x.dart'),
        'app_core',
      );
    },
  );

  test('a nested "app" dir inside a package does not reattribute', () {
    expect(key('/r/packages/app_core/lib/app/y.dart'), 'app_core');
  });

  test('a "packages/<key>" dir inside app/ stays the app root', () {
    expect(key('/r/app/lib/packages/app_core/z.dart'), 'demo_app');
  });

  group('clone under an ancestor named app/ (e.g. /home/u/app/alatyr)', () {
    const root = '/home/u/app/alatyr';
    test('tool/ and root test/ files are outside any package', () {
      // The old scan saw the ancestor "app" segment and attributed these to
      // the app root, so boundary/purity rules fired on toolchain code.
      expect(key('$root/tool/x.dart', root: root), isNull);
      expect(key('$root/test/graph_test.dart', root: root), isNull);
    });
    test('an unknown package is still unknown', () {
      expect(key('$root/packages/ghost/lib/g.dart', root: root), isNull);
    });
    test('real members still resolve', () {
      expect(key('$root/app/lib/main.dart', root: root), 'demo_app');
      expect(key('$root/packages/app_core/lib/x.dart', root: root), 'app_core');
    });
  });

  group('clone under an ancestor named packages/app_core/', () {
    const root = '/srv/packages/app_core/alatyr';
    test('member resolution is taken from below the root, not above it', () {
      // The old scan matched the ancestor packages/app_core first and
      // reported data_local's files as app_core.
      expect(
        key('$root/packages/data_local/lib/x.dart', root: root),
        'data_local',
      );
      expect(key('$root/tool/x.dart', root: root), isNull);
    });
  });

  test('a file outside the root resolves to null', () {
    expect(key('/other/packages/app_core/lib/x.dart'), isNull);
    // Prefix must be a whole segment: /r2 is not inside /r.
    expect(key('/r2/packages/app_core/lib/x.dart'), isNull);
  });

  test('a root given with a trailing slash behaves the same', () {
    expect(key('/r/packages/app_core/lib/x.dart', root: '/r/'), 'app_core');
  });

  test('too-shallow paths resolve to null', () {
    expect(key('/r/packages/app_core'), isNull);
    expect(key('/r/app'), isNull);
  });

  test('windows separators are normalized (file and root)', () {
    expect(
      key(r'C:\r\packages\app_core\lib\x.dart', root: r'C:\r'),
      'app_core',
    );
    expect(key(r'C:\r\packages\app_core\lib\x.dart', root: 'C:/r'), 'app_core');
  });
}
