#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/build_support.sh
source "$SCRIPT_DIR/lib/build_support.sh"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "CursorCage" >/dev/null 2>&1 || true

build_soniccage debug "$DIST_DIR/$APP_NAME.app"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

case "$MODE" in
    run)
        /usr/bin/open -n "$APP_BUNDLE"
        ;;
    --debug|debug)
        lldb -- "$APP_BINARY"
        ;;
    --logs|logs)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    --telemetry|telemetry)
        /usr/bin/open -n "$APP_BUNDLE"
        /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
        ;;
    --verify|verify)
        /usr/bin/open -n "$APP_BUNDLE"
        sleep 1
        pgrep -x "$APP_NAME" >/dev/null || fail "SonicCage did not remain running."
        ;;
    *)
        echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
        exit 2
        ;;
esac
