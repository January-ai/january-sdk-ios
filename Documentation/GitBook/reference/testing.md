# Testing your integration

Test your token provider on its own, then the token lifecycle against a real endpoint.

## Token provider

Check that your provider:

1. posts to the configured URL with the app session in `Authorization`;
2. sends `January-End-User-ID`, which the token relay needs;
3. decodes January's token response unchanged;
4. throws `JanuaryTokenProviderError` for every failure, with `retryable: true` only for network errors, timeouts, and HTTP 408, 429, and 5xx;
5. never logs token responses; and
6. has no fallback URL.

Use a `URLProtocol` subclass or an injected `URLSession` configuration to test it without a live server.

## Token lifecycle

To see refresh happen quickly, have your endpoint mint tokens with `ttl_seconds: 300` (on the [token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay), set `TOKEN_TTL_SECONDS=300`). The SDK then asks for a new token after about 240 seconds. Check that:

* the provider is called again before the token expires;
* concurrent calls on a cold start make one provider call;
* a provider marked retryable is retried with backoff and then fails; and
* other authentication errors don't cause a refresh loop.

The expected behavior is in [Retries and concurrency](retries-and-concurrency.md).

## Consumer build

Keep a small app or package that depends on the same SDK release as production. It should import `January`, create a provider-backed client, and compile representative calls. That catches product-name, access-control, deployment-target, and concurrency problems when you update the SDK.
