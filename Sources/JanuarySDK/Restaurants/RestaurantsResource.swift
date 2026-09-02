import Foundation
import JanuaryPartnerTransport

public struct RestaurantsResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?
    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    public func search(_ request: SearchRestaurantsRequest) async throws -> SearchRestaurantsResponse {
        try validate(request)
        return try await performTransportRequest {
            let output = try await client.searchRestaurants(input(request))
            switch output {
            case .ok(let response):
                let value = try response.body.json
                return SearchRestaurantsResponse(
                    totalCount: value.items.count,
                    items: value.items.map { item in
                        Restaurant(
                            type: .restaurant, id: item.id, name: item.name,
                            isChain: item.isChain, distance: item.distanceMeters,
                            city: item.city, address1: item.address1, address2: item.address2
                        )
                    }
                )
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
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
                    radiusMeters: request.radius,
                    limit: request.limit,
                    query: request.query,
                    latitude: request.latitude,
                    longitude: request.longitude
                )
            )
            let output = try await client.searchRestaurantMenuItems(value)
            switch output {
            case .ok(let response): return map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    /// Loads one page of a restaurant's menu by its search-result ID.
    public func getMenuItems(_ request: GetRestaurantMenuItemsRequest) async throws -> GetRestaurantMenuItemsResponse {
        guard request.restaurantID.range(of: "^[A-Za-z0-9_-]{1,256}$", options: .regularExpression) != nil,
              (1...100).contains(request.limit), (0...2_147_483_647).contains(request.offset) else {
            throw JanuaryError(category: .validation, message: "A restaurant id and valid menu pagination are required.")
        }
        return try await performTransportRequest {
            let output = try await client.getRestaurantMenuItems(.init(
                path: .init(restaurantId: request.restaurantID),
                query: .init(limit: request.limit, offset: request.offset)
            ))
            switch output {
            case .ok(let response):
                let value = try response.body.json
                return GetRestaurantMenuItemsResponse(items: value.items.map { item in
                    RestaurantMenuEntry(
                        id: item.id, name: item.name,
                        calories: item.nutrients.calories?.value,
                        protein: item.nutrients.protein?.value,
                        carbohydrates: item.nutrients.carbohydrates?.value,
                        netCarbohydrates: item.nutrients.netCarbohydrates?.value,
                        totalFat: item.nutrients.totalFat?.value,
                        fiber: item.nutrients.fiber?.value,
                        totalSugars: item.nutrients.totalSugars?.value,
                        addedSugars: item.nutrients.addedSugars?.value,
                        glycemicIndex: item.glycemicIndex,
                        glycemicLoad: item.glycemicLoad,
                        servings: item.servings.map(mapServing)
                    )
                })
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func input(_ request: SearchRestaurantsRequest) -> Operations.SearchRestaurants.Input {
        .init(
            query: .init(
                radiusMeters: request.radius,
                limit: request.limit,
                query: request.query,
                latitude: request.latitude,
                longitude: request.longitude
            )
        )
    }

    private func validate(_ request: SearchRestaurantsRequest) throws {
        try validate(
            query: request.query, latitude: request.latitude, longitude: request.longitude,
            radius: request.radius, limit: request.limit
        )
    }

    private func resolvedEndUserID(_ requestEndUserID: PartnerUserID?) -> PartnerUserID? {
        userContext?.endUserID ?? requestEndUserID
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
        guard (1...50_000).contains(radius), (1...100).contains(limit) else {
            throw JanuaryError(category: .validation, message: "Restaurant radius or limit is outside the valid range.")
        }
    }

    private func map(
        _ value: Components.Schemas.SearchRestaurantMenuItemsResponse
    ) -> SearchRestaurantMenuItemsResponse {
        SearchRestaurantMenuItemsResponse(
            totalCount: value.items.count,
            items: value.items.map { item in
                RestaurantMenuItem(
                    type: item._type.rawValue,
                    id: item.id,
                    name: item.name,
                    restaurantName: item.restaurantName,
                    isChain: item.isChain,
                    calories: item.nutrients.calories?.value,
                    protein: item.nutrients.protein?.value,
                    carbohydrates: item.nutrients.carbohydrates?.value,
                    netCarbohydrates: item.nutrients.netCarbohydrates?.value,
                    totalFat: item.nutrients.totalFat?.value,
                    fiber: item.nutrients.fiber?.value,
                    totalSugars: item.nutrients.totalSugars?.value,
                    addedSugars: item.nutrients.addedSugars?.value,
                    glycemicIndex: item.glycemicIndex,
                    glycemicLoad: item.glycemicLoad,
                    photoURL: item.imageUrl,
                    distance: item.distanceMeters,
                    servings: item.servings.map(mapServing)
                )
            }
        )
    }

    private func mapServing(_ serving: Components.Schemas.ServingOption) -> ServingOption {
        ServingOption(
            id: serving.id.map { ServingID(rawValue: $0) },
            quantity: serving.quantity,
            unit: serving.unit,
            scalingFactor: serving.scalingFactor ?? 1,
            weightGrams: serving.weightGrams,
            isPrimary: serving.isPrimary
        )
    }
}
