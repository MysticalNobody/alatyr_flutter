# ADR-0005: Cross-review protocol

**Status:** accepted (amended 2026-09-04)
**Date:** 2026-08-13

## Context

A single agent reviewing its own diff shares its own blind spots. The
template needs an independent reader before work counts as done, without
turning that reader into a second implementer or a silent gate that can
be routed around. Implementers may use either Claude Code or Codex.

## Decision

The implementer dispatches the other agent as reviewer: Claude Code uses
`.claude/skills/cross-review/codex_review.sh`; Codex discovers
`.agents/skills/cross-review/SKILL.md` and uses `tool/claude_review.sh`.
Both workflows pass an explicit `--base` saved from `git rev-parse HEAD`
before task edits; runners require a clean tree and a non-empty committed
diff. A dirty tree or missing, invalid, or empty scope is recoverable;
fix it and retry.

The reviewer evaluates `## Code Review Rules` in `AGENTS.md`. Every P0/P1
finding is fixed or explicitly rebutted with reasoning in the task report,
and the verdict is quoted verbatim. If a reviewer CLI, authentication, or
model failure prevents review, only the human can explicitly waive DoD 4.
Cross-review remains part of the Definition of Done, not a default Stop
hook. The rubric is shared; reviewer-only restrictions live in skills and
runners so either agent can still implement ordinary tasks.

Codex runs in its read-only sandbox with an ephemeral session. Claude
runs with only Read/Grep/Glob, `dontAsk`, skills/MCP/hooks disabled, and no
session persistence; these are CLI tool restrictions, not an OS sandbox.
Codex's model is configured in `.codex/config.toml`; Claude's model is in
`.claude/review-model` (default `sonnet`, a moving alias). Both runners
offer text output and structured output using `.codex/review-schema.json`.

Both runners require `--base`. Codex reports invalid or empty scopes with
exit 2; Claude uses exit 3. Either requires correcting the scope, never a
review waiver.

## Consequences

Teams can choose their implementer while retaining an independent review
and one rubric. Claude's JSON envelope is validated with Node >= 20 before
the runner publishes a result. Reviewer configuration and compatibility
need maintenance for both CLIs. A task can still be declared done without
review having run; the completion report must expose any unwaived DoD
item under Remaining risks. Stop-hook enforcement is opt-in hardening.

## Alternatives considered

- **A Stop-hook-enforced review gate** — documented as opt-in; rejected
  as the default because every stop would depend on an external CLI.
- **Fixed roles (Claude implements, Codex reviews)** — the original
  decision favored Claude's implementer tooling and Codex's native review.
  The 2026-09-04 amendment supports the reverse direction with the same
  scope checks, rubric, finding evaluation, and human waiver requirement.
