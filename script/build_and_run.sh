#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="${QUILLLOOK_BUILD_ROOT:-${MARKDOWNQL_BUILD_ROOT:-$HOME/Library/Caches/QuillLook}}"
DERIVED_DATA="$BUILD_ROOT/DerivedData"
CONFIGURATION="${QUILLLOOK_CONFIGURATION:-${MARKDOWNQL_CONFIGURATION:-Release}}"
PROJECT="$ROOT/QuillLook.xcodeproj"
APP_NAME="QuillLook"
LEGACY_APP_NAME="MarkdownQL"
APP_PRODUCT="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
EXTENSION_PRODUCT="$DERIVED_DATA/Build/Products/$CONFIGURATION/${APP_NAME}PreviewExtension.appex"
DIST_DIR="${QUILLLOOK_DIST_DIR:-${MARKDOWNQL_DIST_DIR:-$HOME/Applications}}"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

VERIFY=false
CLEAN_ONLY=false
REFRESH_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --verify)
      VERIFY=true
      ;;
    --clean-stale)
      CLEAN_ONLY=true
      ;;
    --refresh-quicklook)
      REFRESH_ONLY=true
      ;;
    *)
      echo "Unknown option: $arg"
      exit 1
      ;;
  esac
done

refresh_quicklook() {
  /usr/bin/qlmanage -r >/dev/null 2>&1 || true
  /usr/bin/qlmanage -r cache >/dev/null 2>&1 || true
}

unregister_bundle() {
  local path="$1"
  /usr/bin/pluginkit -r "$path" >/dev/null 2>&1 || true
  "$LSREGISTER" -u "$path" >/dev/null 2>&1 || true
}

remove_stale_path() {
  local path="$1"
  local installed_app="$DIST_DIR/$APP_NAME.app"

  if [[ "$path" == "$installed_app" || "$path" == "$installed_app/" ]]; then
    return
  fi

  if [[ -e "$path" ]]; then
    while IFS= read -r -d '' bundle_path; do
      unregister_bundle "$bundle_path"
    done < <(/usr/bin/find "$path" \( -name "$APP_NAME.app" -o -name "${APP_NAME}PreviewExtension.appex" -o -name "$LEGACY_APP_NAME.app" -o -name "${LEGACY_APP_NAME}PreviewExtension.appex" \) -print0 2>/dev/null || true)
    unregister_bundle "$path"
    rm -rf "$path"
    echo "Removed stale QuillLook copy: $path"
  fi
}

clean_stale_bundles() {
  local stale_paths=(
    "$DIST_DIR/$LEGACY_APP_NAME.app"
    "$ROOT/dist/$APP_NAME.app"
    "$ROOT/dist/$LEGACY_APP_NAME.app"
    "$ROOT/build/DerivedData"
    "$BUILD_ROOT/TestDerivedData"
    "$BUILD_ROOT/PackageDerivedData"
    "$HOME/Library/Caches/$LEGACY_APP_NAME"
    "$DERIVED_DATA/Build/Products/Debug/$APP_NAME.app"
    "$DERIVED_DATA/Build/Products/Debug/${APP_NAME}PreviewExtension.appex"
    "$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
    "$DERIVED_DATA/Build/Products/Release/${APP_NAME}PreviewExtension.appex"
  )

  for path in "${stale_paths[@]}"; do
    remove_stale_path "$path"
  done

  if [[ -d "$DIST_DIR/$APP_NAME.app" ]]; then
    "$LSREGISTER" -f -R -trusted "$DIST_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
  fi
  refresh_quicklook
}

if [[ "$REFRESH_ONLY" == true && "$CLEAN_ONLY" == false && "$VERIFY" == false ]]; then
  refresh_quicklook
  echo "Quick Look caches refreshed."
  exit 0
fi

if [[ "$CLEAN_ONLY" == true ]]; then
  clean_stale_bundles
  echo "Stale QuillLook copies cleaned."
  exit 0
fi

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
clean_stale_bundles
xattr -rc "$ROOT/QuillLookPreviewExtension/Resources" "$ROOT/QuillLook/Resources" >/dev/null 2>&1 || true
xcodegen generate

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

xcodebuild \
  -project "$PROJECT" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

mkdir -p "$DIST_DIR"
unregister_bundle "$DIST_DIR/$APP_NAME.app"
rm -rf "$DIST_DIR/$APP_NAME.app"
/usr/bin/ditto --noqtn "$APP_PRODUCT" "$DIST_DIR/$APP_NAME.app"
xattr -rc "$DIST_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
codesign --force --deep --sign - --timestamp=none --preserve-metadata=identifier,entitlements,flags "$DIST_DIR/$APP_NAME.app" >/dev/null
"$LSREGISTER" -f -R -trusted "$DIST_DIR/$APP_NAME.app" >/dev/null 2>&1 || true
remove_stale_path "$APP_PRODUCT"
remove_stale_path "$EXTENSION_PRODUCT"
refresh_quicklook
/usr/bin/open -n "$DIST_DIR/$APP_NAME.app"

if [[ "$VERIFY" == true ]]; then
  sleep 1
  pgrep -x "$APP_NAME" >/dev/null
fi

echo "Launched $DIST_DIR/$APP_NAME.app"
