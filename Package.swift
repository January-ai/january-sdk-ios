// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "JanuaryPartnerSDK",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "JanuaryPartnerSDK",
            targets: ["JanuaryPartnerSDK"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-openapi-runtime",
            exact: "1.12.0"
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-urlsession",
            exact: "1.3.1"
        ),
        .package(
            url: "https://github.com/apple/swift-http-types",
            exact: "1.6.0"
        ),
    ],
    targets: [
        .target(
            name: "JanuaryPartnerTransport",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .target(
            name: "JanuaryPartnerSDK",
            dependencies: [
                "JanuaryPartnerTransport",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .executableTarget(
            name: "JanuaryPartnerSmoke",
            dependencies: ["JanuaryPartnerSDK"]
        ),
        .executableTarget(
            name: "JanuaryPartnerFullSmoke",
            dependencies: ["JanuaryPartnerSDK"]
        ),
        .testTarget(
            name: "JanuaryPartnerSDKTests",
            dependencies: [
                "JanuaryPartnerSDK",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
