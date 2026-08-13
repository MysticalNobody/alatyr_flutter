#!/usr/bin/env bash
# THE quality gate. Tiers:
#   --fast            format + graph + imports (~seconds, agent inner loop)
#   (default: full)   fast + codegen freshness + toolchain tests
#                     + per-package analyze/test
#   --package <path>  targeted analyze+test for one workspace member
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
  # NOTE (deviation from brief): `((${#temporary_files[@]})) && rm -f ...`
  # returns the *arithmetic test's* exit status (1) when the array is empty,
  # short-circuiting past rm -f. Under `set -e`, a failing command inside a
  # trap is NOT itself fatal, but bash still uses the trap handler's own
  # last exit status as the process's final exit code when the handler
  # doesn't call exit explicitly - so a "successful" `exit 0`/`OK (fast)`
  # run was silently turned into exit code 1 whenever temporary_files was
  # empty (always true for --fast and --package, which never mktemp).
  # Verified interactively: the `&&` form flips a script that calls
  # `exit 0` into process exit code 1; the `if` form below preserves 0.
  if ((${#temporary_files[@]})); then
    rm -f "${temporary_files[@]}"
  fi
}
trap cleanup EXIT

# Tracked+staged diff plus content hashes of untracked files. Lets the
# freshness guard work in a dirty tree: only deltas introduced BY the gate
# (stale codegen) fail it; pre-existing edits pass through unchanged.
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
  ( cd "$ROOT_DIR/$dir"
    if [[ "$runner" == "flutter" ]]; then
      run_flutter analyze --no-pub --fatal-infos
      [[ "$has_tests" == "true" ]] && run_flutter test --no-pub
    else
      run_dart analyze --fatal-infos
      [[ "$has_tests" == "true" ]] && run_dart test
    fi )
}

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

before_snapshot=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  before_snapshot="$(mktemp)"; temporary_files+=("$before_snapshot")
  snapshot_worktree >"$before_snapshot"
elif is_ci; then
  echo "FATAL: not a git worktree - codegen freshness cannot be checked in CI" >&2
  exit 1
else
  echo "WARNING: not a git worktree - codegen freshness check SKIPPED" >&2
fi

echo "==> Codegen (freshness check)"
bash "$ROOT_DIR/tool/codegen.sh"

if [[ -n "$before_snapshot" ]]; then
  after_snapshot="$(mktemp)"; temporary_files+=("$after_snapshot")
  snapshot_worktree >"$after_snapshot"
  if ! cmp -s "$before_snapshot" "$after_snapshot"; then
    echo "Generated artifacts are stale (codegen changed the tree):" >&2
    git status --short -- . >&2
    exit 1
  fi
fi

echo "==> Toolchain tests (root)"
run_dart test

echo "==> Analyze + test (per workspace package)"
while IFS=$'\t' read -r runner dir has_tests; do
  analyze_and_test "$runner" "$dir" "$has_tests"
done < <(run_dart run tool/checks_workspace.dart)

echo "OK"
