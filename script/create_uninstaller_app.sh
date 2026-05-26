#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  echo "Usage: create_uninstaller_app.sh OUTPUT_APP_PATH"
  exit 64
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_APP="$1"
TEMPLATE_DIR="$ROOT/Distribution/Uninstaller"
EXECUTABLE_NAME="Uninstall QuillLook"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quilllook-uninstaller.XXXXXX")"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
MACOS_DIR="$OUTPUT_APP/Contents/MacOS"
RESOURCES_DIR="$OUTPUT_APP/Contents/Resources"

rm -rf "$OUTPUT_APP"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/ditto "$TEMPLATE_DIR/Info.plist" "$OUTPUT_APP/Contents/Info.plist"
/usr/bin/ditto "$ROOT/QuillLook/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

for arch in arm64 x86_64; do
  xcrun swiftc \
    -O \
    -parse-as-library \
    -target "$arch-apple-macos14.0" \
    -sdk "$SDKROOT" \
    "$TEMPLATE_DIR/UninstallQuillLook.swift" \
    -o "$BUILD_DIR/$arch"
done

/usr/bin/lipo -create "$BUILD_DIR/arm64" "$BUILD_DIR/x86_64" -output "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
/usr/bin/touch "$OUTPUT_APP"
