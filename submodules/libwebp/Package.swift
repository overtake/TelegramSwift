// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "libwebp",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .library(
            name: "libwebp",
            targets: ["libwebp"]),
    ],
    targets: [
        .binaryTarget(
            name: "libwebp",
            path: "Frameworks/libwebp.xcframework"
        ),
    ]
)

