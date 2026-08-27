# Testing your integration

Test the app/backend boundary separately from January resource behavior.

## Token provider contract

Verify that your provider:

1. sends the app's session authentication to your configured backend URL;
2. accepts both `expiresIn` and `expires_in` responses;
3. rejects non-2xx responses;
4. never logs token response bodies; and
5. has no fallback endpoint.

Use `URLProtocol` or an injected `URLSession` configuration to test the provider without a live server.

## Refresh behavior

In an integration environment, use a short-lived server token or a controlled clock to verify:

* proactive refresh inside the 60-second leeway;
* one provider call for concurrent cold-cache requests;
* bounded 1, 2, 4, 8-second retry scheduling;
* one January API replay after `401 token_expired`; and
* no refresh loop for other authentication codes.

## Repository checks

From an authorized checkout:

```sh
node scripts/check-coverage.mjs
```

This runs the SDK tests on an iPhone Simulator with code coverage enabled. The tests cover the public resource surface, transport mapping, validation, token decoding, caching, single-flight refresh, retry exhaustion, jitter bounds, cancellation, and `token_expired` replay.

## Live client-token integration

With the development stand-in partner backend running, execute the live iOS
integration test by supplying its endpoint and January's development API origin:

```sh
PARTNER_TOKEN_URL=http://127.0.0.1:8787/january-token \
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai \
JANUARY_END_USER_ID=local-ios-e2e-user \
xcodebuild -scheme JanuarySDK-Package \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  -only-testing:JanuarySDKTests \
  test
```

The test calls the partner backend, decodes its short-lived token response, and
uses that token through `JanuaryClient` for a real food search. It returns
immediately during ordinary test runs when the two required URLs are absent.
Swift Testing top-level test names are not reliable `xcodebuild` filters, so the
documented command deliberately selects the complete `JanuarySDKTests` target.

## Consumer build

Keep a minimal app or package that depends on the same pinned preview revision as production. Its build should import `JanuarySDK`, construct a provider-backed client, and compile representative request examples. This catches product-name, module-name, access-control, deployment-target, and concurrency regressions that internal `@testable` tests cannot.

When a public release exists, repeat this check from a clean machine without organization credentials.
