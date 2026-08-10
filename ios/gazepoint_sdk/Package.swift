// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "gazepoint_sdk",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "gazepoint-sdk", targets: ["gazepoint_sdk"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "gazepoint_sdk",
            dependencies: [],
            path: "../Classes",
            resources: [
                .process("gazepoint_sdk/PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
