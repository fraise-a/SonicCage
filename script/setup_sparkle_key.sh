#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/build_support.sh
source "$SCRIPT_DIR/lib/build_support.sh"

prepare_swift_build
cd "$ROOT_DIR"
swift build --disable-sandbox --configuration debug >/dev/null
KEY_TOOL="$(sparkle_tool generate_keys)"

# This is Sparkle's official key tool. It stores the private key only in the
# login Keychain, under SonicCage's dedicated account. It does not export it.
if ! "$KEY_TOOL" --account "$SPARKLE_KEYCHAIN_ACCOUNT" -p >/dev/null 2>&1; then
    "$KEY_TOOL" --account "$SPARKLE_KEYCHAIN_ACCOUNT"
fi

PUBLIC_KEY="$($KEY_TOOL --account "$SPARKLE_KEYCHAIN_ACCOUNT" -p)"
[[ "$PUBLIC_KEY" =~ ^[A-Za-z0-9+/=]{40,100}$ ]] || fail "Sparkle did not return a valid public key."

TEMP_CONFIG="$(mktemp "$SCRIPT_DIR/.sparkle.env.XXXXXX")"
trap 'rm -f "$TEMP_CONFIG"' EXIT
{
    printf '%s\n' '# The public key is safe to commit. Its matching private key remains in the login Keychain.'
    printf 'SPARKLE_PUBLIC_ED_KEY="%s"\n' "$PUBLIC_KEY"
    printf '%s\n' ''
    printf '%s\n' "# Public, HTTPS-only update locations. The actual DMGs remain GitHub release assets; this feed is committed to the repository's main branch."
    printf 'SPARKLE_FEED_URL="%s"\n' "$SPARKLE_FEED_URL"
    printf 'GITHUB_REPOSITORY="%s"\n' "$GITHUB_REPOSITORY"
    printf 'SPARKLE_KEYCHAIN_ACCOUNT="%s"\n' "$SPARKLE_KEYCHAIN_ACCOUNT"
} > "$TEMP_CONFIG"
mv "$TEMP_CONFIG" "$SCRIPT_DIR/sparkle.env"
trap - EXIT

echo "Sparkle's public key is configured for SonicCage. The private key remains in your login Keychain."
