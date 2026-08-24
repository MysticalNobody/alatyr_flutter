# Patrol e2e (`tool/e2e.sh`)

```bash
dart pub global activate patrol_cli 4.7.0   # <-> patrol 4.9.0 in app/pubspec.yaml
tool/e2e.sh android                         # or ios; --device <id>, --list, -t <file>
```

- **Devices** are found-or-created from the declarative spec in
  `tool/e2e.yaml`: Android AVD `e2e_pixel` (`pixel_7` profile, API 34, the
  arm64 or x86_64 system image per host architecture), iOS simulator
  `e2e_iphone` on an `iPhone 16`, matched to the newest installed "iOS
  26.x" runtime by major version (an exact `26.0` runtime is rarely what a
  dev machine has). No "first available device" fallback — a running
  emulator is reused only if it IS the declared AVD. `E2E_EMULATOR_PORT`
  (default `5554`) picks a different console port when that one is busy.
- **`patrol_cli`** must match the version pinned in `tool/e2e.sh` (checked
  against `patrol --version`); a mismatch fails with the exact activate
  command to run. See `docs/workflow/maintenance.md` for the pin's
  upgrade rules.
- **Exit codes:** `0` every test passed; patrol's own non-zero exit on
  test failures/errors; `2` usage; `3` e2e not performed (reason on
  stderr — report it verbatim, never fabricate a result); `124`
  (`gtimeout`/`timeout`) or `142` (the bare-macOS `perl`-alarm fallback,
  SIGALRM) when the hard wall-clock guard kills a hung run.
- **Xcode 26 summary quirk:** `patrol_cli` 4.7.0 cannot parse the new
  Xcode's console stream: on iOS 26.x its summary prints `Total: 0` even
  though every test ran — the run's `.xcresult` records them and the exit
  code stays truthful. Trust the exit code and the `.xcresult`; re-check
  on the next patrol/patrol_cli bump.
- **Disk:** a local `patrol test`, like `flutter build`, leaves
  0.5–2 GB under `app/build` — delete it after each proof step.

On iOS 26.2/Xcode 26.2, `patrol_cli 4.7.0` may print blank progress and a
`Total: 0` summary even when the run succeeded; the generated `.xcresult`
records the tests and the process exit code remains authoritative. Check both,
and re-verify the console summary on the next patrol/patrol_cli bump.

The iOS `RunnerUITests` target is committed directly in
`app/ios/Runner.xcodeproj/project.pbxproj`. Its one-off Ruby/xcodeproj
generator is not shipped. If a Flutter or Xcode regeneration replaces that
project structure, recreate the target from Patrol's current setup guidance or
write a new generator — there is no retained script to rerun.

See [`docs/reference/critical_flows.md`](../reference/critical_flows.md)
for the registered flow this drives.
