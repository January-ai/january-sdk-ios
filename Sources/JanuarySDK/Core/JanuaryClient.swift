import Foundation
import JanuaryPartnerTransport
import OSLog
import OpenAPIRuntime
import OpenAPIURLSession

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
    public let photoScanning: PhotoScanningResource
    public let foodLogs: FoodLogsResource
    public let glucose: GlucoseResource

    /// Creates a client using API-key authentication for local development only.
    ///
    /// - Warning: Do not use API-key authentication in a production or
    ///   distributed app. Never embed an API key in an app binary or commit it to
    ///   source control. Use ``JanuaryTokenProvider`` in production.
    @available(*, deprecated, message: "Local testing only. Do not ship your app with this key; use JanuaryTokenProvider for production authentication.")
    public init(
        developmentAPIKey: String,
        endUserID: PartnerUserID
    ) throws {
        let normalizedAPIKey = try Self.validateDevelopmentAPIKey(
            developmentAPIKey,
            warningHandler: { message in
                Self.authenticationLogger.warning("\(message, privacy: .public)")
            }
        )
        let normalizedEndUserID = try Self.validateDevelopmentEndUserID(endUserID)
        try self.init(
            developmentAPIKey: normalizedAPIKey,
            endUserID: normalizedEndUserID,
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
    public init(
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        try self.init(
            serverURL: Self.productionServerURL,
            transport: URLSessionTransport(),
            clientTokenProvider: clientTokenProvider,
            userAgent: SDKUserAgent.current,
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    /// Explicit non-production API origin used by January-owned demo tooling.
    /// Partner applications should use the production initializer above.
    @_spi(JanuaryDevelopment)
    public init(
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        apiBaseURL: URL,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        try self.init(
            serverURL: apiBaseURL,
            transport: URLSessionTransport(),
            clientTokenProvider: clientTokenProvider,
            userAgent: SDKUserAgent.current,
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    /// Explicit non-production API origin used by January-owned demo tooling
    /// with a named token-provider implementation.
    @_spi(JanuaryDevelopment)
    public init(
        clientTokenProvider: any JanuaryTokenProvider,
        apiBaseURL: URL,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        try self.init(
            clientTokenProvider: { try await clientTokenProvider.fetchClientToken() },
            apiBaseURL: apiBaseURL,
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    /// Creates a client with a short-lived token managed by the integrating app.
    ///
    /// Recreate the client when the token changes. For automatic refresh, use a
    /// `clientTokenProvider` or `JanuaryTokenProvider` implementation.
    public init(
        clientToken: String
    ) throws {
        try self.init(
            clientToken: clientToken,
            serverURL: Self.productionServerURL,
            transport: URLSessionTransport(),
            userAgent: SDKUserAgent.current
        )
    }

    internal init(
        clientToken: String,
        serverURL: URL,
        transport: any ClientTransport,
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
            userAgent: userAgent
        )
    }

    /// Creates a client backed by a named token-provider implementation.
    public init(
        clientTokenProvider: any JanuaryTokenProvider,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default
    ) throws {
        try self.init(
            clientTokenProvider: { try await clientTokenProvider.fetchClientToken() },
            tokenRetryPolicy: tokenRetryPolicy
        )
    }

    internal init(
        developmentAPIKey: String,
        endUserID: PartnerUserID? = nil,
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

    internal static func validateDevelopmentEndUserID(
        _ endUserID: PartnerUserID
    ) throws -> PartnerUserID {
        let normalizedValue = endUserID.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedValue.isEmpty else {
            throw JanuaryError(
                category: .authentication,
                code: "invalid_end_user_id",
                message: "A stable partner end-user ID is required for development API-key authentication."
            )
        }
        return PartnerUserID(rawValue: normalizedValue)
    }

    internal init(
        serverURL: URL,
        transport: any ClientTransport,
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        userAgent: String = SDKUserAgent.current,
        refreshLeeway: TimeInterval = 60,
        tokenRetryPolicy: JanuaryTokenRetryPolicy = .default,
        now: @escaping @Sendable () -> Date = Date.init,
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
            userAgent: userAgent
        )
    }

    private init(
        serverURL: URL,
        transport: any ClientTransport,
        authenticationSource: AuthenticationSource,
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
        self.foods = FoodsResource(client: transportClient)
        self.restaurants = RestaurantsResource(client: transportClient)
        self.photoScanning = PhotoScanningResource(client: transportClient)
        self.foodLogs = FoodLogsResource(client: transportClient)
        self.glucose = GlucoseResource(client: transportClient)
    }
}
