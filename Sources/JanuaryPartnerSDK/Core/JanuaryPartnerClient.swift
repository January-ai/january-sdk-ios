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

        let transportClient = Client(
            serverURL: serverURL,
            transport: transport,
            middlewares: [
                DevelopmentAuthenticationMiddleware(
                    apiKey: developmentAPIKey,
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
