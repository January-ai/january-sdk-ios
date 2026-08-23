import JanuaryPartnerTransport

public struct RestaurantsResource: Sendable {
    private let client: Client
    internal init(client: Client) { self.client = client }

    public func search(_ request: SearchRestaurantsRequest) async throws -> SearchRestaurantsResponse {
        try validate(request)
        return try await performTransportRequest {
            let output = try await client.searchRestaurants(input(request))
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func searchMenuItems(
        _ request: SearchRestaurantsRequest
    ) async throws -> SearchRestaurantMenuItemsResponse {
        try validate(request)
        return try await performTransportRequest {
            let value = Operations.SearchRestaurantMenuItems.Input(
                query: .init(
                    radius: request.radius,
                    limit: Double(request.limit),
                    query: request.query,
                    latitude: request.latitude,
                    longitude: request.longitude
                ),
                headers: .init(xEndUserId: request.endUserID?.rawValue)
            )
            let output = try await client.searchRestaurantMenuItems(value)
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func input(_ request: SearchRestaurantsRequest) -> Operations.SearchRestaurants.Input {
        .init(
            query: .init(
                radius: request.radius,
                limit: Double(request.limit),
                query: request.query,
                latitude: request.latitude,
                longitude: request.longitude
            ),
            headers: .init(xEndUserId: request.endUserID?.rawValue)
        )
    }

    private func validate(_ request: SearchRestaurantsRequest) throws {
        guard !request.query.isEmpty, request.query.count <= 256 else {
            throw JanuaryError(category: .validation, message: "Restaurant search query must contain between 1 and 256 characters.")
        }
        guard (-90...90).contains(request.latitude), (-180...180).contains(request.longitude) else {
            throw JanuaryError(category: .validation, message: "Restaurant coordinates are outside the valid range.")
        }
        guard (1...17_000).contains(request.radius), (1...100).contains(request.limit) else {
            throw JanuaryError(category: .validation, message: "Restaurant radius or limit is outside the valid range.")
        }
    }
}
