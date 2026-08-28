// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "January",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "January",
            targets: ["January"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JanuaryPartnerTransport",
            dependencies: []
        ),
        .target(
            name: "January",
            dependencies: [
                "JanuaryPartnerTransport",
            ],
            path: "Sources/JanuarySDK"
        ),
        .testTarget(
            name: "JanuarySDKTests",
            dependencies: [
                "January",
                "JanuaryPartnerTransport",
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
