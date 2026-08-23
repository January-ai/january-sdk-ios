# January Partner SDK for Swift

Build personalized nutrition experiences with the January Partner API. The
Swift SDK provides native models and modern `async`/`await` APIs for iOS and
macOS applications.

## Requirements

- Swift 6.1 or later
- iOS 16 or later
- macOS 13 or later

## Installation

### Xcode

In **File → Add Package Dependencies**, enter:

```text
https://github.com/January-ai/partner-sdk-ios.git
```

Select `JanuaryPartnerSDK` and add it to your application target.

### Package.swift

```swift
dependencies: [
    .package(
        url: "https://github.com/January-ai/partner-sdk-ios.git",
        from: "0.1.0"
    ),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "JanuaryPartnerSDK", package: "partner-sdk-ios"),
        ]
    ),
]
```

## Quick start

```swift
import JanuaryPartnerSDK

let january = try JanuaryPartnerClient(developmentAPIKey: apiKey)

let results = try await january.foods.search(
    SearchFoodsRequest(
        query: "greek yogurt",
        category: .branded,
        endUserID: PartnerUserID(rawValue: userID)
    )
)

for food in results.items {
    print(food.name)
}
```

## API resources

- `foods` — food search, barcode lookup, natural-language search, and alternatives
- `restaurants` — restaurant and menu search
- `photoScanning` — meal-photo scanning and corrections
- `foodLogs` — create, retrieve, update, and delete food logs
- `glucose` — glucose prediction

## Error handling

SDK requests throw `JanuaryError`, which provides a category, machine-readable
API code, message, and HTTP status when available.

```swift
do {
    let results = try await january.foods.search(request)
    // Use results
} catch let error as JanuaryError {
    print(error.category, error.message)
}
```

## Authentication

Keep API credentials out of source control and application logs. Do not embed a
long-lived API key in a distributed application.

## Documentation

See the [January Partner API documentation](https://docs.january.ai/nutrition/apis/v1.2/).
