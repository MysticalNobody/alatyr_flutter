#!/usr/bin/env bash
# Workspace-wide codegen. Builders execute in the package that owns their
# sources - running build_runner only from the root silently skips member
# builders, hence the per-package plan.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"

echo "    resolve workspace dependencies"
run_dart pub get

plan="$(run_dart run tool/checks_workspace.dart --codegen)"
[[ -z "$plan" ]] && { echo "    no codegen packages - skipping"; exit 0; }

while IFS= read -r package_dir; do
  [[ -z "$package_dir" ]] && continue
  echo "    codegen ${package_dir}"
  ( cd "$ROOT_DIR/$package_dir"
    run_dart run build_runner build --low-resources-mode --delete-conflicting-outputs )
done <<<"$plan"
