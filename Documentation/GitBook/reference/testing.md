# Testing your integration

Test the app/backend boundary separately from January resource behavior.

## Token provider contract

Verify that your provider:

1. sends the configured authentication to your configured backend or testing-relay URL;
2. sends `x-end-user-id` when testing the relay contract;
3. accepts both `expiresIn` and `expires_in` responses;
4. rejects non-2xx responses;
5. never logs token response bodies; and
6. has no fallback endpoint.

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

## Partner-backend integration

Run the optional live integration test against your configured token endpoint
by supplying the same authorization and test-user configuration used by your
app:

```sh
PARTNER_TOKEN_URL=https://your-backend.example.com/january-token \
PARTNER_APP_SESSION_TOKEN=your-app-session-token \
JANUARY_END_USER_ID=your-test-user \
node scripts/check-coverage.mjs
```

The test calls the partner backend, decodes its short-lived token response, and
uses that token through `JanuaryClient` for a real food search. It returns
immediately during ordinary test runs when any required value is absent.
The coverage script selects the first available iPhone Simulator, runs the
complete `JanuarySDKTests` target with coverage enabled, and enforces the
repository's coverage threshold. Swift Testing top-level test names are not
reliable `xcodebuild` filters, so the documented command deliberately runs the
complete target.

## Local lifecycle verification

In a local Debug app, `JanuaryDevelopmentTokenProvider` can verify the complete
token lifecycle without a partner backend. Token lifetime is managed
internally. To test server-expiry replay deterministically, use the SDK's mocked
transport tests rather than placing internal environment URLs in public source
or documentation.

## Consumer build

Keep a minimal app or package that depends on the same SDK release as production. Its build should import `January`, construct a provider-backed client, and compile representative request examples. This catches product-name, module-name, access-control, deployment-target, and concurrency regressions that internal `@testable` tests cannot.

When the repository becomes public, repeat this check from a clean machine without organization credentials.
