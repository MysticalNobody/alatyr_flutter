import 'package:test/test.dart';

import '../tool/src/purity_checker.dart';

// Canned `dart pub deps --json` fixtures, trimmed to the fields the checker
// actually reads (name + kind + dependencies on each packages[] entry).
// Shape verified against a real `fvm dart pub deps --json` run at the repo
// root and against a real Flutter workspace (see task-7-report.md).

const String _cleanJson = '''
{
  "root": "alatyr_workspace",
  "packages": [
    {"name": "app_core", "kind": "root", "dependencies": ["collection"]},
    {"name": "collection", "kind": "transitive", "dependencies": []}
  ],
  "sdks": []
}
''';

const String _violatingJson = '''
{
  "root": "alatyr_workspace",
  "packages": [
    {"name": "app_core", "kind": "root", "dependencies": ["shared_preferences"]},
    {
      "name": "shared_preferences",
      "kind": "transitive",
      "dependencies": ["flutter"]
    },
    {"name": "flutter", "kind": "transitive", "dependencies": []}
  ],
  "sdks": []
}
''';

void main() {
  test('clean case: pure package reaches only pure-dart deps', () {
    final violations = purityViolations(
      pubDepsJson: _cleanJson,
      purePackages: {'app_core'},
    );
    expect(violations, isEmpty);
  });

  test('violating case: message names the shortest path to flutter', () {
    final violations = purityViolations(
      pubDepsJson: _violatingJson,
      purePackages: {'app_core'},
    );
    expect(violations, hasLength(1));
    expect(
      violations.single,
      contains('app_core -> shared_preferences -> flutter'),
    );
  });

  test('shortest path is picked when multiple routes reach flutter', () {
    // app_core -> a -> flutter (length 3)
    // app_core -> b -> c -> flutter (length 4)
    // The shorter route must win the reported message.
    const json = '''
    {
      "root": "alatyr_workspace",
      "packages": [
        {"name": "app_core", "kind": "root", "dependencies": ["a", "b"]},
        {"name": "a", "kind": "transitive", "dependencies": ["flutter"]},
        {"name": "b", "kind": "transitive", "dependencies": ["c"]},
        {"name": "c", "kind": "transitive", "dependencies": ["flutter"]},
        {"name": "flutter", "kind": "transitive", "dependencies": []}
      ],
      "sdks": []
    }
    ''';
    final violations = purityViolations(
      pubDepsJson: json,
      purePackages: {'app_core'},
    );
    expect(violations, hasLength(1));
    expect(violations.single, contains('app_core -> a -> flutter'));
  });

  test('pure package missing from JSON fails loud (fail closed)', () {
    const json = '''
    {
      "root": "alatyr_workspace",
      "packages": [
        {"name": "collection", "kind": "transitive", "dependencies": []}
      ],
      "sdks": []
    }
    ''';
    final violations = purityViolations(
      pubDepsJson: json,
      purePackages: {'app_core'},
    );
    expect(violations, hasLength(1));
    expect(violations.single, contains('app_core'));
  });

  test('multiple pure packages: clean and violating are both reported', () {
    const json = '''
    {
      "root": "alatyr_workspace",
      "packages": [
        {"name": "app_core", "kind": "root", "dependencies": ["collection"]},
        {"name": "collection", "kind": "transitive", "dependencies": []},
        {
          "name": "app_config",
          "kind": "root",
          "dependencies": ["shared_preferences"]
        },
        {
          "name": "shared_preferences",
          "kind": "transitive",
          "dependencies": ["flutter"]
        },
        {"name": "flutter", "kind": "transitive", "dependencies": []}
      ],
      "sdks": []
    }
    ''';
    final violations = purityViolations(
      pubDepsJson: json,
      purePackages: {'app_core', 'app_config'},
    );
    expect(violations, hasLength(1));
    expect(
      violations.single,
      contains('app_config -> shared_preferences -> flutter'),
    );
  });
}
