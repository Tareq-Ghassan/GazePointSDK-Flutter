// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "gazepoint_sdk",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "gazepoint-sdk", targets: ["gazepoint_sdk"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "gazepoint_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
