# ``JanuarySDK``

Add January food and metabolic intelligence to iOS applications.

## Overview

The SDK supports iOS 15 and later and uses Swift concurrency. A distributed app
authenticates with short-lived client tokens issued by its own backend. January
server credentials never belong in the app.

Implement ``JanuaryTokenProvider`` using your existing authenticated backend.
The provider makes an API call to your server; your server returns
`{ "token": "ct-…", "expiresIn": 1800 }`:

```swift
struct AppTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String

    func fetchClientToken() async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.setValue(
            "Bearer \(appSessionToken)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

let january = try JanuaryClient(
    clientTokenProvider: AppTokenProvider(
        endpoint: requiredTokenEndpoint,
        appSessionToken: signedInUser.sessionToken
    )
)
```

The provider owns its URL, session authentication, and network request. The SDK
keeps the returned token in memory, refreshes it before expiry, and coordinates
concurrent refreshes.

### Local development only

> Warning: ``JanuaryClient/init(developmentAPIKey:)`` is only for local testing
> and intentionally emits Xcode and runtime console warnings. The warning never
> contains the key. Never ship an API key in a production app or commit one to
> source control. Production apps must use ``JanuaryTokenProvider``.

```swift
guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"] else {
    fatalError("Set JANUARY_API_KEY in the local Xcode scheme.")
}
let january = try JanuaryClient(developmentAPIKey: apiKey)
```

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
