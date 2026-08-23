# Quick start

This walkthrough creates a client and searches January's food database.

## Prerequisites

* The SDK is [installed](installation.md).
* A development API key is injected at runtime.
* You have an optional stable ID for the end user.

## Create the client

```swift
import JanuaryPartnerSDK

let january = try JanuaryPartnerClient(
    developmentAPIKey: apiKey
)
```

## Search for a food

```swift
let results = try await january.foods.search(
    SearchFoodsRequest(
        query: "greek yogurt",
        category: .branded,
        limit: 10,
        endUserID: PartnerUserID(rawValue: userID)
    )
)

for food in results.items {
    print(food.name)
    print(food.calories as Any)
    print(food.servings)
}
```

`query` must contain 1–256 characters. `limit` must be between 1 and 40.

## Handle failures

```swift
do {
    let results = try await january.foods.search(
        SearchFoodsRequest(query: "banana")
    )
    print(results.items)
} catch let error as JanuaryError {
    print(error.category)
    print(error.code as Any)
    print(error.message)
    print(error.requestID as Any)
}
```

Continue to the [Foods guide](../guides/foods.md) for barcode lookup, natural-language parsing, and alternatives.

