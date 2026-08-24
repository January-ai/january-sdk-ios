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
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func searchMenuItems(
        _ request: SearchRestaurantMenuItemsRequest
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
            case .ok(let response): return map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
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
        try validate(
            query: request.query, latitude: request.latitude, longitude: request.longitude,
            radius: request.radius, limit: request.limit
        )
    }

    private func validate(_ request: SearchRestaurantMenuItemsRequest) throws {
        try validate(
            query: request.query, latitude: request.latitude, longitude: request.longitude,
            radius: request.radius, limit: request.limit
        )
    }

    private func validate(query: String, latitude: Double, longitude: Double, radius: Double, limit: Int) throws {
        guard !query.isEmpty, query.count <= 256 else {
            throw JanuaryError(category: .validation, message: "Restaurant search query must contain between 1 and 256 characters.")
        }
        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw JanuaryError(category: .validation, message: "Restaurant coordinates are outside the valid range.")
        }
        guard (1...17_000).contains(radius), (1...100).contains(limit) else {
            throw JanuaryError(category: .validation, message: "Restaurant radius or limit is outside the valid range.")
        }
    }

    private func map(
        _ value: Components.Schemas.SearchRestaurantMenuItemsResponse
    ) -> SearchRestaurantMenuItemsResponse {
        SearchRestaurantMenuItemsResponse(
            totalCount: Int(value.totalCount),
            items: value.items.map { item in
                RestaurantMenuItem(
                    type: item._type,
                    id: item.id,
                    name: item.name,
                    restaurantName: item.restaurantName,
                    isChain: item.isChain,
                    calories: item.nutrients?.calories?.value,
                    protein: item.nutrients?.protein?.value,
                    carbohydrates: item.nutrients?.carbohydrates?.value,
                    netCarbohydrates: item.nutrients?.netCarbohydrates?.value,
                    totalFat: item.nutrients?.totalFat?.value,
                    fiber: item.nutrients?.fiber?.value,
                    totalSugars: item.nutrients?.totalSugars?.value,
                    addedSugars: item.nutrients?.addedSugars?.value,
                    glycemicIndex: item.glycemicIndex,
                    glycemicLoad: item.glycemicLoad,
                    photoURL: item.imageUrl,
                    distance: item.distance,
                    servings: item.servings.map { serving in
                        ServingOption(
                            id: .init(rawValue: serving.id),
                            quantity: serving.quantity,
                            unit: serving.unit,
                            scalingFactor: serving.scalingFactor ?? 1,
                            weightGrams: serving.weightGrams,
                            isPrimary: serving.isPrimary
                        )
                    }
                )
            }
        )
    }
}
