# Authentication and security

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

## Production applications

The development-key initializer is intended for non-distributable development integration. Before releasing an app, coordinate with January on the supported production authentication flow. Do not invent a client-side key-storage scheme as a substitute.

