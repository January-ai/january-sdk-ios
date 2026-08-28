# Client lifecycle

Create one `JanuaryClient` for an authenticated app session and reuse it. Then
create a lightweight `JanuaryUserClient` to keep the active user's request
context together. Both values are `Sendable`, and all resources share the same
transport and authentication source.

```swift
let client = try JanuaryClient(clientTokenProvider: tokenProvider)
let user = client.forUser(
    partnerUserID,
    timezone: TimeZone.current.identifier
)

async let foods = user.foods.search(.init(query: "oatmeal"))
async let restaurants = user.restaurants.search(
    .init(query: "cafe", latitude: 40.7128, longitude: -74.0060)
)

let (foodResults, restaurantResults) = try await (foods, restaurants)
```

## When to recreate it

Recreate the client when:

* the signed-in app account changes;
* you intentionally replace a fixed app-managed client token; or
* the app's dependency graph is rebuilt.

Do not recreate a provider-backed client for ordinary token refresh. The SDK caches and refreshes provider tokens itself. Recreate the scoped user client when the signed-in account or request context changes.

## Resource values

The main client and the user-scoped client both cover `foods`, `restaurants`,
`photoScanning`, `foodLogs`, and `glucose`. Prefer the user-scoped resources in
app features so the stable partner user context and timezone are not repeated
across request models.

With client-token authentication, the token is authoritative for identity. The
SDK strips `x-end-user-id` from outgoing January requests; the scoped client
still centralizes the timezone and compatible request context.

## Cancellation

SDK calls participate in Swift structured concurrency. Cancelling the calling task cancels waiting and networking where the underlying transport supports it. `CancellationError` is preserved rather than converted into `JanuaryError`.

Do not automatically retry a cancelled operation.
