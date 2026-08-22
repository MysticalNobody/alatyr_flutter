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
- **`libsecret-1-dev`** on Linux — `flutter_secure_storage`'s libsecret
  backend needs it (drift's own native `sqlite3` library is no longer an
  apt package: see First gate run below).
- **Android SDK** with the `platforms;android-37` component installed
  (`sdkmanager --install "platforms;android-37"`) — `compileSdk 37` (see
  `docs/workflow/maintenance.md`) needs it present to build the app at
  all, separately from whatever system image `tool/e2e.sh` provisions for
  the emulator.
- **Node**, for the agent CLIs (`npm i -g @openai/codex`; Claude Code
  itself) and the web runtime smoke (`tool/web_smoke.sh`, Node >= 20).

## Instantiation (`tool/init.dart`)

Template-repo only: this checkout already carries the placeholder identity
(`alatyr_starter` / `dev.alatyr` / `Alatyr Starter`) that this command
rewrites into yours. Skip this section once you have run it — the command
deletes itself as its last step.

```bash
dart run tool/init.dart --name my_app --org com.example \
  [--display-name "My App"] [--template-url <url>] [--yes]
```

Prints the rename plan and asks to confirm (skip with `--yes`), then:
rewrites the identity everywhere it legitimately appears (`app/`, native
shells, the root `pubspec.yaml`, `docs/reference/package_graph.yaml`,
`README.md`) — Android/Linux/web get the snake-case bundle id
(`org.name`), iOS/macOS the camelCase one (`org.nameCamel`, no
underscores; Apple bundle ids forbid them); deletes itself, its tests,
and `docs/superpowers/` (the fixed list is `templateOnlyPaths` in
`tool/src/init_rewrite.dart`); runs `dart format` on what it touched,
then `dart pub get` and `tool/checks.sh --fast`. `docs/adr/` is never
rewritten — see ADR-0006 for the full identity grammar and rationale.
`--template-url` links the generated `README.md` back to Alatyr;
`--print-identity` prints the placeholder tokens as `KEY='value'` lines
instead of instantiating, for scripts that must not spell them
(`tool/template_smoke.sh`).

Needs a git checkout (`git ls-files` enumerates what to rewrite) — "Use
this template" and `tool/template_smoke.sh` both give you one; a plain
archive download does not, and the tool says so. If something looks wrong
before you commit the result, recover with `git checkout -- . && git
clean -fd`.

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
its native library through a Dart build hook, downloading a sha-pinned
prebuilt binary from `github.com` into `.dart_tool/hooks_runner/sqlite3/`
the first time any package that depends on it is built or tested —
outbound HTTPS to `github.com` must be reachable for that first run
(nothing needs installing by hand; `libsqlite3-dev` is not required).
Subsequent runs reuse it; offline CI runners should warm this cache once
before going air-gapped.

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
`docs/workflow/maintenance.md`, Web assets). Without COOP/COEP response
headers drift falls back to `sharedIndexedDb` (persists, slower); with
them it uses `opfsLocks`. A missing asset surfaces in the browser console
as `WebAssembly ... HTTP status code is not ok` (logged through the app's
theme-stream warning). `tool/web_smoke.sh` is the runtime check that
proves persistence survives a reload; it builds into `app/build/web` and
does not clean up after itself — delete `app/build` once you are done,
same as after a patrol run.

## Patrol e2e (`tool/e2e.sh`)

```bash
dart pub global activate patrol_cli 4.7.0   # <-> patrol 4.9.0 in app/pubspec.yaml
tool/e2e.sh android                         # or ios; --device <id>, --list, -t <file>
```

- **Devices** are found-or-created from the declarative spec in
  `tool/e2e.yaml`: Android AVD `e2e_pixel` (`pixel_7` profile, API 34, the
  arm64 or x86_64 system image per host architecture), iOS simulator
  `e2e_iphone` on an `iPhone 16`, matched to the newest installed "iOS
  18.x" runtime by major version (an exact `18.0` runtime is rarely what a
  dev machine has). No "first available device" fallback — a running
  emulator is reused only if it IS the declared AVD. `E2E_EMULATOR_PORT`
  (default `5554`) picks a different console port when that one is busy.
- **`patrol_cli`** must match the version pinned in `tool/e2e.sh` (checked
  against `patrol --version`); a mismatch fails with the exact activate
  command to run. See `docs/workflow/maintenance.md` for how this pin is
  kept in lockstep with `.github/workflows/e2e.yml`.
- **Exit codes:** `0` every test passed; patrol's own non-zero exit on
  test failures/errors; `2` usage; `3` e2e not performed (reason on
  stderr — report it verbatim, never fabricate a result); `124`
  (`gtimeout`/`timeout`) or `142` (the bare-macOS `perl`-alarm fallback,
  SIGALRM) when the hard wall-clock guard kills a hung run.
- **Disk:** a local `patrol test`, like `flutter build`, leaves
  0.5–2 GB under `app/build` — delete it after each proof step.

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
- **`tool/e2e.sh` exits 3 with `patrol_cli … is required (found …)`:**
  activate the exact pinned version it names — `fvm dart pub global run`
  still resolves from your global pub cache, so "some version installed"
  is not enough.
- **`tool/e2e.sh` exits 3 with "Android SDK command-line tools + emulator
  not found":** install the `cmdline-tools` and `emulator` SDK components
  and point `ANDROID_HOME` (or `ANDROID_SDK_ROOT`) at the SDK root; on
  iOS the equivalent is `xcrun` missing Xcode.

## Next

`docs/workflow/feature-workflow.md` for the day-to-day ritual once the gate
is green.
