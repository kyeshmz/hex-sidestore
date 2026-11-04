#!/usr/bin/env bash
# Build Hex's iOS app as an unsigned .ipa that SideStore re-signs on the phone.
# Needs Xcode 26+ and XcodeGen.
# Usage: scripts/build-ipa.sh <hex-checkout> <output.ipa> <version> <build-number>
set -euo pipefail

checkout=$(cd "$1" && pwd)
mkdir -p "$(dirname "$2")"
ipa="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
version=$3
build_number=$4
scripts=$(cd "$(dirname "$0")" && pwd)
derived="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/hex-derived-data"

"$scripts/patch-upstream.sh" "$checkout"

cd "$checkout/ios"
xcodegen generate

# Xcode 26 installs the Metal compiler on demand; DotScopeShader.metal needs it.
xcrun metal --version >/dev/null 2>&1 || xcodebuild -downloadComponent MetalToolchain

build_args=(
  -project HEXMobile.xcodeproj -scheme HEXMobile -configuration Release
  -destination 'generic/platform=iOS' -derivedDataPath "$derived"
  -skipPackagePluginValidation -skipMacroValidation
  CODE_SIGNING_ALLOWED=NO
  MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$build_number"
)
xcodebuild "${build_args[@]}" build

# product name <TAB> entitlements file <TAB> product type, one line per target
settings=$(xcodebuild "${build_args[@]}" -showBuildSettings -json | python3 -c '
import json, re, sys
text = sys.stdin.read()
for target in json.loads(text[re.search(r"^\[", text, re.M).start():]):
    s = target["buildSettings"]
    print(s["FULL_PRODUCT_NAME"], s.get("CODE_SIGN_ENTITLEMENTS", ""), s["PRODUCT_TYPE"], sep="\t")
')
app_name=$(awk -F'\t' '$3 == "com.apple.product-type.application" { print $1; exit }' <<<"$settings")
app="$derived/Build/Products/Release-iphoneos/$app_name"
[[ -d "$app" ]] || { echo "build-ipa: no app at $app" >&2; exit 1; }

entitlements_for() { awk -F'\t' -v name="$1" '$1 == name && $2 != "" { print $2; exit }' <<<"$settings"; }

# Ad-hoc sign innermost bundles first so the App Group entitlement is embedded.
# SideStore reads it to register the group under your team before signing for real.
while IFS= read -r -d '' bundle; do
  entitlements=$(entitlements_for "$(basename "$bundle")")
  codesign --force --sign - --timestamp=none \
    ${entitlements:+--entitlements "$checkout/ios/$entitlements"} "$bundle"
done < <(find "$app" -depth \( -name '*.appex' -o -name '*.framework' -o -name '*.dylib' -o -path "$app" \) -print0)

stage=$(mktemp -d)
mkdir "$stage/Payload"
cp -R "$app" "$stage/Payload/"
rm -f "$ipa"
(cd "$stage" && zip -qry "$ipa" Payload)
echo "build-ipa: wrote $ipa ($version, build $build_number)"
