#!/usr/bin/env bash
# THE quality gate. Tiers:
#   --fast            format + graph + imports (~seconds, agent inner loop)
#   (default: full)   fast + codegen freshness + toolchain analyze/test
#                     + per-package analyze/test
#   --package <path>  fast tier + targeted analyze+test for one workspace
#                     member
# M2 appends lint-plugin stages; M5 appends the critical-flows check.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"

MODE=full; TARGET=""
case "${1:-}" in
  --fast) MODE=fast ;;
  --package) MODE=package; TARGET="${2:?--package needs a path}" ;;
  "") ;;
  *) echo "usage: tool/checks.sh [--fast|--package <path>]" >&2; exit 2 ;;
esac

temporary_files=()
cleanup() {
  # if-form, not `((n)) && ...`: with an empty array the && short-circuit
  # would make the trap's status 1 and bash would override exit 0 with it
  # (and bash 3.2 nounset chokes on empty-array expansion).
  if ((${#temporary_files[@]})); then
    rm -f "${temporary_files[@]}"
  fi
}
trap cleanup EXIT

# Tracked+staged diff plus content hashes of untracked files. Lets the
# freshness guard work in a dirty tree: only deltas introduced BY the gate
# (stale codegen, or an unresolved pubspec.lock) fail it; pre-existing edits
# pass through unchanged.
snapshot_worktree() {
  git diff --binary -- .
  git diff --cached --binary -- .
  while IFS= read -r -d '' file; do
    printf 'untracked:%s\0' "$file"
    git hash-object -- "$file"
  done < <(git ls-files --others --exclude-standard -z -- .)
}

analyze_and_test() { # <runner> <dir> <hasTests>
  local runner="$1" dir="$2" has_tests="$3"
  echo "    analyze ${dir}"
  # Explicit if/then/fi, not `[[ has_tests == true ]] && run_x test` as the
  # branch's last command: when has_tests is false, the `[[ ]]` test's own
  # exit status (1) would become the subshell's exit status, and set -e
  # would fail the whole gate on a test-less member with no error message.
  ( cd "$ROOT_DIR/$dir"
    if [[ "$runner" == "flutter" ]]; then
      run_flutter analyze --no-pub --fatal-infos
      if [[ "$has_tests" == "true" ]]; then run_flutter test --no-pub; fi
    else
      run_dart analyze --fatal-infos
      if [[ "$has_tests" == "true" ]]; then run_dart test; fi
    fi )
}

# Captured before ANY dart/flutter command runs (full tier only): the very
# first `dart run` below implicitly resolves pubspec dependencies and can
# rewrite pubspec.lock. Snapshotting after that point - as this script used
# to - would fold an unresolved-lockfile drift into "before", so the
# after-codegen comparison never sees it and a PR that edits a pubspec
# without updating the committed lock passes green. `dart format` writes
# nothing, but every stage from here on may resolve, so the snapshot has to
# lead all of them.
before_snapshot=""
if [[ "$MODE" == "full" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    before_snapshot="$(mktemp)"; temporary_files+=("$before_snapshot")
    snapshot_worktree >"$before_snapshot"
  elif is_ci; then
    echo "FATAL: not a git worktree - codegen/lockfile freshness cannot be checked in CI" >&2
    exit 1
  else
    echo "WARNING: not a git worktree - codegen/lockfile freshness check SKIPPED" >&2
  fi
fi

echo "==> Formatting"
run_dart format --output=none --set-exit-if-changed .

echo "==> Dependency graph (pubspec level)"
run_dart run tool/verify_dependencies.dart

echo "==> Architecture imports (deterministic scanner)"
run_dart run tool/verify_imports.dart

[[ "$MODE" == "fast" ]] && { echo "OK (fast)"; exit 0; }

if [[ "$MODE" == "package" ]]; then
  line="$(run_dart run tool/checks_workspace.dart | awk -F'\t' -v t="$TARGET" '$2==t')"
  [[ -z "$line" ]] && { echo "Unknown workspace member: $TARGET" >&2; exit 1; }
  IFS=$'\t' read -r runner dir has_tests <<<"$line"
  analyze_and_test "$runner" "$dir" "$has_tests"
  echo "OK (package $TARGET)"; exit 0
fi

echo "==> Codegen (freshness check)"
bash "$ROOT_DIR/tool/codegen.sh"

if [[ -n "$before_snapshot" ]]; then
  after_snapshot="$(mktemp)"; temporary_files+=("$after_snapshot")
  snapshot_worktree >"$after_snapshot"
  if ! cmp -s "$before_snapshot" "$after_snapshot"; then
    echo "Generated artifacts are stale, or pubspec.lock does not match the" >&2
    echo "resolved dependencies (commit the regenerated lock):" >&2
    git status --short -- . >&2
    exit 1
  fi
fi

echo "==> Toolchain analyze (root)"
run_dart analyze --fatal-infos .

echo "==> Toolchain tests (root)"
run_dart test

echo "==> Analyze + test (per workspace package)"
# Materialize the plan into a variable first, not `done < <(run_dart run
# tool/checks_workspace.dart)`: process substitution runs the producer in a
# background subshell whose exit status is invisible to `set -e` (pipefail
# only covers `|` pipes, not `<(...)`), so a crashing plan builder would
# silently run zero iterations instead of failing the gate. An
# empty-but-successful plan is also treated as fatal below.
plan="$(run_dart run tool/checks_workspace.dart)"
[[ -z "$plan" ]] && { echo "FATAL: empty checks plan" >&2; exit 1; }
while IFS=$'\t' read -r runner dir has_tests; do
  analyze_and_test "$runner" "$dir" "$has_tests"
done <<<"$plan"

echo "OK"
