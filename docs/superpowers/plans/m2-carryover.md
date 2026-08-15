# Carryover into M2/M3 planning (from M1 reviews and the Codex cross-review)

Obligations that survived M1's final review and the post-review Codex round.
The M2 and M3 plans MUST pick these up; delete entries as they land.

## M2 (lint plugin + gate evolution)

- Opportunistic: fixture for the `pure_dart_packages`-lists-unknown-package
  loader branch (currently code-only coverage).
- `sdk#63787`: one-shot `flutter analyze` may miss plugin diagnostics -
  scanners are the floor (documented in `checks.sh` comment).

## M3 (example slice) tripwires

- Wrap `build_runner` invocations in a `CHECKS_CODEGEN_TIMEOUT` guard
  (`tool/common.sh` only guards analyze/test today).
- Widen import-scan scope to `bin/`, `example/`, `integration_test/` when the
  app shell lands (banned-package rule currently sees only `lib/` + `test/`).
- Extend `analysis_options.yaml` excludes for any new unresolvable fixture
  trees.

## Recorded as accepted (no action planned)

- Deferred minors triaged OK-TO-DEFER at the M1 final review (cosmetics,
  report noise, symmetric-code coverage gaps) — see git history of the M1
  branch reviews.
- Lexer: no explicit recursion cap on interpolation nesting (bounded by real
  source shape); malformed-paren directive bodies degrade to EOF-bounded scan.
