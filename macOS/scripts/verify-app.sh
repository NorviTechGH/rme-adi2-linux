#!/bin/bash
set -euo pipefail
app_path="${1:?Usage: verify-app.sh path/to/app}"
codesign --verify --deep --strict --verbose=2 "$app_path"
plutil -lint "$app_path/Contents/Info.plist" "$app_path/Contents/Resources/PrivacyInfo.xcprivacy"
test -s "$app_path/Contents/Resources/AppIcon.icns"
entitlement_file="$(mktemp -t adi2-entitlements)"
trap 'rm -f "$entitlement_file"' EXIT
codesign --display --entitlements :- "$app_path" > "$entitlement_file" 2>/dev/null
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlement_file" | /usr/bin/grep -qx true
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.files.user-selected.read-write' "$entitlement_file" | /usr/bin/grep -qx true
if xattr -r "$app_path" | /usr/bin/grep -q 'com.apple.quarantine'; then
    echo 'Bundle contains com.apple.quarantine; remove it before App Store upload.' >&2
    exit 1
fi
file "$app_path/Contents/MacOS/ADI2Companion"
echo 'Bundle structure, signature and sandbox entitlements verified.'
echo 'This check does not validate Apple distribution signing or hardware communication.'
