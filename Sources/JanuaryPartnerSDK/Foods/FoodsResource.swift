import Foundation
import JanuaryPartnerTransport

/// Food operations exposed by ``JanuaryPartnerClient``.
public struct FoodsResource: Sendable {
    private let client: Client

    internal init(client: Client) {
        self.client = client
    }

    /// Searches the January food database by name.
    public func search(_ request: SearchFoodsRequest) async throws -> FoodSearchResults {
        guard !request.query.isEmpty, request.query.count <= 256 else {
            throw JanuaryError(
                category: .validation,
                message: "Food search query must contain between 1 and 256 characters."
            )
        }
        guard (1...40).contains(request.limit) else {
            throw JanuaryError(
                category: .validation,
                message: "Food search limit must be between 1 and 40."
            )
        }

        let input = Operations.SearchFoods.Input(
            query: .init(
                query: request.query,
                category: request.category.map(Components.Schemas.FoodCategory.init),
                limit: request.limit
            ),
            headers: .init(xEndUserId: request.endUserID?.rawValue)
        )

        return try await performTransportRequest {
            try map(await client.searchFoods(input))
        }
    }

    /// Looks up a food by UPC/EAN/GTIN barcode.
    public func lookupByBarcode(_ request: LookupFoodByBarcodeRequest) async throws -> FoodSearchResults {
        let upcBytes = request.upc.utf8
        guard (6...14).contains(upcBytes.count), upcBytes.allSatisfy({ (48...57).contains($0) }) else {
            throw JanuaryError(
                category: .validation,
                message: "Barcode must contain between 6 and 14 ASCII digits."
            )
        }

        return try await performTransportRequest {
            let output = try await client.lookupFoodByBarcode(
                .init(
                    path: .init(upc: request.upc),
                    headers: .init(xEndUserId: request.endUserID?.rawValue)
                )
            )
            switch output {
            case .ok(let response): return map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    /// Parses a natural-language meal description into foods and servings.
    public func searchByNaturalLanguage(
        _ request: SearchFoodsByNaturalLanguageRequest
    ) async throws -> SearchFoodsByNaturalLanguageResponse {
        guard !request.query.isEmpty, request.query.count <= 512 else {
            throw JanuaryError(
                category: .validation,
                message: "Natural-language food search query must contain between 1 and 512 characters."
            )
        }

        return try await performTransportRequest {
            let output = try await client.searchFoodsByNaturalLanguage(
                .init(
                    query: .init(query: request.query),
                    headers: .init(xEndUserId: request.endUserID?.rawValue)
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    /// Suggests healthier alternatives for a food.
    public func suggestAlternatives(
        _ request: SuggestFoodAlternativesRequest
    ) async throws -> SuggestFoodAlternativesResponse {
        guard !request.dietRestrictions.isEmpty, !request.dietPreferences.isEmpty else {
            throw JanuaryError(
                category: .validation,
                message: "Diet restrictions and preferences must each contain at least one value; use .none when none apply."
            )
        }

        return try await performTransportRequest {
            let transportBody: Components.Schemas.SuggestFoodAlternativesBody = try ModelBridge.convert(
                SuggestBody(
                    dietRestrictions: request.dietRestrictions,
                    dietPreferences: request.dietPreferences
                )
            )
            let output = try await client.suggestFoodAlternatives(
                .init(
                    path: .init(foodId: request.foodID.rawValue),
                    headers: .init(xEndUserId: request.endUserID?.rawValue),
                    body: .json(transportBody)
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func map(_ output: Operations.SearchFoods.Output) throws -> FoodSearchResults {
        switch output {
        case .ok(let response):
            return map(try response.body.json)
        case .badRequest(let response):
            throw apiError(.validation, status: 400, response: try response.body.json)
        case .unauthorized(let response):
            throw apiError(.authentication, status: 401, response: try response.body.json)
        case .tooManyRequests(let response):
            throw apiError(.rateLimited, status: 429, response: try response.body.json)
        case .undocumented(let statusCode, _):
            throw apiError(errorCategory(for: statusCode), status: statusCode)
        }
    }

    private func map(_ value: Components.Schemas.FoodSearchResults) -> FoodSearchResults {
        FoodSearchResults(
            totalCount: value.totalCount,
            items: value.items.map { item in
                FoodSearchItem(
                    id: FoodID(rawValue: item.id),
                    name: item.name,
                    brandName: item.brandName,
                    calories: item.energy,
                    protein: item.protein,
                    carbohydrates: item.carbs,
                    netCarbohydrates: item.netCarbs,
                    totalFat: item.fat,
                    saturatedFat: item.fatTotalSaturated,
                    fiber: item.fiber,
                    totalSugars: item.sugars,
                    addedSugars: item.addedSugars,
                    sodium: item.sodium,
                    potassium: item.potassium,
                    cholesterol: item.cholesterol,
                    glycemicIndex: item.gi,
                    glycemicLoad: item.gl,
                    photoURL: item.photoUrl,
                    servings: item.servings.map { serving in
                        ServingOption(
                            id: ServingID(rawValue: serving.id),
                            quantity: serving.quantity,
                            unit: serving.unit,
                            scalingFactor: serving.scalingFactor ?? 1.0,
                            weightGrams: serving.weightGrams,
                            isPrimary: serving.isPrimary
                        )
                    }
                )
            }
        )
    }

}

private struct SuggestBody: Codable {
    let dietRestrictions: [DietRestriction]
    let dietPreferences: [DietPreference]
    enum CodingKeys: String, CodingKey {
        case dietRestrictions = "diet_restrictions"
        case dietPreferences = "diet_preferences"
    }
}

private extension Components.Schemas.FoodCategory {
    init(_ category: FoodCategory) {
        switch category {
        case .general: self = .general
        case .branded: self = .branded
        case .recipe: self = .recipe
        }
    }
}
