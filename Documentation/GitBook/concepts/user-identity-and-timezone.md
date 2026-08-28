# User identity and timezone

January client tokens are bound to one end user. With client-token authentication, the SDK removes `x-end-user-id` from outgoing January requests so the app cannot contradict the token's identity.

## Partner-owned identifiers

`PartnerUserID` is a typed wrapper for an identifier from your own system:

```swift
let partnerUserID = PartnerUserID(rawValue: account.stableID)
```

Do not use an email address, display name, or other directly identifying value. Keep the mapping in your system.

## Set the user once

Create one client after authentication. It keeps the active app account and timezone together for Foods, Restaurants, Photo Scanning, Food Logs, and Glucose:

```swift
let client = try JanuaryClient(
    endUserID: partnerUserID,
    timezone: "America/New_York",
    clientTokenProvider: tokenProvider
)

let logs = try await client.foodLogs.list(
    start: "2026-08-01",
    end: "2026-08-31"
)

let foods = try await client.foods.search(
    .init(query: "greek yogurt")
)
```

Use an IANA timezone identifier such as `America/New_York`.

Request models retain optional identity fields for source compatibility, but
new integrations should configure the general client instead of passing an
end-user ID to every operation. Recreate the client when the signed-in account
changes.

## Client-token behavior

The end-user identity comes from the client token, so the SDK removes
`x-end-user-id` before calling January. A client cannot change the user bound to
that token. Its timezone is sent when the operation supports it, and
its partner user ID remains useful for compatible request context and local
development authentication. Your backend must derive the authenticated user
before requesting the client token.

The SDK does not persist `PartnerUserContext`.
