# Installation

Check the [requirements](../README.md#requirements) first. Releases before 1.0 can break the API in a minor version, so allow patch updates only.

## Swift Package Manager

1. In Xcode, choose **File → Add Package Dependencies**.
2. Enter `https://github.com/January-ai/january-sdk-ios.git`.
3. Set **Dependency Rule** to **Up to Next Minor Version** from `0.3.2`.
4. Add the `January` product to your app target.

In a `Package.swift` manifest:

```swift
dependencies: [
    .package(url: "https://github.com/January-ai/january-sdk-ios.git", .upToNextMinor(from: "0.3.2")),
],
targets: [
    .target(name: "YourApp", dependencies: [
        .product(name: "January", package: "january-sdk-ios"),
    ]),
]
```

## CocoaPods

Add the `January` pod to your `Podfile`:

```ruby
platform :ios, "15.0"

target "YourApp" do
  pod "January", "~> 0.3.2"
end
```

Then run `pod install --repo-update` and open the generated `.xcworkspace`.

## Import the SDK

```swift
import January
```

Next: [Backend token endpoint](backend-token-endpoint.md).
