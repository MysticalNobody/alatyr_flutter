# Instantiation (`tool/init.dart`)

Template-repo only: this checkout already carries the placeholder identity
(`alatyr_starter` / `dev.alatyr` / `Alatyr Starter`) that this command
rewrites into yours. Skip this doc once you have run it — the command
deletes itself as its last step.

```bash
fvm install   # once; init's own pub get and gate run need the pinned SDK
fvm dart run tool/init.dart --name my_app --org com.example \
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

Needs a git checkout (`git ls-files` enumerates what to rewrite) — "Use
this template" and `tool/template_smoke.sh` both give you one; a plain
archive download does not, and the tool says so. If something looks wrong
before you commit the result, recover with `git checkout -- . && git
clean -fd`.

## Next

[`docs/workflow/getting-started.md`](getting-started.md) picks back up at
the first gate run.
