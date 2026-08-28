# Authentication API

## JanuaryClient

```swift
public struct JanuaryClient: Sendable {
    public let foods: FoodsResource
    public let restaurants: RestaurantsResource
    public let foodAnalysis: FoodAnalysisResource
    public let foodLogs: FoodLogsResource
    public let glucose: GlucoseResource

    public init(
        endUserID: String,
        timezone: TimeZone? = nil,
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws
    public init(
        endUserID: String,
        timezone: TimeZone? = nil,
        clientTokenProvider: any JanuaryTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws
    public init(
        clientToken: String,
        endUserID: String,
        timezone: TimeZone? = nil
    ) throws

    public init(
        developmentAPIKey: String,
        endUserID: String,
        timezone: TimeZone? = nil
    ) throws
}
```

The client-token initializers target January production. `clientToken` rejects an empty value and cannot refresh itself.

`developmentAPIKey` is supported for local Debug testing and emits a runtime console warning for a nonempty key. The SDK never includes the key in that warning. Release builds reject the initializer at compile time. Its `endUserID` is required. Never ship an API key in a production or distributed app; use `JanuaryTokenProvider` instead.

## Token provider

```swift
public struct JanuaryClientToken: Codable, Hashable, Sendable {
    public let token: String
    public let expiresIn: TimeInterval
    public init(token: String, expiresIn: TimeInterval)
}

public typealias JanuaryClientTokenProvider =
    @Sendable (_ endUserID: String) async throws -> JanuaryClientToken

public protocol JanuaryTokenProvider: Sendable {
    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken
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
    public init(apiKey: String) throws

    public func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken
}
```

This provider exercises the production client-token lifecycle without a partner
backend. Token lifetime is managed internally. It emits a runtime warning that
never contains the key. Release builds reject its
initializer at compile time. It is strictly for a local Debug build. Never distribute an app containing a
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

## User context

```swift
public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID?
    public var timezone: TimeZone
    public init(endUserID: PartnerUserID? = nil, timezone: TimeZone? = nil)
}
```

Configure the optional end-user ID and timezone directly on `JanuaryClient`.
Its `foods`, `restaurants`, `foodAnalysis`, `foodLogs`, and `glucose` resources
reuse that context automatically. Client-token authentication removes the
end-user header because the token already carries identity. An omitted or blank
timezone resolves to `TimeZone.current`. The SDK sends its `identifier` only at
the HTTP boundary.
