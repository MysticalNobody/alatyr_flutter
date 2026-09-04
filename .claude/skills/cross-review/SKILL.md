---
name: cross-review
description: Run the Codex cross-review of this branch (Definition of Done item 4) and evaluate its findings - use after the gate is green and before declaring a task done, or when asked to "cross-review", "run codex review", "get the review verdict".
argument-hint: "--base <saved-task-start-sha> [--structured]"
allowed-tools: Bash(.claude/skills/cross-review/codex_review.sh:*), Bash(git:*), Read
---

# Cross-review (Codex)

Independent review of this branch by a second model. You stay responsible:
Codex gives input; you evaluate every point against the code.

## 1. Run it

```bash
.claude/skills/cross-review/codex_review.sh --base <saved-task-start-sha>
```

Use the task-start SHA recorded before edits (AGENTS.md), or an explicit
review base supplied by the user in `$ARGUMENTS`. Never guess `HEAD~1` or
silently use the runner's legacy `main` default for a task. If the saved
base is unavailable, recover it from the task record or ask for the scope.

This skill is for **Claude implementation -> Codex review**. When Codex
implements, use `.agents/skills/cross-review/SKILL.md`, which runs Claude
through `tool/claude_review.sh` instead. Do not ask the implementing model
to act as its own cross-reviewer.

**Commit first:** the script diffs committed HEAD against the base and
refuses a dirty tree (uncommitted or untracked files) with exit 3 - commit
and re-run.

The script does the pre-flight (clean tree, codex installed and logged in,
base ref exists, diff non-empty), forces the reviewer role (read-only
sandbox, ephemeral, high effort, user skills off) and prints the output
path: `review.txt` (native reviewer, applies `## Code Review Rules` from
AGENTS.md) or, with `--structured`, `review.json` matching
`.codex/review-schema.json`. Reviews take 1–5 minutes: run with a Bash
timeout of 600000 ms; never background it.

**Exit 3 = review not performed** - two kinds, handled differently:

- **Recoverable:** a dirty tree, missing/invalid base ref, or empty diff.
  Commit the work or correct the scope using the saved task-start SHA,
  then re-run. These are not waiver cases.
- **Honest failure:** codex not installed, not logged in, the pinned model
  rejected. Stop, quote the
  script's stderr reason verbatim in your report under Remaining risks,
  and never invent findings. The human waives DoD 4 explicitly - you do
  not.

Exit 2 is a usage error in your own invocation - fix the arguments.

## 2. Evaluate, don't obey

Read the output file. For each finding: read the cited lines, trace the
claimed failure, then classify:

- ✅ Agree — state the concrete failing path; fix it (P0/P1 must be fixed
  or rebutted before done).
- ❌ Disagree — say why it does not apply (quote the code).
- 🤔 Your call — plausible but unverified; tell the human.

Quote the reviewer's conclusion verbatim (structured path: the `verdict`
and `summary` fields; native path: its opening summary line and every
`[Pn]` title) — never paraphrase it. P2/P3 are at your discretion. Never
silently apply suggestions.

## 3. Report

```
Cross-review (codex, base <ref>): <verdict verbatim>
- ✅ …  - ❌ …  - 🤔 …
Remaining risks: <open P2/P3, anything not re-verified, or "none">
```
