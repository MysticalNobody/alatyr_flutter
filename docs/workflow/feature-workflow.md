# Feature workflow

The graph-first ritual, step by step, with the exact commands and skills —
and the roles that make "the agent implements; tools verify; an
independent AI reviews; the human decides" hold in practice.

## Before the first edit

Use the task's existing branch/worktree, or create a working branch with
`git switch -c codex/<task-name>`. Run `git rev-parse HEAD` and record the
printed SHA in the task plan or task conversation as the review base.
Keep that same SHA through every implementation/fix commit and session
restart. Set `TASK_BASE` to this saved value when running cross-review;
do not recompute it after committing or guess `HEAD~1`.

For work already started without a saved base, identify the pre-task
commit from history and the intended scope. If the scope is uncertain,
ask the human to clarify it; an incorrect base is not a review waiver.

## The ritual

1. **Edit the graph.** Propose the package shape by editing
   `docs/reference/package_graph.yaml` (new packages, kinds,
   `allowed_dependencies`) and draft the feature plan.
2. **Optional plan-challenge** (recommended for non-trivial features): a
   fresh, read-only pass over the plan and the graph diff, hunting
   misunderstood requirements, missing edge cases, excess complexity, and
   architectural conflicts. A Claude implementer can dispatch Codex:
   ```bash
   codex exec -C . -s read-only --ephemeral \
     -c model_reasoning_effort="high" -c skills.include_instructions=false \
     "<challenge prompt: misunderstood requirements, missing edge cases, \
   excess complexity, architectural conflicts; BLOCKER/MAJOR/MINOR + \
   APPROVE/REVISE>" < /dev/null
   ```
   A Codex implementer can dispatch a fresh collaboration subagent with
   a read-only task, no conversation history, and only the plan, graph
   diff, and relevant contract paths. Use the same challenge rubric and
   verdict; do not pass the implementer's own reasoning.
   Findings come back as BLOCKER/MAJOR/MINOR with an APPROVE/REVISE
   verdict. Evaluate on merit — never auto-apply. One round is normally
   enough; catching a wrong plan here costs minutes, catching it in the
   diff costs the whole implementation.
3. **Human graph approval.** A human reviews the graph diff — the one
   cheap checkpoint tools cannot replace: "is this designed right?"
4. **Implement in fixed order:** `*_api` (contracts only) → impl → wiring
   in `app/`.
5. **Inner loop:** `tool/checks.sh --fast` after every meaningful edit
   (format, graph, imports — seconds).
6. **Adversarial pass** once the first green implementation of the new
   behavior exists (Definition of Done item 2). Claude uses
   `/adversarial-tests <feature_api dir> [feature impl dir]`. Codex
   dispatches a fresh, read-only collaboration subagent with the same
   contract/spec/diff inputs and the rubric in
   `.claude/agents/test-breaker.md`; no implementer reasoning or inherited
   conversation. Either implementer covers every returned scenario with
   a test or an explicit `skip: 'deliberate: …'` stub and reports the tally.
7. **Full gate:** `tool/checks.sh` (no flags) — green before review.
8. **Cross-review:** commit first, then invoke the implementer's
   `cross-review` skill with `--base <saved-task-start-sha>` — Claude
   dispatches Codex, and Codex dispatches Claude (Definition of Done
   item 4). Both runners review committed HEAD against the supplied base
   and reject a dirty tree (tracked edits or untracked files). Commit and
   retry; this is recoverable. Missing/invalid bases, no common ancestor,
   and empty diffs also require correcting the scope, never a waiver. If
   there are truly no net changes, report that fact instead of selecting
   an unrelated base. If a reviewer CLI,
   authentication, or model failure prevents review, report the stderr
   reason verbatim under Remaining risks; only the human can explicitly
   waive DoD 4. Evaluate every P0/P1 finding, fix or rebut it with recorded
   reasoning, and re-review code fixes against the original saved base.
9. **Human behavioral check** for any UI-affecting change (Definition of
   Done item 5) — the one layer that stays human by design.

## The proofs beyond the gate

DoD 3's "critical flows are touched" and the two smokes, made mechanical
— run the proof when the diff matches, no judgment calls:

- `tool/e2e.sh` (every locally reachable platform): the diff touches
  `app/`, a `feature_*` package, `data_local`, or
  `docs/reference/critical_flows.md`.
- `tool/web_smoke.sh`: the diff touches `app/web/`, `data_local`, or
  bumps drift/`sqlite3`.
- `tool/template_smoke.sh` (template repo only): the diff touches
  `tool/init.dart`, `tool/src/init_*`, or a path `templateOnlyPaths`
  names.

## Roles

| Role | Responsibility |
|---|---|
| Claude Code or Codex (implements) | Proposes the graph diff, writes `*_api`/impl/`app/` code and every layer of tests, runs the inner loop, dispatches the adversarial pass, evaluates review findings, writes the completion report. |
| Tools (verify) | `tool/checks.sh` — graph, imports, lints, codegen freshness, purity, analyze, tests — mechanically, the same on every machine. |
| The other agent (reviews) | Independent, read-only second reader of the diff against `## Code Review Rules`; a verdict to evaluate, never to obey blindly. |
| Human (decides) | Approves the graph diff before code is written; performs the behavioral check for UI-affecting changes; explicitly decides any waiver when an external review cannot run. |

## Review commands and outputs

Set `TASK_BASE` to the SHA recorded **before edits**, then run the
command for your implementer after committing:

```bash
# Claude implements; Codex reviews.
.claude/skills/cross-review/codex_review.sh --base "$TASK_BASE"

# Codex implements; Claude reviews.
tool/claude_review.sh --base "$TASK_BASE"
```

Claude's skill is `.claude/skills/cross-review/SKILL.md`; Codex's skill is
`.agents/skills/cross-review/SKILL.md`. Both commands support
`--structured` and `--out <dir>` and print the result path: `review.txt`
by default, or `review.json` matching `.codex/review-schema.json`.
Claude's structured result is extracted and validated from its CLI JSON
envelope. Default output directories are `.superpowers/cross-review`
for Codex and `.superpowers/cross-review/claude` for Claude (gitignored).
Exit 0 means a review was written, not that it approved the diff; read
the verdict. Exit 2 is an invocation error; Codex also uses it for invalid
or empty scopes, while Claude reports those with exit 3. Exit 3 means
review was not performed, with the reason on stderr. Scope errors and
dirty trees are recoverable in either runner, regardless of exit code.

The Claude runner enables only Read/Grep/Glob, uses `dontAsk`, disables
skills, MCP servers and hooks, and does not persist the session. These
CLI restrictions do not provide an OS sandbox. Node >= 20 validates its
output. Codex retains its read-only sandbox and ephemeral session.

## Completion-report shape

Every completion report ends with a **Remaining risks** section — this is
the honesty forcing function behind any "done" claim, not boilerplate; an
empty section states "none" explicitly rather than being omitted.

```
## What I implemented
…
## Tests
…
## Adversarial pass
<N> scenarios - <a> already covered, <b> tests added, <c> deliberate skips.
## Cross-review
<verdict, quoted verbatim> - ✅ … ❌ … 🤔 …
## Remaining risks
<waivers, deliberate skips, unverified assumptions, or "none">
```

## Opt-in hardening: a Stop-hook review gate

The ritual above trusts the agent to actually run cross-review before
declaring a task done — nothing stops a commit from landing without it.
Teams that want that enforced can wire a `Stop` hook that blocks the
session from ending while the cross-review verdict is `request_changes`.
**This is not wired by default** — every stop would then wait 1–5 minutes
for an external review, which is too slow for the inner loop this
template optimizes for. Add it deliberately, per project, if the cost is
worth it to you. The example below is for a Claude implementation session
with Codex reviewing. Supply `TASK_BASE` in that session's
environment using the saved starting SHA; there is no implicit branch
default:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/tool/hooks/stop_review_gate.sh",
            "timeout": 600
          }
        ]
      }
    ]
  }
}
```

with a `tool/hooks/stop_review_gate.sh` shaped like this (illustrated here,
**not shipped** — write it yourself if you opt in):

```bash
#!/usr/bin/env bash
# Illustrative only - not shipped. Blocks Stop until cross-review is clean.
set -u
payload="$(cat)"
# Must not loop on its own continuation: Claude Code re-invokes Stop hooks
# after one already blocked with stop_hook_active=true - exit 0 immediately
# then, or the hook fires forever.
printf '%s' "$payload" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

# Fails OPEN by design: a non-zero exit here (exit 3 - codex missing, not
# logged in, dirty tree) must not trap the session in an unstoppable loop.
# Swap `exit 0` for `exit 2` + the stderr reason if you want a missing
# reviewer to block Stop instead.
# Configure TASK_BASE in this hook's environment from the saved task SHA;
# never derive it from HEAD at Stop time, after the task was committed.
[[ -n "${TASK_BASE:-}" ]] || { echo "Set TASK_BASE to the saved pre-task SHA" >&2; exit 2; }
review_file="$(.claude/skills/cross-review/codex_review.sh --base "$TASK_BASE" --structured)" || {
  status=$?
  # Scope/usage errors must be corrected, not treated as reviewer downtime.
  [[ "$status" -eq 2 ]] && exit 2
  exit 0
}
# Failing open does not waive DoD 4; the caller must resolve the failure
# or obtain the human's explicit waiver for unavailable external review.
verdict="$(grep -o '"verdict"[[:space:]]*:[[:space:]]*"[^"]*"' "$review_file" \
  | sed -E 's/.*"([a-z_]+)"$/\1/')"

if [[ "$verdict" == "request_changes" ]]; then
  echo "Cross-review requested changes - see $review_file:" >&2
  cat "$review_file" >&2
  exit 2
fi
exit 0
```

## Reasoning-effort escalation

When a task stalls (an agent loops without progress, a plan-challenge
comes back REVISE twice on the same point, a review verdict cannot be
resolved), re-dispatch with a more capable model or a higher reasoning
effort rather than retrying the identical call again — repetition without
a capability change tends to reproduce the same stall.

## Next

`docs/workflow/maintenance.md` for keeping the pins in this ritual current;
`docs/workflow/modules.md` for the optional modules that compose with it.
