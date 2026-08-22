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
3. Run a template smoke once `tool/init.dart` exists (M5): instantiate a
   fixture copy and run the gate on it too — a Flutter bump can shift
   generated output in ways only a real `init` run surfaces.

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
Only `patrol_finders 3.6.0` is pinned today (the widget-test half, already
in use); `patrol` itself (the e2e binary + `patrol_cli`) is added in M5.
When M5 lands, pin all three together and re-verify the compatibility
table — patrol's finder API and its e2e runner version in lockstep.

## Codex model and CLI

- **Model pin:** `review_model` in `.codex/config.toml`, read by
  `.claude/skills/cross-review/codex_review.sh`. When Codex rejects the
  pinned model (deprecated, renamed), update it in that one file — both
  the CLI review and Codex cloud PR review pick it up.
- **CLI version:** `0.144.x` — the hook schema, `--output-schema`, and the
  `-c key=value` override flags this template relies on were verified
  against that line. Re-verify `.codex/hooks.json`'s schema and the
  `codex_review.sh` flags after any major/minor CLI bump before trusting
  its output again.

## Claude Code

Hooks and path-scoped rules (`.claude/settings.json`, `.claude/rules/`)
were verified against Claude Code `2.1.x`. Re-check hook payload shapes
and rule-loading behavior (`paths:` frontmatter) after a major bump.

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

## Running an upgrade

1. Bump the pin (Flutter, a package constraint, the Codex model, or a CLI
   version).
2. `fvm flutter pub get`.
3. `tool/checks.sh` (full gate).
4. Fix whatever the gate surfaces.
5. Record what changed and why in this file, next to the relevant
   section, so the next upgrade starts from the same evidence instead of
   re-deriving it.
