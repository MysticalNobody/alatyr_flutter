# CI contract

CI runs `tool/checks.sh` verbatim and owns no logic of its own — there is
exactly one place that decides what "green" means (the gate script), and
CI's only job is to invoke it and report the exit code. This is the point
of ADR-0004 (single gate): whatever a contributor runs locally is exactly
what a PR runs, so a red CI run is always reproducible on a laptop.

`tool/checks.sh` detects CI through the standard `CI` environment
variable: any truthy value (`CI=true`, which GitHub Actions sets by
default) switches the codegen-freshness check from a warning (dirty local
tree tolerated) to a hard failure when the working tree is not a git
repository at all — CI without a git worktree cannot verify freshness, so
that combination is treated as a setup bug, not a pass.

## `ci.yml` today

- Trigger: pushes to `main`, and every pull request.
- Runner: `ubuntu-latest`, `libsqlite3-dev` installed (drift's native
  sqlite3 build needs it — standard drift practice).
- Flutter: `subosito/flutter-action@v2` reading the version from
  `.fvmrc`, with its cache enabled.
- One step after checkout and setup: `tool/checks.sh`. Nothing else — no
  separate lint step, no separate test step; the gate already runs both.
- Timeout: 30 minutes for the whole job.

## Environment assumptions to verify on first real runs

- **The sqlite3 Dart-hook download** (see
  `docs/workflow/getting-started.md`) happens on Linux runners the same as
  locally — the first codegen/test invocation that touches a package
  depending on `sqlite3` fetches its prebuilt native library through the
  build hook. A cold CI runner therefore pays that network cost on its
  first cache-miss run; if `ci.yml` ever adds dependency caching, cache
  `.dart_tool/hooks_runner/` alongside `pubspec.lock`-keyed pub caches.
- **KVM availability for e2e** — `e2e.yml` (lands in M5) needs a
  hardware-accelerated Android emulator; GitHub-hosted `ubuntu` runners
  expose KVM, but this must be confirmed empirically on the first real
  `e2e.yml` run, not assumed from documentation.

## What lands in M5

- **`e2e.yml`** — PRs to main, `tool/e2e.sh android` with the committed
  device spec (`tool/e2e.yaml`).
- **`template-smoke.yml`** — template-repo only: copies the tree, runs
  `tool/init.dart` on the copy, then the full gate on the result. Deleted
  by `init` itself (it has no meaning once a repo has been instantiated).

## Documented, not shipped

Claude's GitHub bot and Codex cloud PR review are **documented here, not
wired into any workflow**: both need per-user secrets or app installs that
this template cannot ship on a consumer's behalf. Codex cloud in
particular needs zero workflow file of its own — installing the Codex
GitHub App on a repository is enough for it to pick up this repo's
`## Code Review Rules` section from `AGENTS.md` and apply the same rubric
`codex_review.sh` uses locally, with no YAML to write or maintain.
