# Install the iOS SDK

## Requirements

* Xcode 15 or later
* Swift 5.9 or later
* iOS 15 or later

## Add the package in Xcode

1. Open your app project.
2. Choose **File → Add Package Dependencies**.
3. Enter `https://github.com/January-ai/january-sdk-ios.git`.
4. Select the latest release shown by Xcode.
5. Add the `January` product to your app target.
6. Import January in your app:

```swift
import January
```

Continue to [Backend token endpoint](backend-token-endpoint.md).
