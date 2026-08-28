# Authentication

Use a `JanuaryTokenProvider` in every production or distributed application. Its `fetchClientToken()` method makes an authenticated API call to your backend and returns that backend response directly as `JanuaryClientToken`.

{% hint style="danger" %}
Production apps must use short-lived client tokens. Server-side token issuance and its credentials stay outside the app and SDK integration. API-key authentication is available only for local development and must never be shipped.
{% endhint %}

## Implement a URLSession provider

This implementation keeps the endpoint and the app's session authentication injected. It accepts both `expiresIn` and `expires_in` because `JanuaryClientToken` decodes both forms.

```swift
import Foundation
import JanuarySDK

struct PartnerBackendTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let session: URLSession
    let authorizationHeader: @Sendable () async throws -> String

    init(
        endpoint: URL,
        session: URLSession = .shared,
        authorizationHeader: @escaping @Sendable () async throws -> String
    ) {
        self.endpoint = endpoint
        self.session = session
        self.authorizationHeader = authorizationHeader
    }

    func fetchClientToken() async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET" // Match your backend contract.
        request.setValue(
            try await authorizationHeader(),
            forHTTPHeaderField: "Authorization"
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JanuaryTokenProviderError("Token endpoint is unavailable.", retryable: true)
        }
        guard let http = response as? HTTPURLResponse else {
            throw JanuaryTokenProviderError("Token endpoint returned an invalid response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw JanuaryTokenProviderError(
                "Token endpoint rejected the request.",
                retryable: http.statusCode == 408 || http.statusCode == 429 || http.statusCode >= 500
            )
        }

        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}
```

`authorizationHeader` is an app hook. Return whatever your backend expects, such as `Bearer <your-app-session-token>`.

## Inject configuration and create the client

Resolve the endpoint from required app configuration. Do not provide a guessed or localhost default in production code.

```swift
func makeJanuaryClient(
    tokenEndpoint: URL,
    appAuthorizationHeader: @escaping @Sendable () async throws -> String
) throws -> JanuaryClient {
    let provider = PartnerBackendTokenProvider(
        endpoint: tokenEndpoint,
        authorizationHeader: appAuthorizationHeader
    )
    return try JanuaryClient(clientTokenProvider: provider)
}
```

`JanuaryClient` always targets January's production Partner API through its documented client-token initializers. It exposes no API-origin override.

Create a lightweight user-scoped client for resource calls so user context and
timezone are configured once:

```swift
let user = client.forUser(
    partnerUserID,
    timezone: TimeZone.current.identifier
)

let results = try await user.foods.search(.init(query: "greek yogurt"))
```

With client-token authentication, the token remains authoritative for identity.
The SDK removes `x-end-user-id` before calling January, so the scoped context
cannot override the user bound to the token. The scoped timezone is applied to
operations that support it.

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
let client = try JanuaryClient(clientToken: clientTokenValue)
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

let provider = try JanuaryDevelopmentTokenProvider(
    apiKey: apiKey,
    endUserID: PartnerUserID(rawValue: rawUserID),
    ttlSeconds: 300
)
let client = try JanuaryClient(clientTokenProvider: provider)
#endif
```

The supported lifetime is 300–7,200 seconds. A 300-second token reaches the
SDK's 60-second proactive-refresh window after approximately four minutes. When
your backend becomes available, replace this helper with your own provider; the
`JanuaryClient` construction and resource calls stay the same.

## Local development API-key authentication

{% hint style="danger" %}
`developmentAPIKey` is only for local testing. Do not use it in production, include an API key in a distributed app, or commit one to source control. Use `JanuaryTokenProvider` for production.
{% endhint %}

Load the key from local Xcode scheme configuration instead of putting it in Swift source:

```swift
import Foundation
import JanuarySDK

guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"] else {
    fatalError("Set JANUARY_API_KEY in the local Xcode scheme.")
}
guard let rawUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set JANUARY_END_USER_ID in the local Xcode scheme.")
}

let client = try JanuaryClient(
    developmentAPIKey: apiKey,
    endUserID: PartnerUserID(rawValue: rawUserID)
)
```

Xcode intentionally marks this initializer as deprecated so every call site displays the warning. Supplying a nonempty key also writes the same warning to the Xcode console at runtime without logging the key itself. An empty or whitespace-only value fails validation without logging a warning.

The required end-user ID is your own stable, non-identifying ID for the user exercising the SDK. Development API-key mode binds the client to that ID and applies it to every request, overriding a conflicting request value. Do not use the SDK developer's personal ID, an email address, or a display name.
