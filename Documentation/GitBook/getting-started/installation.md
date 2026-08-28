# Install the iOS SDK

{% hint style="warning" %}
**Controlled Preview:** `January-ai/january-sdk-ios` is currently private. You need repository access from January before Xcode or Swift Package Manager can resolve it.
{% endhint %}

## Requirements

* Xcode 15 or later
* Swift 5.9 or later
* iOS 15 or later
* A GitHub account authorized for the private repository

## Add the package in Xcode

1. Sign in to the authorized GitHub account in Xcode.
2. Open your app project.
3. Choose **File → Add Package Dependencies**.
4. Enter `https://github.com/January-ai/january-sdk-ios.git`.
5. Select the latest release shown by Xcode.
6. Add the `January` product to your app target.
7. Import January in your app:

```swift
import January
```

Continue to [Backend token endpoint](backend-token-endpoint.md).
