// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "JanuaryPartnerContractGenerator",
    platforms: [.macOS(.v13), .iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", exact: "1.13.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", exact: "1.12.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", exact: "1.3.1"),
    ],
    targets: [
        .target(
            name: "JanuaryPartnerTransport",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            resources: [
                .copy("openapi-generator-config.yaml"),
                .copy("openapi.yaml"),
            ]
        ),
    ]
)
