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
   fresh, read-only Codex pass over the plan and the graph diff, hunting
   misunderstood requirements, missing edge cases, excess complexity, and
   architectural conflicts.
   ```bash
   codex exec -C . -s read-only --ephemeral \
     -c model_reasoning_effort="high" -c skills.include_instructions=false \
     "<challenge prompt: misunderstood requirements, missing edge cases, \
   excess complexity, architectural conflicts; BLOCKER/MAJOR/MINOR + \
   APPROVE/REVISE>" < /dev/null
   ```
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
6. **Adversarial pass:** `/adversarial-tests <feature_api dir> [feature
   impl dir]` once the first green implementation of the new behavior
   exists (Definition of Done item 2).
7. **Full gate:** `tool/checks.sh` (no flags) — green before review.
8. **Cross-review:** commit first, then `/cross-review --base <saved-sha>` — an independent
   Codex pass over the whole diff (Definition of Done item 4). The script
   diffs committed HEAD against the base and refuses a dirty tree
   (uncommitted or untracked files) with exit 3; that exit is recoverable —
   commit and re-run. A missing/invalid base, no common ancestor, or an
   empty diff is exit 2: correct the scope using the saved base, never
   waive review. If there are truly no net changes, report that fact
   instead of selecting an unrelated base. The other exit-3 reasons
   (codex absent, not logged in, the pinned model rejected) are honest failures:
   stop, report the reason verbatim under Remaining risks, and let the
   human waive Definition of Done item 4.
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
| Agent (implements) | Proposes the graph diff, writes `*_api`/impl/`app/` code and every layer of tests, runs the inner loop, dispatches the adversarial pass, evaluates review findings, writes the completion report. |
| Tools (verify) | `tool/checks.sh` — graph, imports, lints, codegen freshness, purity, analyze, tests — mechanically, the same on every machine. |
| Codex (reviews) | Independent, read-only second reader of the diff against `## Code Review Rules`; a verdict to evaluate, never to obey blindly. |
| Human (decides) | Exactly two checkpoints: approves the graph diff before code is written; performs the behavioral check for UI-affecting changes. |

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

The ritual above trusts the agent to actually run `/cross-review` before
declaring a task done — nothing stops a commit from landing without it.
Teams that want that enforced can wire a `Stop` hook that blocks the
session from ending while the cross-review verdict is `request_changes`.
**This is not wired by default** — every stop would then wait 1–5 minutes
for a full Codex review, which is too slow for the inner loop this
template optimizes for. Add it deliberately, per project, if the cost is
worth it to you:

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
