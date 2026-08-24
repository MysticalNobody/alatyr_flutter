#!/usr/bin/env bash
# Template smoke (docs/reference/ci_contract.md): copy this checkout, make the
# copy a git worktree (the gate's freshness snapshot needs one), instantiate it with
# tool/init.dart and run the FULL gate on the result. Proves that what users
# receive is a working project. Deleted by init.
#   tool/template_smoke.sh [<fixture dir>]   (default: a temp dir)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
FIXTURE="${1:-$(mktemp -d "${TMPDIR:-/tmp}/alatyr-smoke.XXXXXX")/fixture_app}"
mkdir -p "$FIXTURE"
echo "==> Copy -> $FIXTURE"
rsync -a --exclude .git --exclude .dart_tool --exclude build --exclude '*.ru.md' --exclude docs/superpowers --exclude CLAUDE.local.md "$ROOT_DIR"/ "$FIXTURE"/
cd "$FIXTURE"
git init -q
git -c user.email=smoke@template -c user.name=smoke add -A
git -c user.email=smoke@template -c user.name=smoke commit -qm "template snapshot"
echo "==> Instantiate"
run_dart pub get >/dev/null
# Capture the placeholder identity BEFORE init deletes its own sources; this
# script lives in tool/ and must never spell the tokens itself.
identity="$(run_dart run tool/init.dart --print-identity)"; eval "$identity"
[[ -n "$PACKAGE_NAME" && -n "$BUNDLE_ID" && -n "$ORG" && -n "$DISPLAY_NAME" && -n "$WORKSPACE_NAME" ]] || { echo "could not derive the placeholder identity" >&2; exit 1; }
# The deletion list too comes from init itself (it deletes its own sources),
# so this script can assert on EVERY entry without restating the list.
template_only="$(run_dart run tool/init.dart --print-template-only-paths)"
[[ -n "$template_only" ]] || { echo "could not read the template-only path list" >&2; exit 1; }
run_dart run tool/init.dart --name fixture_app --org dev.fixture --yes
echo "==> Assert the template machinery is gone and no identity token survived"
while IFS= read -r path; do
  if [[ -n "$path" && -e "$path" ]]; then
    echo "init left $path behind" >&2
    exit 1
  fi
done <<<"$template_only"
survivors="$(git ls-files -z | xargs -0 /usr/bin/grep -aIl -F -e "$PACKAGE_NAME" -e "$BUNDLE_ID" -e "$ORG" -e "$DISPLAY_NAME" -e "$WORKSPACE_NAME" -- 2>/dev/null | grep -v '^docs/adr/' || true)"
[[ -z "$survivors" ]] || { echo "identity token survived init:" >&2; echo "$survivors" >&2; exit 1; }
[[ -d app/android/app/src/main/kotlin/dev/fixture/fixture_app ]] || { echo "Kotlin package dir was not moved" >&2; exit 1; }
pbxproj="app/ios/Runner.xcodeproj/project.pbxproj"
# grep on a missing file exits 2, which the `&&` list would swallow: a broken
# rewrite or copy must not read as a clean iOS project.
[[ -f "$pbxproj" ]] || { echo "$pbxproj is missing: the rewrite or the copy is broken" >&2; exit 1; }
grep -q 'DEVELOPMENT_TEAM' "$pbxproj" && { echo "a DEVELOPMENT_TEAM leaked into the iOS project" >&2; exit 1; }
echo "==> Full gate on the instantiated project"
bash tool/checks.sh
echo "template smoke OK ($FIXTURE)"
