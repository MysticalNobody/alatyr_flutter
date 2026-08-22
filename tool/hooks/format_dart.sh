#!/usr/bin/env bash
# Claude Code PostToolUse (Edit|Write): keep the gate's format stage green
# by formatting the Dart file that was just written. Never blocks (exit 0
# always; PostToolUse cannot undo the edit anyway). Generated files are
# skipped - codegen owns their formatting. fvm-first like tool/common.sh.
set -u
payload="$(cat 2>/dev/null || true)"
path="$(printf '%s' "$payload" \
  | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
  | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
[[ -z "$path" || "$path" != *.dart || ! -f "$path" ]] && exit 0
[[ "$path" == *.g.dart || "$path" == *.freezed.dart || "$path" == *.drift.dart ]] && exit 0
if command -v fvm >/dev/null 2>&1; then fvm dart format "$path" >/dev/null 2>&1
else dart format "$path" >/dev/null 2>&1; fi
exit 0
