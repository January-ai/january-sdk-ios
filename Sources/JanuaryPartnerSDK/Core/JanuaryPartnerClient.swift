import Foundation
import JanuaryPartnerTransport
import OpenAPIRuntime
import OpenAPIURLSession

/// The entry point for the January Partner SDK.
public struct JanuaryPartnerClient: Sendable {
    /// Food search operations.
    public let foods: FoodsResource
    public let restaurants: RestaurantsResource
    public let photoScanning: PhotoScanningResource
    public let foodLogs: FoodLogsResource
    public let glucose: GlucoseResource

    /// Creates a client for non-distributable development integration tests.
    ///
    /// The API key is held by this client and added to requests at runtime. Never
    /// embed it in an application, source file, example, or distributed binary.
    public init(developmentAPIKey: String) throws {
        try self.init(
            developmentAPIKey: developmentAPIKey,
            serverURL: URL(string: "https://partners.dev.january.ai")!,
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
        serverURL: URL = URL(string: "https://partners.january.ai")!,
        clientTokenProvider: @escaping JanuaryClientTokenProvider
    ) throws {
        try self.init(
            serverURL: serverURL,
            transport: URLSessionTransport(),
            clientTokenProvider: clientTokenProvider,
            userAgent: SDKUserAgent.current
        )
    }

    internal init(
        developmentAPIKey: String,
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
            authenticationSource: .developmentAPIKey(developmentAPIKey),
            userAgent: userAgent
        )
    }

    internal init(
        serverURL: URL,
        transport: any ClientTransport,
        clientTokenProvider: @escaping JanuaryClientTokenProvider,
        userAgent: String = SDKUserAgent.current,
        refreshLeeway: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) throws {
        self.init(
            serverURL: serverURL,
            transport: transport,
            authenticationSource: .clientToken(
                ClientTokenManager(
                    provider: clientTokenProvider,
                    refreshLeeway: refreshLeeway,
                    now: now
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
