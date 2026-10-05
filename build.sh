#!/bin/bash

# Build script for NetCheck macOS application

set -e

echo "Building NetCheck..."

# Build the project
swift build -c release

# Create app bundle structure
APP_NAME="NetCheck"
APP_PATH="$APP_NAME.app"
CONTENTS="$APP_PATH/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Remove existing app bundle if exists
rm -rf "$APP_PATH"

# Create directory structure
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy the executable
cp .build/release/NetCheck "$MACOS/"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>NetCheck</string>
    <key>CFBundleIdentifier</key>
    <string>com.netcheck.app</string>
    <key>CFBundleName</key>
    <string>NetCheck</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2.0</string>
    <key>CFBundleVersion</key>
    <string>1.2.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <string>1</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Set executable permissions
chmod +x "$MACOS/NetCheck"

echo "Build complete: $APP_PATH"
echo "You can now drag this to /Applications folder"
