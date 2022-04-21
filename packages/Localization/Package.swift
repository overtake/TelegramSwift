// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Localization",
    platforms: [
        .macOS(.v10_11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Localization",
            targets: ["Localization"]),
    ],
    dependencies: [
        .package(name: "TelegramCore", path: "../submodules/telegram-ios/submodules/TelegramCore"),
        .package(name: "TGUIKit", path: "../TGUIKit"),
        .package(name: "NumberPluralization", path: "../NumberPluralization"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Localization",
            dependencies: [.product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                           .product(name: "TGUIKit", package: "TGUIKit", condition: nil),
                           .product(name: "NumberPluralization", package: "NumberPluralization", condition: nil),
                          ]),
    ]
)
