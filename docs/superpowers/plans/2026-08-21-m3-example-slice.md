# M3 — Example Slice: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The worked example feature that crosses every layer — `design_system` → `feature_settings` (bloc + screen) → repository port → `data_local` (drift, codegen) → `app/` wiring through the `feature_settings_api` port — plus `data_secure`, the native app shell with the placeholder identity, the full copyable test-exemplar set, and the four M2 carryover obligations.

**Architecture:** Six new workspace members + the app shell, born graph-first (spec §5 ritual: the graph diff below is the one spec §6 already approved). Feature contract per spec §5: `feature_settings_api` ships contracts only (route spec, key namespace, `SettingsApi` port, failure codes); `feature_settings` exports exactly one factory `createSettingsModule(...)` returning `SettingsModule { routes, api }`; only `app/` constructs implementations (manual constructor DI in `bootstrap/`). Persistence is the single source of truth: the bloc *watches* the repository stream (drift `watchSingleOrNull` emits the current row first, then every change — verified), so `MaterialApp.themeMode` in `app/` is driven by the same stream through the `SettingsApi` port.

**Tech Stack (exact versions resolved on Flutter 3.44.9 / Dart 3.12.2 in the research pass — one shared workspace resolution; freezed 3.2.5 caps `analyzer <11`, which holds drift_dev at 2.34.0 and build_runner at 2.15.1):** drift 2.34.3, drift_dev 2.34.0, drift_flutter 0.3.1 (sqlite3 3.5.2 via Dart hooks), build_runner 2.15.1, freezed 3.2.5 / freezed_annotation 3.1.0, flutter_bloc 9.1.1 (bloc 9.2.1), bloc_test 10.0.0, mocktail 1.0.5, go_router 17.5.0, flutter_secure_storage 11.0.0, patrol_finders 3.6.0, flutter_lints 6.0.0.

**Spec:** `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` §3, §5, §6, §8, §9 (identity), §10, §16-M3. **Carryover:** `docs/superpowers/plans/m2-carryover.md` (M3 section — this plan closes it).

**Verified reference (consult for exact, already-passing code; everything in it ran on the pinned toolchain):** `/private/tmp/claude-501/-Users-dev-Documents-projects-my-alatyr-flutter/274f6fc9-972b-474e-8cfd-9d8077742bfc/scratchpad/m3-research.md` (facts + snippets) and `.../scratchpad/m3sim/` (a full M3-shaped copy of the repo on which `tool/checks.sh` passed end-to-end in 1m26s). If the scratchpad is gone, this plan is self-sufficient — every snippet it needs is inlined below. The snippets were compiled and their tests run during the plan challenge, but they are not all `dart format`-clean as inlined: run `fvm dart format .` after pasting (the `--fast` gate starts with the format check).

## Global Constraints

- English only in every shipped file (code, comments, docs, messages).
- Canonical stack only (spec §5): `flutter_bloc`, `go_router`, manual constructor DI, `drift`, `freezed`, `flutter_secure_storage`, `patrol_finders`, `mocktail`. The banned list in `docs/reference/package_graph.yaml` is authoritative.
- Hard invariants (spec §4): cross-feature deps only via `*_api`; only `app/` depends on feature impls; `app_core`/`app_config` stay pure Dart; runtime secrets only in `data_secure`; generated files (`*.g.dart`, `*.freezed.dart`) are **committed and never hand-edited** — regenerate with `tool/codegen.sh`; every interactive widget carries a `ValueKey` from its feature's key namespace (`SettingsKeys`); widget tests use patrol finders (`$` syntax); test names are the test cases (`'given stored theme is corrupted, settings falls back to system'`).
- Lint plugin rules apply to every member (enforced by the root `dart analyze` stage): one public widget class per file (`StatelessWidget`/`StatefulWidget` subclasses not starting with `_`), no named function/method other than `build` returning `Widget`, no nested ternaries (also in tests).
- `data_local/lib/**` (generated files included) must not contain identifiers matching `token|secret|password|credential` (case-insensitive) — the secret-leak heuristic scans it. Safe names used here: `key`, `value`, `keyValues`.
- Every Flutter member declares `flutter: { sdk: flutter }` explicitly (the checks plan builder classifies by declaration, not by transitive closure) and `resolution: workspace`. Workspace-member deps are declared as `<name>: any`.
- No `pubspec.lock` inside members (root `.gitignore` already ignores them; only `/pubspec.lock` is tracked). The root `pubspec.lock` changes in Task 3 and MUST be committed in the same commit, or the freshness stage fails.
- Commands: `fvm dart` / `fvm flutter` (3.44.9 pinned by `.fvmrc`); `tool/checks.sh --fast` before every commit, full `tool/checks.sh` at the end of every task. `fvm dart format .` clean before every commit.
- TDD; conventional commits + trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; never push.
- Work on branch `feat/m3-example-slice` (from `main`).
- Placeholder identity (spec §9): Dart package `alatyr_starter`, org `dev.alatyr`, bundle id / applicationId `dev.alatyr.starter`, display name `Alatyr Starter`. These tokens may appear only in `app/` (and its native shells), root `pubspec.yaml`, `docs/reference/package_graph.yaml`, `README.md` — never in `packages/`, `lints/`, `tool/`.

---

### Task 1: Gate prep — carryovers that do not need the new packages

**Files:**
- Modify: `pubspec.yaml` (root: `flutter_lints` dev dep), `analysis_options.yaml` (root: lint set include + `**/build/**` exclude)
- Modify: `tool/common.sh`, `tool/codegen.sh`, `tool/checks.sh`
- Modify: `tool/src/import_validator.dart`
- Create: `test/fixtures/workspaces/imports/packages/b/bin/b_cli_check.dart`, `test/fixtures/workspaces/imports/packages/b/example/b_example_check.dart`, `test/fixtures/workspaces/imports/packages/b/integration_test/b_flow_check.dart`
- Test: `test/import_validator_test.dart`

**Interfaces:**
- Produces: `CHECKS_CODEGEN_TIMEOUT` env var (default 600) honoured by `run_dart run build_runner …`; import scanner covering `lib/ bin/ example/ integration_test/ test/` (banned rule in all of them; boundary/purity/secret rules stay `lib/`-only); root analysis context with `flutter_lints` (so the new Flutter members and `app/` need NO `analysis_options.yaml` of their own — a nested one would open a second context without the lint plugin, verified).

- [ ] **Step 1: Create the branch**

```bash
git checkout -b feat/m3-example-slice main
```

- [ ] **Step 2: Root lint set + build exclude**

Root `pubspec.yaml` — add `flutter_lints` to `dev_dependencies` (it depends only on `lints`, no Flutter SDK, so the pure packages stay pure):

```yaml
dev_dependencies:
  flutter_lints: ^6.0.0
  test: ^1.25.0
```

Root `analysis_options.yaml` — add the include at the top (before `plugins:`) and the exclude at the end of the `exclude:` list:

```yaml
# One analysis context for the whole workspace: the lint set, the strict
# language modes and the alatyr_lints plugin below apply to every member and
# to app/. Members MUST NOT ship their own analysis_options.yaml - a nested
# file opens a separate context in which the root `plugins:` is silently
# absent (and re-declaring it there is rejected: plugins_in_inner_options).
include: package:flutter_lints/flutter.yaml
```

```yaml
    # Build outputs (flutter run/build/test, build_runner -o) are not
    # analyzable sources. NOT implicit: only dot-directories are skipped by
    # the analyzer and the formatter; build/ is walked like any other dir.
    - "**/build/**"
```

Run: `fvm dart pub get && fvm dart analyze --fatal-infos .`
Expected: `No issues found!` (tool/ writes via `stdout.writeln`, never `print`; `app_core`'s `ConsoleLogger` already carries `// ignore: avoid_print`). If any info appears, fix it at the source (do not disable rules).

- [ ] **Step 3: Codegen guard + dead build_runner flags**

`tool/common.sh` — after `CHECKS_ANALYZE_TIMEOUT`:

```bash
# build_runner AOT-compiles every builder on a cold .dart_tool/build (~20 s
# per package on an M-series laptop) before it generates anything, and a
# mis-resolved builder can spin forever - same wall-clock guard as tests.
CHECKS_CODEGEN_TIMEOUT="${CHECKS_CODEGEN_TIMEOUT:-600}"
```

`tool/common.sh` — in `_tool`'s `case`, add a `run)` branch before `*)`:

```bash
    run)
      # Only `dart run build_runner ...` gets the guard: the other `dart run`
      # callers (tool/*.dart plan builders and validators) are sub-second,
      # and guarding them would only add a perl/timeout hop per call.
      if [[ "${2:-}" == "build_runner" ]]; then
        run_guarded "$CHECKS_CODEGEN_TIMEOUT" "${cmd[@]}" "$@"
      else
        "${cmd[@]}" "$@"
      fi ;;
```

`tool/codegen.sh` — replace the build line:

```bash
    # build_runner >= 2.15 removed --delete-conflicting-outputs and
    # --low-resources-mode (passing them only prints a warning); conflicting
    # outputs are now always overwritten.
    run_dart run build_runner build )
```

Also fix the stale header comment of `tool/codegen.sh`: build_runner 2.15 grew a `--workspace` flag that builds every member from the root in one run; the per-package plan is kept because it is proven, names the offending package on failure, and is unit-tested (`buildCodegenPlan`). Replace the first comment block with:

```bash
# Workspace-wide codegen, one build_runner invocation per package that
# declares it (plan from tool/checks_workspace.dart --codegen). A plain
# root invocation exits 0 and writes nothing; build_runner 2.15's
# `--workspace` mode would work but the per-package plan names the failing
# package and is unit-tested, so it stays.
```

Run: `bash -c 'source tool/common.sh; set +e; run_guarded 2 sleep 10; echo exit=$?'` (`set +e` because common.sh turns on `set -e`, which would abort before the echo)
Expected: `exit=142` (SIGALRM via the perl fallback on this machine; `124` where `timeout` exists).

- [ ] **Step 4: Make the root analyze stage's role explicit**

`tool/checks.sh` — replace the `echo "==> Toolchain analyze (root)"` line:

```bash
echo "==> Analyze (root context: tool/, test/ and every member - the only stage"
echo "    where alatyr_lints diagnostics are enforced: one-shot flutter analyze"
echo "    never surfaces plugin diagnostics, sdk#63787)"
```

and in `analyze_and_test` use `dart analyze` for BOTH runners (plugin-aware in Flutter members too — verified; `flutter analyze` adds nothing over it):

```bash
  ( cd "$ROOT_DIR/$dir"
    # `dart analyze` (not `flutter analyze`) for every member: the plugin host
    # only loads under dart analyze (sdk#63787), and dart analyze resolves
    # Flutter members fine after the single workspace `pub get`. Tests still
    # go through the matching runner.
    run_dart analyze --fatal-infos .
    if [[ "$has_tests" == "true" ]]; then
      if [[ "$runner" == "flutter" ]]; then run_flutter test --no-pub
      else run_dart test; fi
    fi )
```

Delete the old `# Known upstream caveat sdk#63787 …` comment block inside `analyze_and_test` (its content now lives in the comment above) and, in the file's tier header, change `per-package analyze/test` to `per-package dart-analyze/test`.

- [ ] **Step 5: Failing tests for the widened import scan**

Create the three fixture files (names end in `_check.dart`, NOT `_test.dart` — the root `dart test` stage loads every `*_test.dart` under `test/`, fixtures included, and these import unresolvable packages):

`test/fixtures/workspaces/imports/packages/b/bin/b_cli_check.dart`:
```dart
import 'package:provider/provider.dart';
import 'package:data_local/data_local.dart';
```

`test/fixtures/workspaces/imports/packages/b/example/b_example_check.dart`:
```dart
import 'package:hive/hive.dart';
```

`test/fixtures/workspaces/imports/packages/b/integration_test/b_flow_check.dart`:
```dart
import 'package:riverpod/riverpod.dart';
import 'package:data_local/data_local.dart';
```

In `test/import_validator_test.dart`, replace the final `exact violation count` test with:

```dart
    test('banned rule covers bin/, example/ and integration_test/', () {
      expect(
        v.join('\n'),
        allOf(
          matches(
            RegExp(r'packages/b/bin/b_cli_check\.dart:\d+:\d+: .*provider'),
          ),
          matches(
            RegExp(r'packages/b/example/b_example_check\.dart:\d+:\d+: .*hive'),
          ),
          matches(
            RegExp(
              r'packages/b/integration_test/b_flow_check\.dart:\d+:\d+: .*riverpod',
            ),
          ),
        ),
      );
    });
    test('boundary rule stays lib/-only in the widened scopes', () {
      expect(
        v.join('\n'),
        isNot(
          matches(
            RegExp(
              r'(b_cli_check|b_flow_check)\.dart:\d+:\d+: import of member',
            ),
          ),
        ),
      );
    });
    // 4 original violation cases + 2 (flutter_bloc, dart:ui_web pure-core
    // widening) + 2 (orphan: missing-from-graph + banned mockito)
    // + 3 (banned imports in bin/, example/, integration_test/) = 11.
    test('exact violation count', () => expect(v, hasLength(11)));
```

Run: `fvm dart test test/import_validator_test.dart`
Expected: FAIL — the three new scopes are not scanned yet (count 8, no `provider`/`hive`/`riverpod` hits).

- [ ] **Step 6: Widen the scan**

`tool/src/import_validator.dart` — add above `validateImports`:

```dart
const List<String> _scannedScopes = [
  'lib',
  'bin',
  'example',
  'integration_test',
  'test',
];
```

and replace `for (final scope in ['lib', 'test']) {` with:

```dart
    // Every directory pub treats as Dart source. Boundary, purity and the
    // data_local secret scan stay lib/-only (they govern the package's
    // public/production surface); the banned-package rule applies to all of
    // them - a banned import in a CLI entrypoint, an example, or a patrol
    // flow is just as much a banned dependency as one in lib/.
    for (final scope in _scannedScopes) {
```

Run: `fvm dart test test/import_validator_test.dart`
Expected: PASS (19 tests).

- [ ] **Step 7: Gate + commit**

Run: `tool/checks.sh`
Expected: `OK` (full tier; the root analyze stage now prints the new heading).

```bash
git add -A
git commit -m "feat(gate): root lint set, codegen timeout guard, widened import scan (M3 carryover)"
```

---

### Task 2: Lints carryover — anchor path→graph-key resolution at the discovered root

**Files:**
- Modify: `lints/lib/src/graph/path_resolver.dart`, `lints/lib/src/graph/graph_loader.dart`
- Modify: `lints/lib/src/rules/boundary_import_rule.dart:62-71`, `lints/lib/src/rules/pure_core_rule.dart:61-70`
- Modify (neutral fixture names): `lints/test/path_resolver_test.dart`, `lints/test/boundary_checker_test.dart`, `lints/test/package_graph_test.dart`
- Test: `lints/test/path_resolver_test.dart` (rewritten), `lints/test/graph_loader_test.dart` (one test added)

**Interfaces:**
- Produces: `String? GraphLoader.rootFor(String filePath)` (public; same per-directory cache `graphFor` uses); `String? graphKeyForPath({required String filePath, required PackageGraph graph, required String root})` — only the first segments *below* `root` decide the key.

- [ ] **Step 1: Rewrite the resolver tests (failing)**

Replace `lints/test/path_resolver_test.dart` with:

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

  test('a nested "packages/<key>" dir inside a package does not reattribute', () {
    // Left-to-right this already worked by luck (first match wins); anchored
    // resolution makes it a guarantee: only segments[0..1] below root count.
    expect(
      key('/r/packages/app_core/lib/packages/data_local/x.dart'),
      'app_core',
    );
  });

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
    expect(
      key(r'C:\r\packages\app_core\lib\x.dart', root: 'C:/r'),
      'app_core',
    );
  });
}
```

Add to `lints/test/graph_loader_test.dart` (same `createTempSync` / `try … finally deleteSync` pattern as the existing tests a–e, with a `docs/reference/package_graph.yaml` written under the temp dir and a `lib/x.dart` file below it):

```dart
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
```

(`_outerGraph` is the file's existing valid-graph constant.)

Run: `cd lints && fvm dart test`
Expected: FAIL (compile error: `root` is not a parameter; `rootFor` undefined).

- [ ] **Step 2: Implement**

`lints/lib/src/graph/path_resolver.dart` (full file):

```dart
import 'package_graph.dart';

/// Maps an absolute file path to its package-graph key, or null when the
/// file lives outside any graphed package (tool/, root test/, ...).
///
/// [root] is the repo root that [GraphLoader] discovered for this file (the
/// directory holding docs/reference/package_graph.yaml). Resolution is
/// anchored there: only the FIRST path segments below the root decide the
/// key - `packages/<name>/...` maps to `<name>` when the graph knows it, and
/// `app/...` maps to the single `app_root` entry. Segments above the root
/// (a clone living at `/home/u/app/...` or `/srv/packages/app_core/...`)
/// and segments deeper inside a package (`lib/packages/x/`) never take
/// part, which is what a left-to-right scan of the full path got wrong.
String? graphKeyForPath({
  required String filePath,
  required PackageGraph graph,
  required String root,
}) {
  final file = _normalize(filePath);
  var base = _normalize(root);
  if (!base.endsWith('/')) base = '$base/';
  if (!file.startsWith(base)) return null;
  final segments = file.substring(base.length).split('/');
  if (segments.length < 3) return null; // <dir>/<name>/<file> at minimum
  if (segments[0] == 'packages' && graph.kinds.containsKey(segments[1])) {
    return segments[1];
  }
  if (segments[0] == 'app') {
    final appRoots = graph.kinds.entries
        .where((e) => e.value == 'app_root')
        .toList();
    if (appRoots.length == 1) return appRoots.single.key;
  }
  return null;
}

String _normalize(String path) => path.replaceAll(r'\', '/');
```

`lints/lib/src/graph/graph_loader.dart` — replace `graphFor`:

```dart
  /// The nearest ancestor directory of [filePath] holding
  /// docs/reference/package_graph.yaml, or null. Cached per directory; the
  /// same root [graphFor] loads the graph from, so rules can anchor
  /// path -> graph-key resolution at it.
  String? rootFor(String filePath) {
    final dir = p.dirname(p.normalize(filePath));
    return _rootByDirectory.putIfAbsent(dir, () => _findRoot(dir));
  }

  PackageGraph? graphFor(String filePath) {
    final root = rootFor(filePath);
    if (root == null) return null;
    return _graphByRoot.putIfAbsent(root, () => _load(root));
  }
```

`lints/lib/src/rules/boundary_import_rule.dart` and `lints/lib/src/rules/pure_core_rule.dart` — identical edit at the call site:

```dart
    final path = _context.definingUnit.file.path;
    final root = GraphLoader.instance.rootFor(path);
    final graph = GraphLoader.instance.graphFor(path);
    if (root == null || graph == null) return;

    final fromKey = graphKeyForPath(filePath: path, graph: graph, root: root);
    if (fromKey == null) return;
```

(`banned_dependency_rule.dart` only needs `graphFor` — unchanged.)

- [ ] **Step 3: Neutral fixture names**

In `lints/test/boundary_checker_test.dart` and `lints/test/package_graph_test.dart` replace every `alatyr_starter` with `demo_app` (graph key in the fixture YAML and in the expectations). Rationale: `lints/` is product-neutral by construction and Task 10 adds a root test asserting no identity token appears under `packages/`, `lints/`, `tool/`.

Run: `cd lints && fvm dart analyze --fatal-infos . && fvm dart test && bash test/integration_check.sh`
Expected: analyze clean; all tests pass (66 + new); integration check prints six `1/1 OK` lines. `grep -rn alatyr_starter lints/` → no output.

- [ ] **Step 4: Gate + commit**

Run: `tool/checks.sh` → `OK`.

```bash
git add -A
git commit -m "fix(lints): anchor path resolution at the discovered repo root (M3 carryover)"
```

---

### Task 3: Graph-first — the M3 graph diff, workspace members, package skeletons, app shell

This is spec §5 ritual steps 1–3 for M3: the graph edit comes first; it reproduces spec §6's graph verbatim, which is the human-approved design. All six members and the app are created as compilable skeletons with their FULL dependency sets, so the workspace resolves once (one `pubspec.lock` change) and every later task only adds code.

**Files:**
- Modify: `docs/reference/package_graph.yaml`, `pubspec.yaml` (root workspace list), `.gitignore`, `pubspec.lock` (regenerated)
- Create: `packages/design_system/{pubspec.yaml,lib/design_system.dart}`, `packages/data_local/{pubspec.yaml,lib/data_local.dart}`, `packages/data_secure/{pubspec.yaml,lib/data_secure.dart}`, `packages/feature_settings_api/{pubspec.yaml,lib/feature_settings_api.dart}`, `packages/feature_settings/{pubspec.yaml,lib/feature_settings.dart}`
- Create: `app/` via `flutter create` + identity rewrite; replace `app/pubspec.yaml`, `app/README.md`; delete `app/analysis_options.yaml`, `app/pubspec.lock`

**Interfaces:**
- Produces: the eight-member workspace the rest of the plan fills in; graph keys `design_system`, `data_local`, `data_secure`, `feature_settings_api`, `feature_settings`, `alatyr_starter`.

- [ ] **Step 1: The graph diff**

Replace the `packages:` section of `docs/reference/package_graph.yaml` with (spec §6 verbatim):

```yaml
packages:
  app_core:             { kind: base, allowed_dependencies: [] }
  app_config:           { kind: base, allowed_dependencies: [app_core] }
  design_system:        { kind: base, allowed_dependencies: [app_core] }
  data_local:           { kind: base, allowed_dependencies: [app_core] }
  data_secure:          { kind: base, allowed_dependencies: [app_core] }
  feature_settings_api: { kind: feature_api, allowed_dependencies: [app_core] }
  feature_settings:
    kind: feature_impl
    allowed_dependencies:
      [feature_settings_api, app_core, design_system, data_local]
  alatyr_starter:       { kind: app_root, allowed_dependencies: "*_all_members" }
```

Run: `fvm dart run tool/verify_dependencies.dart`
Expected: FAIL — every new graph entry is missing on disk (the completeness check is loud). This is the "graph before code" moment.

- [ ] **Step 2: Root workspace list + gitignore**

Root `pubspec.yaml`:

```yaml
workspace:
  - packages/app_core
  - packages/app_config
  - packages/design_system
  - packages/data_local
  - packages/data_secure
  - packages/feature_settings_api
  - packages/feature_settings
  - app
```

Root `.gitignore` — append:

```
# Written by `flutter pub get`/`flutter test` into every member whose closure
# has Flutter plugins; self-described "do not check into version control".
.flutter-plugins-dependencies
# Kotlin Gradle plugin session dir (android builds)
.kotlin/
```

- [ ] **Step 3: Member skeletons**

`packages/design_system/pubspec.yaml`:
```yaml
name: design_system
description: Theme, design tokens and base widgets shared by every feature.
publish_to: none
resolution: workspace
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol_finders: ^3.6.0
```
`packages/design_system/lib/design_system.dart`:
```dart
/// Theme, design tokens and base widgets shared by every feature.
library;
```

`packages/data_local/pubspec.yaml`:
```yaml
name: data_local
description: Local persistence - drift database and a key-value DAO.
publish_to: none
resolution: workspace
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  drift: ^2.34.0
  # ^0.3.x pulls the hooks-based sqlite3 3.x; ^0.2.x silently resolves the
  # old sqlite3_flutter_libs stack.
  drift_flutter: ^0.3.1
dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.15.0
  drift_dev: ^2.34.0
```
`packages/data_local/lib/data_local.dart`:
```dart
/// Local persistence: the drift database and its key-value DAO.
library;
```

`packages/data_secure/pubspec.yaml`:
```yaml
name: data_secure
description: Secure storage port and its flutter_secure_storage implementation.
publish_to: none
resolution: workspace
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  app_core: any
  flutter_secure_storage: ^11.0.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  mocktail: ^1.0.5
```
`packages/data_secure/lib/data_secure.dart`:
```dart
/// Secure storage: the port runtime secrets go through, and its adapters.
library;
```

`packages/feature_settings_api/pubspec.yaml`:
```yaml
name: feature_settings_api
description: Contracts of the settings feature - route spec, keys, ports, failure codes.
publish_to: none
resolution: workspace
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
dev_dependencies:
  flutter_test:
    sdk: flutter
```
`packages/feature_settings_api/lib/feature_settings_api.dart`:
```dart
/// Contracts of the settings feature. Implementation lives in feature_settings.
library;
```

`packages/feature_settings/pubspec.yaml`:
```yaml
name: feature_settings
description: Settings feature - theme mode selection (bloc, screen, repository, module).
publish_to: none
resolution: workspace
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  app_core: any
  design_system: any
  data_local: any
  feature_settings_api: any
  flutter_bloc: ^9.1.0
  freezed_annotation: ^3.1.0
  go_router: ^17.5.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^10.0.0
  build_runner: ^2.15.0
  freezed: ^3.2.0
  mocktail: ^1.0.5
  patrol_finders: ^3.6.0
```
`packages/feature_settings/lib/feature_settings.dart`:
```dart
/// The settings feature. Exposes exactly one factory: `createSettingsModule`.
library;
```

- [ ] **Step 4: App shell via flutter create**

```bash
fvm flutter create --org dev.alatyr --project-name alatyr_starter --empty \
  --platforms android,ios,web,macos,linux,windows --no-pub app
```

Then run the identity rewrite (write this script to the scratchpad, NOT into the repo — it is a one-time authoring step; init's renamer in M5 is the shipped tool):

```sh
#!/usr/bin/env sh
# Rewrite flutter-create placeholders (dev.alatyr.alatyr_starter /
# dev.alatyr.alatyrStarter / "alatyr_starter" labels) to the spec identity:
# bundle id / applicationId dev.alatyr.starter, display name "Alatyr Starter".
# Dart package name, BINARY_NAME, macOS PRODUCT_NAME stay alatyr_starter.
# Portable between BSD and GNU sed (`sed -i.bak`, BRE only). Idempotent.
set -eu
APP_DIR="${1:?usage: $0 <app-dir>}"
cd "$APP_DIR"
OLD_ID_SNAKE='dev.alatyr.alatyr_starter'
OLD_ID_CAMEL='dev.alatyr.alatyrStarter'
NEW_ID='dev.alatyr.starter'
OLD_LABEL='alatyr_starter'
NEW_LABEL='Alatyr Starter'
sedi() { f="$1"; shift; sed -i.bak "$@" "$f" && rm -f "$f.bak"; }

# Android
sedi android/app/build.gradle.kts \
  -e "s/namespace = \"$OLD_ID_SNAKE\"/namespace = \"$NEW_ID\"/" \
  -e "s/applicationId = \"$OLD_ID_SNAKE\"/applicationId = \"$NEW_ID\"/"
sedi android/app/src/main/AndroidManifest.xml \
  -e "s/android:label=\"$OLD_LABEL\"/android:label=\"$NEW_LABEL\"/"
if [ -d android/app/src/main/kotlin/dev/alatyr/alatyr_starter ]; then
  mv android/app/src/main/kotlin/dev/alatyr/alatyr_starter \
     android/app/src/main/kotlin/dev/alatyr/starter
fi
sedi android/app/src/main/kotlin/dev/alatyr/starter/MainActivity.kt \
  -e "s/^package $OLD_ID_SNAKE\$/package $NEW_ID/"

# iOS (Runner + RunnerTests x3 configs; strip the machine's signing team)
sedi ios/Runner.xcodeproj/project.pbxproj \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = $OLD_ID_CAMEL/PRODUCT_BUNDLE_IDENTIFIER = $NEW_ID/" \
  -e '/^[[:space:]]*DEVELOPMENT_TEAM = [A-Za-z0-9]*;$/d'
sedi ios/Runner/Info.plist \
  -e "s|<string>$OLD_LABEL</string>|<string>$NEW_LABEL</string>|"

# macOS (keep PRODUCT_NAME; set human-facing names literally)
sedi macos/Runner/Configs/AppInfo.xcconfig \
  -e "s/^PRODUCT_BUNDLE_IDENTIFIER = $OLD_ID_CAMEL\$/PRODUCT_BUNDLE_IDENTIFIER = $NEW_ID/"
sedi macos/Runner.xcodeproj/project.pbxproj \
  -e "s/PRODUCT_BUNDLE_IDENTIFIER = $OLD_ID_CAMEL/PRODUCT_BUNDLE_IDENTIFIER = $NEW_ID/"
if ! grep -q '<key>CFBundleDisplayName</key>' macos/Runner/Info.plist; then
  sedi macos/Runner/Info.plist \
    -e "s|^\([[:space:]]*\)<key>CFBundleExecutable</key>\$|\1<key>CFBundleDisplayName</key>\\
\1<string>$NEW_LABEL</string>\\
\1<key>CFBundleExecutable</key>|"
fi
sedi macos/Runner/Info.plist \
  -e "s|^\([[:space:]]*\)<string>\$(PRODUCT_NAME)</string>\$|\1<string>$NEW_LABEL</string>|"

# Web
sedi web/manifest.json \
  -e "s/\"name\": \"$OLD_LABEL\"/\"name\": \"$NEW_LABEL\"/" \
  -e "s/\"short_name\": \"$OLD_LABEL\"/\"short_name\": \"$NEW_LABEL\"/"
sedi web/index.html \
  -e "s/<title>$OLD_LABEL<\/title>/<title>$NEW_LABEL<\/title>/" \
  -e "s/content=\"$OLD_LABEL\"/content=\"$NEW_LABEL\"/"

# Linux
sedi linux/CMakeLists.txt \
  -e "s/set(APPLICATION_ID \"$OLD_ID_SNAKE\")/set(APPLICATION_ID \"$NEW_ID\")/"
sedi linux/runner/my_application.cc \
  -e "s/gtk_header_bar_set_title(header_bar, \"$OLD_LABEL\")/gtk_header_bar_set_title(header_bar, \"$NEW_LABEL\")/" \
  -e "s/gtk_window_set_title(window, \"$OLD_LABEL\")/gtk_window_set_title(window, \"$NEW_LABEL\")/"

# Windows
sedi windows/runner/Runner.rc \
  -e "s/VALUE \"FileDescription\", \"$OLD_LABEL\"/VALUE \"FileDescription\", \"$NEW_LABEL\"/" \
  -e "s/VALUE \"ProductName\", \"$OLD_LABEL\"/VALUE \"ProductName\", \"$NEW_LABEL\"/"
sedi windows/runner/main.cpp \
  -e "s/window.Create(L\"$OLD_LABEL\"/window.Create(L\"$NEW_LABEL\"/"

# IDE litter + files the template replaces or must not ship
rm -rf .idea
rm -f alatyr_starter.iml android/alatyr_starter_android.iml
rm -f analysis_options.yaml pubspec.lock
echo "identity rewrite done in $APP_DIR"
```

Run: `sh <scratchpad>/rewrite_identity.sh app`
Then verify: `grep -rn -E 'alatyrStarter|dev\.alatyr\.alatyr_starter|DEVELOPMENT_TEAM' app` → no output; `grep -rn 'dev.alatyr.starter' app | wc -l` → 14; `grep -rn 'Alatyr Starter' app | wc -l` → 14. Keep `app/.metadata` (it pins the create revision; flutter tooling wants it tracked). `macos/Runner/Configs/AppInfo.xcconfig`'s `PRODUCT_COPYRIGHT` and Windows `CompanyName "dev.alatyr"` keep the org token as generated — both are whole-token greppable and covered by init's org replacement.

Replace `app/pubspec.yaml`:

```yaml
name: alatyr_starter
description: Alatyr Starter - the working placeholder app of the Alatyr Flutter template.
publish_to: none
resolution: workspace
version: 0.1.0+1
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"
dependencies:
  flutter:
    sdk: flutter
  app_core: any
  app_config: any
  design_system: any
  data_local: any
  data_secure: any
  feature_settings_api: any
  feature_settings: any
  go_router: ^17.5.0
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol_finders: ^3.6.0
flutter:
  uses-material-design: true
```

Replace `app/README.md`:

```markdown
# Alatyr Starter

The working placeholder app of the Alatyr template: `lib/main.dart` boots the
composition root in `lib/bootstrap/`, which wires `feature_settings` and the
base packages with manual constructor injection and assembles the router from
module routes. `dart run tool/init.dart` (see the repo README) renames this
app to your product identity.
```

Leave `app/lib/main.dart` as generated (`MainApp`, one public widget) until Task 10.

- [ ] **Step 5: Resolve, gate, commit**

Run: `fvm flutter pub get` (root) — expected: resolves; root `pubspec.lock` changes (≈80 new entries; `analyzer` lands at 10.2.0 workspace-wide — `lints/` keeps its own 14.1.0 because it is not a member).
Run: `fvm dart run tool/verify_dependencies.dart && fvm dart run tool/verify_imports.dart` → both OK.
Run: `tool/checks.sh` → `OK` (codegen stage runs build_runner in `data_local` and `feature_settings`, writes 0 outputs — cold AOT compile ≈20 s each; per-member loop shows all eight members; `app` has no tests yet).
Check: `git status --short` shows no `.flutter-plugins-dependencies`, no member `pubspec.lock`, no `app/.idea`.

```bash
git add -A
git commit -m "feat: M3 graph diff, workspace members, package skeletons and app shell"
```

---

### Task 4: design_system — tokens, theme, base widgets

**Files:**
- Create: `packages/design_system/lib/src/tokens/app_spacing.dart`, `packages/design_system/lib/src/tokens/app_radii.dart`, `packages/design_system/lib/src/theme/app_theme.dart`, `packages/design_system/lib/src/widgets/app_choice_tile.dart`, `packages/design_system/lib/src/widgets/app_page_scaffold.dart`
- Modify: `packages/design_system/lib/design_system.dart`
- Test: `packages/design_system/test/app_theme_test.dart`, `packages/design_system/test/app_choice_tile_test.dart`, `packages/design_system/test/app_page_scaffold_test.dart`

**Interfaces:**
- Produces: `AppSpacing.{xs,sm,md,lg,xl}` (double), `AppRadii.{sm,md}` (Radius); `ThemeData AppTheme.light()`, `ThemeData AppTheme.dark()`; `AppChoiceTile({required Key key, required String title, required bool selected, required VoidCallback onTap, String? subtitle})`; `AppPageScaffold({Key? key, required String title, required Widget body})`.

- [ ] **Step 1: Failing tests**

`packages/design_system/test/app_theme_test.dart`:
```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light theme is light and uses Material 3', () {
    final theme = AppTheme.light();
    expect(theme.brightness, Brightness.light);
    expect(theme.useMaterial3, isTrue);
  });

  test('dark theme is dark', () {
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('spacing tokens grow monotonically', () {
    expect(
      [AppSpacing.xs, AppSpacing.sm, AppSpacing.md, AppSpacing.lg, AppSpacing.xl],
      [4, 8, 16, 24, 32],
    );
  });
}
```

`packages/design_system/test/app_choice_tile_test.dart`:
```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

const _key = ValueKey<String>('demo.choice.alpha');

Future<void> _pump(PatrolTester $, {required bool selected, VoidCallback? onTap}) {
  return $.pumpWidgetAndSettle(
    MaterialApp(
      home: Scaffold(
        body: AppChoiceTile(
          key: _key,
          title: 'Alpha',
          subtitle: 'First option',
          selected: selected,
          onTap: onTap ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  patrolWidgetTest('renders title and subtitle under its key', ($) async {
    await _pump($, selected: false);
    expect($(_key), findsOneWidget);
    expect($(_key).$('Alpha'), findsOneWidget);
    expect($(_key).$('First option'), findsOneWidget);
  });

  patrolWidgetTest('shows a check mark only when selected', ($) async {
    await _pump($, selected: true);
    expect($(Icons.check), findsOneWidget);
    await _pump($, selected: false);
    expect($(Icons.check), findsNothing);
  });

  patrolWidgetTest('tap invokes onTap exactly once', ($) async {
    var taps = 0;
    await _pump($, selected: false, onTap: () => taps++);
    await $(_key).tap();
    expect(taps, 1);
  });
}
```

`packages/design_system/test/app_page_scaffold_test.dart`:
```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

void main() {
  patrolWidgetTest('shows the title in an app bar and the body below', ($) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(
        home: AppPageScaffold(
          key: ValueKey<String>('demo.page'),
          title: 'Demo',
          body: Text('body'),
        ),
      ),
    );
    expect($(AppBar).$('Demo'), findsOneWidget);
    expect($(#demo.page).$('body'), findsOneWidget);
  });
}
```

Run: `cd packages/design_system && fvm flutter test --no-pub`
Expected: FAIL (undefined `AppTheme`, `AppChoiceTile`, …).

- [ ] **Step 2: Implement**

`lib/src/tokens/app_spacing.dart`:
```dart
/// Spacing scale (logical pixels). Use these instead of magic numbers.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}
```

`lib/src/tokens/app_radii.dart`:
```dart
import 'package:flutter/widgets.dart';

/// Corner radii.
abstract final class AppRadii {
  static const Radius sm = Radius.circular(8);
  static const Radius md = Radius.circular(12);
}
```

`lib/src/theme/app_theme.dart`:
```dart
import 'package:flutter/material.dart';

import '../tokens/app_radii.dart';

/// The app's light and dark [ThemeData], derived from one seed colour so
/// both modes stay consistent.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF3F51B5);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
    listTileTheme: const ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.md),
      ),
    ),
  );
}
```

`lib/src/widgets/app_choice_tile.dart`:
```dart
import 'package:flutter/material.dart';

/// One option in a single-choice list. The [key] is REQUIRED (not optional
/// as on most widgets): every interactive widget carries a ValueKey from its
/// feature's key namespace, and making it a constructor requirement is the
/// cheapest way to never forget it.
final class AppChoiceTile extends StatelessWidget {
  const AppChoiceTile({
    required Key super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}
```

`lib/src/widgets/app_page_scaffold.dart`:
```dart
import 'package:flutter/material.dart';

/// Standard page chrome: an app bar with [title] above [body].
final class AppPageScaffold extends StatelessWidget {
  const AppPageScaffold({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)), body: body);
}
```

`lib/design_system.dart`:
```dart
/// Theme, design tokens and base widgets shared by every feature.
library;

export 'src/theme/app_theme.dart';
export 'src/tokens/app_radii.dart';
export 'src/tokens/app_spacing.dart';
export 'src/widgets/app_choice_tile.dart';
export 'src/widgets/app_page_scaffold.dart';
```

Run: `cd packages/design_system && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub`
Expected: clean; 7 tests pass.

- [ ] **Step 3: Gate + commit**

Run: `tool/checks.sh --fast` then `tool/checks.sh --package packages/design_system` → OK.

```bash
git add -A
git commit -m "feat(design_system): tokens, seed-derived theme, choice tile and page scaffold"
```

---

### Task 5: data_local — drift database + key-value DAO (codegen live)

**Files:**
- Create: `packages/data_local/lib/src/tables.dart`, `packages/data_local/lib/src/app_database.dart`, `packages/data_local/lib/src/key_value_dao.dart`, `packages/data_local/lib/testing.dart`
- Generated (committed): `packages/data_local/lib/src/app_database.g.dart`, `packages/data_local/lib/src/key_value_dao.g.dart`
- Modify: `packages/data_local/lib/data_local.dart`
- Test: `packages/data_local/test/key_value_dao_test.dart`

**Interfaces:**
- Produces: `AppDatabase(QueryExecutor)`, `AppDatabase.open({required String name})`, `AppDatabase.keyValueDao`; test-only entry point `package:data_local/testing.dart` with `AppDatabase inMemoryAppDatabase()` (the ONLY place `drift/native.dart` is imported — it pulls `dart:ffi`, which would make the web shell uncompilable if it sat in the production library); `KeyValueDao { Future<String?> read(String key); Future<void> write(String key, String value); Future<void> remove(String key); Stream<String?> watch(String key); }` — `watch` emits the current value first (null when absent), then one emission per change.

- [ ] **Step 1: Failing tests**

`packages/data_local/test/key_value_dao_test.dart`:
```dart
import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = inMemoryAppDatabase());
  // Plain `test()` (no FakeAsync zone): awaiting close() here is fine. In
  // `testWidgets` it is not - see the widget-test exemplars in Tasks 9-10.
  tearDown(() => db.close());

  test('write then read roundtrip', () async {
    await db.keyValueDao.write('theme', 'dark');
    expect(await db.keyValueDao.read('theme'), 'dark');
  });

  test('write overwrites an existing value (upsert)', () async {
    await db.keyValueDao.write('theme', 'dark');
    await db.keyValueDao.write('theme', 'light');
    expect(await db.keyValueDao.read('theme'), 'light');
  });

  test('read of a missing key returns null', () async {
    expect(await db.keyValueDao.read('missing'), isNull);
  });

  test('remove deletes the key; removing a missing key is a no-op', () async {
    await db.keyValueDao.write('theme', 'dark');
    await db.keyValueDao.remove('theme');
    expect(await db.keyValueDao.read('theme'), isNull);
    await db.keyValueDao.remove('theme');
  });

  test('watch emits the current value first, then every change', () async {
    await db.keyValueDao.write('theme', 'dark');
    final emitted = <String?>[];
    final sub = db.keyValueDao.watch('theme').listen(emitted.add);
    addTearDown(sub.cancel);

    await pumpEventQueue();
    expect(emitted, ['dark'], reason: 'first emission is the current row');
    await db.keyValueDao.write('theme', 'light');
    await pumpEventQueue();
    expect(emitted, ['dark', 'light']);
    await db.keyValueDao.remove('theme');
    await pumpEventQueue();
    expect(emitted, ['dark', 'light', null]);
  });

  test('watch on a missing key emits null first', () async {
    expect(await db.keyValueDao.watch('nope').first, isNull);
  });

  test('keys are independent', () async {
    await db.keyValueDao.write('a', '1');
    await db.keyValueDao.write('b', '2');
    expect(await db.keyValueDao.read('a'), '1');
    expect(await db.keyValueDao.read('b'), '2');
  });

  test('watch does not re-emit when another key changes or the same value is rewritten', () async {
    await db.keyValueDao.write('theme', 'dark');
    final emitted = <String?>[];
    final sub = db.keyValueDao.watch('theme').listen(emitted.add);
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await db.keyValueDao.write('other', 'x');
    await db.keyValueDao.write('theme', 'dark');
    await pumpEventQueue();

    expect(emitted, ['dark']);
  });
}
```

Run: `cd packages/data_local && fvm flutter test --no-pub` → FAIL (no `AppDatabase`).

- [ ] **Step 2: Implement the schema, database and DAO**

`lib/src/tables.dart`:
```dart
import 'package:drift/drift.dart';

/// Generic string key -> string value storage for small settings-like data.
/// NOT for secrets (those go through data_secure) - the import validator's
/// secret-leak heuristic scans this package for a reason.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
```

`lib/src/app_database.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'key_value_dao.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The single on-device database. Tables and DAOs are registered here;
/// schema changes bump [schemaVersion] and add a migration.
///
/// Deliberately NO `drift/native.dart` import in this library: it pulls
/// `dart:ffi` and would make `flutter build web` fail. The in-memory
/// constructor tests use lives in `package:data_local/testing.dart`.
@DriftDatabase(tables: [KeyValues], daos: [KeyValueDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// On-device database named [name]: drift_flutter picks the platform
  /// storage (documents directory on native, IndexedDB/OPFS on web).
  ///
  /// `web` is mandatory for web builds (`driftDatabase` throws without it)
  /// and names the two assets drift needs next to `index.html`:
  /// `sqlite3.wasm` and `drift_worker.js`. The template's app shell does
  /// not ship those binaries yet (M5 carryover); until then web builds
  /// compile and run but persistence fails at open time with a clear
  /// drift error rather than an ArgumentError.
  AppDatabase.open({required String name})
    : super(
        driftDatabase(
          name: name,
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 1;
}
```

`lib/src/key_value_dao.dart`:
```dart
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'tables.dart';

part 'key_value_dao.g.dart';

/// Key-value access over [KeyValues].
@DriftAccessor(tables: [KeyValues])
class KeyValueDao extends DatabaseAccessor<AppDatabase>
    with _$KeyValueDaoMixin {
  KeyValueDao(super.attachedDatabase);

  Future<String?> read(String key) async {
    final row = await (select(
      keyValues,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> write(String key, String value) async {
    await into(
      keyValues,
    ).insertOnConflictUpdate(KeyValuesCompanion.insert(key: key, value: value));
  }

  /// Named `remove`, not `delete`: `DatabaseAccessor` already inherits
  /// `DatabaseConnectionUser.delete(TableInfo)`, so a `delete(String)`
  /// member on a DAO is an invalid override (compile error).
  Future<void> remove(String key) async {
    await (delete(keyValues)..where((t) => t.key.equals(key))).go();
  }

  /// Emits the current value (null when absent) on subscription, then one
  /// value per change of that key. drift re-runs the query on ANY change to
  /// the table, so `distinct()` is what turns "table changed" into "this
  /// key's value changed".
  Stream<String?> watch(String key) =>
      (select(keyValues)..where((t) => t.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value)
          .distinct();
}
```

`lib/data_local.dart`:
```dart
/// Local persistence: the drift database and its key-value DAO.
library;

export 'src/app_database.dart';
export 'src/key_value_dao.dart';
export 'src/tables.dart';
```

`lib/testing.dart` (a second entry point; never exported from `data_local.dart`):
```dart
/// Test-only entry point. `drift/native.dart` reaches `dart:ffi`, so this
/// library must stay out of `data_local.dart`: the production library is
/// what `app/` compiles for every platform, including web.
library;

import 'package:drift/native.dart';

import 'src/app_database.dart';

/// A fresh in-memory [AppDatabase]: nothing touches disk, every call is a
/// new database.
AppDatabase inMemoryAppDatabase() => AppDatabase(NativeDatabase.memory());
```

- [ ] **Step 3: Generate, test**

Run: `tool/codegen.sh`
Expected: `codegen packages/data_local` writes `lib/src/app_database.g.dart` and `lib/src/key_value_dao.g.dart` (both start with `// GENERATED CODE - DO NOT MODIFY BY HAND` and `// ignore_for_file: type=lint`). First `flutter test` run on this machine downloads sqlite3's prebuilt library via the package's Dart hook (network; cached under root `.dart_tool/hooks_runner/`).

Run: `cd packages/data_local && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub`
Expected: clean; 8 tests pass.

Run: `fvm dart run tool/verify_imports.dart` → `Architecture imports: OK` (no secret-shaped identifier in `data_local/lib`, generated code included).

- [ ] **Step 4: Gate (freshness live) + commit**

Run: `tool/checks.sh` → `OK`. This is the first run where the codegen-freshness stage has real work: the snapshot before/after `tool/codegen.sh` must match — it does only because the generated files are committed below. Proof of the stage: `echo '// stale' >> packages/data_local/lib/src/key_value_dao.g.dart && tool/checks.sh` → the gate fails with `Generated artifacts are stale` (the gate's own codegen run has already restored the file — the snapshot compare is what flags it; `git status` is clean again afterwards).

```bash
git add -A
git commit -m "feat(data_local): drift database with key-value DAO (generated code committed)"
```

---

### Task 5b: Cold codegen in the freshness stage (found by Task 5's review)

Task 5's review reproduced a gap in the gate: with a warm `.dart_tool/build` cache, build_runner 2.15 re-runs a builder only when its tracked inputs changed — a hand-edit to an already-generated `.g.dart` is NOT rewritten, so a format-neutral tamper passes the freshness compare. Spec §6 ("any delta = stale generated artifacts → fail") and hard invariant 5 need the compare to see a real regeneration. Cost of the fix: one cold builder AOT compile per codegen package per full gate (≈20 s each) — accepted; `tool/codegen.sh` without the flag stays warm for the developer loop.

**Files:**
- Modify: `tool/codegen.sh`, `tool/checks.sh`

**Interfaces:**
- Produces: `tool/codegen.sh [--cold]` — with `--cold`, every codegen package's `.dart_tool/build` is removed before its `build_runner build`; the gate's freshness stage calls `tool/codegen.sh --cold`.

- [ ] **Step 1: Reproduce the gap (must pass the gate today)**

From a clean tree: `sed -i.bak 's#^// ignore_for_file: type=lint$#// ignore_for_file: type=lint, unused_element#' packages/data_local/lib/src/key_value_dao.g.dart && rm packages/data_local/lib/src/key_value_dao.g.dart.bak && tool/checks.sh; echo "gate exit=$?"`
Expected today: `OK`, `gate exit=0` (the tamper survives). Restore: `git checkout -- packages/data_local/lib/src/key_value_dao.g.dart`.

- [ ] **Step 2: Implement `--cold`**

`tool/codegen.sh` — parse the flag after the `cd "$ROOT_DIR"` line:

```bash
# --cold: drop each package's build_runner cache first. The gate's freshness
# stage needs a REAL regeneration: a warm cache only re-runs builders whose
# tracked inputs changed, so a hand-edited generated file would survive the
# before/after snapshot compare (found in M3, Task 5 review). Developers
# keep the warm default.
COLD=false
case "${1:-}" in
  --cold) COLD=true ;;
  "") ;;
  *) echo "usage: tool/codegen.sh [--cold]" >&2; exit 2 ;;
esac
```

and in the per-package subshell, before `run_dart run build_runner build`:

```bash
    if [[ "$COLD" == "true" ]]; then rm -rf .dart_tool/build; fi
```

`tool/checks.sh` — the freshness stage:

```bash
echo "==> Codegen (freshness check, cold rebuild)"
bash "$ROOT_DIR/tool/codegen.sh" --cold
```

Update the tier header comment of `tool/checks.sh` (`codegen freshness` → `codegen freshness (cold rebuild)`).

- [ ] **Step 3: Prove it**

Repeat Step 1's tamper: the gate must now stop at the freshness stage with `Generated artifacts are stale, or pubspec.lock does not match the resolved dependencies` and `gate exit=1`. Restore the file with `git checkout -- packages/data_local/lib/src/key_value_dao.g.dart`. Then `bash tool/codegen.sh` (warm, no flag) → unchanged tree; `tool/checks.sh` → `OK`.

- [ ] **Step 4: Commit**

```bash
git add tool/codegen.sh tool/checks.sh
git commit -m "fix(gate): cold build_runner rebuild in the codegen freshness stage"
```

---

### Task 6: data_secure — secure storage port, adapter, in-memory double

**Files:**
- Create: `packages/data_secure/lib/src/secure_store.dart`, `packages/data_secure/lib/src/flutter_secure_store.dart`, `packages/data_secure/lib/src/in_memory_secure_store.dart`
- Modify: `packages/data_secure/lib/data_secure.dart`
- Test: `packages/data_secure/test/in_memory_secure_store_test.dart`, `packages/data_secure/test/flutter_secure_store_test.dart`

**Interfaces:**
- Produces: `abstract interface class SecureStore { Future<Result<String?>> read(String key); Future<Result<void>> write(String key, String value); Future<Result<void>> delete(String key); }`; `SecureStoreFailureCodes.{read,write,delete}` = `'secure.read-failed'`, `'secure.write-failed'`, `'secure.delete-failed'`; `FlutterSecureStore(FlutterSecureStorage storage)` + `FlutterSecureStore.platform()`; `InMemorySecureStore()`.

- [ ] **Step 1: Failing tests**

`packages/data_secure/test/in_memory_secure_store_test.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:data_secure/data_secure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemorySecureStore store;
  setUp(() => store = InMemorySecureStore());

  test('read of a missing key is Ok(null)', () async {
    // `Ok` does not override `==` (app_core keeps Result minimal), so
    // assert on the shape, never on instance equality.
    expect(
      await store.read('k'),
      isA<Ok<String?>>().having((r) => r.value, 'value', isNull),
    );
  });

  test('write then read roundtrip', () async {
    expect(await store.write('k', 'v'), isA<Ok<void>>());
    expect((await store.read('k')).valueOrNull, 'v');
  });

  test('delete removes the key and is a no-op when absent', () async {
    await store.write('k', 'v');
    expect(await store.delete('k'), isA<Ok<void>>());
    expect((await store.read('k')).valueOrNull, isNull);
    expect(await store.delete('k'), isA<Ok<void>>());
  });
}
```

`packages/data_secure/test/flutter_secure_store_test.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:data_secure/data_secure.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late _MockStorage storage;
  late FlutterSecureStore store;

  setUp(() {
    storage = _MockStorage();
    store = FlutterSecureStore(storage);
  });

  test('read delegates with the named key', () async {
    when(() => storage.read(key: 'k')).thenAnswer((_) async => 'v');
    expect(
      await store.read('k'),
      isA<Ok<String?>>().having((r) => r.value, 'value', 'v'),
    );
    verify(() => storage.read(key: 'k')).called(1);
    verifyNoMoreInteractions(storage);
  });

  test('write delegates key and value', () async {
    when(() => storage.write(key: 'k', value: 'v')).thenAnswer((_) async {});
    expect(await store.write('k', 'v'), isA<Ok<void>>());
    verify(() => storage.write(key: 'k', value: 'v')).called(1);
  });

  test('delete delegates with the named key', () async {
    when(() => storage.delete(key: 'k')).thenAnswer((_) async {});
    expect(await store.delete('k'), isA<Ok<void>>());
    verify(() => storage.delete(key: 'k')).called(1);
  });

  test('a PlatformException on read becomes Err(secure.read-failed) with the cause', () async {
    final boom = PlatformException(code: 'Exception', message: 'keychain locked');
    when(() => storage.read(key: 'k')).thenThrow(boom);
    final result = await store.read('k');
    final failure = result.failureOrNull;
    expect(failure?.code, SecureStoreFailureCodes.read);
    expect(failure?.cause, same(boom));
  });

  test('an async failure on write becomes Err(secure.write-failed)', () async {
    when(() => storage.write(key: 'k', value: 'v'))
        .thenAnswer((_) async => throw PlatformException(code: 'Exception'));
    expect((await store.write('k', 'v')).failureOrNull?.code, SecureStoreFailureCodes.write);
  });

  test('a MissingPluginException on delete becomes Err(secure.delete-failed)', () async {
    when(() => storage.delete(key: 'k')).thenThrow(MissingPluginException());
    expect((await store.delete('k')).failureOrNull?.code, SecureStoreFailureCodes.delete);
  });
}
```

Run: `cd packages/data_secure && fvm flutter test --no-pub` → FAIL.

- [ ] **Step 2: Implement**

`lib/src/secure_store.dart`:
```dart
import 'package:app_core/app_core.dart';

/// Failure codes of [SecureStore] operations (`<area>.<reason>`).
abstract final class SecureStoreFailureCodes {
  static const String read = 'secure.read-failed';
  static const String write = 'secure.write-failed';
  static const String delete = 'secure.delete-failed';
}

/// Port for encrypted key-value storage. Runtime secrets (tokens, refresh
/// credentials) live ONLY behind this port - never in drift, prefs, logs or
/// source (hard invariant 4).
abstract interface class SecureStore {
  /// The value for [key], or `Ok(null)` when absent.
  Future<Result<String?>> read(String key);

  /// Persists [value] under [key], overwriting any previous value.
  Future<Result<void>> write(String key, String value);

  /// Removes [key]; `Ok` when it was absent.
  Future<Result<void>> delete(String key);
}
```

`lib/src/flutter_secure_store.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_store.dart';

/// [SecureStore] backed by `flutter_secure_storage` (Keychain / Keystore /
/// libsecret / DPAPI / WebCrypto).
///
/// Platform notes a consumer must keep: macOS needs `keychain-access-groups`
/// in both `DebugProfile.entitlements` and `Release.entitlements` (the app
/// shell ships them); iOS works with the default keychain group - add the
/// same entry to `ios/Runner/*.entitlements` the day App Groups are
/// enabled; Linux needs `libsecret-1-dev` and a running secret service.
///
/// Every operation is `async` and guarded by `on Exception`: the plugin
/// throws `PlatformException` (codes differ per platform, so the TYPE is
/// what we map) and `MissingPluginException` where no implementation is
/// registered; a synchronous throw from the plugin thus surfaces as a
/// rejected future that the guard turns into an [Err].
final class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore(this._storage);

  /// Adapter over the platform plugin with default options.
  const FlutterSecureStore.platform() : this(const FlutterSecureStorage());

  final FlutterSecureStorage _storage;

  @override
  Future<Result<String?>> read(String key) async {
    try {
      return Ok(await _storage.read(key: key));
    } on Exception catch (e) {
      return Err(_failure(SecureStoreFailureCodes.read, 'read', e));
    }
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(_failure(SecureStoreFailureCodes.write, 'write', e));
    }
  }

  @override
  Future<Result<void>> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(_failure(SecureStoreFailureCodes.delete, 'delete', e));
    }
  }

  // The failure message names the operation, never the key or the value:
  // failures may end up in logs.
  static AppFailure _failure(String code, String operation, Exception cause) =>
      AppFailure(
        code: code,
        message: 'Secure storage $operation failed',
        cause: cause,
      );
}
```

`lib/src/in_memory_secure_store.dart`:
```dart
import 'package:app_core/app_core.dart';

import 'secure_store.dart';

/// Volatile [SecureStore] for tests, previews and platforms without a
/// secure backend. Nothing is persisted.
final class InMemorySecureStore implements SecureStore {
  final Map<String, String> _values = {};

  @override
  Future<Result<String?>> read(String key) async => Ok(_values[key]);

  @override
  Future<Result<void>> write(String key, String value) async {
    _values[key] = value;
    return const Ok(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    _values.remove(key);
    return const Ok(null);
  }
}
```

`lib/data_secure.dart`:
```dart
/// Secure storage: the port runtime secrets go through, and its adapters.
library;

export 'src/flutter_secure_store.dart';
export 'src/in_memory_secure_store.dart';
export 'src/secure_store.dart';
```

Also add the keychain entitlement the plugin's README requires on BOTH Apple platforms to the app shell created in Task 3.

macOS — in `app/macos/Runner/DebugProfile.entitlements` and `app/macos/Runner/Release.entitlements`, inside the top-level `<dict>`:

```xml
	<key>keychain-access-groups</key>
	<array/>
```

iOS — `flutter create` ships no entitlements file; create `app/ios/Runner/Runner.entitlements` (one file for all configurations, the shape Xcode itself generates when a capability is added):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>keychain-access-groups</key>
	<array/>
</dict>
</plist>
```

and point the Runner target's three build configurations at it. In `app/ios/Runner.xcodeproj/project.pbxproj` exactly three `XCBuildConfiguration` blocks carry `PRODUCT_BUNDLE_IDENTIFIER = dev.alatyr.starter;` (the RunnerTests ones end in `.RunnerTests`); insert the setting before each of them:

```sh
cd app/ios && sed -i.bak 's|^\([[:space:]]*\)PRODUCT_BUNDLE_IDENTIFIER = dev.alatyr.starter;$|\1CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\
\1PRODUCT_BUNDLE_IDENTIFIER = dev.alatyr.starter;|' Runner.xcodeproj/project.pbxproj && rm Runner.xcodeproj/project.pbxproj.bak && cd ../..
```

Verify: `grep -c 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;' app/ios/Runner.xcodeproj/project.pbxproj` → `3`; `plutil -lint app/ios/Runner/Runner.entitlements app/macos/Runner/*.entitlements` → all OK; `cd app && fvm flutter build ios --simulator --debug` → succeeds (simulator builds need no signing; ~2 min; then `rm -rf app/build`). The empty array is the documented value for apps without App Groups; with App Groups the group name goes into the array (README).

Run: `cd packages/data_secure && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub`
Expected: clean; 9 tests pass.

- [ ] **Step 3: Gate + commit**

Run: `tool/checks.sh --fast && tool/checks.sh --package packages/data_secure` → OK.

```bash
git add -A
git commit -m "feat(data_secure): SecureStore port, flutter_secure_storage adapter, in-memory double"
```

---

### Task 7: feature_settings_api — contracts only

**Files:**
- Create: `packages/feature_settings_api/lib/src/settings_api.dart`, `packages/feature_settings_api/lib/src/settings_keys.dart`, `packages/feature_settings_api/lib/src/settings_routes.dart`, `packages/feature_settings_api/lib/src/settings_failure_codes.dart`
- Modify: `packages/feature_settings_api/lib/feature_settings_api.dart`
- Test: `packages/feature_settings_api/test/settings_keys_test.dart`

**Interfaces:**
- Produces: `abstract interface class SettingsApi { Stream<ThemeMode> watchThemeMode(); }`; `SettingsRoutes.path = '/settings'`, `SettingsRoutes.name = 'settings'`; `SettingsKeys.screen` (`ValueKey('settings.screen')`), `SettingsKeys.failureBanner` (`ValueKey('settings.failure')`), `Key SettingsKeys.themeModeTile(ThemeMode)` (`ValueKey('settings.theme_mode.<mode.name>')`); `SettingsFailureCodes.load = 'settings.load-failed'`, `SettingsFailureCodes.save = 'settings.save-failed'`.

- [ ] **Step 1: Failing test**

`packages/feature_settings_api/test/settings_keys_test.dart`:
```dart
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme mode tile keys are distinct ValueKey<String>s in the settings namespace', () {
    final keys = ThemeMode.values.map(SettingsKeys.themeModeTile).toList();
    expect(keys.toSet(), hasLength(ThemeMode.values.length));
    for (final key in keys) {
      expect(key, isA<ValueKey<String>>());
      expect((key as ValueKey<String>).value, startsWith('settings.theme_mode.'));
    }
  });

  test('dark tile key is the documented literal (patrol `#` selector form)', () {
    expect(
      SettingsKeys.themeModeTile(ThemeMode.dark),
      const ValueKey<String>('settings.theme_mode.dark'),
    );
  });

  test('screen and error keys live in the settings namespace', () {
    expect(SettingsKeys.screen, const ValueKey<String>('settings.screen'));
    expect(SettingsKeys.failureBanner, const ValueKey<String>('settings.failure'));
  });

  test('route path and name are the documented literals', () {
    expect(SettingsRoutes.path, '/settings');
    expect(SettingsRoutes.name, 'settings');
  });
}
```

Run: `cd packages/feature_settings_api && fvm flutter test --no-pub` → FAIL.

- [ ] **Step 2: Implement**

`lib/src/settings_api.dart`:
```dart
import 'package:flutter/material.dart' show ThemeMode;

/// What other parts of the app may ask the settings feature.
///
/// Only `app/` constructs the implementation (through the module factory);
/// consumers depend on this package alone.
abstract interface class SettingsApi {
  /// Emits the effective theme mode on subscription and then on every
  /// change. A missing or corrupted stored value is reported as
  /// [ThemeMode.system] - the stream never errors because of bad data.
  Stream<ThemeMode> watchThemeMode();
}
```

`lib/src/settings_keys.dart`:
```dart
import 'package:flutter/material.dart' show Key, ThemeMode, ValueKey;

/// ValueKey namespace of the settings feature (`settings.*`). Patrol finders
/// address these as `$(#settings.theme_mode.dark)` or
/// `$(SettingsKeys.themeModeTile(ThemeMode.dark))`.
abstract final class SettingsKeys {
  static const String _ns = 'settings';

  static const Key screen = ValueKey<String>('$_ns.screen');
  static const Key failureBanner = ValueKey<String>('$_ns.failure');

  static Key themeModeTile(ThemeMode mode) =>
      ValueKey<String>('$_ns.theme_mode.${mode.name}');
}
```

`lib/src/settings_routes.dart`:
```dart
/// Route spec of the settings feature (the app assembles the router).
abstract final class SettingsRoutes {
  static const String path = '/settings';
  static const String name = 'settings';
}
```

`lib/src/settings_failure_codes.dart`:
```dart
/// Failure codes the settings feature reports (`<area>.<reason>`).
abstract final class SettingsFailureCodes {
  /// The persisted settings could not be read (storage stream error).
  static const String load = 'settings.load-failed';
  static const String save = 'settings.save-failed';
}
```

`lib/feature_settings_api.dart`:
```dart
/// Contracts of the settings feature. Implementation lives in feature_settings.
library;

export 'src/settings_api.dart';
export 'src/settings_failure_codes.dart';
export 'src/settings_keys.dart';
export 'src/settings_routes.dart';
```

Run: `cd packages/feature_settings_api && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub` → clean; 4 tests pass.

- [ ] **Step 3: Gate + commit**

Run: `tool/checks.sh --fast && tool/checks.sh --package packages/feature_settings_api` → OK.

```bash
git add -A
git commit -m "feat(feature_settings_api): SettingsApi port, route spec, key namespace, failure codes"
```

---

### Task 8: feature_settings — repository and bloc (freezed state)

**Files:**
- Create: `packages/feature_settings/lib/src/settings_repository.dart`, `packages/feature_settings/lib/src/drift_settings_repository.dart`, `packages/feature_settings/lib/src/bloc/settings_event.dart`, `packages/feature_settings/lib/src/bloc/settings_state.dart`, `packages/feature_settings/lib/src/bloc/settings_bloc.dart`
- Generated (committed): `packages/feature_settings/lib/src/bloc/settings_state.freezed.dart`
- Test: `packages/feature_settings/test/drift_settings_repository_test.dart`, `packages/feature_settings/test/settings_bloc_test.dart`

**Interfaces:**
- Consumes: `KeyValueDao` (Task 5), `Result`/`AppFailure`/`AppLogger`/`NoopLogger` (app_core), `SettingsFailureCodes` (Task 7).
- Produces (package-internal, `src/` — not exported): `abstract interface class SettingsRepository { Stream<ThemeMode> watchThemeMode(); Future<Result<void>> saveThemeMode(ThemeMode mode); }`; `DriftSettingsRepository(KeyValueDao dao, {AppLogger logger})` with `static const themeModeKey = 'settings.theme_mode'`; `SettingsState.ready` also carries `lastFailure` with code `settings.load-failed` when the repository stream errors; events `SettingsStarted()`, `SettingsThemeModeChanged(ThemeMode themeMode)`; state `SettingsState.loading()` / `SettingsState.ready({required ThemeMode themeMode, AppFailure? lastFailure})` (freezed: `SettingsLoading`, `SettingsReady` with `copyWith`); `SettingsBloc(SettingsRepository)`.

- [ ] **Step 1: Failing repository tests**

`packages/feature_settings/test/drift_settings_repository_test.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:feature_settings/src/drift_settings_repository.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockDao extends Mock implements KeyValueDao {}

void main() {
  group('on a real in-memory database', () {
    late AppDatabase db;
    late DriftSettingsRepository repository;

    setUp(() {
      db = inMemoryAppDatabase();
      repository = DriftSettingsRepository(db.keyValueDao);
    });
    tearDown(() => db.close()); // plain test(): awaiting close is fine here

    test('given nothing is stored, emits system', () async {
      expect(await repository.watchThemeMode().first, ThemeMode.system);
    });

    test('given a stored mode, emits it', () async {
      await db.keyValueDao.write(DriftSettingsRepository.themeModeKey, 'dark');
      expect(await repository.watchThemeMode().first, ThemeMode.dark);
    });

    test('given stored theme is corrupted, settings falls back to system', () async {
      await db.keyValueDao.write(DriftSettingsRepository.themeModeKey, 'purple');
      expect(await repository.watchThemeMode().first, ThemeMode.system);
    });

    test('saveThemeMode persists and the watch stream emits the new mode', () async {
      final emitted = <ThemeMode>[];
      final sub = repository.watchThemeMode().listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();

      expect(await repository.saveThemeMode(ThemeMode.light), isA<Ok<void>>());
      await pumpEventQueue();

      expect(emitted, [ThemeMode.system, ThemeMode.light]);
      expect(
        await db.keyValueDao.read(DriftSettingsRepository.themeModeKey),
        'light',
      );
    });
  });

  test('saveThemeMode maps a storage exception to settings.save-failed', () async {
    final dao = _MockDao();
    when(() => dao.write(any(), any())).thenThrow(Exception('disk full'));
    final result = await DriftSettingsRepository(dao).saveThemeMode(ThemeMode.dark);
    expect(result.failureOrNull?.code, SettingsFailureCodes.save);
    expect(result.failureOrNull?.cause, isA<Exception>());
  });
}
```

Run: `cd packages/feature_settings && fvm flutter test --no-pub test/drift_settings_repository_test.dart` → FAIL.

- [ ] **Step 2: Implement the repository**

`lib/src/settings_repository.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart' show ThemeMode;

/// Persistence port of the settings feature (package-internal; the
/// cross-feature contract is `SettingsApi` in feature_settings_api).
abstract interface class SettingsRepository {
  /// Emits the stored mode on subscription, then on every change. Missing
  /// or corrupted values map to [ThemeMode.system].
  Stream<ThemeMode> watchThemeMode();

  Future<Result<void>> saveThemeMode(ThemeMode mode);
}
```

`lib/src/drift_settings_repository.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'settings_repository.dart';

/// [SettingsRepository] over data_local's key-value DAO.
final class DriftSettingsRepository implements SettingsRepository {
  // Private named initializing formal (Dart 3.12): callers still write
  // `logger:`; flutter_lints' prefer_initializing_formals rejects the
  // `: _logger = logger` spelling under --fatal-infos.
  DriftSettingsRepository(this._dao, {this._logger = const NoopLogger()});

  /// Storage key of the theme mode (value: `ThemeMode.name`).
  static const String themeModeKey = 'settings.theme_mode';

  final KeyValueDao _dao;
  final AppLogger _logger;

  @override
  Stream<ThemeMode> watchThemeMode() =>
      _dao.watch(themeModeKey).map(_decode);

  @override
  Future<Result<void>> saveThemeMode(ThemeMode mode) async {
    try {
      await _dao.write(themeModeKey, mode.name);
      return const Ok(null);
    } on Exception catch (e) {
      return Err(
        AppFailure(
          code: SettingsFailureCodes.save,
          message: 'Could not persist the theme mode',
          cause: e,
        ),
      );
    }
  }

  ThemeMode _decode(String? raw) {
    if (raw == null) return ThemeMode.system;
    final mode = ThemeMode.values.where((m) => m.name == raw).firstOrNull;
    if (mode == null) {
      _logger.warn('settings: unknown stored theme mode "$raw", using system');
      return ThemeMode.system;
    }
    return mode;
  }
}
```

Run: `cd packages/feature_settings && fvm flutter test --no-pub test/drift_settings_repository_test.dart` → 5 pass.

- [ ] **Step 3: Failing bloc tests**

`packages/feature_settings/test/settings_bloc_test.dart`:
```dart
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:feature_settings/src/bloc/settings_bloc.dart';
import 'package:feature_settings/src/bloc/settings_event.dart';
import 'package:feature_settings/src/bloc/settings_state.dart';
import 'package:feature_settings/src/settings_repository.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockRepository repository;
  late StreamController<ThemeMode> modes;
  late List<ThemeMode> completedSaves;

  setUpAll(() => registerFallbackValue(ThemeMode.system));

  setUp(() {
    repository = _MockRepository();
    // Single-subscription on purpose: events added before the bloc
    // subscribes are buffered (a broadcast controller would drop them).
    modes = StreamController<ThemeMode>();
    when(repository.watchThemeMode).thenAnswer((_) => modes.stream);
  });
  // NOT awaited: the done future of a never-listened single-subscription
  // controller never completes, so `tearDown(() => modes.close())` would
  // time out every test that does not subscribe.
  tearDown(() => unawaited(modes.close()));

  test('initial state is loading', () async {
    final bloc = SettingsBloc(repository);
    addTearDown(bloc.close);
    expect(bloc.state, const SettingsState.loading());
  });

  blocTest<SettingsBloc, SettingsState>(
    'SettingsStarted mirrors every repository emission into ready',
    build: () => SettingsBloc(repository),
    act: (bloc) {
      bloc.add(const SettingsStarted());
      modes
        ..add(ThemeMode.system)
        ..add(ThemeMode.dark);
    },
    expect: () => const [
      SettingsState.ready(themeMode: ThemeMode.system),
      SettingsState.ready(themeMode: ThemeMode.dark),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'SettingsThemeModeChanged saves; the new mode arrives through the stream, not the event',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer((_) async => const Ok(null));
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) => bloc.add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const <SettingsState>[],
    verify: (_) => verify(() => repository.saveThemeMode(ThemeMode.dark)).called(1),
  );

  blocTest<SettingsBloc, SettingsState>(
    'a failed save keeps the current mode and exposes the failure',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer(
        (_) async => const Err(AppFailure(code: 'settings.save-failed', message: 'nope')),
      );
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.light),
    act: (bloc) => bloc.add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const [
      SettingsState.ready(
        themeMode: ThemeMode.light,
        lastFailure: AppFailure(code: 'settings.save-failed', message: 'nope'),
      ),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'the next stream emission clears a previous failure',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer(
        (_) async => const Err(AppFailure(code: 'settings.save-failed', message: 'nope')),
      );
    },
    build: () => SettingsBloc(repository),
    act: (bloc) async {
      bloc.add(const SettingsStarted());
      modes.add(ThemeMode.light);
      await Future<void>.delayed(Duration.zero);
      bloc.add(const SettingsThemeModeChanged(ThemeMode.dark));
      await Future<void>.delayed(Duration.zero);
      modes.add(ThemeMode.light);
    },
    expect: () => const [
      SettingsState.ready(themeMode: ThemeMode.light),
      SettingsState.ready(
        themeMode: ThemeMode.light,
        lastFailure: AppFailure(code: 'settings.save-failed', message: 'nope'),
      ),
      SettingsState.ready(themeMode: ThemeMode.light),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'SettingsThemeModeChanged while still loading is ignored',
    build: () => SettingsBloc(repository),
    act: (bloc) => bloc.add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const <SettingsState>[],
    verify: (_) => verifyNever(() => repository.saveThemeMode(any())),
  );

  blocTest<SettingsBloc, SettingsState>(
    'two quick changes (double tap) both reach the repository; the state keeps mirroring the stream',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer((_) async => const Ok(null));
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) => bloc
      ..add(const SettingsThemeModeChanged(ThemeMode.dark))
      ..add(const SettingsThemeModeChanged(ThemeMode.dark)),
    expect: () => const <SettingsState>[],
    verify: (_) => verify(() => repository.saveThemeMode(ThemeMode.dark)).called(2),
  );

  blocTest<SettingsBloc, SettingsState>(
    'a slower earlier save completes before a later one starts, so the latest choice wins',
    setUp: () {
      completedSaves = [];
      when(() => repository.saveThemeMode(ThemeMode.dark)).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        completedSaves.add(ThemeMode.dark);
        return const Ok(null);
      });
      when(() => repository.saveThemeMode(ThemeMode.light)).thenAnswer((_) async {
        completedSaves.add(ThemeMode.light);
        return const Ok(null);
      });
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) => bloc
      ..add(const SettingsThemeModeChanged(ThemeMode.dark))
      ..add(const SettingsThemeModeChanged(ThemeMode.light)),
    wait: const Duration(milliseconds: 80),
    expect: () => const <SettingsState>[],
    // Without serialization the fast `light` save would complete first and
    // the slow `dark` one would overwrite it.
    verify: (_) => expect(completedSaves, [ThemeMode.dark, ThemeMode.light]),
  );

  blocTest<SettingsBloc, SettingsState>(
    'a save that completes after close() neither throws nor emits',
    setUp: () {
      when(() => repository.saveThemeMode(any())).thenAnswer(
        (_) => Future<Result<void>>.delayed(
          const Duration(milliseconds: 20),
          () => const Err(AppFailure(code: 'settings.save-failed', message: 'late')),
        ),
      );
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) async {
      bloc.add(const SettingsThemeModeChanged(ThemeMode.dark));
      await Future<void>.delayed(Duration.zero);
      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 40));
    },
    expect: () => const <SettingsState>[],
    errors: () => isEmpty,
  );

  blocTest<SettingsBloc, SettingsState>(
    'a repository stream error surfaces as settings.load-failed and keeps the last mode',
    build: () => SettingsBloc(repository),
    act: (bloc) async {
      bloc.add(const SettingsStarted());
      modes.add(ThemeMode.dark);
      await Future<void>.delayed(Duration.zero);
      modes.addError(StateError('database gone'));
    },
    expect: () => [
      const SettingsState.ready(themeMode: ThemeMode.dark),
      isA<SettingsReady>()
          .having((s) => s.themeMode, 'themeMode', ThemeMode.dark)
          .having((s) => s.lastFailure?.code, 'lastFailure.code', 'settings.load-failed'),
    ],
    errors: () => isEmpty,
  );
}
```

Each bloc test here is a copyable exemplar of one adversarial class from spec section 10: dependency failure (failed save), races/double-tap, lifecycle (save completing after close), corrupted/erroring source. Nothing is deliberately skipped in this feature.

Run: `cd packages/feature_settings && fvm flutter test --no-pub test/settings_bloc_test.dart` → FAIL.

- [ ] **Step 4: Implement events, freezed state, bloc**

`lib/src/bloc/settings_event.dart`:
```dart
import 'package:flutter/material.dart' show ThemeMode;

sealed class SettingsEvent {
  const SettingsEvent();
}

/// Start mirroring the persisted settings.
final class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

/// The user picked a theme mode.
final class SettingsThemeModeChanged extends SettingsEvent {
  const SettingsThemeModeChanged(this.themeMode);
  final ThemeMode themeMode;
}
```

`lib/src/bloc/settings_state.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState.loading() = SettingsLoading;

  /// [lastFailure] is set when the most recent save failed; the shown
  /// [themeMode] is still the persisted one.
  const factory SettingsState.ready({
    required ThemeMode themeMode,
    AppFailure? lastFailure,
  }) = SettingsReady;
}
```

`lib/src/bloc/settings_bloc.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

/// Persistence is the single source of truth: the bloc mirrors the
/// repository stream and a successful save reaches the UI through that
/// stream, never by echoing the event. Handlers run concurrently (bloc's
/// default transformer), so the long-lived `SettingsStarted` handler does
/// not block saves - but saves themselves are serialized, otherwise a slow
/// earlier save could land after (and overwrite) a later choice.
final class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._repository) : super(const SettingsState.loading()) {
    on<SettingsStarted>(_onStarted);
    on<SettingsThemeModeChanged>(_onThemeModeChanged, transformer: _sequential);
  }

  /// One event at a time, in order (what `bloc_concurrency`'s `sequential()`
  /// does; inlined to keep the canonical stack minimal).
  static Stream<SettingsThemeModeChanged> _sequential(
    Stream<SettingsThemeModeChanged> events,
    Stream<SettingsThemeModeChanged> Function(SettingsThemeModeChanged) mapper,
  ) => events.asyncExpand(mapper);

  final SettingsRepository _repository;

  Future<void> _onStarted(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) => emit.forEach<ThemeMode>(
    _repository.watchThemeMode(),
    onData: (mode) => SettingsState.ready(themeMode: mode),
    // Without onError a stream error would escape the handler as an
    // uncaught error and silently end the mirror. Keep the last known mode
    // (or system) and surface the failure; the subscription stays alive.
    onError: (error, stackTrace) => SettingsState.ready(
      themeMode: switch (state) {
        SettingsReady(:final themeMode) => themeMode,
        SettingsLoading() => ThemeMode.system,
      },
      lastFailure: AppFailure(
        code: SettingsFailureCodes.load,
        message: 'Could not read the stored settings',
        cause: error,
      ),
    ),
  );

  Future<void> _onThemeModeChanged(
    SettingsThemeModeChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final current = state;
    if (current is! SettingsReady) return;
    final result = await _repository.saveThemeMode(event.themeMode);
    // close() drains the in-flight sequential handler before cancelling
    // its emitter, so without this guard a save finishing during close()
    // would still emit. `isClosed` flips synchronously when close() starts.
    if (isClosed) return;
    result.fold(
      ok: (_) {},
      err: (failure) => emit(current.copyWith(lastFailure: failure)),
    );
  }
}
```

Run: `tool/codegen.sh` → writes `lib/src/bloc/settings_state.freezed.dart`.
Run: `fvm dart format . && cd packages/feature_settings && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub` → clean; 15 tests pass.

- [ ] **Step 5: Gate + commit**

Run: `tool/checks.sh` → `OK` (freshness stage now also covers the freezed output).

```bash
git add -A
git commit -m "feat(feature_settings): drift-backed repository and settings bloc with freezed state"
```

---

### Task 9: feature_settings — screen, selector, module factory, assembly test

**Files:**
- Create: `packages/feature_settings/lib/src/ui/settings_screen.dart`, `packages/feature_settings/lib/src/ui/theme_mode_selector.dart`, `packages/feature_settings/lib/src/settings_api_impl.dart`, `packages/feature_settings/lib/src/settings_module.dart`
- Modify: `packages/feature_settings/lib/feature_settings.dart`
- Test: `packages/feature_settings/test/settings_screen_test.dart`, `packages/feature_settings/test/settings_module_test.dart`

**Interfaces:**
- Consumes: Task 8's bloc/state/events/repository; `AppChoiceTile`, `AppPageScaffold`, `AppSpacing` (Task 4); `SettingsKeys`, `SettingsRoutes`, `SettingsApi` (Task 7); `KeyValueDao` (Task 5).
- Produces (the package's ONLY public API): `final class SettingsModule { List<RouteBase> routes; SettingsApi api; }`; `SettingsModule createSettingsModule({required KeyValueDao keyValueDao, AppLogger logger = const NoopLogger()})`.

- [ ] **Step 1: Failing screen tests**

`packages/feature_settings/test/settings_screen_test.dart`:
```dart
import 'dart:async';

import 'package:app_core/app_core.dart';
import 'package:feature_settings/src/bloc/settings_bloc.dart';
import 'package:feature_settings/src/bloc/settings_event.dart';
import 'package:feature_settings/src/settings_repository.dart';
import 'package:feature_settings/src/ui/settings_screen.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Deterministic in-memory repository: a broadcast stream that replays the
/// current value to new listeners, and an optional forced save failure.
final class _FakeRepository implements SettingsRepository {
  _FakeRepository({this.failSaves = false, this.neverLoads = false});

  final bool failSaves;

  /// A load that never completes (storage hanging): the screen stays in
  /// its loading state for the whole test.
  final bool neverLoads;
  ThemeMode _current = ThemeMode.system;
  final _changes = StreamController<ThemeMode>.broadcast();

  @override
  Stream<ThemeMode> watchThemeMode() async* {
    if (!neverLoads) yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> saveThemeMode(ThemeMode mode) async {
    if (failSaves) {
      return const Err(AppFailure(code: SettingsFailureCodes.save, message: 'nope'));
    }
    _current = mode;
    _changes.add(mode);
    return const Ok(null);
  }

}

/// The widget tree owns the bloc (`BlocProvider(create:)` closes it at
/// disposal). Nothing here is closed through an awaited tearDown: a
/// `Bloc.close()` / `StreamController.close()` whose completion depends on
/// objects created inside the FakeAsync zone of `testWidgets` never
/// completes once the body has returned, and the test hangs (verified).
Future<void> _pump(PatrolTester $, _FakeRepository repository) =>
    $.pumpWidgetAndSettle(
      MaterialApp(
        home: BlocProvider(
          create: (_) => SettingsBloc(repository)..add(const SettingsStarted()),
          child: const SettingsScreen(),
        ),
      ),
    );

// Patrol finders all the way down; `$.tester.widget<T>` is the only way to
// read a widget property, so that part is unavoidable.
bool _isSelected(PatrolTester $, ThemeMode mode) => $.tester
    .widget<ListTile>($(SettingsKeys.themeModeTile(mode)).$(ListTile))
    .selected;

void main() {
  patrolWidgetTest('renders one keyed tile per theme mode, system selected by default', ($) async {
    await _pump($, _FakeRepository());
    expect($(SettingsKeys.screen), findsOneWidget);
    for (final mode in ThemeMode.values) {
      expect($(SettingsKeys.themeModeTile(mode)), findsOneWidget);
    }
    expect(_isSelected($, ThemeMode.system), isTrue);
    expect(_isSelected($, ThemeMode.dark), isFalse);
    expect($(SettingsKeys.failureBanner).exists, isFalse);
  });

  patrolWidgetTest('tapping dark persists and selects dark', ($) async {
    final repository = _FakeRepository();
    await _pump($, repository);
    await $(#settings.theme_mode.dark).tap();
    expect(_isSelected($, ThemeMode.dark), isTrue);
    expect(_isSelected($, ThemeMode.system), isFalse);
  });

  patrolWidgetTest('given the save fails, the selection stays and an error is shown', ($) async {
    await _pump($, _FakeRepository(failSaves: true));
    await $(#settings.theme_mode.light).tap();
    expect(_isSelected($, ThemeMode.system), isTrue);
    expect($(SettingsKeys.failureBanner).$('Could not save your choice. Please try again.'), findsOneWidget);
  });

  patrolWidgetTest('tapping the already selected mode keeps it selected', ($) async {
    await _pump($, _FakeRepository());
    await $(#settings.theme_mode.system).tap();
    expect(_isSelected($, ThemeMode.system), isTrue);
  });

  patrolWidgetTest('disposing the screen while still loading closes the bloc cleanly', ($) async {
    // Plain pumps: a progress indicator animates forever, so
    // pumpWidgetAndSettle would time out here.
    await $.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) =>
              SettingsBloc(_FakeRepository(neverLoads: true))
                ..add(const SettingsStarted()),
          child: const SettingsScreen(),
        ),
      ),
    );
    await $.pump();
    expect($(CircularProgressIndicator), findsOneWidget);
    await $.pumpWidget(const SizedBox.shrink());
    await $.pump();
    // No error, no pending timer: the lifecycle case "dispose during load".
  });
}
```

Run: `cd packages/feature_settings && fvm flutter test --no-pub test/settings_screen_test.dart` → FAIL.

- [ ] **Step 2: Implement the UI**

`lib/src/ui/theme_mode_selector.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:design_system/design_system.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';

/// Single-choice list of theme modes. Stateless: the selected mode and the
/// last failure come from the bloc state, taps go back as callbacks.
final class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({
    required this.selected,
    required this.onChanged,
    this.failure,
    super.key,
  });

  final ThemeMode selected;
  final ValueChanged<ThemeMode> onChanged;
  final AppFailure? failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Public fields never promote; shadow it so `_message(failure)` sees a
    // non-nullable value (same idiom as AppChoiceTile.subtitle).
    final failure = this.failure;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              _message(failure),
              key: SettingsKeys.failureBanner,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        for (final mode in ThemeMode.values)
          AppChoiceTile(
            key: SettingsKeys.themeModeTile(mode),
            title: _label(mode),
            selected: mode == selected,
            onTap: () => onChanged(mode),
          ),
      ],
    );
  }

  static String _label(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  static String _message(AppFailure failure) => switch (failure.code) {
    SettingsFailureCodes.load => 'Could not read your saved settings.',
    _ => 'Could not save your choice. Please try again.',
  };
}
```

`lib/src/ui/settings_screen.dart`:
```dart
import 'package:design_system/design_system.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'theme_mode_selector.dart';

/// The settings page. Expects a [SettingsBloc] above it (the module's route
/// provides one).
final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => AppPageScaffold(
    key: SettingsKeys.screen,
    title: 'Settings',
    body: BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) => switch (state) {
        SettingsLoading() => const Center(child: CircularProgressIndicator()),
        SettingsReady(:final themeMode, :final lastFailure) =>
          ThemeModeSelector(
            selected: themeMode,
            failure: lastFailure,
            onChanged: (mode) => context.read<SettingsBloc>().add(
              SettingsThemeModeChanged(mode),
            ),
          ),
      },
    ),
  );
}
```

Run: `fvm dart format . && cd packages/feature_settings && fvm flutter test --no-pub test/settings_screen_test.dart` → 5 pass. (Guardrail, verified during plan challenge: these tests hang only if the body or a `tearDown`/`addTearDown` awaits something whose completion is delivered outside the FakeAsync flush — `Bloc.close()`, `StreamController.close()`, a drift `close()`, or `.first` on a repository stream. Never add one; `pumpWidgetAndSettle` itself settles fine.)

- [ ] **Step 3: Failing assembly tests**

`packages/feature_settings/test/settings_module_test.dart`:
```dart
import 'dart:async';

import 'package:data_local/data_local.dart';
import 'package:data_local/testing.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol_finders/patrol_finders.dart';

/// Drift schedules a zero-duration timer when the bloc's watch subscription
/// is cancelled (BlocProvider closes the bloc at tree disposal), and
/// flutter_test asserts that no timer is pending after the body. So every
/// drift-backed widget test unmounts explicitly and gives that timer one
/// pump before returning.
Future<void> _unmount(PatrolTester $) async {
  await $.pumpWidget(const SizedBox.shrink());
  await $.pump(Duration.zero);
}

void main() {
  late AppDatabase db;
  late SettingsModule module;

  setUp(() {
    db = inMemoryAppDatabase();
    module = createSettingsModule(keyValueDao: db.keyValueDao);
  });
  // Fire-and-forget: after a testWidgets body, an awaited db.close() hangs
  // (its completion lives in the finished FakeAsync zone).
  tearDown(() => unawaited(db.close()));

  test('contributes exactly one route at the documented path and name', () {
    expect(module.routes, hasLength(1));
    final route = module.routes.single as GoRoute;
    expect(route.path, SettingsRoutes.path);
    expect(route.name, SettingsRoutes.name);
  });

  test('api reports system until something is stored, then the stored mode', () async {
    expect(await module.api.watchThemeMode().first, ThemeMode.system);
    await db.keyValueDao.write('settings.theme_mode', 'dark');
    expect(await module.api.watchThemeMode().first, ThemeMode.dark);
  });

  patrolWidgetTest('the route renders the settings screen wired to real persistence', ($) async {
    final router = GoRouter(initialLocation: SettingsRoutes.path, routes: module.routes);
    addTearDown(router.dispose);
    await $.pumpWidgetAndSettle(MaterialApp.router(routerConfig: router));

    expect($(SettingsKeys.screen), findsOneWidget);
    await $(#settings.theme_mode.dark).tap();
    // Assert through read(), never by awaiting the drift-backed STREAM
    // (`.first`) inside the body: that await resumes outside the FakeAsync
    // zone and strands every later pump (verified hang). The api stream is
    // covered by the plain test above.
    final stored = await db.keyValueDao.read('settings.theme_mode');
    await _unmount($);

    expect(stored, 'dark');
  });
}
```

Run: `cd packages/feature_settings && fvm flutter test --no-pub test/settings_module_test.dart` → FAIL (no `createSettingsModule`).

- [ ] **Step 4: Implement the api adapter and the module factory**

`lib/src/settings_api_impl.dart`:
```dart
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'settings_repository.dart';

/// [SettingsApi] over the feature's repository. Package-internal: reachable
/// only through `createSettingsModule`.
final class RepositorySettingsApi implements SettingsApi {
  const RepositorySettingsApi(this._repository);

  final SettingsRepository _repository;

  @override
  Stream<ThemeMode> watchThemeMode() => _repository.watchThemeMode();
}
```

`lib/src/settings_module.dart`:
```dart
import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'bloc/settings_bloc.dart';
import 'bloc/settings_event.dart';
import 'drift_settings_repository.dart';
import 'settings_api_impl.dart';
import 'ui/settings_screen.dart';

/// What the settings feature hands to the app: routes to mount and the api
/// other parts of the app talk to.
final class SettingsModule {
  const SettingsModule({required this.routes, required this.api});

  final List<RouteBase> routes;
  final SettingsApi api;
}

/// The feature's single entry point. `app/` calls this from its composition
/// root with the dependencies it constructed; nothing else in the package
/// is public.
SettingsModule createSettingsModule({
  required KeyValueDao keyValueDao,
  AppLogger logger = const NoopLogger(),
}) {
  final repository = DriftSettingsRepository(keyValueDao, logger: logger);
  return SettingsModule(
    routes: [
      GoRoute(
        path: SettingsRoutes.path,
        name: SettingsRoutes.name,
        builder: (context, state) => BlocProvider(
          create: (_) => SettingsBloc(repository)..add(const SettingsStarted()),
          child: const SettingsScreen(),
        ),
      ),
    ],
    api: RepositorySettingsApi(repository),
  );
}
```

`lib/feature_settings.dart`:
```dart
/// The settings feature. Exposes exactly one factory: `createSettingsModule`.
library;

export 'src/settings_module.dart' show SettingsModule, createSettingsModule;
```

Run: `fvm dart format . && cd packages/feature_settings && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub` → clean; 23 tests pass.

- [ ] **Step 5: Gate + commit**

Run: `tool/checks.sh` → `OK`.

```bash
git add -A
git commit -m "feat(feature_settings): settings screen, theme mode selector and module factory"
```

---

### Task 10: app/ — composition root, router, themed shell, smoke tests, identity test

**Files:**
- Create: `app/lib/bootstrap/app_dependencies.dart`, `app/lib/bootstrap/bootstrap.dart`, `app/lib/app.dart`; replace `app/lib/main.dart`
- Create: `.dart-defines/dev.env.example`; modify `.gitignore`
- Test: `app/test/app_test.dart`, `test/template_identity_test.dart` (root)

**Interfaces:**
- Consumes: `AppConfig` (app_config), `ConsoleLogger`/`NoopLogger` (app_core), `AppDatabase` (Task 5), `FlutterSecureStore`/`InMemorySecureStore`/`SecureStore` (Task 6), `createSettingsModule`/`SettingsModule` (Task 9), `SettingsRoutes`/`SettingsKeys` (Task 7), `AppTheme` (Task 4).
- Produces: `AppDependencies({required AppConfig config, required AppLogger logger, required AppDatabase database, required SecureStore secureStore})`, `AppDependencies.production()`, `AppDependencies.settings`, `GoRouter AppDependencies.buildRouter()`, `Future<void> AppDependencies.dispose()`; `App({required AppDependencies dependencies})`; `Future<void> bootstrap({AppDependencies Function() createDependencies = AppDependencies.production})`.

- [ ] **Step 1: Failing smoke tests**

`app/test/app_test.dart`:
```dart
import 'dart:async';

import 'package:alatyr_starter/app.dart';
import 'package:alatyr_starter/bootstrap/app_dependencies.dart';
import 'package:alatyr_starter/bootstrap/bootstrap.dart';
import 'package:app_config/app_config.dart';
import 'package:app_core/app_core.dart';
import 'package:data_local/testing.dart';
import 'package:data_secure/data_secure.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';

AppDependencies _testDependencies() => AppDependencies(
  config: AppConfig(env: AppEnv.dev, apiBaseUrl: Uri.parse('https://example.invalid')),
  logger: const NoopLogger(),
  database: inMemoryAppDatabase(),
  secureStore: InMemorySecureStore(),
);

// `$.tester.widget<T>` is the only way to read a widget property; the
// lookup itself stays a patrol finder.
ThemeMode? _themeMode(PatrolTester $) =>
    $.tester.widget<MaterialApp>($(MaterialApp)).themeMode;

bool _isSelected(PatrolTester $, ThemeMode mode) => $.tester
    .widget<ListTile>($(SettingsKeys.themeModeTile(mode)).$(ListTile))
    .selected;

/// See feature_settings/test/settings_module_test.dart: drift's zero-timer
/// on stream cancel must fire before the body returns.
Future<void> _unmount(PatrolTester $) async {
  await $.pumpWidget(const SizedBox.shrink());
  await $.pump(Duration.zero);
}

void main() {
  late AppDependencies deps;

  setUp(() => deps = _testDependencies());
  // Fire-and-forget (see settings_module_test.dart).
  tearDown(() => unawaited(deps.dispose()));

  patrolWidgetTest('bootstrap() boots into the settings screen with the persisted (system) mode selected', ($) async {
    // The real entry path (binding + runApp), with the test seam supplying
    // in-memory dependencies; the test binding is the WidgetsBinding
    // bootstrap() initializes, so runApp lands in this tester's tree.
    await bootstrap(createDependencies: () => deps);
    await $.pumpAndSettle();
    expect($(SettingsKeys.screen), findsOneWidget);
    // Selected tile, not MaterialApp.themeMode: the latter is satisfied by
    // StreamBuilder.initialData even if the port never emitted.
    expect(_isSelected($, ThemeMode.system), isTrue);
    await _unmount($);
  });

  patrolWidgetTest('choosing dark drives MaterialApp.themeMode through the SettingsApi port', ($) async {
    await $.pumpWidgetAndSettle(App(dependencies: deps));
    await $(#settings.theme_mode.dark).tap();
    final mode = _themeMode($);
    await _unmount($);
    expect(mode, ThemeMode.dark);
  });

  patrolWidgetTest('a fresh app over the same database restores the persisted theme', ($) async {
    await $.pumpWidgetAndSettle(App(dependencies: deps));
    await $(#settings.theme_mode.dark).tap();

    // "Restart" = a NEW widget tree and DI graph over the same storage (the
    // convention spec section 8 records for critical flows). Unmount first:
    // pumping a second `App` straight over the first would update the
    // existing element and keep `_AppState`'s router and stream bound to
    // the old dependencies - the test would pass without proving anything.
    await _unmount($);
    final restarted = AppDependencies(
      config: deps.config,
      logger: deps.logger,
      database: deps.database,
      secureStore: deps.secureStore,
    );
    await $.pumpWidgetAndSettle(App(dependencies: restarted));
    final mode = _themeMode($);
    await _unmount($);
    expect(mode, ThemeMode.dark);
  });
}
```

Root `test/template_identity_test.dart`:
```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Spec section 9: packages/, lints/ and tool/ are product-neutral by
/// construction, so init's identity rewrite never has to touch them. This
/// test is what makes "by construction" true.
void main() {
  const identityTokens = [
    'alatyr_starter',
    'dev.alatyr',
    'Alatyr Starter',
    'alatyr_workspace',
  ];
  const neutralDirs = ['packages', 'lints', 'tool'];
  const skippedDirNames = {'.dart_tool', 'build'};

  test('product-neutral directories contain no placeholder identity token', () {
    final hits = <String>[];
    for (final dir in neutralDirs) {
      final files = Directory(dir)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => !p.split(f.path).any(skippedDirNames.contains));
      for (final file in files) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          for (final token in identityTokens) {
            if (lines[i].contains(token)) {
              hits.add('${file.path}:${i + 1}: $token');
            }
          }
        }
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
```

Run: `cd app && fvm flutter test --no-pub` → FAIL (no `app.dart`); `fvm dart test test/template_identity_test.dart` → PASS already (Task 2 neutralised `lints/`), which is fine — it guards the rest of the task.

- [ ] **Step 2: Implement the composition root**

`app/lib/bootstrap/app_dependencies.dart`:
```dart
import 'package:app_config/app_config.dart';
import 'package:app_core/app_core.dart';
import 'package:data_local/data_local.dart';
import 'package:data_secure/data_secure.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:go_router/go_router.dart';

/// The composition root: every implementation is constructed HERE, by hand,
/// and handed down through constructors (ADR: manual DI). Feature modules
/// receive only what they declare; the app assembles the router from the
/// routes they contribute.
final class AppDependencies {
  AppDependencies({
    required this.config,
    required this.logger,
    required this.database,
    required this.secureStore,
  }) : settings = createSettingsModule(
         keyValueDao: database.keyValueDao,
         logger: logger,
       );

  /// Production wiring: real config from dart-defines, console logging, the
  /// on-device database and the platform keychain.
  factory AppDependencies.production() => AppDependencies(
    config: AppConfig.fromEnvironment(),
    logger: const ConsoleLogger(),
    database: AppDatabase.open(name: 'alatyr_starter'),
    secureStore: const FlutterSecureStore.platform(),
  );

  final AppConfig config;
  final AppLogger logger;
  final AppDatabase database;

  /// Where runtime secrets go (hard invariant 4). No feature needs it yet;
  /// the first one that does receives it through its module factory.
  final SecureStore secureStore;

  final SettingsModule settings;

  GoRouter buildRouter() => GoRouter(
    initialLocation: SettingsRoutes.path,
    routes: [...settings.routes],
  );

  Future<void> dispose() => database.close();
}
```

`app/lib/app.dart`:
```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap/app_dependencies.dart';

/// Root widget: owns the router and drives [MaterialApp.themeMode] from the
/// settings feature through its api port.
final class App extends StatefulWidget {
  const App({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<App> createState() => _AppState();
}

final class _AppState extends State<App> {
  late final GoRouter _router = widget.dependencies.buildRouter();

  // Subscribed once: a new stream per build would resubscribe on every
  // rebuild and replay the current value each time.
  late final Stream<ThemeMode> _themeMode =
      widget.dependencies.settings.api.watchThemeMode();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<ThemeMode>(
    stream: _themeMode,
    initialData: ThemeMode.system,
    builder: (context, snapshot) => MaterialApp.router(
      title: 'Alatyr Starter',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: snapshot.data,
      routerConfig: _router,
    ),
  );
}
```

`app/lib/bootstrap/bootstrap.dart`:
```dart
import 'package:flutter/widgets.dart';

import '../app.dart';
import 'app_dependencies.dart';

/// Process entry: binding, dependencies, run. [createDependencies] is the
/// test seam: the bootstrap smoke test runs this exact path with in-memory
/// dependencies; `main` uses production ones.
Future<void> bootstrap({
  AppDependencies Function() createDependencies = AppDependencies.production,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App(dependencies: createDependencies()));
}
```

`app/lib/main.dart`:
```dart
import 'bootstrap/bootstrap.dart';

Future<void> main() => bootstrap();
```

Run: `fvm dart format . && cd app && fvm dart analyze --fatal-infos . && fvm flutter test --no-pub` → clean; 3 tests pass.

- [ ] **Step 3: Local env scheme**

`.dart-defines/dev.env.example`:
```
# Copy to .dart-defines/dev.env (gitignored) and pass with
#   flutter run --dart-define-from-file=.dart-defines/dev.env
# Only PUBLIC client values belong here (spec section 1). Keys are read by
# packages/app_config (AppConfig.fromEnvironment).
APP_ENV=dev
API_BASE_URL=https://api.example.invalid
```

Root `.gitignore` — append:
```
# Local env files; only the *.example scheme is committed.
.dart-defines/*.env
```

- [ ] **Step 4: Gate + commit**

Run: `tool/checks.sh` → `OK` (the per-member loop now tests `app`; root tests include the identity test). Also: `cd app && fvm flutter build apk --debug` is NOT required by the gate — do not run it here (≈2.5 GB of build output); the research probe proved the rewritten shells build for Android, iOS simulator, macOS and web before the packages were wired in, and the production library keeps `dart:ffi` out (Task 5) so the web compile stays possible. Run `cd app && fvm flutter build web` once at the end of this task as the cheap proof (~1 min, no device) and delete `app/build/` afterwards.

```bash
git add -A
git commit -m "feat(app): composition root, router assembly, theme driven through SettingsApi, smoke tests"
```

---

### Task 11: M3 wrap-up

**Files:**
- Modify: `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` (status + two touch-ups), `docs/superpowers/plans/m2-carryover.md` → rename/replace with `docs/superpowers/plans/m3-carryover.md`
- Russian twins of every touched doc (`*.ru.md`, gitignored — local rule)

- [ ] **Step 1: Full gate, twice**

Run: `tool/checks.sh` → `OK`. Then `git status --short` → empty (no stray generated or plugin files). Then `tool/checks.sh --fast` → `OK (fast)`.

- [ ] **Step 2: Spec touch-ups (facts learned, not design changes)**

- Status line: `implementation in progress (M3 done)`.
- §6 `tool/checks.sh` paragraph: `build_runner build --low-resources-mode --delete-conflicting-outputs` → `build_runner build` (flags removed in build_runner 2.15; conflicting outputs are always overwritten), and the per-package analyze command is `dart analyze --fatal-infos` for every member (one-shot `flutter analyze` never loads the plugin host — sdk#63787; the root `dart analyze` stage is the plugin-enforcing one); tests keep `flutter test --no-pub` / `dart test`.
- §8, shipped test exemplars paragraph — append after "app bootstrap smoke test,": `the in-process "restart" case (a second widget tree + DI graph over the same in-memory database) as the widget-level twin of the patrol restart flow,`. §10's table stays as is.

- [ ] **Step 3: Carryover file**

Create `docs/superpowers/plans/m3-carryover.md` (delete `m2-carryover.md` — every M3 tripwire landed: codegen timeout (Task 1), widened scan (Task 1), build exclude (Task 1), anchored path resolution (Task 2)):

```markdown
# Carryover into M4/M5 planning (from M3)

Obligations that survived M3. The M4 and M5 plans MUST pick these up; delete
entries as they land.

## M4 (agent harness)

- `docs/workflow/getting-started.md` must cover: first `flutter test` of
  data_local downloads sqlite3's prebuilt library through the package's Dart
  hook (network once, cached under `.dart_tool/hooks_runner/`); Apple targets
  need `keychain-access-groups` entitlements (shipped for macOS); Linux needs
  `libsecret-1-dev` + a secret service for data_secure.
- `docs/workflow/maintenance.md` owns the codegen-stack ceiling: freezed
  3.2.5 caps `analyzer <11`, which holds drift_dev at 2.34.0 and build_runner
  at 2.15.1 workspace-wide; re-check on every freezed release.
- `docs/testing/widget-test-guardrails.md`: the patrol `#` selector maps to
  `ValueKey<String>` only; `BlocProvider(create:)` is lazy; dispose a
  per-test `GoRouter` in `tearDown`; adapter methods over plugins are `async`
  so sync throws become rejected futures.
- `.claude/rules/widgets.md`: `AppChoiceTile` requires its key; document the
  `settings.*` namespace pattern as the template for new features.
- `docs/testing/widget-test-guardrails.md` (the FakeAsync rules, verified in
  M3's plan challenge): never await, via `tearDown`/`addTearDown`, a future
  whose completion depends on objects created inside a `testWidgets` body
  (`Bloc.close()`, `StreamController.close()`, drift `close()`) — let the
  tree own blocs, use `unawaited(...)` closes; never `await` a drift-backed
  stream (`.first`, `await for`) inside the body — assert through `read()`;
  drift schedules a zero-duration timer when a watch subscription is
  cancelled, so drift-backed widget tests end with an explicit unmount +
  `pump(Duration.zero)`.
- `docs/workflow/getting-started.md`: web persistence needs drift's
  `sqlite3.wasm` + `drift_worker.js` next to `index.html` (M5 ships them);
  Apple platforms ship `keychain-access-groups` with an empty array - put
  the App Group name into it when App Groups are enabled.

## M5 (instantiation + e2e)

- Identity layout to rename (verified by grep after the rewrite): Android
  `namespace`/`applicationId` + Kotlin dir `dev/alatyr/starter`; iOS/macOS
  `PRODUCT_BUNDLE_IDENTIFIER` (Runner + RunnerTests), iOS `CFBundleName`,
  macOS `CFBundleName`/`CFBundleDisplayName` (literal, PRODUCT_NAME kept);
  web `manifest.json` name/short_name + `index.html` title/apple title;
  linux `APPLICATION_ID` + GTK titles; windows `Runner.rc`
  FileDescription/ProductName/CompanyName + `main.cpp` title; macOS
  `PRODUCT_COPYRIGHT` and windows `LegalCopyright` carry the org token.
- `flutter create` on a Mac with a signing identity writes
  `DEVELOPMENT_TEAM` into the iOS pbxproj; the shipped shell has it stripped -
  the init fixture must assert it stays absent.
- patrol_cli 4.x defaults the e2e dir to `patrol_test/`; to keep the spec's
  `app/integration_test/` layout set `patrol: test_directory:
  integration_test` in `app/pubspec.yaml`. `patrol` (the plugin, 4.9.0) is
  added to the app only in M5; set `PATROL_FLUTTER_COMMAND='fvm flutter'`.
- The app smoke test's in-process "restart" case is the widget-level twin of
  the patrol restart flow; register the patrol one in `critical_flows.md`.
- Web runtime: `AppDatabase.open` already passes `DriftWebOptions` for
  `sqlite3.wasm` + `drift_worker.js`; ship both into `app/web/` (versions
  matching the resolved `sqlite3` and `drift` packages - drift's
  "Getting started on the web" page lists the download URLs per release)
  and add a web runtime smoke (`flutter run -d chrome` or a web
  integration test) so persistence on web is verified, not assumed.
- `ios/Runner/Runner.entitlements` + `CODE_SIGN_ENTITLEMENTS` are part of
  the iOS shell now; the init fixture matrix must keep them intact (no
  identity tokens inside) and the iOS e2e run is the runtime proof.
- `test/template_identity_test.dart` asserts `tool/` carries no identity
  token; `tool/init.dart` + `tool/src/init_*` must spell them. Decide before
  M5 adds them: allowlist those files in the test, or have init derive the
  tokens (e.g. read the app entry of `package_graph.yaml` and the root
  pubspec name) instead of hardcoding them.

## Recorded as accepted (no action planned)

- Carried from M1/M2 reviews: deferred minors triaged OK-TO-DEFER at the M1
  final review (cosmetics, report noise, symmetric-code coverage gaps — see
  the M1 branch reviews in git history); the import lexer has no explicit
  recursion cap on interpolation nesting (bounded by real source shape) and
  malformed-paren directive bodies degrade to an EOF-bounded scan.
- Per-member `dart analyze` in the full tier duplicates the root analyze
  stage (~16 s); kept for per-package failure attribution.
- build_runner 2.15's `--workspace` single-invocation mode is not used; the
  per-package plan is unit-tested and names the failing package.
- `data_secure` is wired in `AppDependencies` but no feature consumes it
  yet - it demonstrates the kind and the invariant-4 home; the first feature
  with a secret receives it through its module factory.
```

- [ ] **Step 4: Russian twins, commit, merge**

Update the `.ru.md` twins of the spec and the carryover and re-sync this plan's twin (`2026-08-21-m3-example-slice.ru.md`, created with the plan) with any edits made during execution (local rule; gitignored). Then:

```bash
fvm dart format --output=none --set-exit-if-changed . && git add -A
git commit -m "chore: mark M3 complete in spec status, carryover for M4/M5"
git checkout main && git merge --no-ff feat/m3-example-slice -m "merge: M3 — example slice"
```

Do not push.

---

## Remaining risks (known at planning time)

- **sqlite3 Dart hooks on CI (ubuntu):** locally the hook downloads a prebuilt dylib; on Linux it should download a prebuilt `.so` or compile with gcc. `libsqlite3-dev` stays in `ci.yml` as a harmless fallback. If the first CI run fails in `data_local` tests, the documented escape is `hooks: user_defines: sqlite3: source: system` in the consuming app's pubspec — record the outcome in `ci_contract.md` (M4).
- **Version ceiling:** freezed 3.2.5 pins analyzer 10.x workspace-wide (drift_dev 2.34.0, build_runner 2.15.1). Functional, but `flutter pub outdated` will nag; owned by maintenance.md (M4).
- **FakeAsync teardown rules (found and fixed during the plan challenge, not by the research pass):** an awaited `Bloc.close()`, an awaited `close()` of a never-listened single-subscription `StreamController`, and an awaited drift `close()` after a `testWidgets` body all hang; drift schedules a zero-duration timer when a watch subscription is cancelled at tree disposal and flutter_test fails the test on it. A fourth trap: awaiting a drift-backed stream (`.first`, `await for`) inside the body resumes it outside the FakeAsync zone and strands every later pump. The exemplars apply the verified recipe (tree-owned blocs, `unawaited` closes in `tearDown`, explicit `_unmount` + `pump(Duration.zero)`, assertions through `read()` instead of stream awaits); the plan-challenge reviewers ran the whole slice green with it (full gate 1m12s). If anything still hangs for the executor, the diagnosis is one of those four awaits, not the fake repository or `pumpAndSettle`.
- **Web runtime:** the production library is web-compilable (no `dart:ffi` path) and `AppDatabase.open` passes the mandatory `DriftWebOptions`, but the two assets they name (`sqlite3.wasm`, `drift_worker.js`) are not shipped in M3: `flutter build web` succeeds, the settings page on web fails to open its database until M5 adds the assets + a web runtime smoke (carryover). Android/iOS/macOS/Linux/Windows persist through the native path.
- **Bootstrap smoke through `runApp`:** the boot test drives the real `bootstrap()` (binding + `runApp`) inside `patrolWidgetTest`; `runApp` under the test binding attaches to the tester's tree, but this exact combination was not run during the research pass — if it misbehaves, fall back to pumping `App(dependencies: deps)` and keep `bootstrap()` covered by an analyzer-only guarantee, recording the gap here.
- **iOS entitlements wiring by sed:** `CODE_SIGN_ENTITLEMENTS` is inserted into three pbxproj blocks by pattern; `flutter build ios --simulator --debug` in Task 6 is the proof it still builds.
- **`flutter_bloc` age:** 9.1.1 / bloc_test 10.0.0 are the newest on pub.dev; no action.
