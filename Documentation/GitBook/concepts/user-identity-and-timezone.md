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

## Client-token behavior

The end-user identity comes from the client token, so `x-end-user-id` is removed. The timezone is sent when the request supports it. Your backend should derive the user before requesting the client token.

The SDK does not persist `PartnerUserContext`. Rebuild the scoped client when the active app account changes.
