# Troubleshooting

## Xcode cannot resolve the package

The repository is private during Controlled Preview. Confirm that:

1. January granted your GitHub account access;
2. Xcode is authenticated to that account;
3. the package URL is exactly `https://github.com/January-ai/partner-sdk-ios.git`;
4. the revision matches [Installation](../getting-started/installation.md); and
5. the `JanuaryPartnerSDK` product is linked to the correct target.

There is no public version tag to select today.

## “A development API key is required”

The value passed to `JanuaryPartnerClient(developmentAPIKey:)` is empty or whitespace-only. Check the runtime injection mechanism. Do not replace it with a hard-coded fallback.

## Authentication or authorization errors

Inspect `JanuaryError.category`, `code`, `httpStatus`, and `requestID` without logging credentials.

For client-token integrations, confirm that the app configured its own partner
backend URL, that the response contains a non-empty `token` and an `expiresIn`
greater than 60 seconds, and that the backend authenticates the current app user.
There is intentionally no default token endpoint in the SDK.

Only `token_expired` triggers automatic refresh and one replay. `token_invalid`, `token_revoked`, and authorization errors require an integration or session fix.

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

## Native scanner reports missing camera usage description

Add a nonempty `NSCameraUsageDescription` string to the host app's `Info.plist`. The ready-made scanner is iOS-only; camera capture requires a physical device.

## Demo refuses to start

Choose exactly one documented demo path. Development-key mode needs `JANUARY_DEMO_API_KEY`. Token mode needs `PARTNER_TOKEN_URL`, `JANUARY_INTERNAL_API_BASE_URL`, and optionally `JANUARY_END_USER_ID`. These variables are for the January-owned demo, not public SDK configuration.

## Requests are rate limited

Read `retryAfterSeconds` from `JanuaryError` when available and delay the retry. Avoid tight automatic retry loops.

## Support diagnostics

Capture the failing operation, SDK revision, platform version, `JanuaryError.category`, `code`, `httpStatus`, and `requestID`. Do not include the API key or user health data.

Send those diagnostics through your January partner support channel. See [Versioning and support](versioning-and-support.md).
