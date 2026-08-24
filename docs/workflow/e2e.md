# Patrol e2e (`tool/e2e.sh`)

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
  command to run. See `docs/workflow/maintenance.md` for the pin's
  upgrade rules.
- **Exit codes:** `0` every test passed; patrol's own non-zero exit on
  test failures/errors; `2` usage; `3` e2e not performed (reason on
  stderr — report it verbatim, never fabricate a result); `124`
  (`gtimeout`/`timeout`) or `142` (the bare-macOS `perl`-alarm fallback,
  SIGALRM) when the hard wall-clock guard kills a hung run.
- **Disk:** a local `patrol test`, like `flutter build`, leaves
  0.5–2 GB under `app/build` — delete it after each proof step.

See [`docs/reference/critical_flows.md`](../reference/critical_flows.md)
for the registered flow this drives.
