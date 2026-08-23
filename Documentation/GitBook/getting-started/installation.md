# Installation

Add `JanuaryPartnerSDK` to an iOS or macOS project with Swift Package Manager.

## Xcode

1. Open your project in Xcode.
2. Choose **File → Add Package Dependencies**.
3. Enter the package URL:

```text
https://github.com/January-ai/partner-sdk-ios.git
```

4. Select the version or branch provided by January.
5. Add the `JanuaryPartnerSDK` product to your application target.

The repository is private, so Xcode must be authenticated to a GitHub account with access.

## Package.swift

Add the package dependency and library product:

```swift
dependencies: [
    .package(
        url: "https://github.com/January-ai/partner-sdk-ios.git",
        revision: "<commit-sha-provided-by-january>"
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
```

{% hint style="info" %}
The SDK is currently pre-release and has no published version tag. During development, use the branch or revision supplied by January. Switch to a released semantic version when one becomes available.
{% endhint %}

## Verify the installation

Import the module from your application target:

```swift
import JanuaryPartnerSDK
```

If the project builds, continue to [Authentication and security](authentication.md).
