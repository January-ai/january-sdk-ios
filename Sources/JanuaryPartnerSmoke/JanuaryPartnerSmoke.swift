import Foundation
import JanuaryPartnerSDK

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
        let client = try JanuaryPartnerClient(developmentAPIKey: apiKey)
        let result = try await client.foods.search(
            SearchFoodsRequest(
                query: query,
                limit: 3,
                endUserID: PartnerUserID(rawValue: endUserID)
            )
        )

        print("Development food search succeeded with \(result.items.count) returned items.")
    }
}
