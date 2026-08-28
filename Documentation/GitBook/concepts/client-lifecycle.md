# Client lifecycle

Create one `JanuaryClient` for an authenticated app session and reuse it. Every
resource shares the same transport and authentication source. The end-user ID
is required so the provider can mint tokens for the correct user. If no
timezone is supplied, the SDK uses `TimeZone.current`.

```swift
let client = try JanuaryClient(
    endUserID: signedInUser.id,
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

The client covers `foods`, `restaurants`, `foodAnalysis`, `foodLogs`, and
`glucose`. Any configured partner user context and the resolved timezone are
automatically reused across request models.

With client-token authentication, the token is authoritative for identity. The
SDK strips `x-end-user-id` from outgoing January requests; the client still
centralizes the timezone and compatible request context.

## Cancellation

SDK calls participate in Swift structured concurrency. Cancelling the calling task cancels waiting and networking where the underlying transport supports it. `CancellationError` is preserved rather than converted into `JanuaryError`.

Do not automatically retry a cancelled operation.
