#!/bin/bash
set -euo pipefail
package_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$package_dir"

# Full Xcode supplies XCTest; use SwiftPM's normal discovery in that environment.
# Command Line Tools can run the same test bodies through their standalone
# assertion harnesses. No hardware is contacted by either route.
if printf 'import XCTest\n' | xcrun swiftc -typecheck - >/dev/null 2>&1; then
    exec xcrun swift test --package-path "$package_dir"
fi

test_dir="$package_dir/.build/cli-check"
mkdir -p "$test_dir"
xcrun swiftc -parse-as-library -enable-testing -emit-library -emit-module \
    -module-name ADI2Core Sources/ADI2Core/*.swift \
    -emit-module-path "$test_dir/ADI2Core.swiftmodule" \
    -o "$test_dir/libADI2Core.dylib"
link_args=(-parse-as-library -I "$test_dir" -L "$test_dir" -lADI2Core -Xlinker -rpath -Xlinker @executable_path)
xcrun swiftc "${link_args[@]}" Tests/ADI2CoreTests/ADI2CoreTests.swift -o "$test_dir/CoreTests"
"$test_dir/CoreTests"
xcrun swiftc "${link_args[@]}" Sources/ADI2Mac/AppModel.swift Sources/ADI2Mac/CoreMIDILink.swift \
    Tests/ADI2MacTests/AppModelTests.swift -o "$test_dir/AppModelTests"
"$test_dir/AppModelTests"
