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

Two AI agents work this repo in fixed roles: **Claude Code implements**
(writes the graph diff, the code, every layer of tests, runs the gate),
and **OpenAI Codex cross-reviews** (a second, independent, read-only pass
over every diff before it counts as done). A human sits at exactly two
checkpoints in that loop — approving the dependency-graph diff before
implementation starts, and performing the behavioral check on UI-affecting
changes — everything else is tools or agents. The full ritual is in
[`docs/workflow/feature-workflow.md`](docs/workflow/feature-workflow.md).

The repo you are looking at is not template output rendered by a separate
generator — it is a fully working, buildable, analyzable Flutter project
today, complete with one worked example feature (`feature_settings`,
theme-mode selection) that crosses every architectural layer end to end.

## Quick start

1. Click **Use this template** on GitHub.
2. Give the copy its own identity (replaces the `alatyr_starter` /
   `dev.alatyr` / `Alatyr Starter` placeholder throughout the repo — lands
   in M5):
   ```bash
   dart run tool/init.dart --name my_app --org com.example
   ```
3. Resolve dependencies and run the gate:
   ```bash
   fvm flutter pub get
   tool/checks.sh
   ```

See [`docs/workflow/getting-started.md`](docs/workflow/getting-started.md)
for prerequisites, running the app, and the one-time agent trust steps.

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
├── tool/              # tool/checks.sh — the one quality gate, locally and in CI
├── test/              # fixture tests for the toolchain itself
├── docs/              # architecture, ADRs, testing, workflow, reference
└── .claude/ .codex/   # hooks, rules, skills, review config for both agents
```

## Documentation

- [`docs/README.md`](docs/README.md) — the full documentation index:
  architecture, ADRs, testing strategy, workflow, reference.
- [`docs/workflow/maintenance.md`](docs/workflow/maintenance.md) — pin
  update cadence (Flutter, the codegen ceiling, patrol, the Codex model)
  and the upgrade checklist. Survives instantiation.

## License

MIT — see [`LICENSE`](LICENSE).
