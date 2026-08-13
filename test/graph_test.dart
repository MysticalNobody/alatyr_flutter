import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/graph.dart';

String fixture(String name) =>
    File(p.join('test', 'fixtures', 'graphs', name)).readAsStringSync();

void main() {
  test('loads a valid graph', () {
    final g = loadPackageGraph(fixture('valid.yaml'), sourcePath: 'valid.yaml');
    expect(g.packageKinds, contains('feature_api'));
    expect(g.bannedPackages.keys, contains('get_it'));
    expect(g.pureDartPackages, contains('app_core'));
    expect(g.packages['app_config']!.allowedDependencies, ['app_core']);
    expect(g.packages['app_config']!.allowsAllMembers, isFalse);
  });

  test('sentinel *_all_members sets allowsAllMembers', () {
    final src = fixture('valid.yaml').replaceFirst(
        'app_config: { kind: base, allowed_dependencies: [app_core] }',
        'app_config: { kind: base, allowed_dependencies: "*_all_members" }');
    final g = loadPackageGraph(src, sourcePath: 'valid.yaml');
    expect(g.packages['app_config']!.allowsAllMembers, isTrue);
  });

  test('unknown kind is a format error', () {
    expect(() => loadPackageGraph(fixture('unknown_kind.yaml'), sourcePath: 'x'),
        throwsA(isA<GraphFormatException>()));
  });

  test('allowed dependency on unknown package is a format error', () {
    expect(() => loadPackageGraph(fixture('dangling_dep.yaml'), sourcePath: 'x'),
        throwsA(isA<GraphFormatException>()));
  });
}
