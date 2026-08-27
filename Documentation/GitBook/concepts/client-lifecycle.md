# Client lifecycle

Create one `JanuaryPartnerClient` for an authenticated app session and reuse it. The client is a `Sendable` value whose resources share the same transport and authentication source.

```swift
let client = try JanuaryPartnerClient(clientTokenProvider: tokenProvider)

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

Do not recreate a provider-backed client for ordinary token refresh. The SDK caches and refreshes provider tokens itself.

## Resource values

The main client exposes `foods`, `restaurants`, `photoScanning`, `foodLogs`, and `glucose`. A user-scoped client from `forUser` exposes convenience wrappers for Food Logs and Glucose.

## Cancellation

SDK calls participate in Swift structured concurrency. Cancelling the calling task cancels waiting and networking where the underlying transport supports it. `CancellationError` is preserved rather than converted into `JanuaryError`.

Do not automatically retry a cancelled operation.
