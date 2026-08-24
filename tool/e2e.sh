#!/usr/bin/env bash
# Patrol e2e runner (spec section 10): reads tool/e2e.yaml, finds or creates
# the declared device, boots it, runs the registered flows with patrol under
# a hard wall-clock guard, and shuts the device down in CI (keeps it alive
# locally - a warm emulator is the developer's inner loop).
#
#   tool/e2e.sh [android|ios] [-t <test file>] [--device <id>] [--list]
#
# No "first available device" fallback: the device named in e2e.yaml is the
# one that runs (a running emulator is reused only when it IS that AVD), or
# the script explains what is missing. Exit codes: 0 all tests passed;
# patrol's own non-zero exit on test failures/errors; 2 usage; 3 e2e not
# performed (reason on stderr - report it verbatim, never fabricate a
# result); 124/142 when the wall-clock guard killed the run.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/tool/common.sh"
cd "$ROOT_DIR"

PATROL_CLI_VERSION="4.7.0"   # <-> patrol 4.9.0 in app/pubspec.yaml (docs/workflow/maintenance.md)
PLATFORM=""; TEST_FILE=""; DEVICE=""; LIST=false
usage() { echo "usage: tool/e2e.sh [android|ios] [-t <test file>] [--device <id>] [--list]" >&2; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    android|ios) PLATFORM="$1"; shift ;;
    -t) [[ $# -ge 2 && $2 != -* ]] || { usage; exit 2; }; TEST_FILE="$2"; shift 2 ;;
    --device) [[ $# -ge 2 && $2 != -* ]] || { usage; exit 2; }; DEVICE="$2"; shift 2 ;;
    --list) LIST=true; shift ;;
    *) usage; exit 2 ;;
  esac
done
not_performed() { echo "e2e not performed: $*" >&2; exit 3; }

# `-t` is spelled the way docs/reference/critical_flows.md spells it: relative
# to the REPOSITORY ROOT (app/integration_test/...). patrol runs inside app/,
# so resolve the path here, while the root is still the frame of reference -
# an absolute path and an app-relative one are accepted too.
if [[ -n "$TEST_FILE" ]]; then
  if [[ "$TEST_FILE" != /* ]]; then
    if   [[ -f "$ROOT_DIR/$TEST_FILE"     ]]; then TEST_FILE="$ROOT_DIR/$TEST_FILE"
    elif [[ -f "$ROOT_DIR/app/$TEST_FILE" ]]; then TEST_FILE="$ROOT_DIR/app/$TEST_FILE"
    fi
  fi
  if [[ ! -f "$TEST_FILE" ]]; then
    echo "no such test file: $TEST_FILE (paths are relative to the repository root, e.g. app/integration_test/x_test.dart)" >&2
    exit 2
  fi
fi

# --- config (typed loader; prints KEY='value' lines)
config="$(run_dart run tool/e2e_config.dart)" || not_performed "tool/e2e.yaml is invalid (see above)"
eval "$config"
[[ -n "$PLATFORM" ]] || PLATFORM="$DEFAULT_PLATFORM"

# --list is a pure config echo: it must work on a machine with no patrol_cli
# and no Flutter SDK resolved, so it comes before every tooling gate.
if [[ "$LIST" == "true" ]]; then
  echo "android: avd=$ANDROID_AVD_NAME profile=$ANDROID_DEVICE_PROFILE api=$ANDROID_API_LEVEL images: arm64=$ANDROID_SYSTEM_IMAGE_ARM64 x86_64=$ANDROID_SYSTEM_IMAGE_X86_64"
  echo "ios: simulator=$IOS_SIMULATOR_NAME type='$IOS_DEVICE_TYPE' runtime='$IOS_RUNTIME'"
  exit 0
fi

# --- patrol_cli, fvm-first like common.sh
patrol() {
  if command -v fvm >/dev/null 2>&1; then fvm dart pub global run patrol_cli:main "$@"
  else dart pub global run patrol_cli:main "$@"; fi
}
# Tolerant of the banner format: the first x.y.z in `patrol --version`.
installed="$(patrol --version 2>/dev/null | grep -o -E '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
[[ "$installed" == "$PATROL_CLI_VERSION" ]] || not_performed "patrol_cli $PATROL_CLI_VERSION is required (found '${installed:-none}'): dart pub global activate patrol_cli $PATROL_CLI_VERSION"
export PATROL_FLUTTER_COMMAND
if command -v fvm >/dev/null 2>&1; then
  PATROL_FLUTTER_COMMAND="$(fvm exec which flutter)" \
    || not_performed "fvm could not resolve the pinned Flutter SDK (fvm install)"
else PATROL_FLUTTER_COMMAND="flutter"; fi

PROVISION_TIMEOUT="$CHECKS_E2E_PROVISION_TIMEOUT"   # image install / boot, bounded like everything else
booted_device=""   # set BEFORE any wait so cleanup can always reach it
cleanup() {
  rm -f "$ROOT_DIR/app/integration_test/test_bundle.dart"
  if is_ci && [[ -n "$booted_device" ]]; then
    case "$PLATFORM" in
      android) "$ANDROID_HOME/platform-tools/adb" -s "$booted_device" emu kill >/dev/null 2>&1 || true ;;
      ios) xcrun simctl shutdown "$booted_device" >/dev/null 2>&1 || true ;;
    esac
  fi
}
trap cleanup EXIT

# --- device
case "$PLATFORM" in
  android)
    ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
    TOOLS="$ANDROID_HOME/cmdline-tools/latest/bin"
    [[ -x "$TOOLS/avdmanager" && -x "$TOOLS/sdkmanager" && -x "$ANDROID_HOME/emulator/emulator" ]] \
      || not_performed "Android SDK command-line tools + emulator not found under $ANDROID_HOME (set ANDROID_HOME)"
    case "$(uname -m)" in
      arm64|aarch64) IMAGE="$ANDROID_SYSTEM_IMAGE_ARM64" ;;
      x86_64) IMAGE="$ANDROID_SYSTEM_IMAGE_X86_64" ;;
      *) not_performed "unsupported host architecture $(uname -m)" ;;
    esac
    ADB="$ANDROID_HOME/platform-tools/adb"
    if [[ -z "$DEVICE" ]]; then
      # A running emulator is reused ONLY if it is the declared AVD; any
      # other running emulator is an error, not a fallback.
      others=""
      for serial in $("$ADB" devices | awk '/^emulator-[0-9]+[[:space:]]+device/ {print $1}'); do
        # `|| true`: an unreadable console must not abort the script with
        # adb's own status (it would read as a failed e2e run). It also
        # keeps the name adb did print before `head -n 1` closed the pipe
        # on it - SIGPIPE fails the pipeline under `pipefail`.
        avd="$("$ADB" -s "$serial" emu avd name 2>/dev/null | head -n 1 | tr -d '\r')" || true
        if [[ "$avd" == "$ANDROID_AVD_NAME" ]]; then DEVICE="$serial"; echo "    using running $ANDROID_AVD_NAME ($DEVICE)"; break; fi
        others="$others $serial($avd)"
      done
      [[ -n "$DEVICE" || -z "$others" ]] || not_performed "running emulator(s)$others are not the declared '$ANDROID_AVD_NAME' (shut them down, or pass --device <serial> to use one explicitly)"
    fi
    if [[ -z "$DEVICE" ]]; then
      # Captured, then matched with grep -F: a `grep -q` closing the pipe early
      # can kill the producer with SIGPIPE, and under `pipefail` that reads as
      # "not installed". -F/-x: these are names, not regexes.
      avds="$("$TOOLS/avdmanager" list avd -c 2>/dev/null || true)"
      if ! grep -qxF -- "$ANDROID_AVD_NAME" <<<"$avds"; then
        images="$("$TOOLS/sdkmanager" --list_installed 2>/dev/null || true)"
        grep -qF -- "$IMAGE" <<<"$images" \
          || { echo "    installing $IMAGE"; yes | "$TOOLS/sdkmanager" --licenses >/dev/null 2>&1 || true; run_guarded "$PROVISION_TIMEOUT" "$TOOLS/sdkmanager" "$IMAGE" >/dev/null || not_performed "could not install $IMAGE"; }
        echo "    creating AVD $ANDROID_AVD_NAME ($ANDROID_DEVICE_PROFILE, $IMAGE)"
        echo no | "$TOOLS/avdmanager" create avd -n "$ANDROID_AVD_NAME" -k "$IMAGE" -d "$ANDROID_DEVICE_PROFILE" >/dev/null \
          || not_performed "avdmanager could not create $ANDROID_AVD_NAME"
      fi
      # Explicit console port: the serial is known before the device exists,
      # so every adb call below is addressed (a second attached phone would
      # otherwise make a bare `adb wait-for-device` fail).
      PORT="${E2E_EMULATOR_PORT:-5554}"
      DEVICE="emulator-$PORT"
      "$ANDROID_HOME/emulator/emulator" -port "$PORT" -avd "$ANDROID_AVD_NAME" -no-window -no-audio -no-boot-anim -no-snapshot-save >/dev/null 2>&1 &
      booted_device="$DEVICE"
      run_guarded "$PROVISION_TIMEOUT" "$ADB" -s "$DEVICE" wait-for-device || not_performed "emulator $DEVICE did not appear"
      for _ in $(seq 1 $((PROVISION_TIMEOUT / 2))); do
        [[ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
        sleep 2
      done
      [[ "$("$ADB" -s "$DEVICE" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] || not_performed "emulator $DEVICE did not finish booting within ${PROVISION_TIMEOUT}s"
    fi ;;
  ios)
    command -v xcrun >/dev/null 2>&1 || not_performed "xcrun not found (Xcode required)"
    if [[ -z "$DEVICE" ]]; then
      major="${IOS_RUNTIME#iOS }"; major="${major%%.*}"
      runtime_id="$(xcrun simctl list runtimes -j | run_dart run tool/e2e_pick_runtime.dart "$major")" \
        || not_performed "no installed iOS $major.x simulator runtime (xcrun simctl list runtimes); install one in Xcode > Settings > Components"
      found="$(xcrun simctl list devices -j | run_dart run tool/e2e_pick_device.dart "$IOS_SIMULATOR_NAME" "$runtime_id")" || found=""
      DEVICE="${found%% *}"; state="${found#* }"
      if [[ -z "$DEVICE" ]]; then
        echo "    creating simulator $IOS_SIMULATOR_NAME ($IOS_DEVICE_TYPE, $runtime_id)"
        DEVICE="$(xcrun simctl create "$IOS_SIMULATOR_NAME" "$IOS_DEVICE_TYPE" "$runtime_id")" \
          || not_performed "simctl could not create '$IOS_DEVICE_TYPE' on $runtime_id (xcrun simctl list devicetypes)"
        state="Shutdown"
      fi
      if [[ "$state" != "Booted" ]]; then
        booted_device="$DEVICE"
        xcrun simctl boot "$DEVICE" || not_performed "simctl could not boot $DEVICE"
        run_guarded "$PROVISION_TIMEOUT" xcrun simctl bootstatus "$DEVICE" -b >/dev/null || not_performed "simulator $DEVICE did not finish booting within ${PROVISION_TIMEOUT}s"
      fi
    fi ;;
esac

# --- run (functions are invisible to run_guarded's exec, hence the explicit binaries)
args=(test -d "$DEVICE")
[[ -n "$TEST_FILE" ]] && args+=(-t "$TEST_FILE")
echo "==> patrol test on $PLATFORM ($DEVICE)"
( cd "$ROOT_DIR/app"
  if command -v fvm >/dev/null 2>&1; then
    run_guarded "$CHECKS_E2E_TIMEOUT" fvm dart pub global run patrol_cli:main "${args[@]}"
  else
    run_guarded "$CHECKS_E2E_TIMEOUT" dart pub global run patrol_cli:main "${args[@]}"
  fi )
