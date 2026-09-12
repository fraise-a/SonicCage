#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/build_support.sh
source "$SCRIPT_DIR/lib/build_support.sh"

# Validate the existing release configuration before --next is allowed to
# change the single version source. A missing Keychain setup therefore cannot
# leave a half-prepared version bump behind.
require_sparkle_configuration

if [[ "${1:-}" == "--next" ]]; then
    NEXT_VERSION="${2:-}"
    [[ $# -eq 2 && "$NEXT_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]] || {
        echo "usage: $0 [--next <numeric.dotted.version>]" >&2
        exit 2
    }
    [[ "$NEXT_VERSION" != "$APP_VERSION" ]] || fail "The next version must differ from $APP_VERSION."

    NEXT_BUILD_NUMBER="$((10#$BUILD_NUMBER + 1))"
    TEMP_VERSION_FILE="$(mktemp "$SCRIPT_DIR/.version.env.XXXXXX")"
    trap 'rm -f "$TEMP_VERSION_FILE"' EXIT
    {
        printf '%s\n' "# SonicCage's single version source of truth. CFBundleVersion must only move"
        printf '%s\n' '# forward: Sparkle uses it to decide whether an update is newer.'
        printf 'APP_VERSION="%s"\n' "$NEXT_VERSION"
        printf 'BUILD_NUMBER="%s"\n' "$NEXT_BUILD_NUMBER"
    } > "$TEMP_VERSION_FILE"
    mv "$TEMP_VERSION_FILE" "$SCRIPT_DIR/version.env"
    trap - EXIT
    APP_VERSION="$NEXT_VERSION"
    BUILD_NUMBER="$NEXT_BUILD_NUMBER"
fi

[[ $# -eq 0 || "${1:-}" == "--next" ]] || {
    echo "usage: $0 [--next <numeric.dotted.version>]" >&2
    exit 2
}

RELEASE_DIR="$ROOT_DIR/release"
ARCHIVE_DIR="$RELEASE_DIR/archives"
RELEASE_APP="$RELEASE_DIR/$APP_NAME-$APP_VERSION.app"
ARCHIVE_NAME="$APP_NAME-$APP_VERSION.dmg"
ARCHIVE_PATH="$ARCHIVE_DIR/$ARCHIVE_NAME"
APPCAST_PATH="$ARCHIVE_DIR/appcast.xml"
ROOT_APPCAST="$ROOT_DIR/appcast.xml"
DOWNLOAD_PREFIX="https://github.com/$GITHUB_REPOSITORY/releases/download/$APP_VERSION/"

[[ ! -e "$ARCHIVE_PATH" ]] || fail "$ARCHIVE_PATH already exists. Refusing to overwrite an existing release archive."
[[ ! -e "$RELEASE_APP" ]] || fail "$RELEASE_APP already exists. Refusing to overwrite an existing release bundle."
mkdir -p "$ARCHIVE_DIR"
if [[ -f "$ROOT_APPCAST" && ! -f "$APPCAST_PATH" ]]; then
    # Keep the tracked feed as the source of prior release entries. The copy in
    # archives is only generate_appcast's working file and stays untracked.
    /usr/bin/ditto "$ROOT_APPCAST" "$APPCAST_PATH"
fi
BUILD_DIR="$(mktemp -d "$RELEASE_DIR/.build-stage.XXXXXX")"
STAGING_DIR="$(mktemp -d "$RELEASE_DIR/.dmg-stage.XXXXXX")"
DMG_DIR="$(mktemp -d "$RELEASE_DIR/.dmg-output.XXXXXX")"
cleanup() {
    rm -rf "$BUILD_DIR"
    rm -rf "$STAGING_DIR"
    rm -rf "$DMG_DIR"
}
trap cleanup EXIT

build_soniccage release "$BUILD_DIR/$APP_NAME.app"
/usr/bin/ditto "$BUILD_DIR/$APP_NAME.app" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"
TEMP_DMG="$DMG_DIR/$ARCHIVE_NAME"
/usr/bin/hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING_DIR" -format UDZO -ov "$TEMP_DMG" >/dev/null
/usr/bin/hdiutil verify "$TEMP_DMG" >/dev/null
/usr/bin/ditto "$BUILD_DIR/$APP_NAME.app" "$RELEASE_APP"
mv "$TEMP_DMG" "$ARCHIVE_PATH"

# generate_appcast reads the Ed25519 private key directly from the Keychain;
# this script deliberately never accepts, prints, or writes that private key.
APPCAST_TOOL="$(sparkle_tool generate_appcast)"
"$APPCAST_TOOL" \
    --account "$SPARKLE_KEYCHAIN_ACCOUNT" \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    --link "https://github.com/$GITHUB_REPOSITORY" \
    --maximum-versions 0 \
    --maximum-deltas 0 \
    -o "$APPCAST_PATH" \
    "$ARCHIVE_DIR"

/usr/bin/ditto "$APPCAST_PATH" "$ROOT_APPCAST"

/usr/bin/xmllint --noout "$ROOT_APPCAST"
/usr/bin/grep -Fq "<sparkle:version>$BUILD_NUMBER</sparkle:version>" "$ROOT_APPCAST" || fail "The appcast does not contain build $BUILD_NUMBER."
/usr/bin/grep -Fq "$DOWNLOAD_PREFIX$ARCHIVE_NAME" "$ROOT_APPCAST" || fail "The appcast does not point at $ARCHIVE_NAME."
/usr/bin/grep -F '<enclosure ' "$ROOT_APPCAST" | /usr/bin/grep -Fq 'sparkle:edSignature=' || fail "The appcast lacks Sparkle's Ed25519 archive signature."
/usr/bin/grep -Fq '<!-- sparkle-signatures:' "$ROOT_APPCAST" || fail "The appcast lacks Sparkle's signed-feed block."
/usr/bin/grep -Fq 'edSignature:' "$ROOT_APPCAST" || fail "The appcast lacks Sparkle's signed-feed signature."

echo "Prepared $ARCHIVE_PATH"
echo "Prepared $ROOT_APPCAST"
echo "No files were published, committed, tagged, or uploaded."
