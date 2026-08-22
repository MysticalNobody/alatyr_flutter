# M4 — Agent Harness: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The instruction layer and the two-agent harness the spec promises — `AGENTS.md` + `CLAUDE.md`, path-scoped rules, one hook script wired into both Claude Code and Codex, the `cross-review` and `adversarial-tests` skills, the `test-breaker` subagent, `.codex/` config + findings schema, the complete docs set of spec §13, and a root test suite that keeps all of it honest (size caps, links, English-only, hook behaviour on real payloads).

**Architecture:** Prose is layered exactly as spec §4 orders it (user > AGENTS.md > docs/architecture > ADRs > docs/reference > README), and every rule that must always hold is owned by a tool (Principle 2): the `guard_generated` hook blocks hand edits of generated files in both agents, the gate stays the backstop, and new root tests enforce the harness's own invariants (AGENTS.md < 8 KB, `@AGENTS.md` import, rule frontmatter, hook behaviour, doc links, no Cyrillic in shipped files). Role instructions ("act as a reviewer, read-only") live only in the skill and the per-call Codex flags — never in AGENTS.md, which Codex applies to implementation runs too.

**Tech Stack (verified on this machine in the research pass):** Claude Code 2.1.235 (hooks: PreToolUse/PostToolUse, `${CLAUDE_PROJECT_DIR}`, exit 2 = block; `@file` imports; `.claude/rules/*.md` with `paths:` frontmatter; subagent + skill frontmatter), Codex CLI 0.144.6 (project `.codex/hooks.json` with PreToolUse on `apply_patch` matched by `Edit|Write`, exit 2 = block, per-hook trust via `/hooks`; `codex exec review --base <ref>`; `codex exec --output-schema` strict JSON; `[profiles.*]` in project config is IGNORED since 0.134), bash + sed/awk/grep only in hook scripts (no jq/python dependency).

**Spec:** `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` §4, §6 (agent-level hooks), §7, §10 (adversarial), §12, §13, §15, §16-M4. **Carryover:** `docs/superpowers/plans/m3-carryover.md` (M4 section — this plan closes it).

**Verified reference (may be gone in a later session; the plan is self-sufficient):** `/private/tmp/claude-501/-Users-nikitakhilobok-Documents-projects-my-alatyr-flutter/274f6fc9-972b-474e-8cfd-9d8077742bfc/scratchpad/m4-research.md` (probe facts: captured Codex hook payload, working invocations, strict schema example, Claude Code doc citations, the repo fact sheet).

## Global Constraints

- English only in every shipped file. New root test enforces it: no Cyrillic in any tracked file (`*.ru.md` twins are gitignored; CLAUDE.local.md is gitignored).
- `AGENTS.md` < 8192 bytes (spec §4); `CLAUDE.md` line 1 is exactly `@AGENTS.md`. Rubric (*what findings matter*) lives in AGENTS.md; role instructions (*act as reviewer, read-only, sandbox*) live only in the skills and per-call flags.
- One hook script for both agents: `tool/hooks/guard_generated.sh`; exit 2 + stderr = block; unparsable input → exit 0 (the codegen-freshness gate is the backstop, spec §6).
- Hook scripts use bash + POSIX `sed -E`/`awk`/`grep` only — no `jq`, no `python3` (BSD and GNU compatible).
- Codex reality (verified): no `[profiles.review]` in project config (ignored with a warning); reviewer constraints are passed per call: `-s read-only --ephemeral -c model_reasoning_effort="high" -c skills.include_instructions=false`; `codex review` has no `--json` and a prompt cannot be combined with `--base` → primary path is `codex exec … review --base <ref> -o <file>`, structured path is `codex exec … --output-schema .codex/review-schema.json`. Always redirect stdin (`< /dev/null` or the diff) — an open TTY-less stdin makes `codex exec` wait.
- Codex project hooks load only after project trust AND per-hook trust (`/hooks` in the TUI); untrusted hooks are skipped silently. Docs must say so; the gate stays the backstop.
- Docs: every file of spec §13's tree exists; every relative markdown link resolves (root test); each architecture doc is 1–2 pages (≤ ~120 lines); nothing claims M5 deliverables exist (`tool/init.dart`, `tool/e2e.sh`, `e2e.yaml`, patrol e2e, `integration_test/`, web assets, critical-flows gate stage) — say "lands in M5".
- Claude Code loads `.claude/settings.json` (hooks, permissions) and `CLAUDE.md` from the directory it is STARTED in — sessions must start at the repository root; docs and CLAUDE.md say so.
- Facts docs must state exactly (from the repo at 8c2d361): gate tiers `--fast` / full / `--package <dir>`; full-tier order: format → dependency graph → architecture imports → codegen (cold rebuild) + snapshot compare → transitive purity → root `dart analyze --fatal-infos .` (loads the `alatyr_lints` plugin — as does the per-member `dart analyze`; one-shot `flutter analyze` does not, sdk#63787) → root `dart test` → per-member `dart analyze` + `flutter test --no-pub`/`dart test` → lints isolated → lints integration fixture; timeouts `CHECKS_ANALYZE_TIMEOUT=180`, `CHECKS_TEST_TIMEOUT=300`, `CHECKS_CODEGEN_TIMEOUT=600` (env-overridable; `gtimeout` → `timeout` → perl-alarm fallback, `brew install coreutils` recommended); resolved versions drift 2.34.3 / drift_dev 2.34.0 / drift_flutter 0.3.1 / sqlite3 3.5.2 / build_runner 2.15.1 / freezed 3.2.5 / freezed_annotation 3.1.0 / flutter_bloc 9.1.1 / bloc_test 10.0.0 / mocktail 1.0.5 / go_router 17.5.0 / flutter_secure_storage 11.0.0 / patrol_finders 3.6.0 / flutter_lints 6.0.0; analyzer 10.2.0 in the workspace vs 14.1.0 + analysis_server_plugin 0.3.20 in `lints/` (never quote "the analyzer version"); freezed 3.2.5's `analyzer <11` cap holds drift_dev at 2.34.0 and build_runner at 2.15.1; 12 banned packages with reasons in `package_graph.yaml`; identity tokens `alatyr_starter`, `dev.alatyr` (bundle `dev.alatyr.starter`), `Alatyr Starter`, `alatyr_workspace`.
- Commands: `fvm dart` / `fvm flutter`; `fvm dart format .` then `tool/checks.sh --fast` before every commit (the gate's first stage is a format CHECK and the snippets below are not all format-clean as inlined), full gate at the end of every task (Bash timeout 600000 ms). TDD for every test file; conventional commits — every `git commit` below carries the trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` (shown once in Task 1, implied afterwards); never push.
- Work on branch `feat/m4-agent-harness` (from `main`).
- Russian twins (`*.ru.md`, gitignored, local rule): every new/edited doc under `docs/`, plus `AGENTS.md` and `README.md`, gets/updates its twin in the same task.

---

### Task 1: AGENTS.md, CLAUDE.md, path-scoped rules, harness tests

**Files:**
- Create: `AGENTS.md`, `CLAUDE.md`, `.claude/rules/testing.md`, `.claude/rules/widgets.md`, `.claude/rules/codegen.md`
- Test: `test/harness_test.dart` (AGENTS.md size, CLAUDE.md import, rules frontmatter)
- Twins: `AGENTS.ru.md` (gitignored)

**Interfaces:**
- Produces: the canonical contract other tasks reference (`## Code Review Rules` consumed by Task 3's skill; DoD items 2 and 4 consumed by Tasks 3–4's skills); `test/harness_test.dart` that later tasks extend (Task 2 adds settings/hooks checks).

- [ ] **Step 1: Branch + failing harness test**

```bash
git checkout -b feat/m4-agent-harness main
```

`test/harness_test.dart`:
```dart
import 'dart:io';

import 'package:test/test.dart';

/// The harness's own invariants (spec section 4): the contract stays under
/// Codex's comfortable budget, Claude imports it rather than duplicating
/// it, and every path-scoped rule declares the paths it binds to.
void main() {
  test('AGENTS.md exists and is under 8 KB', () {
    final file = File('AGENTS.md');
    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), lessThan(8192));
  });

  test('CLAUDE.md imports AGENTS.md on its first line', () {
    final lines = File('CLAUDE.md').readAsLinesSync();
    expect(lines.first, '@AGENTS.md');
  });

  test('AGENTS.md ends with the Code Review Rules section', () {
    final content = File('AGENTS.md').readAsStringSync();
    final index = content.indexOf('## Code Review Rules');
    expect(index, greaterThan(0));
    expect(content.indexOf('\n## ', index + 1), -1,
        reason: 'Code Review Rules must be the final section');
  });

  test('every .claude/rules file declares paths: frontmatter', () {
    final rules = Directory('.claude/rules')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(rules.map((f) => f.uri.pathSegments.last).toSet(),
        {'testing.md', 'widgets.md', 'codegen.md'});
    for (final rule in rules) {
      final lines = rule.readAsLinesSync();
      expect(lines.first, '---', reason: '${rule.path} has no frontmatter');
      final end = lines.indexOf('---', 1);
      expect(end, greaterThan(1), reason: '${rule.path} frontmatter unterminated');
      final frontmatter = lines.sublist(1, end);
      expect(frontmatter, contains('paths:'), reason: rule.path);
      expect(frontmatter.any((l) => RegExp(r'^\s+-\s+".+"$').hasMatch(l)), isTrue,
          reason: '${rule.path}: paths entries are quoted globs');
    }
  });
}
```

Run: `fvm dart test test/harness_test.dart` → FAIL (files missing).

- [ ] **Step 2: AGENTS.md**

```markdown
# AGENTS.md — the Alatyr agent contract

Canonical instructions for every coding agent in this repository. Claude
Code imports this file from `CLAUDE.md`; Codex reads it natively. Keep it
under 8 KB: machine-readable files carry the detail.

## 1. Instruction priority

user > this file > `docs/architecture` > `docs/adr` > `docs/reference` >
`README.md`. The ladder governs prose only: machine-readable files
(`docs/reference/package_graph.yaml`, `docs/reference/critical_flows.md`)
outrank any prose that restates them — on conflict the machine file wins
and the prose is the bug.

## 2. Canonical stack

State `bloc` / `flutter_bloc` · navigation `go_router` · DI: manual
constructor injection · local DB `drift` · codegen models `freezed`
(+ `json_serializable`) · secure storage `flutter_secure_storage` · widget
and e2e tests `patrol_finders` / `patrol` · test doubles `mocktail` ·
networking reserved: `dio` (+ `retrofit`) enters with the first
`data_remote` package through the ritual. Banned alternatives and their
reasons live in `docs/reference/package_graph.yaml`. Toolchain: Flutter
pinned by `.fvmrc` — always `fvm flutter` / `fvm dart`.

## 3. Package kinds and boundaries

Four kinds — `base`, `feature_api`, `feature_impl`, `app_root` — declared
per package in `docs/reference/package_graph.yaml`, the single source of
truth for allowed edges (three independent enforcers read it). Contract:
`feature_x_api` ships contracts only (route spec, models, ports, failure
codes, key namespace); `feature_x` exports exactly one factory
`createXModule(...)` returning `XModule { routes, api }`; only `app/`
constructs implementations (`app/lib/bootstrap/`) and assembles the router.

## 4. Hard invariants

1. Cross-feature dependencies go only through `*_api` packages.
2. Only `app/` may depend on feature implementation packages.
3. `app_core` and `app_config` stay pure Dart (no Flutter SDK).
4. Runtime secrets and tokens live only behind `data_secure` — never in
   drift, prefs, logs, messages, or source.
5. Generated files (`*.g.dart`, `*.freezed.dart`, `*.drift.dart`) are
   never hand-edited; regenerate with `tool/codegen.sh`.
6. Any dependency change starts with a `package_graph.yaml` edit approved
   by a human before implementation code is written.
7. Every interactive widget carries a `ValueKey` from its feature's key
   namespace (`<feature>.<screen>.<element>`, e.g. `SettingsKeys`).
8. Widget and integration tests use patrol finders; every critical flow
   has a patrol test registered in `docs/reference/critical_flows.md`.
9. No dependency outside the canonical stack without an accepted ADR. Tools
   enforce the banned list in `package_graph.yaml` (authoritative); the ADR
   requirement for other newcomers is review-owned.

| Invariant | Enforced by |
|---|---|
| 1, 2, 3, 9 (banned list) | `tool/verify_dependencies.dart` + `tool/verify_imports.dart` + the `alatyr_lints` plugin — all read the graph; the ADR half of 9 is review-owned |
| 4 | secret-leak scan over `data_local` (`verify_imports`) + `Read` deny on `.dart-defines/*.env` + the review rubric (full semantic tracking is review-owned — accepted gap) |
| 5 | `tool/hooks/guard_generated.sh` in both agents + the codegen-freshness stage (cold rebuild) |
| 6 | human graph-diff approval |
| 7 | review rubric + patrol e2e (no lint rule yet — accepted gap) |
| 8 | critical-flows registry check in the gate (lands in M5) + review rubric |

## 5. The graph-first feature ritual

1. Propose the package shape by editing `package_graph.yaml`; draft the
   plan. 2. Optional, recommended for non-trivial work: challenge the plan
   with a fresh read-only Codex pass (`docs/workflow/feature-workflow.md`).
3. A human approves the graph diff. 4. Implement in order: `*_api` →
impl → wiring in `app/`. 5. Tools enforce continuously; the gate, the
adversarial pass, cross-review and the behavioral check close the loop.

## 6. Definition of Done

1. `tool/checks.sh` (full) is green.
2. Adversarial pass done: test-breaker scenarios are covered by tests or
   skipped in code with a reason — `skip: 'deliberate: …'`.
3. `tool/e2e.sh` is green when critical flows are touched (lands in M5).
4. Cross-review completed; no open P0/P1 finding — each is fixed or
   rebutted with recorded reasoning. If review is honestly impossible
   (`codex` absent, model rejected), the human waives this item explicitly
   and the waiver is recorded; the agent never waives it.
5. Human behavioral check for UI-affecting changes.

Every completion report ends with a **Remaining risks** section —
waivers, deliberate skips, unverified assumptions; an empty section says
"none" explicitly.

## 7. Stop conditions

Ambiguity → stop and ask, or file an ADR draft from `docs/adr/template.md`.
Never improvise around a failing gate. Keep diffs scoped to the task.

## 8. Commands

`tool/checks.sh --fast` (format → graph → imports; the inner loop) ·
`tool/checks.sh` (full gate) · `tool/checks.sh --package <dir>` ·
`tool/codegen.sh [--cold]` · `tool/e2e.sh` and `dart run tool/init.dart`
(both land in M5).

## Code Review Rules

Flag P0/P1 only: unawaited futures; `BuildContext` used across an async
gap; missing `dispose`; `setState`/`emit` after dispose or close; secrets
or tokens in code, logs, or drift; semantic violations of `*_api`
contracts; tests that assert nothing; adversarial scenarios silently
dropped. Leave formatting and style to the gate.
```

- [ ] **Step 3: CLAUDE.md**

```markdown
@AGENTS.md

# Claude Code notes

- **Skills (repo-level, `.claude/skills/`):** `/cross-review [base-ref]`
  after the gate is green and before declaring a task done (DoD 4);
  `/adversarial-tests <feature_api package dir> [feature impl dir]` after
  the first green implementation of new behaviour (DoD 2). Both read
  AGENTS.md themselves — do not paraphrase the rubric into prompts.
- **Hooks (`.claude/settings.json`):** a PreToolUse hook blocks `Edit`/
  `Write` on `*.g.dart`, `*.freezed.dart`, `*.drift.dart` — when it fires,
  change the source and run `tool/codegen.sh`; a PostToolUse hook runs
  `dart format` on every Dart file you edit, so the format stage stays
  green without extra commands.
- **Permissions:** `Read` of `.dart-defines/*.env` is denied; only the
  committed `*.env.example` files are yours to read.
- **Rules:** path-scoped conventions load automatically from
  `.claude/rules/` (testing, widgets, codegen) when you touch matching
  files.
- **Start at the repository root.** Project settings (hooks, permissions)
  and this file load only from the directory the session starts in; a
  session started in `app/` has neither the hooks nor the deny rule.
- **Toolchain:** `fvm flutter` / `fvm dart`. Lint-plugin diagnostics only
  surface under `dart analyze` (sdk#63787); `flutter analyze` is not the
  gate's analyzer.
- **Subagents:** `test-breaker` (`.claude/agents/`) generates adversarial
  scenarios from a fresh context; `codex-reviewer` wraps the cross-review
  script for workflows. Neither edits files.
- Every completion report ends with **Remaining risks**.
- `CLAUDE.local.md` (gitignored) is the personal-overrides file.
```

- [ ] **Step 4: Rules**

`.claude/rules/testing.md`:
```markdown
---
paths:
  - "**/test/**"
  - "**/integration_test/**"
---

# Testing conventions

- Widget and integration tests use patrol finders: `patrolWidgetTest`,
  `$(#feature.screen.element)` / `$(SettingsKeys.x)`, `.tap()`, `.exists`.
  `$.tester.widget<T>(finder)` is the only raw-tester use — reading a widget
  property. No `find.byKey`/`find.byType` in new tests.
- Test names are the test cases (`'given stored theme is corrupted,
  settings falls back to system'`); the case catalog is generated from
  code, never hand-maintained.
- Deliberately uncovered scenarios become stubs:
  `test('…', () {}, skip: 'deliberate: <reason>')`.
- FakeAsync rules (the exemplars in `packages/feature_settings/test/` and
  `app/test/` embody them): the widget tree owns blocs
  (`BlocProvider(create:)`); never `await`, in the body or a
  `tearDown`/`addTearDown`, a `Bloc.close()`, `StreamController.close()`,
  or drift `close()` created inside a `testWidgets` body — use
  `unawaited(...)`; never `await` a drift-backed stream (`.first`,
  `await for`) inside the body — assert through `read()`; drift schedules a
  zero-duration timer when a watch subscription is cancelled, so
  drift-backed widget tests end with an explicit unmount
  (`pumpWidget(SizedBox.shrink())` + `pump(Duration.zero)`).
- A progress indicator animates forever: use plain pumps, not
  `pumpWidgetAndSettle`, while one is on screen.
- Per-test `GoRouter` → `dispose()` it; `BlocProvider(create:)` is lazy;
  adapter methods over plugins are `async` so sync throws become rejected
  futures; `$(#a.b.c)` matches `ValueKey<String>('a.b.c')` only.
- Run tests with `fvm flutter test --no-pub` (Flutter members) or `fvm dart
  test` (pure packages, root); the full gate is `tool/checks.sh`.
```

`.claude/rules/widgets.md`:
```markdown
---
paths:
  - "packages/design_system/**"
  - "**/widgets/**"
  - "**/ui/**"
---

# Widget conventions

- One public `StatelessWidget`/`StatefulWidget` per file (lint
  `alatyr_one_widget_per_file`); no named function or method other than
  `build` returns `Widget` (`alatyr_no_widget_returning_function`); no
  nested ternaries (`alatyr_no_nested_ternary`).
- Every interactive widget carries a `ValueKey` from its feature's key
  namespace: a `<Feature>Keys` class in the feature's `*_api` package with a
  private `_ns` and `ValueKey<String>('<ns>.<screen>.<element>')` members
  (template: `SettingsKeys`). Base widgets make the key a constructor
  requirement (`required Key super.key`, see `AppChoiceTile`).
- Tokens before numbers: `AppSpacing`, `AppRadii`; colours come from
  `Theme.of(context).colorScheme`; themes from `AppTheme.light()/dark()`.
- Public fields never promote: shadow them (`final failure = this.failure;`)
  before null checks.
```

`.claude/rules/codegen.md`:
```markdown
---
paths:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.drift.dart"
---

# Generated code

Never edit these files by hand — change the source file (`part of` target)
and run `tool/codegen.sh` (warm) from the repository root. The gate's
freshness stage regenerates cold and fails on any delta; a PreToolUse hook
blocks edits in both agents.
```

Run: `fvm dart test test/harness_test.dart` → PASS (4 tests). Check: `wc -c AGENTS.md` < 8192.

- [ ] **Step 5: Twin, gate, commit**

Write `AGENTS.ru.md` (translation; gitignored). Run `tool/checks.sh` → `OK`.

```bash
fvm dart format test && tool/checks.sh --fast
git add AGENTS.md CLAUDE.md .claude/rules test/harness_test.dart
git commit -m "feat(harness): AGENTS.md contract, CLAUDE.md import bridge, path-scoped rules" -m "Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: One hook script, two configs — guard_generated + format hooks, settings.json, hooks.json

**Files:**
- Create: `tool/hooks/guard_generated.sh`, `tool/hooks/format_dart.sh`, `.claude/settings.json`, `.codex/hooks.json`
- Test: `test/guard_generated_test.dart`, `test/harness_test.dart` (extend)

**Interfaces:**
- Produces: `tool/hooks/guard_generated.sh` — stdin: a Claude Code PreToolUse payload (`tool_input.file_path`) or a Codex PreToolUse payload (`tool_name: apply_patch`, `tool_input.command` = patch text); exit 2 + stderr message containing `tool/codegen.sh` when any target path ends with `.g.dart`, `.freezed.dart` or `.drift.dart`; exit 0 otherwise (including unparsable input). `tool/hooks/format_dart.sh` — PostToolUse (Claude): formats the edited `.dart` file, always exit 0.

- [ ] **Step 1: Failing tests with the real payload shapes**

`test/guard_generated_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Drives the hook script with the payload shapes both agents really send
/// (captured in the M4 research pass) and checks the exit-code contract:
/// 2 = block, 0 = allow, unparsable = allow (the gate is the backstop).
Future<ProcessResult> runGuard(String stdin) async {
  final process = await Process.start('bash', ['tool/hooks/guard_generated.sh']);
  process.stdin.write(stdin);
  await process.stdin.close();
  final out = await process.stdout.transform(utf8.decoder).join();
  final err = await process.stderr.transform(utf8.decoder).join();
  return ProcessResult(process.pid, await process.exitCode, out, err);
}

String claudePayload(String tool, String filePath) => jsonEncode({
  'session_id': 'abc',
  'transcript_path': '/tmp/t.jsonl',
  'cwd': '/repo',
  'hook_event_name': 'PreToolUse',
  'tool_name': tool,
  'tool_input': tool == 'Write'
      ? {'file_path': filePath, 'content': 'x'}
      : {'file_path': filePath, 'old_string': 'a', 'new_string': 'b'},
});

String codexPayload(String patch) => jsonEncode({
  'session_id': '01a0',
  'turn_id': '01a0',
  'transcript_path': null,
  'cwd': '/repo',
  'hook_event_name': 'PreToolUse',
  'model': 'gpt-5.6-sol',
  'permission_mode': 'default',
  'tool_name': 'apply_patch',
  'tool_input': {'command': patch},
  'tool_use_id': 'exec-1',
});

void main() {
  test('Claude Write on a .g.dart file is blocked with the codegen hint', () async {
    final r = await runGuard(claudePayload('Write', '/repo/packages/data_local/lib/src/app_database.g.dart'));
    expect(r.exitCode, 2);
    expect(r.stderr, contains('tool/codegen.sh'));
  });

  test('Claude Edit on .freezed.dart and .drift.dart files is blocked', () async {
    expect((await runGuard(claudePayload('Edit', '/r/lib/s.freezed.dart'))).exitCode, 2);
    expect((await runGuard(claudePayload('Edit', '/r/lib/s.drift.dart'))).exitCode, 2);
  });

  test('Claude Edit on a hand-written Dart file is allowed', () async {
    final r = await runGuard(claudePayload('Edit', '/repo/packages/data_local/lib/src/key_value_dao.dart'));
    expect(r.exitCode, 0);
    expect(r.stderr, isEmpty);
  });

  test('a file whose name merely contains "g.dart" is allowed (suffix match only)', () async {
    expect((await runGuard(claudePayload('Write', '/r/lib/config.dart'))).exitCode, 0);
    expect((await runGuard(claudePayload('Write', '/r/lib/big.dart'))).exitCode, 0);
  });

  test('Codex apply_patch touching a generated file among others is blocked', () async {
    const patch = '*** Begin Patch\n*** Update File: packages/data_local/lib/src/key_value_dao.dart\n@@\n-a\n+b\n*** Add File: packages/data_local/lib/src/key_value_dao.g.dart\n+hello\n*** End Patch';
    final r = await runGuard(codexPayload(patch));
    expect(r.exitCode, 2);
    expect(r.stderr, contains('key_value_dao.g.dart'));
  });

  test('Codex apply_patch moving a file onto a generated name is blocked', () async {
    const patch = '*** Begin Patch\n*** Update File: lib/a.dart\n*** Move to: lib/a.freezed.dart\n@@\n-a\n+b\n*** End Patch';
    expect((await runGuard(codexPayload(patch))).exitCode, 2);
  });

  test('Codex apply_patch on hand-written files only is allowed', () async {
    const patch = '*** Begin Patch\n*** Add File: demo.txt\n+hello\n*** Update File: lib/main.dart\n@@\n-a\n+b\n*** End Patch';
    expect((await runGuard(codexPayload(patch))).exitCode, 0);
  });

  test('a generated-file name mentioned only inside patch content does not block', () async {
    const patch = '*** Begin Patch\n*** Update File: docs/x.md\n@@\n-a\n+see app_database.g.dart for the schema\n*** End Patch';
    expect((await runGuard(codexPayload(patch))).exitCode, 0);
  });

  test('a Claude Write whose CONTENT quotes Codex patch headers or a file_path key is allowed', () async {
    final payload = jsonEncode({
      'hook_event_name': 'PreToolUse',
      'tool_name': 'Write',
      'tool_input': {
        'file_path': '/repo/docs/workflow/getting-started.md',
        'content': 'Example payload:\n*** Add File: demo.g.dart\n{"file_path":"x.freezed.dart"}\n',
      },
    });
    final r = await runGuard(payload);
    expect(r.exitCode, 0, reason: r.stderr);
  });

  test('unparsable or empty input is allowed (fail open; the gate is the backstop)', () async {
    expect((await runGuard('')).exitCode, 0);
    expect((await runGuard('{}')).exitCode, 0);
    expect((await runGuard('not json at all')).exitCode, 0);
  });

  group('format_dart.sh (PostToolUse)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('format_hook'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<int> runFormat(String filePath) async {
      final process = await Process.start('bash', ['tool/hooks/format_dart.sh']);
      process.stdin.write(jsonEncode({'tool_name': 'Write', 'tool_input': {'file_path': filePath, 'content': ''}}));
      await process.stdin.close();
      await process.stdout.drain<void>();
      await process.stderr.drain<void>();
      return process.exitCode;
    }

    test('formats the edited Dart file and exits 0', () async {
      final file = File('${tmp.path}/a.dart')..writeAsStringSync('void main(){print( 1 );}\n');
      expect(await runFormat(file.path), 0);
      expect(file.readAsStringSync(), 'void main() {\n  print(1);\n}\n');
    });

    test('leaves generated files and non-Dart files alone, still exit 0', () async {
      final gen = File('${tmp.path}/a.g.dart')..writeAsStringSync('void main(){print( 1 );}\n');
      expect(await runFormat(gen.path), 0);
      expect(gen.readAsStringSync(), 'void main(){print( 1 );}\n');
      expect(await runFormat('${tmp.path}/missing.dart'), 0);
      expect(await runFormat('${tmp.path}/notes.md'), 0);
    });
  });
}
```

Extend `test/harness_test.dart` with a new group:
```dart
  group('hook wiring', () {
    test('.claude/settings.json wires both hooks to existing executable scripts and denies env reads', () {
      final settings = jsonDecode(File('.claude/settings.json').readAsStringSync()) as Map<String, dynamic>;
      final hooks = settings['hooks'] as Map<String, dynamic>;
      final commands = <String>[];
      for (final event in ['PreToolUse', 'PostToolUse']) {
        final groups = hooks[event] as List<dynamic>;
        for (final group in groups.cast<Map<String, dynamic>>()) {
          expect(group['matcher'], 'Edit|Write');
          for (final h in (group['hooks'] as List<dynamic>).cast<Map<String, dynamic>>()) {
            expect(h['type'], 'command');
            commands.add(h['command'] as String);
          }
        }
      }
      expect(commands.any((c) => c.contains('tool/hooks/guard_generated.sh')), isTrue);
      expect(commands.any((c) => c.contains('tool/hooks/format_dart.sh')), isTrue);
      for (final script in ['tool/hooks/guard_generated.sh', 'tool/hooks/format_dart.sh']) {
        final stat = File(script).statSync();
        expect(stat.mode & 0x49, 0x49, reason: '$script must be executable (u+x,g+x,o+x)');
      }
      final deny = (settings['permissions'] as Map<String, dynamic>)['deny'] as List<dynamic>;
      expect(deny, contains('Read(/.dart-defines/*.env)'));
    });

    test('.codex/hooks.json wires the same guard script via the git root', () {
      final hooks = jsonDecode(File('.codex/hooks.json').readAsStringSync()) as Map<String, dynamic>;
      final pre = ((hooks['hooks'] as Map<String, dynamic>)['PreToolUse'] as List<dynamic>).cast<Map<String, dynamic>>();
      expect(pre.single['matcher'], 'Edit|Write');
      final command = ((pre.single['hooks'] as List<dynamic>).single as Map<String, dynamic>)['command'] as String;
      expect(command, contains('git rev-parse --show-toplevel'));
      expect(command, contains('tool/hooks/guard_generated.sh'));
    });
  });
```
(add `import 'dart:convert';` at the top.)

Run: `fvm dart test test/guard_generated_test.dart test/harness_test.dart` → FAIL.

- [ ] **Step 2: The guard script**

`tool/hooks/guard_generated.sh` (then `chmod +x`):
```bash
#!/usr/bin/env bash
# ONE hook script for BOTH agents (spec section 6): blocks hand edits of
# generated Dart files (*.g.dart, *.freezed.dart, *.drift.dart).
#
# Payloads (captured in the M4 research pass):
#   Claude Code PreToolUse, matcher Edit|Write:
#     {"tool_name":"Write","tool_input":{"file_path":"/abs/x.g.dart",...}}
#   Codex PreToolUse, matcher Edit|Write (alias of apply_patch):
#     {"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n
#      *** Add File: x.g.dart\n+...\n*** End Patch"}}
# Contract: exit 2 + message on stderr = block (both agents show the
# message to the model); exit 0 = allow. Anything we cannot parse is
# allowed - the codegen-freshness gate is the backstop, this hook is the
# fast path. bash + POSIX sed/awk/grep only: no jq, no python.
set -u
payload="$(cat 2>/dev/null || true)"
[[ -z "$payload" ]] && exit 0

claude_paths=""; codex_paths=""
if printf '%s' "$payload" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"apply_patch"'; then
  # Codex shape: patch headers inside the JSON-escaped command string.
  # Unescape \n so the headers sit on their own lines, then keep the targets.
  codex_paths="$(printf '%s' "$payload" \
    | awk '{ gsub(/\\n/, "\n"); print }' \
    | grep -E '^\*\*\* (Add|Update|Delete) File: |^\*\*\* Move to: ' \
    | sed -E 's/^\*\*\* (Add|Update|Delete) File: //; s/^\*\*\* Move to: //; s/\\"/"/g; s/[[:space:]]*$//')"
else
  # Claude shape: the FIRST "file_path" value - tool_input.file_path precedes
  # the content, so text inside the content cannot be mistaken for it.
  claude_paths="$(printf '%s' "$payload" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
fi

blocked="$(printf '%s\n%s\n' "$claude_paths" "$codex_paths" \
  | grep -E '\.(g|freezed|drift)\.dart$' || true)"

if [[ -n "$blocked" ]]; then
  {
    echo "Generated file(s) must not be hand-edited:"
    printf '%s\n' "$blocked" | sed 's/^/  /'
    echo "Edit the source (the 'part of' target) and run tool/codegen.sh instead (hard invariant 5)."
  } >&2
  exit 2
fi
exit 0
```

`tool/hooks/format_dart.sh` (then `chmod +x`):
```bash
#!/usr/bin/env bash
# Claude Code PostToolUse (Edit|Write): keep the gate's format stage green
# by formatting the Dart file that was just written. Never blocks (exit 0
# always; PostToolUse cannot undo the edit anyway). Generated files are
# skipped - codegen owns their formatting. fvm-first like tool/common.sh.
set -u
payload="$(cat 2>/dev/null || true)"
path="$(printf '%s' "$payload" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
  | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
[[ -z "$path" || "$path" != *.dart || ! -f "$path" ]] && exit 0
[[ "$path" == *.g.dart || "$path" == *.freezed.dart || "$path" == *.drift.dart ]] && exit 0
if command -v fvm >/dev/null 2>&1; then fvm dart format "$path" >/dev/null 2>&1
else dart format "$path" >/dev/null 2>&1; fi
exit 0
```

Run: `fvm dart test test/guard_generated_test.dart` → 12 pass. Manual: `printf '%s' '{"tool_name":"Write","tool_input":{"file_path":"x.g.dart"}}' | bash tool/hooks/guard_generated.sh; echo "exit=$?"` → message + `exit=2`.

- [ ] **Step 3: The two configs**

`.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/tool/hooks/guard_generated.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/tool/hooks/format_dart.sh",
            "timeout": 60
          }
        ]
      }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(fvm flutter analyze:*)",
      "Bash(fvm flutter test:*)",
      "Bash(fvm flutter pub get:*)",
      "Bash(fvm dart analyze:*)",
      "Bash(fvm dart test:*)",
      "Bash(fvm dart format:*)",
      "Bash(fvm dart run:*)",
      "Bash(fvm dart pub get:*)",
      "Bash(flutter analyze:*)",
      "Bash(flutter test:*)",
      "Bash(dart analyze:*)",
      "Bash(dart test:*)",
      "Bash(dart format:*)",
      "Bash(dart run:*)",
      "Bash(tool/checks.sh:*)",
      "Bash(tool/codegen.sh:*)",
      "Bash(tool/e2e.sh:*)",
      "Bash(bash tool/checks.sh:*)",
      "Bash(bash tool/codegen.sh:*)"
    ],
    "deny": [
      "Read(/.dart-defines/*.env)"
    ]
  }
}
```

`.codex/hooks.json`:
```json
{
  "description": "Alatyr: block hand edits of generated Dart files (hard invariant 5). Loads after project trust; review and trust it once with /hooks in the Codex TUI.",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$(git rev-parse --show-toplevel)/tool/hooks/guard_generated.sh\"",
            "timeout": 30,
            "statusMessage": "guard_generated"
          }
        ]
      }
    ]
  }
}
```

Run: `fvm dart test test/harness_test.dart` → PASS (6 tests).

- [ ] **Step 4: Live smoke of both agents (report honestly; do not fake)**

Claude Code — from a scratch copy outside the repo so nothing here is touched:
```bash
S=/private/tmp/claude-501/m4-hook-smoke && rm -rf "$S" && mkdir -p "$S/tool/hooks" "$S/.claude" && cp tool/hooks/*.sh "$S/tool/hooks/" && cp .claude/settings.json "$S/.claude/" && cd "$S" && git init -q && env -u CLAUDECODE claude -p "Create a file named demo.g.dart containing the single line hello, then a file named demo.txt containing hello" --allowedTools Write --permission-mode acceptEdits --max-turns 4 --output-format text; ls; cd -
```
Expected: `demo.txt` exists, `demo.g.dart` does NOT, and Claude's output mentions the hook's message. If `claude -p` cannot run nested in this session (auth/sandbox), record that in the report and the ledger — the Dart test above already proves the contract on the captured payload.

Codex — same scratch copy with `.codex/hooks.json`; the hook must be trusted for that path first. Compute the trust hash the way the research pass verified (Python reimplementation of Codex's `version_for_toml`: canonical JSON of `{"event_name":"pre_tool_use","matcher":"Edit|Write","hooks":[{"type":"command","command":<command>,"timeout":30,"async":false,"statusMessage":"guard_generated"}]}`, sha256) and pass it inline:
```bash
cp -r .codex "$S/" && cd "$S" && H=$(python3 - <<'PY'
import json,hashlib
cmd='"$(git rev-parse --show-toplevel)/tool/hooks/guard_generated.sh"'
identity={"event_name":"pre_tool_use","matcher":"Edit|Write","hooks":[{"type":"command","command":cmd,"timeout":30,"async":False,"statusMessage":"guard_generated"}]}
print("sha256:"+hashlib.sha256(json.dumps(identity,separators=(",",":"),sort_keys=True).encode()).hexdigest())
PY
) && codex exec -s workspace-write --ephemeral --skip-git-repo-check -c model_reasoning_effort="low" -c "hooks.state={\"$S/.codex/hooks.json:pre_tool_use:0:0\"={trusted_hash=\"$H\"}}" "Create a file named demo2.g.dart containing hello, then a file named demo2.txt containing hello" < /dev/null; ls; cd -
```
Expected: `demo2.txt` exists, `demo2.g.dart` does not. If the hash is rejected (hook silently skipped → both files exist), say so in the report: the per-hook trust step is what `docs/workflow/getting-started.md` (Task 6) tells users to do once via `/hooks`, and the freshness gate remains the backstop. Do not spend more than two attempts on the hash. (Python is used only in this one-off smoke, never in shipped scripts.)

- [ ] **Step 5: Gate + commit**

Run: `tool/checks.sh` → `OK` (root tests now include guard + harness tests).

```bash
fvm dart format test && tool/checks.sh --fast
git add tool/hooks .claude/settings.json .codex/hooks.json test/guard_generated_test.dart test/harness_test.dart
git commit -m "feat(harness): guard_generated + format hooks, Claude settings and Codex hooks wiring"
```

---

### Task 3: `.codex/` config + findings schema, the cross-review skill, the codex-reviewer subagent

**Files:**
- Create: `.codex/config.toml`, `.codex/review-schema.json`, `.claude/skills/cross-review/SKILL.md`, `.claude/skills/cross-review/codex_review.sh`, `.claude/agents/codex-reviewer.md`
- Test: `test/harness_test.dart` (extend: schema is strict JSON Schema; config has no `[profiles]`; skill frontmatter)

**Interfaces:**
- Produces: `.claude/skills/cross-review/codex_review.sh [--base <ref>] [--structured] [--out <dir>]` — pre-flight (codex present + logged in, ref exists, diff non-empty) → primary `codex exec … review --base <ref>` (text to `<out>/review.txt`) or structured `codex exec … --output-schema` (JSON to `<out>/review.json`); prints the output path; exit 0 only when the review ran to completion, exit 3 = "review not performed because …" (never fabricated). The `codex-reviewer` subagent and the skill both call it.

- [ ] **Step 1: Failing tests**

Append to `test/harness_test.dart`:
```dart
  group('codex review protocol', () {
    test('review-schema.json is a strict object schema everywhere (OpenAI structured outputs)', () {
      final schema = jsonDecode(File('.codex/review-schema.json').readAsStringSync()) as Map<String, dynamic>;
      void assertStrict(Map<String, dynamic> node, String path) {
        final type = node['type'];
        final isObject = type == 'object' || (type is List && type.contains('object'));
        if (isObject) {
          expect(node['additionalProperties'], isFalse, reason: '$path: additionalProperties must be false');
          final props = (node['properties'] as Map<String, dynamic>?) ?? {};
          expect((node['required'] as List<dynamic>?)?.toSet(), props.keys.toSet(), reason: '$path: every property must be required');
          for (final entry in props.entries) {
            assertStrict(entry.value as Map<String, dynamic>, '$path.${entry.key}');
          }
        }
        if (node['items'] is Map<String, dynamic>) assertStrict(node['items'] as Map<String, dynamic>, '$path[]');
      }
      assertStrict(schema, r'$');
      expect(((schema['properties'] as Map<String, dynamic>)['verdict'] as Map<String, dynamic>)['enum'], ['approve', 'request_changes']);
    });

    test('.codex/config.toml pins review_model and carries no profile table (ignored since Codex 0.134)', () {
      final config = File('.codex/config.toml').readAsStringSync();
      expect(RegExp(r'^\s*\[profiles', multiLine: true).hasMatch(config), isFalse);
      expect(config, contains('review_model = "gpt-5.6-sol"'));
      // The script reads the same pin, so the two cannot drift.
      final script = File('.claude/skills/cross-review/codex_review.sh').readAsStringSync();
      expect(script, contains('review_model'));
    });

    test('cross-review skill declares frontmatter and ships its script', () {
      final skill = File('.claude/skills/cross-review/SKILL.md').readAsLinesSync();
      expect(skill.first, '---');
      expect(skill.sublist(1, skill.indexOf('---', 1)).join('\n'), allOf(contains('name: cross-review'), contains('description:')));
      final script = File('.claude/skills/cross-review/codex_review.sh');
      expect(script.existsSync(), isTrue);
      expect(script.statSync().mode & 0x49, 0x49);
    });
  });
```

Run: `fvm dart test test/harness_test.dart` → FAIL.

- [ ] **Step 2: `.codex/config.toml` and the schema**

`.codex/config.toml`:
```toml
# Project-scoped Codex config. Loads only after the project is trusted
# (first `codex` run in this repo asks; or `[projects."<abs path>"]
# trust_level = "trusted"` in ~/.codex/config.toml). These keys apply to
# EVERY Codex session in this repository, implementation included - so only
# the review model pin lives here. Reviewer-role constraints (read-only
# sandbox, high reasoning effort, no user skills) are passed per call by
# .claude/skills/cross-review/codex_review.sh, which also reads the model
# pin below. NOTE: profile tables in project config are ignored by Codex
# >= 0.134 (profiles are per-user files); do not add one. Model pin
# maintenance: docs/workflow/maintenance.md.
review_model = "gpt-5.6-sol"
```

`.codex/review-schema.json`:
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Alatyr cross-review findings",
  "type": "object",
  "properties": {
    "verdict": { "type": "string", "enum": ["approve", "request_changes"] },
    "summary": { "type": "string" },
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "title": { "type": "string" },
          "body": { "type": "string" },
          "priority": { "type": "integer", "minimum": 0, "maximum": 3 },
          "confidence_score": { "type": "number", "minimum": 0, "maximum": 1 },
          "code_location": {
            "type": ["object", "null"],
            "properties": {
              "filepath": { "type": "string" },
              "line_range": {
                "type": "object",
                "properties": {
                  "start": { "type": "integer", "minimum": 1 },
                  "end": { "type": "integer", "minimum": 1 }
                },
                "required": ["start", "end"],
                "additionalProperties": false
              }
            },
            "required": ["filepath", "line_range"],
            "additionalProperties": false
          }
        },
        "required": ["title", "body", "priority", "confidence_score", "code_location"],
        "additionalProperties": false
      }
    }
  },
  "required": ["verdict", "summary", "findings"],
  "additionalProperties": false
}
```

- [ ] **Step 3: The review script**

`.claude/skills/cross-review/codex_review.sh` (`chmod +x`):
```bash
#!/usr/bin/env bash
# Cross-review runner (spec section 7). Runs OpenAI Codex as a READ-ONLY
# reviewer of this branch's diff and writes its verdict to a file. Used by
# the /cross-review skill, the codex-reviewer subagent, and humans.
#
#   codex_review.sh [--base <ref>] [--structured] [--out <dir>]
#
# --base       base ref for the diff (default: main)
# --structured machine-readable findings via --output-schema
#              (.codex/review-schema.json) instead of the native reviewer
# --out        output directory (default: .superpowers/cross-review, gitignored)
#
# Exit codes: 0 review written; 2 usage; 3 review NOT performed (the reason
# is on stderr - report it verbatim, never fabricate a verdict).
set -euo pipefail

BASE=main; STRUCTURED=false; OUT=""; DEFAULT_OUT=".superpowers/cross-review"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:?--base needs a ref}"; shift 2 ;;
    --structured) STRUCTURED=true; shift ;;
    --out) OUT="${2:?--out needs a dir}"; shift 2 ;;
    *) echo "usage: codex_review.sh [--base <ref>] [--structured] [--out <dir>]" >&2; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "review not performed: not inside a git repository" >&2; exit 3; }
# Absolute output dir (the caller's cwd may differ from the root we cd into).
if [[ -z "$OUT" ]]; then OUT="$ROOT/$DEFAULT_OUT"; elif [[ "$OUT" != /* ]]; then OUT="$PWD/$OUT"; fi
cd "$ROOT"
command -v codex >/dev/null 2>&1 || { echo "review not performed: codex CLI not installed (npm i -g @openai/codex)" >&2; exit 3; }
# `codex login status` reports on stderr; its exit status is the contract.
codex login status >/dev/null 2>&1 || { echo "review not performed: codex is not logged in (run: codex login)" >&2; exit 3; }
# ONE model pin, read from the project config so the two cannot drift.
REVIEW_MODEL="$(sed -n 's/^review_model = "\(.*\)"$/\1/p' "$ROOT/.codex/config.toml" | head -n 1)"
[[ -n "$REVIEW_MODEL" ]] || { echo "review not performed: review_model missing in .codex/config.toml" >&2; exit 3; }
git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "review not performed: base ref '$BASE' does not exist" >&2; exit 3; }
if [[ -z "$(git diff --merge-base "$BASE" HEAD --stat)" ]]; then
  echo "review not performed: no changes between $BASE and HEAD" >&2; exit 3
fi

mkdir -p "$OUT"
# Reviewer role lives HERE, not in AGENTS.md: read-only sandbox, no session
# file, high effort, and no user-level skills (a user's own skills can
# hijack a review run - e.g. one that triggers on "review" wording).
COMMON=(-C "$ROOT" -s read-only --ephemeral
        -c 'model_reasoning_effort="high"'
        -c 'skills.include_instructions=false')

if [[ "$STRUCTURED" == "true" ]]; then
  TARGET="$OUT/review.json"
  PROMPT="Act as a code reviewer for this repository; do not modify files. Apply the '## Code Review Rules' section of AGENTS.md to the unified diff in the <stdin> block (the branch's changes against $BASE). Report findings only for rule violations you can point to with file and line; priority 0 = blocks merge, 3 = nit; confidence_score in [0,1]. Verdict request_changes iff any finding has priority <= 1."
  # With a positional prompt AND piped stdin, codex appends stdin as a
  # <stdin> block (codex exec --help) - the diff travels that way. -m pins
  # the model for plain exec (review_model only governs the reviewer).
  git diff --merge-base "$BASE" HEAD \
    | codex exec "${COMMON[@]}" -m "$REVIEW_MODEL" --output-schema "$ROOT/.codex/review-schema.json" -o "$TARGET" "$PROMPT" \
        >"$OUT/review.log" 2>&1 \
    || { echo "review not performed: codex exec exited non-zero (see $OUT/review.log)" >&2; exit 3; }
else
  TARGET="$OUT/review.txt"
  # Native reviewer: applies AGENTS.md's Code Review Rules itself; a custom
  # prompt cannot be combined with --base (clap: mutually exclusive).
  codex exec "${COMMON[@]}" -c "review_model=\"$REVIEW_MODEL\"" review --base "$BASE" -o "$TARGET" \
      >"$OUT/review.log" 2>&1 < /dev/null \
    || { echo "review not performed: codex review exited non-zero (see $OUT/review.log)" >&2; exit 3; }
fi
[[ -s "$TARGET" ]] || { echo "review not performed: codex produced no output (see $OUT/review.log)" >&2; exit 3; }
echo "$TARGET"
```

Add `.superpowers/` is already gitignored (root `.gitignore` has `.superpowers/`) — confirm with `git check-ignore .superpowers/cross-review/x`.

- [ ] **Step 4: The skill and the subagent**

`.claude/skills/cross-review/SKILL.md`:
```markdown
---
name: cross-review
description: Run the Codex cross-review of this branch (Definition of Done item 4) and evaluate its findings - use after the gate is green and before declaring a task done, or when asked to "cross-review", "run codex review", "get the review verdict".
argument-hint: "[--base <ref>] [--structured]"
allowed-tools: Bash(.claude/skills/cross-review/codex_review.sh:*), Bash(git:*), Read
---

# Cross-review (Codex)

Independent review of this branch by a second model. You stay responsible:
Codex gives input; you evaluate every point against the code.

## 1. Run it

```bash
.claude/skills/cross-review/codex_review.sh --base main
```

If the user passed arguments (`$ARGUMENTS`, e.g. `--base develop --structured`),
use them instead of `--base main`.

The script does the pre-flight (codex installed and logged in, base ref
exists, diff non-empty), forces the reviewer role (read-only sandbox,
ephemeral, high effort, user skills off) and prints the output path:
`review.txt` (native reviewer, applies `## Code Review Rules` from
AGENTS.md) or, with `--structured`, `review.json` matching
`.codex/review-schema.json`. Reviews take 1–5 minutes: run with a Bash
timeout of 600000 ms; never background it.

**Exit 3 = review not performed.** Quote the script's stderr reason in your
report under Remaining risks and stop; never invent findings. The human
waives DoD 4 explicitly if the review is impossible - you do not.

## 2. Evaluate, don't obey

Read the output file. For each finding: read the cited lines, trace the
claimed failure, then classify:

- ✅ Agree — state the concrete failing path; fix it (P0/P1 must be fixed
  or rebutted before done).
- ❌ Disagree — say why it does not apply (quote the code).
- 🤔 Your call — plausible but unverified; tell the human.

Quote the reviewer's conclusion verbatim (structured path: the `verdict`
and `summary` fields; native path: its opening summary line and every
`[Pn]` title) — never paraphrase it. P2/P3 are at your discretion. Never
silently apply suggestions.

## 3. Report

```
Cross-review (codex, base <ref>): <verdict verbatim>
- ✅ …  - ❌ …  - 🤔 …
Remaining risks: <open P2/P3, anything not re-verified, or "none">
```
```

`.claude/agents/codex-reviewer.md`:
```markdown
---
name: codex-reviewer
description: Thin wrapper that runs the Codex cross-review script and returns its output verbatim - for workflows and skills that need the review as a node; it never edits files and never interprets findings.
tools: Bash, Read
model: sonnet
---

You run one command and return what it produced. Nothing else.

1. Run `.claude/skills/cross-review/codex_review.sh` with the arguments you
   were given (default `--base main`), Bash timeout 600000 ms.
2. Exit 0: Read the printed output file and return its full content
   verbatim, prefixed by one line `performed: true, file: <path>`.
3. Exit 3: return `performed: false, reason: <the stderr text verbatim>`.
   Do not retry, do not guess, do not write a review yourself.

You do not evaluate, summarize, or soften findings — the caller does.
```

Run: `fvm dart test test/harness_test.dart` → PASS (9 tests).

- [ ] **Step 5: Gate + commit**

Run: `fvm dart format test && tool/checks.sh` → `OK`.

```bash
git add .codex/config.toml .codex/review-schema.json .claude/skills/cross-review .claude/agents/codex-reviewer.md test/harness_test.dart
git commit -m "feat(harness): Codex config + findings schema, cross-review skill and script, codex-reviewer subagent"
```

`codex-reviewer` is an addition beyond spec §3's tree (which lists only `test-breaker.md`): it is the thin wrapper that lets workflows and scripts run the review as a node without re-deriving the invocation; Task 8 records it in the spec.

- [ ] **Step 6: Live proof on this branch (dogfood, DoD 4 for Tasks 1–3)**

The script diffs committed changes (`--merge-base <ref> HEAD`), so this runs AFTER the commit. Run, each with a Bash timeout of 600000 ms:

```bash
.claude/skills/cross-review/codex_review.sh --base main --structured --out /private/tmp/claude-501/m4-review-smoke; echo "exit=$?"
.claude/skills/cross-review/codex_review.sh --base main --out /private/tmp/claude-501/m4-review-smoke2; echo "exit=$?"
```

Expected: exit 0 twice; `review.json` with `verdict` ∈ {approve, request_changes} and a findings array; `review.txt` with `[P0]..[P3]`-prefixed titles or a no-findings statement. Paste both outputs VERBATIM into the task report (the reviewer checks them — a verdict sentence alone is not evidence). Evaluate per the skill; fix every accepted P0/P1 in a commit `fix(harness): address cross-review findings (Tasks 1-3)`, rebut the rest in the report. Exit 3 → quote the stderr reason; if the reason is ours (flags, stdin, pin), fix the script in the same fix commit and re-run.

---

### Task 4: test-breaker subagent + adversarial-tests skill (dogfooded on feature_settings)

**Files:**
- Create: `.claude/agents/test-breaker.md`, `.claude/skills/adversarial-tests/SKILL.md`
- Modify: `packages/feature_settings/test/*` when the dogfood pass finds an uncovered scenario (a test or a `skip: 'deliberate: …'` stub); `packages/feature_settings/lib/**` or `packages/feature_settings_api/lib/**` ONLY when a scenario exposes a real bug or contract gap (red → fix → green, with the RED output in the report)
- Test: `test/harness_test.dart` (extend: agent is read-only, skill frontmatter)

**Interfaces:**
- Produces: `test-breaker` subagent (fresh context, tools `Read, Grep, Glob`, model sonnet) returning scenarios as `action → required behaviour → test layer`; `/adversarial-tests <api dir> [impl dir]` skill orchestrating: invoke test-breaker → map scenarios to existing tests → write missing tests or deliberate-skip stubs → report.

- [ ] **Step 1: Failing tests**

Append to `test/harness_test.dart`:
```dart
  group('adversarial harness', () {
    test('test-breaker subagent is read-only and uses a fixed model', () {
      final lines = File('.claude/agents/test-breaker.md').readAsLinesSync();
      final front = lines.sublist(1, lines.indexOf('---', 1)).join('\n');
      expect(front, contains('name: test-breaker'));
      expect(RegExp(r'^tools:\s*Read,\s*Grep,\s*Glob\s*$', multiLine: true).hasMatch(front), isTrue,
          reason: 'test-breaker must not get Edit/Write/Bash');
      expect(front, contains('model: sonnet'));
    });

    test('adversarial-tests skill declares its frontmatter', () {
      final lines = File('.claude/skills/adversarial-tests/SKILL.md').readAsLinesSync();
      final front = lines.sublist(1, lines.indexOf('---', 1)).join('\n');
      expect(front, allOf(contains('name: adversarial-tests'), contains('description:')));
    });
  });
```

Run → FAIL.

- [ ] **Step 2: The subagent**

`.claude/agents/test-breaker.md`:
```markdown
---
name: test-breaker
description: Fresh-context adversarial scenario generator - given a feature's *_api contract, its spec/plan text and the diff, lists the ways the implementation could break (boundary values, races and double taps, lifecycle, process death, dependency failures, corrupted stored data) as "action → required behaviour → test layer". Read-only; never writes tests or code.
tools: Read, Grep, Glob
model: sonnet
---

You are a test breaker. You have NOT seen the implementer's reasoning - that
is the point. You read contracts and code, and you list what would break
them. You never fix, never write tests, never soften.

## Input (from the caller)
- the `*_api` package directory (contracts: ports, models, route spec, key
  namespace, failure codes)
- optionally the implementation package directory and a spec/plan excerpt
- optionally a diff or commit range

## Method
1. Read the `*_api` contracts first and write down every promise they make
   (doc comments count: "emits the current value first", "never errors on
   bad data", "Ok(null) when absent").
2. Read the implementation and its tests. For each promise, ask what input,
   timing or environment would break it.
3. Enumerate scenarios in these classes, at least one per class or state
   "none applicable" with a reason:
   - boundary values (empty, null, max, unknown enum name, unicode)
   - races: double tap, rapid successive events, event during pending IO
   - lifecycle: dispose/close while loading, save completing after close,
     stream cancel
   - process death / restart: a second widget tree + DI graph over the same
     storage (in-process restart); OS-level death with persisted state
   - dependency failures: storage throws, stream errors, platform channel
     missing, closed database
   - corrupted stored data: wrong type, unknown value, truncated
   - contract drift: a consumer relying on an undocumented behaviour

## Output (exactly this shape, nothing else)
```
## Scenarios for <api package>
1. <action> → <required behaviour, citing the contract line> → <test layer: bloc | repository | widget | module | app | e2e>
   covered by: <test file: test name> | NOT COVERED
2. …
## Summary
covered: N · not covered: M · contract gaps (promise with no test AND no code path): K
```
Mark "covered by" only when you found a test whose assertions prove the
required behaviour — a test that merely exercises the path does not count.
```

- [ ] **Step 3: The skill**

`.claude/skills/adversarial-tests/SKILL.md`:
```markdown
---
name: adversarial-tests
description: Adversarial test pass (Definition of Done item 2) - dispatch the fresh-context test-breaker subagent over a feature's *_api contract and implementation, then cover every scenario with a test or a deliberate skip stub. Use after the first green implementation of new behaviour, or when asked to "break this", "adversarial pass", "test-breaker".
argument-hint: "<feature_api dir> [feature impl dir]"
---

# Adversarial tests

Self-confirmation is the failure mode this skill exists for: the agent that
wrote the code is the worst judge of what breaks it. The scenarios come
from a subagent that has not seen your reasoning.

## 1. Break it

Dispatch the `test-breaker` subagent (Agent tool, `subagent_type:
test-breaker`) with: the `*_api` directory (`$1`), the implementation
directory (`$2`, if given), the feature's spec/plan excerpt if you have
one, and the diff range. Do not pass your own analysis or assumptions -
only the artefacts. Wait for its scenario list.

## 2. Cover it

For every scenario:
- **NOT COVERED and implementable** → write the test at the named layer
  (patrol finders for widgets; in-memory drift for repositories; bloc_test
  for blocs). The test name is the scenario. Run it: it must fail before
  the fix if the scenario exposed a bug, and pass after.
- **NOT COVERED and deliberately out of scope** (OS-level process death,
  hardware, a platform channel you cannot fake) → add a stub in the right
  test file so the gap is machine-visible:
  `test('<scenario>', () {}, skip: 'deliberate: <why>');`
- **covered** → nothing, but verify the cited test really asserts the
  behaviour; if it only exercises the path, strengthen it.
- **contract gap** (a promise with neither code nor test) → fix the code or
  the contract doc comment; never leave the promise dangling.

## 3. Report

```
Adversarial pass (<api package>): <N> scenarios - <a> already covered,
<b> tests added, <c> deliberate skips, <d> contract gaps fixed.
Deliberate skips: <list with reasons>
Remaining risks: <anything you could not cover or verify, or "none">
```
The skipped stubs ARE the record of known-uncovered scenarios
(`flutter test --reporter json` enumerates them); do not keep a separate
list.
```

Run: `fvm dart test test/harness_test.dart` → PASS (11 tests).

- [ ] **Step 4: Dogfood on feature_settings**

Claude Code registers `.claude/agents/*.md` at session start, so the `test-breaker` subagent type is not available in the session that created it. Run the skill's step 1 with the equivalent: dispatch ONE general-purpose subagent (Agent tool, model sonnet) whose prompt is the full body of `.claude/agents/test-breaker.md` (everything below the frontmatter, verbatim) followed by the inputs — the file lists of `packages/feature_settings_api/lib/**` and `packages/feature_settings/lib/**` + `test/**`, and the diff TEXT of `git diff d41ac00..HEAD -- packages/feature_settings_api packages/feature_settings` (the agent has no Bash; it reads files and the pasted diff). This is the one subagent this task is allowed to dispatch. Paste its scenario list into the task report verbatim.

Then apply the skill's step 2: for each NOT COVERED scenario add a test or a `skip: 'deliberate: …'` stub in the matching `packages/feature_settings/test/*.dart` file (expected: OS-level process death → deliberate skip in `settings_module_test.dart` pointing at the M5 patrol restart flow); if a scenario exposes a real bug or contract gap, fix the code or the contract doc comment (RED output in the report). Run `cd packages/feature_settings && fvm flutter test --no-pub` → green (skips reported as skipped).

- [ ] **Step 5: Gate + commit**

Run: `tool/checks.sh` → `OK`.

```bash
fvm dart format . && tool/checks.sh --fast
git add .claude/agents/test-breaker.md .claude/skills/adversarial-tests test/harness_test.dart packages/feature_settings
git commit -m "feat(harness): test-breaker subagent and adversarial-tests skill (dogfooded on feature_settings)"
```

---

### Task 5: M3 carryover code items — Completer-driven bloc tests (the two wall-clock ones), shipped-comment cleanup

**Files:**
- Modify: `packages/feature_settings/test/settings_bloc_test.dart`, `packages/data_local/test/key_value_dao_test.dart`

**Interfaces:** none new; behaviour of the three timing-based tests becomes deterministic.

- [ ] **Step 1: Rewrite the two wall-clock tests**

In `settings_bloc_test.dart` replace the tests `'a slower earlier save completes before a later one starts, so the latest choice wins'` and `'a save that completes after close() neither throws nor emits'` (the two tests that use `Duration(milliseconds: …)` — 30/80 and 20/40 ms) with Completer-driven versions (the double-tap test has no timing and stays). The ordering test must never leave `darkSave` unresolved — a failed `expect` inside `act` while the handler awaits the completer would hang `bloc.close()` — so it records the overlap and asserts in `verify`:

```dart
  blocTest<SettingsBloc, SettingsState>(
    'a slower earlier save completes before a later one starts, so the latest choice wins',
    setUp: () {
      completedSaves = [];
      lightStartedWhileDarkPending = false;
      darkSave = Completer<Result<void>>();
      when(() => repository.saveThemeMode(ThemeMode.dark)).thenAnswer((_) async {
        final result = await darkSave.future;
        completedSaves.add(ThemeMode.dark);
        return result;
      });
      when(() => repository.saveThemeMode(ThemeMode.light)).thenAnswer((_) async {
        lightStartedWhileDarkPending = !darkSave.isCompleted;
        completedSaves.add(ThemeMode.light);
        return const Ok(null);
      });
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) async {
      bloc
        ..add(const SettingsThemeModeChanged(ThemeMode.dark))
        ..add(const SettingsThemeModeChanged(ThemeMode.light));
      await Future<void>.delayed(Duration.zero);
      darkSave.complete(const Ok(null)); // always resolved: never strands close()
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => const <SettingsState>[],
    // Without serialization the light save would run while dark was still
    // pending, and dark would overwrite it afterwards.
    verify: (_) {
      expect(lightStartedWhileDarkPending, isFalse);
      expect(completedSaves, [ThemeMode.dark, ThemeMode.light]);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'a save that completes after close() neither throws nor emits',
    setUp: () {
      lateSave = Completer<Result<void>>();
      when(() => repository.saveThemeMode(any())).thenAnswer((_) => lateSave.future);
    },
    build: () => SettingsBloc(repository),
    seed: () => const SettingsState.ready(themeMode: ThemeMode.system),
    act: (bloc) async {
      bloc.add(const SettingsThemeModeChanged(ThemeMode.dark));
      await Future<void>.delayed(Duration.zero);
      final closing = bloc.close();
      lateSave.complete(const Err(AppFailure(code: 'settings.save-failed', message: 'late')));
      await closing;
    },
    expect: () => const <SettingsState>[],
    errors: () => isEmpty,
  );
```

Declare `late Completer<Result<void>> darkSave;`, `late Completer<Result<void>> lateSave;` and `late bool lightStartedWhileDarkPending;` next to `completedSaves` in `main()`. Remove the `wait:` parameters and every `Duration(milliseconds: …)` from this file; `grep -n "milliseconds" packages/feature_settings/test/settings_bloc_test.dart` must print nothing.

- [ ] **Step 2: Shipped comment cleanup**

`packages/data_local/test/key_value_dao_test.dart`: replace `see the widget-test exemplars in Tasks 9-10.` with `see the widget-test exemplars in packages/feature_settings/test/ and app/test/.` (a plan reference must not ship).

Run: `cd packages/feature_settings && fvm flutter test --no-pub` → all pass (run it three times in a row to show determinism); `cd packages/data_local && fvm flutter test --no-pub` → pass.

- [ ] **Step 3: Gate + commit**

Run: `tool/checks.sh` → `OK`.

```bash
fvm dart format packages && tool/checks.sh --fast
git add packages/feature_settings/test/settings_bloc_test.dart packages/data_local/test/key_value_dao_test.dart
git commit -m "test(feature_settings): Completer-driven ordering tests; drop plan reference from a shipped comment"
```

---

### Task 6: Docs set part 1 — docs/README.md, architecture/01–06, ADRs

**Files:**
- Create: `docs/README.md`, `docs/architecture/01-overview.md`, `02-package-graph.md`, `03-feature-contract.md`, `04-composition.md`, `05-error-handling.md`, `06-security.md`, `docs/adr/README.md`, `docs/adr/template.md`, `docs/adr/0001-package-boundaries.md`, `0002-manual-di.md`, `0003-test-strategy.md`, `0004-single-gate.md`, `0005-cross-review-protocol.md`, `0006-working-placeholder-instantiation.md`
- Test: `test/docs_test.dart` (created here; Task 7 extends the required-files list)
- Twins for every file (gitignored)

**Interfaces:**
- Produces: `test/docs_test.dart` with `requiredDocs` list, a relative-link checker over `docs/**/*.md`, `README.md`, `AGENTS.md`, `CLAUDE.md`, and the English-only (no Cyrillic) scan over `git ls-files`.

- [ ] **Step 1: Failing docs test**

`test/docs_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// The docs set of spec section 13, kept honest by machine: every file
/// exists, every relative link resolves, and nothing shipped is in
/// Russian (twins are gitignored).
const requiredDocs = [
  'docs/README.md',
  'docs/architecture/01-overview.md',
  'docs/architecture/02-package-graph.md',
  'docs/architecture/03-feature-contract.md',
  'docs/architecture/04-composition.md',
  'docs/architecture/05-error-handling.md',
  'docs/architecture/06-security.md',
  'docs/adr/README.md',
  'docs/adr/template.md',
  'docs/adr/0001-package-boundaries.md',
  'docs/adr/0002-manual-di.md',
  'docs/adr/0003-test-strategy.md',
  'docs/adr/0004-single-gate.md',
  'docs/adr/0005-cross-review-protocol.md',
  'docs/adr/0006-working-placeholder-instantiation.md',
];

final _link = RegExp(r'\[[^\]]*\]\(([^)\s#]+)(#[^)]*)?\)');
// Written with escapes on purpose: this file is scanned by its own test.
final _cyrillic = RegExp(r'[\u0400-\u04FF]');
final _fencedBlock = RegExp(r'```[\s\S]*?```');
final _inlineCode = RegExp(r'`[^`\n]*`');

/// Shipped markdown: the top-level contracts plus docs/, minus the working
/// documents under docs/superpowers/ (deleted by init) and Russian twins.
Iterable<File> _markdownFiles() sync* {
  for (final top in ['README.md', 'AGENTS.md', 'CLAUDE.md']) {
    final f = File(top);
    if (f.existsSync()) yield f;
  }
  yield* Directory('docs')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) =>
          f.path.endsWith('.md') &&
          !f.path.endsWith('.ru.md') &&
          !p.split(f.path).contains('superpowers'));
}

/// Markdown with code removed, so examples inside fences/spans are not
/// mistaken for links.
String _prose(File file) => file
    .readAsStringSync()
    .replaceAll(_fencedBlock, '')
    .replaceAll(_inlineCode, '');

void main() {
  test('every documented file exists', () {
    final missing = requiredDocs.where((d) => !File(d).existsSync()).toList();
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('every relative markdown link resolves', () {
    final broken = <String>[];
    for (final file in _markdownFiles()) {
      for (final m in _link.allMatches(_prose(file))) {
        final target = m.group(1)!;
        if (target.startsWith('http://') || target.startsWith('https://') || target.startsWith('mailto:')) continue;
        if (target.contains('<') || target.contains('>')) continue; // placeholder in prose
        final resolved = p.normalize(p.join(p.dirname(file.path), target));
        if (!File(resolved).existsSync() && !Directory(resolved).existsSync()) {
          broken.add('${file.path}: $target');
        }
      }
    }
    expect(broken, isEmpty, reason: broken.join('\n'));
  });

  test('architecture docs stay at 1-2 pages and ADRs stay short', () {
    for (final doc in requiredDocs.where((d) => d.startsWith('docs/architecture/'))) {
      expect(File(doc).readAsLinesSync().length, lessThanOrEqualTo(120), reason: doc);
    }
    for (final adr in requiredDocs.where((d) => RegExp(r'docs/adr/\d{4}-').hasMatch(d))) {
      expect(File(adr).readAsLinesSync().length, lessThanOrEqualTo(60), reason: adr);
    }
  });

  test('no shipped (tracked) file contains Cyrillic', () {
    final tracked = (Process.runSync('git', ['ls-files', '-z']).stdout as String)
        .split('\u0000')
        .where((s) => s.isNotEmpty);
    final hits = <String>[];
    for (final path in tracked) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = file.readAsBytesSync();
      // Skip binaries: a NUL byte in the first 1 KB is good enough here.
      if (bytes.take(1024).contains(0)) continue;
      final text = utf8.decode(bytes, allowMalformed: true);
      if (_cyrillic.hasMatch(text)) hits.add(path);
    }
    expect(hits, isEmpty, reason: 'Russian text in shipped files:\n${hits.join('\n')}');
  });
}
```
Run: `fvm dart test test/docs_test.dart` → FAIL (missing files). The Cyrillic test must PASS already (nothing Russian is tracked; the test's own regex is escaped) — confirm.

- [ ] **Step 2: Write the docs**

Every architecture doc is 1–2 pages (≤ 120 lines), English, present tense, and states only what is true at this commit (say "lands in M5" for init/e2e/critical-flows stage/web assets). Relative links to real files. Required content:

`docs/README.md` — index of the tree below with one line per file; the **supersession-banner convention** shown inside a fenced block (so the link checker does not parse the placeholder): an obsoleted doc gets, as its first line, a blockquote `> **Superseded by [NEW_DOC_TITLE](relative/path.md) on YYYY-MM-DD.** Kept for history.` — never a silent rewrite; the Russian-twin note (twins are gitignored and exist only during template development).

`docs/architecture/01-overview.md` — system map: the eight workspace members in their layers (base: app_core, app_config, design_system, data_local, data_secure; feature_api: feature_settings_api; feature_impl: feature_settings; app_root: app/alatyr_starter), `lints/` outside the workspace, `tool/` and root `test/`; the four package kinds; one paragraph on "the repo is the deliverable" (Principle 3); links to 02–06.

`02-package-graph.md` — `docs/reference/package_graph.yaml` as the single source of truth; exact semantics: `allowed_dependencies` = workspace edges only; third-party deps governed solely by `banned_packages`; SDK deps forbidden in `pure_dart_packages`; keys are package names; completeness both ways; the three consumers (verify_dependencies: pubspec level; verify_imports: lexer, scans lib/bin/example/integration_test/test, banned rule in all scopes, boundary/purity/secret lib-only, < 1 s; alatyr_lints: six rules, all WARNING, widget rules test-exempt, nested-ternary not, loaded by `dart analyze` (root stage and per-member stage) but never by one-shot `flutter analyze` — sdk#63787); **banned_packages govern direct declarations and imports only — transitive presence through a canonical package is allowed by design** (`provider` sits in `pubspec.lock` via `flutter_bloc`); the 12 banned entries with reasons (copy from the yaml).

`03-feature-contract.md` — api = contracts only (ports, models, route spec, key namespace, failure codes; Flutter packages on purpose); impl exports exactly one factory (`createSettingsModule({required KeyValueDao keyValueDao, AppLogger logger})` → `SettingsModule { List<RouteBase> routes; SettingsApi api }`); everything else private (`src/`, not exported); cross-feature consumption through `*_api` only; the key namespace rule with `SettingsKeys` as the worked example; the single-source-of-truth pattern (bloc mirrors the repository stream, a successful save emits nothing, the app consumes the same stream through the port).

`04-composition.md` — manual constructor DI: `app/lib/bootstrap/app_dependencies.dart` is the only place that names implementations; `AppDependencies.production()` vs test construction; `bootstrap({createDependencies})` seam; router assembled from module routes (`buildRouter`, `initialLocation: SettingsRoutes.path`); `App` drives `MaterialApp.themeMode` from `settings.api.watchThemeMode()` through a once-subscribed stream; why no get_it/injectable (link ADR-0002).

`05-error-handling.md` — `Result<T>` = `Ok`/`Err` (no `==` override by design — assert on shape), `AppFailure(code, message, cause)` with `<area>.<reason>` codes (`config.invalid-url`, `settings.load-failed`, `settings.save-failed`, `secure.read-failed`…); adapters convert exceptions only — `Error`s propagate (quote `SettingsRepository.saveThemeMode` doc); failure messages never carry keys/values; UI shows failures from state (`lastFailure`), logs via `AppLogger`.

`06-security.md` — `.dart-defines/` scheme (`*.env.example` committed, `*.env` gitignored, `--dart-define-from-file`; only public client values); `data_secure` as the only home of runtime secrets (`SecureStore` port, `FlutterSecureStore.platform()`, `InMemorySecureStore`); Apple `keychain-access-groups` entitlements shipped (empty array; App Group name goes in when enabled), Linux `libsecret-1-dev` + secret service; the never-in-repo list (tokens, keys, `.env`, signing identities — `DEVELOPMENT_TEAM` is stripped from the iOS project); the secret-leak scan over `data_local`; the `Read` deny rule in `.claude/settings.json`.

`docs/adr/README.md` — what an ADR is here, the numbering, the **ADR-draft escalation flow**: when an agent hits a stop condition (AGENTS.md §7) it writes `docs/adr/NNNN-<slug>.md` from `template.md` with status `draft` and stops; a human accepts/rejects; no code lands against a draft. Index of 0001–0006.

`docs/adr/template.md` — `# ADR-NNNN: <title>` / Status (draft | accepted | superseded by ADR-NNNN) / Date / Context / Decision / Consequences / Alternatives considered.

ADRs 0001–0006 (each ≤ 60 lines, status accepted, date 2026-08-13, Context/Decision/Consequences/Alternatives): 0001 package boundaries (four kinds, graph as truth, monorepo-minimum, single app — spec §3/§5/§6, Appendix A #2 #6); 0002 manual DI (no get_it/injectable; composition root; Appendix A #4); 0003 test strategy (patrol finders structural default, goldens opt-in and Flutter-engine only, no coverage floor, "TMS from code", adversarial pass — spec §10, Appendix A #8–10); 0004 single gate (one `tool/checks.sh` locally and in CI, CI owns no logic, hard wall-clock timeouts, cold codegen freshness — spec §6/§11); 0005 cross-review protocol (Codex as independent reviewer, evaluate-don't-obey, honest failure, rubric in AGENTS.md / role in the skill, no Stop hook by default — spec §7, Appendix A #3 #14); 0006 working-placeholder instantiation (token replacement over a working app, mason/.tmpl rejected — spec §9, Appendix A #7).

- [ ] **Step 3: Twins, test, gate, commit**

Write the `.ru.md` twin of every file above. Run: `fvm dart format test && fvm dart test test/docs_test.dart` → PASS (4 tests). Run: `tool/checks.sh` → `OK`.

```bash
git add docs/README.md docs/architecture docs/adr test/docs_test.dart
git commit -m "docs: index, architecture set (01-06) and ADRs 0001-0006"
```

---

### Task 7: Docs set part 2 — testing, workflow, reference, root README

**Files:**
- Create: `docs/testing/strategy.md`, `docs/testing/widget-test-guardrails.md`, `docs/workflow/getting-started.md`, `docs/workflow/feature-workflow.md`, `docs/workflow/maintenance.md`, `docs/workflow/modules.md`, `docs/reference/critical_flows.md`, `docs/reference/ci_contract.md`, `docs/reference/feature_package_skeletons.md`
- Modify: `README.md` (root), `test/docs_test.dart` (extend `requiredDocs`)
- Twins for every file

**Interfaces:**
- Produces: `docs/reference/critical_flows.md` in the machine-readable shape M5's gate check will parse — a markdown table `| Flow | Test |` whose `Test` cells are repo-relative paths; M4 ships the header, the format description and an empty table with a comment line `<!-- first row lands in M5 with app/integration_test/settings_theme_test.dart -->`.

- [ ] **Step 1: Extend the docs test**

Add to `requiredDocs`: the nine files above plus `'README.md'`. Add a test:
```dart
  test('critical_flows.md has the registry table shape the gate will parse', () {
    final lines = File('docs/reference/critical_flows.md').readAsLinesSync();
    expect(lines, contains('| Flow | Test |'));
    final rows = lines.where((l) => l.trimLeft().startsWith('|'));
    for (final row in rows) {
      final cells = row.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      if (cells.isEmpty || cells.first == 'Flow') continue; // header
      if (cells.every((c) => RegExp(r'^:?-+:?$').hasMatch(c))) continue; // separator
      expect(cells, hasLength(2), reason: row);
      expect(File(cells[1]).existsSync(), isTrue, reason: 'registry entry points to a missing test: ${cells[1]}');
    }
  });
```
Run → FAIL (files missing).

- [ ] **Step 2: Write the docs**

`docs/testing/strategy.md` — the pyramid table of spec §10 (layer → test type → tools) as it exists now (rows marked "lands in M5" for patrol e2e); no coverage floor and why; patrol-finders policy (structural default; goldens opt-in, Flutter-engine only, cross-engine comparison banned by ADR-0003); "TMS from code" (names as cases, `flutter test --reporter json`, registry as e2e plan, `skip: 'deliberate: …'` stubs as the record); the adversarial pass (test-breaker + `/adversarial-tests`); the eight verification layers of a feature; exemplar map: which file in the repo demonstrates each test type (bloc: `settings_bloc_test.dart`; repository on in-memory drift: `drift_settings_repository_test.dart`; patrol widget: `settings_screen_test.dart`, `app_choice_tile_test.dart`; module assembly: `settings_module_test.dart`; app smoke incl. bootstrap and in-process restart: `app/test/app_test.dart`; toolchain fixtures: root `test/`; lint rules: `lints/test/`).

`docs/testing/widget-test-guardrails.md` — the anti-hang rules, each with the symptom, the cause and the recipe, quoting the exemplar comments: (1) awaited `Bloc.close()`/`StreamController.close()`/drift `close()` in tearDown after a testWidgets body never completes — let the tree own blocs, `unawaited(...)`; (2) `await stream.first` on a drift-backed stream inside the body strands every later pump — assert via `read()`; (3) drift's zero-duration timer on watch-cancel trips "A Timer is still pending" — explicit unmount + `pump(Duration.zero)`; (4) progress indicators animate forever — plain pumps; (5) `BlocProvider(create:)` is lazy; (6) per-test `GoRouter` → `dispose()`; (7) `$(#a.b.c)` ≡ `ValueKey<String>('a.b.c')` only, and symbol segments must be identifiers; (8) plugin adapters are `async` so sync throws become rejected futures; (9) plain `test()` has no FakeAsync zone — awaited closes are fine there; (10) StreamController single-subscription buffers pre-listen events, broadcast drops them; (11) element reuse — pump a `SizedBox.shrink()` between two trees of the same widget type or the State survives.

`docs/workflow/getting-started.md` — prerequisites (fvm + Flutter 3.44.9 via `.fvmrc`, Xcode CLT on macOS, `brew install coreutils` for `gtimeout`, `libsqlite3-dev` + `libsecret-1-dev` on Linux, Node for the agent CLIs); clone → `fvm install` → `fvm flutter pub get` → `tool/checks.sh --fast` → full `tool/checks.sh` (what each stage prints; first run downloads sqlite3's prebuilt library through the Dart hook into `.dart_tool/hooks_runner/` — network once); running the app (`cp .dart-defines/dev.env.example .dart-defines/dev.env`, `cd app && fvm flutter run -d <device> --dart-define-from-file=../.dart-defines/dev.env`); web: compiles, persistence needs `sqlite3.wasm` + `drift_worker.js` (lands in M5); **trust steps**: Claude Code — start `claude` AT THE REPOSITORY ROOT (project settings, hooks and the deny rule load from the start directory only; a session started in `app/` has none of them), accept workspace trust (hooks in `.claude/settings.json` fire only after that; `/hooks` shows them); Codex — first `codex` run asks for project trust (writes `[projects."<abs path>"] trust_level = "trusted"` to `~/.codex/config.toml`; a read-only run never trusts), then review the guard hook once with `/hooks` in the TUI — until then the hook is **silently skipped** and only the codegen-freshness gate protects generated files; `codex login`; the `gpt-5.6-sol` pin; troubleshooting (analysis server must restart after `plugins:` edits; `flutter analyze` does not show plugin diagnostics; patrol setup lands in M5).

`docs/workflow/feature-workflow.md` — the ritual step by step with the exact commands and skills (graph edit → optional plan-challenge: `codex exec -C . -s read-only --ephemeral -c model_reasoning_effort="high" -c skills.include_instructions=false "<challenge prompt: misunderstood requirements, missing edge cases, excess complexity, architectural conflicts; BLOCKER/MAJOR/MINOR + APPROVE/REVISE>" < /dev/null` → human graph approval → `*_api` → impl → `app/` → `tool/checks.sh --fast` inner loop → `/adversarial-tests` → full gate → `/cross-review` → behavioral check); the role table (agent implements / tools verify / Codex reviews / human decides at two checkpoints); the completion-report shape with **Remaining risks**; **opt-in hardening** subsection: a Stop-hook review gate, shown as this snippet and explicitly NOT wired by default (cost: every stop waits 1–5 min for a review):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/tool/hooks/stop_review_gate.sh",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

with `tool/hooks/stop_review_gate.sh` (shown in the doc, not shipped) reading the payload, exiting 0 immediately when `stop_hook_active` is true (the hook must not loop on its own continuation), running `.claude/skills/cross-review/codex_review.sh --structured` and exiting 2 with the findings on stderr when `verdict` is `request_changes`; reasoning-effort escalation note (when a task stalls, re-dispatch with a more capable model / higher effort rather than retrying the same one).

`docs/workflow/maintenance.md` — survives init; pin-update cadence and checklist: Flutter (`.fvmrc` → re-validate `analysis_server_plugin` pin (0.3.20, exact; hang history), full gate, template smoke); the codegen ceiling (freezed 3.2.5 `analyzer <11` → drift_dev 2.34.0 / build_runner 2.15.1; re-check on every freezed release; `flutter pub outdated` will nag); patrol/patrol_cli coupling (patrol 4.9.0 ↔ patrol_cli 4.7.0, min Flutter 3.32 — verified against pub.dev and the patrol compatibility table on 2026-08-21; only `patrol_finders` 3.6.0 is pinned until M5 adds `patrol`); Codex model pin (`review_model` in `.codex/config.toml` + the skill) and CLI version (0.144.x; flags verified there); Claude Code hooks/rules features (2.1.x); the `provider`-via-flutter_bloc transitive note; how to run the upgrade: bump → `fvm flutter pub get` → `tool/checks.sh` → fix → record in this file.

`docs/workflow/modules.md` — spec §12 with its exact one-liners: superpowers (recommended, per-user, zero repo footprint: `/plugin install superpowers@claude-plugins-official` in Claude Code + the documented Codex bootstrap); spec-kit (optional: `uv tool install specify-cli`, `specify init . --integration claude`, `specify integration install codex`; the constitution concept is already AGENTS.md); beads (optional: `brew install beads && bd init && bd setup claude && bd setup codex`); marionette (optional module: `marionette_flutter` in the debug build + a verify-flow skill; the ValueKey convention already serves it); nothing vendored and why (churn).

`docs/reference/critical_flows.md` — purpose (the e2e test plan; gate-checked from M5: every row's test path must exist), the table format, the empty table + the M5 comment, the restart convention (in-process widget restart in `app/test/app_test.dart` is the widget-level twin; OS process death is out of scope).

`docs/reference/ci_contract.md` — CI runs `tool/checks.sh` verbatim and owns no logic; `CI=true` detection; what `ci.yml` does today (ubuntu-latest, `libsqlite3-dev`, flutter-action from `.fvmrc`, 30 min); known environment assumptions to verify on first runs (sqlite3 Dart hook download on Linux; KVM for e2e — M5); `e2e.yml` and `template-smoke.yml` land in M5; Claude GitHub bot and Codex cloud PR review are documented, not shipped (per-user secrets; Codex cloud picks up `## Code Review Rules` with zero workflow).

`docs/reference/feature_package_skeletons.md` — the file trees for the ritual: `packages/feature_x_api/` (pubspec, `lib/feature_x_api.dart`, `src/x_api.dart`, `src/x_keys.dart`, `src/x_routes.dart`, `src/x_failure_codes.dart`, `test/x_keys_test.dart`) and `packages/feature_x/` (pubspec with the allowed deps, `lib/feature_x.dart` with the single `show` export, `src/x_repository.dart`, `src/<impl>_x_repository.dart`, `src/bloc/x_event.dart`, `x_state.dart` (freezed), `x_bloc.dart`, `src/ui/x_screen.dart`, `src/x_api_impl.dart`, `src/x_module.dart`, `test/…` mirroring `feature_settings`), the `package_graph.yaml` entries to add, and the `app/lib/bootstrap/app_dependencies.dart` lines that wire the module.

Root `README.md` — pitch (what Alatyr is, the hardness idea, two agents, human at two checkpoints), quick start (Use this template → `dart run tool/init.dart --name my_app --org com.example` (lands in M5) → `fvm flutter pub get` → `tool/checks.sh`), what's inside (the layout from spec §3 trimmed to what exists), the docs index link, the maintenance link, licence (MIT). Identity tokens may appear here (spec §9).

- [ ] **Step 3: Twins, test, gate, commit**

Write the `.ru.md` twins (including `README.ru.md`). Run: `fvm dart format test && fvm dart test test/docs_test.dart` → PASS (5 tests). Run: `tool/checks.sh` → `OK`.

```bash
git add docs/testing docs/workflow docs/reference README.md test/docs_test.dart
git commit -m "docs: testing, workflow, reference set and root README"
```

---

### Task 8: Dogfood the harness on this branch — cross-review of M4, spec touch-ups, carryover, wrap-up

**Files:**
- Modify: `docs/superpowers/specs/2026-08-13-alatyr-flutter-starter-design.md` (status + §6 hook note + §7 rewrite to the verified Codex reality), `docs/superpowers/plans/m3-carryover.md` → `m4-carryover.md`
- Twins

- [ ] **Step 1: Cross-review of the whole branch (DoD 4)**

Run: `.claude/skills/cross-review/codex_review.sh --base main --structured` and `… --base main` (primary), Bash timeout 600000 ms each. Paste both outputs VERBATIM into the task report (the verdict sentence alone is not evidence). Evaluate per the skill (✅/❌/🤔), fix every accepted P0/P1 in a commit `fix(harness): address cross-review findings` and record rebuttals in the task report. If the review could not be performed, quote the stderr reason — the human decides the waiver at merge time.

- [ ] **Step 2: Spec touch-ups (facts, not design)**

- Status: `implementation in progress (M4 done)`.
- §6 "Agent-level hooks" implementation note → replace with the verified facts: Codex project hooks live in `.codex/hooks.json`, file edits arrive as `apply_patch` (matched by `Edit|Write`) with the patch text in `tool_input.command`, exit 2 + stderr blocks, hooks load only after project trust AND a one-time `/hooks` trust per checkout and are skipped silently otherwise — the freshness gate remains the backstop for invariant 5.
- §7: replace the `[profiles.review]` block and the `codex review --base <branch> --json "<reviewer prompt>"` sentence with the verified shapes (project `.codex/config.toml` holds only `review_model`; role constraints are per-call flags in the skill's script; primary path `codex exec -s read-only --ephemeral … review --base <ref> -o <file>`; structured path `git diff --merge-base <ref> HEAD | codex exec … --output-schema .codex/review-schema.json`). Keep the four-point protocol.
- §3 tree: `.codex/config.toml   # review model pin (trust-gated project config)` and add `codex-reviewer.md  # thin wrapper: runs codex_review.sh for workflows` under `.claude/agents/`; §4 "the review profile" → "the skill's per-call flags"; §6 and §14 "repo-relative path" → "git-root-resolved path (Codex runs hooks with the session cwd)"; §4 enforcement table row for invariant 9 → "banned list enforced by tools; the ADR requirement is review-owned".
- §15 risk 4 → "resolved: verified end-to-end in the M4 research pass (Codex 0.144.6 blocked a generated-file write through `.codex/hooks.json`)" — plus "and reproduced in Task 2's smoke" only if that smoke actually blocked; otherwise leave the research sentence alone.

- [ ] **Step 3: Carryover**

Create `docs/superpowers/plans/m4-carryover.md` and delete `m3-carryover.md` AND its twin `m3-carryover.ru.md` (the M4 section is closed by Tasks 1–7). The new file has exactly two sections, `## M5 (instantiation + e2e)` and `## Recorded as accepted (no action planned)`: copy m3-carryover's M5 bullets and accepted bullets forward verbatim into them, then append these bullets to the SAME sections (no duplicate headings):

```markdown
- `docs/reference/critical_flows.md` ships the table format and an empty
  table; M5 adds the first row (`app/integration_test/...`) together with
  the gate's registry-check stage and the `e2e.sh`/`e2e.yaml` runner.
- `tool/init.dart` must keep `AGENTS.md`, `CLAUDE.md`, `.claude/`,
  `.codex/` and `tool/hooks/` product-neutral (no identity tokens are in
  them today; `test/template_identity_test.dart` scans `packages/`,
  `lints/`, `tool/` — extend it to `AGENTS.md`, `CLAUDE.md`, `.claude/`,
  `.codex/`) and must delete `docs/superpowers/` and this file.
- The Codex PostToolUse payload for `apply_patch` was not captured; a
  Codex-side `dart format` hook (mirroring `.claude/settings.json`'s
  PostToolUse) is not shipped - add it once the payload shape is verified.
- `.claude/settings.json` permissions allow `tool/e2e.sh` ahead of its
  existence; M5 adds the script.
```

and to "Recorded as accepted":

```markdown
- Codex hooks depend on per-checkout trust (`/hooks`); CI runners and fresh
  clones are unprotected by the hook until trusted - the cold-rebuild
  freshness gate is the enforcement of record for invariant 5.
- The Stop-hook review gate is documented as opt-in hardening, not wired.
- `guard_generated.sh` reads the first `file_path` of a Claude payload and
  parses patch headers only for `apply_patch`; a JSON parser would be
  exact, but bash + sed keeps the hook dependency-free.
```

- [ ] **Step 4: Gate, twins, commit**

Run: `tool/checks.sh` → `OK`; `fvm dart test test/docs_test.dart test/harness_test.dart` → PASS.

```bash
git add -A docs/superpowers AGENTS.md README.md
git commit -m "chore: mark M4 complete in spec status, carryover for M5"
```

(The merge into `main` is the controller's step after the whole-branch review.)

---

## Remaining risks (known at planning time)

- **Live hook smokes (Task 2 Step 4)** need a nested `claude -p` run and a hand-computed Codex hook-trust hash; both were exercised only in the research pass (Codex: verified; Claude: documented). If they fail in execution, the Dart tests on captured payloads are the contract's proof and the report says so.
- **`codex exec review` honouring `## Code Review Rules`:** the research pass planted a rule in a scratch AGENTS.md and saw the local native reviewer apply it (one run, 0.144.6); Task 3 Step 6 re-checks on this branch. If the native reviewer ever ignores the rubric, the structured path (which states it in the prompt) becomes primary and the skill says so.
- **Invariant 9 is only half tool-enforced:** the graph consumers enforce the banned list; "no non-canonical dependency without an ADR" is review-owned (AGENTS.md says so now; spec §4's table is touched up in Task 8).
- **Nested agent runs in smokes** (`claude -p` with `CLAUDECODE` unset; `codex exec` with an inline hook-trust hash and `--skip-git-repo-check`, which is not project trust) may fail for environment reasons; the captured-payload Dart tests are the contract's proof and the report must say which smoke ran.
- **Docs drift:** the docs set describes the repo at this commit; M5 will change commands (init, e2e). Each M5 task must touch the docs it invalidates; the link/existence test catches structure, not prose.
- **Trust gating:** neither agent's project hooks fire before the user trusts the project (and, for Codex, the hook); invariant 5 is enforced by the gate alone on fresh clones and CI — recorded in the carryover and in getting-started.
