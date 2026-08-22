# CI contract

CI runs `tool/checks.sh` verbatim and owns no logic of its own — there is
exactly one place that decides what "green" means (the gate script), and
CI's only job is to invoke it and report the exit code. This is the point
of ADR-0004 (single gate): whatever a contributor runs locally is exactly
what a PR runs, so a red CI run is always reproducible on a laptop.

`tool/checks.sh` detects CI through the standard `CI` environment
variable: any truthy value (`CI=true`, which GitHub Actions sets by default)
turns exactly one case from a warning into a hard failure — the
codegen-freshness stage running outside a git worktree, where it cannot
compare anything. CI without a worktree is a setup bug, not a pass.
Independently of `CI`, that stage compares a snapshot of the working tree
taken before codegen with one taken after, so pre-existing local edits show
up in both and are tolerated; only what codegen itself changed fails it.

## `ci.yml` today

- Trigger: pushes to `main`, and every pull request.
- Runner: `ubuntu-latest`. No apt step: sqlite3's Dart hook downloads a
  sha-pinned prebuilt library from github.com at test time (see the
  comment above the gate step in `ci.yml` itself and
  `docs/workflow/getting-started.md`) — nothing needs to be installed by
  the workflow for it.
- Flutter: `subosito/flutter-action@v2` reading the version from
  `.fvmrc`, with its cache enabled.
- One step after checkout and setup: `tool/checks.sh`. Nothing else — no
  separate lint step, no separate test step; the gate already runs both.
- Timeout: 30 minutes for the whole job.

## `template-smoke.yml` today

Template-repo only: checkout, Flutter via `.fvmrc`, then
`tool/template_smoke.sh "${{ runner.temp }}/fixture_app"` — copies the
tree, runs `tool/init.dart` on the copy, then the full gate on the
result. Triggers on pushes to `main`, every pull request, and
`workflow_dispatch`; 40-minute timeout. Deleted by `init` itself (it has
no meaning once a repo has been instantiated).

## `e2e.yml` today — advisory

PRs to main and `workflow_dispatch`; `tool/e2e.sh android` with the
device spec read from `tool/e2e.yaml` through `tool/e2e_config.dart`
(single source of truth — the workflow restates nothing). The job runs
with `continue-on-error: true`, so a red run is reported on the PR but
never blocks merge: hosted-runner Android-emulator viability (KVM
availability, boot time, AVD cache correctness) has no track record yet
(spec §15 risk 5). Flip it to required — drop `continue-on-error` — once
it has been green on a handful of real PRs.

## Environment assumptions to verify on first real runs

- **The sqlite3 Dart-hook download** (see
  `docs/workflow/getting-started.md`) happens on Linux runners the same as
  locally — the first codegen/test invocation that touches a package
  depending on `sqlite3` fetches its prebuilt native library through the
  build hook. A cold CI runner therefore pays that network cost on its
  first cache-miss run; if `ci.yml` ever adds dependency caching, cache
  `.dart_tool/hooks_runner/` alongside `pubspec.lock`-keyed pub caches.
- **KVM availability for e2e** — `e2e.yml` needs a hardware-accelerated
  Android emulator; GitHub-hosted `ubuntu` runners expose KVM, but this
  must be confirmed empirically on the first real `e2e.yml` runs, not
  assumed from documentation — which is exactly why the job stays
  advisory (`continue-on-error: true`) until it has that track record.

## Documented, not shipped

Claude's GitHub bot and Codex cloud PR review are **documented here, not
wired into any workflow**: both need per-user secrets or app installs that
this template cannot ship on a consumer's behalf. Codex cloud in
particular needs zero workflow file of its own — installing the Codex
GitHub App on a repository is enough for it to pick up this repo's
`## Code Review Rules` section from `AGENTS.md` and apply the same rubric
`codex_review.sh` uses locally, with no YAML to write or maintain.
