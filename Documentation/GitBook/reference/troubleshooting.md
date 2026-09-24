# Troubleshooting

## Xcode can't resolve the package

Check that:

1. the package URL is exactly `https://github.com/January-ai/january-sdk-ios.git`;
2. the dependency rule allows the release you want ([Installation](../getting-started/installation.md)); and
3. the `January` product is linked to your app target.

If Xcode resolves the package but says **Unable to load the Read Me**, choose **File → Packages → Reset Package Caches**, then **File → Packages → Resolve Package Versions**.

## Authentication or authorization errors

Check `JanuaryError.category`, `code`, `httpStatus`, and `message`, without logging credentials.

| What you see | Cause |
| --- | --- |
| `.authentication`, code `client_token_provider_failed` | Your token provider failed; `message` is the provider's. Check your token endpoint's URL and response. |
| `.transport`, "The request to the January API failed.", before any request reaches January | Your token provider threw an error that isn't a `JanuaryTokenProviderError` ([token provider failures](error-handling.md#token-provider-failures)). |
| `.authentication`, code `invalid_client_token_expiration` | Your endpoint returned a token with 60 seconds or less to live. Return January's response unchanged. |
| `.authorization`, code `scope_insufficient` | The token lacks the scope for this call. Mint it with the scopes of every feature your app uses ([scopes](../getting-started/backend-token-endpoint.md#scopes)). |
| `403 forbidden` when your backend mints a token | **Enable client tokens** is off ([Backend token endpoint](../getting-started/backend-token-endpoint.md#enable-client-tokens)). |
| `.authentication`, code `token_invalid` or `token_revoked` | The token isn't valid. The SDK refreshes only on `token_expired`. |

## Water or weight calls fail with `scope_insufficient` in development

`JanuaryDevelopmentTokenProvider` doesn't request the water and weight scopes in 0.3.2. Use the [token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay) instead.

## The token provider is called often

Frequent calls usually mean your endpoint returns short-lived tokens. The SDK asks for a new token only on the schedule in [Token lifecycle](retries-and-concurrency.md#token-lifecycle) and after `401 token_expired`.

## Validation errors

Check the input against [Validation limits](validation.md).

## Food analysis fails with content too large

Reduce the image's dimensions or JPEG quality before you send it. Don't retry the same image.

## The food scanner reports a missing camera usage description

Add a non-empty `NSCameraUsageDescription` string to your app's `Info.plist`. Camera capture needs a physical device.

## The example app won't start

Set `JANUARY_PARTNER_TOKEN_URL` in the Xcode Run scheme, plus `JANUARY_PARTNER_SESSION_TOKEN` when the endpoint requires a session (a local relay doesn't). `JANUARY_END_USER_ID` defaults to `january-sdk-demo-user`. See [Example app](../getting-started/example-app.md).

## Requests are rate limited

Retry only `code == "rate_limited"`, with backoff. `request_limit_exceeded` and `credit_limit_exceeded` reset next month; don't retry them. The SDK doesn't expose the `Retry-After` header in 0.3.2.

## Support diagnostics

Collect the failing operation, the SDK version, the iOS version, the time of the failure, and the error's `category`, `code`, `httpStatus`, and `message`. Don't include client tokens, API keys, or user health data. Send them to your January contact ([Versioning and support](versioning-and-support.md)).
