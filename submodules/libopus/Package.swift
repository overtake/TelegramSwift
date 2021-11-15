// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "libopus",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .library(
            name: "libopus",
            targets: ["libopus"]),
    ],
    targets: [
        .binaryTarget(
            name: "libopus",
            path: "Frameworks/libopus.xcframework"
        ),
    ]
)

