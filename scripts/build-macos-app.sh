#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/native"
APP_DIR="$BUILD_DIR/Codex Companion.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swiftc "$ROOT_DIR/native/main.swift" "$ROOT_DIR/native/CodexCompanion.swift" \
  -framework Cocoa \
  -o "$MACOS_DIR/Codex Companion"

cp "$ROOT_DIR/public/assets/pet-placeholder.png" "$RESOURCES_DIR/pet-placeholder.png"
cp "$ROOT_DIR"/public/assets/dancer-frames/dancer-frame-*.png "$RESOURCES_DIR"/
cp -R "$ROOT_DIR/public/assets/dancer-actions" "$RESOURCES_DIR/dancer-actions"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Codex Companion</string>
  <key>CFBundleIdentifier</key>
  <string>local.codex-companion.desktop-pet</string>
  <key>CFBundleName</key>
  <string>Codex Companion</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "$MACOS_DIR/Codex Companion"
echo "$APP_DIR"
