import Foundation
import JanuaryPartnerTransport

/// Food operations exposed by ``JanuaryClient``.
public struct FoodsResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?

    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    /// Returns lightweight food suggestions as a user types.
    public func autocomplete(
        _ request: AutocompleteFoodsRequest
    ) async throws -> AutocompleteFoodsResponse {
        guard request.query.count <= 64 else {
            throw JanuaryError(
                category: .validation,
                message: "Food autocomplete query must contain at most 64 characters."
            )
        }
        guard request.limit.rounded() == request.limit, (1...20).contains(request.limit) else {
            throw JanuaryError(
                category: .validation,
                message: "Food autocomplete limit must be an integer between 1 and 20."
            )
        }

        let output = try await performTransportRequest {
            try await client.autocompleteFoods(
                .init(
                    query: .init(
                        query: request.query,
                        category: request.category.map(Components.Schemas.AutocompleteFoodCategory.init),
                        limit: request.limit
                    ),
                    headers: .init(xEndUserId: resolvedEndUserID(request.endUserID)?.rawValue)
                )
            )
        }
        switch output {
        case .ok(let response):
            let value = try response.body.json
            return AutocompleteFoodsResponse(
                items: value.items.map {
                    FoodSuggestion(
                        id: FoodID(rawValue: $0.id),
                        name: $0.name,
                        brandName: $0.brandName,
                        imageURL: $0.imageUrl,
                        nutrients: $0.nutrients.map(map)
                    )
                }
            )
        case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
        case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
        case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
        case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
        }
    }

    /// Retrieves a complete food record, including every available serving.
    public func get(
        id: FoodID,
        endUserID: PartnerUserID? = nil
    ) async throws -> FoodSearchItem {
        let output = try await performTransportRequest {
            try await client.getFood(
                .init(
                    path: .init(foodId: id.rawValue),
                    headers: .init(xEndUserId: resolvedEndUserID(endUserID)?.rawValue)
                )
            )
        }
        switch output {
        case .ok(let response): return map(try response.body.json)
        case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
        case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
        case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
        case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
        case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
        }
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
            headers: .init(xEndUserId: resolvedEndUserID(request.endUserID)?.rawValue)
        )

        return try await performTransportRequest {
            try map(await client.searchFoods(input))
        }
    }

    /// Looks up a food by UPC/EAN/GTIN barcode.
    public func lookupBarcode(_ request: LookupFoodByBarcodeRequest) async throws -> FoodSearchResults {
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
                    headers: .init(xEndUserId: resolvedEndUserID(request.endUserID)?.rawValue)
                )
            )
            switch output {
            case .ok(let response): return map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    /// Suggests healthier alternatives for a food.
    public func suggestAlternatives(
        _ request: SuggestFoodAlternativesRequest
    ) async throws -> SuggestFoodAlternativesResponse {
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
                    headers: .init(xEndUserId: resolvedEndUserID(request.endUserID)?.rawValue),
                    body: .json(transportBody)
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
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
        case .default(let status, _):
            throw apiError(errorCategory(for: status), status: status)
        }
    }

    private func resolvedEndUserID(_ requestEndUserID: PartnerUserID?) -> PartnerUserID? {
        userContext?.endUserID ?? requestEndUserID
    }

    private func map(_ value: Components.Schemas.FoodSearchResults) -> FoodSearchResults {
        FoodSearchResults(
            totalCount: value.totalCount,
            items: value.items.map(map)
        )
    }

    private func map(_ item: Components.Schemas.FoodSearchItem) -> FoodSearchItem {
        FoodSearchItem(
            id: FoodID(rawValue: item.id),
            name: item.name,
            brandName: item.brandName,
            nutrients: map(item.nutrients),
            calories: item.nutrients.calories?.value,
            protein: item.nutrients.protein?.value,
            carbohydrates: item.nutrients.carbohydrates?.value,
            netCarbohydrates: item.nutrients.netCarbohydrates?.value,
            totalFat: item.nutrients.totalFat?.value,
            saturatedFat: item.nutrients.saturatedFat?.value,
            fiber: item.nutrients.fiber?.value,
            totalSugars: item.nutrients.totalSugars?.value,
            addedSugars: item.nutrients.addedSugars?.value,
            sodium: item.nutrients.sodium?.value,
            potassium: item.nutrients.potassium?.value,
            cholesterol: item.nutrients.cholesterol?.value,
            glycemicIndex: item.glycemicIndex,
            glycemicLoad: item.glycemicLoad,
            photoURL: item.imageUrl,
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

    private func map(_ value: Components.Schemas.NutritionFacts) -> NutritionFacts {
        func amount(_ value: Components.Schemas.NutrientAmount?) -> NutrientAmount? {
            value.map { NutrientAmount(value: $0.value, unit: $0.unit) }
        }
        return NutritionFacts(
            calories: amount(value.calories), protein: amount(value.protein),
            carbohydrates: amount(value.carbohydrates), netCarbohydrates: amount(value.netCarbohydrates),
            totalFat: amount(value.totalFat), transFat: amount(value.transFat),
            saturatedFat: amount(value.saturatedFat), fiber: amount(value.fiber),
            totalSugars: amount(value.totalSugars), addedSugars: amount(value.addedSugars),
            cholesterol: amount(value.cholesterol), calcium: amount(value.calcium),
            iron: amount(value.iron), potassium: amount(value.potassium),
            sodium: amount(value.sodium), vitaminD: amount(value.vitaminD)
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

private extension Components.Schemas.AutocompleteFoodCategory {
    init(_ category: AutocompleteFoodCategory) {
        switch category {
        case .general: self = .general
        case .branded: self = .branded
        }
    }
}
