# Authentication and security

The SDK supports two additive authentication modes:

1. a development API key for current non-distributable integration work; and
2. short-lived client tokens fetched from the integrating app's backend.

The current SDK accepts a development API key when creating `JanuaryPartnerClient`.

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

In a distributable application, provide an asynchronous closure that calls your
own authenticated backend. Your backend derives the current user from its
session and requests a short-lived token from January using its server-side
partner secret.

```swift
let january = try JanuaryPartnerClient(clientTokenProvider: {
    let response = try await partnerBackend.createJanuaryToken()
    return JanuaryClientToken(
        value: response.accessToken,
        expiresAt: response.expiresAt
    )
})
```

The SDK caches the token in memory, refreshes it one minute before expiration,
and coalesces concurrent refreshes. When January returns the standard
`invalid_token` challenge, the SDK refreshes and retries a replayable request
once. It never persists or logs the token.

The provider must call the partner's backend, not January's token-issuance
endpoint. A partner API key must never enter the app process.

## Production applications

The development-key initializer remains available while January rolls out the
token service, but it is intended only for non-distributable development
integration. Do not invent a client-side key-storage scheme as a substitute.
