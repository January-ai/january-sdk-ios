# Client lifecycle

Create one `JanuaryClient` for an authenticated app session and reuse it. Give
that client the active user's ID and timezone at initialization. Every resource
shares the same transport, authentication source, and user context.

```swift
let client = try JanuaryClient(
    endUserID: partnerUserID,
    timezone: TimeZone.current.identifier,
    clientTokenProvider: tokenProvider
)

async let foods = client.foods.search(.init(query: "oatmeal"))
async let restaurants = client.restaurants.search(
    .init(query: "cafe", latitude: 40.7128, longitude: -74.0060)
)

let (foodResults, restaurantResults) = try await (foods, restaurants)
```

## When to recreate it

Recreate the client when:

* the signed-in app account changes;
* you intentionally replace a fixed app-managed client token; or
* the app's dependency graph is rebuilt.

Do not recreate a provider-backed client for ordinary token refresh. The SDK caches and refreshes provider tokens itself. Recreate the client when the signed-in account or request context changes.

## Resource values

The client covers `foods`, `restaurants`, `photoScanning`, `foodLogs`, and
`glucose`. Its stable partner user context and timezone are automatically
reused across request models.

With client-token authentication, the token is authoritative for identity. The
SDK strips `x-end-user-id` from outgoing January requests; the client still
centralizes the timezone and compatible request context.

## Cancellation

SDK calls participate in Swift structured concurrency. Cancelling the calling task cancels waiting and networking where the underlying transport supports it. `CancellationError` is preserved rather than converted into `JanuaryError`.

Do not automatically retry a cancelled operation.
