#!/usr/bin/env bash
# Shared helpers for tool/*.sh: fvm-first dart/flutter and hard wall-clock
# timeouts. flutter/dart test --timeout does NOT catch teardown hangs, and
# analyzer plugins can hang in child processes - so every analyze/test call
# is bounded at the OS level and a failure names the offending package.
set -euo pipefail

CHECKS_TEST_TIMEOUT="${CHECKS_TEST_TIMEOUT:-300}"
CHECKS_ANALYZE_TIMEOUT="${CHECKS_ANALYZE_TIMEOUT:-180}"
# build_runner AOT-compiles every builder on a cold .dart_tool/build (~20 s
# per package on an M-series laptop) before it generates anything, and a
# mis-resolved builder can spin forever - same wall-clock guard as tests.
CHECKS_CODEGEN_TIMEOUT="${CHECKS_CODEGEN_TIMEOUT:-600}"
# tool/e2e.sh: patrol has no wall-clock guard of its own, and a cold run is
# a full native build plus an install plus the flows - 30 min covers it on a
# hosted runner. Provisioning (system-image download, AVD/simulator create,
# first boot) is bounded separately: it can be slow without being stuck.
CHECKS_E2E_TIMEOUT="${CHECKS_E2E_TIMEOUT:-1800}"
CHECKS_E2E_PROVISION_TIMEOUT="${CHECKS_E2E_PROVISION_TIMEOUT:-900}"

is_ci() { [[ -n "${CI:-}" && "${CI}" != "false" && "${CI}" != "0" ]]; }

run_guarded() {
  local seconds="$1"; shift
  if command -v gtimeout >/dev/null 2>&1; then gtimeout -k 10 "$seconds" "$@"
  elif command -v timeout >/dev/null 2>&1; then timeout -k 10 "$seconds" "$@"
  else
    # Fallback (bare macOS): perl alarm. Does not kill grandchildren as
    # reliably as timeout -k; brew install coreutils for the robust path.
    perl -e 'my $s = shift @ARGV; alarm $s; exec @ARGV or die "exec: $!"' \
      "$seconds" "$@"
  fi
}

_tool() { # _tool <dart|flutter> <args...>
  local bin="$1"; shift
  local cmd=("$bin")
  command -v fvm >/dev/null 2>&1 && cmd=(fvm "$bin")
  case "${1:-}" in
    test)    run_guarded "$CHECKS_TEST_TIMEOUT" "${cmd[@]}" "$@" ;;
    analyze) run_guarded "$CHECKS_ANALYZE_TIMEOUT" "${cmd[@]}" "$@" ;;
    run)
      # Only `dart run build_runner ...` gets the guard: the other `dart run`
      # callers (tool/*.dart plan builders and validators) are sub-second,
      # and guarding them would only add a perl/timeout hop per call.
      if [[ "${2:-}" == "build_runner" ]]; then
        run_guarded "$CHECKS_CODEGEN_TIMEOUT" "${cmd[@]}" "$@"
      else
        "${cmd[@]}" "$@"
      fi ;;
    *)       "${cmd[@]}" "$@" ;;
  esac
}

run_dart()    { _tool dart "$@"; }
run_flutter() { _tool flutter "$@"; }
