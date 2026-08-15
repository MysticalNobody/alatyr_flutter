#!/usr/bin/env bash
# End-to-end proof that all six alatyr_lints rules actually fire through
# the real `dart analyze` plugin-host pipeline (not just the in-memory
# AnalysisRuleTest harness). Copies the plugin package and the violations
# fixture (lints/test/fixtures/violations/) into a fresh scratch directory,
# preserving their relative geometry, then greps the plugin-host output for
# each of the six rule names and asserts exactly one hit apiece.
#
# A fresh scratch dir forces the analysis server to resolve the plugin as a
# brand-new synthetic package on every run, instead of possibly reusing a
# stale plugin-host cache from a previous invocation.
#
# NOT `set -e`: `dart analyze` exits non-zero by design here - the fixture
# ships deliberately-unresolvable `package:` imports (see the fixture's own
# file comments), so a non-zero analyze exit is expected and must not abort
# the script. `set -u` still catches unset-variable typos.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
LINTS_DIR="$ROOT_DIR/lints"
FIXTURE_DIR="$LINTS_DIR/test/fixtures/violations"

# --- fvm-first dart resolution -------------------------------------------
# `fvm dart` (and `fvm exec`) resolve the pinned SDK by reading `.fvmrc` in
# the CURRENT directory - run from outside the repo (as this script must,
# once it starts working in the scratch dir) it silently falls back to
# fvm's *global* default, a different Dart version than the one this repo
# pins. So: resolve the absolute path to the pinned `dart` binary ONCE,
# from inside the repo, and invoke that absolute path from then on -
# cwd-independent, same effective pin as tool/common.sh's `run_dart`.
DART_BIN="dart"
if command -v fvm >/dev/null 2>&1; then
  resolved="$(cd "$ROOT_DIR" && fvm exec which dart 2>/dev/null || true)"
  if [[ -n "$resolved" && -x "$resolved" ]]; then
    DART_BIN="$resolved"
  fi
fi

SCRATCH="$(mktemp -d)"
cleanup() { rm -rf "$SCRATCH"; }
trap cleanup EXIT

PLUGIN_ROOT="$SCRATCH/alatyr_lints"
FIXTURE_COPY="$PLUGIN_ROOT/test/fixtures/violations"

# Copy plugin package (pubspec.yaml + lib/ only - no test/, no .dart_tool/)
# to $SCRATCH/alatyr_lints/, then the fixture to
# $SCRATCH/alatyr_lints/test/fixtures/violations/. This mirrors the fixture's
# own in-repo depth below lints/, so its committed
# `plugins: alatyr_lints: path: ../../..` resolves correctly here too.
mkdir -p "$PLUGIN_ROOT"
cp "$LINTS_DIR/pubspec.yaml" "$PLUGIN_ROOT/"
cp -R "$LINTS_DIR/lib" "$PLUGIN_ROOT/lib"

mkdir -p "$(dirname "$FIXTURE_COPY")"
cp -R "$FIXTURE_DIR" "$FIXTURE_COPY"

echo "==> pub get (fixture)"
if ! ( cd "$FIXTURE_COPY" && "$DART_BIN" pub get ); then
  echo "FAIL: pub get failed in the fixture" >&2
  exit 1
fi

echo "==> dart analyze (fixture)"
log="$("$DART_BIN" analyze "$FIXTURE_COPY" 2>&1)"

expect() { # <rule name> <expected count>
  local rule="$1" want="$2" got
  got="$(grep -c "$rule" <<<"$log")"
  if [[ "$got" -ne "$want" ]]; then
    echo "FAIL: $rule expected $want, got $got" >&2
    echo "--- full dart analyze log ---" >&2
    echo "$log" >&2
    exit 1
  fi
  echo "$rule: $got/$want OK"
}

expect alatyr_boundary_import 1
expect alatyr_banned_dependency 1
expect alatyr_pure_core 1
expect alatyr_one_widget_per_file 1
expect alatyr_no_widget_returning_function 1
expect alatyr_no_nested_ternary 1

echo "OK"
