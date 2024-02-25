// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BuildConfig",
    platforms: [.macOS(.v10_13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BuildConfig",
            targets: ["BuildConfig"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "MurMurHash32", path: "../../submodules/telegram-ios/submodules/MurMurHash32"),
        .package(name: "CryptoUtils", path: "../../submodules/telegram-ios/submodules/CryptoUtils"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BuildConfig",
            dependencies: [.product(name: "CryptoUtils", package: "CryptoUtils", condition: nil),
                           .product(name: "MurMurHash32", package: "MurMurHash32", condition: nil)],
            path: "Sources",
            cSettings: [
                .headerSearchPath("include")
            ]),
    ]
)
