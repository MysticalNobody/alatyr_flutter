import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/dependency_validator.dart';

String ws(String name) => p.join('test', 'fixtures', 'workspaces', name);

void main() {
  test('clean workspace has no violations', () {
    expect(
      validateDependencies(rootDir: ws('clean'), graphPath: 'graph.yaml'),
      isEmpty,
    );
  });

  test('member edge not in allowed_dependencies is reported', () {
    final v = validateDependencies(
      rootDir: ws('forbidden_edge'),
      graphPath: 'graph.yaml',
    );
    expect(v, hasLength(1));
    expect(
      v.single,
      allOf(contains('b'), contains('a'), contains('not allowed')),
    );
  });

  test('banned packages are reported with reasons, in both sections', () {
    final v = validateDependencies(
      rootDir: ws('banned_dep'),
      graphPath: 'graph.yaml',
    );
    expect(v, hasLength(2));
    expect(
      v.join('\n'),
      allOf(
        contains('get_it'),
        contains('mockito'),
        contains('manual constructor DI'),
      ),
    );
  });

  test('graph and workspace membership are checked both ways', () {
    final v = validateDependencies(
      rootDir: ws('graph_drift'),
      graphPath: 'graph.yaml',
    );
    expect(v.join('\n'), allOf(contains('c'), contains('ghost')));
    expect(v, hasLength(2));
  });

  test('pure packages may not touch Flutter or non-pure members', () {
    final v = validateDependencies(
      rootDir: ws('impure'),
      graphPath: 'graph.yaml',
    );
    expect(v.join('\n'), allOf(contains('flutter'), contains('non-pure')));
    expect(v, hasLength(2));
  });
}
