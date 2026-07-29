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
GENERATED_ICNS="$GENERATED_DIR/AppIconSystemDark.icns"
NATIVE_ICON_PNG="$GENERATED_DIR/AppIconSystemDark.png"
ICON_COMPOSER_DOCUMENT="$PROJECT_DIR/Resources/AppIcon.iconset/TorrServeGUI.icon"
ICON_COMPOSER_TOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

find "$PROJECT_DIR/Resources" -name ".DS_Store" -type f -delete

swift build -c release --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build -c release --package-path "$PROJECT_DIR" --show-bin-path)"

rm -rf "$APP_PATH"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$GENERATED_DIR"

if [[ -x "$ICON_COMPOSER_TOOL" ]]; then
  "$ICON_COMPOSER_TOOL" \
    "$ICON_COMPOSER_DOCUMENT" \
    --export-image \
    --output-file "$NATIVE_ICON_PNG" \
    --platform macOS \
    --rendition Default \
    --width 1024 \
    --height 1024 \
    --scale 1 >/dev/null

  rm -rf "$GENERATED_ICONSET"
  mkdir -p "$GENERATED_ICONSET"
  sips -z 16 16 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$NATIVE_ICON_PNG" --out "$GENERATED_ICONSET/icon_512x512.png" >/dev/null
  cp "$NATIVE_ICON_PNG" "$GENERATED_ICONSET/icon_512x512@2x.png"
else
  TORRSERVER_ICON_APPEARANCE=dark swift "$PROJECT_DIR/scripts/build-icon.swift" \
    "$PROJECT_DIR/Resources/AppIcon.iconset" \
    "$GENERATED_ICONSET"
fi
iconutil -c icns "$GENERATED_ICONSET" -o "$GENERATED_ICNS"

cp "$BIN_DIR/TorrServerManager" "$MACOS_DIR/TorrServerManager"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/PkgInfo" "$CONTENTS_DIR/PkgInfo"
cp "$GENERATED_ICNS" "$RESOURCES_DIR/AppIconSystemDark.icns"

chflags -R nohidden "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --deep "$APP_PATH"
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true

echo "$APP_PATH"
