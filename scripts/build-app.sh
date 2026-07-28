#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="TorrServer.app"
APP_DIR="$PROJECT_DIR/build/app"
APP_PATH="$APP_DIR/$APP_NAME"
CONTENTS_DIR="$APP_PATH/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
GENERATED_DIR="$PROJECT_DIR/build/generated"
GENERATED_ICONSET="$GENERATED_DIR/AppIcon.iconset"
GENERATED_ICNS="$GENERATED_DIR/AppIconDark.icns"

find "$PROJECT_DIR/Resources" -name ".DS_Store" -type f -delete

swift build -c release --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build -c release --package-path "$PROJECT_DIR" --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$GENERATED_DIR"

TORRSERVER_ICON_APPEARANCE=dark swift "$PROJECT_DIR/scripts/build-icon.swift" \
  "$PROJECT_DIR/Resources/AppIcon.iconset" \
  "$GENERATED_ICONSET"
iconutil -c icns "$GENERATED_ICONSET" -o "$GENERATED_ICNS"

cp "$BIN_DIR/TorrServerManager" "$MACOS_DIR/TorrServerManager"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/PkgInfo" "$CONTENTS_DIR/PkgInfo"
cp "$GENERATED_ICNS" "$RESOURCES_DIR/AppIconDark.icns"

chflags -R nohidden "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --deep "$APP_PATH"
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true

echo "$APP_PATH"
