import Foundation
import JanuaryPartnerSDK

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresAt: String
}

@main
enum JanuaryPartnerTokenSmoke {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        let partnerURL = URL(
            string: environment["PARTNER_TOKEN_URL"] ?? "http://127.0.0.1:4020/api/january/token"
        )!
        let januaryURL = URL(
            string: environment["JANUARY_BASE_URL"] ?? "http://127.0.0.1:4010"
        )!
        let endUserID = environment["JANUARY_END_USER_ID"] ?? "local-ios-user"

        let client = try JanuaryPartnerClient(serverURL: januaryURL) {
            var request = URLRequest(url: partnerURL)
            request.httpMethod = "POST"
            request.setValue(endUserID, forHTTPHeaderField: "x-demo-user-id")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw SmokeError.tokenRequestFailed
            }
            let wire = try JSONDecoder().decode(TokenResponse.self, from: data)
            guard let expiresAt = iso8601Date(wire.expiresAt) else {
                throw SmokeError.invalidExpiration
            }
            return JanuaryClientToken(value: wire.accessToken, expiresAt: expiresAt)
        }

        let results = try await client.foods.search(
            SearchFoodsRequest(
                query: "banana",
                endUserID: PartnerUserID(rawValue: endUserID)
            )
        )
        guard results.items.first?.name == "Banana" else {
            throw SmokeError.unexpectedFoodResponse
        }
        print("Client-token smoke passed for \(endUserID); token value was not logged.")
    }

    private static func iso8601Date(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

private enum SmokeError: Error {
    case tokenRequestFailed
    case invalidExpiration
    case unexpectedFoodResponse
}
