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
