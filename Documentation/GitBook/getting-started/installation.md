# Installation

The package product and importable module are both named `JanuarySDK`.
It has no third-party runtime dependencies.

{% hint style="warning" %}
**Controlled Preview:** `January-ai/january-sdk-ios` is currently private. You need repository access from January before Xcode or Swift Package Manager can resolve it.
{% endhint %}

## Requirements

* Xcode 15 or later
* Swift 5.9 or later
* iOS 15 or later
* A GitHub account authorized for the private repository

The SDK supports iOS 15 with Xcode 15 and Swift 5.9. The January-owned example
app uses newer tab-bar APIs and separately requires Xcode 26 and iOS 26; its
deployment target does not change the SDK's minimum requirements.

## Xcode

1. Sign in to the authorized GitHub account in Xcode.
2. Open your app project.
3. Choose **File → Add Package Dependencies**.
4. Enter `https://github.com/January-ai/january-sdk-ios.git`.
5. Select the latest release shown by Xcode.
6. Add the `JanuarySDK` product to your app target.

## Package.swift

Swift Package Manager does not provide a symbolic `latest` requirement in a
package manifest. For manifest-only integrations, use the current release tag
shown under the repository's latest GitHub release, then add the `JanuarySDK`
product. Do not depend on the `main` branch for a production application.

## Verify the package

Add this import to an application source file and build the target:

```swift
import JanuarySDK
```

If resolution fails, follow [Xcode cannot resolve the package](../reference/troubleshooting.md#xcode-cannot-resolve-the-package).

Continue to [Backend token endpoint](backend-token-endpoint.md).
