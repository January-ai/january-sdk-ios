import Foundation
import Testing
@testable import January

private struct LivePartnerTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String
    let performRequest: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    init(
        endpoint: URL,
        appSessionToken: String,
        performRequest: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = {
            try await URLSession.shared.data(for: $0)
        }
    ) {
        self.endpoint = endpoint
        self.appSessionToken = appSessionToken
        self.performRequest = performRequest
    }

    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(appSessionToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(endUserID, forHTTPHeaderField: "x-end-user-id")
        let (data, response) = try await performRequest(request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw LiveIntegrationError.tokenRequestFailed
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

private actor RelayRequestProbe {
    private(set) var request: URLRequest?

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(#"{"token":"ct-relay","expiresIn":1800}"#.utf8), response)
    }
}

private enum LiveIntegrationError: Error {
    case tokenRequestFailed
}

@Test
func relayProviderUsesVerifiedRequestContract() async throws {
    let probe = RelayRequestProbe()
    let provider = LivePartnerTokenProvider(
        endpoint: URL(string: "https://relay.example.test/api/january/client-token")!,
        appSessionToken: "fixture-relay-secret",
        performRequest: { request in try await probe.perform(request) }
    )

    let token = try await provider.fetchClientToken(for: "fixture-user")
    let request = try #require(await probe.request)

    #expect(token == JanuaryClientToken(token: "ct-relay", expiresIn: 1_800))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-relay-secret")
    #expect(request.value(forHTTPHeaderField: "x-end-user-id") == "fixture-user")
}

@Test
func livePartnerTokenProviderCallsPartnerBackendAndJanuaryWhenConfigured() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard
        let rawTokenURL = environment["PARTNER_TOKEN_URL"],
        let tokenURL = URL(string: rawTokenURL),
        let appSessionToken = environment["PARTNER_APP_SESSION_TOKEN"],
        !appSessionToken.isEmpty,
        let endUserID = environment["JANUARY_END_USER_ID"],
        !endUserID.isEmpty
    else {
        return
    }
    let provider = LivePartnerTokenProvider(
        endpoint: tokenURL,
        appSessionToken: appSessionToken
    )
    let client = try JanuaryClient(
        endUserID: endUserID,
        clientTokenProvider: provider,
        tokenRetryPolicy: .none
    )

    let results = try await client.foods.search(
        .init(query: "banana", limit: 1)
    )

    #expect(!results.items.isEmpty)
    #expect(results.items[0].name.lowercased().contains("banana"))
}
