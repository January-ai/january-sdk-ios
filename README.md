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

- `foods` — autocomplete, food search, full food details, barcode lookup, natural-language search, and alternatives
- `restaurants` — restaurant and menu search
- `photoScanning` — meal-photo scanning and corrections
- `foodLogs` — create, retrieve, update, and delete food logs
- `glucose` — glucose prediction

## Full food details and portions

Search and autocomplete return lightweight discovery results. Fetch the selected
food to get every serving, then let the SDK scale all nutrients and build the
selection used by food-log and glucose-prediction requests:

```swift
let food = try await january.foods.getFood(.init(foodID: result.id))
let portion = try food.portion(
    servingID: food.servings[1].id,
    quantity: 1.5
)

print(portion.nutrition.calories?.value ?? 0)
let selection = portion.selection
```

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

For production-shaped integration, supply a token provider that calls the
integrating app's authenticated backend:

```swift
let january = try JanuaryPartnerClient(clientTokenProvider: {
    let token = try await partnerBackend.createJanuaryToken()
    return JanuaryClientToken(value: token.accessToken, expiresAt: token.expiresAt)
})
```

The existing `developmentAPIKey:` initializer remains supported during the
server rollout.

## Documentation

See the [January Partner API documentation](https://docs.january.ai/nutrition/apis/v1.2/).

## Example app

The repository includes an iOS 26 SwiftUI example app that demonstrates local
API-key setup and the starting navigation for each SDK resource. Open
`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj` in Xcode to run it.
