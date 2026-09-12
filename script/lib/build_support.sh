#!/usr/bin/env bash
# Shared local build helpers. This file deliberately contains no signing key:
# Sparkle keeps the private update key in the login Keychain.

set -euo pipefail

BUILD_SUPPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$BUILD_SUPPORT_DIR/../.." && pwd)"

# shellcheck source=../version.env
source "$ROOT_DIR/script/version.env"
# shellcheck source=../sparkle.env
source "$ROOT_DIR/script/sparkle.env"

APP_NAME="SonicCage"
BUNDLE_ID="com.fraise.SonicCage"
MIN_SYSTEM_VERSION="14.0"
BUNDLE_REQUIREMENT='=designated => identifier "com.fraise.SonicCage"'
MODULE_CACHE_DIR="${TMPDIR:-/tmp}/sonic-cage-module-cache"
DIST_DIR="$ROOT_DIR/dist"
ICON_SOURCE="$ROOT_DIR/Assets/SonicCage-liquid-glass.icns"
INFO_TEMPLATE="$ROOT_DIR/Assets/Info.plist.template"
SPARKLE_FRAMEWORK_SOURCE="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
SPARKLE_TOOLS_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
SIGNING_IDENTITY="${SONICCAGE_SIGNING_IDENTITY:--}"

fail() {
    echo "error: $*" >&2
    exit 1
}

require_sparkle_configuration() {
    [[ "$APP_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || fail "APP_VERSION in script/version.env must use numeric dotted components."
    [[ "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || fail "BUILD_NUMBER in script/version.env must be a positive integer."
    [[ "$SPARKLE_FEED_URL" == https://* ]] || fail "SPARKLE_FEED_URL must use HTTPS."
    [[ "$GITHUB_REPOSITORY" == */* ]] || fail "GITHUB_REPOSITORY must use owner/repository form."
    [[ "$SPARKLE_KEYCHAIN_ACCOUNT" == com.fraise.SonicCage.* ]] || fail "Use SonicCage's dedicated Sparkle Keychain account."
    [[ "$SPARKLE_PUBLIC_ED_KEY" =~ ^[A-Za-z0-9+/=]{40,100}$ ]] || fail "No Sparkle public key is configured. Run ./script/setup_sparkle_key.sh once, approve macOS's Keychain prompt, then rebuild."
}

prepare_swift_build() {
    mkdir -p "$MODULE_CACHE_DIR"
    export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
    export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
}

sparkle_tool() {
    local name="$1"
    local path="$SPARKLE_TOOLS_DIR/$name"
    [[ -x "$path" ]] || fail "Sparkle tool $name is unavailable. Run a Swift build first so SwiftPM fetches Sparkle."
    printf '%s\n' "$path"
}

write_info_plist() {
    local plist="$1"
    [[ -f "$INFO_TEMPLATE" ]] || fail "Missing $INFO_TEMPLATE."
    /usr/bin/ditto "$INFO_TEMPLATE" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$plist"
    /usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$plist"
    /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_ED_KEY" "$plist"
    /usr/bin/plutil -lint "$plist" >/dev/null
}

sign_path() {
    local path="$1"
    if [[ "$SIGNING_IDENTITY" == "-" ]]; then
        # Ad-hoc development signatures have no Team ID. Enabling the
        # hardened runtime here would make macOS library validation reject the
        # embedded framework, despite both components being correctly signed.
        /usr/bin/codesign --force --sign - --timestamp=none "$path"
    else
        /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$path"
    fi
}

sign_app_bundle() {
    local app_bundle="$1"
    local framework="$app_bundle/Contents/Frameworks/Sparkle.framework"
    local current="$framework/Versions/Current"

    # Sign innermost bundles first. Do not use --deep: every nested Sparkle
    # component is named deliberately, so failures cannot be hidden.
    sign_path "$current/XPCServices/Downloader.xpc"
    sign_path "$current/XPCServices/Installer.xpc"
    sign_path "$current/Updater.app"
    sign_path "$current/Autoupdate"
    sign_path "$framework"

    if [[ "$SIGNING_IDENTITY" == "-" ]]; then
        /usr/bin/codesign --force --sign - --timestamp=none --requirements "$BUNDLE_REQUIREMENT" "$app_bundle"
    else
        /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp --requirements "$BUNDLE_REQUIREMENT" "$app_bundle"
    fi
}

verify_app_bundle() {
    local app_bundle="$1"
    local binary="$app_bundle/Contents/MacOS/$APP_NAME"
    local framework="$app_bundle/Contents/Frameworks/Sparkle.framework"
    local current="$framework/Versions/Current"
    local plist="$app_bundle/Contents/Info.plist"

    [[ -x "$binary" ]] || fail "The app executable is missing."
    [[ -d "$framework" && -L "$framework/Versions/Current" ]] || fail "Sparkle.framework or its Current symlink is missing."
    [[ -x "$current/Autoupdate" ]] || fail "Sparkle's Autoupdate helper is missing."
    [[ -d "$current/Updater.app" ]] || fail "Sparkle's Updater.app helper is missing."
    [[ -d "$current/XPCServices/Downloader.xpc" ]] || fail "Sparkle's Downloader XPC helper is missing."
    [[ -d "$current/XPCServices/Installer.xpc" ]] || fail "Sparkle's Installer XPC helper is missing."
    /usr/bin/otool -l "$binary" | /usr/bin/grep -A2 'LC_RPATH' | /usr/bin/grep -Fq '@executable_path/../Frameworks' || fail "The app executable lacks Sparkle's framework runpath."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "$APP_VERSION" ]] || fail "The app version was not written to Info.plist."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")" == "$BUILD_NUMBER" ]] || fail "The app build number was not written to Info.plist."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist")" == "$SPARKLE_PUBLIC_ED_KEY" ]] || fail "The Sparkle public key was not written to Info.plist."
    [[ "$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$plist")" == "$SPARKLE_FEED_URL" ]] || fail "The Sparkle feed URL was not written to Info.plist."

    /usr/bin/codesign --verify --strict --verbose=2 "$current/XPCServices/Downloader.xpc"
    /usr/bin/codesign --verify --strict --verbose=2 "$current/XPCServices/Installer.xpc"
    /usr/bin/codesign --verify --strict --verbose=2 "$current/Updater.app"
    /usr/bin/codesign --verify --strict --verbose=2 "$current/Autoupdate"
    /usr/bin/codesign --verify --strict --verbose=2 "$framework"
    /usr/bin/codesign --verify --strict --verbose=2 "$app_bundle"
}

build_soniccage() {
    local configuration="$1"
    local app_bundle="${2:-$DIST_DIR/$APP_NAME.app}"
    local contents="$app_bundle/Contents"
    local macos="$contents/MacOS"
    local resources="$contents/Resources"
    local frameworks="$contents/Frameworks"
    local binary

    [[ "$configuration" == "debug" || "$configuration" == "release" ]] || fail "Build configuration must be debug or release."
    require_sparkle_configuration
    prepare_swift_build
    cd "$ROOT_DIR"
    swift build --disable-sandbox --configuration "$configuration"
    binary="$(swift build --disable-sandbox --configuration "$configuration" --show-bin-path)/$APP_NAME"
    [[ -x "$binary" ]] || fail "SwiftPM did not produce $APP_NAME."
    [[ -d "$SPARKLE_FRAMEWORK_SOURCE" ]] || fail "SwiftPM did not fetch the expected Sparkle.framework."

    # The target is a single, known generated bundle—not a broad workspace
    # path. This keeps rebuilding safe in an otherwise dirty working copy.
    rm -rf "$app_bundle"
    mkdir -p "$macos" "$resources" "$frameworks"
    /usr/bin/ditto "$binary" "$macos/$APP_NAME"
    /usr/bin/ditto "$ICON_SOURCE" "$resources/SonicCage.icns"
    # ditto preserves the versioned-framework symlinks, executable bits, and
    # code-signature resources that a recursive copy can accidentally lose.
    /usr/bin/ditto "$SPARKLE_FRAMEWORK_SOURCE" "$frameworks/Sparkle.framework"
    write_info_plist "$contents/Info.plist"
    printf 'APPL????' > "$contents/PkgInfo"
    sign_app_bundle "$app_bundle"
    verify_app_bundle "$app_bundle"
}
