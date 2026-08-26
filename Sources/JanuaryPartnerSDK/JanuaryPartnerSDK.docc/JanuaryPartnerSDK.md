# ``JanuaryPartnerSDK``

Build food and metabolic intelligence into Swift applications with native
Swift concurrency.

## Overview

Create a development client with a runtime-injected key, then call resource
methods with `async`/`await`:

```swift
let client = try JanuaryPartnerClient(developmentAPIKey: developmentAPIKey)
let foods = try await client.foods.search(
    SearchFoodsRequest(query: "banana")
)
```

The current package is private and intended for non-distributable development
integration only. Never embed a January bearer key in an application binary.

The public API is handwritten and grouped into resource domains. The generated
OpenAPI transport is package-private and cannot be imported by SDK consumers.

## Reuse an authenticated user

The integrating app remains the source of truth for user identity. Persist an
opaque partner-owned ID in the app's authenticated session, then create a
lightweight scoped client when that user signs in:

```swift
let user = PartnerUserContext(
    endUserID: PartnerUserID(rawValue: signedInUser.id),
    timezone: TimeZone.current.identifier
)
let userClient = client.forUser(user)

let logs = try await userClient.foodLogs.list(
    start: "2026-08-01",
    end: "2026-08-31"
)
```

The SDK does not persist the context. Clear or replace the app's stored value
when the active account changes.
