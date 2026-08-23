# January Partner SDK for Swift

Build food, nutrition, and metabolic intelligence into native Swift applications with January's Partner API.

The January Partner SDK provides typed models and modern `async`/`await` APIs for:

* Food search, barcode lookup, and natural-language meal parsing
* Restaurant and menu-item discovery
* Meal-photo scanning and corrections
* Food-log creation and management
* Glucose-impact prediction

{% hint style="warning" %}
The current Swift SDK is a pre-release development integration. Never embed a long-lived January API key in source code or a distributed application binary.
{% endhint %}

## Requirements

* Swift 6.1 or later
* iOS 16 or later
* macOS 13 or later
* Access to the private `January-ai/partner-sdk-ios` repository
* A January development API key

## Quick integration path

1. [Install the SDK](getting-started/installation.md) with Swift Package Manager.
2. [Provide credentials securely](getting-started/authentication.md) at runtime.
3. Create a `JanuaryPartnerClient`.
4. Make your first [food search](getting-started/quick-start.md).
5. Explore the task-focused [guides](guides/foods.md).

```swift
import JanuaryPartnerSDK

let january = try JanuaryPartnerClient(developmentAPIKey: apiKey)
let results = try await january.foods.search(
    SearchFoodsRequest(query: "greek yogurt")
)
```

## SDK architecture

| Component | Role |
| --- | --- |
| `JanuaryPartnerClient` | Main SDK entry point |
| `foods` | Food search, barcode lookup, meal parsing, and alternatives |
| `restaurants` | Restaurant and menu-item search |
| `photoScanning` | Meal-photo analysis and corrections |
| `foodLogs` | Create, list, update, and delete food logs |
| `glucose` | Personalized glucose prediction |
| `JanuaryError` | Stable errors with category, status, and request metadata |

## Next steps

* [Install the SDK](getting-started/installation.md)
* [Read the credential-security requirements](getting-started/authentication.md)
* [Run the quick start](getting-started/quick-start.md)
* [Open the example app](getting-started/example-app.md)

