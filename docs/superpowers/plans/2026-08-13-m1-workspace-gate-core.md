# M1 — Workspace + Gate Core: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A resolvable Dart pub workspace with two pure base packages, the machine-readable package graph, both deterministic validators, the tiered quality gate (`checks.sh --fast` / full), toolchain fixture tests, and CI — all green.

**Architecture:** Everything derives from two files: the root `pubspec.yaml` `workspace:` list (package discovery) and `docs/reference/package_graph.yaml` (dependency rules). Validators are pure-logic Dart in `tool/src/` with thin entrypoints in `tool/`, fixture-tested from root `test/`. Shell scripts orchestrate; they own no rules.

**Tech Stack:** Dart (pinned via `.fvmrc`), bash, `path` + `yaml` + `test` as the only root dependencies, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` (§2, §3, §5, §6, §11, §16-M1). On conflict, the spec wins.

## Global Constraints

- English only in every shipped file (code, comments, docs, commit messages).
- No credentials, no product-specific values; placeholder URLs use `template.invalid`.
- Prose docs get a gitignored Russian twin `<name>.ru.md` (rule in CLAUDE.local.md); machine files (YAML, code) do not.
- Flutter pin: `.fvmrc` with the latest stable (known-good floor `3.41.5`; verify at execution with `fvm releases` and use the newest stable; root `environment: sdk:` must match that Flutter's Dart).
- Workspace root package name: `alatyr_workspace`. Base packages are product-neutral and never renamed by init.
- `app_core` and `app_config` are pure Dart: no `flutter`/`flutter_test` anywhere in their pubspecs or imports.
- Bash: `set -euo pipefail` in every script; every analyze/test invocation wrapped in `run_guarded` (analyze 180 s, test 300 s, overridable via `CHECKS_ANALYZE_TIMEOUT`/`CHECKS_TEST_TIMEOUT`).
- CI detection: truthy `CI` env var (`CI` set, not `false`, not `0`).
- Explicit M1 seams (deferred stages, added by later milestones): lint-plugin stages (M2), critical-flows registry check (M5), codegen stage ships now but no-ops until a package declares `build_runner` (M3).
- Commit messages: conventional (`feat:`, `chore:`, `test:`…), each ends with the Claude co-author trailer.

---

### Task 1: Repo scaffold + root workspace

**Files:**
- Create: `.fvmrc`, `LICENSE`, `README.md`, `pubspec.yaml`, `analysis_options.yaml`
- Modify: `.gitignore`

**Interfaces:**
- Produces: root workspace with `workspace:` list `[packages/app_core, packages/app_config]` (Tasks 2–8 rely on it); root deps `path`, `yaml`, dev-dep `test` (used by all `tool/` code and root tests).

- [ ] **Step 1: Pin Flutter/Dart**

Run: `fvm releases | tail -20` — pick the newest stable (floor `3.41.5`). Write `.fvmrc`:

```json
{"flutter": "3.41.5"}
```

Run `fvm use 3.41.5 && fvm dart --version` and note the Dart major.minor (e.g. `3.10`) for Step 2.

- [ ] **Step 2: Write root files**

`pubspec.yaml`:

```yaml
name: alatyr_workspace
description: Alatyr - Flutter starter for AI-agent development. Workspace root.
publish_to: none
environment:
  sdk: ^3.10.0   # match the Dart bundled with .fvmrc's Flutter
workspace:
  - packages/app_core
  - packages/app_config
dependencies:
  path: ^1.9.0
  yaml: ^3.1.2
dev_dependencies:
  test: ^1.25.0
```

`analysis_options.yaml`:

```yaml
analyzer:
  language:
    strict-casts: true
    strict-inference: true
    strict-raw-types: true
```

`LICENSE`: standard MIT text, copyright line `Copyright (c) 2026 Alatyr contributors`.

`README.md` (stub; the full README is M4):

```markdown
# Alatyr

Flutter starter for AI-agent development: Claude Code implements, Codex
cross-reviews. Under construction — see
`docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md`.
```

Append to `.gitignore`:

```
.dart_tool/
build/
pubspec.lock
!/pubspec.lock
```

(Root `pubspec.lock` is committed for reproducible tooling; package-level locks don't exist in a workspace.)

- [ ] **Step 3: Verify resolution fails only on missing members**

Run: `fvm dart pub get`
Expected: FAIL mentioning `packages/app_core` (listed member missing) — proves the workspace list is read. (Task 2 makes it pass.)

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "chore: root workspace, toolchain pin, license"
```

---

### Task 2: app_core (pure Dart base package)

**Files:**
- Create: `packages/app_core/pubspec.yaml`, `packages/app_core/lib/app_core.dart`, `packages/app_core/lib/src/app_failure.dart`, `packages/app_core/lib/src/result.dart`, `packages/app_core/lib/src/logging.dart`
- Test: `packages/app_core/test/result_test.dart`, `packages/app_core/test/logging_test.dart`

**Interfaces:**
- Produces: `AppFailure({required String code, required String message, Object? cause})` value type; `sealed Result<T>` with `Ok(T value)` / `Err(AppFailure failure)`, members `isOk`, `valueOrNull`, `failureOrNull`, `R fold<R>({required R Function(T) ok, required R Function(AppFailure) err})`; `abstract AppLogger` with `debug/info/warn/error(String message, {Object? error, StackTrace? stackTrace})`, plus `ConsoleLogger` and `NoopLogger`. Task 3 and all later milestones consume these exact names.

- [ ] **Step 1: Package skeleton**

`packages/app_core/pubspec.yaml`:

```yaml
name: app_core
description: Pure Dart core - failures, results, logging facade.
publish_to: none
resolution: workspace
environment:
  sdk: ^3.10.0
dev_dependencies:
  test: ^1.25.0
```

`lib/app_core.dart`:

```dart
export 'src/app_failure.dart';
export 'src/logging.dart';
export 'src/result.dart';
```

- [ ] **Step 2: Write the failing tests**

`test/result_test.dart`:

```dart
import 'package:app_core/app_core.dart';
import 'package:test/test.dart';

void main() {
  const failure = AppFailure(code: 'demo.failed', message: 'demo');

  test('Ok exposes value and folds through ok branch', () {
    const Result<int> r = Ok(42);
    expect(r.isOk, isTrue);
    expect(r.valueOrNull, 42);
    expect(r.failureOrNull, isNull);
    expect(r.fold(ok: (v) => v + 1, err: (_) => 0), 43);
  });

  test('Err exposes failure and folds through err branch', () {
    const Result<int> r = Err(failure);
    expect(r.isOk, isFalse);
    expect(r.valueOrNull, isNull);
    expect(r.failureOrNull, failure);
    expect(r.fold(ok: (_) => 'ok', err: (f) => f.code), 'demo.failed');
  });

  test('AppFailure equality is by code and message', () {
    expect(failure, const AppFailure(code: 'demo.failed', message: 'demo'));
    expect(failure, isNot(const AppFailure(code: 'demo.failed', message: 'x')));
  });
}
```

`test/logging_test.dart`:

```dart
import 'package:app_core/app_core.dart';
import 'package:test/test.dart';

final class _RecordingLogger extends AppLogger {
  final List<String> lines = [];
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    lines.add('${level.name}: $message');
  }
}

void main() {
  test('level helpers delegate to log', () {
    final logger = _RecordingLogger()
      ..debug('d')
      ..info('i')
      ..warn('w')
      ..error('e');
    expect(logger.lines, ['debug: d', 'info: i', 'warn: w', 'error: e']);
  });

  test('NoopLogger swallows everything', () {
    expect(() => const NoopLogger().error('boom'), returnsNormally);
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd packages/app_core && fvm dart pub get && fvm dart test`
Expected: FAIL — types not defined.

- [ ] **Step 4: Implement**

`lib/src/app_failure.dart`:

```dart
/// Stable, machine-readable failure value carried across layer boundaries.
final class AppFailure {
  const AppFailure({required this.code, required this.message, this.cause});

  /// Stable code, `<area>.<reason>` (e.g. `config.invalid-url`).
  final String code;
  final String message;
  final Object? cause;

  @override
  bool operator ==(Object other) =>
      other is AppFailure && other.code == code && other.message == message;

  @override
  int get hashCode => Object.hash(code, message);

  @override
  String toString() => 'AppFailure($code: $message)';
}
```

`lib/src/result.dart`:

```dart
import 'app_failure.dart';

sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;
  T? get valueOrNull => switch (this) { Ok(:final value) => value, Err() => null };
  AppFailure? get failureOrNull =>
      switch (this) { Ok() => null, Err(:final failure) => failure };

  R fold<R>({
    required R Function(T value) ok,
    required R Function(AppFailure failure) err,
  }) =>
      switch (this) {
        Ok(:final value) => ok(value),
        Err(:final failure) => err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final AppFailure failure;
}
```

`lib/src/logging.dart`:

```dart
enum LogLevel { debug, info, warn, error }

abstract class AppLogger {
  const AppLogger();

  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace});

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warn(String message, {Object? error}) =>
      log(LogLevel.warn, message, error: error);
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      log(LogLevel.error, message, error: error, stackTrace: stackTrace);
}

final class ConsoleLogger extends AppLogger {
  const ConsoleLogger();
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {
    // ignore: avoid_print - the console IS this logger's sink.
    print('[${level.name}] $message${error == null ? '' : ' | $error'}');
  }
}

final class NoopLogger extends AppLogger {
  const NoopLogger();
  @override
  void log(LogLevel level, String message, {Object? error, StackTrace? stackTrace}) {}
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm dart test` (in `packages/app_core`)
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/app_core && git commit -m "feat(app_core): failures, results, logging facade"
```

---

### Task 3: app_config (pure Dart base package)

**Files:**
- Create: `packages/app_config/pubspec.yaml`, `packages/app_config/lib/app_config.dart`, `packages/app_config/lib/src/app_config.dart`
- Test: `packages/app_config/test/app_config_test.dart`

**Interfaces:**
- Consumes: `Result`, `Ok`, `Err`, `AppFailure` from `app_core` (Task 2).
- Produces: `enum AppEnv { dev, staging, prod }`; `AppConfig({required AppEnv env, required Uri apiBaseUrl})`; `static Result<AppConfig> parse({required String env, required String apiBaseUrl})` (failure codes `config.invalid-env`, `config.invalid-url`); `factory AppConfig.fromEnvironment()` reading dart-defines `APP_ENV` (default `dev`) and `API_BASE_URL` (default `https://template.invalid`), throwing `StateError` on invalid values (compile-time defines are a build bug, not a runtime state).

- [ ] **Step 1: Package skeleton**

`packages/app_config/pubspec.yaml`:

```yaml
name: app_config
description: Typed application config from compile-time dart-defines.
publish_to: none
resolution: workspace
environment:
  sdk: ^3.10.0
dependencies:
  app_core: any   # workspace member; version governed by the workspace
dev_dependencies:
  test: ^1.25.0
```

`lib/app_config.dart`: `export 'src/app_config.dart';`

- [ ] **Step 2: Write the failing tests**

`test/app_config_test.dart`:

```dart
import 'package:app_config/app_config.dart';
import 'package:test/test.dart';

void main() {
  test('parse accepts valid env and https url', () {
    final r = AppConfig.parse(env: 'staging', apiBaseUrl: 'https://api.example.com');
    expect(r.isOk, isTrue);
    final config = r.valueOrNull!;
    expect(config.env, AppEnv.staging);
    expect(config.apiBaseUrl, Uri.parse('https://api.example.com'));
  });

  test('parse rejects unknown env with stable code', () {
    final r = AppConfig.parse(env: 'qa', apiBaseUrl: 'https://api.example.com');
    expect(r.failureOrNull?.code, 'config.invalid-env');
  });

  test('parse rejects non-absolute url with stable code', () {
    final r = AppConfig.parse(env: 'dev', apiBaseUrl: 'not a url');
    expect(r.failureOrNull?.code, 'config.invalid-url');
  });

  test('fromEnvironment falls back to dev + template.invalid', () {
    final config = AppConfig.fromEnvironment();
    expect(config.env, AppEnv.dev);
    expect(config.apiBaseUrl.host, 'template.invalid');
  });
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `cd packages/app_config && fvm dart pub get && fvm dart test`
Expected: FAIL — types not defined.

- [ ] **Step 4: Implement**

`lib/src/app_config.dart`:

```dart
import 'package:app_core/app_core.dart';

enum AppEnv { dev, staging, prod }

final class AppConfig {
  const AppConfig({required this.env, required this.apiBaseUrl});

  final AppEnv env;
  final Uri apiBaseUrl;

  static Result<AppConfig> parse({
    required String env,
    required String apiBaseUrl,
  }) {
    final parsedEnv =
        AppEnv.values.where((e) => e.name == env).firstOrNull;
    if (parsedEnv == null) {
      return Err(AppFailure(
        code: 'config.invalid-env',
        message: 'APP_ENV must be one of ${AppEnv.values.map((e) => e.name)}, got "$env"',
      ));
    }
    final url = Uri.tryParse(apiBaseUrl);
    if (url == null || !url.isAbsolute) {
      return Err(AppFailure(
        code: 'config.invalid-url',
        message: 'API_BASE_URL must be an absolute URL, got "$apiBaseUrl"',
      ));
    }
    return Ok(AppConfig(env: parsedEnv, apiBaseUrl: url));
  }

  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const apiBaseUrl =
        String.fromEnvironment('API_BASE_URL', defaultValue: 'https://template.invalid');
    return parse(env: env, apiBaseUrl: apiBaseUrl).fold(
      ok: (config) => config,
      err: (f) => throw StateError('Invalid build configuration: $f'),
    );
  }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm dart test` (in `packages/app_config`)
Expected: PASS (4 tests). Also run root `fvm dart pub get` — the workspace now resolves.

- [ ] **Step 6: Commit**

```bash
git add packages/app_config && git commit -m "feat(app_config): typed config from dart-defines"
```

---

### Task 4: package_graph.yaml + graph loader

**Files:**
- Create: `docs/reference/package_graph.yaml`, `tool/src/graph.dart`
- Test: `test/graph_test.dart`, fixtures `test/fixtures/graphs/valid.yaml`, `test/fixtures/graphs/unknown_kind.yaml`, `test/fixtures/graphs/dangling_dep.yaml`

**Interfaces:**
- Produces: `PackageGraph { List<String> packageKinds; Map<String, String> bannedPackages; Set<String> pureDartPackages; Map<String, PackageNode> packages; }`, `PackageNode { String kind; List<String> allowedDependencies; bool allowsAllMembers; }`, `PackageGraph loadPackageGraph(String yamlSource, {required String sourcePath})` throwing `GraphFormatException(String message)` on structural errors. Sentinel `"*_all_members"` sets `allowsAllMembers`. Tasks 5–6 consume exactly these names.

- [ ] **Step 1: Write the real graph**

`docs/reference/package_graph.yaml`:

```yaml
# THE machine-readable source of truth for architecture rules.
# Semantics (spec section 6):
#   - allowed_dependencies lists WORKSPACE MEMBERS only.
#   - Third-party deps are governed solely by banned_packages below.
#   - SDK deps (flutter, flutter_test) are forbidden in pure_dart_packages.
#   - Keys are package names; the app entry is renamed by tool/init.dart.
package_kinds: [base, feature_api, feature_impl, app_root]

banned_packages:
  get_it: "manual constructor DI (spec section 5)"
  injectable: "manual constructor DI (spec section 5)"
  riverpod: "bloc is the canonical state management"
  flutter_riverpod: "bloc is the canonical state management"
  provider: "bloc is the canonical state management"
  get: "bloc is the canonical state management"
  mobx: "bloc is the canonical state management"
  auto_route: "go_router is the canonical navigation"
  hive: "drift is the canonical local database"
  isar: "drift is the canonical local database"
  built_value: "freezed is the canonical codegen model library"
  mockito: "mocktail is the canonical test-double library (no codegen mocks)"

pure_dart_packages: [app_core, app_config]

packages:
  app_core:   { kind: base, allowed_dependencies: [] }
  app_config: { kind: base, allowed_dependencies: [app_core] }
```

- [ ] **Step 2: Write fixtures + failing tests**

`test/fixtures/graphs/valid.yaml` — copy of the real graph above.
`test/fixtures/graphs/unknown_kind.yaml` — same but `app_core: { kind: cosmic, allowed_dependencies: [] }`.
`test/fixtures/graphs/dangling_dep.yaml` — same but `app_config: { kind: base, allowed_dependencies: [ghost_pkg] }`.

`test/graph_test.dart`:

```dart
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
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `fvm dart test test/graph_test.dart` (from root)
Expected: FAIL — `tool/src/graph.dart` does not exist.

- [ ] **Step 4: Implement the loader**

`tool/src/graph.dart`:

```dart
import 'package:yaml/yaml.dart';

const String allMembersSentinel = '*_all_members';

final class GraphFormatException implements Exception {
  GraphFormatException(this.message);
  final String message;
  @override
  String toString() => 'GraphFormatException: $message';
}

final class PackageNode {
  const PackageNode({
    required this.kind,
    required this.allowedDependencies,
    required this.allowsAllMembers,
  });
  final String kind;
  final List<String> allowedDependencies;
  final bool allowsAllMembers;
}

final class PackageGraph {
  const PackageGraph({
    required this.packageKinds,
    required this.bannedPackages,
    required this.pureDartPackages,
    required this.packages,
  });
  final List<String> packageKinds;
  final Map<String, String> bannedPackages;
  final Set<String> pureDartPackages;
  final Map<String, PackageNode> packages;
}

PackageGraph loadPackageGraph(String yamlSource, {required String sourcePath}) {
  final root = loadYaml(yamlSource);
  if (root is! YamlMap) {
    throw GraphFormatException('$sourcePath: top level must be a map');
  }
  final kinds = [
    for (final k in _req<YamlList>(root, 'package_kinds', sourcePath)) k.toString(),
  ];
  final banned = <String, String>{
    for (final e in _req<YamlMap>(root, 'banned_packages', sourcePath).entries)
      e.key.toString(): e.value.toString(),
  };
  final pure = {
    for (final k in _req<YamlList>(root, 'pure_dart_packages', sourcePath))
      k.toString(),
  };
  final rawPackages = _req<YamlMap>(root, 'packages', sourcePath);
  final packages = <String, PackageNode>{};
  for (final entry in rawPackages.entries) {
    final name = entry.key.toString();
    final value = entry.value;
    if (value is! YamlMap) {
      throw GraphFormatException('$sourcePath: packages.$name must be a map');
    }
    final kind = value['kind']?.toString();
    if (kind == null || !kinds.contains(kind)) {
      throw GraphFormatException(
          '$sourcePath: packages.$name has unknown kind "$kind"');
    }
    final rawDeps = value['allowed_dependencies'];
    final allowsAll = rawDeps is String && rawDeps == allMembersSentinel;
    final deps = allowsAll
        ? const <String>[]
        : rawDeps is YamlList
            ? [for (final d in rawDeps) d.toString()]
            : throw GraphFormatException(
                '$sourcePath: packages.$name.allowed_dependencies must be a '
                'list or "$allMembersSentinel"');
    packages[name] = PackageNode(
        kind: kind, allowedDependencies: deps, allowsAllMembers: allowsAll);
  }
  for (final entry in packages.entries) {
    for (final dep in entry.value.allowedDependencies) {
      if (!packages.containsKey(dep)) {
        throw GraphFormatException(
            '$sourcePath: packages.${entry.key} allows unknown package "$dep"');
      }
    }
  }
  for (final name in pure) {
    if (!packages.containsKey(name)) {
      throw GraphFormatException(
          '$sourcePath: pure_dart_packages lists unknown package "$name"');
    }
  }
  return PackageGraph(
    packageKinds: kinds,
    bannedPackages: banned,
    pureDartPackages: pure,
    packages: packages,
  );
}

T _req<T>(YamlMap map, String key, String sourcePath) {
  final value = map[key];
  if (value is! T) {
    throw GraphFormatException('$sourcePath: "$key" missing or wrong type');
  }
  return value;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm dart test test/graph_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add docs/reference/package_graph.yaml tool/src/graph.dart test/
git commit -m "feat(tool): package graph source of truth + loader"
```

---

### Task 5: Dependency validator (pubspec level)

**Files:**
- Create: `tool/src/dependency_validator.dart`, `tool/verify_dependencies.dart`
- Test: `test/dependency_validator_test.dart`, fixture workspaces under `test/fixtures/workspaces/`

**Interfaces:**
- Consumes: `loadPackageGraph`, `PackageGraph`, `allMembersSentinel` (Task 4).
- Produces: `List<String> validateDependencies({required String rootDir})` returning human-readable violations (empty = clean), and CLI `dart run tool/verify_dependencies.dart` (exit 0 clean / 1 violations, one per line, `path: message` format). Task 8's `checks.sh` calls the CLI.

**Rules implemented (spec §6):** (1) every workspace member's name appears in the graph and vice versa — checked both ways; (2) a dependency on another workspace member must be in `allowed_dependencies` (or the member `allowsAllMembers`) — checked in `dependencies` AND `dev_dependencies`; (3) any dependency named in `banned_packages` is a violation (both sections), message includes the reason; (4) a `pure_dart_packages` member must not declare `flutter`/`flutter_test` SDK deps (both sections) and must not depend on a non-pure workspace member.

- [ ] **Step 1: Build fixture workspaces**

Create minimal synthetic workspaces (each: root `pubspec.yaml` with `workspace:`, a `graph.yaml`, and member dirs with only `pubspec.yaml`):

- `test/fixtures/workspaces/clean/` — two members `a` (base, `[]`, pure) and `b` (base, `[a]`), `b` depends on `a`. Expect: no violations.
- `test/fixtures/workspaces/forbidden_edge/` — `b` depends on `a`, but graph gives `b` `allowed_dependencies: []`. Expect: 1 violation naming `b`, `a`.
- `test/fixtures/workspaces/banned_dep/` — `b` declares `get_it: ^8.0.0` in `dependencies` and `mockito: ^5.0.0` in `dev_dependencies`; graph bans both. Expect: 2 violations, each quoting the reason.
- `test/fixtures/workspaces/graph_drift/` — workspace lists member `c` absent from graph, and graph has entry `ghost` with no directory. Expect: 2 violations.
- `test/fixtures/workspaces/impure/` — pure member `a` declares `flutter: {sdk: flutter}`, and pure member `p` depends on non-pure member `b`. Expect: 2 violations.

Example member pubspec (`clean/packages/b/pubspec.yaml`):

```yaml
name: b
publish_to: none
resolution: workspace
environment: { sdk: ^3.10.0 }
dependencies:
  a: any
```

Example fixture root (`clean/pubspec.yaml`):

```yaml
name: fixture_workspace
publish_to: none
environment: { sdk: ^3.10.0 }
workspace: [packages/a, packages/b]
```

Each fixture's `graph.yaml` follows the real schema (reuse the kinds/banned lists from Task 4's valid fixture, adjusting `packages:`/`pure_dart_packages:` per case).

- [ ] **Step 2: Write the failing test**

`test/dependency_validator_test.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/dependency_validator.dart';

String ws(String name) => p.join('test', 'fixtures', 'workspaces', name);

void main() {
  test('clean workspace has no violations', () {
    expect(validateDependencies(rootDir: ws('clean')), isEmpty);
  });

  test('member edge not in allowed_dependencies is reported', () {
    final v = validateDependencies(rootDir: ws('forbidden_edge'));
    expect(v, hasLength(1));
    expect(v.single, allOf(contains('b'), contains('a'), contains('not allowed')));
  });

  test('banned packages are reported with reasons, in both sections', () {
    final v = validateDependencies(rootDir: ws('banned_dep'));
    expect(v, hasLength(2));
    expect(v.join('\n'), allOf(contains('get_it'), contains('mockito'),
        contains('manual constructor DI')));
  });

  test('graph and workspace membership are checked both ways', () {
    final v = validateDependencies(rootDir: ws('graph_drift'));
    expect(v.join('\n'), allOf(contains('c'), contains('ghost')));
    expect(v, hasLength(2));
  });

  test('pure packages may not touch Flutter or non-pure members', () {
    final v = validateDependencies(rootDir: ws('impure'));
    expect(v.join('\n'), allOf(contains('flutter'), contains('non-pure')));
    expect(v, hasLength(2));
  });
}
```

Note: fixture workspaces keep the graph at `<root>/graph.yaml`; `validateDependencies` takes `graphPath` with default `docs/reference/package_graph.yaml` and the tests pass `graph.yaml` — add the named parameter `String graphPath = 'docs/reference/package_graph.yaml'` and in tests call with `graphPath: 'graph.yaml'` (relative to `rootDir`). Update the test calls accordingly:
`validateDependencies(rootDir: ws('clean'), graphPath: 'graph.yaml')` — same for all five.

- [ ] **Step 3: Run test to verify it fails**

Run: `fvm dart test test/dependency_validator_test.dart`
Expected: FAIL — validator not defined.

- [ ] **Step 4: Implement**

`tool/src/dependency_validator.dart`:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'graph.dart';

List<String> validateDependencies({
  required String rootDir,
  String graphPath = 'docs/reference/package_graph.yaml',
}) {
  final violations = <String>[];
  final graphFile = File(p.join(rootDir, graphPath));
  final graph = loadPackageGraph(graphFile.readAsStringSync(),
      sourcePath: graphFile.path);

  final rootPubspec =
      loadYaml(File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
  final memberPaths = [
    for (final m in rootPubspec['workspace'] as YamlList? ?? YamlList()) m.toString(),
  ];

  final membersByName = <String, String>{}; // name -> dir
  for (final memberPath in memberPaths) {
    final pubspecFile = File(p.join(rootDir, memberPath, 'pubspec.yaml'));
    final pubspec = loadYaml(pubspecFile.readAsStringSync()) as YamlMap;
    membersByName[pubspec['name'].toString()] = memberPath;
  }

  for (final name in membersByName.keys) {
    if (!graph.packages.containsKey(name)) {
      violations.add('${membersByName[name]}/pubspec.yaml: '
          'workspace member "$name" is missing from the package graph');
    }
  }
  for (final name in graph.packages.keys) {
    if (!membersByName.containsKey(name)) {
      violations.add('$graphPath: graph entry "$name" has no workspace member');
    }
  }

  for (final entry in membersByName.entries) {
    final name = entry.key;
    final node = graph.packages[name];
    if (node == null) continue;
    final pubspecPath = p.join(entry.value, 'pubspec.yaml');
    final pubspec =
        loadYaml(File(p.join(rootDir, pubspecPath)).readAsStringSync()) as YamlMap;
    final isPure = graph.pureDartPackages.contains(name);

    for (final section in ['dependencies', 'dev_dependencies']) {
      final deps = pubspec[section];
      if (deps is! YamlMap) continue;
      for (final dep in deps.entries) {
        final depName = dep.key.toString();
        final banReason = graph.bannedPackages[depName];
        if (banReason != null) {
          violations.add('$pubspecPath: "$depName" is banned - $banReason');
        }
        if (isPure && (depName == 'flutter' || depName == 'flutter_test')) {
          violations.add(
              '$pubspecPath: pure Dart package "$name" declares "$depName"');
        }
        if (membersByName.containsKey(depName)) {
          final allowed =
              node.allowsAllMembers || node.allowedDependencies.contains(depName);
          if (!allowed) {
            violations.add('$pubspecPath: dependency on member "$depName" is '
                'not allowed by the package graph');
          }
          if (isPure && !graph.pureDartPackages.contains(depName)) {
            violations.add('$pubspecPath: pure Dart package "$name" depends on '
                'non-pure member "$depName"');
          }
        }
      }
    }
  }
  return violations;
}
```

`tool/verify_dependencies.dart`:

```dart
import 'dart:io';
import 'src/dependency_validator.dart';

void main() {
  final violations = validateDependencies(rootDir: Directory.current.path);
  if (violations.isEmpty) {
    stdout.writeln('Dependency graph: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm dart test test/dependency_validator_test.dart` — PASS (5 tests).
Then the real repo: `fvm dart run tool/verify_dependencies.dart` — `Dependency graph: OK`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add tool/ test/ && git commit -m "feat(tool): pubspec-level dependency validator"
```

---

### Task 6: Import lexer + import validator

**Files:**
- Create: `tool/src/import_validator.dart`, `tool/verify_imports.dart`
- Test: `test/import_validator_test.dart`, fixture workspace `test/fixtures/workspaces/imports/`

**Interfaces:**
- Consumes: `loadPackageGraph` etc. (Task 4).
- Produces: `List<String> collectPackageImports(String dartSource)` (unit-testable lexer, returns imported/exported package names in order) and `List<String> validateImports({required String rootDir, String graphPath = ...})` (violations `file:line:col: message`), CLI `dart run tool/verify_imports.dart` (exit 0/1). Task 8's `checks.sh` calls the CLI.

**Rules implemented (spec §6):** boundary — an import of another workspace member must be an allowed graph edge (scanned in `lib/` only; `test/` exempt); banned — importing a `banned_packages` package is a violation in `lib/` AND `test/`; pure-core — `pure_dart_packages` members may not import `package:flutter*` or `dart:ui` (in `lib/`); secret-leak heuristic — in a member named `data_local`, `lib/` declarations matching identifier regex `(token|secret|password|credential)` (case-insensitive) are violations pointing to `data_secure`. Lexer must ignore directives inside `//`, `/* */`, single/double/triple-quoted and raw strings, and must handle conditional directives (`import 'a.dart' if (dart.library.io) 'package:x/y.dart';` — every URI in the directive counts).

- [ ] **Step 1: Write the failing lexer unit tests**

`test/import_validator_test.dart` (part 1 — lexer):

```dart
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/import_validator.dart';

void main() {
  group('collectPackageImports', () {
    test('reads imports and exports', () {
      const src = '''
import 'package:a/a.dart';
export 'package:b/b.dart';
import 'dart:async';
import 'src/local.dart';
''';
      expect(collectPackageImports(src), ['a', 'b']);
    });

    test('ignores directives inside comments and strings', () {
      const src = '''
// import 'package:evil/evil.dart';
/* import 'package:evil2/e.dart'; */
const s = "import 'package:evil3/e.dart';";
const r = r"import 'package:evil4/e.dart';";
const t = \'\'\'
import 'package:evil5/e.dart';
\'\'\';
import 'package:good/g.dart';
''';
      expect(collectPackageImports(src), ['good']);
    });

    test('collects every URI of a conditional directive', () {
      const src = '''
import 'stub.dart'
    if (dart.library.io) 'package:io_impl/io.dart'
    if (dart.library.html) 'package:web_impl/web.dart';
''';
      expect(collectPackageImports(src), ['io_impl', 'web_impl']);
    });
  });
  // part 2 added in Step 4
}
```

Run: `fvm dart test test/import_validator_test.dart` — FAIL (not defined).

- [ ] **Step 2: Implement the lexer**

`tool/src/import_validator.dart` (lexer half):

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'graph.dart';

/// Package names imported/exported by [dartSource], directive-aware:
/// skips comments and string literals, follows conditional URIs.
List<String> collectPackageImports(String dartSource) =>
    [for (final d in _directives(dartSource)) ..._packagesOf(d.uris)];

final class _Directive {
  _Directive(this.line, this.col, this.uris);
  final int line;
  final int col;
  final List<String> uris;
}

Iterable<String> _packagesOf(List<String> uris) sync* {
  for (final uri in uris) {
    if (uri.startsWith('package:')) {
      yield uri.substring('package:'.length).split('/').first;
    }
  }
}

List<_Directive> _directives(String src) {
  final out = <_Directive>[];
  var i = 0, line = 1, col = 1;
  void advance([int n = 1]) {
    for (var k = 0; k < n && i < src.length; k++) {
      if (src[i] == '\n') { line++; col = 1; } else { col++; }
      i++;
    }
  }

  bool at(String s) => src.startsWith(s, i);

  void skipLineComment() { while (i < src.length && src[i] != '\n') advance(); }

  void skipBlockComment() {
    advance(2);
    var depth = 1;
    while (i < src.length && depth > 0) {
      if (at('/*')) { depth++; advance(2); }
      else if (at('*/')) { depth--; advance(2); }
      else { advance(); }
    }
  }

  /// Consumes a string literal, returns its contents (null for interpolated
  /// complexity we don't need - directive URIs are always simple).
  String? readString() {
    final raw = at('r');
    if (raw) advance();
    for (final quote in ["'''", '"""', "'", '"']) {
      if (at(quote)) {
        advance(quote.length);
        final start = i;
        while (i < src.length && !at(quote)) {
          if (!raw && src[i] == r'\') advance();
          advance();
        }
        final value = src.substring(start, i);
        advance(quote.length);
        return value;
      }
    }
    return null;
  }

  bool atKeyword(String kw) {
    if (!at(kw)) return false;
    final after = i + kw.length;
    final before = i - 1;
    final wordChar = RegExp(r'[A-Za-z0-9_$]');
    if (before >= 0 && wordChar.hasMatch(src[before])) return false;
    if (after < src.length && wordChar.hasMatch(src[after])) return false;
    return true;
  }

  while (i < src.length) {
    if (at('//')) { skipLineComment(); continue; }
    if (at('/*')) { skipBlockComment(); continue; }
    if (at("'") || at('"') || at("r'") || at('r"')) { readString(); continue; }
    if (atKeyword('import') || atKeyword('export')) {
      final dLine = line, dCol = col;
      advance(6); // both keywords are 6 chars
      final uris = <String>[];
      while (i < src.length && src[i] != ';') {
        if (at("'") || at('"') || at("r'") || at('r"')) {
          final uri = readString();
          if (uri != null) uris.add(uri);
        } else {
          advance();
        }
      }
      out.add(_Directive(dLine, dCol, uris));
      continue;
    }
    advance();
  }
  return out;
}
```

Run the lexer tests: `fvm dart test test/import_validator_test.dart` — PASS (3 tests).

- [ ] **Step 3: Fixture workspace + failing validator tests**

`test/fixtures/workspaces/imports/` — root pubspec (workspace `[packages/a, packages/b, packages/data_local]`), `graph.yaml` (all `base`; `a` pure with `allowed_dependencies: []`; `b` allows `[a]`; `data_local` allows `[]`; bans include `get_it`), members with `lib/`/`test/` Dart files:

- `packages/a/lib/a.dart` — `import 'package:flutter/widgets.dart';` (pure-core violation).
- `packages/b/lib/b.dart` — `import 'package:a/a.dart';` (allowed) and `import 'package:data_local/data_local.dart';` (edge NOT allowed → boundary violation).
- `packages/b/test/b_test.dart` — `import 'package:data_local/data_local.dart';` (test file → boundary exempt) and `import 'package:get_it/get_it.dart';` (banned → violation even in test).
- `packages/data_local/lib/dao.dart` — `class SessionDao { String? authToken; }` (secret heuristic violation).

Append to `test/import_validator_test.dart`:

```dart
  group('validateImports', () {
    final root = p.join('test', 'fixtures', 'workspaces', 'imports');
    late final List<String> v;
    setUpAll(() => v = validateImports(rootDir: root, graphPath: 'graph.yaml'));

    test('pure package importing flutter is reported', () {
      expect(v.join('\n'), contains('packages/a/lib/a.dart'));
    });
    test('disallowed member edge in lib/ is reported with position', () {
      expect(v.join('\n'),
          matches(RegExp(r'packages/b/lib/b\.dart:\d+:\d+: .*data_local')));
    });
    test('boundary rule exempts test/, banned rule does not', () {
      expect(v.join('\n'), isNot(contains('b_test.dart: import of member')));
      expect(v.join('\n'), contains('get_it'));
    });
    test('secret-shaped identifier in data_local lib is reported', () {
      expect(v.join('\n'), allOf(contains('dao.dart'), contains('data_secure')));
    });
    test('exact violation count', () => expect(v, hasLength(4)));
  });
```

Run — FAIL (`validateImports` not defined).

- [ ] **Step 4: Implement the validator half**

Append to `tool/src/import_validator.dart`:

```dart
List<String> validateImports({
  required String rootDir,
  String graphPath = 'docs/reference/package_graph.yaml',
}) {
  final violations = <String>[];
  final graph = loadPackageGraph(
      File(p.join(rootDir, graphPath)).readAsStringSync(), sourcePath: graphPath);
  final rootPubspec =
      loadYaml(File(p.join(rootDir, 'pubspec.yaml')).readAsStringSync()) as YamlMap;
  final members = <String, String>{}; // name -> dir
  for (final m in rootPubspec['workspace'] as YamlList? ?? YamlList()) {
    final dir = m.toString();
    final pubspec =
        loadYaml(File(p.join(rootDir, dir, 'pubspec.yaml')).readAsStringSync())
            as YamlMap;
    members[pubspec['name'].toString()] = dir;
  }
  final secretIdent = RegExp(r'(token|secret|password|credential)',
      caseSensitive: false);
  final declaration = RegExp(
      r'^\s*(?:final|const|var|late|String|int|double|bool|Object)\??\s+'
      r'([A-Za-z_$][A-Za-z0-9_$]*)');

  for (final entry in members.entries) {
    final name = entry.key;
    final node = graph.packages[name];
    if (node == null) continue;
    final isPure = graph.pureDartPackages.contains(name);
    for (final scope in ['lib', 'test']) {
      final dir = Directory(p.join(rootDir, entry.value, scope));
      if (!dir.existsSync()) continue;
      final inLib = scope == 'lib';
      for (final file in dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final relPath =
            p.relative(file.path, from: rootDir).replaceAll(r'\', '/');
        final src = file.readAsStringSync();
        for (final d in _directives(src)) {
          for (final pkg in _packagesOf(d.uris)) {
            final banReason = graph.bannedPackages[pkg];
            if (banReason != null) {
              violations.add(
                  '$relPath:${d.line}:${d.col}: import of banned package '
                  '"$pkg" - $banReason');
            }
            if (inLib && isPure && (pkg == 'flutter' || pkg == 'flutter_test')) {
              violations.add('$relPath:${d.line}:${d.col}: pure Dart package '
                  '"$name" imports "$pkg"');
            }
            if (inLib && members.containsKey(pkg) && pkg != name) {
              final allowed =
                  node.allowsAllMembers || node.allowedDependencies.contains(pkg);
              if (!allowed) {
                violations.add('$relPath:${d.line}:${d.col}: import of member '
                    '"$pkg" is not an allowed edge for "$name"');
              }
            }
          }
          if (inLib && isPure) {
            for (final uri in d.uris.where((u) => u == 'dart:ui')) {
              violations.add('$relPath:${d.line}:${d.col}: pure Dart package '
                  '"$name" imports "$uri"');
            }
          }
        }
        if (inLib && name == 'data_local') {
          final lines = src.split('\n');
          for (var li = 0; li < lines.length; li++) {
            final m = declaration.firstMatch(lines[li]);
            if (m != null && secretIdent.hasMatch(m.group(1)!)) {
              violations.add('$relPath:${li + 1}:1: secret-shaped identifier '
                  '"${m.group(1)}" in data_local - runtime secrets belong in '
                  'data_secure (spec invariant 4)');
            }
          }
        }
      }
    }
  }
  return violations;
}
```

`tool/verify_imports.dart`:

```dart
import 'dart:io';
import 'src/import_validator.dart';

void main() {
  final violations = validateImports(rootDir: Directory.current.path);
  if (violations.isEmpty) {
    stdout.writeln('Architecture imports: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `fvm dart test test/import_validator_test.dart` — PASS (8 tests).
Real repo: `fvm dart run tool/verify_imports.dart` — `Architecture imports: OK`.

- [ ] **Step 6: Commit**

```bash
git add tool/ test/ && git commit -m "feat(tool): deterministic import lexer + validator"
```

---

### Task 7: Checks plan builder

**Files:**
- Create: `tool/src/checks_workspace.dart`, `tool/checks_workspace.dart`
- Test: `test/checks_workspace_test.dart`, fixture `test/fixtures/workspaces/plan/`

**Interfaces:**
- Consumes: nothing from earlier tasks (reads pubspecs directly).
- Produces: `List<ChecksPackage> buildChecksPlan(String rootDir)` where `ChecksPackage { String path; bool isFlutter; bool hasTests; }`; `List<String> buildCodegenPlan(String rootDir)` (member paths declaring `build_runner`, root included if it declares it); `String formatChecksPlanLine(ChecksPackage p)` → `flutter|dart<TAB>path<TAB>true|false`; CLI `dart run tool/checks_workspace.dart [--codegen]` printing one line per entry. Task 8 parses these exact lines.

**Rules:** a member is Flutter iff its pubspec `environment:` contains `flutter:` or any deps section has an `sdk: flutter` dependency; `hasTests` iff `test/` contains `*_test.dart` recursively; plan covers workspace members only (root toolchain tests are a dedicated gate stage).

- [ ] **Step 1: Fixture + failing tests**

`test/fixtures/workspaces/plan/` — root pubspec (workspace `[packages/pure, packages/flutterish, packages/gen]`); `pure` (no flutter, has `test/pure_test.dart`), `flutterish` (deps `flutter: {sdk: flutter}`, no test dir), `gen` (dev_dep `build_runner: any`, has `test/gen_test.dart`).

`test/checks_workspace_test.dart`:

```dart
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import '../tool/src/checks_workspace.dart';

void main() {
  final root = p.join('test', 'fixtures', 'workspaces', 'plan');

  test('plan classifies runner and test presence per member', () {
    final lines = buildChecksPlan(root).map(formatChecksPlanLine).toList();
    expect(lines, [
      'dart\tpackages/pure\ttrue',
      'flutter\tpackages/flutterish\tfalse',
      'dart\tpackages/gen\ttrue',
    ]);
  });

  test('codegen plan lists only build_runner packages', () {
    expect(buildCodegenPlan(root), ['packages/gen']);
  });
}
```

Run — FAIL.

- [ ] **Step 2: Implement**

`tool/src/checks_workspace.dart`:

```dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final class ChecksPackage {
  const ChecksPackage(
      {required this.path, required this.isFlutter, required this.hasTests});
  final String path;
  final bool isFlutter;
  final bool hasTests;
}

String formatChecksPlanLine(ChecksPackage pkg) =>
    '${pkg.isFlutter ? 'flutter' : 'dart'}\t${pkg.path}\t${pkg.hasTests}';

List<ChecksPackage> buildChecksPlan(String rootDir) => [
      for (final dir in _memberDirs(rootDir))
        ChecksPackage(
          path: dir,
          isFlutter: _isFlutter(_pubspec(rootDir, dir)),
          hasTests: _hasTests(Directory(p.join(rootDir, dir, 'test'))),
        ),
    ];

List<String> buildCodegenPlan(String rootDir) => [
      if (_declaresBuildRunner(_pubspec(rootDir, '.'))) '.',
      for (final dir in _memberDirs(rootDir))
        if (_declaresBuildRunner(_pubspec(rootDir, dir))) dir,
    ];

List<String> _memberDirs(String rootDir) {
  final workspace = _pubspec(rootDir, '.')['workspace'];
  if (workspace is! YamlList) {
    throw StateError('Root pubspec.yaml must contain a workspace list.');
  }
  return [for (final m in workspace) m.toString()];
}

YamlMap _pubspec(String rootDir, String dir) =>
    loadYaml(File(p.join(rootDir, dir, 'pubspec.yaml')).readAsStringSync())
        as YamlMap;

bool _isFlutter(YamlMap pubspec) {
  final env = pubspec['environment'];
  if (env is YamlMap && env.containsKey('flutter')) return true;
  for (final section in ['dependencies', 'dev_dependencies']) {
    final deps = pubspec[section];
    if (deps is YamlMap) {
      for (final v in deps.values) {
        if (v is YamlMap && v['sdk'] == 'flutter') return true;
      }
    }
  }
  return false;
}

bool _declaresBuildRunner(YamlMap pubspec) {
  for (final section in ['dependencies', 'dev_dependencies']) {
    final deps = pubspec[section];
    if (deps is YamlMap && deps.containsKey('build_runner')) return true;
  }
  return false;
}

bool _hasTests(Directory testDir) =>
    testDir.existsSync() &&
    testDir
        .listSync(recursive: true)
        .whereType<File>()
        .any((f) => f.path.endsWith('_test.dart'));
```

`tool/checks_workspace.dart`:

```dart
import 'dart:io';
import 'src/checks_workspace.dart';

void main(List<String> args) {
  final root = Directory.current.path;
  if (args.contains('--codegen')) {
    buildCodegenPlan(root).forEach(stdout.writeln);
    return;
  }
  buildChecksPlan(root).map(formatChecksPlanLine).forEach(stdout.writeln);
}
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `fvm dart test test/checks_workspace_test.dart` — PASS (2 tests).

- [ ] **Step 4: Commit**

```bash
git add tool/ test/ && git commit -m "feat(tool): checks + codegen plan builder"
```

---

### Task 8: common.sh + codegen.sh + checks.sh (the tiered gate)

**Files:**
- Create: `tool/common.sh`, `tool/codegen.sh`, `tool/checks.sh`

**Interfaces:**
- Consumes: CLIs from Tasks 5–7 (`verify_dependencies.dart`, `verify_imports.dart`, `checks_workspace.dart [--codegen]`, plan-line format `runner\tpath\thasTests`).
- Produces: `tool/checks.sh [--fast|--package <path>]` — THE gate; `tool/codegen.sh` (workspace resolve + per-package build_runner, silent no-op when the codegen plan is empty); `tool/common.sh` sourced helpers `run_guarded`, `run_dart`, `run_flutter`, `is_ci`. Later milestones append stages here (M2: lints; M5: critical-flows check).

- [ ] **Step 1: Write `tool/common.sh`**

```bash
#!/usr/bin/env bash
# Shared helpers for tool/*.sh: fvm-first dart/flutter and hard wall-clock
# timeouts. flutter/dart test --timeout does NOT catch teardown hangs, and
# analyzer plugins can hang in child processes - so every analyze/test call
# is bounded at the OS level and a failure names the offending package.
set -euo pipefail

CHECKS_TEST_TIMEOUT="${CHECKS_TEST_TIMEOUT:-300}"
CHECKS_ANALYZE_TIMEOUT="${CHECKS_ANALYZE_TIMEOUT:-180}"

is_ci() { [[ -n "${CI:-}" && "${CI}" != "false" && "${CI}" != "0" ]]; }

run_guarded() {
  local seconds="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 10 "$seconds" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 10 "$seconds" "$@"
  else
    # Fallback (bare macOS): perl alarm. Does not kill grandchildren as
    # reliably as timeout -k; brew install coreutils for the robust path.
    perl -e 'my $s = shift @ARGV; alarm $s; exec @ARGV or die "exec: $!"' \
      "$seconds" "$@"
  fi
}

_tool() { # _tool <dart|flutter> <args...>
  local bin="$1"; shift
  local cmd=("$bin")
  command -v fvm >/dev/null 2>&1 && cmd=(fvm "$bin")
  case "${1:-}" in
    test)    run_guarded "$CHECKS_TEST_TIMEOUT" "${cmd[@]}" "$@" ;;
    analyze) run_guarded "$CHECKS_ANALYZE_TIMEOUT" "${cmd[@]}" "$@" ;;
    *)       "${cmd[@]}" "$@" ;;
  esac
}

run_dart()    { _tool dart "$@"; }
run_flutter() { _tool flutter "$@"; }
```

- [ ] **Step 2: Write `tool/codegen.sh`**

```bash
#!/usr/bin/env bash
# Workspace-wide codegen. Builders execute in the package that owns their
# sources - running build_runner only from the root silently skips member
# builders, hence the per-package plan.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"

echo "    resolve workspace dependencies"
run_dart pub get

plan="$(run_dart run tool/checks_workspace.dart --codegen)"
[[ -z "$plan" ]] && { echo "    no codegen packages - skipping"; exit 0; }

while IFS= read -r package_dir; do
  [[ -z "$package_dir" ]] && continue
  echo "    codegen ${package_dir}"
  ( cd "$ROOT_DIR/$package_dir"
    run_dart run build_runner build --low-resources-mode --delete-conflicting-outputs )
done <<<"$plan"
```

- [ ] **Step 3: Write `tool/checks.sh`**

```bash
#!/usr/bin/env bash
# THE quality gate. Tiers:
#   --fast            format + graph + imports (~seconds, agent inner loop)
#   (default: full)   fast + codegen freshness + toolchain tests
#                     + per-package analyze/test
#   --package <path>  targeted analyze+test for one workspace member
# M2 appends lint-plugin stages; M5 appends the critical-flows check.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"

MODE=full; TARGET=""
case "${1:-}" in
  --fast) MODE=fast ;;
  --package) MODE=package; TARGET="${2:?--package needs a path}" ;;
  "") ;;
  *) echo "usage: tool/checks.sh [--fast|--package <path>]" >&2; exit 2 ;;
esac

temporary_files=()
cleanup() { ((${#temporary_files[@]})) && rm -f "${temporary_files[@]}"; }
trap cleanup EXIT

# Tracked+staged diff plus content hashes of untracked files. Lets the
# freshness guard work in a dirty tree: only deltas introduced BY the gate
# (stale codegen) fail it; pre-existing edits pass through unchanged.
snapshot_worktree() {
  git diff --binary -- .
  git diff --cached --binary -- .
  while IFS= read -r -d '' file; do
    printf 'untracked:%s\0' "$file"
    git hash-object -- "$file"
  done < <(git ls-files --others --exclude-standard -z -- .)
}

analyze_and_test() { # <runner> <dir> <hasTests>
  local runner="$1" dir="$2" has_tests="$3"
  echo "    analyze ${dir}"
  ( cd "$ROOT_DIR/$dir"
    if [[ "$runner" == "flutter" ]]; then
      run_flutter analyze --no-pub --fatal-infos
      [[ "$has_tests" == "true" ]] && run_flutter test --no-pub
    else
      run_dart analyze --fatal-infos
      [[ "$has_tests" == "true" ]] && run_dart test
    fi )
}

echo "==> Formatting"
run_dart format --output=none --set-exit-if-changed .

echo "==> Dependency graph (pubspec level)"
run_dart run tool/verify_dependencies.dart

echo "==> Architecture imports (deterministic scanner)"
run_dart run tool/verify_imports.dart

[[ "$MODE" == "fast" ]] && { echo "OK (fast)"; exit 0; }

if [[ "$MODE" == "package" ]]; then
  line="$(run_dart run tool/checks_workspace.dart | awk -F'\t' -v t="$TARGET" '$2==t')"
  [[ -z "$line" ]] && { echo "Unknown workspace member: $TARGET" >&2; exit 1; }
  IFS=$'\t' read -r runner dir has_tests <<<"$line"
  analyze_and_test "$runner" "$dir" "$has_tests"
  echo "OK (package $TARGET)"; exit 0
fi

before_snapshot=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  before_snapshot="$(mktemp)"; temporary_files+=("$before_snapshot")
  snapshot_worktree >"$before_snapshot"
elif is_ci; then
  echo "FATAL: not a git worktree - codegen freshness cannot be checked in CI" >&2
  exit 1
else
  echo "WARNING: not a git worktree - codegen freshness check SKIPPED" >&2
fi

echo "==> Codegen (freshness check)"
bash "$ROOT_DIR/tool/codegen.sh"

if [[ -n "$before_snapshot" ]]; then
  after_snapshot="$(mktemp)"; temporary_files+=("$after_snapshot")
  snapshot_worktree >"$after_snapshot"
  if ! cmp -s "$before_snapshot" "$after_snapshot"; then
    echo "Generated artifacts are stale (codegen changed the tree):" >&2
    git status --short -- . >&2
    exit 1
  fi
fi

echo "==> Toolchain tests (root)"
run_dart test

echo "==> Analyze + test (per workspace package)"
while IFS=$'\t' read -r runner dir has_tests; do
  analyze_and_test "$runner" "$dir" "$has_tests"
done < <(run_dart run tool/checks_workspace.dart)

echo "OK"
```

Run: `chmod +x tool/*.sh`

- [ ] **Step 4: Verify the gate end-to-end**

- `tool/checks.sh --fast` → `OK (fast)`, ~seconds.
- `tool/checks.sh --package packages/app_core` → analyze+test of app_core only.
- `tool/checks.sh` (full) → all stages, `OK`. The codegen stage prints `no codegen packages - skipping`.
- Negative check (proves the gate bites): add `import 'package:flutter/widgets.dart';` to `packages/app_core/lib/src/result.dart`, run `tool/checks.sh --fast` — MUST fail in the imports stage; revert the edit.
- Negative check (format): add trailing spaces to any Dart file, `--fast` MUST fail; revert.

- [ ] **Step 5: Commit**

```bash
git add tool/ && git commit -m "feat(tool): tiered quality gate (checks/codegen/common)"
```

---

### Task 9: CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `tool/checks.sh` (Task 8), `.fvmrc` (Task 1).

- [ ] **Step 1: Write the workflow**

```yaml
name: CI
on:
  push: { branches: [main] }
  pull_request:
jobs:
  checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # libsqlite3 is needed by drift tests from M3 on; harmless before that.
      - run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev
      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: .fvmrc
          cache: true
      - run: tool/checks.sh
```

Note: verify at execution that the installed `subosito/flutter-action@v2` version supports `flutter-version-file` with `.fvmrc` (supported since v2.13; if not, fall back to parsing `.fvmrc` into `flutter-version` with a `jq` step). GitHub sets `CI=true`, so the gate's CI mode (freshness-skip fatal) is active automatically.

- [ ] **Step 2: Verify YAML + local CI-mode behavior**

- `fvm dart run tool/checks_workspace.dart` still prints 2 lines (sanity).
- `CI=true tool/checks.sh` locally in the repo → passes (we ARE a git worktree).
- `cd "$(mktemp -d)" && cp -R <repo>/. . && rm -rf .git && CI=true tool/checks.sh` → MUST fail with the FATAL not-a-git-worktree message (proves CI hard-error path). Clean up the temp dir.

- [ ] **Step 3: Commit**

```bash
git add .github && git commit -m "ci: run the canonical gate on ubuntu"
```

---

### Task 10: M1 wrap-up

**Files:**
- Modify: `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` (status line only)

- [ ] **Step 1: Full gate, clean tree**

Run: `git status --short` (empty) then `tool/checks.sh` → `OK`.

- [ ] **Step 2: Update spec status**

Change the spec's Status line to: `Status: approved; implementation in progress (M1 done)`. Mirror the same line in the `.ru.md` twin.

- [ ] **Step 3: Commit + report**

```bash
git add -A && git commit -m "chore: mark M1 complete in spec status"
```

Produce the M1 completion report with a mandatory **Remaining risks** section (per spec §4). Known candidates to carry into it: `subosito/flutter-action` `.fvmrc` support unverified until first push; CI green unverified until the repo has a GitHub remote; perl-alarm fallback kills process groups less reliably than `timeout -k`.

---

## Self-review notes (per writing-plans checklist)

- **Spec coverage (M1 slice):** workspace+members (§3) → T1–T3; graph schema+semantics (§6) → T4; pubspec validator (§6.1) → T5; import lexer incl. secret heuristic (§6.2) → T6; plan builder (§6, checks_workspace) → T7; tiered gate + snapshot freshness + CI detection + toolchain-tests stage (§6) → T8; ci.yml (§11) → T9. Deferred by design (Global Constraints seams): lints (M2), app/example/e2e (M3/M5), harness files (M4).
- **Type consistency:** `ChecksPackage.isFlutter` (T7) ↔ plan-line `flutter|dart` parsing (T8); `validateDependencies/validateImports(rootDir:, graphPath:)` signatures match test usage; `Result`/`AppFailure` names in T3 match T2 exports.
- **Known judgment calls:** root `pubspec.lock` committed; banned list checked in dev_dependencies too; boundary scan exempts `test/`, banned scan does not. All mirror spec §6 decisions.
