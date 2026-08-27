import Foundation
import Testing
@_spi(JanuaryDevelopment) @testable import JanuarySDK

private struct LivePartnerTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let endUserID: String

    func fetchClientToken() async throws -> JanuaryClientToken {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw LiveIntegrationError.invalidConfiguration
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "user", value: endUserID),
        ]
        guard let url = components.url else {
            throw LiveIntegrationError.invalidConfiguration
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw LiveIntegrationError.tokenRequestFailed
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

private enum LiveIntegrationError: Error {
    case invalidConfiguration
    case tokenRequestFailed
}

@Test
func livePartnerTokenProviderCallsPartnerBackendAndJanuaryWhenConfigured() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard
        let rawTokenURL = environment["PARTNER_TOKEN_URL"],
        let tokenURL = URL(string: rawTokenURL),
        let rawAPIBaseURL = environment["JANUARY_INTERNAL_API_BASE_URL"],
        let apiBaseURL = URL(string: rawAPIBaseURL)
    else {
        return
    }
    let endUserID = environment["JANUARY_END_USER_ID"] ?? "local-ios-e2e-user"
    let provider = LivePartnerTokenProvider(endpoint: tokenURL, endUserID: endUserID)
    let client = try JanuaryClient(
        clientTokenProvider: provider,
        apiBaseURL: apiBaseURL,
        tokenRetryPolicy: .none
    )

    let results = try await client.foods.search(
        .init(query: "banana", limit: 1, endUserID: .init(rawValue: endUserID))
    )

    #expect(!results.items.isEmpty)
    #expect(results.items[0].name.lowercased().contains("banana"))
}
