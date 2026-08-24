#!/usr/bin/env bash
# Template smoke (docs/reference/ci_contract.md): build a fixture from this
# checkout's TRACKED files (what "Use this template" actually delivers — no
# gitignored local junk, no .dart-defines/*.env), make it a git checkout (the
# gate's freshness snapshot and init's clean-worktree guard both need one),
# instantiate it with tool/init.dart and run the FULL gate on the result.
# Proves that what users receive is a working project. Deleted by init.
#   tool/template_smoke.sh [<fixture dir>]
# (default: a temp dir — removed on success, kept for debugging on failure)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
if [[ -n "${1:-}" ]]; then
  FIXTURE="$1"
else
  SMOKE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/alatyr-smoke.XXXXXX")"
  trap 'status=$?; if [[ "$status" -eq 0 ]]; then rm -rf "$SMOKE_TMP"; else echo "smoke fixture kept for debugging: $SMOKE_TMP" >&2; fi' EXIT
  FIXTURE="$SMOKE_TMP/fixture_app"
fi
mkdir -p "$FIXTURE"
# Physical path (pwd -P): mktemp answers under /var/folders, a macOS symlink
# to /private/var — the gate below compares $PWD-derived paths with Dart
# getcwd()-derived ones (which resolve symlinks), so the fixture must start
# from the resolved spelling.
FIXTURE="$(cd "$FIXTURE" && pwd -P)"
echo "==> Copy tracked files -> $FIXTURE"
# Tracked files only, taken from the working tree: exactly the GitHub payload
# plus your uncommitted edits to it. A tracked-but-deleted file fails the tar
# loudly — a payload candidate with a hole in it must not smoke green.
(cd "$ROOT_DIR" && git ls-files -z | tar -cf - --null -T -) | tar -xf - -C "$FIXTURE"
cd "$FIXTURE"
git init -q
git -c user.email=smoke@template -c user.name=smoke add -A
git -c user.email=smoke@template -c user.name=smoke -c commit.gpgsign=false commit -qm "template snapshot"
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
# --others --exclude-standard: init moves the Kotlin/androidTest sources to
# NEW, untracked paths and may create files - the pre-init index alone would
# never scan them, so both greps read tracked AND untracked-not-ignored.
survivors="$(git ls-files -z --cached --others --exclude-standard | xargs -0 /usr/bin/grep -aIl -F -e "$PACKAGE_NAME" -e "$BUNDLE_ID" -e "$ORG" -e "$DISPLAY_NAME" -e "$WORKSPACE_NAME" -- 2>/dev/null | grep -v '^docs/adr/' || true)"
[[ -z "$survivors" ]] || { echo "identity token survived init:" >&2; echo "$survivors" >&2; exit 1; }
# The surviving docs must not keep pointing at the deleted instantiation
# machinery: those references live inside template-only markers that init
# strips, and an unmarked one would ship a dangling walkthrough. The page is
# matched with its directory ('workflow/'): the ADR filename
# 0006-working-placeholder-instantiation.md legitimately survives in links.
doc_refs="$(git ls-files -z --cached --others --exclude-standard | xargs -0 /usr/bin/grep -aIl -F -e 'workflow/instantiation.md' -e 'template-only:' -- 2>/dev/null | grep -v '^docs/adr/' || true)"
[[ -z "$doc_refs" ]] || { echo "template-only doc content survived init:" >&2; echo "$doc_refs" >&2; exit 1; }
[[ -d app/android/app/src/main/kotlin/dev/fixture/fixture_app ]] || { echo "Kotlin package dir was not moved" >&2; exit 1; }
pbxproj="app/ios/Runner.xcodeproj/project.pbxproj"
# grep on a missing file exits 2, which the `&&` list would swallow: a broken
# rewrite or copy must not read as a clean iOS project.
[[ -f "$pbxproj" ]] || { echo "$pbxproj is missing: the rewrite or the copy is broken" >&2; exit 1; }
grep -q 'DEVELOPMENT_TEAM' "$pbxproj" && { echo "a DEVELOPMENT_TEAM leaked into the iOS project" >&2; exit 1; }
echo "==> Full gate on the instantiated project"
bash tool/checks.sh
echo "template smoke OK"
