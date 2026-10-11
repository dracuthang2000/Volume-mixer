#!/usr/bin/env bash
# Builds "build/Volume Mixer.app" from the Swift package (no Xcode needed).
# Usage: scripts/build-app.sh [release|debug]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
APP="build/Volume Mixer.app"

swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/VolumeMixer" "$APP/Contents/MacOS/VolumeMixer"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature: enough to run locally. macOS may ask for audio permission again after each rebuild.
codesign --force --sign - "$APP"

echo "Built $APP"
echo "Run it with: open \"$APP\""
