#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("$PROJECT_DIR/scripts/build-app.sh" | tail -n 1)"
OUTPUT_DIR="$PROJECT_DIR/dist"
ZIP_PATH="$OUTPUT_DIR/TorrServer-macOS-arm64.zip"

mkdir -p "$OUTPUT_DIR"
rm -f "$ZIP_PATH"
chflags -R nohidden "$APP_PATH" 2>/dev/null || true
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --deep "$APP_PATH" >/dev/null
xattr -cr "$APP_PATH" 2>/dev/null || true
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo "$ZIP_PATH"
