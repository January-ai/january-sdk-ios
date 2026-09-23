# Error handling

SDK requests throw `JanuaryError` for local validation, authentication, server responses, networking, timeouts, and decoding failures.

```swift
do {
    let results = try await client.foods.search(
        .init(query: "banana")
    )
    display(results)
} catch let error as JanuaryError {
    switch error.category {
    case .authentication, .authorization:
        showSignInOrConnectionError()
    case .validation:
        showInputError(error.message)
    case .rateLimited:
        scheduleRetry(after: error.retryAfterSeconds)
    case .timeout, .transport, .server:
        showRetryState()
    case .notFound:
        showNotFoundState()
    case .decoding:
        reportIntegrationFailure(requestID: error.requestID)
    }
}
```

Handle `CancellationError` separately when your UI starts requests from cancellable tasks:

```swift
do {
    try await loadFoods()
} catch is CancellationError {
    return
} catch let error as JanuaryError {
    show(error)
}
```

## Available metadata

| Property | Description |
| --- | --- |
| `category` | Stable `ErrorCategory` for application control flow |
| `code` | Machine-readable API error code, when supplied |
| `message` | Human-readable failure description |
| `httpStatus` | HTTP status code, when applicable |
| `requestID` | Request identifier for support and diagnostics |
| `retryAfterSeconds` | Server-provided retry delay, when available |

Avoid displaying raw server messages without considering the surrounding user experience. Never log credentials, photo contents, nutrition details, or health-profile data while diagnosing an error.

The SDK itself handles `401 token_expired` by invalidating the cached token,
calling the provider, and replaying the API operation once. Do not add another
unbounded request-retry loop around SDK calls.

A `409` response has the code `conflict`: the request conflicts with an existing resource. It is a `validation` error because sending the same request again fails the same way; change the request instead of retrying it. For a status an operation does not document, `code` and `message` are still the ones the API returned.

Malformed provider tokens produce authentication errors with `invalid_client_token` or `invalid_client_token_expiration`. Exhausted provider fetches produce `client_token_provider_failed` without exposing the provider's underlying error text. A provider that throws `JanuaryTokenProviderError` with `retryable: false`, for example because your token endpoint refused the user, also produces an authentication error with `client_token_provider_failed`, carrying the message your provider supplied; no January API request is made.
