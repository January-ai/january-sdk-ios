# January SDK for iOS

Build food discovery, nutrition, meal logging, and glucose-prediction experiences with native Swift models and `async`/`await` APIs.

## What you can build

* Autocomplete, food search, barcode lookup, and full serving hydration
* Restaurant and menu-item discovery
* Meal-photo analysis, corrections, and an iOS-native camera/barcode scanner
* Food-log creation and management
* Personalized glucose-impact predictions

## Requirements

| Component | Requirement |
| --- | --- |
| SDK platform | iOS 15 or later |
| SDK build tools | Xcode 15 or later and Swift 5.9 or later |
| Runtime dependencies | None |
| Demo app | Xcode 26 and an iOS 26 simulator or device, independently of the SDK requirements |
| Distribution | Swift Package Manager using versioned repository releases |
| Production integration | A partner-controlled backend that issues short-lived January client tokens |

## Start here

1. [Install the latest release](getting-started/installation.md).
2. [Build the partner token endpoint](getting-started/backend-token-endpoint.md).
3. [Add a concrete token provider](getting-started/authentication.md).
4. [Run your first food search](getting-started/quick-start.md).
5. Learn the [search → hydrate → portion](concepts/food-hydration-and-portions.md) workflow.

```swift
import Foundation
import January

let january = try JanuaryClient(
    endUserID: signedInUser.id,
    clientTokenProvider: tokenProvider
)
let results = try await january.foods.search(.init(query: "greek yogurt"))
```

## SDK entry points

| API | Purpose |
| --- | --- |
| `JanuaryClient` | Configures authentication, optional user context, and all resources |
| `foods` | Food discovery, hydration, barcode lookup, meal parsing, and alternatives |
| `restaurants` | Nearby restaurant search, menu-item search, and menu lookup by restaurant ID |
| `foodAnalysis` | Meal-photo analysis and corrections |
| `foodLogs` | Food-log CRUD operations |
| `glucose` | Personalized glucose prediction |
| `JanuaryFoodScannerView` | iOS-only ready-made camera and barcode flow |
| `JanuaryError` | Stable error categories and request metadata |

The generated OpenAPI transport is an implementation detail. Integrate through the public types in `January`.

## Security boundary

Production SDK authentication uses client tokens. Your backend authenticates the user, completes January's private server-side token exchange, and returns a short-lived client token to the app. A supported API-key initializer is available strictly for local development and must never be shipped. See [Authentication](getting-started/authentication.md) and [Backend token endpoint](getting-started/backend-token-endpoint.md).
