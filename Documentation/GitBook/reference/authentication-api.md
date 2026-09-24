# Authentication API

## JanuaryClient

```swift
public struct JanuaryClient: Sendable {
    public let foods: FoodsResource
    public let restaurants: RestaurantsResource
    public let foodAnalysis: FoodAnalysisResource
    public let foodLogs: FoodLogsResource
    public let glucose: GlucoseResource
    public let waterLogs: WaterLogsResource
    public let weightLogs: WeightLogsResource

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

    // Debug builds only.
    public init(
        developmentAPIKey: String,
        endUserID: String,
        timezone: TimeZone? = nil
    ) throws
}
```

`clientToken` rejects an empty value, and the SDK can't refresh it. `developmentAPIKey` is for local development only ([local development](../getting-started/authentication.md#local-development)).

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

`JanuaryClientToken` decodes January's token response unchanged: it reads `token` and either `expires_in` or `expiresIn`. It encodes `expiresIn`.

Throw `JanuaryTokenProviderError` from your provider for every failure, with `retryable: true` only for transient ones: network errors, timeouts, and HTTP 408, 429, and 5xx. [Errors](error-handling.md#token-provider-failures) shows what each kind of failure becomes, and [Retries and concurrency](retries-and-concurrency.md) covers caching, refresh, and retries.

## Development token provider

```swift
// Debug builds only.
public struct JanuaryDevelopmentTokenProvider: JanuaryTokenProvider {
    public init(apiKey: String) throws

    public func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken
}
```

It mints 300-second tokens with your API key, for the scopes `foods:read`, `food_analysis:write`, `food_logs:read`, `food_logs:write`, `glucose:read`, and `restaurants:read`. See [local development](../getting-started/authentication.md#development-token-provider).

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

Invalid values fail a precondition. See [provider retries](retries-and-concurrency.md#provider-retries).

## User context

```swift
public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID?
    public var timezone: TimeZone
    public init(endUserID: PartnerUserID? = nil, timezone: TimeZone? = nil)
}
```

Request-value forms of the log operations take a `PartnerUserContext` as `user`. On a `JanuaryClient`, the client's required end-user ID and timezone replace it. The client's `foods`, `restaurants`, `foodAnalysis`, `foodLogs`, `glucose`, `waterLogs`, and `weightLogs` resources all use them ([User identity and timezone](../concepts/user-identity-and-timezone.md)). An omitted `timezone` resolves to `TimeZone.current`.
