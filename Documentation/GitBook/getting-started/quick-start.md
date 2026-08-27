# Quick start

This walkthrough creates a client and searches January's food database.

## Prerequisites

* The SDK is [installed](installation.md).
* Your authenticated backend can return `{ token, expiresIn }`.
* You have an optional stable ID for the end user.

## Create the client

```swift
import JanuaryPartnerSDK

let january = try JanuaryPartnerClient(clientTokenProvider: {
    try await partnerBackend.createJanuaryToken()
})
```

## Search for a food

```swift
let results = try await january.foods.search(
    SearchFoodsRequest(
        query: "greek yogurt",
        category: .branded,
        limit: 10,
        endUserID: nil
    )
)

for food in results.items {
    print(food.name)
    print(food.calories as Any)
    print(food.servings)
}
```

`query` must contain 1–256 characters. `limit` must be between 1 and 40.
Client-token requests omit `x-end-user-id`; the token already identifies the
user. Use `forUser` to reuse app-owned identity and timezone for Food Logs and
Glucose when using development-key authentication.

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
