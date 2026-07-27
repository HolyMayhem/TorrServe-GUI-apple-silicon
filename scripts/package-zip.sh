#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("$PROJECT_DIR/scripts/build-app.sh" | tail -n 1)"
OUTPUT_DIR="$PROJECT_DIR/dist"
ZIP_PATH="$OUTPUT_DIR/TorrServer-macOS-arm64.zip"

mkdir -p "$OUTPUT_DIR"
rm -f "$ZIP_PATH"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"
chflags nohidden "$APP_PATH"
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true
codesign --force --sign - --deep "$APP_PATH" >/dev/null
xattr -d com.apple.FinderInfo "$APP_PATH" 2>/dev/null || true

echo "$ZIP_PATH"
