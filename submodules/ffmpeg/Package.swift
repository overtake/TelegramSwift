// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "ffmpeg",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .library(
            name: "ffmpeg",
            targets: ["ffmpeg"]),
    ],
    targets: [
        .binaryTarget(
            name: "ffmpeg",
            path: "Frameworks/ffmpeg.xcframework"
        ),
    ]
)

