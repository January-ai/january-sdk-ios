# Installation

The package product and importable module are both named `JanuarySDK`.

{% hint style="warning" %}
**Controlled Preview:** `January-ai/january-sdk-ios` is currently private. You need repository access from January before Xcode or Swift Package Manager can resolve it.
{% endhint %}

## Requirements

* Swift 6.1 or later
* iOS 15 or later
* A GitHub account authorized for the private repository

The example app uses the latest tab-bar APIs and targets iOS 26 independently of the SDK.

## Xcode

1. Sign in to the authorized GitHub account in Xcode.
2. Open your app project.
3. Choose **File → Add Package Dependencies**.
4. Enter `https://github.com/January-ai/january-sdk-ios.git`.
5. Select **Exact Version** and enter the preview release:

```text
0.1.0-beta.1
```

6. Add the `JanuarySDK` product to your app target.

## Package.swift

Use the same exact prerelease while the SDK is in Controlled Preview:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/January-ai/january-sdk-ios.git",
            exact: "0.1.0-beta.1"
        ),
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(
                    name: "JanuarySDK",
                    package: "january-sdk-ios"
                ),
            ]
        ),
    ]
)
```

Pinning prevents an unreviewed preview update from changing your build. January will publish a new prerelease when you should update.

## Verify the package

Add this import to an application source file and build the target:

```swift
import JanuarySDK
```

If resolution fails, follow [Xcode cannot resolve the package](../reference/troubleshooting.md#xcode-cannot-resolve-the-package).

## Stable releases

After January publishes `0.1.0`, use a compatible version requirement so your app can receive non-breaking updates:

```text
.package(url: "https://github.com/January-ai/january-sdk-ios.git", from: "0.1.0")
```

Continue to [Backend token endpoint](backend-token-endpoint.md).
