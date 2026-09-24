# Client lifecycle

Create one `JanuaryClient` per signed-in account and reuse it for every call. Its resources (`foods`, `restaurants`, `foodAnalysis`, `foodLogs`, `waterLogs`, `weightLogs`, and `glucose`) share one token cache, and calls can run concurrently:

```swift
async let foods = client.foods.search(.init(query: "oatmeal"))
async let restaurants = client.restaurants.search(
    .init(query: "cafe", latitude: 40.7128, longitude: -74.0060)
)

let (foodResults, restaurantResults) = try await (foods, restaurants)
```

## When to replace it

A client's end-user ID, timezone, and token cache are fixed when you create it. Create a new client when:

* the user signs out (discard the client) or a different account signs in;
* the device timezone changes (`NSSystemTimeZoneDidChange`); or
* you created it with a fixed `clientToken` and that token is about to expire.

Don't create a new client to refresh a token. The SDK refreshes provider tokens itself.

## Keep it in your app

In a SwiftUI app, a main-actor model can own the client and follow the session:

```swift
import Foundation
import January

@MainActor
final class JanuaryConnection: ObservableObject {
    @Published private(set) var client: JanuaryClient?
    private let tokenProvider: BackendTokenProvider
    private var endUserID: String?

    init(tokenProvider: BackendTokenProvider) {
        self.tokenProvider = tokenProvider
    }

    /// Call after sign-in.
    func connect(endUserID: String) throws {
        self.endUserID = endUserID
        client = try JanuaryClient(
            endUserID: endUserID,
            timezone: TimeZone.current,
            clientTokenProvider: tokenProvider
        )
    }

    /// Call on sign-out.
    func disconnect() {
        endUserID = nil
        client = nil
    }

    /// Call when the device timezone changes.
    func reconnect() throws {
        guard let endUserID else { return }
        try connect(endUserID: endUserID)
    }
}
```

`BackendTokenProvider` is the provider from [Authentication](../getting-started/authentication.md#write-the-token-provider). Call `reconnect()` from your root view:

```swift
.onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
    try? connection.reconnect()
}
```

## Cancellation

SDK calls support Swift task cancellation. Cancel the task and the call throws `CancellationError`, not a `JanuaryError`. Don't retry or display it.

Next: [User identity and timezone](user-identity-and-timezone.md).
