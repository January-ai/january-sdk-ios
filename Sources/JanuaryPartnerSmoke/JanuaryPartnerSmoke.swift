import Foundation
@_spi(JanuaryDevelopment) import JanuarySDK

@main
struct JanuaryPartnerSmoke {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let apiKey = environment["JANUARY_API_KEY"], !apiKey.isEmpty else {
            print("Development smoke skipped: JANUARY_API_KEY is not configured.")
            return
        }
        guard let endUserID = environment["JANUARY_END_USER_ID"], !endUserID.isEmpty else {
            print("Development smoke skipped: JANUARY_END_USER_ID is not configured.")
            return
        }

        let query = environment["JANUARY_FOOD_QUERY"] ?? "banana"
        let client = try JanuaryClient(developmentAPIKey: apiKey)
        let userID = PartnerUserID(rawValue: endUserID)
        let suggestions = try await client.foods.autocomplete(
            .init(query: "ban", limit: 5, endUserID: userID)
        )
        guard !suggestions.items.isEmpty else {
            throw SmokeError("Food autocomplete returned no suggestions.")
        }
        let result = try await client.foods.search(
            SearchFoodsRequest(
                query: query,
                limit: 3,
                endUserID: userID
            )
        )
        guard let match = result.items.first else {
            throw SmokeError("Food search returned no foods.")
        }
        let food = try await client.foods.getFood(.init(foodID: match.id, endUserID: userID))
        guard food.servings.count >= 2 else {
            throw SmokeError("The full food record returned fewer than two servings.")
        }
        let primary = try food.portion()
        let alternate = try food.portion(servingID: food.servings[1].id, quantity: 1.5)

        print(
            "PASS Swift SDK food discovery: \(suggestions.items.count) suggestions, " +
            "\(result.items.count) search results, \(food.servings.count) full-record servings, " +
            "calories \(primary.nutrition.calories?.value ?? 0) -> " +
            "\(alternate.nutrition.calories?.value ?? 0)."
        )
    }
}

private struct SmokeError: Error {
    let message: String

    init(_ message: String) {
        self.message = message
    }
}
