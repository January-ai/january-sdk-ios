import Foundation
import Testing
@testable import January

private actor DevelopmentTokenRequestProbe {
    private(set) var request: URLRequest?
    let responseStatus: Int
    let responseBody: String

    init(
        responseStatus: Int = 201,
        responseBody: String = #"{"token":"ct-development","expires_in":300}"#
    ) {
        self.responseStatus = responseStatus
        self.responseBody = responseBody
    }

    func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatus,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(responseBody.utf8), response)
    }
}

@Test
func developmentTokenProviderMintsAndDecodesClientToken() async throws {
    let probe = DevelopmentTokenRequestProbe()
    var warnings: [String] = []
    let provider = try JanuaryDevelopmentTokenProvider(
        apiKey: "  fixture-development-key  ",
        ttlSeconds: 300,
        endpoint: URL(string: "https://example.invalid/v1.2/auth/client-tokens")!,
        warningHandler: { warnings.append($0) },
        performRequest: { request in try await probe.perform(request) }
    )

    let token = try await provider.fetchClientToken(for: "  demo-user  ")
    let request = try #require(await probe.request)
    let body = try #require(request.httpBody)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )

    #expect(token == JanuaryClientToken(token: "ct-development", expiresIn: 300))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer fixture-development-key")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(json["end_user_id"] as? String == "demo-user")
    #expect(json["ttl_seconds"] as? Int == 300)
    #expect(Set(json["scopes"] as? [String] ?? []) == Set([
        "foods:read",
        "food_analysis:write",
        "food_logs:read",
        "food_logs:write",
        "glucose:read",
        "restaurants:read",
    ]))
    #expect(warnings == [JanuaryDevelopmentTokenProvider.warning])
    #expect(!warnings[0].contains("fixture-development-key"))
}

@Test(arguments: [299, 7_201])
func developmentTokenProviderRejectsInvalidTTL(_ ttlSeconds: Int) {
    #expect(throws: JanuaryError.self) {
        _ = try JanuaryDevelopmentTokenProvider(
            apiKey: "fixture-development-key",
            ttlSeconds: ttlSeconds,
            endpoint: URL(string: "https://example.invalid")!,
            warningHandler: { _ in },
            performRequest: { _ in throw URLError(.badServerResponse) }
        )
    }
}

@Test
func developmentTokenProviderRejectsInvalidIdentity() async throws {
    var warnings: [String] = []
    let provider = try JanuaryDevelopmentTokenProvider(
        apiKey: "fixture-development-key",
        ttlSeconds: 300,
        endpoint: URL(string: "https://example.invalid")!,
        warningHandler: { warnings.append($0) },
        performRequest: { _ in throw URLError(.badServerResponse) }
    )

    do {
        _ = try await provider.fetchClientToken(for: "   ")
        Issue.record("Expected invalid identity to fail.")
    } catch let error as JanuaryError {
        #expect(error.code == "invalid_end_user_id")
    }
    #expect(warnings == [JanuaryDevelopmentTokenProvider.warning])
}

@Test
func developmentTokenProviderMapsRejectedMintWithoutExposingBody() async throws {
    let probe = DevelopmentTokenRequestProbe(
        responseStatus: 401,
        responseBody: #"{"message":"sensitive response","code":"unauthorized"}"#
    )
    let provider = try JanuaryDevelopmentTokenProvider(
        apiKey: "fixture-development-key",
        ttlSeconds: 300,
        endpoint: URL(string: "https://example.invalid")!,
        warningHandler: { _ in },
        performRequest: { request in try await probe.perform(request) }
    )

    do {
        _ = try await provider.fetchClientToken(for: "demo-user")
        Issue.record("Expected token minting to fail.")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.httpStatus == 401)
        #expect(!error.message.contains("sensitive response"))
    }
}

@Test
func developmentTokenProviderMarksServerFailuresRetryable() async throws {
    let probe = DevelopmentTokenRequestProbe(responseStatus: 503)
    let provider = try JanuaryDevelopmentTokenProvider(
        apiKey: "fixture-development-key",
        ttlSeconds: 300,
        endpoint: URL(string: "https://example.invalid")!,
        warningHandler: { _ in },
        performRequest: { request in try await probe.perform(request) }
    )

    do {
        _ = try await provider.fetchClientToken(for: "demo-user")
        Issue.record("Expected token minting to fail.")
    } catch let error as JanuaryTokenProviderError {
        #expect(error.retryable)
    }
}
