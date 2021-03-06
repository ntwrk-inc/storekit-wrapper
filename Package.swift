// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoreKitWrapper",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v11),
    ],
    products: [
        .library(
            name: "StoreKitWrapper",
            targets: ["StoreKitWrapper"]
        ),
    ],
    dependencies: [
        .package(name: "FoundationExtensions", url: "https://github.com/ntwrk-inc/foundation-extensions.git", .upToNextMajor(from: "0.0.1")),
        .package(name: "Logger", url: "https://github.com/ntwrk-inc/logger.git", .upToNextMajor(from: "0.0.1")),
    ],
    targets: [
        .target(
            name: "StoreKitWrapper",
            dependencies: ["FoundationExtensions", "Logger"]
        ),
        .testTarget(
            name: "StoreKitWrapperTests",
            dependencies: ["StoreKitWrapper"]
        ),
    ]
)
