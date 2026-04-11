#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="PixelPal"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Building $APP_NAME (Universal Binary)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64 2>&1

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/Assets"

# Copy binary
cp "$BUILD_DIR/apple/Products/Release/PixelPal" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null \
  || cp "$BUILD_DIR/release/PixelPal" "$APP_BUNDLE/Contents/MacOS/$APP_NAME" 2>/dev/null \
  || { echo "ERROR: Cannot find built binary"; exit 1; }

# Copy assets
if [ -d "$PROJECT_DIR/Assets" ]; then
    cp -r "$PROJECT_DIR/Assets/"* "$APP_BUNDLE/Contents/Resources/Assets/"
fi

# Copy shell integration
cp "$PROJECT_DIR/Shell/pixelpal.zsh" "$APP_BUNDLE/Contents/Resources/"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>PixelPal</string>
    <key>CFBundleIdentifier</key>
    <string>com.pixelpal.app</string>
    <key>CFBundleName</key>
    <string>PixelPal</string>
    <key>CFBundleVersion</key>
    <string>0.2.0</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>SUFeedURL</key>
    <string>https://pixelpal.app/appcast.xml</string>
</dict>
</plist>
PLIST

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To install as LaunchAgent:  bash $PROJECT_DIR/Scripts/install-launchagent.sh"
