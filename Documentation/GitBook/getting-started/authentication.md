# Authentication

Use a `JanuaryTokenProvider` in every production or distributed application. Its `fetchClientToken(for:)` method receives the required end-user ID, makes an authenticated API call to your backend, and returns that backend response directly as `JanuaryClientToken`.

{% hint style="danger" %}
Production apps must use short-lived client tokens. Server-side token issuance and its credentials stay outside the app and SDK integration. API-key authentication is available only for local development and must never be shipped.
{% endhint %}

## Call your backend for a client token

This provider is an example API request to **your server**, not to January. Your server authenticates the signed-in app user, mints a new short-lived January client token, and returns `{ "token": "ct-…", "expiresIn": 1800 }`.

```swift
import Foundation
import January

struct PartnerBackendTokenProvider: JanuaryTokenProvider {
    let tokenEndpoint: URL
    let appSessionToken: String

    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken {
        // This calls your server to mint a new January client token.
        var request = URLRequest(url: tokenEndpoint)
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
            throw JanuaryTokenProviderError("Your token endpoint is unavailable.", retryable: true)
        }
        guard let http = response as? HTTPURLResponse else {
            throw JanuaryTokenProviderError("Your token endpoint returned an invalid response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw JanuaryTokenProviderError(
                "Your token endpoint rejected the request.",
                retryable: http.statusCode == 408 || http.statusCode == 429 || http.statusCode >= 500
            )
        }

        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}
```

Change the HTTP method and authentication header only if your backend uses a different contract. `JanuaryClientToken` accepts both `expiresIn` and `expires_in`.

## Inject configuration and create the client

Resolve the endpoint from required app configuration. Do not provide a guessed or localhost default in production code.

```swift
func makeJanuaryClient(
    tokenEndpoint: URL,
    appSessionToken: String,
    endUserID: String,
    timezone: TimeZone? = nil
) throws -> JanuaryClient {
    let provider = PartnerBackendTokenProvider(
        tokenEndpoint: tokenEndpoint,
        appSessionToken: appSessionToken
    )
    return try JanuaryClient(
        endUserID: endUserID,
        timezone: timezone,
        clientTokenProvider: provider
    )
}
```

`JanuaryClient` always targets January's production Partner API through its documented client-token initializers. It exposes no API-origin override.

The required stable user ID and the resolved timezone are configured once on
the general client, so all resources are available directly:

```swift
let results = try await client.foods.search(.init(query: "greek yogurt"))
```

With client-token authentication, the token remains authoritative for identity.
The SDK removes `x-end-user-id` before calling January, so the configured context
cannot override the user bound to the token. The configured timezone—or
`TimeZone.current` when omitted—is applied to supported operations.

## Token lifecycle

The provider response must contain a non-empty token and an `expiresIn` value greater than 60 seconds. The SDK then:

* stores the token in memory only;
* refreshes it 60 seconds before its reported expiration;
* shares one in-flight refresh across concurrent requests;
* retries provider failures explicitly marked retryable with the configured bounded policy; and
* invalidates and replaces a token after January returns `401` with `code: "token_expired"`.

After `token_expired`, the original January operation is replayed at most once. Other January authentication errors are returned immediately. See [Retries and concurrency](../reference/retries-and-concurrency.md).

## Customize provider retries

The default is nine total provider calls: one initial attempt and eight retries. Nominal delays are 1, 2, 4, 8, 8, 8, 8, and 8 seconds with ±20% jitter and an 8-second cap.

```swift
let client = try JanuaryClient(
    endUserID: endUserID,
    clientTokenProvider: provider,
    tokenRetryPolicy: JanuaryTokenRetryPolicy(
        maximumAttempts: 9,
        initialDelay: 1,
        multiplier: 2,
        maximumDelay: 8,
        jitterRatio: 0.2
    )
)
```

Pass `.none` as `tokenRetryPolicy` to make a single provider attempt. Ordinary
errors and `JanuaryTokenProviderError(retryable: false)` stop immediately.

## App-managed fixed token

If your app deliberately owns the entire token lifecycle, it may create a client from one short-lived token and recreate the client when the token changes:

```swift
let client = try JanuaryClient(
    clientToken: clientTokenValue,
    endUserID: endUserID
)
```

The SDK cannot refresh this fixed-token client.

## Local development client-token exchange

Use `JanuaryDevelopmentTokenProvider` when you need to exercise minting,
caching, proactive refresh, and `token_expired` replay before your partner
backend is available.

{% hint style="danger" %}
This helper sends a January API key from the app process and is only for a local
Debug build. Never commit the key, include it in a distributed binary, or ship
this configuration. Production apps must use a backend-backed
`JanuaryTokenProvider`.
{% endhint %}

```swift
#if DEBUG
guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"],
      let rawUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set the local January development credentials in the Xcode scheme.")
}

let provider = try JanuaryDevelopmentTokenProvider(apiKey: apiKey)
let client = try JanuaryClient(
    endUserID: rawUserID,
    clientTokenProvider: provider
)
#endif
```

Token lifetime is managed internally. When your backend becomes available,
replace this helper with your own provider; the `JanuaryClient` construction
and resource calls stay the same.

## Local development API-key authentication

{% hint style="danger" %}
`developmentAPIKey` is only for local testing. Do not use it in production, include an API key in a distributed app, or commit one to source control. Use `JanuaryTokenProvider` for production.
{% endhint %}

Load the key from local Xcode scheme configuration instead of putting it in Swift source:

```swift
import Foundation
import January

guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"],
      let endUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set the local January development credentials in the Xcode scheme.")
}
let client = try JanuaryClient(
    developmentAPIKey: apiKey,
    endUserID: endUserID
)
```

This initializer is supported for local Debug testing and is not deprecated. Supplying a nonempty key writes a warning to the Xcode console at runtime without logging the key itself. Release builds reject the initializer at compile time, preventing the development key from being shipped. An empty or whitespace-only value fails validation without logging a warning.

The end-user ID is required. Use your own stable, non-identifying string for
the user exercising the SDK. Do not use the SDK developer's personal ID, an
email address, or a display name. An omitted timezone defaults to
`TimeZone.current`.
