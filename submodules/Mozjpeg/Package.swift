// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "Mozjpeg",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "Mozjpeg",
            targets: ["Mozjpeg"]),
    ],
    targets: [
        .target(
            name: "Mozjpeg",
            dependencies: [],
            path: ".",
            publicHeadersPath: "Sources",
            cSettings: [
                .headerSearchPath("Sources"),
                .headerSearchPath("SharedHeaders/libmozjpeg"),
                .headerSearchPath("SharedHeaders/ios-mozjpeg"),
            ]),
    ]
)///../../submodules/telegram-ios/third-party/mozjpeg/mozjpeg

