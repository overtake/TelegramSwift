// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "webrtc",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .library(
            name: "webrtc",
            targets: ["webrtc"]),
    ],
    targets: [
        .binaryTarget(
            name: "webrtc",
            path: "Frameworks/webrtc.xcframework"
        ),
    ]
)

