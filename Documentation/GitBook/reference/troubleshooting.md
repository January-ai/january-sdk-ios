# Troubleshooting

## Xcode cannot resolve the package

Confirm that the GitHub account configured in Xcode has access to the private `January-ai/partner-sdk-ios` repository. Then retry package resolution.

## “A development API key is required”

The value passed to `JanuaryPartnerClient(developmentAPIKey:)` is empty or whitespace-only. Check the runtime injection mechanism. Do not replace it with a hard-coded fallback.

## Authentication or authorization errors

Inspect the `JanuaryError` category and HTTP status. Confirm that the development key is active and authorized for the requested Partner API environment.

For client-token integrations, confirm that the app configured its own partner
backend URL, that the response contains a non-empty `token` and an `expiresIn`
greater than 60 seconds, and that the backend authenticates the current app user.
There is intentionally no default token endpoint in the SDK.

## Token provider is called repeatedly

The SDK refreshes one minute before expiration. A token whose reported lifetime
is 60 seconds or less is rejected as already or nearly expired. Concurrent calls
share one refresh, and only `401` with `code: "token_expired"` triggers a refresh
and one API replay.

## Food search validation errors

Name searches require 1–256 characters and a limit from 1–40. Natural-language searches allow up to 512 characters.

## Restaurant validation errors

Check coordinate ranges, radius, and result limit. See [Restaurants](../guides/restaurants.md#input-limits).

## Photo scan fails with content too large

Reduce the source image dimensions or JPEG quality before building the data URI. Do not retry the same oversized payload.

## Requests are rate limited

Read `retryAfterSeconds` from `JanuaryError` when available and delay the retry. Avoid tight automatic retry loops.

## Support diagnostics

Capture the failing operation, SDK revision, platform version, `JanuaryError.category`, `code`, `httpStatus`, and `requestID`. Do not include the API key or user health data.
