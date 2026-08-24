#!/usr/bin/env bash
# ONE hook script for BOTH agents (AGENTS.md hard invariant 5): blocks hand edits of
# generated Dart files (*.g.dart, *.freezed.dart, *.drift.dart).
# Deletes (`*** Delete File:`) and renames onto a generated name
# (`*** Move to:`) are blocked on purpose too: codegen recreates the file,
# and a hand delete would only resurface as a red codegen-freshness stage.
#
# Supported payloads (captured from both agent CLIs):
#   Claude Code PreToolUse, matcher Edit|Write:
#     {"tool_name":"Write","tool_input":{"file_path":"/abs/x.g.dart",...}}
#   Codex PreToolUse, matcher Edit|Write (alias of apply_patch):
#     {"tool_name":"apply_patch","tool_input":{"command":"*** Begin Patch\n
#      *** Add File: x.g.dart\n+...\n*** End Patch"}}
# Contract: exit 2 + message on stderr = block (both agents show the
# message to the model); exit 0 = allow. Anything we cannot parse is
# allowed - the codegen-freshness gate is the backstop, this hook is the
# fast path. bash + POSIX sed/awk/grep only: no jq, no python.
set -u
payload="$(cat 2>/dev/null || true)"
[[ -z "$payload" ]] && exit 0

claude_paths=""; codex_paths=""
if printf '%s' "$payload" | grep -q '"tool_name"[[:space:]]*:[[:space:]]*"apply_patch"'; then
  # Codex shape: patch headers inside the JSON-escaped command string.
  # Unescape \n so the headers sit on their own lines, then keep the targets.
  codex_paths="$(printf '%s' "$payload" \
    | awk '{ gsub(/\\n/, "\n"); print }' \
    | grep -E '^\*\*\* (Add|Update|Delete) File: |^\*\*\* Move to: ' \
    | sed -E 's/^\*\*\* (Add|Update|Delete) File: //; s/^\*\*\* Move to: //; s/\\"/"/g; s/[[:space:]]*$//')"
else
  # Claude shape: the FIRST "file_path" value - tool_input.file_path precedes
  # the content, so text inside the content cannot be mistaken for it.
  claude_paths="$(printf '%s' "$payload" \
    | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed -E 's/^"file_path"[[:space:]]*:[[:space:]]*"(.*)"$/\1/')"
fi

blocked="$(printf '%s\n%s\n' "$claude_paths" "$codex_paths" \
  | grep -E '\.(g|freezed|drift)\.dart$' || true)"

if [[ -n "$blocked" ]]; then
  {
    echo "Generated file(s) must not be hand-edited:"
    printf '%s\n' "$blocked" | sed 's/^/  /'
    echo "Edit the source (the 'part of' target) and run tool/codegen.sh instead (hard invariant 5)."
  } >&2
  exit 2
fi
exit 0
