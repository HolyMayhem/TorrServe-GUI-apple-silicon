#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$("$PROJECT_DIR/scripts/build-app.sh" | tail -n 1)"
OUTPUT_DIR="$PROJECT_DIR/dist"
ZIP_PATH="$OUTPUT_DIR/TorrServer-macOS-arm64.zip"
STAGING_DIR="$(mktemp -d /tmp/torrserver-package.XXXXXX)"
STAGED_APP="$STAGING_DIR/TorrServer.app"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"
rm -f "$ZIP_PATH"
ditto --norsrc "$APP_PATH" "$STAGED_APP"
chflags -R nohidden "$STAGED_APP" 2>/dev/null || true
xattr -cr "$STAGED_APP" 2>/dev/null || true
codesign --force --sign - --deep "$STAGED_APP" >/dev/null
xattr -cr "$STAGED_APP" 2>/dev/null || true
codesign --verify --deep --strict "$STAGED_APP"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "$STAGED_APP" "$ZIP_PATH"

echo "$ZIP_PATH"
