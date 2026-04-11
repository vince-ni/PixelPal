#!/bin/bash
set -euo pipefail

# Install PixelPal as a LaunchAgent (auto-start on login)
PLIST_NAME="com.pixelpal.app"
PLIST_PATH="$HOME/Library/LaunchAgents/${PLIST_NAME}.plist"
APP_PATH="/Applications/PixelPal.app"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    # Fall back to build dir
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    APP_PATH="$(cd "$SCRIPT_DIR/.." && pwd)/.build/PixelPal.app"
fi

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: PixelPal.app not found"
    exit 1
fi

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${PLIST_NAME}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${APP_PATH}/Contents/MacOS/PixelPal</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "✅ PixelPal LaunchAgent installed. Will auto-start on login."
echo "   To uninstall: launchctl unload $PLIST_PATH && rm $PLIST_PATH"
