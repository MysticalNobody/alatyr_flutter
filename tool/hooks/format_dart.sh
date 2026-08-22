#!/usr/bin/env bash
# PostToolUse formatter for BOTH agents: Claude Code (Edit|Write payload with
# tool_input.file_path) and Codex (apply_patch payload whose tool_response
# lists "A/M <path>" lines under "Updated the following files:"). Keeps the
# gate's format stage green. Never blocks (exit 0 always; PostToolUse cannot
# undo the edit); generated files are skipped - codegen owns their formatting.
set -u
payload="$(cat 2>/dev/null || true)"
[[ -z "$payload" ]] && exit 0
paths=""
if printf '%s' "$payload" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"apply_patch"'; then
  paths="$(printf '%s' "$payload" \
    | awk '{ gsub(/\\n/, "\n"); print }' \
    | sed -n '/Updated the following files:/,$p' \
    | sed -n -E 's/^[AM] (.*\.dart)[[:space:]]*$/\1/p' | sed -E 's/\\"/"/g; s/"[[:space:]]*$//')"
else
  paths="$(printf '%s' "$payload" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
fi
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
targets=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  [[ "$path" == *.dart ]] || continue
  [[ "$path" == *.g.dart || "$path" == *.freezed.dart || "$path" == *.drift.dart ]] && continue
  [[ "$path" = /* ]] || path="$root/$path"
  [[ -f "$path" ]] && targets+=("$path")
done <<<"$paths"
((${#targets[@]})) || exit 0
if command -v fvm >/dev/null 2>&1; then fvm dart format "${targets[@]}" >/dev/null 2>&1
else dart format "${targets[@]}" >/dev/null 2>&1; fi
exit 0
