// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "Mozjpeg",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .library(
            name: "Mozjpeg",
            targets: ["Mozjpeg"]),
    ],
    targets: [
        .binaryTarget(
            name: "Mozjpeg",
            path: "Frameworks/Mozjpeg.xcframework"
        ),
    ]
)

