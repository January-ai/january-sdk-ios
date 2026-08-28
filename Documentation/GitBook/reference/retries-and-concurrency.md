# Retries and concurrency

Token acquisition and January API operations have intentionally different retry rules.

## Provider retries

The default `JanuaryTokenRetryPolicy` allows nine total provider calls. With zero jitter, delays after failures are:

```text
1s → 2s → 4s → 8s → 8s → 8s → 8s → 8s
```

The default adds ±20% jitter and caps the result at 8 seconds. `maximumAttempts` includes the initial call.

Only `JanuaryTokenProviderError` values with `retryable: true` are retried.
Ordinary errors and `CancellationError` stop immediately. A successfully
returned but empty or nearly expired token fails validation without retrying.

```swift
let noProviderRetry = try JanuaryClient(
    clientTokenProvider: tokenProvider,
    tokenRetryPolicy: .none
)
```

## Single-flight refresh

Concurrent January requests that need a token share one provider refresh. Five cold-cache requests should not cause five partner-backend calls.

The token is cached only while its reported lifetime remains more than the 60-second refresh leeway. The SDK does not persist it.

## January API replay

Only a January response with both of these properties triggers token invalidation:

* HTTP status `401`; and
* JSON body `code` equal to `token_expired`.

The SDK obtains a replacement token and replays the original operation once when the request body is replayable. `token_invalid`, `token_revoked`, scope errors, and other failures surface immediately.

Do not wrap SDK calls in an unbounded authentication retry loop.

## Cancellation

Cancellation is preserved as `CancellationError`. A cancelled caller stops waiting; a shared token refresh may still complete for another concurrent caller. Treat cancellation as control flow, not as an error to retry or display.
