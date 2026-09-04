# ADR-0005: Cross-review protocol

**Status:** accepted
**Date:** 2026-08-13

## Context

A single agent reviewing its own diff shares its own blind spots. The
template needs a second, independent reader before work counts as done,
without turning that reader into a second implementer or a silent gate
that can be routed around.

## Decision

Codex acts as an independent AI reviewer through a repo-level skill
(`.claude/skills/cross-review/`), invoked as part of the Definition of
Done rather than enforced by a Stop hook. The reviewer runs read-only,
evaluates the diff against `## Code Review Rules` in `AGENTS.md` (the same
rubric Codex reads natively and Codex cloud PR review applies), and
returns a verdict the implementer must **evaluate, not obey**: every
P0/P1 finding is either fixed or explicitly rebutted with reasoning in the
task report, and the verdict is quoted, not paraphrased. If review is
honestly impossible (`codex` absent, the model rejected the call), the
human explicitly waives the item — the agent never waives it itself. The
rubric lives in `AGENTS.md` (what findings matter); role/sandbox
instructions (read-only, ephemeral, "act as a reviewer") live only in the
skill and per-call flags, never in `AGENTS.md`, which Codex also reads for
ordinary implementation tasks.

The caller records the pre-task commit SHA before editing and passes it
as the required `--base`. Invalid or empty review scopes are recoverable
usage errors (exit 2), never grounds for a review waiver.

## Consequences

The same rubric drives local CLI review, headless `codex exec` review, and
Codex cloud PR review with no extra configuration. Because there is no
Stop hook by default, a task can still be declared done without review
having actually run — the honesty burden sits on the "Remaining risks"
section of the completion report and on the human seeing an unwaived DoD
item, not on a hook that would block the commit outright. Hardening that
enforcement is documented as an opt-in, not shipped by default.

## Alternatives considered

- **A Stop-hook-enforced review gate** — considered and documented as
  opt-in hardening; rejected as the default because it would make every
  commit depend on an external CLI's availability.
- **Role inversion (Codex implements, Claude reviews)** — considered
  after comparing against an external Claude+Codex workflow that inverts
  the roles; rejected because this harness lives on the implementer side,
  where Claude Code's tooling is richer, and Codex's review tooling
  (native `AGENTS.md` reading, `codex review`) is the better fit for the
  reviewer side.
