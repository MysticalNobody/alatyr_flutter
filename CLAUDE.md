@AGENTS.md

# Claude Code notes

- **Skills (repo-level, `.claude/skills/`):** `/cross-review [base-ref]`
  after the gate is green and before declaring a task done (DoD 4);
  `/adversarial-tests <feature_api package dir> [feature impl dir]` after
  the first green implementation of new behaviour (DoD 2). Both read
  AGENTS.md themselves — do not paraphrase the rubric into prompts.
- **Hooks (`.claude/settings.json`):** a PreToolUse hook blocks `Edit`/
  `Write` on `*.g.dart`, `*.freezed.dart`, `*.drift.dart` — when it fires,
  change the source and run `tool/codegen.sh`; a PostToolUse hook runs
  `dart format` on every Dart file you edit, so the format stage stays
  green without extra commands.
- **Permissions:** `Read` of `.dart-defines/*.env` is denied; only the
  committed `*.env.example` files are yours to read.
- **Rules:** path-scoped conventions load automatically from
  `.claude/rules/` (testing, widgets, codegen) when you touch matching
  files.
- **Start at the repository root.** Project settings (hooks, permissions)
  and this file load only from the directory the session starts in; a
  session started in `app/` has neither the hooks nor the deny rule.
- **Toolchain:** `fvm flutter` / `fvm dart`. Lint-plugin diagnostics only
  surface under `dart analyze` (sdk#63787); `flutter analyze` is not the
  gate's analyzer.
- **Subagents:** `test-breaker` (`.claude/agents/`) generates adversarial
  scenarios from a fresh context; `codex-reviewer` wraps the cross-review
  script for workflows. Neither edits files.
- Every completion report ends with **Remaining risks**.
- `CLAUDE.local.md` (gitignored) is the personal-overrides file.
