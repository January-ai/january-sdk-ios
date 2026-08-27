# Authentication and security

The SDK supports three mutually exclusive authentication modes:

1. a development API key for current non-distributable integration work; and
2. an app-managed short-lived client token; or
3. short-lived client tokens fetched from the integrating app's backend through
   a callback or `JanuaryTokenProvider` implementation.

Use the provider mode in distributed applications. Fixed client tokens are useful
when the app owns the lifecycle. Development keys are only for January-approved,
non-distributable integration work.

{% hint style="danger" %}
Do not hard-code a January API key in Swift source, commit it to Git, include it in an example, or ship it inside a distributed application. A key embedded in an app binary can be extracted.
{% endhint %}

## Development setup

Inject the key at runtime from a local development mechanism, then create the client:

```swift
import JanuaryPartnerSDK

let january = try JanuaryPartnerClient(
    developmentAPIKey: apiKey
)
```

The initializer rejects empty or whitespace-only keys with an authentication-category `JanuaryError`.

## End-user attribution

Use a stable identifier from your own system when an operation accepts `PartnerUserID`:

```swift
let userID = PartnerUserID(rawValue: partnerOwnedUserID)
```

Do not pass email addresses, names, or other directly identifying information as the raw value. Keep the mapping inside your system.

## Short-lived client tokens

If the app already owns the complete token lifecycle, pass the token directly
and recreate the client when it changes:

```swift
let january = try JanuaryPartnerClient(clientToken: accessToken)
let user = january.forUser(PartnerUserID(rawValue: partnerOwnedUserID))
```

In a distributable application, provide an asynchronous closure that calls your
own authenticated backend. Your backend derives the current user from its
session and requests a short-lived token from January using its server-side
partner secret.

```swift
let january = try JanuaryPartnerClient(clientTokenProvider: {
    try await partnerBackend.createJanuaryToken()
})
```

The same integration can use a named provider object when that fits the app's
dependency-injection architecture:

```swift
struct AppJanuaryTokenProvider: JanuaryTokenProvider {
    let partnerBackend: PartnerBackend

    func fetchClientToken() async throws -> JanuaryClientToken {
        try await partnerBackend.createJanuaryToken()
    }
}

let january = try JanuaryPartnerClient(
    clientTokenProvider: AppJanuaryTokenProvider(partnerBackend: partnerBackend)
)
```

By default, a failed provider fetch gets nine total attempts (eight retries) with
exponential backoff and ±20% jitter. Nominal delays are 1, 2, 4, 8, 8, 8, 8,
and 8 seconds. The policy is configurable and can be disabled with
`.none`:

```swift
let january = try JanuaryPartnerClient(
    clientTokenProvider: AppJanuaryTokenProvider(partnerBackend: partnerBackend),
    tokenRetryPolicy: JanuaryTokenRetryPolicy(
        maximumAttempts: 9,
        initialDelay: 1,
        multiplier: 2,
        maximumDelay: 8,
        jitterRatio: 0.2
    )
)
```

Have the backend client decode the response as `JanuaryClientToken`. Its stable
shape is `{ token, expiresIn }`; the decoder also accepts `{ token, expires_in }`
when a backend relays January's response without changing the casing.

The SDK caches the token in memory, refreshes it one minute before expiration,
coalesces concurrent refreshes, and retries failed provider fetches using the
configured bounded policy. Only an HTTP 401 whose JSON body contains
`code: "token_expired"` causes invalidation and one replay of the January API
operation. Other authentication errors stop immediately and surface to the app.
It never persists or logs the token, and client-token requests omit
`x-end-user-id` because the token already
identifies the user.

The provider must call the partner's backend, not January's token-issuance
endpoint. It owns the endpoint URL, HTTP method, session authentication, and
headers. The SDK intentionally has no default token endpoint, so missing app
configuration fails where the app constructs its provider. A partner API key
must never enter the app process.

## Production applications

The development-key initializer remains available while January rolls out the
token service, but it is intended only for non-distributable development
integration. Do not invent a client-side key-storage scheme as a substitute.
