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

## Ready-to-use meal scanner for iOS

The existing `JanuaryPartnerSDK` product includes a complete camera flow. Add
`NSCameraUsageDescription` to the host app's Info.plist, then present the
scanner. It handles camera permission, denied-access recovery, meal-photo
compression, barcode detection, and the corresponding API requests.

```swift
import JanuaryPartnerSDK

JanuaryMealScannerView(
    client: january,
    endUserID: PartnerUserID(rawValue: userID),
    onResult: { result in
        switch result {
        case .meal(let image, let analysis):
            // image is the square JPEG sent to January; analysis is the FoodScan.
            showMeal(image.image, analysis)
        case .barcode(let value, let food):
            // food is the full food record, including its available servings.
            showBarcodeFood(value, food)
        }
    },
    onCancel: { dismissScanner() }
)
```

UIKit apps can present the same flow with
`JanuaryMealScanner.makeViewController(...)`. The host app remains responsible
only for the camera usage-description string and presenting the scanner.

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
    try await partnerBackend.createJanuaryToken()
})
```

Token-provider failures are retried with bounded exponential backoff and jitter.
The default makes nine total attempts (the initial fetch plus eight retries).
Customize or disable this behavior explicitly when constructing the client:

```swift
let retryPolicy = JanuaryTokenRetryPolicy(
    maximumAttempts: 9,
    initialDelay: 1,
    multiplier: 2,
    maximumDelay: 8,
    jitterRatio: 0.2
)

let january = try JanuaryPartnerClient(
    clientTokenProvider: { try await partnerBackend.createJanuaryToken() },
    tokenRetryPolicy: retryPolicy
)
```

Decode the backend's JSON response directly as `JanuaryClientToken`; its
stable shape is `{ token, expiresIn }`. Decoding also tolerates January's
snake-case `{ token, expires_in }` response.

If the app manages refresh itself, pass the short-lived token directly and
recreate the client when it changes:

```swift
let january = try JanuaryPartnerClient(clientToken: accessToken)
let user = january.forUser(PartnerUserID(rawValue: partnerUserID))
```

For larger integrations, implement `JanuaryTokenProvider` instead of a
closure. Provider tokens are kept only in memory, refreshed 60 seconds before
expiration, and shared across concurrent requests. A failed provider fetch uses
the configured bounded backoff policy. An HTTP 401 whose JSON body has
`code: "token_expired"` invalidates the token and replays the January operation
once after obtaining a replacement. Other authentication errors are surfaced
without replaying. The provider owns its endpoint URL,
request authentication, and headers; the SDK provides no token-endpoint URL or
fallback. Client-token requests omit `x-end-user-id`, because the token already
identifies the end user.

The existing `developmentAPIKey:` initializer remains supported during the
server rollout.

## Documentation

Start with the [Swift SDK GitBook](Documentation/GitBook/README.md), or see the
[January Partner API documentation](https://docs.january.ai/nutrition/apis/v1.2/)
for the underlying HTTP contract.

## Example app

The repository includes an iOS 26 SwiftUI example app covering token-provider
authentication, discovery, scanning, food logs, and glucose prediction. Open
`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj` in Xcode to run it.
