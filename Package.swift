// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JanuarySDK",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "JanuarySDK",
            targets: ["JanuarySDK"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "JanuaryPartnerTransport",
            dependencies: []
        ),
        .target(
            name: "JanuarySDK",
            dependencies: [
                "JanuaryPartnerTransport",
            ]
        ),
        .executableTarget(
            name: "JanuaryPartnerTokenSmoke",
            dependencies: ["JanuarySDK"]
        ),
        .testTarget(
            name: "JanuarySDKTests",
            dependencies: [
                "JanuarySDK",
                "JanuaryPartnerTransport",
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
