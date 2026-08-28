# ``January``

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

    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(appSessionToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(endUserID, forHTTPHeaderField: "x-end-user-id")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JanuaryTokenProviderError("Token endpoint is unavailable.", retryable: true)
        }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode
            throw JanuaryTokenProviderError(
                "Token endpoint rejected the request.",
                retryable: status == 408 || status == 429 || (status ?? 0) >= 500
            )
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

let january = try JanuaryClient(
    endUserID: signedInUser.id,
    clientTokenProvider: AppTokenProvider(
        endpoint: requiredTokenEndpoint,
        appSessionToken: signedInUser.sessionToken
    )
)
```

The provider owns its URL, session authentication, and network request. The SDK
keeps the returned token in memory, refreshes it before expiry, and coordinates
concurrent refreshes.

The required end-user ID is a stable string from your user system. The SDK
passes it to the provider whenever it needs a new token. An omitted timezone
defaults to `TimeZone.current` across resources:

```swift
let results = try await january.foods.search(.init(query: "banana"))
```

`JanuaryClient` exposes Foods, Restaurants, Photo Scanning, Food Logs, and
Glucose. Recreate the client when the signed-in account changes.

For a local end-to-end check, deploy the public
[January token relay](https://github.com/January-ai/january-token-relay) and use
its URL and relay secret only in local app configuration. No hosted test URL or
shared secret is embedded in the SDK. Distributed apps should use an
authenticated backend that derives the user identity from the app session.

### Test client-token refresh locally

``JanuaryDevelopmentTokenProvider`` lets a local Debug build exercise token
minting, proactive refresh, and `token_expired` replay before a partner backend
is available:

```swift
#if DEBUG
let provider = try JanuaryDevelopmentTokenProvider(apiKey: requiredLocalDevelopmentKey)
let january = try JanuaryClient(
    endUserID: "local-test-user",
    clientTokenProvider: provider
)
#endif
```

> Warning: This helper sends the API key from the app process. Never ship or
> distribute an app configured this way. Production apps must replace it with
> their own backend-backed ``JanuaryTokenProvider``.

### Local development only

> Warning: ``JanuaryClient/init(developmentAPIKey:endUserID:timezone:)`` is only for local testing
> and intentionally emits Xcode and runtime console warnings. The warning never
> contains the key. Never ship an API key in a production app or commit one to
> source control. Production apps must use ``JanuaryTokenProvider``.

```swift
guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"] else {
    fatalError("Set JANUARY_API_KEY in the local Xcode scheme.")
}
guard let rawUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set JANUARY_END_USER_ID in the local Xcode scheme.")
}
let january = try JanuaryClient(
    developmentAPIKey: apiKey,
    endUserID: rawUserID
)
```

Search results are intentionally lightweight. Hydrate a selected result before
showing servings:

```swift
let results = try await january.foods.search(
    SearchFoodsRequest(query: "banana")
)

if let match = results.items.first {
    let food = try await january.foods.get(id: match.id)
    print(food.servings)
}
```

## Topics

### Client and authentication

- ``JanuaryClient``
- ``JanuaryTokenProvider``
- ``JanuaryClientToken``
- ``JanuaryTokenRetryPolicy``
- ``JanuaryDevelopmentTokenProvider``

### User identity

- ``PartnerUserContext``
- ``PartnerUserID``

### Resources

- ``FoodsResource``
- ``RestaurantsResource``
- ``FoodAnalysisResource``
- ``FoodLogsResource``
- ``GlucoseResource``
