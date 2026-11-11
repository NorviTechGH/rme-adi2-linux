// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "ADI2Companion",
    platforms: [.macOS(.v14)],
    products: [.library(name: "ADI2Core", targets: ["ADI2Core"]), .executable(name: "ADI2Companion", targets: ["ADI2Mac"])],
    targets: [
        .target(name: "ADI2Core"),
        .executableTarget(name: "ADI2Mac", dependencies: ["ADI2Core"], linkerSettings: [.linkedFramework("CoreMIDI"), .linkedFramework("AppKit")]),
        .testTarget(name: "ADI2CoreTests", dependencies: ["ADI2Core"]),
        .testTarget(name: "ADI2MacTests", dependencies: ["ADI2Mac", "ADI2Core"])
    ]
)
