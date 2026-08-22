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
  otherwise; see `tool/common.sh`).
- **`libsqlite3-dev`** and **`libsecret-1-dev`** on Linux — drift's native
  sqlite3 build and `flutter_secure_storage`'s libsecret backend need them.
- **Node**, for the agent CLIs (`npm i -g @openai/codex`; Claude Code
  itself).

## First gate run

```bash
git clone <your fork>
cd alatyr_flutter
fvm install
fvm flutter pub get
tool/checks.sh --fast   # format + dependency graph + imports, ~seconds
tool/checks.sh          # the full gate, ~3 minutes cold
```

`--fast` prints three stages (`Formatting`, `Dependency graph`,
`Architecture imports`) and exits `OK (fast)`. The full gate additionally
runs codegen (a **cold** `build_runner` rebuild — every codegen package's
`.dart_tool/build` is removed first, so this run recompiles every builder;
later runs are faster), compares a before/after worktree snapshot to catch
stale generated files, checks transitive purity, analyzes and tests the
root context and every workspace member, then the lint plugin in isolation
plus its violations-fixture integration check, and prints `OK`.

The **first** full-gate run also does one network fetch you would not
expect from a "local" quality gate: drift's `sqlite3` dependency provisions
its native library through a Dart build hook, downloading a prebuilt
binary into `.dart_tool/hooks_runner/sqlite3/` the first time any package
that depends on it is built or tested. Subsequent runs reuse it; offline
CI runners should warm this cache once before going air-gapped.

## Running the app

```bash
cp .dart-defines/dev.env.example .dart-defines/dev.env
cd app
fvm flutter run -d <device> --dart-define-from-file=../.dart-defines/dev.env
```

Only public client values belong in `dev.env` (base URLs, publishable
keys) — see `docs/architecture/06-security.md`. `<device>` is any device
`fvm flutter devices` lists.

**Web:** the app compiles and runs, but persistence needs two web-specific
assets drift ships for the browser (`sqlite3.wasm`, `drift_worker.js`) that
this milestone does not wire up yet — lands in M5.

## Trust steps

Both agents refuse to act on this repo's automation until you trust it
once. Skipping this step does not break anything loudly — hooks are simply
silent, which is why it is worth doing deliberately.

### Claude Code

Start the `claude` session **at the repository root**. Project settings
(`.claude/settings.json` — hooks, permissions) and `CLAUDE.md` load only
from the directory the session starts in; a session started inside `app/`
has neither the codegen-guard hook nor the deny rule. On first use, Claude
Code asks you to accept workspace trust for the folder — hooks in
`.claude/settings.json` fire only after you accept it. Run `/hooks` inside
the session at any point to see which hooks are currently wired and
trusted.

### Codex

The first `codex` command you run in this repository asks whether to
trust the project; accepting writes
`[projects."<absolute repo path>"] trust_level = "trusted"` to
`~/.codex/config.toml`. A read-only invocation (`-s read-only`, as the
cross-review skill uses) never prompts for or grants trust on its own.
Project trust alone is not enough for hooks: review and trust
`.codex/hooks.json` once with `/hooks` inside the Codex TUI. **Until you do
that, the hook is silently skipped** — no warning, no error — and the
codegen-freshness gate stage is the only thing still protecting generated
files from hand edits by Codex.

Log in once with `codex login`. The review model is pinned in
`.codex/config.toml` (`review_model`) — read the value there rather than
from this page; if Codex ever rejects that pin,
`docs/workflow/maintenance.md` owns the update.

## Troubleshooting

- **Edited `plugins:` and lint diagnostics did not change:** restart the
  Dart/Flutter analysis server (your editor's "Restart Analysis Server"
  command) — it only re-reads `analysis_options.yaml`'s `plugins:` section
  on (re)start.
- **`flutter analyze` shows no `alatyr_lints` diagnostics:** this is
  expected, not a bug — the analyzer-plugin host does not load under
  one-shot `flutter analyze` (`sdk#63787`). Use `dart analyze` (what
  `tool/checks.sh` runs) to see plugin diagnostics.
- **Patrol e2e setup** (device provisioning, `tool/e2e.sh`) lands in M5;
  there is nothing to troubleshoot here yet.

## Next

`docs/workflow/feature-workflow.md` for the day-to-day ritual once the gate
is green.
