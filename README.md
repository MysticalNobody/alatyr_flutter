# Alatyr

A hardened Flutter starter for AI-agent development — a GitHub template
repository, not a library.

## What this is

Alatyr's core bet is **hardness**: every architectural rule this repo
states is machine-enforced, not merely written down. A dependency graph in
one YAML file drives three independent checkers (a pubspec validator, an
import scanner, and a first-party analyzer plugin), so "the code follows
the architecture" is a fact `tool/checks.sh` proves in seconds, not a
review-time hope. Generated code, secrets placement, and test-type
coverage all have the same property: a tool checks them, or the review
rubric names them explicitly — nothing here relies on an agent remembering
a rule from a prompt.

Either **Claude Code or OpenAI Codex implements**: writes the graph diff,
the code, every layer of tests, and runs the gate. **The other agent
cross-reviews** the committed task diff in an independent, read-only pass
before it counts as done. Claude discovers `.claude/skills/cross-review/`
and dispatches Codex; Codex discovers `.agents/skills/cross-review/` and
dispatches Claude through `tool/claude_review.sh`. Both workflows save the
starting commit before edits and pass it as `--base` after committing.
A human approves the dependency-graph diff before implementation starts
and performs the behavioral check on UI-affecting changes. A human also
decides any explicit waiver when an external reviewer cannot run.
The full ritual is in
[`docs/workflow/feature-workflow.md`](docs/workflow/feature-workflow.md).

The repo you are looking at is not template output rendered by a separate
generator — it is a fully working, buildable, analyzable Flutter project
today, complete with one worked example feature (`feature_settings`,
theme-mode selection) that crosses every architectural layer end to end.
It is a clean-room implementation: earlier ReviDeck work informed the
architecture, but no ReviDeck code or product artifacts were carried over.

## Quick start

1. Click **Use this template** on GitHub.
2. Install the pinned toolchain, then give the copy its own identity
   (replaces the `alatyr_starter` / `dev.alatyr` / `Alatyr Starter`
   placeholder throughout the repo):
   ```bash
   fvm install
   fvm dart run tool/init.dart --name my_app --org com.example
   ```
   One-shot and self-deleting: it prints the rename plan, asks to confirm
   (skip with `--yes`), then rewrites the identity, deletes the init
   machinery and its tests, and runs `dart pub get` + `tool/checks.sh --fast`
   for you.
3. Commit the result, then run the full gate:
   ```bash
   tool/checks.sh
   ```

See [`docs/workflow/getting-started.md`](docs/workflow/getting-started.md)
for prerequisites, running the app (including the patrol e2e runner and
the web runtime smoke), and the one-time agent trust steps.

## What's inside

```
alatyr_flutter/
├── AGENTS.md          # canonical agent contract (agents.md standard)
├── CLAUDE.md          # @AGENTS.md import + Claude-specific notes
├── app/               # the single app shell (working placeholder)
├── packages/
│   ├── app_core/              # base, pure Dart: Result, AppFailure, logging
│   ├── app_config/            # base, pure Dart: typed config from dart-defines
│   ├── design_system/         # base, Flutter: theme, tokens, base widgets
│   ├── data_local/              # base, Flutter: drift database + KV DAO
│   ├── data_secure/             # base, Flutter: secure storage port + impl
│   ├── feature_settings_api/   # feature_api: contracts only
│   └── feature_settings/       # feature_impl: bloc, screen, repository, module
├── lints/             # first-party analyzer plugin (not a workspace member)
├── tool/              # tool/checks.sh — the one quality gate (ADR-0004)
├── test/              # fixture tests for the toolchain itself
├── docs/              # architecture, ADRs, testing, workflow, reference
└── .claude/ .codex/ .agents/ # hooks, rules, skills, review config for both agents
```

## Documentation

- [`docs/README.md`](docs/README.md) — the full documentation index:
  architecture, ADRs, testing strategy, workflow, reference.
- [`docs/workflow/maintenance.md`](docs/workflow/maintenance.md) — pin
  update cadence (Flutter, the codegen ceiling, patrol, reviewer models)
  and the upgrade checklist. Survives instantiation.

## License

MIT — see [`LICENSE`](LICENSE).
