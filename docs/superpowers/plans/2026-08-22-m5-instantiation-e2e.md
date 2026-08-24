# M5 — Instantiation + e2e: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The last milestone of the spec: `dart run tool/init.dart` turns the working placeholder into a product (whole-token identity rewrite, template machinery removed, gate green), `tool/e2e.sh` runs the registered patrol critical flow on a declaratively found-or-created device, the gate checks the critical-flows registry, CI gains `e2e.yml` and `template-smoke.yml`, the web shell ships drift's assets, and the docs/spec stop saying "lands in M5".

**Architecture:** Everything derives from files that already exist: init derives the placeholder identity from the app shell (graph app entry, `applicationId`, `CFBundleDisplayName`, root pubspec name) so `tool/` stays token-free; `tool/e2e.yaml` is parsed by a typed Dart loader that `tool/e2e.sh` consumes as `KEY=value` lines; the registry check is a Dart validator with fixture tests like the other three. The patrol "restart" is the process boundary patrol itself puts between two ordered tests (Android orchestrator without `clearPackageData`, iOS per-test relaunch) — the only real process death available, documented as such.

**Tech Stack (verified in the M5 research pass on this machine):** patrol 4.9.0 ↔ patrol_cli 4.7.0 (Flutter 3.44.9; both `patrol test` runs green: iPhone 15 Pro simulator 2/2, Pixel_5 API 34 arm64 AVD 2/2); Android `compileSdk = 37` (flutter_secure_storage 11 requires it; the shipped shell did not build before) + `android.suppressUnsupportedCompileSdk=37.0`; iOS RunnerUITests target created by an `xcodeproj` Ruby script (SwiftPM, no Podfile); drift web assets `sqlite3.wasm` (sqlite3-3.5.2 release) + `drift_worker.js` (drift-2.34.3 release) — persistence on web proven with headless Chrome; init prototype: full gate green on a renamed copy (2m47s), iOS simulator build green with the new identity, Android manifest merge green.

**Spec:** `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` §8 (restart convention), §9, §10 (e2e), §11 (CI), §15, §16-M5. **Carryover:** `docs/superpowers/plans/m4-carryover.md` (M5 section — this plan closes it; the two "nits" at its end too).

**Verified reference (may be gone in a later session; the plan is self-sufficient):** `/private/tmp/claude-501/-Users-dev-Documents-projects-my-alatyr-flutter/274f6fc9-972b-474e-8cfd-9d8077742bfc/scratchpad/m5-research.md`, scratch copies `.../scratchpad/m5-patrol/repo` (patrol scaffolding applied, both runs green) and `.../scratchpad/m5-init/repo` (renamed copy, gate green).

## Global Constraints

- English only in every shipped file; the root Cyrillic scan (`test/docs_test.dart`) enforces it. Russian twins (`*.ru.md`, gitignored, local rule) for every new/edited doc, `AGENTS.md`, `README.md` — in the same task.
- Identity tokens (`alatyr_starter`, `dev.alatyr` / `dev.alatyr.starter`, `Alatyr Starter`, `alatyr_workspace`) may live only in `app/` (+ native shells, patrol scaffolding), root `pubspec.yaml`, `docs/reference/package_graph.yaml`, `README.md`, root `test/` fixtures and the docs that legitimately describe the placeholder; never in `packages/`, `lints/`, `tool/`, `.claude/`, `.codex/`, `AGENTS.md`, `CLAUDE.md` (`test/template_identity_test.dart` enforces it, extended in Task 1). `tool/init.dart` therefore DERIVES the tokens from the app shell; it never spells them.
- Init mapping (verified against `flutter create` 3.44.9): `--name my_app --org com.example [--display-name "My App"]` ⇒ Android/Linux id `com.example.my_app` (snake), iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER` `com.example.myApp` (camelCase — Apple ids forbid `_`), display name default = title case of the name (`My App`), workspace `my_app_workspace`; bundle id replaced BEFORE the bare org; `docs/adr/**` is never rewritten (ADR-0006 records the placeholder identity); `dart format` runs on every changed Dart file before `pub get` and `checks.sh --fast`.
- The e2e "restart" follows spec §8's convention — re-invoking the app entrypoint within ONE test (a fresh widget tree + DI graph; with production dependencies that means a second `AppDatabase.open` over the same on-disk file) — so the registered flow is self-contained. The same file carries a second, clearly labelled test that runs in a fresh OS process (patrol's per-test process boundary: Android orchestrator ON with `clearPackageData` OFF — verified: with it on, the second test fails; iOS relaunches per test) as a bonus check of real process death; docs say both, and which is the registered one.
- Shipped Dart snippets are written so that `dart format` is a no-op: every `if`/`for` body in braces (flutter_lints' `curly_braces_in_flow_control_structures` turns a wrapped single-line `if` into a fatal info); doc comments never contain `<...>` (`unintended_html_in_doc_comment`) — use backticks.
- Identity tokens must not appear in `tool/` even inside comments or grep patterns (the identity test is a substring scan); scripts that need them derive them (`dart run tool/init.dart --print-identity`).
- `tool/e2e.sh` never falls back to "first available device": a running emulator is reused only if `adb -s <serial> emu avd name` equals the declared AVD; otherwise the declared AVD is booted on an explicit console port and addressed by serial everywhere; `-d <id>` is always passed to patrol; missing tooling → actionable error; `fvm` gated like `tool/common.sh` (absent on CI); `patrol_cli` invoked as `dart pub global run patrol_cli:main` (fvm-first) and its version checked against the pin; in CI every device the script booted is shut down on exit.
- Generated/untracked litter: `**/test_bundle.dart`, `.patrol.env`, `**/xcshareddata/swiftpm/` are gitignored; `app/macos/Flutter/GeneratedPluginRegistrant.swift` is tracked and committed when patrol changes it.
- CI owns no logic (`docs/reference/ci_contract.md`): `e2e.yml` = environment (device inputs READ from `tool/e2e.yaml` through `tool/e2e_config.dart`, never restated) + `tool/e2e.sh android --device emulator-5554`; `template-smoke.yml` = checkout + `tool/template_smoke.sh`. `e2e.yml` is `workflow_dispatch` + PR-advisory (`continue-on-error: true`) until it has a track record on hosted runners — the spec's "verified during implementation" (§15 risk 5) cannot be met from a workstation that never pushes; stated in `ci_contract.md` and the Remaining risks.
- `patrol` needs no graph edit or ADR: it is part of the canonical stack (spec §5, "Widget/e2e tests: patrol_finders / patrol") and third-party packages are governed by the banned list only (§6); invariant 6 concerns workspace edges.
- Disk: every local `patrol test`/`flutter build` leaves 0.5–2 GB under `app/build`; delete `app/build` after each proof step. Bash timeouts 600000 ms for builds/tests/gate; `fvm dart format .` + `tool/checks.sh --fast` before every commit, full `tool/checks.sh` at the end of every task. TDD for every Dart test; conventional commits with the trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`; never push.
- Work on branch `feat/m5-instantiation-e2e` (from `main`).

---

### Task 1: Gate + tests — critical-flows validator, e2e config loader, identity test hardening, carryover nits

**Files:**
- Create: `tool/src/critical_flows.dart`, `tool/verify_critical_flows.dart`, `test/critical_flows_test.dart`, `test/fixtures/critical_flows/{ok,empty,missing,malformed}/docs/reference/critical_flows.md`, `tool/src/e2e_config.dart`, `tool/e2e_config.dart`, `tool/e2e.yaml`, `test/e2e_config_test.dart`, `test/fixtures/e2e/valid.yaml`
- Modify: `tool/checks.sh` (new stage + header), `test/docs_test.dart` (drop the registry-shape test), `test/template_identity_test.dart` (replace), `test/harness_test.dart` (git-config hardening), `.claude/skills/cross-review/codex_review.sh` (flag guard)

**Interfaces:**
- Produces: `List<String> validateCriticalFlows({required String rootDir, String registryPath})` (every `Test` path must be repo-relative, under `app/integration_test/`, end in `_test.dart`, and exist) + `parseCriticalFlows(String, {required List<String> problems})`; `E2eConfig loadE2eConfig(String yaml, {required String sourcePath})` with `defaultPlatform`, `android.{avdName, deviceProfile, apiLevel, systemImageFor(HostArch)}`, `ios.{simulatorName, deviceType, runtime}`; `dart run tool/e2e_config.dart [--platform android|ios]` prints `KEY=value` lines (`DEFAULT_PLATFORM`, `ANDROID_AVD_NAME`, `ANDROID_DEVICE_PROFILE`, `ANDROID_API_LEVEL`, `ANDROID_SYSTEM_IMAGE_ARM64`, `ANDROID_SYSTEM_IMAGE_X86_64`, `IOS_SIMULATOR_NAME`, `IOS_DEVICE_TYPE`, `IOS_RUNTIME`) for `tool/e2e.sh` to `eval`.

- [ ] **Step 1: Branch + failing tests**

```bash
git checkout -b feat/m5-instantiation-e2e main
```

`test/critical_flows_test.dart`:
```dart
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/critical_flows.dart';

String fx(String name) => p.join('test', 'fixtures', 'critical_flows', name);

void main() {
  test('every registered test exists: no violations; backticks tolerated', () {
    expect(validateCriticalFlows(rootDir: fx('ok')), isEmpty);
  });

  test('header and separator rows are skipped, rows parsed with line numbers', () {
    final problems = <String>[];
    final flows = parseCriticalFlows(
      '| Flow | Test |\n|:---|---:|\n| a | `x_test.dart` |\n',
      problems: problems,
    );
    expect(problems, isEmpty);
    expect(flows.single.name, 'a');
    expect(flows.single.testPath, 'x_test.dart');
    expect(flows.single.line, 3);
  });

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
        contains(':7: "test/graph_test.dart" is not under app/integration_test/'),
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
    expect(validateCriticalFlows(rootDir: fx('nope')).single, contains('missing'));
  });
}
```

Fixtures (`docs/reference/critical_flows.md` under each fixture dir; `ok/` also has the two test files it points at as empty `void main() {}` files named exactly as below):
- `ok`: `# Registry\n\n| Flow | Test |\n|---|---|\n| settings: choose theme, restart, theme persisted | `app/integration_test/settings_theme_test.dart` |\n| settings: second flow same file | app/integration_test/settings_theme_test.dart |\n` (create `ok/app/integration_test/settings_theme_test.dart`)
- `empty`: `| Flow | Test |\n|---|---|\n<!-- no rows -->\n`
- `missing`: `| Flow | Test |\n|---|---|\n| ghost flow | app/integration_test/ghost_test.dart |\n`
- `malformed`: `| Flow | Test |\n|:---|:---:|\n| three | cells | here |\n| one-cell |\n| abs | /etc/passwd_test.dart |\n| not a test | app/lib/main.dart |\n| unit test | test/graph_test.dart |\n` (create `malformed/test/graph_test.dart` as `void main() {}` so only the location rule fires for it)

`test/e2e_config_test.dart` (fixture `test/fixtures/e2e/valid.yaml` = spec §10's block verbatim, with `runtime: "iOS 18.0"` quoted):
```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/e2e_config.dart';

String fixture(String name) =>
    File(p.join('test', 'fixtures', 'e2e', name)).readAsStringSync();

void main() {
  test('loads the spec-shaped config', () {
    final c = loadE2eConfig(fixture('valid.yaml'), sourcePath: 'valid.yaml');
    expect(c.defaultPlatform, E2ePlatform.android);
    expect(c.android.avdName, 'e2e_pixel');
    expect(c.android.deviceProfile, 'pixel_7');
    expect(c.android.apiLevel, 34);
    expect(c.android.systemImageFor(HostArch.x86_64), 'system-images;android-34;google_apis;x86_64');
    expect(c.android.systemImageFor(HostArch.arm64), 'system-images;android-34;google_apis;arm64-v8a');
    expect(c.ios.simulatorName, 'e2e_iphone');
    expect(c.ios.deviceType, 'iPhone 16');
    expect(c.ios.runtime, 'iOS 18.0');
  });

  test('unknown default_platform is a config error', () {
    final src = fixture('valid.yaml').replaceFirst('android\n', 'web\n');
    expect(() => loadE2eConfig(src, sourcePath: 'x'), throwsA(isA<E2eConfigException>()));
  });

  test('a system image whose API level disagrees with api_level is rejected', () {
    final src = fixture('valid.yaml').replaceFirst('android-34;google_apis;x86_64', 'android-35;google_apis;x86_64');
    expect(() => loadE2eConfig(src, sourcePath: 'x'), throwsA(predicate((e) => e.toString().contains('pins API 35'))));
  });

  test('a missing host-arch image is rejected (no silent fallback)', () {
    final src = fixture('valid.yaml').replaceFirst(RegExp(r'    arm64:.*\n'), '');
    expect(() => loadE2eConfig(src, sourcePath: 'x'), throwsA(predicate((e) => e.toString().contains('missing arm64'))));
  });

  test('api_level must be an int, not a string', () {
    final src = fixture('valid.yaml').replaceFirst('api_level: 34', 'api_level: "34"');
    expect(() => loadE2eConfig(src, sourcePath: 'x'), throwsA(predicate((e) => e.toString().contains('api_level'))));
  });

  test('ios.runtime shape is validated', () {
    final src = fixture('valid.yaml').replaceFirst('iOS 18.0', 'iOS18');
    expect(() => loadE2eConfig(src, sourcePath: 'x'), throwsA(predicate((e) => e.toString().contains('ios.runtime'))));
  });

  test('string fields with shell-unsafe characters are rejected by the loader', () {
    for (final bad in ["pixel'7", 'pixel\n7', 'pixel\t7']) {
      final src = fixture('valid.yaml').replaceFirst('pixel_7', bad);
      expect(() => loadE2eConfig(src, sourcePath: 'x'), throwsA(isA<E2eConfigException>()), reason: bad);
    }
  });

  test('env dump lists every key bash needs', () {
    final c = loadE2eConfig(fixture('valid.yaml'), sourcePath: 'valid.yaml');
    final env = envLines(c);
    expect(env, containsAll([
      'DEFAULT_PLATFORM=android',
      'ANDROID_AVD_NAME=e2e_pixel',
      'ANDROID_DEVICE_PROFILE=pixel_7',
      'ANDROID_API_LEVEL=34',
      'ANDROID_SYSTEM_IMAGE_ARM64=system-images;android-34;google_apis;arm64-v8a',
      'ANDROID_SYSTEM_IMAGE_X86_64=system-images;android-34;google_apis;x86_64',
      'IOS_SIMULATOR_NAME=e2e_iphone',
      'IOS_DEVICE_TYPE=iPhone 16',
      'IOS_RUNTIME=iOS 18.0',
    ]));
  });
}
```

Run: `fvm dart test test/critical_flows_test.dart test/e2e_config_test.dart` → FAIL (missing libraries).

- [ ] **Step 2: The validators**

`tool/src/critical_flows.dart`:
```dart
import 'dart:io';

import 'package:path/path.dart' as p;

/// One row of docs/reference/critical_flows.md: flow name -> patrol test.
final class CriticalFlow {
  const CriticalFlow({required this.name, required this.testPath, required this.line});
  final String name;
  final String testPath;

  /// 1-based line in the registry, for `path:line:` style messages.
  final int line;
}

const String criticalFlowsRegistryPath = 'docs/reference/critical_flows.md';

final _separatorCell = RegExp(r'^:?-+:?$');

/// Parses every markdown table row of [markdown] (lines whose first
/// non-blank character is `|`). The header row (first cell `Flow`) and
/// separator rows (`|---|---|`) are skipped; every other row must carry
/// exactly two cells. Surrounding backticks on the `Test` cell are
/// tolerated so the path may be written as code. Structural problems go to
/// [problems] (`N: ...`, N = 1-based line) so every malformed row is listed.
List<CriticalFlow> parseCriticalFlows(String markdown, {required List<String> problems}) {
  final flows = <CriticalFlow>[];
  final lines = markdown.split('\n');
  var sawHeader = false;
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (!raw.trimLeft().startsWith('|')) continue;
    final cells = raw.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (cells.isEmpty) continue;
    if (cells.first == 'Flow') {
      sawHeader = true;
      continue;
    }
    if (cells.every(_separatorCell.hasMatch)) continue;
    if (cells.length != 2) {
      problems.add('${i + 1}: expected 2 cells (Flow | Test), got ${cells.length}');
      continue;
    }
    final testPath = _stripBackticks(cells[1]);
    if (testPath.isEmpty) {
      problems.add('${i + 1}: empty Test cell');
      continue;
    }
    flows.add(CriticalFlow(name: cells[0], testPath: testPath, line: i + 1));
  }
  if (!sawHeader) problems.add('1: no `| Flow | Test |` header row found');
  return flows;
}

String _stripBackticks(String cell) =>
    cell.length >= 2 && cell.startsWith('`') && cell.endsWith('`') ? cell.substring(1, cell.length - 1) : cell;

/// The gate's registry check: every `Test` path must be a repo-relative
/// path to an existing `*_test.dart` file. Returns violations
/// (`registry:line: message`), empty = OK.
List<String> validateCriticalFlows({required String rootDir, String registryPath = criticalFlowsRegistryPath}) {
  final file = File(p.join(rootDir, registryPath));
  if (!file.existsSync()) return ['$registryPath: registry file is missing'];
  final problems = <String>[];
  final flows = parseCriticalFlows(file.readAsStringSync(), problems: problems);
  final violations = [for (final m in problems) '$registryPath:$m'];
  for (final flow in flows) {
    final path = flow.testPath;
    final where = '$registryPath:${flow.line}';
    if (p.isAbsolute(path) || path.contains('..')) {
      violations.add('$where: "$path" must be a repo-relative path');
      continue;
    }
    if (!path.endsWith('_test.dart')) {
      violations.add('$where: "$path" is not a *_test.dart file');
    }
    // Spec section 10: critical flows are patrol tests under
    // app/integration_test/ - a unit test cannot stand in for one.
    if (!path.startsWith('app/integration_test/')) {
      violations.add('$where: "$path" is not under app/integration_test/');
    }
    if (!File(p.join(rootDir, path)).existsSync()) {
      violations.add('$where: flow "${flow.name}" points to a missing test: $path');
    }
  }
  return violations;
}
```

`tool/verify_critical_flows.dart`:
```dart
import 'dart:io';

import 'src/critical_flows.dart';

void main() {
  final violations = validateCriticalFlows(rootDir: Directory.current.path);
  if (violations.isEmpty) {
    stdout.writeln('Critical flows registry: OK');
    return;
  }
  violations.forEach(stderr.writeln);
  exitCode = 1;
}
```

`tool/src/e2e_config.dart`:
```dart
import 'package:yaml/yaml.dart';

const String e2eConfigPath = 'tool/e2e.yaml';

final class E2eConfigException implements Exception {
  E2eConfigException(this.message);
  final String message;
  @override
  String toString() => 'E2eConfigException: $message';
}

enum E2ePlatform { android, ios }

/// Host CPU architectures the Android system image is pinned for.
enum HostArch { arm64, x86_64 }

final class AndroidE2eConfig {
  const AndroidE2eConfig({required this.avdName, required this.deviceProfile, required this.apiLevel, required this.systemImages});
  final String avdName;
  final String deviceProfile;
  final int apiLevel;
  final Map<HostArch, String> systemImages;

  String systemImageFor(HostArch arch) =>
      systemImages[arch] ?? (throw E2eConfigException('android.system_images has no entry for ${arch.name}'));
}

final class IosE2eConfig {
  const IosE2eConfig({required this.simulatorName, required this.deviceType, required this.runtime});
  final String simulatorName;
  final String deviceType;
  final String runtime;
}

final class E2eConfig {
  const E2eConfig({required this.defaultPlatform, required this.android, required this.ios});
  final E2ePlatform defaultPlatform;
  final AndroidE2eConfig android;
  final IosE2eConfig ios;
}

final _sdkmanagerImage = RegExp(r'^system-images;android-(\d+);[^;]+;[^;]+$');
final _iosRuntime = RegExp(r'^iOS \d+(\.\d+)+$');

E2eConfig loadE2eConfig(String yamlSource, {required String sourcePath}) {
  final root = loadYaml(yamlSource);
  if (root is! YamlMap) {
    throw E2eConfigException('$sourcePath: top level must be a map');
  }
  final platformName = _req<String>(root, 'default_platform', sourcePath);
  final defaultPlatform = E2ePlatform.values.asNameMap()[platformName];
  if (defaultPlatform == null) {
    throw E2eConfigException('$sourcePath: default_platform must be android or ios, got "$platformName"');
  }
  final android = _req<YamlMap>(root, 'android', sourcePath);
  final apiLevel = _req<int>(android, 'api_level', '$sourcePath: android');
  final rawImages = _req<YamlMap>(android, 'system_images', '$sourcePath: android');
  final images = <HostArch, String>{};
  for (final entry in rawImages.entries) {
    final arch = HostArch.values.asNameMap()[entry.key.toString()];
    if (arch == null) {
      throw E2eConfigException(
        '$sourcePath: android.system_images.${entry.key} is not a known host arch '
        '(${HostArch.values.map((a) => a.name).join(', ')})',
      );
    }
    final image = entry.value.toString();
    final m = _sdkmanagerImage.firstMatch(image);
    if (m == null) {
      throw E2eConfigException(
        '$sourcePath: android.system_images.${arch.name} "$image" is not an sdkmanager path '
        '(system-images;android-<api>;<tag>;<abi>)',
      );
    }
    if (int.parse(m.group(1)!) != apiLevel) {
      throw E2eConfigException(
        '$sourcePath: android.system_images.${arch.name} pins API ${m.group(1)} but android.api_level is $apiLevel',
      );
    }
    images[arch] = image;
  }
  for (final arch in HostArch.values) {
    if (!images.containsKey(arch)) {
      throw E2eConfigException('$sourcePath: android.system_images is missing ${arch.name} (one image per host architecture)');
    }
  }
  final ios = _req<YamlMap>(root, 'ios', sourcePath);
  final runtime = _req<String>(ios, 'runtime', '$sourcePath: ios');
  if (!_iosRuntime.hasMatch(runtime)) {
    throw E2eConfigException('$sourcePath: ios.runtime must look like "iOS 18.0", got "$runtime"');
  }
  return E2eConfig(
    defaultPlatform: defaultPlatform,
    android: AndroidE2eConfig(
      avdName: _req<String>(android, 'avd_name', '$sourcePath: android'),
      deviceProfile: _req<String>(android, 'device_profile', '$sourcePath: android'),
      apiLevel: apiLevel,
      systemImages: images,
    ),
    ios: IosE2eConfig(
      simulatorName: _req<String>(ios, 'simulator_name', '$sourcePath: ios'),
      deviceType: _req<String>(ios, 'device_type', '$sourcePath: ios'),
      runtime: runtime,
    ),
  );
}

/// `KEY=value` lines for tool/e2e.sh (the entrypoint single-quotes the
/// values; `_req` rejects quotes and control characters so that is safe).
List<String> envLines(E2eConfig c) => [
  'DEFAULT_PLATFORM=${c.defaultPlatform.name}',
  'ANDROID_AVD_NAME=${c.android.avdName}',
  'ANDROID_DEVICE_PROFILE=${c.android.deviceProfile}',
  'ANDROID_API_LEVEL=${c.android.apiLevel}',
  'ANDROID_SYSTEM_IMAGE_ARM64=${c.android.systemImageFor(HostArch.arm64)}',
  'ANDROID_SYSTEM_IMAGE_X86_64=${c.android.systemImageFor(HostArch.x86_64)}',
  'IOS_SIMULATOR_NAME=${c.ios.simulatorName}',
  'IOS_DEVICE_TYPE=${c.ios.deviceType}',
  'IOS_RUNTIME=${c.ios.runtime}',
];

// Values travel to bash as single-quoted words: no quotes, no control
// characters (the loader is the only place that can reject them early).
final _shellUnsafe = RegExp("[\\x00-\\x1f']");

T _req<T>(YamlMap map, String key, String where) {
  final value = map[key];
  if (value is! T) {
    throw E2eConfigException('$where: "$key" is required and must be $T${value == null ? ' (missing)' : ''}');
  }
  if (value is String && _shellUnsafe.hasMatch(value)) {
    throw E2eConfigException('$where: "$key" must not contain quotes or control characters');
  }
  return value;
}
```

`tool/e2e_config.dart`:
```dart
import 'dart:io';

import 'src/e2e_config.dart';

/// Prints tool/e2e.yaml as shell-safe KEY=value lines (quoted with single
/// quotes so `eval` keeps spaces such as "iPhone 16").
void main() {
  final file = File(e2eConfigPath);
  if (!file.existsSync()) {
    stderr.writeln('$e2eConfigPath is missing');
    exitCode = 2;
    return;
  }
  try {
    final config = loadE2eConfig(file.readAsStringSync(), sourcePath: e2eConfigPath);
    for (final line in envLines(config)) {
      final i = line.indexOf('=');
      stdout.writeln("${line.substring(0, i)}='${line.substring(i + 1)}'");
    }
  } on E2eConfigException catch (e) {
    stderr.writeln(e.message);
    exitCode = 2;
  }
}
```

`tool/e2e.yaml` (spec §10, `runtime` quoted so YAML keeps it a string):
```yaml
# Declarative e2e device profiles (spec section 10). No machine-specific
# ids: tool/e2e.sh finds or creates these devices from the specs below, so
# local and CI runs use the same API level and profile. The Android system
# image is pinned per HOST architecture: an arm64 image cannot boot under
# KVM on x86_64 runners and vice versa.
default_platform: android
android:
  avd_name: e2e_pixel
  device_profile: pixel_7
  api_level: 34
  system_images:
    arm64: system-images;android-34;google_apis;arm64-v8a
    x86_64: system-images;android-34;google_apis;x86_64
ios:
  simulator_name: e2e_iphone
  device_type: iPhone 16
  # Matched by major version: the newest installed "iOS 18.x" runtime is
  # used (an exact 18.0 runtime is rarely what a developer machine has).
  runtime: "iOS 18.0"
```

`tool/checks.sh` — insert before the final `echo "OK"`:
```bash
echo "==> Critical flows registry (docs/reference/critical_flows.md -> existing patrol tests)"
run_dart run tool/verify_critical_flows.dart
```
and update the tier header comment: drop `# M5 appends the critical-flows check.`, add `+ critical-flows registry` to the full-tier line.

`test/docs_test.dart`: delete the test `'critical_flows.md has the registry table shape the gate will parse'` (the validator owns the format now; `requiredDocs` keeps the file).

Run: `fvm dart test test/critical_flows_test.dart test/e2e_config_test.dart test/docs_test.dart` → PASS; `fvm dart run tool/verify_critical_flows.dart` → `Critical flows registry: OK` (empty table is valid); `fvm dart run tool/e2e_config.dart` → nine quoted lines.

- [ ] **Step 3: Identity test hardening (binary-safe, harness dirs)**

Replace `test/template_identity_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Spec section 9: packages/, lints/ and tool/ are product-neutral by
/// construction, so init's identity rewrite never has to touch them - and
/// neither are the agent harness files (AGENTS.md, CLAUDE.md, .claude/,
/// .codex/), which init must leave untouched. This test is what makes
/// "by construction" true. Init deletes this file (it is template-only).
void main() {
  const identityTokens = ['alatyr_starter', 'dev.alatyr', 'Alatyr Starter', 'alatyr_workspace'];
  const neutralDirs = ['packages', 'lints', 'tool', '.claude', '.codex'];
  const neutralFiles = ['AGENTS.md', 'CLAUDE.md'];
  const skippedDirNames = {'.dart_tool', 'build'};
  // A developer's local Claude settings are not shipped.
  const skippedFileNames = {'settings.local.json'};

  Iterable<File> neutralTree() sync* {
    for (final dir in neutralDirs) {
      yield* Directory(dir)
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => !p.split(f.path).any(skippedDirNames.contains))
          .where((f) => !skippedFileNames.contains(p.basename(f.path)));
    }
    for (final file in neutralFiles) {
      yield File(file);
    }
  }

  test('product-neutral directories contain no placeholder identity token', () {
    final hits = <String>[];
    var scanned = 0;
    for (final file in neutralTree()) {
      final bytes = file.readAsBytesSync();
      // Skip binaries (NUL in the first 1 KB, as docs_test does) and decode
      // tolerantly so a stray byte in a fixture cannot crash the scan.
      if (bytes.take(1024).contains(0)) continue;
      scanned++;
      final lines = const LineSplitter().convert(utf8.decode(bytes, allowMalformed: true));
      for (var i = 0; i < lines.length; i++) {
        for (final token in identityTokens) {
          if (lines[i].contains(token)) {
            hits.add('${file.path}:${i + 1}: $token');
          }
        }
      }
    }
    expect(scanned, greaterThan(50), reason: 'scan must actually walk files');
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
```

Run: `fvm dart test test/template_identity_test.dart` → PASS.

- [ ] **Step 4: Carryover nits**

`test/harness_test.dart` — in the temp-repo group's setUp, give every `git` call a hardened environment (the group already builds an `env` map for the stub PATH): add `'GIT_CONFIG_GLOBAL': '/dev/null', 'GIT_CONFIG_SYSTEM': '/dev/null', 'GIT_CONFIG_NOSYSTEM': '1'` to that map and pass it to every `Process.runSync('git', …)` in the group (author/committer identity is already set there).

`.claude/skills/cross-review/codex_review.sh` — the two argument guards become `[[ $# -ge 2 && $2 != --* ]] || { usage; exit 2; }`.

Run: `fvm dart test test/harness_test.dart` → PASS; `.claude/skills/cross-review/codex_review.sh --base --structured; echo $?` → usage + `2`.

- [ ] **Step 5: Gate + commit**

Run: `fvm dart format . && tool/checks.sh` → `OK` (the new registry stage prints OK on the empty table).

```bash
git add -A tool test .claude/skills/cross-review/codex_review.sh
git commit -m "feat(gate): critical-flows registry stage, e2e.yaml loader, hardened identity and harness tests"
```

---

### Task 2: Android compileSdk 37, patrol scaffolding, the patrol exemplar, the registry row

**Files:**
- Modify: `app/pubspec.yaml`, `app/android/app/build.gradle.kts`, `app/android/gradle.properties`, `app/ios/Runner.xcodeproj/project.pbxproj`, `app/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`, `app/macos/Flutter/GeneratedPluginRegistrant.swift` (regenerated), `.gitignore`, `docs/reference/critical_flows.md`
- Create: `app/android/app/src/androidTest/java/dev/alatyr/starter/MainActivityTest.java`, `app/ios/RunnerUITests/RunnerUITests.m`, `app/integration_test/settings_theme_test.dart`

**Interfaces:**
- Produces: the registered flow `app/integration_test/settings_theme_test.dart` (two ordered `patrolTest`s); `patrol:` pubspec block (`app_name`, `test_directory: integration_test`, `android.package_name`, `ios.bundle_id`).

- [ ] **Step 1: Android build fix + patrol dependency**

`app/pubspec.yaml` — dev dependency + block:
```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  patrol_finders: ^3.6.0
  patrol: ^4.9.0
flutter:
  uses-material-design: true
patrol:
  app_name: Alatyr Starter
  test_directory: integration_test
  android:
    package_name: dev.alatyr.starter
  ios:
    bundle_id: dev.alatyr.starter
```

`app/android/app/build.gradle.kts` — in `android { … }`:
```kotlin
    // flutter_secure_storage 11 ships AAR metadata requiring compileSdk 37;
    // Flutter 3.44.9 defaults to 36 (flutter.compileSdkVersion). See
    // docs/workflow/maintenance.md.
    compileSdk = 37
```
(replacing `compileSdk = flutter.compileSdkVersion`), in `defaultConfig { … }` after `versionName`:
```kotlin
        // Patrol e2e (tool/e2e.sh). The orchestrator (below) runs every Dart
        // test in its own process; that process boundary is the "restart"
        // of the critical flows. Patrol's docs also set
        // testInstrumentationRunnerArguments["clearPackageData"] = "true" -
        // deliberately NOT here: it would wipe app data between the tests
        // and with it the persisted state the restart flow asserts on.
        testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
```
a new block inside `android { … }`:
```kotlin
    testOptions {
        execution = "ANDROIDX_TEST_ORCHESTRATOR"
    }
```
and at file end:
```kotlin
dependencies {
    androidTestUtil("androidx.test:orchestrator:1.5.1")
}
```

`app/android/gradle.properties` — append:
```
# AGP 9.0.1 is validated up to compile SDK 36.1; compileSdk 37 is required by
# flutter_secure_storage 11 (see app/build.gradle.kts).
android.suppressUnsupportedCompileSdk=37.0
```

`app/android/app/src/androidTest/java/dev/alatyr/starter/MainActivityTest.java` (patrol docs, package replaced):
```java
package dev.alatyr.starter;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

@RunWith(Parameterized.class)
public class MainActivityTest {
    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation = (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation = (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
```

`.gitignore` (root) — append:
```
# patrol_cli regenerates the test bundle on every run; SwiftPM resolution is
# a build artefact of xcodebuild.
**/test_bundle.dart
.patrol.env
**/xcshareddata/swiftpm/
```

- [ ] **Step 2: iOS RunnerUITests target (scripted, committed)**

`app/ios/RunnerUITests/RunnerUITests.m`:
```objc
@import XCTest;
@import patrol;
@import ObjectiveC.runtime;

#if !defined(PATROL_INTEGRATION_TEST_IOS_RUNNER)
#import "PatrolIntegrationTestIosRunner.h"
#endif

PATROL_INTEGRATION_TEST_IOS_RUNNER(RunnerUITests)
```

Create the target with the `xcodeproj` gem (ships with CocoaPods: `gem list xcodeproj`; if absent, `sudo gem install xcodeproj` or `brew install cocoapods`). Write this script to the scratchpad (not the repo) as `add_runner_uitests.rb` and run `ruby add_runner_uitests.rb app/ios`:
```ruby
require 'xcodeproj'
ios_dir = ARGV.fetch(0)
proj_path = File.join(ios_dir, 'Runner.xcodeproj')
project = Xcodeproj::Project.open(proj_path)
runner = project.targets.find { |t| t.name == 'Runner' } or raise 'Runner target missing'
abort 'RunnerUITests already exists' if project.targets.any? { |t| t.name == 'RunnerUITests' }
target = project.new_target(:ui_test_bundle, 'RunnerUITests', :ios, '13.0')
target.add_dependency(runner)
target.frameworks_build_phase.files.to_a.each do |bf|
  next unless bf.file_ref&.path.to_s.end_with?('Foundation.framework')
  ref = bf.file_ref; bf.remove_from_project; ref.remove_from_project
end
fw = project.main_group.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.display_name == 'Frameworks' }
if fw && fw.recursive_children.none? { |c| c.is_a?(Xcodeproj::Project::Object::PBXFileReference) }
  fw.recursive_children.each(&:remove_from_project); fw.remove_from_project
end
group = project.main_group.new_group('RunnerUITests', 'RunnerUITests')
file_ref = group.new_file('RunnerUITests.m')
target.source_build_phase.add_file_reference(file_ref)
runner_base = {}
runner.build_configurations.each { |c| runner_base[c.name] = c.base_configuration_reference }
target.build_configurations.each do |config|
  config.base_configuration_reference = runner_base[config.name]
  s = config.build_settings
  s.delete('INFOPLIST_FILE')
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'dev.alatyr.starter.RunnerUITests'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['TEST_TARGET_NAME'] = 'Runner'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
  s['CODE_SIGN_STYLE'] = 'Automatic'
  s['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  s['CURRENT_PROJECT_VERSION'] = '1'
  s['MARKETING_VERSION'] = '1.0'
  s['SWIFT_VERSION'] = '5.0'
  s['TARGETED_DEVICE_FAMILY'] = '1,2'
end
build_phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
build_phase.name = 'xcode_backend build'
build_phase.shell_path = '/bin/sh'
build_phase.shell_script = "/bin/sh \"$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh\" build\n"
embed_phase = project.new(Xcodeproj::Project::Object::PBXShellScriptBuildPhase)
embed_phase.name = 'xcode_backend embed_and_thin'
embed_phase.shell_path = '/bin/sh'
embed_phase.shell_script = "/bin/sh \"$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh\" embed_and_thin\n"
target.build_phases.insert(0, build_phase)
target.build_phases << embed_phase
dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
dep.product_name = 'FlutterGeneratedPluginSwiftPackage'
target.package_product_dependencies << dep
bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
bf.product_ref = dep
target.frameworks_build_phase.files << bf
attrs = project.root_object.attributes['TargetAttributes'] ||= {}
attrs[target.uuid] = { 'CreatedOnToolsVersion' => '15.1', 'TestTargetID' => runner.uuid }
project.save
scheme_path = Xcodeproj::XCScheme.shared_data_dir(proj_path) + 'Runner.xcscheme'
scheme = Xcodeproj::XCScheme.new(scheme_path)
scheme.test_action.testables.each { |t| t.parallelizable = false }
testable = Xcodeproj::XCScheme::TestAction::TestableReference.new(target)
testable.parallelizable = false
scheme.test_action.add_testable(testable)
scheme.save!
```
Verify: `grep -c 'RunnerUITests' app/ios/Runner.xcodeproj/project.pbxproj` ≥ 10; `grep -c 'DEVELOPMENT_TEAM' app/ios/Runner.xcodeproj/project.pbxproj` → 0 (the script must not add one); `plutil -lint app/ios/Runner/Info.plist` OK.

- [ ] **Step 3: The exemplar (two ordered tests) and the registry row**

`app/integration_test/settings_theme_test.dart`:
```dart
// Critical flow (docs/reference/critical_flows.md):
//   launch -> settings -> choose dark -> restart -> dark persisted.
//
// Patrol runs every Dart test in its own OS process: on Android the test
// orchestrator starts a new instrumentation (= app) process per test, on iOS
// the runner calls `XCUIApplication.launch` before each test, which
// terminates any running instance. That process boundary between the two
// tests below IS the "restart" of the flow - a real process death with the
// file-backed database reopened from disk - which no single-test API can
// produce (patrol has no "relaunch app" call; `pressHome` + `openApp` only
// backgrounds and foregrounds the same process).
//
// Consequences, both deliberate:
// - The second test depends on the first having run (declaration order was
//   the execution order on both platforms in every run so far; the second
//   test fails loudly - not silently - if that ever changes).
// - `clearPackageData` must NOT be set in the Android instrumentation
//   arguments: the orchestrator would `pm clear` the app between the tests
//   and wipe the very state the second test asserts on.
import 'package:alatyr_starter/app.dart';
import 'package:alatyr_starter/bootstrap/app_dependencies.dart';
import 'package:feature_settings_api/feature_settings_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

ThemeMode? _themeMode(PatrolIntegrationTester $) =>
    $.tester.widget<MaterialApp>($(MaterialApp)).themeMode;

bool _isSelected(PatrolIntegrationTester $, ThemeMode mode) => $.tester
    .widget<ListTile>($(SettingsKeys.themeModeTile(mode)).$(ListTile))
    .selected;

/// The production composition root, pumped the way patrol prescribes: no
/// `ensureInitialized`, no `runApp` (patrol owns the binding).
Future<AppDependencies> _launch(PatrolIntegrationTester $) async {
  final deps = AppDependencies.production();
  await $.pumpWidgetAndSettle(App(dependencies: deps));
  expect($(SettingsKeys.screen), findsOneWidget);
  return deps;
}

void main() {
  // THE registered critical flow (docs/reference/critical_flows.md). Its
  // "restart" is the convention spec section 8 fixes: the app entrypoint
  // is re-invoked within the test - a fresh widget tree and DI graph - and
  // with production dependencies that means the on-disk database is closed
  // and reopened from the file. Self-contained: it passes alone.
  patrolTest('settings: choose dark, restart the app, dark is restored', ($) async {
    final first = await _launch($);
    await $(SettingsKeys.themeModeTile(ThemeMode.dark)).tap();
    expect(_themeMode($), ThemeMode.dark);
    expect(_isSelected($, ThemeMode.dark), isTrue);

    // Background and foreground (same process) first...
    await $.platform.mobile.pressHome();
    await $.platform.mobile.openApp();
    await $.pumpAndSettle();
    expect(_isSelected($, ThemeMode.dark), isTrue);

    // ...then the restart: tear the whole graph down (closes the database)
    // and build a new one over the same file.
    await $.pumpWidget(const SizedBox.shrink());
    await first.dispose();
    final second = await _launch($);
    expect(_isSelected($, ThemeMode.dark), isTrue);
    expect(_themeMode($), ThemeMode.dark);
    await second.dispose();
  });

  // Bonus, NOT the registered flow: real OS process death. Patrol runs every
  // Dart test in its own process (see the header), so this test starts in a
  // fresh process over the database the previous test left behind. It is
  // order-dependent by construction and fails loudly when run alone.
  patrolTest('settings (fresh process): the persisted dark theme survives process death', ($) async {
    final deps = await _launch($);
    expect(_isSelected($, ThemeMode.dark), isTrue);
    expect(_themeMode($), ThemeMode.dark);

    // Leave the device as we found it so the next run starts from system.
    await $(SettingsKeys.themeModeTile(ThemeMode.system)).tap();
    expect(_isSelected($, ThemeMode.system), isTrue);
    await deps.dispose();
  });
}
```

`docs/reference/critical_flows.md` — replace the empty registry section with:
```markdown
## The registry

| Flow | Test |
|---|---|
| settings: choose dark, restart the app (fresh DI graph over the same on-disk database), dark is restored | `app/integration_test/settings_theme_test.dart` |
```
and rewrite the intro ("From M5 on…" → present tense: the gate's `verify_critical_flows` stage checks every row) and the restart section: the registered flow uses spec §8's convention (re-invoked entrypoint, fresh widget tree + DI graph, the file-backed database reopened — on device, unlike the in-memory twin in `app/test/app_test.dart`); the same file additionally carries a fresh-process test that relies on patrol's per-test process boundary (Android orchestrator, `clearPackageData` off) — a bonus that proves real process death, order-dependent by construction, not the registered flow.

- [ ] **Step 4: Resolve, analyze, run on both platforms (the proof)**

```bash
fvm flutter pub get                                   # root; patrol enters the lock
git status --short app/macos                          # GeneratedPluginRegistrant.swift changed -> commit it
fvm dart analyze --fatal-infos app                    # integration_test/ is analyzed by the gate
fvm dart pub global activate patrol_cli 4.7.0
ls ~/Library/Android/sdk/platforms | grep android-37  # compileSdk 37 needs the platform installed (sdkmanager "platforms;android-37")
```
iOS (a booted simulator; `xcrun simctl list devices available | grep Booted` → pick its UDID, or `xcrun simctl boot "iPhone 15 Pro"`):
```bash
cd app && PATROL_FLUTTER_COMMAND="$(fvm exec which flutter)" fvm dart pub global run patrol_cli:main test -t integration_test/settings_theme_test.dart -d <UDID>; cd ..
rm -rf app/build            # ~1 GB of derived data between the two platform runs
```
Android (`~/Library/Android/sdk/emulator/emulator -list-avds` → an API 34 arm64 AVD, e.g. `Pixel_5_API_34_no_Google_play_Services`):
```bash
~/Library/Android/sdk/emulator/emulator -avd Pixel_5_API_34_no_Google_play_Services -no-window -no-audio -no-boot-anim &
~/Library/Android/sdk/platform-tools/adb wait-for-device
until [ "$(~/Library/Android/sdk/platform-tools/adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
cd app && PATROL_FLUTTER_COMMAND="$(fvm exec which flutter)" fvm dart pub global run patrol_cli:main test -t integration_test/settings_theme_test.dart -d emulator-5554; cd ..
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 emu kill
rm -rf app/build app/integration_test/test_bundle.dart
```
Expected: `Total 2 / Successful 2` on both (iOS ≈75 s, Android ≈70 s warm, several minutes cold). Paste both summaries into the report. If a platform fails for an environment reason, record it verbatim (do not weaken the test).

- [ ] **Step 5: Gate + commit**

Update the Russian twin of `docs/reference/critical_flows.md`. Run: `fvm dart format . && tool/checks.sh` → `OK` (registry stage now has a row; `flutter test` in `app/` ignores `integration_test/`); `git status --short` must then show only the files below (the root `pubspec.lock` changed when patrol entered the resolution — commit it).

```bash
git add -A app .gitignore pubspec.lock docs/reference/critical_flows.md
git commit -m "feat(e2e): patrol scaffolding on both platforms, compileSdk 37, the settings critical flow and its registry row"
```

---

### Task 3: `tool/e2e.sh` — find-or-create device, boot, run, shut down

**Files:**
- Create: `tool/e2e.sh`
- Modify: `tool/common.sh` (a `CHECKS_E2E_TIMEOUT` default), `docs/reference/critical_flows.md` only if the run reveals a wording issue

**Interfaces:**
- Produces: `tool/e2e.sh [android|ios] [-t <test>] [--device <id>] [--list]` — exit 0 when patrol reports all tests successful; patrol's own non-zero exit (test failures or patrol errors) propagates; exit 2 usage; exit 3 "e2e not performed because …" (missing tool, image, runtime, a running emulator that is not the declared AVD; never a silent fallback); a wall-clock kill surfaces as `run_guarded`'s 124/142. Always passes `-d <id>` to patrol. Shuts down every device it booted when `CI` is truthy, keeps them alive locally. Removes `app/integration_test/test_bundle.dart` afterwards. Helpers `tool/e2e_pick_runtime.dart` / `tool/e2e_pick_device.dart` (stdin JSON from `simctl`), unit-tested with fixture JSON.

- [ ] **Step 1: The script**

`tool/e2e.sh` (`chmod +x`):
```bash
#!/usr/bin/env bash
# Patrol e2e runner (spec section 10): reads tool/e2e.yaml, finds or creates
# the declared device, boots it, runs the registered flows with patrol under
# a hard wall-clock guard, and shuts the device down in CI (keeps it alive
# locally - a warm emulator is the developer's inner loop).
#
#   tool/e2e.sh [android|ios] [-t <test file>] [--device <id>] [--list]
#
# No "first available device" fallback: the device named in e2e.yaml is the
# one that runs (a running emulator is reused only when it IS that AVD), or
# the script explains what is missing. Exit codes: 0 all tests passed;
# patrol's own non-zero exit on test failures/errors; 2 usage; 3 e2e not
# performed (reason on stderr - report it verbatim, never fabricate a
# result); 124/142 when the wall-clock guard killed the run.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"

PATROL_CLI_VERSION="4.7.0"   # <-> patrol 4.9.0 in app/pubspec.yaml (docs/workflow/maintenance.md)
PLATFORM=""; TEST_FILE=""; DEVICE=""; LIST=false
usage() { echo "usage: tool/e2e.sh [android|ios] [-t <test file>] [--device <id>] [--list]" >&2; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    android|ios) PLATFORM="$1"; shift ;;
    -t) [[ $# -ge 2 && $2 != -* ]] || { usage; exit 2; }; TEST_FILE="$2"; shift 2 ;;
    --device) [[ $# -ge 2 && $2 != -* ]] || { usage; exit 2; }; DEVICE="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    *) usage; exit 2 ;;
  esac
done
not_performed() { echo "e2e not performed: $*" >&2; exit 3; }

# --- config (typed loader; prints KEY='value' lines)
config="$(run_dart run tool/e2e_config.dart)" || not_performed "tool/e2e.yaml is invalid (see above)"
eval "$config"
[[ -n "$PLATFORM" ]] || PLATFORM="$DEFAULT_PLATFORM"

# --- patrol_cli, fvm-first like common.sh
patrol() {
  if command -v fvm >/dev/null 2>&1; then fvm dart pub global run patrol_cli:main "$@"
  else dart pub global run patrol_cli:main "$@"; fi
}
# Tolerant of the banner format: the first x.y.z in `patrol --version`.
installed="$(patrol --version 2>/dev/null | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
[[ "$installed" == "$PATROL_CLI_VERSION" ]] || not_performed "patrol_cli $PATROL_CLI_VERSION is required (found '${installed:-none}'): dart pub global activate patrol_cli $PATROL_CLI_VERSION"
export PATROL_FLUTTER_COMMAND
if command -v fvm >/dev/null 2>&1; then PATROL_FLUTTER_COMMAND="$(fvm exec which flutter)"; else PATROL_FLUTTER_COMMAND="flutter"; fi

if [[ "$LIST" == "true" ]]; then
  echo "android: avd=$ANDROID_AVD_NAME profile=$ANDROID_DEVICE_PROFILE api=$ANDROID_API_LEVEL images: arm64=$ANDROID_SYSTEM_IMAGE_ARM64 x86_64=$ANDROID_SYSTEM_IMAGE_X86_64"
  echo "ios: simulator=$IOS_SIMULATOR_NAME type='$IOS_DEVICE_TYPE' runtime='$IOS_RUNTIME'"
  exit 0
fi

CHECKS_E2E_TIMEOUT="${CHECKS_E2E_TIMEOUT:-1800}"
PROVISION_TIMEOUT="${CHECKS_E2E_PROVISION_TIMEOUT:-900}"   # image install / boot, bounded like everything else
booted_device=""   # set BEFORE any wait so cleanup can always reach it
cleanup() {
  rm -f "$ROOT_DIR/app/integration_test/test_bundle.dart"
  if is_ci && [[ -n "$booted_device" ]]; then
    case "$PLATFORM" in
      android) "$ANDROID_HOME/platform-tools/adb" -s "$booted_device" emu kill >/dev/null 2>&1 || true ;;
      ios) xcrun simctl shutdown "$booted_device" >/dev/null 2>&1 || true ;;
    esac
  fi
}
trap cleanup EXIT

# --- device
case "$PLATFORM" in
  android)
    ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
    TOOLS="$ANDROID_HOME/cmdline-tools/latest/bin"
    [[ -x "$TOOLS/avdmanager" && -x "$TOOLS/sdkmanager" && -x "$ANDROID_HOME/emulator/emulator" ]] \
      || not_performed "Android SDK command-line tools + emulator not found under $ANDROID_HOME (set ANDROID_HOME)"
    case "$(uname -m)" in
      arm64|aarch64) IMAGE="$ANDROID_SYSTEM_IMAGE_ARM64" ;;
      x86_64) IMAGE="$ANDROID_SYSTEM_IMAGE_X86_64" ;;
      *) not_performed "unsupported host architecture $(uname -m)" ;;
    esac
    ADB="$ANDROID_HOME/platform-tools/adb"
    if [[ -z "$DEVICE" ]]; then
      # A running emulator is reused ONLY if it is the declared AVD; any
      # other running emulator is an error, not a fallback.
      others=""
      for serial in $("$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device/ {print $1}'); do
        avd="$("$ADB" -s "$serial" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')"
        if [[ "$avd" == "$ANDROID_AVD_NAME" ]]; then DEVICE="$serial"; echo "    using running $ANDROID_AVD_NAME ($DEVICE)"; break; fi
        others="$others $serial($avd)"
      done
      [[ -n "$DEVICE" || -z "$others" ]] || not_performed "running emulator(s)$others are not the declared '$ANDROID_AVD_NAME' (shut them down, or pass --device <serial> to use one explicitly)"
    fi
    if [[ -z "$DEVICE" ]]; then
      if ! "$TOOLS/avdmanager" list avd -c 2>/dev/null | grep -qx "$ANDROID_AVD_NAME"; then
        "$TOOLS/sdkmanager" --list_installed 2>/dev/null | grep -q "$IMAGE" \
          || { echo "    installing $IMAGE"; yes | "$TOOLS/sdkmanager" --licenses >/dev/null 2>&1 || true; run_guarded "$PROVISION_TIMEOUT" "$TOOLS/sdkmanager" "$IMAGE" >/dev/null || not_performed "could not install $IMAGE"; }
        echo "    creating AVD $ANDROID_AVD_NAME ($ANDROID_DEVICE_PROFILE, $IMAGE)"
        echo no | "$TOOLS/avdmanager" create avd -n "$ANDROID_AVD_NAME" -k "$IMAGE" -d "$ANDROID_DEVICE_PROFILE" >/dev/null \
          || not_performed "avdmanager could not create $ANDROID_AVD_NAME"
      fi
      # Explicit console port: the serial is known before the device exists,
      # so every adb call below is addressed (a second attached phone would
      # otherwise make a bare `adb wait-for-device` fail).
      PORT="${E2E_EMULATOR_PORT:-5554}"
      DEVICE="emulator-$PORT"
      "$ANDROID_HOME/emulator/emulator" -port "$PORT" -avd "$ANDROID_AVD_NAME" -no-window -no-audio -no-boot-anim -no-snapshot-save >/dev/null 2>&1 &
      booted_device="$DEVICE"
      run_guarded "$PROVISION_TIMEOUT" "$ADB" -s "$DEVICE" wait-for-device || not_performed "emulator $DEVICE did not appear"
      for _ in $(seq 1 $((PROVISION_TIMEOUT / 2))); do
        [[ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
        sleep 2
      done
      [[ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] || not_performed "emulator $DEVICE did not finish booting within ${PROVISION_TIMEOUT}s"
    fi ;;
  ios)
    command -v xcrun >/dev/null 2>&1 || not_performed "xcrun not found (Xcode required)"
    if [[ -z "$DEVICE" ]]; then
      major="${IOS_RUNTIME#iOS }"; major="${major%%.*}"
      runtime_id="$(xcrun simctl list runtimes -j | run_dart run tool/e2e_pick_runtime.dart "$major")" \
        || not_performed "no installed iOS $major.x simulator runtime (xcrun simctl list runtimes); install one in Xcode > Settings > Components"
      found="$(xcrun simctl list devices -j | run_dart run tool/e2e_pick_device.dart "$IOS_SIMULATOR_NAME" "$runtime_id")" || found=""
      DEVICE="${found%% *}"; state="${found#* }"
      if [[ -z "$DEVICE" ]]; then
        echo "    creating simulator $IOS_SIMULATOR_NAME ($IOS_DEVICE_TYPE, $runtime_id)"
        DEVICE="$(xcrun simctl create "$IOS_SIMULATOR_NAME" "$IOS_DEVICE_TYPE" "$runtime_id")" \
          || not_performed "simctl could not create '$IOS_DEVICE_TYPE' on $runtime_id (xcrun simctl list devicetypes)"
        state="Shutdown"
      fi
      if [[ "$state" != "Booted" ]]; then
        booted_device="$DEVICE"
        xcrun simctl boot "$DEVICE" || not_performed "simctl could not boot $DEVICE"
        run_guarded "$PROVISION_TIMEOUT" xcrun simctl bootstatus "$DEVICE" -b >/dev/null || not_performed "simulator $DEVICE did not finish booting within ${PROVISION_TIMEOUT}s"
      fi
    fi ;;
esac

# --- run (functions are invisible to run_guarded's exec, hence the explicit binaries)
args=(test -d "$DEVICE")
[[ -n "$TEST_FILE" ]] && args+=(-t "$TEST_FILE")
echo "==> patrol test on $PLATFORM ($DEVICE)"
( cd "$ROOT_DIR/app"
  if command -v fvm >/dev/null 2>&1; then
    run_guarded "$CHECKS_E2E_TIMEOUT" fvm dart pub global run patrol_cli:main "${args[@]}"
  else
    run_guarded "$CHECKS_E2E_TIMEOUT" dart pub global run patrol_cli:main "${args[@]}"
  fi )
```

Two tiny JSON helpers (bash has no JSON parser; `jq` is not assumed):

`tool/e2e_pick_runtime.dart`:
```dart
import 'dart:convert';
import 'dart:io';

/// stdin: `xcrun simctl list runtimes -j`; argv[0]: iOS major version.
/// Prints the identifier of the newest available runtime of that major,
/// exit 1 when none is installed. Logic lives in [pickRuntime] so it is
/// unit-tested with fixture JSON (test/e2e_pick_test.dart).
Future<void> main(List<String> args) async {
  final json = await utf8.decoder.bind(stdin).join();
  final id = pickRuntime(json, major: int.parse(args.single));
  if (id == null) {
    exitCode = 1;
    return;
  }
  stdout.write(id);
}

String? pickRuntime(String simctlJson, {required int major}) {
  final json = jsonDecode(simctlJson) as Map<String, dynamic>;
  final runtimes = (json['runtimes'] as List<dynamic>).cast<Map<String, dynamic>>();
  final candidates = runtimes.where((r) => r['platform'] == 'iOS' && r['isAvailable'] == true).where((r) {
    final version = r['version'] as String;
    return int.tryParse(version.split('.').first) == major;
  }).toList()..sort((a, b) => _compare(a['version'] as String, b['version'] as String));
  if (candidates.isEmpty) {
    return null;
  }
  return candidates.last['identifier'] as String;
}

int _compare(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
  }
  return pa.length.compareTo(pb.length);
}
```

`tool/e2e_pick_device.dart`:
```dart
import 'dart:convert';
import 'dart:io';

/// stdin: `xcrun simctl list devices -j`; argv: simulator name, runtime
/// identifier. Prints `<udid> <state>` (state = Booted | Shutdown | ...)
/// of an available device with that name under that runtime, exit 1 when
/// absent. Logic in [pickDevice] (unit-tested with fixture JSON).
Future<void> main(List<String> args) async {
  final json = await utf8.decoder.bind(stdin).join();
  final found = pickDevice(json, name: args[0], runtime: args[1]);
  if (found == null) {
    exitCode = 1;
    return;
  }
  stdout.write(found);
}

String? pickDevice(String simctlJson, {required String name, required String runtime}) {
  final json = jsonDecode(simctlJson) as Map<String, dynamic>;
  final devices = (json['devices'] as Map<String, dynamic>)[runtime] as List<dynamic>?;
  for (final d in (devices ?? const []).cast<Map<String, dynamic>>()) {
    if (d['name'] == name && d['isAvailable'] == true) {
      return '${d['udid']} ${d['state']}';
    }
  }
  return null;
}
```

`tool/common.sh` — add `CHECKS_E2E_TIMEOUT="${CHECKS_E2E_TIMEOUT:-1800}"` and `CHECKS_E2E_PROVISION_TIMEOUT="${CHECKS_E2E_PROVISION_TIMEOUT:-900}"` next to the other timeouts with a comment (a cold emulator boot + first build fits; patrol itself has no wall-clock guard).

`test/e2e_pick_test.dart` (TDD: write first; fixtures `test/fixtures/e2e/runtimes.json` and `devices.json` = trimmed real `xcrun simctl list … -j` output from this machine with runtimes iOS 17.4, 18.4, 26.2 and one `e2e_iphone` device under the 18.4 runtime in state `Shutdown`):
```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/e2e_pick_device.dart';
import '../tool/e2e_pick_runtime.dart';

String fixture(String name) => File(p.join('test', 'fixtures', 'e2e', name)).readAsStringSync();

void main() {
  test('picks the newest available runtime of the requested major', () {
    expect(pickRuntime(fixture('runtimes.json'), major: 18), 'com.apple.CoreSimulator.SimRuntime.iOS-18-4');
    expect(pickRuntime(fixture('runtimes.json'), major: 26), 'com.apple.CoreSimulator.SimRuntime.iOS-26-2');
  });

  test('no runtime of that major -> null', () {
    expect(pickRuntime(fixture('runtimes.json'), major: 16), isNull);
  });

  test('finds the named device under the runtime and reports its state', () {
    expect(pickDevice(fixture('devices.json'), name: 'e2e_iphone', runtime: 'com.apple.CoreSimulator.SimRuntime.iOS-18-4'), matches(RegExp(r'^[0-9A-F-]{36} Shutdown$')));
  });

  test('unknown name or runtime -> null', () {
    expect(pickDevice(fixture('devices.json'), name: 'nope', runtime: 'com.apple.CoreSimulator.SimRuntime.iOS-18-4'), isNull);
    expect(pickDevice(fixture('devices.json'), name: 'e2e_iphone', runtime: 'com.apple.CoreSimulator.SimRuntime.iOS-17-4'), isNull);
  });
}
```

- [ ] **Step 2: Run it for real**

```bash
tool/e2e.sh --list
tool/e2e.sh ios                      # creates/boots e2e_iphone on the newest iOS 18.x runtime (here 18.4)
rm -rf app/build
tool/e2e.sh android                  # creates e2e_pixel (arm64 image) if absent, boots it on port 5554, runs
~/Library/Android/sdk/platform-tools/adb -s emulator-5554 emu kill   # so the CI run has to boot the device itself
CI=true tool/e2e.sh android          # boots, runs, shuts down: emulator-5554 must be absent from `adb devices` afterwards
tool/e2e.sh --device no-such-device android; echo "exit=$?"   # patrol cannot find the device -> non-zero, its message printed
rm -rf app/build
```
Expected: `Total 2 / Successful 2` three times; the CI run shuts the emulator down; `git status --short` clean (no `test_bundle.dart`, no swiftpm files). If another emulator (not `e2e_pixel`) is running on this machine when you start, the script must stop with exit 3 naming it — shut it down and retry. Paste outputs into the report.

- [ ] **Step 3: Gate + commit**

Run: `fvm dart format . && tool/checks.sh` → `OK`.

```bash
git add tool/e2e.sh tool/e2e_pick_runtime.dart tool/e2e_pick_device.dart tool/common.sh test/e2e_pick_test.dart test/fixtures/e2e
git commit -m "feat(e2e): tool/e2e.sh finds or creates the declared device, runs patrol under a wall-clock guard"
```

---

### Task 4: Web assets — drift's sqlite3.wasm + drift_worker.js, and a web runtime smoke

**Files:**
- Create: `app/web/sqlite3.wasm`, `app/web/drift_worker.js`, `tool/web_smoke.sh`, `tool/web_smoke.mjs`
- Modify: `docs/workflow/maintenance.md` (asset provenance + hashes), `docs/workflow/getting-started.md` (web section), `packages/data_local/lib/src/app_database.dart` (doc comment: the assets ship now), twins

**Interfaces:**
- Produces: `tool/web_smoke.sh` — builds the web app, serves `app/build/web` from a Node HTTP server and drives headless Chrome over CDP: open → click Dark → reload → assert Dark still selected; exit 0 = persistence proven, exit 3 = not performed (no `node` ≥ 20 or no Chrome found — the reason printed), non-zero otherwise. Not a gate stage (no browser in the gate, ADR-0004); documented as the web runtime check.

- [ ] **Step 1: Download, verify, commit**

```bash
curl -sSfL -o app/web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/sqlite3.wasm
curl -sSfL -o app/web/drift_worker.js https://github.com/simolus3/drift/releases/download/drift-2.34.3/drift_worker.js
shasum -a 256 -c <<'EOF'
13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4  app/web/sqlite3.wasm
4db0469de8ceabad8d5cd3d920614486ba587e100e39523f36f704a3aec5f26c  app/web/drift_worker.js
EOF
cd app && fvm flutter build web && cd .. && rm -rf app/build
```
Rule (document in `maintenance.md` under a new "Web assets" heading): `sqlite3.wasm` comes from the sqlite3.dart release matching `pubspec.lock`'s `sqlite3` version; `drift_worker.js` from the drift release matching `pubspec.lock`'s `drift` version; record both sha256 there; refresh both whenever either package is bumped. `getting-started.md`: replace the "web persistence needs … (lands in M5)" sentence with: the assets ship in `app/web/`; without COOP/COEP headers drift uses `sharedIndexedDb` (persists, slower), with them `opfsLocks`; a missing asset surfaces as `WebAssembly … HTTP status code is not ok` in the console (logged through the app's theme-stream warning); `tool/web_smoke.sh` is the runtime check. `packages/data_local/lib/src/app_database.dart`: the `AppDatabase.open` doc comment no longer says the binaries are missing — "the app shell ships both under `app/web/` (see docs/workflow/maintenance.md, Web assets)".

- [ ] **Step 2: The web runtime smoke**

`tool/web_smoke.mjs` (Node ≥ 20, no npm dependencies; the research pass ran this logic green):
```js
// Web runtime smoke: serve a built Flutter web app, drive headless Chrome
// over the DevTools protocol, prove that the theme choice persists across
// a page reload (drift on web through sqlite3.wasm + drift_worker.js).
//   node tool/web_smoke.mjs <build/web dir> [chrome binary]
// Exit 0 proven; 3 not performed (no Chrome); 1 assertion failed.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { spawn } from 'node:child_process';
import { join, extname } from 'node:path';

const dir = process.argv[2];
const chrome = process.argv[3] || process.env.CHROME_BIN ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.json': 'application/json', '.css': 'text/css', '.png': 'image/png', '.ico': 'image/x-icon', '.otf': 'font/otf', '.ttf': 'font/ttf' };
const server = createServer(async (req, res) => {
  const path = req.url.split('?')[0];
  const file = join(dir, path === '/' ? 'index.html' : path);
  try {
    await stat(file);
    res.writeHead(200, { 'content-type': types[extname(file)] || 'application/octet-stream' });
    res.end(await readFile(file));
  } catch {
    res.writeHead(404); res.end();
  }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;
try { await stat(chrome); } catch { console.error(`web smoke not performed: Chrome not found at ${chrome} (set CHROME_BIN)`); process.exit(3); }
const proc = spawn(chrome, ['--headless=new', '--remote-debugging-port=0', '--no-first-run', '--user-data-dir=' + join(process.env.TMPDIR || '/tmp', 'web-smoke-profile-' + process.pid), 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
let wsUrl = '';
for await (const chunk of proc.stderr) { const m = String(chunk).match(/DevTools listening on (ws:\/\/\S+)/); if (m) { wsUrl = m[1]; break; } }
const ws = new WebSocket(wsUrl); await new Promise(r => ws.onopen = r);
let id = 0; const pending = new Map();
ws.onmessage = e => { const msg = JSON.parse(e.data); if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg); pending.delete(msg.id); } };
const send = (method, params = {}, sessionId) => new Promise(r => { const i = ++id; pending.set(i, r); ws.send(JSON.stringify({ id: i, method, params, sessionId })); });
const { result: { targetId } } = await send('Target.createTarget', { url: 'about:blank' });
const { result: { sessionId } } = await send('Target.attachToTarget', { targetId, flatten: true });
const evalJs = async (expression) => (await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, sessionId)).result.result.value;
const sleep = ms => new Promise(r => setTimeout(r, ms));
await send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-color-scheme', value: 'light' }] }, sessionId);
await send('Page.navigate', { url: `http://127.0.0.1:${port}/` }, sessionId);
const waitFor = async (js, label) => { for (let i = 0; i < 60; i++) { if (await evalJs(js)) return; await sleep(500); } throw new Error(`timeout waiting for ${label}`); };
const enableSemantics = `(() => { const p = document.querySelector('flt-semantics-placeholder'); if (p) p.click(); return true; })()`;
const tile = (label) => `[...document.querySelectorAll('flt-semantics [role="button"], flt-semantics [aria-label]')].find(e => (e.getAttribute('aria-label') || e.textContent || '').includes('${label}'))`;
await waitFor(`document.querySelector('flt-semantics-placeholder') !== null || document.querySelector('flt-semantics') !== null`, 'flutter');
await evalJs(enableSemantics);
await waitFor(`${tile('Dark')} !== undefined`, 'the Dark tile');
await evalJs(`${tile('Dark')}.click()`);
await waitFor(`${tile('Dark')}?.getAttribute('aria-current') === 'true'`, 'Dark selected');
await send('Page.reload', {}, sessionId);
await waitFor(`document.querySelector('flt-semantics-placeholder') !== null || document.querySelector('flt-semantics') !== null`, 'flutter after reload');
await evalJs(enableSemantics);
try {
  await waitFor(`${tile('Dark')}?.getAttribute('aria-current') === 'true'`, 'Dark selected after reload');
  console.log('web smoke OK: dark theme persisted across reload');
} finally {
  proc.kill(); server.close();
}
```
(Flutter web marks the selected ListTile with `aria-current`; semantics must be enabled by clicking the placeholder — both facts from the research pass. If the selectors drift with a Flutter upgrade, the smoke fails loudly, not silently.)

`tool/web_smoke.sh` (`chmod +x`):
```bash
#!/usr/bin/env bash
# Web runtime smoke (docs/workflow/getting-started.md): build the web app and
# prove with headless Chrome that the theme choice persists across a reload.
# Not a gate stage (no browser in the gate). Exit 0 proven, 3 not performed.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"
command -v node >/dev/null 2>&1 || { echo "web smoke not performed: node (>= 20) is required" >&2; exit 3; }
major="$(node -p 'process.versions.node.split(".")[0]')"
[[ "$major" -ge 20 ]] || { echo "web smoke not performed: node >= 20 required, found $(node -v)" >&2; exit 3; }
( cd app && run_flutter build web )
node_flags=(); [[ "$major" -lt 22 ]] && node_flags=(--experimental-websocket)
node "${node_flags[@]}" tool/web_smoke.mjs app/build/web "${CHROME_BIN:-}"
```
(`CHROME_BIN` empty → the .mjs default path; `--experimental-websocket` is needed on Node 20/21 only.)

Run: `tool/web_smoke.sh` → `web smoke OK: dark theme persisted across reload` (this machine has Chrome + node; ≈40 s). Then `rm -rf app/build`. If node or Chrome is missing here, record the exit-3 reason — and run the research's manual check instead (`flutter run -d chrome`), reporting what was observed.

- [ ] **Step 3: Gate + commit**

Run: `fvm dart format . && tool/checks.sh` → OK (binary assets are skipped by the Cyrillic scan's NUL heuristic; `.mjs` is not analyzed). Twins for the two docs.

```bash
git add app/web/sqlite3.wasm app/web/drift_worker.js tool/web_smoke.sh tool/web_smoke.mjs packages/data_local/lib/src/app_database.dart docs/workflow/maintenance.md docs/workflow/getting-started.md
git commit -m "feat(web): ship drift's sqlite3.wasm and drift_worker.js, add the web runtime smoke"
```

---

### Task 5: `tool/init.dart` — derive, validate, rewrite, delete, format, verify (fixture-tested)

**Files:**
- Create: `tool/src/init_identity.dart`, `tool/src/init_validate.dart`, `tool/src/init_rewrite.dart`, `tool/init.dart`, `test/init_identity_test.dart`, `test/init_validate_test.dart`, `test/init_rewrite_test.dart`, fixture tree `test/fixtures/init/template/**`

**Interfaces:**
- Produces: `TemplateIdentity deriveIdentity(String rootDir)` (`packageName`, `bundleId`, `org`, `displayName`, `workspaceName`); `InitTarget validateTarget({required String name, required String org, String? displayName})` → `InitTarget { name, org, displayName, bundleIdSnake, bundleIdCamel, workspaceName }` or throws `InitArgumentException(message)` (org segments `[a-z][a-z0-9]*` — no underscores, Apple ids; display name `[A-Za-z0-9][A-Za-z0-9 .-]*` — safe in Dart/XML/JSON/YAML/C++/RC strings); `InitReport runInit({required String rootDir, required TemplateIdentity from, required InitTarget to, required List<String> trackedFiles, String? templateUrl})` → rewrites contents/paths, deletes machinery, writes the README stubs, returns `InitReport { rewritten, deleted, movedDirs, changedDartFiles }` and throws `InitPostconditionException` if any token survives; `ProcessResult formatChangedDart({required String rootDir, required List<String> files, required String dartExecutable})` (the CLI's format step, testable); CLI `dart run tool/init.dart --name <n> --org <o> [--display-name <d>] [--template-url <url>] [--yes]` and `dart run tool/init.dart --print-identity` (prints the derived placeholder as `KEY='value'` lines for scripts that must not spell it).

- [ ] **Step 1: Failing tests (fixture tree first)**

Build `test/fixtures/init/template/` as a MINIATURE of the identity-bearing files, each a faithful excerpt of the real file at this commit (copy the real lines; keep them short). EVERY fixture file is stored with a `.txt` suffix appended to its real name (`app/lib/app.dart.txt`, `test/purity_checker_test.dart.txt`, …): root `dart test` loads every `*_test.dart` under `test/` and `dart format .` parses every `.dart` file regardless of analyzer excludes, so no fixture may end in `.dart`; `_copyTree` strips the suffix when materialising. `tracked_files.txt` lists the REAL names (without `.txt`). Fixture files: `pubspec.yaml` (name: alatyr_workspace + workspace list), `docs/reference/package_graph.yaml` (full file), `app/pubspec.yaml` (full, with the patrol block), `app/lib/app.dart` (full), `app/lib/bootstrap/app_dependencies.dart` (full), `app/test/app_test.dart` (the import lines + `void main() {}`), `app/README.md`, `app/android/app/build.gradle.kts` (full), `app/android/app/src/main/AndroidManifest.xml`, `app/android/app/src/main/kotlin/dev/alatyr/starter/MainActivity.kt`, `app/android/app/src/androidTest/java/dev/alatyr/starter/MainActivityTest.java`, `app/ios/Runner/Info.plist`, `app/ios/Runner.xcodeproj/project.pbxproj` (ONLY the XCBuildConfiguration blocks carrying `PRODUCT_BUNDLE_IDENTIFIER` for Runner, RunnerTests and RunnerUITests — 9 lines in total — plus one `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;` line; NO `DEVELOPMENT_TEAM` line), `app/ios/Runner/Runner.entitlements`, `app/macos/Runner/Configs/AppInfo.xcconfig`, `app/macos/Runner/Info.plist`, `app/macos/Runner.xcodeproj/project.pbxproj` (the three `alatyr_starter.app` lines, the three RunnerTests ids and the three TEST_HOST lines), `app/macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` (the BuildableName lines inside a minimal XML), `app/web/index.html`, `app/web/manifest.json`, `app/linux/CMakeLists.txt`, `app/linux/runner/my_application.cc` (the two title lines inside a stub function), `app/windows/CMakeLists.txt`, `app/windows/runner/Runner.rc` (the VALUE block), `app/windows/runner/main.cpp` (the window.Create line inside a stub), `app/web/sqlite3.wasm` (8 bytes with a NUL — proves binaries are skipped), `README.md`, `docs/adr/0006-working-placeholder-instantiation.md` (two lines mentioning `alatyr_starter` that must SURVIVE), `docs/architecture/01-overview.md` (one line mentioning `alatyr_starter` that must be rewritten), `test/purity_checker_test.dart` (valid Dart: `void main() {}` plus a comment line containing `"root": "alatyr_workspace"`), `test/template_identity_test.dart` (`void main() {}`), `tool/init.dart`, `tool/src/init_identity.dart`, `tool/src/init_rewrite.dart` (each `void main() {}` or a comment), `tool/template_smoke.sh`, `.github/workflows/template-smoke.yml`, `docs/superpowers/plans/x.md`, `AGENTS.md` (one token-free line), `.claude/settings.json` (token-free). Plus `test/fixtures/init/tracked_files.txt` listing every REAL path (stands in for `git ls-files`). Note the fixture's `ios/Runner.xcodeproj/project.pbxproj` deliberately has no `DEVELOPMENT_TEAM` line AND the rewrite test asserts the rewriter never adds one — the real-repo absence is asserted by `template_smoke.sh`.

`test/init_identity_test.dart`:
```dart
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/init_identity.dart';

void main() {
  final root = p.join('test', 'fixtures', 'init', 'template');

  test('derives the placeholder identity from the app shell, never from a literal', () {
    final id = deriveIdentity(root);
    expect(id.packageName, 'alatyr_starter');
    expect(id.bundleId, 'dev.alatyr.starter');
    expect(id.org, 'dev.alatyr');
    expect(id.displayName, 'Alatyr Starter');
    expect(id.workspaceName, 'alatyr_workspace');
  });

  test('the real repository derives the same identity', () {
    final id = deriveIdentity('.');
    expect(id.packageName, 'alatyr_starter');
    expect(id.bundleId, 'dev.alatyr.starter');
  });
}
```

`test/init_validate_test.dart`:
```dart
import 'package:test/test.dart';

import '../tool/src/init_validate.dart';

void main() {
  test('valid name and org map to both bundle-id shapes, a title-case display name and the workspace name', () {
    final t = validateTarget(name: 'my_app', org: 'com.example');
    expect(t.bundleIdSnake, 'com.example.my_app');
    expect(t.bundleIdCamel, 'com.example.myApp');
    expect(t.displayName, 'My App');
    expect(t.workspaceName, 'my_app_workspace');
  });

  test('an explicit display name wins', () {
    expect(validateTarget(name: 'my_app', org: 'com.example', displayName: 'Nimbus').displayName, 'Nimbus');
  });

  test('names must be lowercase_with_underscores identifiers', () {
    for (final bad in ['MyApp', '1app', 'my-app', 'my app', '', '_x']) {
      expect(() => validateTarget(name: bad, org: 'com.example'), throwsA(isA<InitArgumentException>()), reason: bad);
    }
  });

  test('Dart keywords and Flutter-reserved package names are rejected', () {
    for (final bad in ['class', 'switch', 'flutter', 'flutter_test', 'meta', 'collection']) {
      expect(() => validateTarget(name: bad, org: 'com.example'), throwsA(isA<InitArgumentException>()), reason: bad);
    }
  });

  test('org must be a lowercase reverse domain of [a-z][a-z0-9]* segments (no underscores: Apple bundle ids)', () {
    for (final bad in ['example', 'Com.Example', 'com.', 'com..example', 'com.1x', 'com.ex-ample', 'com.my_org']) {
      expect(() => validateTarget(name: 'my_app', org: bad), throwsA(isA<InitArgumentException>()), reason: bad);
    }
  });

  test('display names are limited to characters every generated shell can carry verbatim', () {
    for (final bad in ["O'Brien", 'A&B', 'Line\nBreak', 'Back\\slash', '"Quoted"', ' leading']) {
      expect(() => validateTarget(name: 'my_app', org: 'com.example', displayName: bad), throwsA(isA<InitArgumentException>()), reason: bad);
    }
    expect(validateTarget(name: 'my_app', org: 'com.example', displayName: 'My App 2.0 - Beta').displayName, 'My App 2.0 - Beta');
  });

  test('Java keywords are rejected as org segments and as the name (Android package rule)', () {
    expect(() => validateTarget(name: 'my_app', org: 'io.long.org'), throwsA(predicate((e) => e.toString().contains("'long'"))));
    expect(() => validateTarget(name: 'native', org: 'com.example'), throwsA(isA<InitArgumentException>()));
  });
}
```

`test/init_rewrite_test.dart`:
```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/src/init_identity.dart';
import '../tool/src/init_rewrite.dart';
import '../tool/src/init_validate.dart';

void main() {
  late Directory work;
  late String root;
  late InitReport report;

  String read(String rel) => File(p.join(root, rel)).readAsStringSync();
  bool exists(String rel) => File(p.join(root, rel)).existsSync() || Directory(p.join(root, rel)).existsSync();

  setUpAll(() {
    work = Directory.systemTemp.createTempSync('init_rewrite');
    root = work.path;
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), root);
    final tracked = File(p.join('test', 'fixtures', 'init', 'tracked_files.txt')).readAsLinesSync().where((l) => l.isNotEmpty).toList();
    report = runInit(
      rootDir: root,
      from: deriveIdentity(root),
      to: validateTarget(name: 'my_app', org: 'com.example'),
      trackedFiles: tracked,
      templateUrl: 'https://example.invalid/alatyr',
    );
  });
  tearDownAll(() => work.deleteSync(recursive: true));

  test('Android and Linux get the snake bundle id, Apple the camelCase one', () {
    expect(read('app/android/app/build.gradle.kts'), allOf(contains('namespace = "com.example.my_app"'), contains('applicationId = "com.example.my_app"'), isNot(contains('dev.alatyr'))));
    expect(read('app/linux/CMakeLists.txt'), contains('set(APPLICATION_ID "com.example.my_app")'));
    expect(read('app/ios/Runner.xcodeproj/project.pbxproj'), allOf(contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp;'), contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp.RunnerTests;'), contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp.RunnerUITests;'), isNot(contains('DEVELOPMENT_TEAM'))));
    expect(read('app/macos/Runner/Configs/AppInfo.xcconfig'), allOf(contains('PRODUCT_BUNDLE_IDENTIFIER = com.example.myApp'), contains('PRODUCT_NAME = my_app'), contains('Copyright © 2026 com.example.')));
  });

  test('Kotlin sources and the androidTest runner move to the new package directory', () {
    expect(read('app/android/app/src/main/kotlin/com/example/my_app/MainActivity.kt'), startsWith('package com.example.my_app'));
    expect(read('app/android/app/src/androidTest/java/com/example/my_app/MainActivityTest.java'), startsWith('package com.example.my_app;'));
    expect(exists('app/android/app/src/main/kotlin/dev'), isFalse);
    expect(exists('app/android/app/src/androidTest/java/dev'), isFalse);
  });

  test('display names, titles and the patrol block are rewritten', () {
    expect(read('app/ios/Runner/Info.plist'), allOf(contains('<string>My App</string>'), isNot(contains('Alatyr'))));
    expect(read('app/android/app/src/main/AndroidManifest.xml'), contains('android:label="My App"'));
    expect(read('app/web/manifest.json'), contains('"name": "My App"'));
    expect(read('app/windows/runner/Runner.rc'), allOf(contains('"ProductName", "My App"'), contains('"CompanyName", "com.example"')));
    expect(read('app/pubspec.yaml'), allOf(contains('name: my_app'), contains('app_name: My App'), contains('package_name: com.example.my_app'), contains('bundle_id: com.example.myApp')));
  });

  test('Dart sources, tests and the workspace are renamed; descriptions are product text', () {
    expect(read('app/test/app_test.dart'), contains("import 'package:my_app/app.dart';"));
    expect(read('app/lib/bootstrap/app_dependencies.dart'), contains("name: 'my_app'"));
    expect(read('pubspec.yaml'), startsWith('name: my_app_workspace'));
    expect(read('docs/reference/package_graph.yaml'), contains('my_app:'));
    expect(read('app/pubspec.yaml'), contains('description: My App Flutter app.'));
    expect(read('app/web/index.html'), contains('content="My App Flutter app."'));
    expect(read('test/purity_checker_test.dart'), contains('"root": "my_app_workspace"'));
  });

  test('template machinery is deleted and README stubs written; ADRs and binaries are untouched', () {
    for (final gone in ['tool/init.dart', 'tool/src/init_identity.dart', 'tool/src/init_rewrite.dart', 'tool/template_smoke.sh', '.github/workflows/template-smoke.yml', 'docs/superpowers', 'test/template_identity_test.dart']) {
      expect(exists(gone), isFalse, reason: gone);
    }
    expect(read('README.md'), allOf(startsWith('# My App'), contains('https://example.invalid/alatyr'), contains('docs/README.md')));
    expect(read('app/README.md'), startsWith('# My App'));
    expect(read('docs/adr/0006-working-placeholder-instantiation.md'), contains('alatyr_starter'));
    expect(read('docs/architecture/01-overview.md'), allOf(contains('my_app'), isNot(contains('alatyr_starter'))));
    expect(File(p.join(root, 'app/web/sqlite3.wasm')).readAsBytesSync(), contains(0));
    expect(read('AGENTS.md'), isNot(contains('my_app')));
  });

  ProcessResult formatCheck(String dir, List<String> files) => Process.runSync(
    Platform.resolvedExecutable, // the pinned SDK's formatter, not PATH's
    ['format', '--output=none', '--set-exit-if-changed', ...files],
    workingDirectory: dir,
  );

  test('the report lists what changed; a short name needs no reformatting', () {
    expect(report.deleted, contains('docs/superpowers'));
    expect(report.movedDirs, hasLength(2));
    expect(report.changedDartFiles, containsAll(['app/lib/app.dart', 'app/lib/bootstrap/app_dependencies.dart', 'app/test/app_test.dart']));
    expect(formatCheck(root, report.changedDartFiles).exitCode, 0);
  });

  test('a long name breaks formatting until the CLI format step runs (spec section 9 step 7)', () {
    final dir = Directory.systemTemp.createTempSync('init_long');
    addTearDown(() => dir.deleteSync(recursive: true));
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), dir.path);
    final tracked = File(p.join('test', 'fixtures', 'init', 'tracked_files.txt')).readAsLinesSync().where((l) => l.isNotEmpty).toList();
    final r = runInit(
      rootDir: dir.path,
      from: deriveIdentity(dir.path),
      to: validateTarget(name: 'very_long_application_name_for_formatting_checks', org: 'io.extremely.lengthy.organization'),
      trackedFiles: tracked,
    );
    // RED before the format step: the longer name rewraps app_dependencies.dart.
    expect(formatCheck(dir.path, r.changedDartFiles).exitCode, isNot(0), reason: 'the long name must require reformatting, or this test proves nothing');
    final formatted = formatChangedDart(rootDir: dir.path, files: r.changedDartFiles, dartExecutable: Platform.resolvedExecutable);
    expect(formatted.exitCode, 0, reason: '${formatted.stderr}');
    expect(formatCheck(dir.path, r.changedDartFiles).exitCode, 0);
  });

  test('a surviving token is a loud postcondition failure', () {
    final dir = Directory.systemTemp.createTempSync('init_post');
    addTearDown(() => dir.deleteSync(recursive: true));
    _copyTree(p.join('test', 'fixtures', 'init', 'template'), dir.path);
    // A tracked file the rewriter treats as binary (NUL first) but that still
    // carries a token: the rewrite skips it, the postcondition must not.
    File(p.join(dir.path, 'app/extra.bin')).writeAsBytesSync([0, ...'dev.alatyr.starter'.codeUnits]);
    final tracked = [...File(p.join('test', 'fixtures', 'init', 'tracked_files.txt')).readAsLinesSync().where((l) => l.isNotEmpty), 'app/extra.bin'];
    expect(
      () => runInit(rootDir: dir.path, from: deriveIdentity(dir.path), to: validateTarget(name: 'my_app', org: 'com.example'), trackedFiles: tracked),
      throwsA(isA<InitPostconditionException>()),
    );
  });
}

/// Materialises the fixture tree, dropping the `.txt` suffix every fixture
/// file carries (no fixture may end in `.dart`: root `dart test` and
/// `dart format` would pick it up).
void _copyTree(String from, String to) {
  for (final entity in Directory(from).listSync(recursive: true, followLinks: false)) {
    final rel = p.relative(entity.path, from: from);
    if (entity is Directory) {
      Directory(p.join(to, rel)).createSync(recursive: true);
    } else if (entity is File) {
      final target = rel.endsWith('.txt') ? rel.substring(0, rel.length - 4) : rel;
      File(p.join(to, target))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entity.readAsBytesSync());
    }
  }
}
```
(The fixture's `tool/init.dart`, `tool/src/init_*.dart`, `tool/template_smoke.sh`, `test/template_identity_test.dart` are one-line placeholders stored as `….txt` — the test checks deletion, not content. The postcondition scan decodes every tracked file tolerantly and does NOT skip binaries; only the rewrite does.)

Run: `fvm dart test test/init_identity_test.dart test/init_validate_test.dart test/init_rewrite_test.dart` → FAIL (libraries missing).

- [ ] **Step 2: Implement**

`tool/src/init_identity.dart`:
```dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// The placeholder identity, derived from the app shell so that tool/ never
/// spells it (test/template_identity_test.dart keeps tool/ token-free).
final class TemplateIdentity {
  const TemplateIdentity({required this.packageName, required this.bundleId, required this.org, required this.displayName, required this.workspaceName});
  final String packageName;
  final String bundleId;
  final String org;
  final String displayName;
  final String workspaceName;
}

final _applicationId = RegExp(r'^\s*applicationId\s*=\s*"([^"]+)"\s*$', multiLine: true);
final _displayName = RegExp(r'<key>CFBundleDisplayName</key>\s*<string>([^<]+)</string>');

TemplateIdentity deriveIdentity(String rootDir) {
  String read(String rel) => File(p.join(rootDir, rel)).readAsStringSync();

  final workspaceName = (loadYaml(read('pubspec.yaml')) as YamlMap)['name'].toString();
  final graph = loadYaml(read('docs/reference/package_graph.yaml')) as YamlMap;
  final appRoots = [
    for (final e in (graph['packages'] as YamlMap).entries)
      if ((e.value as YamlMap)['kind'] == 'app_root') e.key.toString(),
  ];
  if (appRoots.length != 1) {
    throw StateError('package_graph.yaml must have exactly one app_root, found $appRoots');
  }
  final appPubspecName = (loadYaml(read('app/pubspec.yaml')) as YamlMap)['name'].toString();
  if (appPubspecName != appRoots.single) {
    throw StateError('app/pubspec.yaml name "$appPubspecName" != graph app_root "${appRoots.single}"');
  }
  final gradle = read('app/android/app/build.gradle.kts');
  final bundleId = _applicationId.firstMatch(gradle)?.group(1) ?? (throw StateError('applicationId not found in app/android/app/build.gradle.kts'));
  final org = bundleId.substring(0, bundleId.lastIndexOf('.'));
  final plist = read('app/ios/Runner/Info.plist');
  final displayName = _displayName.firstMatch(plist)?.group(1) ?? (throw StateError('CFBundleDisplayName not found in app/ios/Runner/Info.plist'));
  return TemplateIdentity(packageName: appRoots.single, bundleId: bundleId, org: org, displayName: displayName, workspaceName: workspaceName);
}
```

`tool/src/init_validate.dart`:
```dart
final class InitArgumentException implements Exception {
  InitArgumentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The product identity init writes.
final class InitTarget {
  const InitTarget({required this.name, required this.org, required this.displayName, required this.bundleIdSnake, required this.bundleIdCamel, required this.workspaceName});
  final String name;
  final String org;
  final String displayName;

  /// Android applicationId/namespace, Linux APPLICATION_ID: `org.name`.
  final String bundleIdSnake;

  /// iOS/macOS PRODUCT_BUNDLE_IDENTIFIER: `org.camelName` (no underscores,
  /// exactly what `flutter create` generates).
  final String bundleIdCamel;
  final String workspaceName;
}

const _dartKeywords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external', 'factory', 'false', 'final', 'finally', 'for', 'function', 'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library', 'mixin', 'new', 'null', 'of', 'on', 'operator', 'part', 'required', 'rethrow', 'return', 'set', 'show', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
};
// Package names flutter create refuses (they shadow SDK dependencies).
const _flutterReserved = {'flutter', 'flutter_test', 'collection', 'meta'};
const _javaKeywords = {
  'abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char', 'class', 'const', 'continue', 'default', 'do', 'double', 'else', 'enum', 'extends', 'final', 'finally', 'float', 'for', 'goto', 'if', 'implements', 'import', 'instanceof', 'int', 'interface', 'long', 'native', 'new', 'package', 'private', 'protected', 'public', 'return', 'short', 'static', 'strictfp', 'super', 'switch', 'synchronized', 'this', 'throw', 'throws', 'transient', 'try', 'void', 'volatile', 'while', 'true', 'false', 'null',
};
final _name = RegExp(r'^[a-z][a-z0-9_]*$');
// No underscores: the org goes verbatim into Apple bundle identifiers.
final _orgSegment = RegExp(r'^[a-z][a-z0-9]*$');
// The display name lands in Dart strings, XML, JSON, YAML, C++ and a Windows
// resource script without escaping: letters, digits, spaces, dots, hyphens.
final _displayName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9 .-]*$');

InitTarget validateTarget({required String name, required String org, String? displayName}) {
  if (!_name.hasMatch(name)) {
    throw InitArgumentException('--name "$name" must be lowercase_with_underscores starting with a letter (a Dart package name)');
  }
  if (_dartKeywords.contains(name)) {
    throw InitArgumentException('--name "$name" is a Dart keyword');
  }
  if (_flutterReserved.contains(name)) {
    throw InitArgumentException('--name "$name" shadows a Flutter SDK package');
  }
  final segments = org.split('.');
  if (segments.length < 2 || !segments.every(_orgSegment.hasMatch)) {
    throw InitArgumentException('--org "$org" must be a reverse domain of lowercase letters and digits, e.g. com.example (no underscores: Apple bundle ids)');
  }
  for (final segment in [...segments, name]) {
    if (_javaKeywords.contains(segment)) {
      throw InitArgumentException("'$segment' is a Java keyword and cannot be an Android package segment");
    }
  }
  final display = displayName ?? titleCase(name);
  if (!_displayName.hasMatch(display)) {
    throw InitArgumentException('--display-name "$display" may contain only letters, digits, spaces, dots and hyphens, and must not start with a space');
  }
  return InitTarget(
    name: name,
    org: org,
    displayName: display,
    bundleIdSnake: '$org.$name',
    bundleIdCamel: '$org.${camelCase(name)}',
    workspaceName: '${name}_workspace',
  );
}

/// `my_app` -> `myApp` (flutter create's UTI rule).
String camelCase(String snake) {
  final parts = snake.split('_').where((s) => s.isNotEmpty).toList();
  return [parts.first, for (final p in parts.skip(1)) '${p[0].toUpperCase()}${p.substring(1)}'].join();
}

/// `my_app` -> `My App` (flutter create's default display name).
String titleCase(String snake) =>
    snake.split('_').where((s) => s.isNotEmpty).map((p) => '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
```

`tool/src/init_rewrite.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'init_identity.dart';
import 'init_validate.dart';

final class InitPostconditionException implements Exception {
  InitPostconditionException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class InitReport {
  final rewritten = <String>[];
  final deleted = <String>[];
  final movedDirs = <String>[];
  final changedDartFiles = <String>[];
}

/// Paths init removes (spec section 9 step 6): the init machinery, the
/// template-only tests and CI, and the template's planning history.
const templateOnlyPaths = [
  'tool/init.dart',
  'tool/src/init_identity.dart',
  'tool/src/init_validate.dart',
  'tool/src/init_rewrite.dart',
  'tool/template_smoke.sh',
  'test/init_identity_test.dart',
  'test/init_validate_test.dart',
  'test/init_rewrite_test.dart',
  'test/fixtures/init',
  'test/template_identity_test.dart',
  '.github/workflows/template-smoke.yml',
  'docs/superpowers',
];

/// Files whose prose must keep the placeholder: ADRs record decisions.
bool _neverRewrite(String rel) => rel.startsWith('docs/adr/');

/// Apple projects get the camelCase bundle id, everything else the snake one.
bool _isApple(String rel) => rel.startsWith('app/ios/') || rel.startsWith('app/macos/');

InitReport runInit({required String rootDir, required TemplateIdentity from, required InitTarget to, required List<String> trackedFiles, String? templateUrl}) {
  final report = InitReport();

  // 1. Delete template-only paths first so they are never rewritten.
  for (final rel in templateOnlyPaths) {
    final path = p.join(rootDir, rel);
    if (Directory(path).existsSync()) {
      Directory(path).deleteSync(recursive: true);
      report.deleted.add(rel);
    } else if (File(path).existsSync()) {
      File(path).deleteSync();
      report.deleted.add(rel);
    }
  }
  final deletedPrefixes = templateOnlyPaths;
  bool wasDeleted(String rel) => deletedPrefixes.any((d) => rel == d || rel.startsWith('$d/'));

  // 2. Whole-token replacement in file contents. Order matters: the bundle id
  //    (and its slashed path form) before the bare org, the org before the
  //    name. Boundaries: not preceded/followed by [A-Za-z0-9_]; the org may
  //    not be preceded by '.' either (a longer reverse-domain that merely
  //    ends with the org is left alone).
  for (final rel in trackedFiles) {
    if (wasDeleted(rel) || _neverRewrite(rel)) continue;
    final file = File(p.join(rootDir, rel));
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    if (bytes.take(1024).contains(0)) continue; // binary
    final before = utf8.decode(bytes, allowMalformed: true);
    final newId = _isApple(rel) ? to.bundleIdCamel : to.bundleIdSnake;
    var after = before;
    after = _replaceToken(after, from.bundleId, newId, noDotBefore: true);
    after = _replaceToken(after, from.bundleId.replaceAll('.', '/'), to.bundleIdSnake.replaceAll('.', '/'));
    after = _replaceToken(after, from.org, to.org, noDotBefore: true);
    after = _replaceToken(after, from.workspaceName, to.workspaceName);
    after = _replaceToken(after, from.packageName, to.name);
    after = _replaceToken(after, from.displayName, to.displayName);
    if (after != before) {
      file.writeAsStringSync(after);
      report.rewritten.add(rel);
      if (rel.endsWith('.dart')) report.changedDartFiles.add(rel);
    }
  }

  // 3. Descriptions are product text, not token soup.
  _rewriteDescriptions(rootDir, to, report);

  // 4. Package directories follow the Android package.
  for (final base in ['app/android/app/src/main/kotlin', 'app/android/app/src/androidTest/java']) {
    final oldDir = p.join(rootDir, base, from.bundleId.replaceAll('.', '/'));
    final newDir = p.join(rootDir, base, to.bundleIdSnake.replaceAll('.', '/'));
    if (!Directory(oldDir).existsSync()) continue;
    Directory(newDir).createSync(recursive: true);
    for (final entity in Directory(oldDir).listSync()) {
      entity.renameSync(p.join(newDir, p.basename(entity.path)));
    }
    _pruneEmpty(Directory(oldDir), stopAt: p.join(rootDir, base));
    report.movedDirs.add('$base/${from.bundleId.replaceAll('.', '/')} -> $base/${to.bundleIdSnake.replaceAll('.', '/')}');
  }

  // 5. README stubs (the template README is about the template).
  File(p.join(rootDir, 'README.md')).writeAsStringSync(_rootReadme(to, templateUrl));
  File(p.join(rootDir, 'app', 'README.md')).writeAsStringSync(_appReadme(to));

  // 6. Postcondition: no placeholder token survives in any tracked file
  //    that still exists (binaries included - decoded tolerantly), except
  //    the ADRs that record the placeholder on purpose.
  final survivors = <String>[];
  for (final rel in trackedFiles) {
    if (wasDeleted(rel) || _neverRewrite(rel)) continue;
    final file = File(p.join(rootDir, rel));
    if (!file.existsSync()) continue;
    final text = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    for (final token in [from.bundleId, from.org, from.packageName, from.displayName, from.workspaceName]) {
      if (text.contains(token)) survivors.add('$rel: $token');
    }
  }
  if (survivors.isNotEmpty) {
    throw InitPostconditionException('placeholder identity survived init:\n${survivors.join('\n')}');
  }
  return report;
}

String _replaceToken(String text, String from, String to, {bool noDotBefore = false}) {
  final before = noDotBefore ? r'(?<![A-Za-z0-9_.])' : r'(?<![A-Za-z0-9_])';
  return text.replaceAll(RegExp('$before${RegExp.escape(from)}(?![A-Za-z0-9_])'), to);
}

void _rewriteDescriptions(String rootDir, InitTarget to, InitReport report) {
  final description = '${to.displayName} Flutter app.';
  void edit(String rel, Pattern pattern, String replacement) {
    final file = File(p.join(rootDir, rel));
    if (!file.existsSync()) return;
    final before = file.readAsStringSync();
    final after = before.replaceFirst(pattern, replacement);
    if (after != before) {
      file.writeAsStringSync(after);
      if (!report.rewritten.contains(rel)) report.rewritten.add(rel);
    }
  }
  edit('app/pubspec.yaml', RegExp(r'^description: .*$', multiLine: true), 'description: $description');
  // patrol's ios.bundle_id must equal the iOS PRODUCT_BUNDLE_IDENTIFIER
  // (camelCase); the generic pass wrote the snake id because app/pubspec.yaml
  // is not under app/ios/.
  // (Dart's replaceFirst has no group references; match only the value.)
  edit('app/pubspec.yaml', RegExp('(?<=^\\s+bundle_id:\\s)' + RegExp.escape(to.bundleIdSnake) + r'(?=\s*$)', multiLine: true), to.bundleIdCamel);
  edit('app/web/index.html', RegExp(r'<meta name="description" content="[^"]*">'), '<meta name="description" content="$description">');
  edit('app/web/manifest.json', RegExp(r'"description": "[^"]*"'), '"description": "$description"');
}

void _pruneEmpty(Directory dir, {required String stopAt}) {
  var current = dir;
  while (p.normalize(current.path) != p.normalize(stopAt) && current.existsSync() && current.listSync().isEmpty) {
    current.deleteSync();
    current = current.parent;
  }
}

/// The CLI's format step (spec section 9 step 7), separated so the fixture
/// tests can prove it is needed and sufficient.
ProcessResult formatChangedDart({required String rootDir, required List<String> files, required String dartExecutable}) =>
    Process.runSync(dartExecutable, ['format', ...files], workingDirectory: rootDir);

String _rootReadme(InitTarget to, String? templateUrl) {
  final origin = templateUrl == null ? 'the Alatyr Flutter template' : '[the Alatyr Flutter template]($templateUrl)';
  return '''
# ${to.displayName}

Flutter app generated from $origin. The architecture, the workflow and the
quality gate are documented in [docs/README.md](docs/README.md); coding
agents start at [AGENTS.md](AGENTS.md).

```bash
fvm flutter pub get
tool/checks.sh
```
''';
}

String _appReadme(InitTarget to) => '''
# ${to.displayName}

The app shell: `lib/main.dart` boots the composition root in
`lib/bootstrap/`, which wires the feature modules and the base packages with
manual constructor injection and assembles the router from module routes.
''';
```

`tool/init.dart`:
```dart
import 'dart:io';

import 'src/init_identity.dart';
import 'src/init_rewrite.dart';
import 'src/init_validate.dart';

/// One-shot template instantiation (spec section 9). Self-deleting: the
/// rewrite removes this file, its sources, its tests and the template-only
/// CI. Run from the repository root of a git checkout.
///
/// `dart run tool/init.dart --name NAME --org ORG [--display-name TITLE]
/// [--template-url URL] [--yes]`, or `--print-identity` to print the derived
/// placeholder identity as `KEY='value'` lines (for scripts that must not
/// spell it, e.g. tool/template_smoke.sh).
void main(List<String> args) {
  String? name;
  String? org;
  String? displayName;
  String? templateUrl;
  var yes = false;
  var printIdentity = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--name':
        name = _value(args, ++i, '--name');
      case '--org':
        org = _value(args, ++i, '--org');
      case '--display-name':
        displayName = _value(args, ++i, '--display-name');
      case '--template-url':
        templateUrl = _value(args, ++i, '--template-url');
      case '--yes':
        yes = true;
      case '--print-identity':
        printIdentity = true;
      default:
        _usage('unknown argument ${args[i]}');
    }
  }
  final root = Directory.current.path;
  final from = deriveIdentity(root);
  if (printIdentity) {
    stdout
      ..writeln("PACKAGE_NAME='${from.packageName}'")
      ..writeln("BUNDLE_ID='${from.bundleId}'")
      ..writeln("ORG='${from.org}'")
      ..writeln("DISPLAY_NAME='${from.displayName}'")
      ..writeln("WORKSPACE_NAME='${from.workspaceName}'");
    return;
  }
  if (name == null || org == null) {
    _usage('--name and --org are required');
  }
  final tracked = _trackedFiles(root);
  final InitTarget to;
  try {
    to = validateTarget(name: name, org: org, displayName: displayName);
  } on InitArgumentException catch (e) {
    _usage(e.message);
  }

  stdout
    ..writeln('Instantiating the template:')
    ..writeln('  package      ${from.packageName} -> ${to.name}')
    ..writeln('  bundle id    ${from.bundleId} -> ${to.bundleIdSnake} (Apple: ${to.bundleIdCamel})')
    ..writeln('  org          ${from.org} -> ${to.org}')
    ..writeln('  display name ${from.displayName} -> ${to.displayName}')
    ..writeln('  workspace    ${from.workspaceName} -> ${to.workspaceName}')
    ..writeln('Template machinery removed: ${templateOnlyPaths.join(', ')}');
  if (!yes) {
    stdout.write('Proceed? [y/N] ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer != 'y' && answer != 'yes') {
      stderr.writeln('aborted');
      exit(1);
    }
  }

  final report = runInit(rootDir: root, from: from, to: to, trackedFiles: tracked, templateUrl: templateUrl);
  stdout.writeln('Rewrote ${report.rewritten.length} files, moved ${report.movedDirs.length} directories, deleted ${report.deleted.length} paths.');

  // Spec section 9 step 7: format what the rename touched, resolve, smoke.
  final format = formatChangedDart(rootDir: root, files: report.changedDartFiles, dartExecutable: Platform.resolvedExecutable);
  if (format.exitCode != 0) {
    stderr.writeln('dart format failed: ${format.stderr}');
    exit(format.exitCode);
  }
  _run(root, ['pub', 'get'], 'dart pub get');
  _run(root, ['bash', 'tool/checks.sh', '--fast'], 'tool/checks.sh --fast', shell: true);
  stdout.writeln('Done. Commit the result, then run the full gate: tool/checks.sh');
}

String _value(List<String> args, int i, String flag) {
  if (i >= args.length || args[i].startsWith('--')) {
    _usage('$flag needs a value');
  }
  return args[i];
}

Never _usage(String message) {
  stderr
    ..writeln(message)
    ..writeln('usage: dart run tool/init.dart --name NAME --org ORG [--display-name TITLE] [--template-url URL] [--yes] | --print-identity');
  exit(2);
}

List<String> _trackedFiles(String root) {
  final result = Process.runSync('git', ['ls-files', '-z'], workingDirectory: root);
  if (result.exitCode != 0) {
    stderr.writeln('init must run inside a git checkout (git ls-files failed): ${result.stderr}');
    exit(2);
  }
  return (result.stdout as String).split('\u0000').where((s) => s.isNotEmpty).toList();
}

/// Runs `dart <args>` with the SAME Dart that runs this script (the fvm pin
/// when invoked as `fvm dart run tool/init.dart`), or a shell command.
void _run(String root, List<String> args, String label, {bool shell = false}) {
  final result = shell
      ? Process.runSync(args.first, args.sublist(1), workingDirectory: root)
      : Process.runSync(Platform.resolvedExecutable, args, workingDirectory: root);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('$label failed (exit ${result.exitCode})');
    exit(result.exitCode);
  }
}
```
(The template backlink: there is no way to know the template's canonical URL from a "Use this template" copy — `remote.origin.url` is the user's own repository — so the README stub links only when `--template-url` is given and otherwise names the template in plain text.)

Run: `fvm dart test test/init_identity_test.dart test/init_validate_test.dart test/init_rewrite_test.dart` → PASS (≈20 tests). The `split('\u0000')` literal must be the six characters `\u0000`, never a real NUL byte.

- [ ] **Step 3: Gate + commit**

Before the gate: `fvm dart test test/template_identity_test.dart` must stay green — `tool/` derives and never spells the tokens, not even in comments. Run: `fvm dart format . && fvm dart analyze --fatal-infos tool test && tool/checks.sh` → `OK` (the fixture tree holds no `.dart` files, so neither `dart test` nor `dart format` nor the analyzer sees it). Then the real thing on a throwaway copy: `rsync -a --exclude .git --exclude .dart_tool --exclude build ./ /tmp/claude-501/init-proof/ && cd /tmp/claude-501/init-proof && git init -q && git add -A && git -c user.email=x@y -c user.name=x commit -qm base && fvm dart run tool/init.dart --name my_app --org com.example --yes && tool/checks.sh; echo "gate exit=$?"; cd -` → `OK`, exit 0 (≈3 min); delete the copy afterwards.

```bash
git add -A tool test
git commit -m "feat(init): derive-validate-rewrite instantiation with a fixture matrix (tool/init.dart)"
```

---

### Task 6: CI — template smoke (script + workflow), e2e.yml, ci.yml cleanup; Codex PostToolUse formatter

**Files:**
- Create: `tool/template_smoke.sh`, `.github/workflows/template-smoke.yml`, `.github/workflows/e2e.yml`
- Modify: `.github/workflows/ci.yml`, `tool/hooks/format_dart.sh`, `.codex/hooks.json`, `test/guard_generated_test.dart` (format hook cases for the Codex payload), `AGENTS.md` (one sentence), `test/harness_test.dart` (hooks.json assertion: both events)

- [ ] **Step 1: template_smoke.sh + workflow**

`tool/template_smoke.sh` (`chmod +x`; deleted by init):
```bash
#!/usr/bin/env bash
# Template smoke (spec section 11): copy this checkout, make the copy a git
# worktree (the gate's freshness snapshot needs one), instantiate it with
# tool/init.dart and run the FULL gate on the result. Proves that what users
# receive is a working project. Deleted by init.
#   tool/template_smoke.sh [<fixture dir>]   (default: a temp dir)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
FIXTURE="${1:-$(mktemp -d "${TMPDIR:-/tmp}/alatyr-smoke.XXXXXX")/fixture_app}"
mkdir -p "$FIXTURE"
echo "==> Copy -> $FIXTURE"
rsync -a --exclude .git --exclude .dart_tool --exclude build --exclude '*.ru.md' --exclude CLAUDE.local.md "$ROOT_DIR"/ "$FIXTURE"/
cd "$FIXTURE"
git init -q
git -c user.email=smoke@template -c user.name=smoke add -A
git -c user.email=smoke@template -c user.name=smoke commit -qm "template snapshot"
echo "==> Instantiate"
run_dart pub get >/dev/null
# Capture the placeholder identity BEFORE init deletes its own sources; this
# script lives in tool/ and must never spell the tokens itself.
identity="$(run_dart run tool/init.dart --print-identity)"; eval "$identity"
[[ -n "$PACKAGE_NAME" && -n "$BUNDLE_ID" && -n "$ORG" && -n "$DISPLAY_NAME" && -n "$WORKSPACE_NAME" ]] || { echo "could not derive the placeholder identity" >&2; exit 1; }
run_dart run tool/init.dart --name fixture_app --org dev.fixture --yes
echo "==> Assert the template machinery is gone and no identity token survived"
for path in tool/init.dart tool/template_smoke.sh .github/workflows/template-smoke.yml docs/superpowers test/template_identity_test.dart; do
  [[ -e "$path" ]] && { echo "init left $path behind" >&2; exit 1; }
done
survivors="$(git ls-files -z | xargs -0 /usr/bin/grep -aIl -F -e "$PACKAGE_NAME" -e "$BUNDLE_ID" -e "$ORG" -e "$DISPLAY_NAME" -e "$WORKSPACE_NAME" -- 2>/dev/null | grep -v '^docs/adr/' || true)"
[[ -z "$survivors" ]] || { echo "identity token survived init:" >&2; echo "$survivors" >&2; exit 1; }
[[ -d app/android/app/src/main/kotlin/dev/fixture/fixture_app ]] || { echo "Kotlin package dir was not moved" >&2; exit 1; }
grep -q 'DEVELOPMENT_TEAM' app/ios/Runner.xcodeproj/project.pbxproj && { echo "a DEVELOPMENT_TEAM leaked into the iOS project" >&2; exit 1; }
echo "==> Full gate on the instantiated project"
bash tool/checks.sh
echo "template smoke OK ($FIXTURE)"
```
(init does not commit, so `git ls-files` still names the deleted files; `xargs grep` errors on them go to `/dev/null` and only existing files are read. The `DEVELOPMENT_TEAM` assertion is the real-repo check the fixture test cannot make.)

`.github/workflows/template-smoke.yml`:
```yaml
name: Template smoke
on:
  push: { branches: [main] }
  pull_request:
  workflow_dispatch:
concurrency:
  group: template-smoke-${{ github.ref }}
  cancel-in-progress: true
jobs:
  smoke:
    runs-on: ubuntu-latest
    timeout-minutes: 40
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: .fvmrc
          cache: true
      - run: tool/template_smoke.sh "${{ runner.temp }}/fixture_app"
```

Run locally: `tool/template_smoke.sh` (Bash timeout 600000; ≈3–4 min) → `template smoke OK (<dir>)`. Delete the printed fixture dir afterwards (`rm -rf "$(dirname <dir>)"`).

- [ ] **Step 2: e2e.yml and ci.yml**

`.github/workflows/e2e.yml` (advisory until it has a track record — spec §15 risk 5):
```yaml
name: E2E (android)
on:
  pull_request:
    branches: [main]
  workflow_dispatch:
concurrency:
  group: e2e-${{ github.ref }}
  cancel-in-progress: true
jobs:
  android:
    runs-on: ubuntu-latest   # x86_64; KVM is exposed on hosted Linux runners since 2024-04
    timeout-minutes: 45
    # Advisory: hosted-runner emulator viability is unverified (spec section 15,
    # risk 5; docs/reference/ci_contract.md). Flip to required once it is green
    # on a handful of PRs.
    continue-on-error: true
    env:
      PATROL_CLI_VERSION: "4.7.0"   # <-> patrol 4.9.0 in app/pubspec.yaml; tool/e2e.sh checks it
    steps:
      - uses: actions/checkout@v4
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: "17" }
      - uses: subosito/flutter-action@v2
        with:
          flutter-version-file: .fvmrc
          cache: true
      - uses: gradle/actions/setup-gradle@v4
      - run: dart pub global activate patrol_cli "$PATROL_CLI_VERSION"
      - name: Read the device spec from tool/e2e.yaml (single source of truth)
        id: cfg
        run: |
          dart pub get
          eval "$(dart run tool/e2e_config.dart)"
          tag="${ANDROID_SYSTEM_IMAGE_X86_64#system-images;android-*;}"; tag="${tag%;x86_64}"
          {
            echo "api_level=$ANDROID_API_LEVEL"
            echo "target=$tag"
            echo "profile=$ANDROID_DEVICE_PROFILE"
            echo "avd_name=$ANDROID_AVD_NAME"
          } >> "$GITHUB_OUTPUT"
      - name: AVD cache
        uses: actions/cache@v4
        id: avd-cache
        with:
          path: |
            ~/.android/avd/*
            ~/.android/adb*
          key: avd-${{ steps.cfg.outputs.api_level }}-x86_64-${{ steps.cfg.outputs.target }}-${{ steps.cfg.outputs.profile }}-v1
      - name: Create the AVD once (snapshot for the cache)
        if: steps.avd-cache.outputs.cache-hit != 'true'
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ steps.cfg.outputs.api_level }}
          target: ${{ steps.cfg.outputs.target }}
          arch: x86_64
          profile: ${{ steps.cfg.outputs.profile }}
          avd-name: ${{ steps.cfg.outputs.avd_name }}
          force-avd-creation: false
          emulator-options: -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: false
          script: echo "AVD snapshot generated"
      - name: Critical flows
        uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: ${{ steps.cfg.outputs.api_level }}
          target: ${{ steps.cfg.outputs.target }}
          arch: x86_64
          profile: ${{ steps.cfg.outputs.profile }}
          avd-name: ${{ steps.cfg.outputs.avd_name }}
          force-avd-creation: false
          emulator-options: -no-snapshot-save -no-window -gpu swiftshader_indirect -noaudio -no-boot-anim -camera-back none
          disable-animations: true
          emulator-boot-timeout: 900
          script: tool/e2e.sh android --device emulator-5554
      - name: Upload patrol logs
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: patrol-android-logs
          path: |
            app/build/app/outputs/androidTest-results/**
            app/build/app/reports/androidTests/**
          if-no-files-found: ignore
```
(The emulator-runner action boots the device from inputs READ out of `tool/e2e.yaml` by `tool/e2e_config.dart` — one source of truth; `tool/e2e.sh android --device emulator-5554` then only runs patrol on it — CI owns environment, the script owns the run. The action always boots its emulator on console port 5554.)

`.github/workflows/ci.yml` — remove the `libsqlite3-dev` apt step and its comment; add above the gate step a comment: `# sqlite3's Dart hook downloads a sha-pinned prebuilt library from github.com at test time (docs/reference/ci_contract.md).`

Validate: `python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/workflows/*.yml` (PyYAML may be absent → `fvm dart run tool/e2e_config.dart` is unrelated; use `ruby -ryaml -e 'ARGV.each{|f| YAML.load_file(f)}' .github/workflows/*.yml` instead — Ruby ships with macOS).

- [ ] **Step 3: Codex PostToolUse formatter (shared script)**

`tool/hooks/format_dart.sh` — teach it the Codex shape: when the payload has `"tool_name":"apply_patch"`, extract file paths from the `tool_response` string (`A <path>` / `M <path>` lines after `Updated the following files:`, JSON-escaped `\n`), format every existing `*.dart` among them (skipping generated files), exit 0 always:
```bash
#!/usr/bin/env bash
# PostToolUse formatter for BOTH agents: Claude Code (Edit|Write payload with
# tool_input.file_path) and Codex (apply_patch payload whose tool_response
# lists "A/M <path>" lines under "Updated the following files:"). Keeps the
# gate's format stage green. Never blocks (exit 0 always; PostToolUse cannot
# undo the edit); generated files are skipped - codegen owns their formatting.
set -u
payload="$(cat 2>/dev/null || true)"
[[ -z "$payload" ]] && exit 0
paths=""
if printf '%s' "$payload" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"apply_patch"'; then
  paths="$(printf '%s' "$payload" \
    | awk '{ gsub(/\\n/, "\n"); print }' \
    | sed -n '/Updated the following files:/,$p' \
    | sed -n -E 's/^[AM] (.*\.dart)[[:space:]]*$/\1/p' | sed -E 's/\\"/"/g; s/"[[:space:]]*$//')"
else
  paths="$(printf '%s' "$payload" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
targets=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  [[ "$path" == *.g.dart || "$path" == *.freezed.dart || "$path" == *.drift.dart ]] && continue
  [[ "$path" = /* ]] || path="$root/$path"
  [[ -f "$path" ]] && targets+=("$path")
done <<<"$paths"
((${#targets[@]})) || exit 0
if command -v fvm >/dev/null 2>&1; then fvm dart format "${targets[@]}" >/dev/null 2>&1
else dart format "${targets[@]}" >/dev/null 2>&1; fi
exit 0
```

`.codex/hooks.json` — add a `PostToolUse` group (same matcher `Edit|Write`, command `"$(git rev-parse --show-toplevel)/tool/hooks/format_dart.sh"`, timeout 60, statusMessage `format_dart`); update the description to mention both hooks and that each needs `/hooks` trust once.

`test/guard_generated_test.dart` (format group) — add: a Codex payload (`tool_name: apply_patch`, `tool_response: "Exit code: 0\nWall time: 0.1 seconds\nOutput:\nSuccess. Updated the following files:\nA <tmp>/a.dart\nM <tmp>/b.g.dart\n"`) formats `a.dart` and leaves `b.g.dart` alone; relative paths resolve against the git root (use absolute temp paths in the test to stay hermetic).

`test/harness_test.dart` — the `.codex/hooks.json` test now expects BOTH `PreToolUse` (guard) and `PostToolUse` (format) groups with matcher `Edit|Write`.

`AGENTS.md` — add to §8 Commands' paragraph end: `A PostToolUse hook formats every Dart file you edit (both agents); do not fight it — never re-patch to undo formatting.` Keep < 8192 bytes; update `AGENTS.ru.md`.

Run: `fvm dart test test/guard_generated_test.dart test/harness_test.dart` → PASS.

- [ ] **Step 4: Gate + commit**

Run: `fvm dart format . && tool/checks.sh` → `OK`.

```bash
git add -A tool/template_smoke.sh tool/hooks .github .codex test AGENTS.md
git commit -m "feat(ci): template smoke script + workflow, advisory Android e2e workflow, Codex-side dart-format hook"
```

---

### Task 7: Docs, spec and wrap-up — nothing "lands in M5" any more

**Files:**
- Modify: `packages/feature_settings/test/settings_module_test.dart` (skip reason), `AGENTS.md` (§4 rows 7/8, §6 DoD 3, §8 commands: e2e.sh exists; init is template-only and self-deleting), `README.md` (quick start: init exists; e2e; web), `app/README.md` (sentence about init), `docs/README.md`, `docs/reference/critical_flows.md` (prose), `docs/reference/ci_contract.md` (e2e.yml advisory + what it does; template-smoke; libsqlite3-dev dropped; sqlite3 hook network), `docs/reference/package_graph.yaml` (comment line 6), `docs/testing/strategy.md` (e2e row live; patrol exemplar path), `docs/workflow/getting-started.md` (e2e section: `tool/e2e.sh`, patrol_cli pin, devices, disk; init section: template-repo only, what it deletes, per-platform bundle ids), `docs/workflow/maintenance.md` (patrol pin + `PATROL_CLI_VERSION` in e2e.sh/e2e.yml, compileSdk 37, upgrade checklist gains e2e + template smoke), `docs/adr/0003-test-strategy.md`, `docs/adr/0006-working-placeholder-instantiation.md` (consequences: per-platform bundle ids, ADRs never rewritten, token derivation), the spec (status `implementation complete (M5 done)`; §3 tree gains `tool/e2e_config.dart`, `tool/e2e_pick_*.dart`, `tool/template_smoke.sh`, `tool/web_smoke.*`, `app/integration_test/`; §8: the patrol exemplar follows the in-process restart convention and additionally carries a fresh-process test; §9: per-platform bundle ids, display-name/org grammar, token derivation, `--print-identity`, the deletion list = `templateOnlyPaths`, `docs/adr/` never rewritten, `--template-url`; §10: iOS runtime matched by major version; §11: `e2e.yml` advisory with the reason, `template-smoke.yml` runs `tool/template_smoke.sh`, `ci.yml` without `libsqlite3-dev` (sqlite3's Dart hook downloads a sha-pinned prebuilt, outbound HTTPS to github.com required); §15 risk 3 resolved (patrol researched + pinned), risk 5 open (hosted runners unverified — first Actions run decides)), `docs/superpowers/plans/m4-carryover.md` → `m5-carryover.md` (post-M5 backlog)
- Twins for every file

- [ ] **Step 1: Sweep every forward reference**

`git grep -n -i -E 'M5|lands? in|carryover' -- ':!docs/superpowers'` → read EVERY hit (multi-line strings and comments included: known ones are `packages/data_local/lib/src/app_database.dart` (fixed in Task 4), `packages/feature_settings/test/settings_module_test.dart`'s skip reason → present tense naming `app/integration_test/settings_theme_test.dart` as the registered flow, `AGENTS.md` §4 rows 7/8, §6 DoD 3, §8, `README.md`, `app/README.md`, `docs/README.md`, `docs/reference/ci_contract.md`, `critical_flows.md`, `testing/strategy.md`, `adr/0003`, `adr/0006`, `getting-started.md`, `maintenance.md`, `docs/reference/package_graph.yaml` line 6 comment, `tool/checks.sh` header) and rewrite each to present tense with the real command/path, or delete it. Re-run until only `docs/superpowers/**` hits remain. Also rewrite `AGENTS.md` §8 so init is described as template-only and self-deleting (it must read correctly after instantiation, when the file no longer exists).

- [ ] **Step 2: Write the content listed in Files** (each doc stays ≤ 120 lines; ADRs ≤ 60; link checker + Cyrillic scan + page caps enforce the rest). Facts to state verbatim: e2e exit codes (0 passed; patrol's own non-zero on failures; 2 usage; 3 not performed; 124/142 wall-clock kill); `patrol_cli 4.7.0 ↔ patrol 4.9.0` (`PATROL_CLI_VERSION` pinned in `tool/e2e.sh` and `e2e.yml`); the registered flow = in-process restart over the reopened on-disk database (spec §8), plus the fresh-process bonus test (Android orchestrator on / `clearPackageData` off; observed in-order execution on both platforms, the second test fails loudly if not); iOS runtime major-match; `e2e.yml` advisory (`continue-on-error`) until a track record — reads the device spec from `tool/e2e.yaml`; `template-smoke.yml` runs `tool/template_smoke.sh`; init mapping (snake vs camel ids, org without underscores, display-name grammar, title-case default, ADRs untouched, deletions list = `templateOnlyPaths`, `--template-url`, `--print-identity`), `--yes`, the post-init steps, git checkout required; web assets provenance + `tool/web_smoke.sh`; compileSdk 37 + `suppressUnsupportedCompileSdk` + `platforms;android-37` prerequisite; `ci.yml` needs outbound HTTPS to github.com (sqlite3 hook) and no `libsqlite3-dev` (source-verified on the hook, first Linux run confirms). Twins for every touched doc and `AGENTS.ru.md`/`README.ru.md`.

- [ ] **Step 3: Carryover**

`docs/superpowers/plans/m5-carryover.md` (delete `m4-carryover.md` + its twin): title "Post-M5 backlog"; sections `## Open` (e2e.yml hosted-runner viability — flip to required after green runs; iOS e2e in CI — macOS runners, unscheduled; web runtime smoke as an automated check; `patrol` dev dependency vs release builds — verify exclusion; `android.builtInKotlin=true` with patrol 4.9; Codex `/hooks` trust on CI; `AppDatabase.open` `onResult` logging of the chosen web implementation) and `## Recorded as accepted` (carry forward the existing accepted list; add: the e2e flow's two-test coupling; `templateOnlyPaths` is a hardcoded list — init cannot discover new template-only files; the `xcodeproj`-scripted RunnerUITests target is committed as data, the script is not shipped).

- [ ] **Step 4: Gate, twins, commit**

Run: `fvm dart format . && tool/checks.sh` → `OK`; `fvm dart test test/docs_test.dart test/harness_test.dart` → PASS; `wc -c AGENTS.md` < 8192.

```bash
git add -A docs AGENTS.md README.md app/README.md
git commit -m "chore: mark M5 complete in spec status, docs without forward references, post-M5 backlog"
```

(The merge into `main` is the controller's step after the whole-branch review.)

---

## Remaining risks (known at planning time)

- **`e2e.yml` on hosted runners is unverified** (spec §15 risk 5 asks for verification during implementation; this session never pushes, so it cannot be met here): the workflow is advisory (`continue-on-error`) and documented as such; the first real Actions run after the user pushes decides whether it becomes a required check. Local runs on both platforms are the proof this milestone ships. Same for `template-smoke.yml` and the `libsqlite3-dev` removal (source-verified: the sqlite3 hook downloads a sha-pinned Linux prebuilt; a first Linux run confirms).
- **Two-test coupling of the critical flow:** the second test is meaningless alone and the orchestrator's per-test process boundary is relied upon (documented in the test header, the registry and strategy.md). A future patrol relaunch API would let the flow collapse into one test.
- **`compileSdk = 37` diverges from `flutter.compileSdkVersion`:** required by flutter_secure_storage 11; the Flutter upgrade checklist must revisit it (maintenance.md). `android.suppressUnsupportedCompileSdk` hides AGP's warning by design.
- **Init runs only inside a git checkout** (`git ls-files` is the file enumerator); "Use this template" always yields one, and `template_smoke.sh` creates one. A plain archive download is unsupported and says so.
- **`templateOnlyPaths` is a fixed list:** a new template-only file added later without updating it survives init (the template smoke's post-init assertions catch the known ones only).
- **iOS e2e is local-only** (no macOS CI job) — recorded in the backlog.
- **Display names and orgs are deliberately restricted** (ASCII letters/digits/space/dot/hyphen; org segments without underscores) so the raw replacement is safe in every shell file; products needing other characters edit the shells by hand after init (spec §9: post-init identity changes are manual).
- **Template backlink** needs `--template-url`; without it the generated README names the template in plain text — the canonical URL is not known to the tool (open question for the user).
