# Authentication

A `JanuaryClient` gets client tokens from a token provider, which calls your [backend token endpoint](backend-token-endpoint.md). The SDK keeps each token in memory and asks the provider for a new one shortly before it expires ([token lifecycle](../reference/retries-and-concurrency.md)).

## Write the token provider

```swift
import Foundation
import January

struct BackendTokenProvider: JanuaryTokenProvider {
    let tokenEndpoint: URL
    /// Returns the current app session token. The SDK calls the provider for
    /// the life of the client, so read the session fresh on every call.
    let appSessionToken: @Sendable () async throws -> String

    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        do {
            request.setValue("Bearer \(try await appSessionToken())", forHTTPHeaderField: "Authorization")
        } catch {
            throw JanuaryTokenProviderError("The app session is unavailable.")
        }
        // Only the token relay reads this header. Your production endpoint
        // takes the user from the session and ignores it.
        request.setValue(endUserID, forHTTPHeaderField: "January-End-User-ID")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // Network errors and timeouts are worth retrying.
            throw JanuaryTokenProviderError("Your token endpoint is unreachable.", retryable: true)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw JanuaryTokenProviderError(
                "Your token endpoint returned HTTP \(status).",
                retryable: status == 408 || status == 429 || status >= 500
            )
        }

        do {
            return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
        } catch {
            throw JanuaryTokenProviderError("Your token endpoint returned an unreadable token response.")
        }
    }
}
```

Throw `JanuaryTokenProviderError` for every failure, as this provider does. The SDK retries the ones marked `retryable: true` with backoff. When the provider fails for good, the call throws an `.authentication` error with the code `client_token_provider_failed`. Any other error type reaches your code as a generic `.transport` or `.decoding` error without your message ([Errors](../reference/error-handling.md#token-provider-failures)).

## Create the client

```swift
func makeJanuaryClient(
    tokenEndpoint: URL,
    endUserID: String,
    appSessionToken: @escaping @Sendable () async throws -> String
) throws -> JanuaryClient {
    try JanuaryClient(
        endUserID: endUserID,
        timezone: TimeZone.current,
        clientTokenProvider: BackendTokenProvider(
            tokenEndpoint: tokenEndpoint,
            appSessionToken: appSessionToken
        )
    )
}
```

Read the token endpoint URL from your app's configuration, and fail at startup when it's missing rather than falling back to a default. Create one client per signed-in account and reuse it ([Client lifecycle](../concepts/client-lifecycle.md)). The [end-user ID and timezone](../concepts/user-identity-and-timezone.md) are fixed for the client's life.

To manage tokens yourself instead, create the client from one token with `JanuaryClient(clientToken:endUserID:timezone:)`. The SDK can't refresh that token, so create a new client before it expires.

## Local development

Three options let you run the app before your token endpoint exists:

| Option | What changes in the app | Use it to |
| --- | --- | --- |
| [Token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay) | Only the provider's URL: `http://localhost:8787/api/january/client-token` from the Simulator | Run the production token flow. Prefer this option. |
| `JanuaryDevelopmentTokenProvider` | The provider, which mints tokens with your API key | Exercise token minting and refresh without running the relay |
| `developmentAPIKey` | The initializer, which sends your API key on every call | Make calls with no client tokens at all |

{% hint style="danger" %}
`JanuaryDevelopmentTokenProvider` and `developmentAPIKey` put your `sk-…` API key in the app process. Do not use it in production: keep both to a local Debug build, load the key from the Xcode scheme, never commit it, and never ship a build that contains it. Release builds don't compile either one, and the SDK logs a warning to the Xcode console (without the key) whenever you use one.
{% endhint %}

Set `JANUARY_API_KEY` under **Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables**. An empty key fails with an `.authentication` error.

### Development token provider

`JanuaryDevelopmentTokenProvider` mints 5-minute tokens with your API key, so the SDK refreshes them about every 4 minutes. Keep the production provider in the `#else` branch:

```swift
#if DEBUG
let client = try JanuaryClient(
    endUserID: endUserID,
    timezone: TimeZone.current,
    clientTokenProvider: JanuaryDevelopmentTokenProvider(
        apiKey: ProcessInfo.processInfo.environment["JANUARY_API_KEY"] ?? ""
    )
)
#else
let client = try makeJanuaryClient(
    tokenEndpoint: tokenEndpoint,
    endUserID: endUserID,
    appSessionToken: { try await session.accessToken() }
)
#endif
```

{% hint style="warning" %}
In 0.3.2 this provider's tokens don't include the `water_logs:*` or `weight_logs:*` scopes, so water and weight calls fail with `403 scope_insufficient`. Use the token relay to test them.
{% endhint %}

### Development API key

`developmentAPIKey` skips client tokens and sends your API key on every call:

```swift
#if DEBUG
let client = try JanuaryClient(
    developmentAPIKey: ProcessInfo.processInfo.environment["JANUARY_API_KEY"] ?? "",
    endUserID: endUserID,
    timezone: TimeZone.current
)
#else
let client = try makeJanuaryClient(
    tokenEndpoint: tokenEndpoint,
    endUserID: endUserID,
    appSessionToken: { try await session.accessToken() }
)
#endif
```

Next: [First request](quick-start.md).
