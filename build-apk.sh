#!/bin/bash
# Builds APKs and copies them to the repo root for easy access.
#
# Usage:
#   ./build-apk.sh          # builds both debug + release
#   ./build-apk.sh debug    # builds debug only (Taper DEV, com.vincent.taper.dev)
#   ./build-apk.sh release  # builds release only (Taper, com.vincent.taper)
#
# Both versions can be installed side-by-side on your phone because
# they have different applicationIds — like running staging + production
# of a Laravel app on different subdomains.

set -e

MODE="${1:-both}"

build_debug() {
    echo "Building debug APK..."
    flutter build apk --debug
    cp build/app/outputs/flutter-apk/app-debug.apk ./taper-debug.apk
    echo "Done! Debug APK saved to ./taper-debug.apk"
}

build_release() {
    echo "Building release APK..."
    flutter build apk --release
    cp build/app/outputs/flutter-apk/app-release.apk ./taper-release.apkColors.tea
    echo "Done! Release APK saved to ./taper-release.apk"
}

case "$MODE" in
    both)
        build_debug
        echo ""
        build_release
        ;;
    debug)
        build_debug
        ;;
    release)
        build_release
        ;;
    *)
        echo "Unknown mode: $MODE"
        echo "Usage: ./build-apk.sh [debug|release]"
        exit 1
        ;;
esac
