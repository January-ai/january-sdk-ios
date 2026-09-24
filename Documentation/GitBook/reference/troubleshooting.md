# Troubleshooting

## Xcode cannot resolve the package

Confirm that:

1. the package URL is exactly `https://github.com/January-ai/january-sdk-ios.git`;
2. Xcode selected the latest release described on [Installation](../getting-started/installation.md); and
3. the `January` product is linked to the correct target.

If Xcode resolves the package but says **Unable to load the Read Me**, choose
**File > Packages > Reset Package Caches**, then **File > Packages > Resolve
Package Versions**. The repository contains a root `README.md`; this message
does not indicate a missing package README.

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

Name searches require 1–256 characters, a limit from 1–50, and an offset of 0 or more. Natural-language searches allow up to 512 characters.

## Restaurant validation errors

Check coordinate ranges, radius, and result limit. See [Restaurants](../guides/restaurants.md#input-limits).

## Photo scan fails with content too large

Reduce the source image dimensions or JPEG quality before building the data URI. Do not retry the same oversized payload.

## Native scanner reports missing camera usage description

Add a nonempty `NSCameraUsageDescription` string to the host app's `Info.plist`. The ready-made scanner is iOS-only; camera capture requires a physical device.

## Demo refuses to start

The token-provider path requires `JANUARY_PARTNER_TOKEN_URL` in the Xcode Run
scheme, plus `JANUARY_PARTNER_SESSION_TOKEN` when the endpoint requires
authorization (a local relay does not). Set `JANUARY_END_USER_ID` to the stable
test-user ID you want the demo to use; when omitted, the demo uses
`january-sdk-demo-user`. The token endpoint must return the documented
client-token response.

For the local Debug-only API-key path, remove the token-endpoint variables and
set `JANUARY_API_KEY` instead. Release builds disable this mode. Never commit
the key or distribute a build containing it. See
[Example app](../getting-started/example-app.md).

## Requests are rate limited

Read `retryAfterSeconds` from `JanuaryError` when available and delay the retry. Avoid tight automatic retry loops.

## Support diagnostics

Capture the failing operation, SDK version, platform version, `JanuaryError.category`, `code`, `httpStatus`, and `requestID`. Do not include client tokens or user health data.

Send those diagnostics through your January partner support channel. See [Versioning and support](versioning-and-support.md).
