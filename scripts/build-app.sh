#!/usr/bin/env bash
# Builds "build/Volume Mixer.app" from the Swift package (no Xcode needed).
# Usage: scripts/build-app.sh [release|debug]
# Release builds are universal (Apple silicon + Intel); debug builds are for this Mac only.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Volume Mixer.app"

if [ "$CONFIG" = "release" ]; then
    # Build each architecture, then merge them into one universal binary.
    BINARIES=()
    for ARCH in arm64 x86_64; do
        swift build -c release --arch "$ARCH"
        BINARIES+=("$(swift build -c release --arch "$ARCH" --show-bin-path)/VolumeMixer")
    done
    mkdir -p build
    lipo -create "${BINARIES[@]}" -output build/VolumeMixer-universal
    BINARY=build/VolumeMixer-universal
else
    swift build -c "$CONFIG"
    BINARY="$(swift build -c "$CONFIG" --show-bin-path)/VolumeMixer"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/VolumeMixer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to run locally. macOS may ask for audio permission again after each rebuild.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open \"$APP\""
