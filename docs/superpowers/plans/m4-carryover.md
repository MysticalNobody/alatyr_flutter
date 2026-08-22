# Carryover into M5 planning (from M3/M4)

Obligations that survived M3 and M4 (the M4 section from `m3-carryover.md`
is closed by Tasks 1-7 and dropped). The M5 plan MUST pick these up; delete
entries as they land.

## M5 (instantiation + e2e)

- Identity layout to rename (verified by grep after the rewrite): Android
  `namespace`/`applicationId` + Kotlin dir `dev/alatyr/starter`; iOS/macOS
  `PRODUCT_BUNDLE_IDENTIFIER` (Runner + RunnerTests), iOS `CFBundleName`,
  macOS `CFBundleName`/`CFBundleDisplayName` (literal, PRODUCT_NAME kept);
  web `manifest.json` name/short_name + `index.html` title/apple title;
  linux `APPLICATION_ID` + GTK titles; windows `Runner.rc`
  FileDescription/ProductName/CompanyName + `main.cpp` title; macOS
  `PRODUCT_COPYRIGHT` and windows `LegalCopyright` carry the org token.
- `flutter create` on a Mac with a signing identity writes
  `DEVELOPMENT_TEAM` into the iOS pbxproj; the shipped shell has it stripped -
  the init fixture must assert it stays absent.
- patrol_cli 4.x defaults the e2e dir to `patrol_test/`; to keep the spec's
  `app/integration_test/` layout set `patrol: test_directory:
  integration_test` in `app/pubspec.yaml`. `patrol` (the plugin, 4.9.0) is
  added to the app only in M5; set `PATROL_FLUTTER_COMMAND='fvm flutter'`.
- The app smoke test's in-process "restart" case is the widget-level twin of
  the patrol restart flow; register the patrol one in `critical_flows.md`.
- Web runtime: `AppDatabase.open` already passes `DriftWebOptions` for
  `sqlite3.wasm` + `drift_worker.js`; ship both into `app/web/` (versions
  matching the resolved `sqlite3` and `drift` packages - drift's
  "Getting started on the web" page lists the download URLs per release)
  and add a web runtime smoke (`flutter run -d chrome` or a web
  integration test) so persistence on web is verified, not assumed.
- `ios/Runner/Runner.entitlements` + `CODE_SIGN_ENTITLEMENTS` are part of
  the iOS shell now; the init fixture matrix must keep them intact (no
  identity tokens inside) and the iOS e2e run is the runtime proof.
- `test/template_identity_test.dart` asserts `tool/` carries no identity
  token; `tool/init.dart` + `tool/src/init_*` must spell them. Decide before
  M5 adds them: allowlist those files in the test, or have init derive the
  tokens (e.g. read the app entry of `package_graph.yaml` and the root
  pubspec name) instead of hardcoding them.
- `test/template_identity_test.dart` decodes files as strict UTF-8; before
  M5 adds binary fixtures or assets under `packages/`, `lints/` or `tool/`,
  switch to `utf8.decode(bytes, allowMalformed: true)` or restrict the scan
  to text extensions.
- `docs/reference/critical_flows.md` ships the table format and an empty
  table; M5 adds the first row (`app/integration_test/...`) together with
  the gate's registry-check stage and the `e2e.sh`/`e2e.yaml` runner.
- `tool/init.dart` must keep `AGENTS.md`, `CLAUDE.md`, `.claude/`,
  `.codex/` and `tool/hooks/` product-neutral (no identity tokens are in
  them today; `test/template_identity_test.dart` scans `packages/`,
  `lints/`, `tool/` — extend it to `AGENTS.md`, `CLAUDE.md`, `.claude/`,
  `.codex/`) and must delete `docs/superpowers/` and this file.
- The Codex PostToolUse payload for `apply_patch` was not captured; a
  Codex-side `dart format` hook (mirroring `.claude/settings.json`'s
  PostToolUse) is not shipped - add it once the payload shape is verified.
- `.claude/settings.json` permissions allow `tool/e2e.sh` ahead of its
  existence; M5 adds the script.

## Recorded as accepted (no action planned)

- Carried from M1/M2 reviews: deferred minors triaged OK-TO-DEFER at the M1
  final review (cosmetics, report noise, symmetric-code coverage gaps — see
  the M1 branch reviews in git history); the import lexer has no explicit
  recursion cap on interpolation nesting (bounded by real source shape) and
  malformed-paren directive bodies degrade to an EOF-bounded scan.
- Per-member `dart analyze` in the full tier duplicates the root analyze
  stage (~16 s); kept for per-package failure attribution.
- build_runner 2.15's `--workspace` single-invocation mode is not used; the
  per-package plan is unit-tested and names the failing package.
- `data_secure` is wired in `AppDependencies` but no feature consumes it
  yet - it demonstrates the kind and the invariant-4 home; the first feature
  with a secret receives it through its module factory.
- The settings failure banner has no dismissal path (stays until the stored
  value actually changes) - product decision.
- Codex hooks depend on per-checkout trust (`/hooks`); CI runners and fresh
  clones are unprotected by the hook until trusted - the cold-rebuild
  freshness gate is the enforcement of record for invariant 5.
- The Stop-hook review gate is documented as opt-in hardening, not wired.
- `guard_generated.sh` reads the first `file_path` of a Claude payload and
  parses patch headers only for `apply_patch`; a JSON parser would be
  exact, but bash + sed keeps the hook dependency-free.
- Both agent-side guards bind tools, not the shell. `guard_generated.sh`
  fires on `Edit`/`Write`/`apply_patch`, so a generated file rewritten from
  Bash (`sed -i`, `cat >`) slips past it - the cold-rebuild
  codegen-freshness stage is the enforcement of record. Likewise the
  `Read(/.dart-defines/*.env)` deny in `.claude/settings.json` binds
  Claude's `Read` tool only (a shell `cat` is not covered, and Codex has no
  equivalent); the secret-leak scan plus the never-in-repo rule are the
  backstops.
