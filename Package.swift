// swift-tools-version: 6.1

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
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-openapi-runtime",
            from: "1.12.0"
        ),
        .package(
            url: "https://github.com/apple/swift-openapi-urlsession",
            from: "1.3.1"
        ),
        .package(
            url: "https://github.com/apple/swift-http-types",
            from: "1.6.0"
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
            name: "JanuarySDK",
            dependencies: [
                "JanuaryPartnerTransport",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
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
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
