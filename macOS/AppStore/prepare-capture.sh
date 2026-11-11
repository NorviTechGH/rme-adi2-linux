#!/bin/bash
# Clone an existing development app for isolated manual screenshot capture.
# Does not build, launch, quit apps, connect MIDI or modify the source bundle.
set -euo pipefail
macos_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(cd "$macos_dir/.." && pwd)"
source_app="${1:?Usage: prepare-capture.sh source.app [empty-output-directory]}"
output_dir="${2:-$repo_dir/work/app-store-capture}"
capture_id="tech.norvi.ADI2Companion.AppStoreCapture"
test -f "$source_app/Contents/MacOS/ADI2Companion"
source_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")"
if [[ "$source_id" != "tech.norvi.ADI2Companion" ]]; then
    echo 'Expected the genuine development app bundle as the source.' >&2
    exit 2
fi
codesign --verify --deep --strict "$source_app"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
capture_app="$output_dir/ADI-2 Companion Capture.app"
if [[ -e "$capture_app" ]]; then
    echo 'The capture clone already exists; choose another output directory.' >&2
    exit 2
fi
ditto "$source_app" "$capture_app"
plutil -replace CFBundleIdentifier -string "$capture_id" "$capture_app/Contents/Info.plist"
# Keep the product display name, executable code, artwork and UI unchanged.
codesign --force --sign - --options runtime --entitlements "$macos_dir/Resources/ADI2Companion.entitlements" "$capture_app"
"$macos_dir/scripts/verify-app.sh" "$capture_app"
printf 'Prepared capture clone: %s\n' "$capture_app"
printf 'Separate bundle/container identity: %s\n' "$capture_id"
printf 'Not launched. Root may open this exact clone with --demo for manual capture.\n'
