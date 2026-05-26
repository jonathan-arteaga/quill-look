#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuillLook"
BUILD_ROOT="${QUILLLOOK_BUILD_ROOT:-$HOME/Library/Caches/QuillLook}"
DERIVED_DATA="$BUILD_ROOT/PackageDerivedData"
CONFIGURATION="${QUILLLOOK_CONFIGURATION:-Release}"
PROJECT="$ROOT/$APP_NAME.xcodeproj"
APP_PRODUCT="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
DIST_DIR="$ROOT/dist"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quilllook-package.XXXXXX")"
VERSION="${QUILLLOOK_VERSION:-0.1.0}"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-macOS.zip"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

unregister_bundles_under() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    return
  fi

  while IFS= read -r -d '' bundle_path; do
    /usr/bin/pluginkit -r "$bundle_path" >/dev/null 2>&1 || true
    "$LSREGISTER" -u "$bundle_path" >/dev/null 2>&1 || true
  done < <(/usr/bin/find "$path" \( -name "$APP_NAME.app" -o -name "${APP_NAME}PreviewExtension.appex" \) -print0 2>/dev/null || true)
}

if ! command -v xcodegen >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
  else
    echo "xcodegen is required. Install it with Homebrew, then rerun this script."
    exit 1
  fi
fi

cd "$ROOT"
export COPYFILE_DISABLE=1

rm -rf "$DERIVED_DATA" "$DIST_DIR/$APP_NAME.app" "$ZIP_PATH"
mkdir -p "$DIST_DIR"

xattr -rc "$ROOT/QuillLookPreviewExtension/Resources" "$ROOT/QuillLook/Resources" >/dev/null 2>&1 || true
xcodegen generate

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

/usr/bin/ditto --noqtn "$APP_PRODUCT" "$STAGING_DIR/$APP_NAME.app"
/usr/bin/find "$STAGING_DIR/$APP_NAME.app" -name .DS_Store -delete
/usr/bin/dot_clean -m "$STAGING_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
xattr -cr "$STAGING_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
xattr -d com.apple.FinderInfo "$STAGING_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
codesign --force --deep --sign - --timestamp=none --preserve-metadata=identifier,entitlements,flags "$STAGING_DIR/$APP_NAME.app" >/dev/null
codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/$APP_NAME.app"

(
  cd "$STAGING_DIR"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_NAME.app" "$ZIP_PATH"
)

unregister_bundles_under "$DERIVED_DATA"
rm -rf "$DERIVED_DATA" "$DIST_DIR/$APP_NAME.app"
/usr/bin/qlmanage -r >/dev/null 2>&1 || true
/usr/bin/qlmanage -r cache >/dev/null 2>&1 || true

echo "Packaged $ZIP_PATH"
