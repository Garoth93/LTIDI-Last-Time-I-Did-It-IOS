// swift-tools-version: 5.9
// Logic package for the LTIDI app. Pure Swift, no UIKit/SwiftUI:
// it must build and test on Linux with `swift test`.
import PackageDescription

let package = Package(
    name: "LTIDICore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "LTIDICore", targets: ["LTIDICore"])
    ],
    targets: [
        .target(
            name: "LTIDICore",
            path: "Sources/LTIDICore"
        ),
        .testTarget(
            name: "LTIDICoreTests",
            dependencies: ["LTIDICore"],
            path: "Tests/LTIDICoreTests"
        )
    ]
)
