import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import JanuaryPartnerSDK

private actor AuthenticationTransport: ClientTransport {
    struct Captured: Sendable {
        let authorization: String?
    }

    private var statuses: [HTTPResponse.Status]
    private var challenges: [String?]
    private var captured: [Captured] = []

    init(
        statuses: [HTTPResponse.Status] = [.ok],
        challenges: [String?] = []
    ) {
        self.statuses = statuses
        self.challenges = challenges
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        captured.append(.init(authorization: request.headerFields[.authorization]))
        let index = captured.count - 1
        let status = statuses[min(index, statuses.count - 1)]
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        if index < challenges.count, let challenge = challenges[index] {
            response.headerFields[.wwwAuthenticate] = challenge
        }
        let json = status == .ok
            ? #"{"total_count":0,"items":[]}"#
            : #"{"message":"expired","code":"token_expired"}"#
        return (response, HTTPBody(json))
    }

    func requests() -> [Captured] { captured }
}

private actor TokenProviderProbe {
    private var values: [String]
    private(set) var calls = 0
    private let expiration: Date
    private let delay: Duration?

    init(values: [String], expiration: Date, delay: Duration? = nil) {
        self.values = values
        self.expiration = expiration
        self.delay = delay
    }

    func token() async throws -> JanuaryClientToken {
        calls += 1
        if let delay { try await Task.sleep(for: delay) }
        return JanuaryClientToken(
            value: values[min(calls - 1, values.count - 1)],
            expiresAt: expiration
        )
    }

    func callCount() -> Int { calls }
}

@Test
func clientTokenIsInjectedAndCachedInMemory() async throws {
    let now = Date(timeIntervalSince1970: 1_000)
    let provider = TokenProviderProbe(values: ["ct-one"], expiration: now.addingTimeInterval(3_600))
    let transport = AuthenticationTransport()
    let client = try JanuaryPartnerClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        now: { now }
    )

    _ = try await client.foods.search(.init(query: "banana"))
    _ = try await client.foods.search(.init(query: "apple"))

    #expect(await provider.callCount() == 1)
    #expect(await transport.requests().map(\.authorization) == ["Bearer ct-one", "Bearer ct-one"])
}

@Test
func concurrentRequestsShareOneTokenRefresh() async throws {
    let now = Date(timeIntervalSince1970: 2_000)
    let provider = TokenProviderProbe(
        values: ["ct-shared"],
        expiration: now.addingTimeInterval(3_600),
        delay: .milliseconds(25)
    )
    let transport = AuthenticationTransport()
    let client = try JanuaryPartnerClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        now: { now }
    )

    try await withThrowingTaskGroup(of: Void.self) { group in
        for index in 0..<8 {
            group.addTask {
                _ = try await client.foods.search(.init(query: "food-\(index)"))
            }
        }
        try await group.waitForAll()
    }

    #expect(await provider.callCount() == 1)
    #expect(await transport.requests().count == 8)
}

@Test
func invalidTokenChallengeRefreshesAndRetriesExactlyOnce() async throws {
    let now = Date(timeIntervalSince1970: 3_000)
    let provider = TokenProviderProbe(
        values: ["ct-expired", "ct-refreshed"],
        expiration: now.addingTimeInterval(3_600)
    )
    let transport = AuthenticationTransport(
        statuses: [.unauthorized, .ok],
        challenges: [#"Bearer error="invalid_token""#, nil]
    )
    let client = try JanuaryPartnerClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        now: { now }
    )

    _ = try await client.foods.search(.init(query: "banana"))

    #expect(await provider.callCount() == 2)
    #expect(await transport.requests().map(\.authorization) == [
        "Bearer ct-expired", "Bearer ct-refreshed",
    ])
}

@Test
func providerFailuresMapToSafeAuthenticationErrors() async throws {
    struct ProviderFailure: Error {}
    let now = Date(timeIntervalSince1970: 4_000)
    let client = try JanuaryPartnerClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: AuthenticationTransport(),
        clientTokenProvider: { throw ProviderFailure() },
        now: { now }
    )

    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected token-provider failure")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.code == "client_token_provider_failed")
        #expect(!error.message.contains("ProviderFailure"))
    }
}

@Test
func nearlyExpiredProviderTokensFailBeforeTransport() async throws {
    let now = Date(timeIntervalSince1970: 5_000)
    let transport = AuthenticationTransport()
    let client = try JanuaryPartnerClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: {
            JanuaryClientToken(value: "ct-too-short", expiresAt: now.addingTimeInterval(30))
        },
        now: { now }
    )

    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected token-expiration validation failure")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.code == "invalid_client_token_expiration")
    }
    #expect(await transport.requests().isEmpty)
}
