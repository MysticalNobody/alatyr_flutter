# Carryover into M4/M5 planning (from M3)

Obligations that survived M3. The M4 and M5 plans MUST pick these up; delete
entries as they land.

## M4 (agent harness)

- `docs/workflow/getting-started.md` must cover: first `flutter test` of
  data_local downloads sqlite3's prebuilt library through the package's Dart
  hook (network once, cached under `.dart_tool/hooks_runner/`); Apple targets
  need `keychain-access-groups` entitlements (shipped for macOS); Linux needs
  `libsecret-1-dev` + a secret service for data_secure.
- `docs/workflow/maintenance.md` owns the codegen-stack ceiling: freezed
  3.2.5 caps `analyzer <11`, which holds drift_dev at 2.34.0 and build_runner
  at 2.15.1 workspace-wide; re-check on every freezed release.
- `docs/testing/widget-test-guardrails.md`: the patrol `#` selector maps to
  `ValueKey<String>` only; `BlocProvider(create:)` is lazy; dispose a
  per-test `GoRouter` in `tearDown`; adapter methods over plugins are `async`
  so sync throws become rejected futures.
- `.claude/rules/widgets.md`: `AppChoiceTile` requires its key; document the
  `settings.*` namespace pattern as the template for new features.
- `docs/testing/widget-test-guardrails.md` (the FakeAsync rules, verified in
  M3's plan challenge): never await, via `tearDown`/`addTearDown`, a future
  whose completion depends on objects created inside a `testWidgets` body
  (`Bloc.close()`, `StreamController.close()`, drift `close()`) — let the
  tree own blocs, use `unawaited(...)` closes; never `await` a drift-backed
  stream (`.first`, `await for`) inside the body — assert through `read()`;
  drift schedules a zero-duration timer when a watch subscription is
  cancelled, so drift-backed widget tests end with an explicit unmount +
  `pump(Duration.zero)`.
- `docs/workflow/getting-started.md`: web persistence needs drift's
  `sqlite3.wasm` + `drift_worker.js` next to `index.html` (M5 ships them);
  Apple platforms ship `keychain-access-groups` with an empty array - put
  the App Group name into it when App Groups are enabled.
- `docs/architecture/02-package-graph.md`: `banned_packages` governs direct
  pubspec declarations and imports only; transitive presence of a banned
  package through a canonical package is allowed by design (`provider` sits
  in the root `pubspec.lock` transitively via `flutter_bloc` — no workspace
  member declares or imports it, so the graph rules are unaffected).

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
