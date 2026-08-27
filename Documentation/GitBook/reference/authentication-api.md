# Authentication API

## JanuaryPartnerClient

```swift
public struct JanuaryPartnerClient: Sendable {
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
}
```

The documented client-token initializers target January production. `clientToken` rejects an empty value and cannot refresh itself.

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
```

`JanuaryClientToken` encodes `expiresIn` and decodes either `expiresIn` or `expires_in`. Tokens must be nonempty and report more than 60 seconds of remaining lifetime.

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
public extension JanuaryPartnerClient {
    func forUser(_ context: PartnerUserContext) -> JanuaryPartnerUserClient
    func forUser(
        _ endUserID: PartnerUserID,
        timezone: String? = nil
    ) -> JanuaryPartnerUserClient
}

public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID
    public var timezone: String?
    public init(endUserID: PartnerUserID, timezone: String? = nil)
}
```

`JanuaryPartnerUserClient` exposes `context`, `foodLogs`, and `glucose`. Client-token authentication removes the end-user header because the token already carries identity.
