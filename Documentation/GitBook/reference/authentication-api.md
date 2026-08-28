# Authentication API

## JanuaryClient

```swift
public struct JanuaryClient: Sendable {
    public let foods: FoodsResource
    public let restaurants: RestaurantsResource
    public let photoScanning: PhotoScanningResource
    public let foodLogs: FoodLogsResource
    public let glucose: GlucoseResource

    public init(
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws
    public init(
        clientTokenProvider: any JanuaryTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws
    public init(clientToken: String) throws

    @available(*, deprecated, message: "Local testing only. Do not ship your app with this key; use JanuaryTokenProvider for production authentication.")
    public init(
        developmentAPIKey: String,
        endUserID: PartnerUserID
    ) throws
}
```

The client-token initializers target January production. `clientToken` rejects an empty value and cannot refresh itself.

`developmentAPIKey` is available only for local testing and intentionally emits both an Xcode warning and a runtime console warning for a nonempty key. The SDK never includes the key in that warning. Its required `endUserID` binds every request to one stable partner-owned test user. Never ship an API key in a production or distributed app; use `JanuaryTokenProvider` instead.

## Token provider

```swift
public struct JanuaryClientToken: Codable, Hashable, Sendable {
    public let token: String
    public let expiresIn: TimeInterval
    public init(token: String, expiresIn: TimeInterval)
}

public typealias JanuaryClientTokenProvider =
    @Sendable () async throws -> JanuaryClientToken

public protocol JanuaryTokenProvider: Sendable {
    func fetchClientToken() async throws -> JanuaryClientToken
}

public struct JanuaryTokenProviderError: Error, LocalizedError, Sendable {
    public let message: String
    public let retryable: Bool

    public init(_ message: String, retryable: Bool = false)
    public var errorDescription: String? { get }
}
```

`JanuaryClientToken` encodes `expiresIn` and decodes either `expiresIn` or `expires_in`. Tokens must be nonempty and report more than 60 seconds of remaining lifetime.

Throw `JanuaryTokenProviderError` with `retryable: true` only for transient
failures such as timeouts, rate limits, and server errors. The SDK applies its
bounded provider retry policy only to that explicit error. The default
`retryable` value is `false`; ordinary errors, permanent authentication or
validation failures, malformed token responses, and `CancellationError` stop
immediately.

## Local development token provider

```swift
public struct JanuaryDevelopmentTokenProvider: JanuaryTokenProvider {
    @available(*, deprecated, message: "Local debug testing only…")
    public init(
        apiKey: String,
        endUserID: PartnerUserID,
        ttlSeconds: Int = 300
    ) throws

    public func fetchClientToken() async throws -> JanuaryClientToken
}
```

This provider exercises the production client-token lifecycle without a partner
backend. It accepts a token lifetime from 300 through 7,200 seconds and emits an
Xcode deprecation warning plus a runtime warning that never contains the key.
It is strictly for a local Debug build. Never distribute an app containing a
January API key; production apps implement `JanuaryTokenProvider` against their
authenticated backend.

## Retry policy

```swift
public struct JanuaryTokenRetryPolicy: Hashable, Sendable {
    public static let `default`: JanuaryTokenRetryPolicy
    public static let none: JanuaryTokenRetryPolicy

    public let maximumAttempts: Int
    public let initialDelay: TimeInterval
    public let multiplier: Double
    public let maximumDelay: TimeInterval
    public let jitterRatio: Double

    public init(
        maximumAttempts: Int = 9,
        initialDelay: TimeInterval = 1,
        multiplier: Double = 2,
        maximumDelay: TimeInterval = 8,
        jitterRatio: Double = 0.2
    )
}
```

Invalid policy values fail a precondition. See [Retries and concurrency](retries-and-concurrency.md).

## User-scoped client

```swift
public extension JanuaryClient {
    func forUser(_ context: PartnerUserContext) -> JanuaryUserClient
    func forUser(
        _ endUserID: PartnerUserID,
        timezone: String? = nil
    ) -> JanuaryUserClient
}

public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID
    public var timezone: String?
    public init(endUserID: PartnerUserID, timezone: String? = nil)
}
```

`JanuaryUserClient` exposes `context`, `foods`, `restaurants`, `photoScanning`,
`foodLogs`, and `glucose`. Configure it once after authentication and use those
scoped resources instead of repeating the user ID in individual requests.
Client-token authentication removes the end-user header because the token
already carries identity.
