#!/bin/bash
# Builds a release APK with Flutter and installs it on connected physical devices.
#
# Usage:
#   ./build-release.sh              # build + install on all physical devices
#   DEVICE=<serial> ./build-release.sh  # install on a specific device only
#
# ADB is found automatically by checking (in order):
#   1. $ADB env var
#   2. adb on $PATH
#   3. sdk.dir in android/local.properties
#   4. $ANDROID_SDK_ROOT or $ANDROID_HOME
#   5. macOS default: ~/Library/Android/sdk
#
# Think of this like a deploy script — build the artifact, then push it
# to connected "servers" (devices). Similar to running `php artisan deploy`
# with auto-detected targets.

set -euo pipefail

# Resolve the project root (same directory as this script)
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
APK_NAME="taper-release.apk"
APK_PATH="$PROJECT_ROOT/$APK_NAME"

# --- ADB discovery helpers ---
# These try multiple locations to find adb, just like how Laravel's
# env() helper cascades through .env -> system env -> default.

read_sdk_dir() {
    local properties_file="$PROJECT_ROOT/android/local.properties"
    if [ ! -f "$properties_file" ]; then
        return 0
    fi
    # Parse sdk.dir from local.properties (escaped colons → real colons)
    sed -n 's#^sdk.dir=##p' "$properties_file" | sed 's#\\:#:#g' | head -n 1
}

find_adb() {
    # Check $ADB env var first (explicit override, like APP_ENV)
    if [ -n "${ADB:-}" ] && [ -x "${ADB}" ]; then
        echo "${ADB}"; return 0
    fi

    # Check $PATH (most common case)
    if command -v adb >/dev/null 2>&1; then
        command -v adb; return 0
    fi

    # Check android/local.properties sdk.dir
    local sdk_dir
    sdk_dir="$(read_sdk_dir)"
    if [ -n "$sdk_dir" ] && [ -x "$sdk_dir/platform-tools/adb" ]; then
        echo "$sdk_dir/platform-tools/adb"; return 0
    fi

    # Check ANDROID_SDK_ROOT / ANDROID_HOME
    if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -x "${ANDROID_SDK_ROOT}/platform-tools/adb" ]; then
        echo "${ANDROID_SDK_ROOT}/platform-tools/adb"; return 0
    fi
    if [ -n "${ANDROID_HOME:-}" ] && [ -x "${ANDROID_HOME}/platform-tools/adb" ]; then
        echo "${ANDROID_HOME}/platform-tools/adb"; return 0
    fi

    # macOS default Android Studio install location
    if [ -x "$HOME/Library/Android/sdk/platform-tools/adb" ]; then
        echo "$HOME/Library/Android/sdk/platform-tools/adb"; return 0
    fi

    return 1
}

# Returns device serial numbers, one per line
list_connected_devices() {
    local adb_bin="$1"
    "$adb_bin" devices | awk 'NR > 1 && $2 == "device" { print $1 }'
}

# Returns only physical devices (filters out emulator-* serials)
list_physical_devices() {
    local adb_bin="$1"
    list_connected_devices "$adb_bin" | grep -v '^emulator-' || true
}

# Pretty-prints a device serial with its model name (if available)
describe_device() {
    local adb_bin="$1"
    local serial="$2"
    local model

    model="$("$adb_bin" devices -l | awk -v s="$serial" '$1 == s && $2 == "device" { print }' \
        | sed -n 's/.* model:\([^ ]*\).*/\1/p' | tr '_' ' ')"

    if [ -n "$model" ]; then
        echo "$serial ($model)"
    else
        echo "$serial"
    fi
}

# --- Build ---

echo "Building release APK with Flutter..."
cd "$PROJECT_ROOT"
flutter build apk --release

# Copy to project root for easy access (like `php artisan build` dropping
# the artifact in a predictable location)
cp build/app/outputs/flutter-apk/app-release.apk "$APK_PATH"

echo ""
echo "APK ready: $APK_PATH"
echo "Size: $(du -h "$APK_PATH" | cut -f1)"

# --- Install on connected devices ---

ADB_BIN="$(find_adb)" || {
    echo ""
    echo "Could not find adb — skipping device install."
    echo "Set ADB, ANDROID_SDK_ROOT, or add adb to your PATH."
    exit 0
}

# If DEVICE is set, install only on that serial; otherwise install on
# all connected physical devices (skip emulators).
if [ -n "${DEVICE:-}" ]; then
    # Verify the requested device is actually connected
    if ! list_connected_devices "$ADB_BIN" | grep -Fxq "$DEVICE"; then
        echo ""
        echo "Requested device '$DEVICE' is not connected."
        echo "Connected devices:"
        "$ADB_BIN" devices -l | sed -n '2,$p'
        exit 1
    fi
    INSTALL_TARGETS="$DEVICE"
else
    INSTALL_TARGETS="$(list_physical_devices "$ADB_BIN")"
fi

if [ -n "$INSTALL_TARGETS" ]; then
    echo ""
    echo "Installing on connected physical devices..."
    while IFS= read -r serial; do
        [ -n "$serial" ] || continue
        echo "  → $(describe_device "$ADB_BIN" "$serial")"
        "$ADB_BIN" -s "$serial" install -r "$APK_PATH"
    done <<< "$INSTALL_TARGETS"
else
    echo ""
    echo "No connected physical devices found. Skipping install."
fi
