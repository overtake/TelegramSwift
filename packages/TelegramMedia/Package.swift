// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TelegramMedia",
    platforms: [.macOS(.v10_13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TelegramMedia",
            targets: ["TelegramMedia"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "SSignalKit", path: "../../submodules/telegram-ios/submodules/SSignalKit"),
        .package(name: "TelegramCore", path: "../../submodules/telegram-ios/submodules/TelegramCore"),
        .package(name: "Postbox", path: "../../submodules/telegram-ios/submodules/Postbox"),
        .package(name: "OpusBinding", path: "../../submodules/telegram-ios/submodules/OpusBinding"),
        .package(name: "TelegramVoip", path: "../../submodules/telegram-ios/submodules/TelegramVoip"),
        .package(name: "TgVoipWebrtc", path: "../tgcalls"),
        .package(name: "ColorPalette", path: "../ColorPalette"),
        .package(name: "KeyboardKey", path: "../KeyboardKey"),
        .package(name: "GZIP", path: "../GZIP"),
        .package(name: "TGUIKit", path: "../TGUIKit"),
        .package(name: "CallVideoLayer", path: "../CallVideoLayer"),
        .package(name: "libwebp", path: "../../submodules/libwebp"),
        .package(name: "ApiCredentials", path: "../ApiCredentials"),
        .package(name: "ObjcUtils", path: "../ObjcUtils"),
        .package(name: "TelegramMediaPlayer", path: "../../submodules/telegram-ios/submodules/MediaPlayer"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TelegramMedia",
            dependencies: [.product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                           .product(name: "ColorPalette", package: "ColorPalette", condition: nil),
                           .product(name: "KeyboardKey", package: "KeyboardKey", condition: nil),
                           .product(name: "TGUIKit", package: "TGUIKit", condition: nil),
                           .product(name: "CallVideoLayer", package: "CallVideoLayer", condition: nil),
                           .product(name: "TgVoipWebrtc", package: "TgVoipWebrtc", condition: nil),
                           .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                           .product(name: "GZIP", package: "GZIP", condition: nil),
                           .product(name: "Postbox", package: "Postbox", condition: nil),
                           .product(name: "libwebp", package: "libwebp", condition: nil),
                           .product(name: "ApiCredentials", package: "ApiCredentials", condition: nil),
                           .product(name: "ObjcUtils", package: "ObjcUtils", condition: nil),
                           .product(name: "TelegramMediaPlayer", package: "TelegramMediaPlayer", condition: nil),
                           .product(name: "OpusBinding", package: "OpusBinding", condition: nil),
                           .product(name: "TelegramVoip", package: "TelegramVoip", condition: nil),
                          ],
            path: "Sources"),
    ]
)
