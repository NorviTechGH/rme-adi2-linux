#!/bin/bash
set -euo pipefail

package_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$package_dir/build"
universal=0
bundle_id=""; marketing_version=""; build_number=""
while IFS='=' read -r config_key config_value; do
    config_key="${config_key//[[:space:]]/}"
    config_value="${config_value//[[:space:]]/}"
    case "$config_key" in
        PRODUCT_BUNDLE_IDENTIFIER) bundle_id="$config_value" ;;
        MARKETING_VERSION) marketing_version="$config_value" ;;
        CURRENT_PROJECT_VERSION) build_number="$config_value" ;;
    esac
done < "$package_dir/Resources/App.xcconfig"
test -n "$bundle_id" && test -n "$marketing_version" && test -n "$build_number"
while (($#)); do
    case "$1" in
        --universal) universal=1; shift ;;
        --output) output_dir="${2:?--output requires a directory}"; shift 2 ;;
        *) echo "Usage: $0 [--universal] [--output directory]" >&2; exit 2 ;;
    esac
done
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
app_path="$output_dir/ADI-2 Companion.app"
build_args=(--package-path "$package_dir" -c release)
if ((universal)); then build_args+=(--arch arm64 --arch x86_64); fi
xcrun swift build "${build_args[@]}"
bin_dir="$(xcrun swift build "${build_args[@]}" --show-bin-path)"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_dir/ADI2Companion" "$app_path/Contents/MacOS/ADI2Companion"
cp "$package_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
plutil -replace CFBundleExecutable -string ADI2Companion "$app_path/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$app_path/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$marketing_version" "$app_path/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$build_number" "$app_path/Contents/Info.plist"
cp "$package_dir/Resources/PrivacyInfo.xcprivacy" "$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$package_dir/Resources/AppIcon.icns" "$app_path/Contents/Resources/AppIcon.icns"
cp "$package_dir/Resources/LICENSE.txt" "$app_path/Contents/Resources/LICENSE.txt"
# The standalone executable has no third-party runtime or helper process.
# Ad-hoc signing enables the sandbox for local testing; it is not store signing.
codesign --force --sign - --options runtime --entitlements "$package_dir/Resources/ADI2Companion.entitlements" "$app_path"
"$package_dir/scripts/verify-app.sh" "$app_path"
printf 'Development app: %s\n' "$app_path"
printf 'Launch demo: open "%s" --args --demo\n' "$app_path"
