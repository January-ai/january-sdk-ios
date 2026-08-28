import Foundation
import JanuaryPartnerTransport
import OSLog

/// The entry point for the January SDK.
public struct JanuaryClient: Sendable {
    private static let productionServerURL = URL(string: "https://partners.january.ai")!
    private static let authenticationLogger = Logger(
        subsystem: "ai.january.sdk",
        category: "authentication"
    )
    internal static let developmentAPIKeyWarning =
        "This development API key is for local testing only. Do not ship your app with this key. " +
        "Use JanuaryTokenProvider for production authentication."
    /// Food search operations.
    public let foods: FoodsResource
    public let restaurants: RestaurantsResource
    public let foodAnalysis: FoodAnalysisResource
    public let foodLogs: FoodLogsResource
    public let glucose: GlucoseResource

    /// Creates a client using API-key authentication for local development only.
    ///
    /// - Warning: Do not use API-key authentication in a production or
    ///   distributed app. Never embed an API key in an app binary or commit it to
    ///   source control. Use ``JanuaryTokenProvider`` in production.
#if !DEBUG
    @available(*, unavailable, message: "Development API-key authentication cannot be used in a Release build. Use JanuaryTokenProvider for production authentication.")
#endif
    public init(
        developmentAPIKey: String,
        endUserID: String,
        timezone: TimeZone? = nil
    ) throws {
        let normalizedAPIKey = try Self.validateDevelopmentAPIKey(
            developmentAPIKey,
            warningHandler: { message in
                Self.authenticationLogger.warning("\(message, privacy: .public)")
            }
        )
        let normalizedEndUserID = try Self.validateRequiredEndUserID(endUserID)
        let userContext = Self.userContext(
            endUserID: normalizedEndUserID,
            timezone: timezone
        )
        try self.init(
            developmentAPIKey: normalizedAPIKey,
            endUserID: normalizedEndUserID,
            userContext: userContext,
            serverURL: Self.productionServerURL,
            transport: URLSessionTransport(),
            userAgent: SDKUserAgent.current
        )
    }

    /// Creates a production-shaped client that obtains short-lived credentials
    /// from the integrating app's authenticated backend.
    ///
    /// Tokens are cached in memory, refreshed shortly before expiration, and
    /// never persisted by the SDK. The provider must not return a partner API key.
    /// The end-user ID is required so the integrating backend can mint a token
    /// for the same stable user. When `timezone` is omitted, the SDK uses the
    /// device's current IANA timezone identifier.
    public init(
        endUserID: String,
        timezone: TimeZone? = nil,
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        let normalizedEndUserID = try Self.validateRequiredEndUserID(endUserID)
        let userContext = try Self.validateUserContext(
            endUserID: normalizedEndUserID,
            timezone: timezone
        )
        try self.init(
            serverURL: Self.productionServerURL,
            transport: URLSessionTransport(),
            clientTokenProvider: {
                try await clientTokenProvider(normalizedEndUserID.rawValue)
            },
            userContext: userContext,
            userAgent: SDKUserAgent.current,
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    /// Explicit non-production API origin used by January-owned demo tooling.
    /// Partner applications should use the production initializer above.
    @_spi(JanuaryDevelopment)
    public init(
        endUserID: String,
        timezone: TimeZone? = nil,
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        apiBaseURL: URL,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        let normalizedEndUserID = try Self.validateRequiredEndUserID(endUserID)
        let userContext = try Self.validateUserContext(
            endUserID: normalizedEndUserID,
            timezone: timezone
        )
        try self.init(
            serverURL: apiBaseURL,
            transport: URLSessionTransport(),
            clientTokenProvider: {
                try await clientTokenProvider(normalizedEndUserID.rawValue)
            },
            userContext: userContext,
            userAgent: SDKUserAgent.current,
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    /// Explicit non-production API origin used by January-owned demo tooling
    /// with a named token-provider implementation.
    @_spi(JanuaryDevelopment)
    public init(
        endUserID: String,
        timezone: TimeZone? = nil,
        clientTokenProvider: any JanuaryTokenProvider,
        apiBaseURL: URL,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        try self.init(
            endUserID: endUserID,
            timezone: timezone,
            clientTokenProvider: { try await clientTokenProvider.fetchClientToken(for: $0) },
            apiBaseURL: apiBaseURL,
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    /// Creates a client with a short-lived token managed by the integrating app.
    ///
    /// Recreate the client when the token changes. For automatic refresh, use a
    /// `clientTokenProvider` or `JanuaryTokenProvider` implementation.
    public init(
        clientToken: String,
        endUserID: String,
        timezone: TimeZone? = nil
    ) throws {
        let normalizedEndUserID = try Self.validateRequiredEndUserID(endUserID)
        let userContext = try Self.validateUserContext(
            endUserID: normalizedEndUserID,
            timezone: timezone
        )
        try self.init(
            clientToken: clientToken,
            serverURL: Self.productionServerURL,
            transport: URLSessionTransport(),
            userContext: userContext,
            userAgent: SDKUserAgent.current
        )
    }

    internal init(
        clientToken: String,
        serverURL: URL,
        transport: any ClientTransport,
        userContext: PartnerUserContext? = nil,
        userAgent: String = SDKUserAgent.current
    ) throws {
        let normalizedToken = clientToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedToken.isEmpty else {
            throw JanuaryError(
                category: .authentication,
                code: "invalid_client_token",
                message: "A client token is required."
            )
        }
        self.init(
            serverURL: serverURL,
            transport: transport,
            authenticationSource: .fixedClientToken(normalizedToken),
            userContext: userContext,
            userAgent: userAgent
        )
    }

    /// Creates a client backed by a named token-provider implementation.
    public init(
        endUserID: String,
        timezone: TimeZone? = nil,
        clientTokenProvider: any JanuaryTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        try self.init(
            endUserID: endUserID,
            timezone: timezone,
            clientTokenProvider: { try await clientTokenProvider.fetchClientToken(for: $0) },
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    internal init(
        developmentAPIKey: String,
        endUserID: PartnerUserID? = nil,
        userContext: PartnerUserContext? = nil,
        serverURL: URL,
        transport: any ClientTransport,
        userAgent: String = SDKUserAgent.current
    ) throws {
        guard !developmentAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JanuaryError(
                category: .authentication,
                message: "A development API key is required."
            )
        }

        self.init(
            serverURL: serverURL,
            transport: transport,
            authenticationSource: .developmentAPIKey(
                developmentAPIKey,
                endUserID: endUserID
            ),
            userContext: userContext,
            userAgent: userAgent
        )
    }

    internal static func validateDevelopmentAPIKey(
        _ developmentAPIKey: String,
        warningHandler: (String) -> Void
    ) throws -> String {
        let normalizedAPIKey = developmentAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw JanuaryError(
                category: .authentication,
                message: "A development API key is required."
            )
        }
        warningHandler(developmentAPIKeyWarning)
        return normalizedAPIKey
    }

    internal static func validateEndUserID(
        _ endUserID: PartnerUserID?
    ) throws -> PartnerUserID? {
        guard let endUserID else { return nil }
        let normalizedValue = endUserID.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            throw JanuaryError(
                category: .authentication,
                code: "invalid_end_user_id",
                message: "The end-user ID cannot be empty when supplied."
            )
        }
        return PartnerUserID(rawValue: normalizedValue)
    }

    internal static func validateRequiredEndUserID(
        _ endUserID: String
    ) throws -> PartnerUserID {
        let normalizedValue = endUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            throw JanuaryError(
                category: .authentication,
                code: "invalid_end_user_id",
                message: "A non-empty end-user ID is required."
            )
        }
        return PartnerUserID(rawValue: normalizedValue)
    }

    internal static func validateUserContext(
        endUserID: PartnerUserID?,
        timezone: TimeZone?
    ) throws -> PartnerUserContext {
        let normalizedEndUserID = try validateEndUserID(endUserID)
        return userContext(endUserID: normalizedEndUserID, timezone: timezone)
    }

    private static func userContext(
        endUserID: PartnerUserID?,
        timezone: TimeZone?
    ) -> PartnerUserContext {
        return PartnerUserContext(
            endUserID: endUserID,
            timezone: timezone
        )
    }

    internal init(
        serverURL: URL,
        transport: any ClientTransport,
        clientTokenProvider: @escaping CachedClientTokenProvider,
        userContext: PartnerUserContext? = nil,
        userAgent: String = SDKUserAgent.current,
        refreshLeeway: TimeInterval = 60,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        unitRandom: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) throws {
        self.init(
            serverURL: serverURL,
            transport: transport,
            authenticationSource: .clientToken(
                ClientTokenManager(
                    provider: clientTokenProvider,
                    refreshLeeway: refreshLeeway,
                    retryPolicy: tokenRetryPolicy,
                    now: now,
                    sleep: sleep,
                    unitRandom: unitRandom
                )
            ),
            userContext: userContext,
            userAgent: userAgent
        )
    }

    private init(
        serverURL: URL,
        transport: any ClientTransport,
        authenticationSource: AuthenticationSource,
        userContext: PartnerUserContext?,
        userAgent: String
    ) {
        let transportClient = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [
                AuthenticationMiddleware(
                    source: authenticationSource,
                    userAgent: userAgent
                ),
            ]
        )
        self.foods = FoodsResource(client: transportClient, userContext: userContext)
        self.restaurants = RestaurantsResource(client: transportClient, userContext: userContext)
        self.foodAnalysis = FoodAnalysisResource(client: transportClient, userContext: userContext)
        self.foodLogs = FoodLogsResource(client: transportClient, userContext: userContext)
        self.glucose = GlucoseResource(client: transportClient, userContext: userContext)
    }
}
