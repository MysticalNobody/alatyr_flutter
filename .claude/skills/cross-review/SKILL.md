---
name: cross-review
description: Run the Codex cross-review of this branch (Definition of Done item 4) and evaluate its findings - use after the gate is green and before declaring a task done, or when asked to "cross-review", "run codex review", "get the review verdict".
argument-hint: "[--base <ref>] [--structured]"
allowed-tools: Bash(.claude/skills/cross-review/codex_review.sh:*), Bash(git:*), Read
---

# Cross-review (Codex)

Independent review of this branch by a second model. You stay responsible:
Codex gives input; you evaluate every point against the code.

## 1. Run it

```bash
.claude/skills/cross-review/codex_review.sh --base main
```

If the user passed arguments (`$ARGUMENTS`, e.g. `--base develop --structured`),
use them instead of `--base main`.

The script does the pre-flight (codex installed and logged in, base ref
exists, diff non-empty), forces the reviewer role (read-only sandbox,
ephemeral, high effort, user skills off) and prints the output path:
`review.txt` (native reviewer, applies `## Code Review Rules` from
AGENTS.md) or, with `--structured`, `review.json` matching
`.codex/review-schema.json`. Reviews take 1–5 minutes: run with a Bash
timeout of 600000 ms; never background it.

**Exit 3 = review not performed.** Quote the script's stderr reason in your
report under Remaining risks and stop; never invent findings. The human
waives DoD 4 explicitly if the review is impossible - you do not.

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
