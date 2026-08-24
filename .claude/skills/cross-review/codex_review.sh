#!/usr/bin/env bash
# Cross-review runner (docs/adr/0005-cross-review-protocol.md). Runs Codex as a READ-ONLY
# reviewer of this branch's diff and writes its verdict to a file. Used by
# the /cross-review skill, the codex-reviewer subagent, and humans.
#
#   codex_review.sh [--base <ref>] [--structured] [--out <dir>]
#
# --base       base ref for the diff (default: main)
# --structured machine-readable findings via --output-schema
#              (.codex/review-schema.json) instead of the native reviewer
# --out        output directory (default: .superpowers/cross-review, gitignored)
#
# Exit codes: 0 review written; 2 usage; 3 review NOT performed (the reason
# is on stderr - report it verbatim, never fabricate a verdict).
set -euo pipefail

BASE=main; STRUCTURED=false; OUT=""; DEFAULT_OUT=".superpowers/cross-review"
usage() { echo "usage: codex_review.sh [--base <ref>] [--structured] [--out <dir>]" >&2; }
# A missing value for --base/--out is a usage error (exit 2), not a bash
# parameter-expansion abort (exit 1) - the exit-code contract above is what
# the codex-reviewer agent and the Stop-hook sample branch on.
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) [[ $# -ge 2 && $2 != --* ]] || { usage; exit 2; }; BASE="$2"; shift 2 ;;
    --structured) STRUCTURED=true; shift ;;
    --out) [[ $# -ge 2 && $2 != --* ]] || { usage; exit 2; }; OUT="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "review not performed: not inside a git repository" >&2; exit 3; }
# Absolute output dir (the caller's cwd may differ from the root we cd into).
if [[ -z "$OUT" ]]; then OUT="$ROOT/$DEFAULT_OUT"; elif [[ "$OUT" != /* ]]; then OUT="$PWD/$OUT"; fi
cd "$ROOT"
command -v codex >/dev/null 2>&1 || { echo "review not performed: codex CLI not installed (npm i -g @openai/codex)" >&2; exit 3; }
# `codex login status` reports on stderr; its exit status is the contract.
codex login status >/dev/null 2>&1 || { echo "review not performed: codex is not logged in (run: codex login)" >&2; exit 3; }
# ONE model pin, read from the project config so the two cannot drift.
REVIEW_MODEL="$(sed -n 's/^review_model = "\(.*\)"$/\1/p' "$ROOT/.codex/config.toml" | head -n 1)"
[[ -n "$REVIEW_MODEL" ]] || { echo "review not performed: review_model missing in .codex/config.toml" >&2; exit 3; }
git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "review not performed: base ref '$BASE' does not exist" >&2; exit 3; }
# Cross-review reads committed HEAD only (the diffs below are --merge-base
# <ref> HEAD); an uncommitted tree would otherwise be silently dropped from
# the reviewed scope with no signal to the caller, so fail loud instead
# (task 8 cross-review, P1: "silently omit uncommitted changes"). Commit
# first, then review - the clean-tree precondition is documented in
# SKILL.md section 1 and in step 8 of docs/workflow/feature-workflow.md.
# Unlike every other exit-3 reason above, this one is RECOVERABLE: commit
# and re-run, do not report it as a review that could not be performed.
# `git diff --quiet HEAD --` only sees tracked files (modified or staged);
# untracked new files are invisible to it, so the guard also checks
# `git ls-files --others --exclude-standard` (fix-round-1: the tracked-only
# guard could still approve a stale subset that omits new, never-`git
# add`-ed files).
if ! git diff --quiet HEAD -- || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
  echo "review not performed: uncommitted changes in the working tree (tracked edits and/or untracked new files) - commit them first (cross-review reads committed HEAD only)" >&2
  exit 3
fi
if [[ -z "$(git diff --merge-base "$BASE" HEAD --stat)" ]]; then
  echo "review not performed: no changes between $BASE and HEAD" >&2; exit 3
fi

mkdir -p "$OUT"
# Reviewer role lives HERE, not in AGENTS.md: read-only sandbox, no session
# file, high effort, and no user-level skills (a user's own skills can
# hijack a review run - e.g. one that triggers on "review" wording).
COMMON=(-C "$ROOT" -s read-only --ephemeral
        -c 'model_reasoning_effort="high"'
        -c 'skills.include_instructions=false')

if [[ "$STRUCTURED" == "true" ]]; then
  TARGET="$OUT/review.json"
  # Delete any stale file from an earlier run so a silent codex failure
  # (exit 0, no output) cannot be masked by leftover content below.
  rm -f "$TARGET"
  PROMPT="Act as a code reviewer for this repository; do not modify files. Apply the '## Code Review Rules' section of AGENTS.md to the unified diff in the <stdin> block (the branch's changes against $BASE). Report findings only for rule violations you can point to with file and line; priority 0 = blocks merge, 3 = nit; confidence_score in [0,1]. Verdict request_changes iff any finding has priority <= 1."
  # With a positional prompt AND piped stdin, codex appends stdin as a
  # <stdin> block (codex exec --help) - the diff travels that way. -m pins
  # the model for plain exec (review_model only governs the reviewer).
  git diff --merge-base "$BASE" HEAD \
    | codex exec "${COMMON[@]}" -m "$REVIEW_MODEL" --output-schema "$ROOT/.codex/review-schema.json" -o "$TARGET" "$PROMPT" \
        >"$OUT/review.log" 2>&1 \
    || { echo "review not performed: codex exec exited non-zero (see $OUT/review.log)" >&2; exit 3; }
else
  TARGET="$OUT/review.txt"
  # Delete any stale file from an earlier run (see the --structured branch).
  rm -f "$TARGET"
  # Native reviewer: applies AGENTS.md's Code Review Rules itself; a custom
  # prompt cannot be combined with --base (clap: mutually exclusive).
  codex exec "${COMMON[@]}" -c "review_model=\"$REVIEW_MODEL\"" review --base "$BASE" -o "$TARGET" \
      >"$OUT/review.log" 2>&1 < /dev/null \
    || { echo "review not performed: codex review exited non-zero (see $OUT/review.log)" >&2; exit 3; }
fi
[[ -s "$TARGET" ]] || { echo "review not performed: codex produced no output (see $OUT/review.log)" >&2; exit 3; }
echo "$TARGET"
