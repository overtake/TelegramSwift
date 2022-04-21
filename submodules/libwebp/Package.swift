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
        .target(
            name: "libwebp",
            dependencies: [],
            path: ".",
            publicHeadersPath: "Sources",
            cSettings: [
                .headerSearchPath("Sources"),
                .unsafeFlags([
                    "-I../../core-xprojects/libwebp/build/libwebp/include"
                ])
            ]),
    ]
)

