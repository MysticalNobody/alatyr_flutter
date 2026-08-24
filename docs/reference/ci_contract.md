# CI contract

**No CI is wired today.** The three GitHub workflows that invoked the
gate, the template smoke, and an advisory Android e2e job (`ci.yml`,
`template-smoke.yml`, `e2e.yml`) were removed on 2026-08-24 in favor of
local-only verification: none of them had ever executed on a hosted
runner, and an unexercised workflow is an unverifiable claim — exactly
what this template refuses to ship. The template repository's own git
history keeps all three as a starting point for reintroduction
(`git log --diff-filter=D -- '.github/workflows/*'`); an instantiated
copy has no such history — there, recreate the YAML from the notes
below.

## What runs instead — all local

Each command is the single owner of its result:

- `tool/checks.sh` — the one quality gate (ADR-0004): format, graph,
  imports, codegen freshness (cold rebuild + snapshot compare), purity,
  workspace-wide analyze and tests, the lint plugin's own checks, the
  critical-flows registry. `--fast` is the inner loop.
- `tool/e2e.sh [android|ios]` — the patrol critical flows on the
  declared devices (`tool/e2e.yaml`; see `docs/workflow/e2e.md`).
- `tool/web_smoke.sh` — drift persistence on the web proved in headless
  Chrome.
- `tool/template_smoke.sh` — builds a fixture from this checkout's
  tracked files (exactly the "Use this template" payload — no gitignored
  local junk), instantiates it with `tool/init.dart`, runs the full gate
  on the result; the default temp fixture is removed on success and kept
  for debugging on failure. Template-repo only; deleted by `init`.

## The contract any future CI must keep

CI runs `tool/checks.sh` verbatim and owns no logic of its own — there
is exactly one place that decides what "green" means (the gate script),
and CI's only job is to invoke it and report the exit code. This is the
point of ADR-0004 (single gate): whatever a contributor runs locally is
exactly what a PR runs, so a red CI run is always reproducible on a
laptop.

`tool/checks.sh` detects CI through the standard `CI` environment
variable: any truthy value (`CI=true`, which every major provider sets)
turns exactly one case from a warning into a hard failure — the
codegen-freshness stage running outside a git worktree, where it cannot
compare anything. CI without a worktree is a setup bug, not a pass.
`tool/e2e.sh` likewise shuts booted devices down when `CI` is truthy and
keeps them alive locally.

## Reintroduction checklist

Reintroduce CI as one deliberate pass, in this order:

1. Prove `tool/checks.sh` on a hosted runner, including outbound HTTPS for
   sqlite3's hook and no `libsqlite3-dev` workaround.
2. Add `tool/template_smoke.sh` as its own job.
3. Add Android e2e as advisory until representative green PR runs establish
   KVM, emulator boot, and cache viability; only then make it required.
4. Explicitly accept macOS-runner cost before adding iOS e2e.
5. Explicitly accept headless-Chrome cost and flakiness before adding
   `tool/web_smoke.sh`.
6. Never treat agent hooks as enforcement on an untrusted ephemeral runner.
   Codex `/hooks` requires per-checkout trust; the cold codegen-freshness gate
   remains authoritative.

## Environment notes for a future runner

- **sqlite3's Dart hook** downloads a sha-pinned prebuilt library from
  github.com at test time (see `docs/workflow/getting-started.md`) — a
  Linux runner needs outbound HTTPS and no `libsqlite3-dev`; a cold
  runner pays the network cost on its first cache-miss run (cache
  `.dart_tool/hooks_runner/` alongside `pubspec.lock`-keyed pub caches).
- **Android e2e needs a hardware-accelerated emulator** (KVM on Linux).
  Hosted-runner viability — KVM exposure, boot time, AVD cache
  correctness — has no track record here; reintroduce the job as
  advisory (`continue-on-error`) and flip it to required only after a
  handful of green runs. iOS e2e needs a macOS runner.
- **Flutter** comes from `.fvmrc` (e.g. `subosito/flutter-action@v2`
  with `flutter-version-file`), never a floating channel.

## Documented, not shipped

Claude's GitHub bot and Codex cloud PR review are **documented here, not
wired into any workflow**: both need per-user secrets or app installs
that this template cannot ship on a consumer's behalf. Codex cloud in
particular needs zero workflow file of its own — installing the Codex
GitHub App on a repository is enough for it to pick up this repo's
`## Code Review Rules` section from `AGENTS.md` and apply the same
rubric `codex_review.sh` uses locally, with no YAML to write or
maintain.
