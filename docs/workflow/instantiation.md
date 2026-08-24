# Instantiation (`tool/init.dart`)

Template-repo only: this checkout already carries the placeholder identity
(`alatyr_starter` / `dev.alatyr` / `Alatyr Starter`) that this command
rewrites into yours. The command deletes this page and itself during the run,
so their absence after instantiation is intentional.

```bash
fvm install   # once; init's own pub get and gate run need the pinned SDK
fvm dart run tool/init.dart --name my_app --org com.example \
  [--display-name "My App"] [--template-url <url>] [--yes]
```

`--name` is a lowercase Dart package identifier beginning with a letter;
`--org` is a reverse domain with at least two lowercase letter/digit segments,
each beginning with a letter (no underscores); reserved Dart, Java, Flutter,
Windows, and existing workspace names are rejected. `--display-name` defaults
to title-casing the package name (`my_app` → `My App`) and accepts ASCII
letters, digits, spaces, dots, and hyphens. These restrictions are deliberate:
the values land unescaped in Dart, XML, JSON, YAML, C++, and Windows resource
files. A product needing another character set, or a later identity change,
updates its platform shells manually after this one-shot command.

Prints the rename plan and asks to confirm (skip with `--yes`), then:
rewrites the identity everywhere it legitimately appears (`app/`, native
shells, the root `pubspec.yaml`, `docs/reference/package_graph.yaml`,
`README.md`) — Android/Linux/web get the snake-case bundle id
(`org.name`), iOS/macOS the camelCase one (`org.nameCamel`, no
underscores; Apple bundle ids forbid them); deletes itself and its tests using
`templateOnlyPaths` in `tool/src/init_rewrite.dart`; runs `dart format` on
what it touched, then `dart pub get` and `tool/checks.sh --fast`. `docs/adr/`
is never rewritten — see ADR-0006 for the full rationale.
An identity that reuses one of the template's own tokens is refused
before anything is touched (exit 2): the same org, an org extending it
(`dev.alatyr.apps`), the template's package or display name. The rewrite
replaces whole tokens and then scans for leftovers, so such a target
would either double an identifier or report a survivor that is really
the identity you asked for. `--template-url` overrides the backlink in the generated `README.md`
(default: the canonical template repository URL);
`--print-identity` prints the placeholder tokens as `KEY='value'` lines
instead of instantiating, for scripts that must not spell them
(`tool/template_smoke.sh`).

`templateOnlyPaths` is an explicit maintenance list, not discovery. Every new
tracked template-only artifact must be added there; the smoke reads that same
list and only verifies its entries, so an omitted path survives init silently.
Template-machinery prose inside a doc that itself survives is wrapped in
whole-line `<!-- template-only:begin -->` / `<!-- template-only:end -->`
markers (today: the Instantiation section of `getting-started.md` and this
page's entry in `docs/README.md`): init removes the whole block, markers
included, before token replacement — a block left to the token pass would
come out calling the new identity "the placeholder". Markers must pair up
and sit on their own lines; imbalance, an inline marker, or a typo'd
variant (anything else containing `template-only:begin/end`) aborts the
run. `docs/adr/` is never stripped (nor rewritten). This page may quote
the markers only because init deletes it before the rewrite pass.
The smoke's signing check is also intentionally concrete: it looks for
`DEVELOPMENT_TEAM` in `app/ios/Runner.xcodeproj/project.pbxproj`. After a
Flutter/Xcode layout change, update the check to the new canonical signing
source or fail on the unknown layout — a move into an `.xcconfig` or workspace
setting must not turn into a false pass.

Needs a **clean** git checkout (`git ls-files` enumerates what to
rewrite) — "Use this template" and `tool/template_smoke.sh` both give you
one; a plain archive download does not, and the tool says so. A dirty
worktree is refused (exit 2) before anything is touched: the recovery
command below discards uncommitted work, and refusing up front is what
makes it safe to suggest at all. If something looks wrong before you
commit the result, recover with `git checkout -- . && git clean -fd`.

## Next

[`docs/workflow/getting-started.md`](getting-started.md) picks back up at
the first gate run.
