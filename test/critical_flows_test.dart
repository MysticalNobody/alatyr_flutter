import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/critical_flows.dart';

String fx(String name) => p.join('test', 'fixtures', 'critical_flows', name);

void main() {
  test('every registered test exists: no violations; backticks tolerated', () {
    expect(validateCriticalFlows(rootDir: fx('ok')), isEmpty);
  });

  test(
    'header and separator rows are skipped, rows parsed with line numbers',
    () {
      final problems = <String>[];
      final flows = parseCriticalFlows(
        '| Flow | Test |\n|:---|---:|\n| a | `x_test.dart` |\n',
        problems: problems,
      );
      expect(problems, isEmpty);
      expect(flows.single.name, 'a');
      expect(flows.single.testPath, 'x_test.dart');
      expect(flows.single.line, 3);
    },
  );

  test('an empty registry (header only) is valid', () {
    expect(validateCriticalFlows(rootDir: fx('empty')), isEmpty);
  });

  test('a missing test path is a violation naming flow, line and path', () {
    final v = validateCriticalFlows(rootDir: fx('missing'));
    expect(v, hasLength(1));
    expect(
      v.single,
      allOf(
        startsWith('docs/reference/critical_flows.md:3:'),
        contains('ghost flow'),
        contains('app/integration_test/ghost_test.dart'),
        contains('missing'),
      ),
    );
  });

  test('malformed rows, absolute paths and non-test files are reported', () {
    final v = validateCriticalFlows(rootDir: fx('malformed'));
    expect(
      v.join('\n'),
      allOf(
        contains(':3: expected 2 cells'),
        contains(':4: expected 2 cells'),
        contains(':5: "/etc/passwd_test.dart" must be a repo-relative path'),
        contains(':6: "app/lib/main.dart" is not a *_test.dart file'),
        contains(':6: "app/lib/main.dart" is not under app/integration_test/'),
        contains(':6: flow "not a test" points to a missing test'),
        contains(
          ':7: "test/graph_test.dart" is not under app/integration_test/',
        ),
      ),
    );
    expect(v, hasLength(7));
  });

  test('a missing header row is a violation', () {
    final problems = <String>[];
    parseCriticalFlows('|---|---|\n', problems: problems);
    expect(problems.single, contains('header'));
  });

  test('a missing registry file is a violation, not a crash', () {
    expect(
      validateCriticalFlows(rootDir: fx('nope')).single,
      contains('missing'),
    );
  });

  test('an integration test absent from the registry is a violation', () {
    final v = validateCriticalFlows(rootDir: fx('unregistered'));
    expect(v, hasLength(1));
    expect(
      v.single,
      allOf(
        contains('app/integration_test/orphan_test.dart'),
        contains('not registered'),
        contains('docs/reference/critical_flows.md'),
      ),
    );
  });

  test('a tree with no integration_test directory has nothing to register', () {
    // The empty fixture has a header-only registry and no app/ at all: the
    // reverse check must not invent a requirement for a dir that is absent.
    expect(validateCriticalFlows(rootDir: fx('empty')), isEmpty);
  });
}
