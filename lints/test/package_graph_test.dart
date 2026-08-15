import 'package:alatyr_lints/src/graph/package_graph.dart';
import 'package:test/test.dart';

const _graph = '''
package_kinds: [base, feature_api, feature_impl, app_root]
banned_packages:
  get_it: "manual constructor DI"
pure_dart_packages: [app_core]
packages:
  app_core:   { kind: base, allowed_dependencies: [] }
  app_config: { kind: base, allowed_dependencies: [app_core] }
  alatyr_starter: { kind: app_root, allowed_dependencies: "*_all_members" }
''';

void main() {
  test('parses kinds, allowed, banned, pure, sentinel', () {
    final g = PackageGraph.tryParse(_graph)!;
    expect(g.kinds['app_config'], 'base');
    expect(g.allowed['app_config'], ['app_core']);
    expect(g.allowsAll, contains('alatyr_starter'));
    expect(g.banned['get_it'], contains('DI'));
    expect(g.pure, contains('app_core'));
  });

  test('malformed input returns null, never throws', () {
    expect(PackageGraph.tryParse('- just\n- a list'), isNull);
    expect(PackageGraph.tryParse(': not yaml ::'), isNull);
    expect(PackageGraph.tryParse(''), isNull);
  });

  test('missing kind returns null', () {
    const malformedGraph = '''
packages:
  app_core: { allowed_dependencies: [] }
''';
    expect(PackageGraph.tryParse(malformedGraph), isNull);
  });

  test('non-sentinel scalar allowed_dependencies returns null', () {
    const malformedGraph = '''
packages:
  app_core: { kind: base, allowed_dependencies: banana }
''';
    expect(PackageGraph.tryParse(malformedGraph), isNull);
  });

  test('missing allowed_dependencies returns null', () {
    const malformedGraph = '''
packages:
  app_core: { kind: base }
''';
    expect(PackageGraph.tryParse(malformedGraph), isNull);
  });
}
