#!/bin/bash

set -e

APP_NAME="Text Assistant"
BUNDLE_ID="com.textassistant.app"
VERSION="1.0.0"

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_DIR="$PROJECT_DIR/dist/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building TextAssistant..."

# Build release binary
cd "$PROJECT_DIR"
swift build -c release

echo "📦 Creating app bundle..."

# Clean and create directories
rm -rf "$PROJECT_DIR/dist"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$BUILD_DIR/TextAssistant" "$MACOS_DIR/"

# Copy resources
cp "$PROJECT_DIR/TextAssistant/Resources/Info.plist" "$CONTENTS_DIR/"
cp "$PROJECT_DIR/TextAssistant/Resources/AppIcon.icns" "$RESOURCES_DIR/"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

echo "✅ App bundle created at: $PROJECT_DIR/dist/${APP_NAME}.app"
echo ""
echo "📱 To run the app:"
echo "   open \"$PROJECT_DIR/dist/${APP_NAME}.app\""
echo ""
echo "📀 To create a DMG, run:"
echo "   ./Scripts/create-dmg.sh"
