// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InAppSettings",
    platforms: [.macOS(.v10_11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "InAppSettings",
            targets: ["InAppSettings"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "SSignalKit", path: "../submodules/telegram-ios/submodules/SSignalKit"),
        .package(name: "Postbox", path: "../submodules/telegram-ios/submodules/Postbox"),
        .package(name: "TelegramCore", path: "../submodules/telegram-ios/submodules/TelegramCore"),
        .package(name: "KeyboardKey", path: "../KeyboardKey"),
        .package(name: "Strings", path: "../Strings"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "InAppSettings",
            dependencies: [.product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                           .product(name: "Postbox", package: "Postbox", condition: nil),
                           .product(name: "KeyboardKey", package: "KeyboardKey", condition: nil),
                           .product(name: "Strings", package: "Strings", condition: nil),
                           .product(name: "TelegramCore", package: "TelegramCore", condition: nil)]),
    ]
)
