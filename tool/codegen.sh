#!/usr/bin/env bash
# Workspace-wide codegen, one build_runner invocation per package that
# declares it (plan from tool/checks_workspace.dart --codegen). A plain
# root invocation exits 0 and writes nothing; build_runner 2.15's
# `--workspace` mode would work but the per-package plan names the failing
# package and is unit-tested, so it stays.
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
    # build_runner >= 2.15 removed --delete-conflicting-outputs and
    # --low-resources-mode (passing them only prints a warning); conflicting
    # outputs are now always overwritten.
    run_dart run build_runner build )
done <<<"$plan"
