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
COMPILED_ICON_DIR="$GENERATED_DIR/AppIcon"
PARTIAL_INFO_PLIST="$GENERATED_DIR/AppIcon-Info.plist"
SOURCE_ICON="$PROJECT_DIR/Resources/AppIcon.icon"
XCODE_DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
ACTOOL="$XCODE_DEVELOPER_DIR/usr/bin/actool"

find "$PROJECT_DIR/Resources" -name ".DS_Store" -type f -delete

if [[ ! -d "$SOURCE_ICON" ]]; then
  echo "Missing Icon Composer document: $SOURCE_ICON" >&2
  exit 1
fi

if [[ ! -x "$ACTOOL" ]]; then
  echo "Xcode with Icon Composer support is required to build AppIcon.icon." >&2
  exit 1
fi

swift build -c release --package-path "$PROJECT_DIR"
BIN_DIR="$(swift build -c release --package-path "$PROJECT_DIR" --show-bin-path)"

rm -rf "$APP_PATH"
rm -rf "$COMPILED_ICON_DIR"
rm -f "$GENERATED_DIR/AppIconSystemDark.icns" "$PARTIAL_INFO_PLIST"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$COMPILED_ICON_DIR"

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$ACTOOL" \
  --compile "$COMPILED_ICON_DIR" \
  --platform macosx \
  --minimum-deployment-target 12.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$PARTIAL_INFO_PLIST" \
  --warnings \
  --notices \
  --errors \
  "$SOURCE_ICON" >/dev/null

test -f "$COMPILED_ICON_DIR/AppIcon.icns"
test -f "$COMPILED_ICON_DIR/Assets.car"
test "$(plutil -extract CFBundleIconName raw "$PARTIAL_INFO_PLIST")" = "AppIcon"

cp "$BIN_DIR/TorrServerManager" "$MACOS_DIR/TorrServerManager"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/PkgInfo" "$CONTENTS_DIR/PkgInfo"
cp "$COMPILED_ICON_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$COMPILED_ICON_DIR/Assets.car" "$RESOURCES_DIR/Assets.car"

chflags -R nohidden "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --deep "$APP_PATH"
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true

echo "$APP_PATH"
