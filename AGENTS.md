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
| 7 | review rubric + patrol e2e (lands in M5; no lint rule yet — accepted gap) |
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
