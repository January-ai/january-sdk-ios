# Errors

SDK calls throw `JanuaryError` for local validation, authentication, API error responses, networking, timeouts, and unreadable responses. A canceled task throws `CancellationError` instead.

## Handle an error

```swift
do {
    let results = try await client.foods.search(.init(query: "banana"))
    display(results)
} catch is CancellationError {
    return
} catch let error as JanuaryError {
    switch (error.category, error.code) {
    case (.authorization, "scope_insufficient"?):
        reportIntegrationFailure(error) // Your backend minted the token without this scope.
    case (.authentication, _), (.authorization, _):
        showSignInOrConnectionError()
    case (.validation, _):
        showInputError(error.message)
    case (.rateLimited, "rate_limited"?):
        showRetryState() // A short limit: retry later, with backoff.
    case (.rateLimited, _):
        showQuotaExhausted() // The monthly allowance is spent: don't retry.
    case (.timeout, _), (.transport, _), (.server, _):
        showRetryState()
    case (.notFound, _):
        showNotFoundState()
    case (.decoding, _):
        reportIntegrationFailure(error)
    }
} catch {
    showRetryState()
}
```

Branch on `category`, and on `code` where it matters. Codes and when to retry them are in the [API error table](https://docs.january.ai/rest-api/api-overview#errors). Retry only `rate_limited`, with backoff. `request_limit_exceeded` and `credit_limit_exceeded` reset next month; don't retry them.

## Properties

| Property | Description |
| --- | --- |
| `category` | `ErrorCategory` for your control flow |
| `code` | The API's error code, such as `scope_insufficient`; `nil` for most local errors |
| `message` | A developer-facing description |
| `httpStatus` | The HTTP status, when the API responded |
| `requestID` | Always `nil` in 0.3.2 |
| `retryAfterSeconds` | Always `nil` in 0.3.2; the SDK doesn't read `Retry-After` |

Think before showing `message` to users. Never log credentials, photo contents, nutrition details, or health-profile data while you diagnose an error.

A `409` response has the code `conflict`. It's a `.validation` error, because sending the same request again fails the same way: change the request instead of retrying it. For a status an operation doesn't document, `code` and `message` are still the ones the API returned.

The SDK handles `401 token_expired` itself: it gets a new token and replays the call once. Don't wrap SDK calls in your own authentication retry loop.

## Token provider failures

What your token provider throws decides the error the call gets:

| Your provider | The call throws |
| --- | --- |
| Throws `JanuaryTokenProviderError(retryable: false)` | `.authentication`, code `client_token_provider_failed`, with your message. No January request is made. |
| Throws `JanuaryTokenProviderError(retryable: true)` on every attempt | `.authentication`, code `client_token_provider_failed`, "The app could not obtain a January client token after 9 attempts." |
| Throws a `DecodingError` | `.decoding`, "The January API returned an unreadable response." |
| Throws any other error | `.transport`, "The request to the January API failed." |
| Returns an empty token | `.authentication`, code `invalid_client_token` |
| Returns an `expiresIn` of 60 seconds or less | `.authentication`, code `invalid_client_token_expiration` |

Throw `JanuaryTokenProviderError` for every failure, as the [sample provider](../getting-started/authentication.md#write-the-token-provider) does, so your own message reaches the call.
