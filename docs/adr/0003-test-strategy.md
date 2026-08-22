# ADR-0003: Test strategy

**Status:** accepted
**Date:** 2026-08-13

## Context

An agent-built codebase needs tests that are cheap to write correctly,
hard to write meaninglessly, and do not silently rot into a green gate
over broken behavior.

## Decision

Patrol finders (`patrol_finders`, the `$` syntax) are the structural
default for every widget and integration test — no raw `flutter_test`
finders in new tests. Golden tests are opt-in only, run on a deterministic,
Flutter-engine-only harness (no cross-engine visual comparison). There is
no coverage-percentage floor. Test names are the test-case catalog
("`'given stored theme is corrupted, settings falls back to system'`") —
generated from code, never hand-maintained in an external tool. Every new
or changed behavior gets an adversarial pass: a fresh-context test-breaker
subagent proposes break scenarios, each becomes a test or an explicit
`skip: 'deliberate: …'` stub.

## Consequences

Test quality is a review concern, not a percentage gate: hardness comes
from mandatory test *types* per layer (bloc tests, repository tests on a
real in-memory drift database, structural widget tests, a module assembly
test, an app bootstrap smoke test) plus the adversarial pass, not from
chasing a coverage number. Patrol finders being the only widget-test idiom
means the same key-based addressing (`SettingsKeys`) widget tests use
today will carry over unchanged to patrol e2e once it lands (M5).
Deliberately uncovered scenarios are visible in the diff as skip stubs,
not silently absent.

## Alternatives considered

- **Coverage thresholds** — rejected; they reward percentage-chasing over
  behavior coverage and slow the gate without a corresponding honesty gain.
- **An external test-management system** — rejected; it adds credentials
  and a second source of truth that drifts silently and is invisible to
  agents, the gate, and review. Test names plus skip stubs are the record
  today; the critical-flows registry (M5) joins them as the e2e plan.
- **Golden tests in the default gate** — rejected; cross-engine visual
  drift is real and would make the gate flaky for reasons unrelated to
  the code under test. Goldens remain available, opt-in, engine-pinned.
