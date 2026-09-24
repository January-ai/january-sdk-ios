# Retries and concurrency

Getting a token and calling January follow different retry rules.

## Token lifecycle

With a token provider, the SDK:

* keeps the token in memory only, never on disk;
* asks the provider for a new token 60 seconds before the current one expires;
* shares one provider call among concurrent requests that need a token, so five requests on a cold start make one call to your backend;
* retries provider failures marked `retryable: true` (see below); and
* after January answers `401 token_expired`, gets a new token and replays the call once.

A token must report more than 60 seconds of lifetime ([validation limits](validation.md)). January issues tokens for 300–7200 seconds, so a token from your endpoint passes.

## Provider retries

By default the SDK calls the provider up to nine times: once, then eight retries. With no jitter, the waits between attempts are:

```text
1s → 2s → 4s → 8s → 8s → 8s → 8s → 8s
```

Each wait gets ±20% jitter and is capped at 8 seconds, so an unreachable token endpoint fails the call after about 45 seconds. Only `JanuaryTokenProviderError` with `retryable: true` is retried. Other errors, `CancellationError`, and a returned token that's empty or nearly expired stop at once.

To change the policy, pass `tokenRetryPolicy`:

```swift
let client = try JanuaryClient(
    endUserID: endUserID,
    timezone: TimeZone.current,
    clientTokenProvider: tokenProvider,
    tokenRetryPolicy: JanuaryTokenRetryPolicy(
        maximumAttempts: 4,
        initialDelay: 1,
        multiplier: 2,
        maximumDelay: 4,
        jitterRatio: 0.2
    )
)
```

`maximumAttempts` counts the first call. Pass `.none` for a single attempt.

## January API replay

Only a January response with HTTP status `401` and the code `token_expired` makes the SDK drop its token. It then gets a new token and replays the original call once. `token_invalid`, `token_revoked`, scope errors, and every other failure reach your code at once.

The SDK retries nothing else. Don't wrap SDK calls in an unbounded retry loop.

## Retrying creates

Creating a food, water, or weight log isn't idempotent: sending the same create twice records two entries, and for water, counts twice toward the daily cap. If a create times out, list the day (or get the food log) to see whether it was recorded before you retry. The `token_expired` replay is safe, because January rejects that request before recording anything.

## Cancellation

Cancellation is reported as `CancellationError`. A canceled caller stops waiting, but a token refresh it shared with other callers can still finish for them. Treat cancellation as control flow, not as an error to retry or display.
