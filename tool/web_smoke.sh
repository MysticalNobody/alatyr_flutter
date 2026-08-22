#!/usr/bin/env bash
# Web runtime smoke (docs/workflow/getting-started.md): build the web app and
# prove with headless Chrome that the theme choice persists across a reload.
# Not a gate stage (no browser in the gate). Exit 0 proven, 3 not performed.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"
command -v node >/dev/null 2>&1 || { echo "web smoke not performed: node (>= 20) is required" >&2; exit 3; }
major="$(node -p 'process.versions.node.split(".")[0]')"
[[ "$major" -ge 20 ]] || { echo "web smoke not performed: node >= 20 required, found $(node -v)" >&2; exit 3; }
( cd app && run_flutter build web )
node_flags=(); [[ "$major" -lt 22 ]] && node_flags=(--experimental-websocket)
node "${node_flags[@]}" tool/web_smoke.mjs app/build/web "${CHROME_BIN:-}"
