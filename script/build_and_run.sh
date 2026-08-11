#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SonicCage"
BUNDLE_ID="com.fraise.SonicCage"
MIN_SYSTEM_VERSION="14.0"

MODE="${1:-run}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

APP_BINARY="$APP_MACOS/$APP_NAME"
ICON_SOURCE="$ROOT_DIR/Assets/SonicCage-liquid-glass.icns"
INFO_PLIST="$APP_CONTENTS/Info.plist"
PKG_INFO="$APP_CONTENTS/PkgInfo"

MODULE_CACHE_DIR="${TMPDIR:-/tmp}/sonic-cage-module-cache"

# A stable local designated requirement helps macOS continue recognising
# rebuilt development copies of SonicCage for permissions such as Accessibility.
BUNDLE_REQUIREMENT="=designated => identifier \"$BUNDLE_ID\""

usage() {
    echo "usage: $0 [run|debug|logs|telemetry|verify]" >&2
}

validate_mode() {
    case "$MODE" in
        run|debug|--debug|logs|--logs|telemetry|--telemetry|verify|--verify)
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

stop_running_app() {
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

build_app() {
    cd "$ROOT_DIR"

    mkdir -p "$MODULE_CACHE_DIR" "$DIST_DIR"

    export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
    export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"

    # SwiftPM's manifest sandbox is unavailable in some managed development
    # environments. This affects only the build process, not the app sandbox.
    local build_binary_dir
    build_binary_dir="$(swift build --disable-sandbox --show-bin-path)"

    swift build --disable-sandbox

    rm -rf "$APP_BUNDLE"

    mkdir -p "$APP_MACOS" "$APP_RESOURCES"

    cp "$build_binary_dir/$APP_NAME" "$APP_BINARY"
    cp "$ICON_SOURCE" "$APP_RESOURCES/SonicCage.icns"

    chmod +x "$APP_BINARY"

    write_info_plist
    printf 'APPL????' > "$PKG_INFO"

    codesign \
        --force \
        --sign - \
        --requirements "$BUNDLE_REQUIREMENT" \
        "$APP_BUNDLE" >/dev/null
}

write_info_plist() {
    cat > "$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>

    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>

    <key>CFBundleIconFile</key>
    <string>SonicCage.icns</string>

    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>

    <key>CFBundleName</key>
    <string>$APP_NAME</string>

    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>1.0</string>

    <key>CFBundleVersion</key>
    <string>1</string>

    <key>LSMinimumSystemVersion</key>
    <string>$MIN_SYSTEM_VERSION</string>

    <key>LSUIElement</key>
    <true/>

    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST
}

open_app() {
    /usr/bin/open -n "$APP_BUNDLE"
}

run_mode() {
    case "$MODE" in
        run)
            open_app
            ;;

        debug|--debug)
            lldb -- "$APP_BINARY"
            ;;

        logs|--logs)
            open_app
            /usr/bin/log stream \
                --info \
                --style compact \
                --predicate "process == \"$APP_NAME\""
            ;;

        telemetry|--telemetry)
            open_app
            /usr/bin/log stream \
                --info \
                --style compact \
                --predicate "subsystem == \"$BUNDLE_ID\""
            ;;

        verify|--verify)
            open_app
            sleep 1
            pgrep -x "$APP_NAME" >/dev/null
            echo "$APP_NAME launched successfully."
            ;;
    esac
}

validate_mode
stop_running_app
build_app
run_mode
