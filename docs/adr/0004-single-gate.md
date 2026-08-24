# ADR-0004: Single gate

**Status:** accepted
**Date:** 2026-08-13

## Context

A gate that behaves differently locally and in CI erodes trust in a green
local run, and a hung analyzer or test process is worse than a red one —
it silently stalls an agent's inner loop.

## Decision

One script, `tool/checks.sh`, is the canonical quality gate, run
identically on a developer's machine and in CI. Its tiers are `--fast`
(format → dependency graph → import boundaries, the agent's inner loop),
the default full tier (fast stages, then a cold codegen rebuild with a
worktree snapshot compare, transitive purity, the workspace-wide analyze
and test pass, the lint plugin's own analyze/test/integration fixture),
and `--package <dir>` (a targeted analyze+test for one member). A CI
runner, when one is wired, runs exactly `tool/checks.sh` and owns no
additional logic of its own (none is wired today — see
`docs/reference/ci_contract.md`). Every `analyze`/`test`/codegen
invocation runs under a hard OS wall-clock timeout that names the
offending package.

Generated outputs are committed and must not be gitignored: the cold rebuild
can prove freshness only by comparing regenerated files with tracked output.
The workspace commits one root `pubspec.lock`; member lockfiles do not exist,
and the same snapshot stage rejects an unresolved root lockfile. Codegen stays
one invocation per package declaring `build_runner`: its unit-tested plan
names the failing package, while `build_runner --workspace` does not preserve
that attribution.

## Consequences

There is nothing a PR can pass in CI that a contributor could not have
already seen fail locally, and nothing CI-specific to keep in sync with
the local script. A stale generated file or an unresolved `pubspec.lock`
is caught by the snapshot-diff stage before it can hide behind "it built
fine for me." A hung plugin host or a runaway codegen builder fails loudly
with a named package instead of stalling the whole run indefinitely.
The full tier deliberately repeats analysis per member after root analysis;
the extra time buys package-specific failure attribution while the root run
keeps the whole workspace, root tools, and plugin diagnostics covered.

## Alternatives considered

- **CI-only checks layered on top of the local gate** — rejected; any
  logic that only CI runs is a rule a contributor cannot verify before
  pushing, and it is the exact drift this ADR exists to prevent.
- **`flutter analyze` as the enforcement point for `alatyr_lints`** —
  rejected; a one-shot `flutter analyze` does not load a plugin host
  (`dart-lang/sdk#63787`), so `dart analyze --fatal-infos` is the stage
  that actually enforces plugin diagnostics, at the root and per member.
- **Soft timeouts (`flutter test --timeout`)** — rejected; they do not
  catch teardown hangs, which is exactly the failure mode an agent loop
  cannot recover from unattended.
