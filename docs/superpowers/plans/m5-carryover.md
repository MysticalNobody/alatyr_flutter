# Post-M5 backlog

M5 is the last milestone in the spec's phased plan (§16): this file
replaces `m4-carryover.md`, which is fully closed by Tasks 1-7. Nothing
below blocks the spec's "implementation complete (M5 done)" status; each
item is either a deliberate acceptance or a genuine follow-up worth
picking up during future feature work or a `docs/workflow/maintenance.md`
upgrade pass.

## Open

- **`e2e.yml` on hosted runners is unverified** — advisory
  (`continue-on-error: true`) until it is green on a handful of real PRs
  (spec §15 risk 5); flip it to a required check once it has that track
  record.
- **iOS e2e in CI** — `tool/e2e.sh ios` is local-only today; a macOS
  runner job is unscheduled (cost and macOS-runner-minutes budget, not a
  technical blocker).
- **Web runtime smoke as an automated check** — `tool/web_smoke.sh`
  proves persistence locally with headless Chrome but is not wired into
  any CI workflow; consider a `template-smoke.yml`-style job once
  headless-Chrome-on-CI cost/flakiness is weighed.
- **`patrol` dev dependency vs release builds** — `patrol`/
  `patrol_finders` are `dev_dependencies` in `app/pubspec.yaml`; verify a
  real `flutter build` (release, every platform) actually excludes them
  from the shipped binary rather than trusting the pubspec section alone.
- **`android.builtInKotlin=true` with patrol 4.9** — `app/android/gradle.properties`
  keeps it `false` (the Flutter-template default); patrol's Gradle
  integration with the newer built-in-Kotlin path is unverified and worth
  a compatibility pass before flipping it.
- **Codex `/hooks` trust on CI** — CI runners start untrusted for Codex
  hooks by construction (no interactive `/hooks` step); if Codex ever runs
  unattended in a workflow, the codegen-freshness gate remains the
  backstop, but this deserves a deliberate design pass rather than being
  an accident of omission.
- **`AppDatabase.open`'s web `onResult` logging** — drift's web open path
  can report which storage implementation it actually chose (`opfsLocks`
  vs `sharedIndexedDb`); `packages/data_local` does not log it today, so a
  silent fallback to the slower backend is invisible outside the browser
  console.
- **`formatChangedDart` on an empty changed-files list** (T5 review
  minor): passing zero paths runs `dart format` with no arguments at all,
  which formats the whole working tree rather than doing nothing, and can
  surface a non-zero (`64`) exit only after `runInit`'s destructive
  rewrite/delete step has already run — there is no guard for a
  degenerate rename that touches no Dart files.
- **`--name` colliding with an existing workspace member** (T5 review
  minor): `validateTarget` checks the name is a legal Dart identifier but
  never checks it against `design_system`, `data_local`, etc.; a
  collision would surface later, mid-rewrite, instead of up front as a
  clean usage error.
- **`init` has no rollback hint** (T5 review minor): a failed or
  interrupted run leaves a partially rewritten tree with no built-in
  "undo"; the recovery path is the ordinary git one —
  `git checkout -- . && git clean -fd` — but the tool does not say so on
  failure.
- **Codex PostToolUse payload extractor assumes `tool_response` is the
  last JSON key** (T6 review minor): `tool/hooks/format_dart.sh`'s
  `apply_patch` branch greps for "Updated the following files:" rather
  than parsing JSON structure; a future Codex payload shape that reorders
  keys or nests the file list differently would silently stop matching.
- **`template_smoke.sh`'s `DEVELOPMENT_TEAM` check is path-coupled** (T6
  review minor): it greps `app/ios/Runner.xcodeproj/project.pbxproj`
  directly; if a future Xcode or Flutter template moves signing config
  elsewhere (an `.xcconfig`, a workspace settings file), the check passes
  silently instead of failing loud.
- **`PATROL_CLI_VERSION` pinned in two places** (T6 review minor):
  `tool/e2e.sh` and `.github/workflows/e2e.yml` each hardcode the same
  version literal with no single source of truth between them (unlike the
  Codex model pin, which lives in exactly one file); a bump that updates
  one and forgets the other fails quietly until the next e2e run.

## Recorded as accepted (no action planned)

- The e2e flow's two-test coupling: the fresh-process bonus test is
  meaningless run alone and relies on patrol's per-test process boundary
  and on run order (Android declaration order, iOS alphabetical selector
  order — the test names are chosen to make both agree); documented in
  the test header, the critical-flows registry, and `testing/strategy.md`
  rather than engineered away. A future patrol relaunch API would let the
  flow collapse into one test.
- `templateOnlyPaths` (`tool/src/init_rewrite.dart`) is a fixed list, not
  a discovery mechanism: a template-only file added later without
  updating that list survives `init` uncaught by anything except
  `tool/template_smoke.sh`'s own post-init assertions, which only check
  the paths already known to matter.
- The `xcodeproj`-scripted `RunnerUITests` target lives in the iOS
  project as committed data (`app/ios/Runner.xcodeproj/project.pbxproj`);
  the Ruby script that generated it is not shipped — regenerating the
  target structure from scratch (a Flutter/Xcode upgrade that resets the
  pbxproj) needs the script rewritten, not just re-run.
- Carried from M1/M2 reviews: deferred minors triaged OK-TO-DEFER at the
  M1 final review (cosmetics, report noise, symmetric-code coverage gaps
  — see the M1 branch reviews in git history); the import lexer has no
  explicit recursion cap on interpolation nesting (bounded by real source
  shape) and malformed-paren directive bodies degrade to an EOF-bounded
  scan.
- Per-member `dart analyze` in the full tier duplicates the root analyze
  stage (~16 s); kept for per-package failure attribution.
- build_runner 2.15's `--workspace` single-invocation mode is not used;
  the per-package plan is unit-tested and names the failing package.
- `data_secure` is wired in `AppDependencies` but no feature consumes it
  yet - it demonstrates the kind and the invariant-4 home; the first
  feature with a secret receives it through its module factory.
- The settings failure banner has no dismissal path (stays until the
  stored value actually changes) - product decision.
- Codex hooks depend on per-checkout trust (`/hooks`); CI runners and
  fresh clones are unprotected by the hook until trusted - the
  cold-rebuild freshness gate is the enforcement of record for
  invariant 5.
- The Stop-hook review gate is documented as opt-in hardening, not wired.
- `guard_generated.sh` reads the first `file_path` of a Claude payload and
  parses patch headers only for `apply_patch`; a JSON parser would be
  exact, but bash + sed keeps the hook dependency-free.
- Both agent-side guards bind tools, not the shell. `guard_generated.sh`
  fires on `Edit`/`Write`/`apply_patch`, so a generated file rewritten
  from Bash (`sed -i`, `cat >`) slips past it - the cold-rebuild
  codegen-freshness stage is the enforcement of record. Likewise the
  `Read(/.dart-defines/*.env)` deny in `.claude/settings.json` binds
  Claude's `Read` tool only (a shell `cat` is not covered, and Codex has
  no equivalent); the secret-leak scan plus the never-in-repo rule are
  the backstops.
