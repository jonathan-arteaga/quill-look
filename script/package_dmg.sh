#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="QuillLook"
VERSION="${QUILLLOOK_VERSION:-0.1.0}"
BUILD_ROOT="${QUILLLOOK_BUILD_ROOT:-$HOME/Library/Caches/QuillLook}"
DERIVED_DATA="$BUILD_ROOT/DmgDerivedData"
CONFIGURATION="${QUILLLOOK_CONFIGURATION:-Release}"
PROJECT="$ROOT/$APP_NAME.xcodeproj"
APP_PRODUCT="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
DIST_DIR="$ROOT/dist"
FINAL_DMG="$DIST_DIR/$APP_NAME-$VERSION-macOS.dmg"
NOTARY_PROFILE="${QUILLLOOK_NOTARY_PROFILE:-quilllook-notary}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/quilllook-dmg.XXXXXX")"
DMG_ROOT="$STAGING_DIR/dmg-root"
BACKGROUND_DIR="$DMG_ROOT/.background"
BACKGROUND_PNG="$BACKGROUND_DIR/background.png"
RW_DMG="$STAGING_DIR/$APP_NAME-$VERSION-rw.dmg"
VOLUME_NAME="$APP_NAME"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cleanup() {
  if [[ -n "${MOUNT_POINT:-}" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
  unregister_bundles_under "$DERIVED_DATA"
  rm -rf "$DERIVED_DATA"
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

require_tool() {
  local tool="$1"
  local install_hint="$2"

  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "$tool is required. $install_hint"
    exit 1
  fi
}

ensure_xcodegen() {
  if command -v xcodegen >/dev/null 2>&1; then
    return
  fi

  if command -v brew >/dev/null 2>&1; then
    brew install xcodegen
    return
  fi

  echo "xcodegen is required. Install it with Homebrew, then rerun this script."
  exit 1
}

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

detect_developer_id() {
  if [[ -n "${QUILLLOOK_DEVELOPER_ID:-}" ]]; then
    echo "$QUILLLOOK_DEVELOPER_ID"
    return
  fi

  /usr/bin/security find-identity -v -p codesigning \
    | /usr/bin/awk -F'"' '/Developer ID Application:/ { print $2; exit }'
}

extract_team_id() {
  local identity="$1"
  if [[ -n "${QUILLLOOK_DEVELOPMENT_TEAM:-}" ]]; then
    echo "$QUILLLOOK_DEVELOPMENT_TEAM"
    return
  fi

  echo "$identity" | /usr/bin/sed -n 's/.*(\([A-Z0-9][A-Z0-9]*\)).*/\1/p'
}

preflight_developer_id() {
  DEVELOPER_ID="$(detect_developer_id)"

  if [[ -z "$DEVELOPER_ID" ]]; then
    echo "No Developer ID Application certificate was found in your keychain."
    echo
    echo "Visible signing identities:"
    /usr/bin/security find-identity -v -p codesigning || true
    echo
    echo "Create or download a Developer ID Application certificate from Apple Developer,"
    echo "install it in Keychain Access, then rerun this script."
    echo
    echo "You can also override detection with:"
    echo '  QUILLLOOK_DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" ./script/package_dmg.sh'
    exit 1
  fi

  DEVELOPMENT_TEAM="$(extract_team_id "$DEVELOPER_ID")"
  if [[ -z "$DEVELOPMENT_TEAM" ]]; then
    echo "Could not determine the Apple team ID from:"
    echo "  $DEVELOPER_ID"
    echo
    echo "Rerun with QUILLLOOK_DEVELOPMENT_TEAM=YOUR_TEAM_ID."
    exit 1
  fi
}

preflight_notary_profile() {
  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    return
  fi

  echo "Notary credentials profile '$NOTARY_PROFILE' was not found or could not authenticate."
  echo
  echo "Create it once with:"
  echo "  xcrun notarytool store-credentials $NOTARY_PROFILE \\"
  echo "    --apple-id YOUR_APPLE_ID \\"
  echo "    --team-id YOUR_TEAM_ID \\"
  echo "    --password YOUR_APP_SPECIFIC_PASSWORD"
  echo
  echo "Or choose another stored profile with QUILLLOOK_NOTARY_PROFILE=profile-name."
  exit 1
}

sign_bundle() {
  local bundle_path="$1"
  local entitlements_path="${2:-}"

  if [[ -n "$entitlements_path" ]]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" \
      --entitlements "$entitlements_path" "$bundle_path"
  else
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" "$bundle_path"
  fi
}

sign_app() {
  local app_path="$1"
  local framework_path="$app_path/Contents/Frameworks/QuillLookCore.framework"
  local extension_path="$app_path/Contents/PlugIns/${APP_NAME}PreviewExtension.appex"

  if [[ -d "$framework_path" ]]; then
    sign_bundle "$framework_path"
  fi

  sign_bundle "$extension_path" "$ROOT/QuillLookPreviewExtension/QuillLookPreviewExtension.entitlements"
  sign_bundle "$app_path" "$ROOT/QuillLook/QuillLook.entitlements"

  codesign --verify --deep --strict --verbose=2 "$app_path"
  spctl --assess --type execute --verbose=4 "$app_path" || {
    echo "Gatekeeper has not accepted the app yet. This can be expected before notarizing the final DMG."
    echo "The notarized DMG assessment runs at the end of this script."
  }
}

build_release_app() {
  cd "$ROOT"
  export COPYFILE_DISABLE=1

  rm -rf "$DERIVED_DATA" "$FINAL_DMG" "$DMG_ROOT"
  mkdir -p "$DIST_DIR" "$BACKGROUND_DIR"

  xattr -rc "$ROOT/QuillLookPreviewExtension/Resources" "$ROOT/QuillLook/Resources" >/dev/null 2>&1 || true
  xcodegen generate

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$APP_NAME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build
}

stage_dmg_contents() {
  /usr/bin/ditto --noqtn "$APP_PRODUCT" "$DMG_ROOT/$APP_NAME.app"
  /bin/ln -s /Applications "$DMG_ROOT/Applications"
  "$ROOT/script/generate_dmg_background.swift" "$BACKGROUND_PNG"

  /usr/bin/find "$DMG_ROOT/$APP_NAME.app" -name .DS_Store -delete
  /usr/bin/dot_clean -m "$DMG_ROOT/$APP_NAME.app" >/dev/null 2>&1 || true
  xattr -cr "$DMG_ROOT/$APP_NAME.app" >/dev/null 2>&1 || true
  xattr -d com.apple.FinderInfo "$DMG_ROOT/$APP_NAME.app" >/dev/null 2>&1 || true

  sign_app "$DMG_ROOT/$APP_NAME.app"
}

mount_rw_dmg() {
  hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_ROOT" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    "$RW_DMG" >/dev/null

  MOUNT_POINT="$(hdiutil attach "$RW_DMG" -readwrite -noverify -noautoopen | /usr/bin/awk -F'\t' '/\/Volumes\// { print $NF; exit }')"
  if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
    echo "Could not mount staging DMG."
    exit 1
  fi
}

layout_dmg_window() {
  /usr/bin/osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {100, 100, 760, 480}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set background picture of viewOptions to file ".background:background.png"
    set position of item "$APP_NAME.app" of container window to {160, 210}
    set position of item "Applications" of container window to {500, 210}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

  /bin/sync
  hdiutil detach "$MOUNT_POINT" -quiet
  MOUNT_POINT=""
}

compress_sign_and_notarize_dmg() {
  hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null
  codesign --force --timestamp --sign "$DEVELOPER_ID" "$FINAL_DMG"
  hdiutil verify "$FINAL_DMG"
  codesign --verify --verbose=2 "$FINAL_DMG"

  xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$FINAL_DMG"
  xcrun stapler validate "$FINAL_DMG"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$FINAL_DMG"
}

require_tool xcrun "Install Xcode command line tools."
require_tool hdiutil "Install Xcode command line tools."
require_tool osascript "This script must run on macOS."
require_tool codesign "Install Xcode command line tools."
require_tool spctl "Install Xcode command line tools."
ensure_xcodegen
preflight_developer_id
preflight_notary_profile
build_release_app
stage_dmg_contents
mount_rw_dmg
layout_dmg_window
compress_sign_and_notarize_dmg
unregister_bundles_under "$DERIVED_DATA"
/usr/bin/qlmanage -r >/dev/null 2>&1 || true
/usr/bin/qlmanage -r cache >/dev/null 2>&1 || true

echo "Created notarized DMG: $FINAL_DMG"
