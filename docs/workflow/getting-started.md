# Getting started

From a fresh clone to a green gate and a running app, plus the one-time
trust steps both agents need.

## Prerequisites

- **fvm**, with Flutter pinned by `.fvmrc` (currently `3.44.9`) — always
  invoke `fvm flutter` / `fvm dart`, never the bare binaries.
- **Xcode Command Line Tools** on macOS (`xcode-select --install`), for the
  iOS/macOS toolchains and native-asset builds.
- **`brew install coreutils`** on macOS, for `gtimeout` — the gate's hard
  wall-clock guard prefers it (`timeout` on Linux, a `perl`-alarm fallback
  otherwise; the fallback does not terminate grandchildren as reliably as
  `timeout -k`, see `tool/common.sh`).
- **`libsecret-1-dev`** on Linux — `flutter_secure_storage`'s libsecret
  backend needs it (drift's own native `sqlite3` library is no longer an
  apt package: see First gate run below).
- **Android SDK** with `platforms;android-37` installed
  (`sdkmanager --install "platforms;android-37"`) — `compileSdk 37` (see
  `docs/workflow/maintenance.md`) needs it to build the app at all, apart
  from whatever emulator image `tool/e2e.sh` provisions.
- **Node >= 20**, for the Codex CLI (`npm i -g @openai/codex`), the
  Claude review runner's JSON validation, and `tool/web_smoke.sh`.
- **Claude Code and Codex CLIs**, installed and authenticated for the
  chosen implementation/review pair. Either can implement; the other
  must be available to cross-review.

<!-- template-only:begin -->
## Instantiation

Template-repo only — init strips this whole section, along with the page
it links, out of the instantiated copy. This checkout carries a
placeholder identity (`alatyr_starter` / `dev.alatyr` / `Alatyr
Starter`): run `fvm install`, then `fvm dart run tool/init.dart`, before
anything else. See `docs/workflow/instantiation.md` for the command, the
bundle-id grammar, the clean-worktree requirement, and what it deletes.
<!-- template-only:end -->

## First gate run

```bash
git clone <your fork>
cd <your repo>
fvm install
fvm flutter pub get
tool/checks.sh --fast   # format + dependency graph + imports, ~seconds
tool/checks.sh          # the full gate, ~3 minutes cold
```

`--fast` prints three stages (`Formatting`, `Dependency graph`,
`Architecture imports`) and exits `OK (fast)`. The full gate additionally
runs a **cold** `build_runner` rebuild (every codegen package's
`.dart_tool/build` is removed first, so later runs are faster), diffs a
before/after worktree snapshot to catch stale generated files, checks
transitive purity, analyzes and tests every workspace member, then the
lint plugin in isolation plus its fixture check, and prints `OK`.

The **first** full-gate run also does one network fetch you would not
expect from a "local" quality gate: drift's `sqlite3` dependency downloads
a sha-pinned native prebuilt from `github.com` through a Dart build hook
the first time a dependent package is built or tested — outbound HTTPS to
`github.com` must be reachable once (`libsqlite3-dev` is not required).
Subsequent runs reuse the cache; offline CI runners should warm it first.

## Running the app

```bash
cp .dart-defines/dev.env.example .dart-defines/dev.env
cd app
fvm flutter run -d <device> --dart-define-from-file=../.dart-defines/dev.env
```

Only public client values belong in `dev.env` (base URLs, publishable
keys) — see `docs/architecture/06-security.md`. `<device>` is any device
`fvm flutter devices` lists.

**Web:** the two assets drift needs for browser persistence
(`sqlite3.wasm`, `drift_worker.js`) ship in `app/web/` (see
`docs/workflow/maintenance.md`, Web assets) — without COOP/COEP response
headers drift falls back to `sharedIndexedDb` (persists, slower), with
them `opfsLocks`; a missing asset surfaces in the browser console as
`WebAssembly ... HTTP status code is not ok`. `tool/web_smoke.sh` proves
persistence survives a reload; it builds into `app/build/web` and does not
clean up after itself — delete `app/build` when done, same as after a
patrol run. `AppDatabase.open` does not currently attach drift's web
`onResult` callback, so the chosen backend is not emitted through
`AppLogger`; diagnose a silent fallback in the browser console and add
structured logging before relying on telemetry for it.

## Patrol e2e

`tool/e2e.sh` drives the registered critical flow through a real
Android/iOS device or emulator. See
[`docs/workflow/e2e.md`](e2e.md) for the command, device spec, the
`patrol_cli` pin, exit codes, and disk cleanup.

## Trust steps

Both agents refuse to act on this repo's automation until you trust it
once. Skipping this step does not break anything loudly — hooks are simply
silent, which is why it is worth doing deliberately.

### Claude Code

Start the `claude` session **at the repository root** — project settings
(`.claude/settings.json`, `CLAUDE.md`) load only from the start directory,
so a session started inside `app/` has neither the codegen-guard hook nor
the deny rule. On first use, Claude Code asks you to accept workspace
trust — hooks fire only after that. Run `/hooks` to see what's wired.
Sign in once through `claude` before using it as the external reviewer.
`tool/claude_review.sh` reads the reviewer model from
`.claude/review-model` (`sonnet` by default, a moving alias rather than an
immutable model pin). Reviewer sessions deliberately disable hooks,
skills and MCP servers and allow only Read/Grep/Glob; they do not replace
the trusted implementation session's hooks.

### Codex

The first `codex` command here asks whether to trust the project;
accepting writes `trust_level = "trusted"` to `~/.codex/config.toml` (a
read-only `-s read-only` run, as the cross-review skill uses, never
grants trust). Project trust alone is not enough for hooks: also review
and trust `.codex/hooks.json` once with `/hooks` in the Codex TUI —
**until you do, the hook is silently skipped**, no warning, and the
codegen-freshness gate stage is the only thing still protecting generated
files from hand edits by Codex. Log in once with `codex login`; the
review model is pinned in `.codex/config.toml` (`review_model`) —
`docs/workflow/maintenance.md` owns updating it if Codex ever rejects it.

## Choose the implementer

At task start, use a task branch/worktree and record `git rev-parse HEAD`
in the task plan or conversation. Keep that SHA through every commit and
review fix. After the gate is green and the tree is committed and clean:

- **Claude implements → Codex reviews:** invoke `/cross-review --base
  <saved-task-start-sha>` in Claude Code, or run
  `.claude/skills/cross-review/codex_review.sh --base <saved-task-start-sha>`.
- **Codex implements → Claude reviews:** use Codex's repository skill
  `.agents/skills/cross-review/SKILL.md`, or run
  `tool/claude_review.sh --base <saved-task-start-sha>`.

Either runner supports `--structured` for the shared review schema and
`--out <dir>` for the result location. Both runners require `--base`;
always pass the saved task SHA explicitly. Missing/invalid scope, no
common ancestor, or an empty diff must be corrected,
and a dirty tree must be committed before retrying. These are not waiver
cases. The
[feature workflow](feature-workflow.md) covers findings, outputs, and
explicit human waivers for external CLI/authentication/model failures.

## Troubleshooting

- **Edited `plugins:` and lint diagnostics did not change:** restart the
  analysis server (editor's "Restart Analysis Server" command) — it only
  re-reads `analysis_options.yaml`'s `plugins:` section on (re)start.
  Separately, `flutter analyze` never shows `alatyr_lints` diagnostics —
  expected, not a bug (the plugin host does not load under one-shot
  `flutter analyze`, `sdk#63787`); use `dart analyze` (what
  `tool/checks.sh` runs).
- **`tool/e2e.sh` exits 3:** `patrol_cli … is required (found …)` means
  activate the exact pinned version it names (`fvm dart pub global run`
  still resolves from your global pub cache, so "some version installed"
  is not enough); "Android SDK command-line tools + emulator not found"
  means install the `cmdline-tools`/`emulator` SDK components and point
  `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) at the SDK root — on iOS the
  equivalent is `xcrun` missing Xcode.

## Next

`docs/workflow/feature-workflow.md` for the day-to-day ritual once the gate
is green.
