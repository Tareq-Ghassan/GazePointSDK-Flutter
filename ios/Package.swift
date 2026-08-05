// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gazepoint_sdk",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "gazepoint_sdk",
            targets: ["gazepoint_sdk"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "gazepoint_sdk",
            dependencies: [],
            path: "Classes",
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        )
    ]
)
