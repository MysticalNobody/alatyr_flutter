# Maintenance

This file survives `tool/init.dart` (it is not template-development-only
history) — a consumer's copy of Alatyr keeps it and its update cadence.

## Flutter

Bump the version in `.fvmrc`, then:

1. Re-validate the `analysis_server_plugin` pin (currently `0.3.20`,
   exact) against the new Flutter's bundled analyzer/SDK — it has hang
   history (`dart-lang/sdk#63538`, fixed in `0.3.20`; versions 0.3.15–19
   regressed it). If the new Flutter needs a different pin, update
   `lints/pubspec.yaml`'s exact constraint and re-run the lint-plugin
   stage of the gate.
2. Run the full gate: `tool/checks.sh`.
3. Template repo only (init deletes the script — instantiated copies
   skip this step): `tool/template_smoke.sh` instantiates a fixture copy
   and runs the gate on it too — a Flutter bump can shift generated
   output in ways only a real `init` run surfaces.
4. Re-run `tool/e2e.sh` on both platforms it can reach locally — a
   Flutter bump can shift patrol/emulator behavior independently of the
   unit-test gate.

## Android `compileSdk 37`

`app/android/app/build.gradle.kts` pins `compileSdk = 37`, above
Flutter 3.44.9's own `flutter.compileSdkVersion` default of 36:
`flutter_secure_storage 11` ships AAR metadata that requires it.
`app/android/gradle.properties` sets
`android.suppressUnsupportedCompileSdk=37.0` to silence AGP 9.0.1's
warning that it has only validated compile SDKs up to 36.1 — by design,
not a bug to fix. Building against `compileSdk 37` needs the
`platforms;android-37` SDK component installed locally (see
`docs/workflow/getting-started.md`, Prerequisites); this is independent
of whatever system image `tool/e2e.yaml` pins for the emulator (`34`
today). Revisit this pin on every Flutter bump: once
`flutter.compileSdkVersion` reaches 37, both the explicit `compileSdk`
line and the `suppressUnsupportedCompileSdk` override can be dropped.

## The codegen ceiling

`freezed 3.2.5` caps `analyzer` at `<11`, which in turn holds `drift_dev`
at `2.34.0` and `build_runner` at `2.15.1` (see `pubspec.lock`). Re-check
this ceiling on every `freezed` release: `flutter pub outdated` will nag
about `drift_dev`/`build_runner` being behind — that nag is expected and
should not be "fixed" by force-bumping past the ceiling; bump `freezed`
first, see whether its `analyzer` constraint relaxed, then let
`drift_dev`/`build_runner` follow.

## patrol / patrol_cli coupling

Verified against pub.dev and the patrol compatibility table on
2026-08-21: `patrol 4.9.0` ↔ `patrol_cli 4.7.0`, minimum Flutter `3.32`.
All three are pinned together: `patrol_finders 3.6.0` and `patrol 4.9.0`
in `app/pubspec.yaml`, `patrol_cli 4.7.0` as the global activation
`tool/e2e.sh` checks for at run time. The `patrol_cli` version itself is
pinned once, as `PATROL_CLI_VERSION` in `tool/e2e.sh` (checked against
`patrol --version`). Re-verify the full compatibility table on any bump —
patrol's finder API and its e2e runner version in lockstep.

Two release/toolchain assumptions remain deliberately unclaimed:

- `patrol` and `patrol_finders` are `dev_dependencies`, but their exclusion
  from shipped artifacts has not been proved by classification alone. Before
  a release, build every supported platform in release mode and inspect the
  artifacts/dependency graph.
- Keep `android.builtInKotlin=false`. Patrol 4.9's Gradle integration with
  Flutter's built-in-Kotlin path is unverified; flip it only after an Android
  e2e compatibility pass.

## Codex model and CLI

- **Model pin:** `review_model` in `.codex/config.toml`, read by
  `.claude/skills/cross-review/codex_review.sh`. When Codex rejects the
  pinned model (deprecated, renamed), update it in that one file — both
  the CLI review and Codex cloud PR review pick it up.
- **Model access:** the pinned model is served per account tier; if
  `codex` rejects it on your plan, the DoD-4 waiver path applies until
  the pin is updated here.
- **CLI version:** `0.144.x` — the hook schema, `--output-schema`, and the
  `-c key=value` override flags this template relies on were verified
  against that line. Re-verify `.codex/hooks.json`'s schema and the
  `codex_review.sh` flags after any major/minor CLI bump before trusting
  its output again.

## Release builds

Verified 2026-08-24 (Flutter 3.44.9, `fvm flutter build apk --release`):
`patrol`/`patrol_finders` are fully absent from the release APK — zero
references in `classes.dex`, no patrol native library. `libdartjni.so`
in the APK belongs to `path_provider_android` (a production transitive),
not patrol. Re-verify after a patrol or Flutter bump. The desktop shells
(`linux/`, `windows/`, `macos/`) ship identity-rewritten but unverified:
no gate stage builds them, so the first desktop build is the consumer's
own proof step.

## Claude Code

Hooks and path-scoped rules (`.claude/settings.json`, `.claude/rules/`)
were verified against Claude Code `2.1.x`. Re-check hook payload shapes
and rule-loading behavior (`paths:` frontmatter) after a major bump.

## Agent-hook payloads

The generated-file guard deliberately stays dependency-free. For Claude it
uses the first `file_path` (the tool input precedes user content); for Codex it
parses `apply_patch` headers. Unknown shapes fail open. The Codex formatter
similarly scans from `Updated the following files:` to the end of
`tool_response` instead of decoding JSON, assuming that response remains the
last key. Reordering or nesting can silently stop automatic formatting, so
rerun the hook fixtures after either CLI changes its payload.

These hooks bind Edit/Write/`apply_patch`, not shell rewrites such as `sed -i`
or redirection. They are fast feedback only: the full gate's cold codegen
rebuild plus snapshot comparison is the enforcement of record, and its format
stage catches a formatter hook that stopped matching.

## The `provider`-via-`flutter_bloc` transitive note

`provider` (banned in `docs/reference/package_graph.yaml` — bloc is the
canonical state-management choice, not `provider`) appears in
`pubspec.lock` as a transitive dependency of `flutter_bloc` itself, which
uses it internally for `BlocProvider`'s `InheritedWidget` plumbing.
`tool/verify_dependencies.dart` checks each pubspec's own declared
`dependencies`/`dev_dependencies`, not the resolved transitive closure —
so this is expected and not a violation. Do not "fix" it by vendoring
around `flutter_bloc`, and do not read `provider`'s presence in the
lockfile or `flutter pub deps` output as a banned-package hit.

## Web assets

`app/web/sqlite3.wasm` and `app/web/drift_worker.js` are binaries drift
needs at runtime for web persistence — not npm/pub packages, so they are
committed as-is rather than fetched at build time.

- `sqlite3.wasm` comes from the `sqlite3.dart` GitHub release matching
  `pubspec.lock`'s `sqlite3` version (currently `3.5.2`):
  `https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/sqlite3.wasm`,
  sha256
  `13d3f11d05b39ba0618a7115fb41640a5d48b6300f5d3f325f554b42bd6688a4`.
- `drift_worker.js` comes from the `drift` GitHub release matching
  `pubspec.lock`'s `drift` version (currently `2.34.3`):
  `https://github.com/simolus3/drift/releases/download/drift-2.34.3/drift_worker.js`,
  sha256
  `4db0469de8ceabad8d5cd3d920614486ba587e100e39523f36f704a3aec5f26c`.

Refresh both files (and the hashes recorded above) whenever either
package is bumped in `pubspec.lock`; verify each download's sha256 before
committing.

## Running an upgrade

1. Bump the pin (Flutter, a package constraint, the Codex model, or a CLI
   version).
2. `fvm flutter pub get`.
3. `tool/checks.sh` (full gate).
4. `tool/template_smoke.sh` if the bump could shift generated output
   (Flutter, `init.dart` itself; template repo only — init deletes it);
   `tool/e2e.sh` on whatever platforms are reachable locally if the bump
   touches patrol, `patrol_cli`, or the Android/iOS toolchain;
   `tool/web_smoke.sh` if it touches drift, `sqlite3`, or `app/web/`
   assets.
5. Fix whatever the gate, the smoke, or e2e surfaces.
6. Record what changed and why in this file, next to the relevant
   section, so the next upgrade starts from the same evidence instead of
   re-deriving it.
