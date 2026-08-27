# ``JanuarySDK``

Add January food and metabolic intelligence to iOS applications.

## Overview

The SDK supports iOS 15 and later and uses Swift concurrency. A distributed app
authenticates with short-lived client tokens issued by its own backend. January
server credentials never belong in the app.

Implement ``JanuaryTokenProvider`` using your existing authenticated backend:

```swift
struct AppTokenProvider: JanuaryTokenProvider {
    let endpoint: URL

    func fetchClientToken() async throws -> JanuaryClientToken {
        let (data, _) = try await URLSession.shared.data(from: endpoint)
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

let january = try JanuaryClient(
    clientTokenProvider: AppTokenProvider(endpoint: requiredTokenEndpoint)
)
```

The provider owns its URL, session authentication, and network request. The SDK
keeps the returned token in memory, refreshes it before expiry, and coordinates
concurrent refreshes.

Search results are intentionally lightweight. Hydrate a selected result before
showing servings:

```swift
let results = try await january.foods.search(
    SearchFoodsRequest(query: "banana")
)

if let match = results.items.first {
    let food = try await january.foods.getFood(
        GetFoodRequest(foodID: match.id)
    )
    print(food.servings)
}
```

## Topics

### Client and authentication

- ``JanuaryClient``
- ``JanuaryTokenProvider``
- ``JanuaryClientToken``
- ``JanuaryTokenRetryPolicy``

### User context

- ``PartnerUserContext``
- ``PartnerUserID``
- ``JanuaryUserClient``

### Resources

- ``FoodsResource``
- ``RestaurantsResource``
- ``PhotoScanningResource``
- ``FoodLogsResource``
- ``GlucoseResource``

