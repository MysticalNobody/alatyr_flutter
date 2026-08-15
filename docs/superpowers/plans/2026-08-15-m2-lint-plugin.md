# M2 — Lint Plugin + Gate Evolution: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** IDE-time enforcement of the architecture via a first-party analyzer plugin (`lints/`), integration-proven for all six rules, folded into the gate; plus the carried-over resolution-based purity check.

**Architecture:** Three-layer plugin (pure decision functions → thin AST-adapter rules → `Plugin` registration), graph-driven from `docs/reference/package_graph.yaml` (no hardcoded rule lists — spec §6), NOT a workspace member (decouples the analyzer-14 pin from the app's future codegen stack). The deterministic scanners remain the enforcement floor.

**Tech Stack:** `analysis_server_plugin 0.3.20` (EXACT pin — see Task 1), `analyzer ^14.1.0`, `analyzer_testing ^0.3.4`, Dart 3.12.2 via fvm.

**Spec:** `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` §6, §16-M2. **Carryover:** `docs/superpowers/plans/m2-carryover.md` (M2 section — this plan closes it).

## Global Constraints

- English only in every shipped file; all diagnostic messages English.
- Rule names/codes: `alatyr_boundary_import`, `alatyr_banned_dependency`, `alatyr_pure_core`, `alatyr_one_widget_per_file`, `alatyr_no_widget_returning_function`, `alatyr_no_nested_ternary`. All severity WARNING (analyze exits non-zero on warnings → CI gates without error escalation, which would trigger `unrecognized_error_code`). All six registered via `registry.registerWarningRule` (on by default). No dispose-fields rule (not in spec — YAGNI).
- **No hardcoded rule lists**: banned packages and pure packages come from `package_graph.yaml` via the plugin's own loader. Divergence from the reference implementation is deliberate (spec §6: one source, three consumers).
- `lints/` is NOT in the root `workspace:` list; root analysis excludes `lints/**`; `lints/pubspec.lock` untracked (the analysis server's synthetic package runs its own `pub upgrade` — the pin must live in the version constraint, not a lockfile).
- Plugin degrades gracefully: missing/broken graph → rules silently disabled for that tree (never crash the analyzer host). The strict loader in `tool/` remains the loud one.
- The gate's scanner stages stay authoritative; every plugin stage runs under `run_guarded` wall-clock timeouts (plugin hosts have a hang history: asp ≤0.3.19 + sdk#63538; 0.3.20 fixed it — the guard is insurance). Known upstream caveat sdk#63787: one-shot `flutter analyze` may miss plugin diagnostics — irrelevant to gate correctness because scanners are the floor; record in comments.
- Verified API reference (working skeleton + passing tests from the research pass, consult for exact imports/signatures): `/private/tmp/claude-501/-Users-nikitakhilobok-Documents-projects-my-alatyr-flutter/88c91244-82be-424a-aa0a-981223de147d/scratchpad/e2e/my_lints/`.
- TDD; conventional commits + trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; `fvm dart format` clean before every commit; never push.
- Work on branch `feat/m2-lint-plugin` (from main).

---

### Task 1: lints package skeleton + graph loading

**Files:**
- Create: `lints/pubspec.yaml`, `lints/analysis_options.yaml`, `lints/lib/src/graph/package_graph.dart`, `lints/lib/src/graph/graph_loader.dart`, `lints/lib/src/graph/path_resolver.dart`
- Test: `lints/test/package_graph_test.dart`, `lints/test/path_resolver_test.dart`

**Interfaces:**
- Produces (Tasks 2–4 consume): `PackageGraph { Map<String,String> kinds /* name→kind */; Map<String,List<String>> allowed; Set<String> allowsAll /* names with sentinel */; Map<String,String> banned /* name→reason */; Set<String> pure; }` with `static PackageGraph? tryParse(String yamlSource)` (null on ANY structural problem — graceful); `GraphLoader.instance.graphFor(String filePath) -> PackageGraph?` (walk up ≤40 dirs to the first dir containing `docs/reference/package_graph.yaml`; cache per root + dirname→root memo; errors cache null; `clearForTesting()`); `String? graphKeyForPath({required String filePath, required PackageGraph graph})` — normalize `\` → `/`, split; first `packages` segment whose next segment is in `graph.kinds` → that name; else if any segment `app` and the graph has exactly one entry of kind `app_root` → that entry's name; else null.

- [ ] **Step 1: Package skeleton**

`lints/pubspec.yaml`:

```yaml
name: alatyr_lints
description: First-party analyzer plugin enforcing the Alatyr architecture.
publish_to: none
environment:
  sdk: ^3.12.0
# EXACT pin. The analysis server materializes plugins into a synthetic
# package and runs its own `pub upgrade`; a lockfile cannot hold the
# version, so the constraint IS the pin. 0.3.20 fixed the plugin-host
# hang (dart-lang/sdk#63538) present in 0.3.15-0.3.19.
dependencies:
  analysis_server_plugin: 0.3.20
  analyzer: ^14.1.0
  path: ^1.9.0
  yaml: ^3.1.2
dev_dependencies:
  analyzer_testing: ^0.3.4
  test: ^1.25.0
  test_reflective_loader: ^0.2.2
```

`lints/analysis_options.yaml`:

```yaml
analyzer:
  exclude:
    - test/fixtures/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

- [ ] **Step 2: Failing tests for graph parse + path resolver**

`lints/test/package_graph_test.dart`:

```dart
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
}
```

`lints/test/path_resolver_test.dart`:

```dart
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
          filePath: '/r/packages/app_core/lib/src/x.dart', graph: g),
      'app_core',
    );
  });

  test('app/ resolves to the single app_root package', () {
    expect(graphKeyForPath(filePath: '/r/app/lib/main.dart', graph: g),
        'alatyr_starter');
  });

  test('packages wins over a later app segment', () {
    expect(
      graphKeyForPath(
          filePath: '/r/packages/app_core/lib/app/y.dart', graph: g),
      'app_core',
    );
  });

  test('unknown locations resolve to null', () {
    expect(graphKeyForPath(filePath: '/r/tool/x.dart', graph: g), isNull);
    expect(
        graphKeyForPath(
            filePath: '/r/packages/ghost/lib/g.dart', graph: g),
        isNull);
  });

  test('windows separators are normalized', () {
    expect(
      graphKeyForPath(
          filePath: r'C:\r\packages\app_core\lib\x.dart', graph: g),
      'app_core',
    );
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd lints && fvm dart pub get && fvm dart test`
Expected: FAIL — types not defined. (Resolution itself validates the 0.3.20 pin on this toolchain.)

- [ ] **Step 4: Implement**

`lints/lib/src/graph/package_graph.dart`:

```dart
import 'package:yaml/yaml.dart';

const String _allMembersSentinel = '*_all_members';

/// Parsed view of docs/reference/package_graph.yaml for IDE-time rules.
/// Tolerant by design: [tryParse] returns null on any structural problem —
/// a broken graph must degrade rules, never crash the analyzer host. The
/// strict, loud loader lives in tool/src/graph.dart.
final class PackageGraph {
  const PackageGraph({
    required this.kinds,
    required this.allowed,
    required this.allowsAll,
    required this.banned,
    required this.pure,
  });

  final Map<String, String> kinds;
  final Map<String, List<String>> allowed;
  final Set<String> allowsAll;
  final Map<String, String> banned;
  final Set<String> pure;

  static PackageGraph? tryParse(String yamlSource) {
    try {
      final root = loadYaml(yamlSource);
      if (root is! YamlMap) return null;
      final rawPackages = root['packages'];
      if (rawPackages is! YamlMap) return null;

      final kinds = <String, String>{};
      final allowed = <String, List<String>>{};
      final allowsAll = <String>{};
      for (final entry in rawPackages.entries) {
        final name = entry.key.toString();
        final value = entry.value;
        if (value is! YamlMap) return null;
        kinds[name] = value['kind'].toString();
        final deps = value['allowed_dependencies'];
        if (deps is String && deps == _allMembersSentinel) {
          allowsAll.add(name);
          allowed[name] = const [];
        } else if (deps is YamlList) {
          allowed[name] = [for (final d in deps) d.toString()];
        } else {
          allowed[name] = const [];
        }
      }
      final banned = <String, String>{
        if (root['banned_packages'] is YamlMap)
          for (final e in (root['banned_packages'] as YamlMap).entries)
            e.key.toString(): e.value.toString(),
      };
      final pure = <String>{
        if (root['pure_dart_packages'] is YamlList)
          for (final p in root['pure_dart_packages'] as YamlList) p.toString(),
      };
      return PackageGraph(
        kinds: kinds,
        allowed: allowed,
        allowsAll: allowsAll,
        banned: banned,
        pure: pure,
      );
    } on Object {
      return null;
    }
  }
}
```

`lints/lib/src/graph/graph_loader.dart`:

```dart
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
          File(p.join(root, _graphRelativePath)).readAsStringSync());
    } on Object {
      return null;
    }
  }

  void clearForTesting() {
    _rootByDirectory.clear();
    _graphByRoot.clear();
  }
}
```

`lints/lib/src/graph/path_resolver.dart`:

```dart
import 'package_graph.dart';

/// Maps an absolute file path to its package-graph key, or null when the
/// file lives outside any graphed package (tool/, root test/, ...).
String? graphKeyForPath({
  required String filePath,
  required PackageGraph graph,
}) {
  final segments = filePath.replaceAll(r'\', '/').split('/');
  for (var i = 0; i < segments.length - 1; i++) {
    if (segments[i] == 'packages' && graph.kinds.containsKey(segments[i + 1])) {
      return segments[i + 1];
    }
  }
  if (segments.contains('app')) {
    final appRoots =
        graph.kinds.entries.where((e) => e.value == 'app_root').toList();
    if (appRoots.length == 1) return appRoots.single.key;
  }
  return null;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm dart test` (in `lints/`) — PASS (7 tests). `fvm dart analyze .` clean.

- [ ] **Step 6: Commit**

```bash
git add lints/ && git commit -m "feat(lints): package skeleton, tolerant graph loading, path resolver"
```

---

### Task 2: Pure decision logic (checkers + style predicates)

**Files:**
- Create: `lints/lib/src/graph/boundary_checker.dart`, `lints/lib/src/rules/style_predicates.dart`
- Test: `lints/test/boundary_checker_test.dart`, `lints/test/style_predicates_test.dart`

**Interfaces:**
- Consumes: `PackageGraph` (Task 1).
- Produces (Tasks 3–4 consume; all pure — zero analyzer/dart:io imports):
  `String? packageNameFromUri(String uri)`;
  `String? boundaryViolation({required String fromKey, required String importedPackage, required PackageGraph graph})`;
  `String? bannedViolation({required String importedPackage, required PackageGraph graph})`;
  `String? pureCoreViolation({required String fromKey, required String importUri, required PackageGraph graph})`;
  `bool isPublicWidgetClass({required String className, required String? superclassName})`;
  `bool isDisallowedWidgetReturn({required String name, required String? returnTypeName, required bool isAccessor})`.

- [ ] **Step 1: Failing tests**

`lints/test/boundary_checker_test.dart`:

```dart
import 'package:alatyr_lints/src/graph/boundary_checker.dart';
import 'package:alatyr_lints/src/graph/package_graph.dart';
import 'package:test/test.dart';

const _graph = '''
package_kinds: [base, feature_api, feature_impl, app_root]
banned_packages:
  get_it: "manual constructor DI (spec section 5)"
  riverpod: "bloc is the canonical state management"
pure_dart_packages: [app_core]
packages:
  app_core: { kind: base, allowed_dependencies: [] }
  design_system: { kind: base, allowed_dependencies: [app_core] }
  feature_settings_api: { kind: feature_api, allowed_dependencies: [app_core] }
  feature_settings:
    { kind: feature_impl,
      allowed_dependencies: [feature_settings_api, app_core, design_system] }
  feature_home:
    { kind: feature_impl, allowed_dependencies: [app_core] }
  alatyr_starter: { kind: app_root, allowed_dependencies: "*_all_members" }
''';

void main() {
  final g = PackageGraph.tryParse(_graph)!;

  group('packageNameFromUri', () {
    test('extracts package name', () {
      expect(packageNameFromUri('package:app_core/src/x.dart'), 'app_core');
    });
    test('null for dart: and relative URIs', () {
      expect(packageNameFromUri('dart:async'), isNull);
      expect(packageNameFromUri('src/local.dart'), isNull);
    });
  });

  group('boundaryViolation', () {
    String? check(String from, String to) =>
        boundaryViolation(fromKey: from, importedPackage: to, graph: g);

    test('impl importing sibling impl is a violation', () {
      expect(check('feature_home', 'feature_settings'),
          allOf(contains('feature_home'), contains('feature_settings')));
    });
    test('impl importing api is allowed', () {
      expect(check('feature_settings', 'feature_settings_api'), isNull);
    });
    test('app_root (sentinel) may import anything graphed', () {
      expect(check('alatyr_starter', 'feature_settings'), isNull);
    });
    test('self-import and external packages are ignored', () {
      expect(check('app_core', 'app_core'), isNull);
      expect(check('app_core', 'collection'), isNull);
    });
  });

  group('bannedViolation', () {
    test('banned package fires with reason', () {
      expect(bannedViolation(importedPackage: 'get_it', graph: g),
          contains('manual constructor DI'));
    });
    test('canonical stack does not fire', () {
      expect(bannedViolation(importedPackage: 'flutter_bloc', graph: g),
          isNull);
    });
  });

  group('pureCoreViolation', () {
    String? check(String from, String uri) =>
        pureCoreViolation(fromKey: from, importUri: uri, graph: g);

    test('pure package importing flutter* fires', () {
      expect(check('app_core', 'package:flutter/widgets.dart'), isNotNull);
      expect(check('app_core', 'package:flutter_bloc/flutter_bloc.dart'),
          isNotNull);
    });
    test('pure package importing dart:ui fires', () {
      expect(check('app_core', 'dart:ui'), isNotNull);
      expect(check('app_core', 'dart:ui_web'), isNotNull);
    });
    test('non-pure package is exempt; pure importing pure deps is fine', () {
      expect(check('design_system', 'package:flutter/widgets.dart'), isNull);
      expect(check('app_core', 'dart:async'), isNull);
    });
  });
}
```

`lints/test/style_predicates_test.dart`:

```dart
import 'package:alatyr_lints/src/rules/style_predicates.dart';
import 'package:test/test.dart';

void main() {
  group('isPublicWidgetClass', () {
    test('public StatelessWidget/StatefulWidget subclass', () {
      expect(
          isPublicWidgetClass(
              className: 'HomeCard', superclassName: 'StatelessWidget'),
          isTrue);
      expect(
          isPublicWidgetClass(
              className: 'HomePage', superclassName: 'StatefulWidget'),
          isTrue);
    });
    test('private or non-widget superclass', () {
      expect(
          isPublicWidgetClass(
              className: '_HomeCard', superclassName: 'StatelessWidget'),
          isFalse);
      expect(isPublicWidgetClass(className: 'HomeCard', superclassName: 'Bloc'),
          isFalse);
      expect(isPublicWidgetClass(className: 'HomeCard', superclassName: null),
          isFalse);
    });
  });

  group('isDisallowedWidgetReturn', () {
    test('bare Widget return fires', () {
      expect(
          isDisallowedWidgetReturn(
              name: 'buildHeader', returnTypeName: 'Widget', isAccessor: false),
          isTrue);
    });
    test('build(), accessors, and non-bare-Widget types are exempt', () {
      expect(
          isDisallowedWidgetReturn(
              name: 'build', returnTypeName: 'Widget', isAccessor: false),
          isFalse);
      expect(
          isDisallowedWidgetReturn(
              name: 'header', returnTypeName: 'Widget', isAccessor: true),
          isFalse);
      expect(
          isDisallowedWidgetReturn(
              name: 'items',
              returnTypeName: 'PreferredSizeWidget',
              isAccessor: false),
          isFalse);
      expect(
          isDisallowedWidgetReturn(
              name: 'x', returnTypeName: null, isAccessor: false),
          isFalse);
    });
  });
}
```

- [ ] **Step 2: Run to verify FAIL**, then implement:

`lints/lib/src/graph/boundary_checker.dart`:

```dart
import 'package_graph.dart';

String? packageNameFromUri(String uri) {
  if (!uri.startsWith('package:')) return null;
  final name = uri.substring('package:'.length).split('/').first;
  return name.isEmpty ? null : name;
}

String? boundaryViolation({
  required String fromKey,
  required String importedPackage,
  required PackageGraph graph,
}) {
  if (importedPackage == fromKey) return null;
  if (!graph.kinds.containsKey(importedPackage)) return null;
  if (graph.allowsAll.contains(fromKey)) return null;
  if ((graph.allowed[fromKey] ?? const []).contains(importedPackage)) {
    return null;
  }
  final importedKind = graph.kinds[importedPackage];
  return "'$fromKey' must not import '$importedPackage' ($importedKind). "
      'Cross-feature dependencies go only through *_api packages; only the '
      'app root assembles implementations. Source of truth: '
      'docs/reference/package_graph.yaml.';
}

String? bannedViolation({
  required String importedPackage,
  required PackageGraph graph,
}) {
  final reason = graph.banned[importedPackage];
  if (reason == null) return null;
  return "'$importedPackage' is banned without an ADR - $reason.";
}

String? pureCoreViolation({
  required String fromKey,
  required String importUri,
  required PackageGraph graph,
}) {
  if (!graph.pure.contains(fromKey)) return null;
  final pkg = packageNameFromUri(importUri);
  final flutterPackage = pkg != null && pkg.startsWith('flutter');
  final uiLibrary = importUri.startsWith('dart:ui');
  if (!flutterPackage && !uiLibrary) return null;
  return "pure Dart package '$fromKey' must not import "
      "'${pkg ?? importUri}' (Flutter/UI dependency).";
}
```

`lints/lib/src/rules/style_predicates.dart`:

```dart
const Set<String> _widgetBaseNames = {'StatelessWidget', 'StatefulWidget'};

bool isPublicWidgetClass({
  required String className,
  required String? superclassName,
}) =>
    !className.startsWith('_') && _widgetBaseNames.contains(superclassName);

bool isDisallowedWidgetReturn({
  required String name,
  required String? returnTypeName,
  required bool isAccessor,
}) =>
    !isAccessor && name != 'build' && returnTypeName == 'Widget';
```

- [ ] **Step 3: PASS** (`fvm dart test` in lints/ — 19 tests total), analyze clean, format clean.

- [ ] **Step 4: Commit**

```bash
git add lints/ && git commit -m "feat(lints): pure decision logic for graph and style rules"
```

---

### Task 3: Plugin registration + three architecture rules

**Files:**
- Create: `lints/lib/main.dart`, `lints/lib/src/rules/boundary_import_rule.dart`, `lints/lib/src/rules/banned_dependency_rule.dart`, `lints/lib/src/rules/pure_core_rule.dart`
- Test: `lints/test/rules/architecture_rules_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2 exports; the verified 0.3.20 API (see Global Constraints skeleton path): `Plugin`/`PluginRegistry` from `package:analysis_server_plugin/plugin.dart` + `registry.dart`; `AnalysisRule`, `RuleVisitorRegistry`, `RuleContext` from `package:analyzer/analysis_rule/...`; `LintCode(..., severity: DiagnosticSeverity.WARNING)`; `rule.reportAtNode(node, arguments: [...])`; `context.definingUnit.file.path`.
- Produces: `final plugin = AlatyrLintsPlugin();` in `lib/main.dart` registering ALL six rules via `registerWarningRule` (Task 4 adds the style three — register them here already as forward declarations is NOT allowed; instead Task 4 EDITS main.dart to add its three registrations).

**Rule semantics (shared adapter flow for all three):** on each `ImportDirective`: `uri.stringValue` → if null, return; `GraphLoader.instance.graphFor(context.definingUnit.file.path)` → null ⇒ return (silent degrade); banned check needs no fromKey; boundary/pure need `graphKeyForPath` → null ⇒ return. Report at the directive node with the violation string as `{0}`. No test-directory exemption for these three (imports in tests are still architecture).

- [ ] **Step 1: Failing rule tests** using `analyzer_testing` (`AnalysisRuleTest`, `assertDiagnostics`/`assertNoDiagnostics`; consult the verified skeleton for the exact harness shape — `rule = ...` in `setUp()` before `super.setUp()`). The harness analyzes in-memory files; the GraphLoader needs a real graph file on disk — write the test graph + a fake `docs/reference/package_graph.yaml` into the harness's file system root (AnalysisRuleTest exposes a resource-provider root; if wiring the on-disk graph into the in-memory provider proves unsupported, test the adapters via a physical temp dir mini-project analyzed with `dart analyze` instead — decide and document; the integration fixture in Task 5 covers the end-to-end path regardless). Minimum cases: banned import fires with reason; boundary violation fires for impl→impl; api import passes; pure-core fires on flutter import from a pure package; file outside any package (no key) produces no diagnostics; missing graph produces no diagnostics.

- [ ] **Step 2: Implement the three rules + plugin.** Message shapes:

```dart
// boundary_import_rule.dart (pattern for all three)
static const LintCode _code = LintCode(
  'alatyr_boundary_import',
  'Architecture boundary violation: {0}',
  severity: DiagnosticSeverity.WARNING,
);
```

`alatyr_banned_dependency` message: `'Banned dependency: {0}'`. `alatyr_pure_core` message: `'Core purity violation: {0}'`. `lints/lib/main.dart`:

```dart
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/banned_dependency_rule.dart';
import 'src/rules/boundary_import_rule.dart';
import 'src/rules/pure_core_rule.dart';

final plugin = AlatyrLintsPlugin();

class AlatyrLintsPlugin extends Plugin {
  @override
  String get name => 'alatyr_lints';

  @override
  void register(PluginRegistry registry) {
    registry
      ..registerWarningRule(BoundaryImportRule())
      ..registerWarningRule(BannedDependencyRule())
      ..registerWarningRule(PureCoreRule());
  }
}
```

- [ ] **Step 3: PASS, analyze clean, format clean. Commit**

```bash
git add lints/ && git commit -m "feat(lints): plugin registration + architecture rules"
```

---

### Task 4: Three style rules

**Files:**
- Create: `lints/lib/src/rules/one_widget_per_file_rule.dart`, `lints/lib/src/rules/no_widget_returning_function_rule.dart`, `lints/lib/src/rules/no_nested_ternary_rule.dart`
- Modify: `lints/lib/main.dart` (add three `registerWarningRule` lines)
- Test: `lints/test/rules/style_rules_test.dart`

**Rule semantics (purely syntactic, no type resolution — a local `class StatelessWidget {}` stub triggers them, which the fixture exploits):**
- `alatyr_one_widget_per_file`: test files EXEMPT (`context.isInTestDirectory` checked in `registerNodeProcessors` — register no visitor). CompilationUnit visitor collects top-level public classes whose superclass simple name is StatelessWidget/StatefulWidget (via `isPublicWidgetClass`); if >1, report on the 2nd+ class name tokens, `{0}` = comma-joined list of all. Message: `'File declares more than one public widget class ({0}). Keep one public widget per file; private (_Foo) helpers are fine.'`
- `alatyr_no_widget_returning_function`: test files EXEMPT. Every MethodDeclaration / top-level FunctionDeclaration where `isDisallowedWidgetReturn` (bare `Widget` return lexeme, not `build`, not accessor). Report at name token, `{0}` = name. Message: `"'{0}' returns Widget. Extract a widget class instead (build() is exempt)."`
- `alatyr_no_nested_ternary`: NO test exemption. ConditionalExpression whose parent is a ConditionalExpression AND is the parent's thenExpression or elseExpression; report the INNER node. Message: `'Nested ternary. Use a switch expression, if/else, or extract a method.'`

- [ ] **Step 1: Failing tests** (AnalysisRuleTest; style rules need no graph — plain in-memory sources). Cases: two public widgets → 1 diagnostic on the second; private second widget → clean; `Widget buildHeader()` fires / `Widget build()` clean / getter clean; nested-in-else fires on inner / ternary-in-condition clean; test-directory exemption for the two widget rules (harness `isInTestDirectory` toggle — consult analyzer_testing API; if not togglable, cover exemption in the integration fixture and note it).

- [ ] **Step 2: Implement + register in main.dart. PASS, analyze, format. Commit**

```bash
git add lints/ && git commit -m "feat(lints): style rules (one-widget, widget-return, nested-ternary)"
```

---

### Task 5: Violations fixture + integration check (all six rules)

**Files:**
- Create: `lints/test/fixtures/violations/` — a standalone mini-workspace: `pubspec.yaml` (name `violations_fixture`, publish_to none, sdk ^3.12.0, ZERO deps), `analysis_options.yaml`, `docs/reference/package_graph.yaml` (mini graph), `packages/pure_pkg/lib/impure.dart`, `packages/feat_a/lib/a.dart`, `packages/feat_b/lib/stubs.dart` + `lib/two_widgets.dart` + `lib/widget_function.dart` + `lib/nested_ternary.dart`
- Create: `lints/test/integration_check.sh`

**Design:** unlike the reference implementation, the fixture ships its own `docs/reference/package_graph.yaml`, so the GraphLoader resolves it as a repo root and ALL SIX rules are integration-proven (mini graph: `pure_pkg` pure base with `allowed_dependencies: []`; `feat_a`, `feat_b` feature_impl with `[]`; banned_packages `{get_it: "manual constructor DI"}`). Violation files (each engineered for exactly one hit of its rule; unresolved `package:` imports are fine — rules are syntactic, and the analyzer's own `uri_does_not_exist` errors don't collide with the grep):
- `packages/pure_pkg/lib/impure.dart`: `import 'package:flutter/widgets.dart';` → 1× `alatyr_pure_core`.
- `packages/feat_a/lib/a.dart`: `import 'package:feat_b/stubs.dart';` → 1× `alatyr_boundary_import`; plus `import 'package:get_it/get_it.dart';` → 1× `alatyr_banned_dependency`.
- `packages/feat_b/lib/stubs.dart`: local `class Widget {}`, `class StatelessWidget {}` stubs (keeps the fixture dependency-free).
- `two_widgets.dart` (imports stubs relatively): two public StatelessWidget subclasses → 1× `alatyr_one_widget_per_file`.
- `widget_function.dart`: `Widget buildHeader() => Widget();` (fires) + `Widget build() => Widget();` (control) → 1× `alatyr_no_widget_returning_function`.
- `nested_ternary.dart`: `final v = a ? 1 : b ? 2 : 3;` shape → 1× `alatyr_no_nested_ternary`.

Fixture `analysis_options.yaml`: `plugins: alatyr_lints: path: <relative to the copied plugin root>` (integration_check.sh copies plugin + fixture into a fresh mktemp dir preserving relative geometry — forces fresh synthetic-package resolution, dodging stale plugin-host caches).

- [ ] **Step 1: Write fixture + script.** `integration_check.sh` (bash, `set -uo pipefail`, NOT `-e` — analyze exits non-zero by design): mktemp scratch; copy `lints/pubspec.yaml` + `lints/lib/` to `$SCRATCH/alatyr_lints/`, fixture to `$SCRATCH/alatyr_lints/test/fixtures/violations/`; fvm-first dart helper; `pub get` in the fixture; `log="$(dart analyze <fixture dir> 2>&1)"`; `expect <rule> <count>` via `grep -c`; assert exactly 1 for each of the SIX rule names; on mismatch print full log, exit 1.

- [ ] **Step 2: Run it** — `bash lints/test/integration_check.sh` → all six `1/1`, OK. First run is the moment of truth for the whole plugin stack on 3.12.2; if a rule doesn't fire end-to-end, debug HERE (this is the task's RED→GREEN).

- [ ] **Step 3: Commit**

```bash
git add lints/test && git commit -m "test(lints): six-rule violations fixture + integration check"
```

---

### Task 6: Root wiring + gate stages

**Files:**
- Modify: `analysis_options.yaml` (root), `tool/checks.sh`

- [ ] **Step 1: Root `analysis_options.yaml`** — add:

```yaml
plugins:
  alatyr_lints:
    path: ./lints
analyzer:
  exclude:
    - lints/**
    - test/fixtures/workspaces/imports/packages/**
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

(Merge with the existing exclude list — keep current entries. Restart note: analysis server must restart after `plugins:` changes; put a one-line comment.)

- [ ] **Step 2: Gate stages** in `tool/checks.sh`, full tier, after the per-package stage (the declared M2 seam):

```bash
echo "==> Lint plugin (isolated analyze + unit tests)"
( cd "$ROOT_DIR/lints"
  run_dart pub get
  run_dart analyze --fatal-infos .
  run_dart test )

echo "==> Lint plugin integration fixture"
run_guarded "$CHECKS_ANALYZE_TIMEOUT" bash "$ROOT_DIR/lints/test/integration_check.sh"
```

(Plugin hosts run in child processes with a hang history — the integration run gets an explicit wall-clock guard; the analyze/test inside the subshell are already guarded via `run_dart`.)

- [ ] **Step 3: Verify** — full `tool/checks.sh` → OK including both new stages (note the cold-run cost ≈ +15 s for synthetic-package resolution — needs network; acceptable, CI has it). NEGATIVE: temporarily add a second public widget class to the fixture's `two_widgets.dart` expectations… simpler negative: change `expect alatyr_no_nested_ternary 1` to `2` in a scratch copy of the script and confirm it fails loudly — then discard. Also verify root `fvm dart analyze --fatal-infos .` now reports plugin diagnostics as part of toolchain-analyze (it may — plugin loads for root analysis; if the root analyze picks up plugin warnings from `test/fixtures/workspaces/imports` trees, extend the exclude list accordingly and document).

- [ ] **Step 4: Commit**

```bash
git add analysis_options.yaml tool/checks.sh && git commit -m "feat(gate): wire lint plugin + integration fixture stages"
```

---

### Task 7: Carryover — resolution-based purity check

**Files:**
- Create: `tool/src/purity_checker.dart`, `tool/verify_purity.dart`
- Modify: `tool/checks.sh` (one stage), `docs/superpowers/plans/m2-carryover.md` (remove closed items)
- Test: `test/purity_checker_test.dart`

**Interfaces:**
- Produces: `List<String> purityViolations({required String pubDepsJson, required Set<String> purePackages})` — pure function over `dart pub deps --json` output: build the name→deps adjacency from `packages[].dependencies`, BFS from each pure package, violation if the closure contains `flutter` (message names the pure package and the shortest offending path, e.g. `app_core -> shared_preferences -> flutter`). CLI `dart run tool/verify_purity.dart` runs `dart pub deps --json` itself (requires a resolved workspace) and exits 0/1.
- Gate: full tier only (needs resolution — NOT in `--fast`), stage after codegen: `echo "==> Transitive purity (resolved graph)"` + `run_dart run tool/verify_purity.dart`. Pure list comes from the strict graph loader (`tool/src/graph.dart`).

- [ ] **Step 1: Failing test** — canned `pub deps --json` fixtures as inline strings: clean case (app_core → collection only); violating case (app_core → shared_preferences → flutter) asserting the path appears in the message; pure package absent from JSON → violation (fail loud, not silent).
- [ ] **Step 2: Implement; PASS**; real-repo run → `Transitive purity: OK`; wire the gate stage; full gate green.
- [ ] **Step 3: Update `m2-carryover.md`** — delete the two closed M2 items (purity check, lint stages), keep M3 tripwires; add line `sdk#63787: one-shot flutter analyze may miss plugin diagnostics - scanners are the floor (documented in checks.sh comment)`.
- [ ] **Step 4: Commit**

```bash
git add tool/ test/ docs/ && git commit -m "feat(tool): resolution-based transitive purity check (M2 carryover)"
```

---

### Task 8: M2 wrap-up

- [ ] **Step 1:** Clean tree; full `tool/checks.sh` → OK (now 10 stages).
- [ ] **Step 2:** Spec status line → `**Status:** approved; implementation in progress (M2 done)`; mirror in `.ru.md` twin (uncommitted).
- [ ] **Step 3:** Commit `chore: mark M2 complete in spec status`. Controller then runs: final whole-branch review → fix wave if needed → Codex cross-review (`codex review --base main`) → evaluate findings → merge per the M1-established finish flow. Completion report with **Remaining risks** (candidates: plugin cold-start needs network in CI; sdk#63787 flutter-analyze caveat; analyzer_testing harness limitations discovered in Tasks 3–4).

---

## Self-review notes (writing-plans checklist)

- **Spec coverage (M2 slice):** lints/ plugin with 3+3 rules (§6) → T1–T4; violations fixture + integration check (§6, improved: all six rules vs reference's four) → T5; root wiring + gate seam (§6, §16-M2) → T6; carryover purity check → T7. Pin validation (§15 risk 1) → T1 Step 3 + T5's end-to-end run on 0.3.20 (hang fix verified upstream + empirically in research).
- **Type consistency:** `PackageGraph.tryParse` (T1) used by T2 tests and T3 adapters; `graphKeyForPath({filePath, graph})` signature consistent T1↔T3; rule code names match Global Constraints everywhere; `run_guarded`/`run_dart` from M1's common.sh reused as-is.
- **Judgment calls:** graph-driven banned/pure lists (spec-mandated divergence from reference); dispose_fields dropped (not in spec); fixture-with-graph innovation covers architecture rules end-to-end; purity check full-tier-only (fast tier stays resolution-free); AnalysisRuleTest harness uncertainty (graph-on-disk wiring, isInTestDirectory toggle) has explicit fallback paths in T3/T4 — implementers decide and document rather than stall.
