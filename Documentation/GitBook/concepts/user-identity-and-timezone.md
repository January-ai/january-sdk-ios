# User identity and timezone

January client tokens are bound to one end user. With client-token authentication, the SDK removes `x-end-user-id` from outgoing January requests so the app cannot contradict the token's identity.

## Partner-owned identifiers

`PartnerUserID` is a typed wrapper for an identifier from your own system:

```swift
let partnerUserID = PartnerUserID(rawValue: account.stableID)
```

Do not use an email address, display name, or other directly identifying value. Keep the mapping in your system.

## Scoped client

Food Logs and Glucose accept repeated user context. A scoped client keeps that context together:

```swift
let user = client.forUser(
    partnerUserID,
    timezone: "America/New_York"
)

let logs = try await user.foodLogs.list(
    start: "2026-08-01",
    end: "2026-08-31"
)
```

Use an IANA timezone identifier such as `America/New_York`.

## Authentication-mode behavior

| Mode | End-user identity sent to January | Timezone |
| --- | --- | --- |
| Client token | Comes from the token; `x-end-user-id` is removed | Sent when the request supports it |
| Development API key | `PartnerUserID` is sent as `x-end-user-id` | Sent when the request supports it |

The development-key behavior exists for non-distributable integration only. Production apps should let the backend derive the user before minting the client token.

The SDK does not persist `PartnerUserContext`. Rebuild the scoped client when the active app account changes.
