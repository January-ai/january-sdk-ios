# Installation

The package product and importable module are both named `JanuaryPartnerSDK`.

{% hint style="warning" %}
**Controlled Preview:** `January-ai/partner-sdk-ios` is currently private and has no version tags. You need repository access from January before Xcode or Swift Package Manager can resolve it.
{% endhint %}

## Requirements

* Swift 6.1 or later
* iOS 15 or later
* A GitHub account authorized for the private repository

The example app has separate requirements: Xcode 26 and iOS 26. Those do not raise the SDK library's deployment targets.

## Xcode

1. Sign in to the authorized GitHub account in Xcode.
2. Open your app project.
3. Choose **File → Add Package Dependencies**.
4. Enter `https://github.com/January-ai/partner-sdk-ios.git`.
5. Select **Revision** and enter the verified preview revision:

```text
c5e4725503eae7bdda85e7ad3786222c42f57d14
```

6. Add the `JanuaryPartnerSDK` product to your app target.

## Package.swift

Use the same pinned revision while the SDK is in Controlled Preview:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "YourApp",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/January-ai/partner-sdk-ios.git",
            revision: "c5e4725503eae7bdda85e7ad3786222c42f57d14"
        ),
    ],
    targets: [
        .target(
            name: "YourApp",
            dependencies: [
                .product(
                    name: "JanuaryPartnerSDK",
                    package: "partner-sdk-ios"
                ),
            ]
        ),
    ]
)
```

Pinning prevents an unreviewed preview update from changing your build. January will provide a new verified revision when you should update.

## Verify the package

Add this import to an application source file and build the target:

```swift
import JanuaryPartnerSDK
```

If resolution fails, follow [Xcode cannot resolve the package](../reference/troubleshooting.md#xcode-cannot-resolve-the-package).

## Future public release — not available today

Do not use a version-based declaration yet: no compatible tag exists. After January publishes the repository and creates a semantic-version release, this page will replace the preview instructions with a real version requirement.

```text
Future only — currently unavailable:
.package(url: "https://github.com/January-ai/partner-sdk-ios.git", from: "<published-version>")
```

Continue to [Backend token endpoint](backend-token-endpoint.md).
