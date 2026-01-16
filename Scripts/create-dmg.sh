#!/bin/bash

set -e

APP_NAME="Text Assistant"
DMG_NAME="TextAssistant"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$DIST_DIR/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${DMG_NAME}-${VERSION}.dmg"
TEMP_DMG="$DIST_DIR/temp.dmg"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at $APP_PATH"
    echo "   Run ./Scripts/build-app.sh first"
    exit 1
fi

echo "📀 Creating DMG..."

# Remove old DMG if exists
rm -f "$DMG_PATH" "$TEMP_DMG"

# Create temporary DMG
hdiutil create -srcfolder "$APP_PATH" -volname "$APP_NAME" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW "$TEMP_DMG"

# Mount DMG
DEVICE=$(hdiutil attach -readwrite -noverify "$TEMP_DMG" | grep "/Volumes" | head -1)
MOUNT_DIR=$(echo "$DEVICE" | awk -F'\t' '{print $NF}')

echo "   Mounted at: $MOUNT_DIR"

# Add Applications symlink
ln -sf /Applications "$MOUNT_DIR/Applications"

# Unmount
sync
hdiutil detach "$MOUNT_DIR"

# Convert to compressed DMG
hdiutil convert "$TEMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

# Cleanup
rm -f "$TEMP_DMG"

echo "✅ DMG created: $DMG_PATH"
echo ""
echo "📤 Ready to upload to GitHub Releases!"
