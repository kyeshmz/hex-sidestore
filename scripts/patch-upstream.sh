#!/usr/bin/env bash
# Patch an upstream Hex checkout so its keyboard can still reach the app after
# SideStore re-signs it. SideStore renames App Groups to "<group>.<TEAMID>" and
# appends the team ID to bundle IDs, so upstream's hardcoded IDs stop matching.
# Usage: scripts/patch-upstream.sh <hex-checkout>
set -euo pipefail

ios="$1/ios"
scripts=$(cd "$(dirname "$0")" && pwd)

fail() { echo "patch-upstream: $*" >&2; exit 1; }

cp "$scripts/SideloadAppGroup.swift" "$ios/HEXShared/SideloadAppGroup.swift"

perl -pi -e 's/static let appGroup = ("group\.[^"]+")/static let appGroup: String = SideloadAppGroup.resolve(fallback: $1)/' \
  "$ios/HEXShared/KeyboardBridge.swift"
perl -pi -e 's/static let keyboardBundleID = "([^"]+)(\.keyboard)"/static let keyboardBundleID = (Bundle.main.bundleIdentifier ?? "$1") + "$2"/' \
  "$ios/HEXMobile/KeyboardSetup.swift"

# Stop the build rather than ship an app whose keyboard silently can't connect.
grep -q 'SideloadAppGroup.resolve' "$ios/HEXShared/KeyboardBridge.swift" \
  || fail "KeyboardBridge.appGroup changed upstream; update this patch"
grep -q 'Bundle.main.bundleIdentifier ??' "$ios/HEXMobile/KeyboardSetup.swift" \
  || fail "KeyboardSetupMonitor.keyboardBundleID changed upstream; update this patch"
if grep -rn --include='*.swift' '"group\.' "$ios" | grep -v 'SideloadAppGroup.resolve'; then
  fail "found an App Group literal this patch doesn't handle"
fi

echo "patch-upstream: App Group and keyboard bundle ID now resolve at runtime"
