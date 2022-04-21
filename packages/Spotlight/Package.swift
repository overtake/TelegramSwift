// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Spotlight",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        .library(
            name: "Spotlight",
            targets: ["Spotlight"]),
    ],
    dependencies: [
        .package(name: "TelegramCore", path: "../submodules/telegram-ios/submodules/TelegramCore"),
        .package(name: "MurMurHash32", path: "../submodules/telegram-ios/submodules/MurMurHash32"),
        .package(name: "Postbox", path: "../submodules/telegram-ios/submodules/Postbox"),
        .package(name: "SSignalKit", path: "../submodules/telegram-ios/submodules/SSignalKit"),
        .package(name: "TGUIKit", path: "../TGUIKit"),
    ],
    targets: [
        .target(
            name: "Spotlight",
            dependencies: [.product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                           .product(name: "MurMurHash32", package: "MurMurHash32", condition: nil),
                           .product(name: "Postbox", package: "Postbox", condition: nil),
                           .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                           .product(name: "TGUIKit", package: "TGUIKit", condition: nil),
                          ]),
    ]
)
