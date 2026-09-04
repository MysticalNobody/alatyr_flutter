---
name: cross-review
description: Run an independent Claude review of Codex implementation in this repository and evaluate its findings. Use after the full gate and before declaring a task complete, or when asked for cross-review or Claude review of the task diff.
---

# Cross-review (Claude)

For **Codex implementation -> Claude review**, run from the repository root:

```bash
tool/claude_review.sh --base <saved-task-start-sha> --structured
```

Use the `git rev-parse HEAD` saved before task edits, or the user's explicit
review base. Never guess `HEAD~1` for a multi-commit task. If the saved base
is unavailable, recover it from the task record or ask for the scope.
For **Claude implementation -> Codex review**, the existing entrypoint is
`.claude/skills/cross-review/SKILL.md`.

Run `tool/checks.sh` first. Commit all task edits before reviewing: the
runner rejects tracked and untracked changes and reviews committed HEAD
against the merge-base with the supplied base. After fixing findings,
run the relevant checks, commit, and re-review with the same saved base.

The runner requires Claude CLI authentication and Node. It reads the
review model from `.claude/review-model`; keeps only Read/Grep/Glob tools;
disables skills, MCP and hooks; and does not persist a session. These are
per-call reviewer restrictions, not implementation settings or an OS
sandbox. Do not replace the command with unrestricted `claude -p`.

Allow up to ten minutes for the review; keep the process attached and poll
its session if the execution tool yields. `--out <dir>` selects an ignored
or external output directory (default `.superpowers/cross-review/claude`).
The final stdout line is the review file: `review.json` with `--structured`
(shared `.codex/review-schema.json`), otherwise `review.txt`.

Handle the exit status:

- **0:** a review was written, including `request_changes`; read it.
- **2:** fix invocation arguments and re-run.
- **3:** review was not performed. Dirty/moved tree, missing or invalid
  base, and empty diff are recoverable: fix the scope or commit and re-run.
  For a CLI/auth/model failure or invalid response, report the exact stderr
  reason and inspect `review.log` / `review-response.json`; never invent a
  verdict. If review remains impossible, only the human can explicitly
  waive DoD 4. Do not substitute a Codex self-review for Claude.

Evaluate every finding against the cited code. Record agreement with the
concrete failing path and fix it, or rebut it with code evidence. Ask the
human about unresolved uncertainty. No open P0/P1 may remain before done.
Quote `verdict` and `summary` verbatim in the completion report; also quote
finding titles when discussing them. Finish with **Remaining risks**,
including waivers and anything not re-verified, or explicitly `none`.
