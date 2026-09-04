# Testing strategy

The pyramid, why there is no coverage floor, the patrol-finders policy, how
test-case management works without an external tool, and where the
adversarial pass fits.

## The pyramid

| Layer | Test type | Tools |
|---|---|---|
| `app_core`, `app_config` | pure unit | `test` |
| Blocs | bloc tests | `bloc_test`, `mocktail` |
| Repositories | unit on real DB | drift in-memory (`NativeDatabase.memory()`) |
| Screens | structural widget tests | `patrol_finders` (`$` syntax) |
| Feature module | assembly test | `flutter_test` + patrol finders |
| App shell | bootstrap smoke | `flutter_test` |
| Critical flows | patrol e2e | `patrol` via `tool/e2e.sh` |
| Toolchain | fixture tests | `test` (root `test/`) |
| Lint rules | unit + integration fixture | `test` + real `dart analyze` |

Every layer, including e2e, exists today as a copyable exemplar: the
runner (`tool/e2e.sh`), the declarative device spec (`tool/e2e.yaml`), and
the registered flow (`docs/reference/critical_flows.md`, proved by
`app/integration_test/settings_theme_test.dart`).

## No coverage floor

There is no coverage-percentage gate, deliberately. A percentage rewards
covering lines, not covering behavior — it is easy to hit 90% while never
asserting the one case that matters, and a floor slows the gate for a
number that does not correlate with correctness. Hardness comes instead
from **mandatory test types per layer** (the pyramid above — a bloc
without a bloc test, or a repository without a real-DB test, is a gap
review will catch, coverage tooling will not) plus review of test
*quality* as part of cross-review. See ADR-0003 for the full argument and
the alternatives considered.

## Patrol-finders policy

`patrol_finders` (the `$` syntax) is the structural default for every
widget and integration test — no raw `flutter_test` finders
(`find.byKey`/`find.byType`) in new tests. Golden tests are opt-in only:
run on a deterministic, Flutter-engine-only harness. Cross-engine visual
comparison is banned by ADR-0003 — it makes the gate flaky for reasons
unrelated to the code under test, so goldens never enter the default gate.

## "TMS from code" — no external test-management system

Test names ARE the test-case catalog:
`'given stored theme is corrupted, settings falls back to system'` reads as
a case on its own. The catalog is generated from code, never hand-
maintained — `flutter test --reporter json` enumerates every case by name.
`docs/reference/critical_flows.md` is the e2e test plan (flow name → patrol
test path). Deliberately uncovered scenarios are `skip: 'deliberate: …'`
stubs: machine-enumerable, visible in the diff, impossible to lose
silently. An external TMS was considered and rejected (ADR-0003): it adds
credentials and a second source of truth that drifts silently and is
invisible to agents, the gate, and review.

## The adversarial pass

Every new or changed behavior gets one: a fresh, read-only subagent
given only the `*_api` contract, feature spec/plan, and diff, with no
implementer reasoning or inherited conversation. Claude dispatches its
`test-breaker` subagent through `/adversarial-tests`; Codex dispatches a
collaboration subagent with the same rubric from
`.claude/agents/test-breaker.md`. It returns break scenarios (boundary values,
races, lifecycle, process death/restart, dependency failures, corrupted
stored data) as "action → required behavior → test layer". The
implementer covers every scenario with a test or a `skip: 'deliberate: …'`
stub and reports the tally. See `docs/workflow/feature-workflow.md` for
where this sits in the ritual for either implementer.

## The eight verification layers of a feature

1. Types + analyzer (`--fatal-infos`) — instant.
2. Architecture: graph / imports / lints — seconds, machine.
3. Package test pyramid (widget tests via patrol finders) — minutes,
   machine.
4. Codegen freshness (snapshot diff) — machine.
5. Adversarial tests (fresh-context test-breaker) — machine + independent
   context.
6. Patrol e2e over registered critical flows — machine, on-device
   (`tool/e2e.sh`).
7. Cross-review of the committed task diff — Codex reviews Claude's work;
   Claude reviews Codex's work, against the same `AGENTS.md` rubric.
8. Human behavioral check (UI changes) — the one human layer, by design.

## Exemplar map

The copyable pattern for each test type, by file:

| Test type | Exemplar |
|---|---|
| Bloc test | `packages/feature_settings/test/settings_bloc_test.dart` |
| Repository on in-memory drift | `packages/feature_settings/test/drift_settings_repository_test.dart` |
| Patrol widget test | `packages/feature_settings/test/settings_screen_test.dart`, `packages/design_system/test/app_choice_tile_test.dart` |
| Module assembly test | `packages/feature_settings/test/settings_module_test.dart` |
| App smoke, incl. bootstrap and in-process restart | `app/test/app_test.dart` |
| Patrol e2e (registered in-process restart + fresh-process bonus) | `app/integration_test/settings_theme_test.dart` |
| Toolchain fixtures | root `test/` |
| Lint rules | `lints/test/` |

## Next

`docs/testing/widget-test-guardrails.md` for the anti-hang rules these
exemplars follow.
