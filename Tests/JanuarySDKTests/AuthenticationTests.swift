import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@_spi(JanuaryDevelopment) @testable import JanuarySDK

private actor AuthenticationTransport: ClientTransport {
    struct Captured: Sendable {
        let authorization: String?
        let endUserID: String?
    }

    private var statuses: [HTTPResponse.Status]
    private var challenges: [String?]
    private var errorCodes: [String]
    private var captured: [Captured] = []

    init(
        statuses: [HTTPResponse.Status] = [.ok],
        challenges: [String?] = [],
        errorCodes: [String] = ["token_expired"]
    ) {
        self.statuses = statuses
        self.challenges = challenges
        self.errorCodes = errorCodes
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        captured.append(.init(
            authorization: request.headerFields[.authorization],
            endUserID: HTTPField.Name("x-end-user-id").flatMap { request.headerFields[$0] }
        ))
        let index = captured.count - 1
        let status = statuses[min(index, statuses.count - 1)]
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        if index < challenges.count, let challenge = challenges[index] {
            response.headerFields[.wwwAuthenticate] = challenge
        }
        let code = errorCodes[min(index, errorCodes.count - 1)]
        let json = status == .ok
            ? #"{"total_count":0,"items":[]}"#
            : #"{"message":"authentication failed","code":"\#(code)","docs_url":"https://docs.january.ai"}"#
        return (response, HTTPBody(json))
    }

    func requests() -> [Captured] { captured }
}

private struct ProviderFailure: Error {}

private enum TokenProviderOutcome: Sendable {
    case token(String)
    case failure
}

private actor TokenProviderProbe {
    private var outcomes: [TokenProviderOutcome]
    private(set) var calls = 0
    private let expiresIn: TimeInterval
    private let delay: TimeInterval?

    init(values: [String], expiresIn: TimeInterval = 3_600, delay: TimeInterval? = nil) {
        self.outcomes = values.map(TokenProviderOutcome.token)
        self.expiresIn = expiresIn
        self.delay = delay
    }

    init(outcomes: [TokenProviderOutcome], expiresIn: TimeInterval = 3_600, delay: TimeInterval? = nil) {
        self.outcomes = outcomes
        self.expiresIn = expiresIn
        self.delay = delay
    }

    func token() async throws -> JanuaryClientToken {
        calls += 1
        if let delay { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
        switch outcomes[min(calls - 1, outcomes.count - 1)] {
        case .token(let value):
            return JanuaryClientToken(token: value, expiresIn: expiresIn)
        case .failure:
            throw ProviderFailure()
        }
    }

    func callCount() -> Int { calls }
}

private actor SleepProbe {
    private var recordedDelays: [TimeInterval] = []

    func sleep(for delay: TimeInterval) {
        recordedDelays.append(delay)
    }

    func delays() -> [TimeInterval] { recordedDelays }
}

@Test
func clientTokenDecodesPartnerServerResponseWithoutMapping() throws {
    let data = Data(#"{"token":"ct-direct","expiresIn":1800}"#.utf8)

    let token = try JSONDecoder().decode(JanuaryClientToken.self, from: data)

    #expect(token.token == "ct-direct")
    #expect(token.expiresIn == 1_800)
}

@Test
func clientTokenDecodesSnakeCaseRelayResponseWithoutMapping() throws {
    let data = Data(#"{"token":"ct-direct","expires_in":1800}"#.utf8)

    let token = try JSONDecoder().decode(JanuaryClientToken.self, from: data)

    #expect(token.token == "ct-direct")
    #expect(token.expiresIn == 1_800)
}

@Test
func clientTokenIsInjectedAndCachedInMemory() async throws {
    let now = Date(timeIntervalSince1970: 1_000)
    let provider = TokenProviderProbe(values: ["ct-one"])
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
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
func fixedClientTokenIsInjected() async throws {
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
        clientToken: "ct-fixed",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        userAgent: "test"
    )

    _ = try await client.foods.search(.init(query: "banana"))

    #expect(await transport.requests().map(\.authorization) == ["Bearer ct-fixed"])
}

@Test
func developmentAPIKeyClientBindsEveryRequestToItsConfiguredEndUser() async throws {
    let transport = AuthenticationTransport()
    let configuredUserID = PartnerUserID(rawValue: "configured-user")
    let client = try JanuaryClient(
        developmentAPIKey: "fixture-api-key",
        endUserID: configuredUserID,
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        userAgent: "test"
    )

    _ = try await client.foods.search(.init(
        query: "banana",
        endUserID: PartnerUserID(rawValue: "conflicting-request-user")
    ))

    #expect(await transport.requests().map(\.authorization) == ["Bearer fixture-api-key"])
    #expect(await transport.requests().map(\.endUserID) == ["configured-user"])
}

@Test
func concurrentRequestsShareOneTokenRefresh() async throws {
    let now = Date(timeIntervalSince1970: 2_000)
    let provider = TokenProviderProbe(
        values: ["ct-shared"],
        delay: 0.025
    )
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
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
func providerFetchRetriesWithBoundedExponentialBackoff() async throws {
    let provider = TokenProviderProbe(outcomes: [
        .failure,
        .failure,
        .token("ct-recovered"),
    ])
    let sleeper = SleepProbe()
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        tokenRetryPolicy: .init(
            maximumAttempts: 9,
            initialDelay: 1,
            multiplier: 2,
            maximumDelay: 8,
            jitterRatio: 0
        ),
        sleep: { await sleeper.sleep(for: $0) }
    )

    _ = try await client.foods.search(.init(query: "banana"))

    #expect(await provider.callCount() == 3)
    #expect(await sleeper.delays() == [1, 2])
    #expect(await transport.requests().map(\.authorization) == ["Bearer ct-recovered"])
}

@Test
func providerFetchStopsAfterMaximumAttempts() async throws {
    let provider = TokenProviderProbe(outcomes: [.failure])
    let sleeper = SleepProbe()
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        tokenRetryPolicy: .init(
            maximumAttempts: 9,
            initialDelay: 1,
            multiplier: 2,
            maximumDelay: 8,
            jitterRatio: 0
        ),
        sleep: { await sleeper.sleep(for: $0) }
    )

    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected token-provider failure")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.code == "client_token_provider_failed")
        #expect(error.message.contains("after 9 attempts"))
    }

    #expect(await provider.callCount() == 9)
    #expect(await sleeper.delays() == [1, 2, 4, 8, 8, 8, 8, 8])
    #expect(await transport.requests().isEmpty)
}

@Test
func tokenExpiredRefreshUsesBackoffBeforeSingleReplay() async throws {
    let provider = TokenProviderProbe(outcomes: [
        .token("ct-expired"),
        .failure,
        .failure,
        .token("ct-refreshed"),
    ])
    let sleeper = SleepProbe()
    let transport = AuthenticationTransport(statuses: [.unauthorized, .ok])
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        tokenRetryPolicy: .init(
            maximumAttempts: 9,
            initialDelay: 1,
            multiplier: 2,
            maximumDelay: 8,
            jitterRatio: 0
        ),
        sleep: { await sleeper.sleep(for: $0) }
    )

    _ = try await client.foods.search(.init(query: "banana"))

    #expect(await provider.callCount() == 4)
    #expect(await sleeper.delays() == [1, 2])
    #expect(await transport.requests().map(\.authorization) == [
        "Bearer ct-expired", "Bearer ct-refreshed",
    ])
}

@Test
func retryPolicyAddsBoundedJitter() {
    let policy = JanuaryTokenRetryPolicy(
        maximumAttempts: 9,
        initialDelay: 1,
        multiplier: 3,
        maximumDelay: 5,
        jitterRatio: 0.2
    )

    #expect(abs(policy.delay(afterFailedAttempt: 1, unitRandom: 0) - 0.8) < 0.000_001)
    #expect(abs(policy.delay(afterFailedAttempt: 1, unitRandom: 1) - 1.2) < 0.000_001)
    #expect(abs(policy.delay(afterFailedAttempt: 2, unitRandom: 0.5) - 3) < 0.000_001)
    #expect(abs(policy.delay(afterFailedAttempt: 3, unitRandom: 1) - 5) < 0.000_001)
    #expect(JanuaryTokenRetryPolicy.none.maximumAttempts == 1)
}

@Test
func tokenExpiredCodeRefreshesAndRetriesExactlyOnce() async throws {
    let now = Date(timeIntervalSince1970: 3_000)
    let provider = TokenProviderProbe(
        values: ["ct-expired", "ct-refreshed"],
        expiresIn: 3_600
    )
    let transport = AuthenticationTransport(
        statuses: [.unauthorized, .ok],
        challenges: [#"Bearer error="invalid_token""#, nil]
    )
    let client = try JanuaryClient(
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
func clientTokenDoesNotSendEndUserHeader() async throws {
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { JanuaryClientToken(token: "ct-user", expiresIn: 1_800) }
    )

    _ = try await client.foods.search(.init(
        query: "banana",
        endUserID: PartnerUserID(rawValue: "partner-user")
    ))

    #expect(await transport.requests().map(\.endUserID) == [nil])
}

@Test
func tokenInvalidDoesNotRefresh() async throws {
    let now = Date(timeIntervalSince1970: 3_500)
    let provider = TokenProviderProbe(values: ["ct-invalid", "ct-should-not-be-used"])
    let transport = AuthenticationTransport(
        statuses: [.unauthorized],
        challenges: [#"Bearer error="invalid_token""#],
        errorCodes: ["token_invalid"]
    )
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        now: { now }
    )

    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected token-invalid authentication failure")
    } catch let error as JanuaryError {
        #expect(error.code == "token_invalid")
    }

    #expect(await provider.callCount() == 1)
    #expect(await transport.requests().count == 1)
}

@Test
func providerFailuresMapToSafeAuthenticationErrors() async throws {
    let now = Date(timeIntervalSince1970: 4_000)
    let provider = TokenProviderProbe(outcomes: [.failure])
    let sleeper = SleepProbe()
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: AuthenticationTransport(),
        clientTokenProvider: { try await provider.token() },
        tokenRetryPolicy: .init(
            maximumAttempts: 9,
            initialDelay: 1,
            multiplier: 2,
            maximumDelay: 8,
            jitterRatio: 0
        ),
        now: { now },
        sleep: { await sleeper.sleep(for: $0) }
    )

    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected token-provider failure")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.code == "client_token_provider_failed")
        #expect(!error.message.contains("ProviderFailure"))
    }
    #expect(await provider.callCount() == 9)
    #expect(await sleeper.delays() == [1, 2, 4, 8, 8, 8, 8, 8])
}

@Test
func nearlyExpiredProviderTokensFailBeforeTransport() async throws {
    let now = Date(timeIntervalSince1970: 5_000)
    let provider = TokenProviderProbe(values: ["ct-too-short"], expiresIn: 30)
    let sleeper = SleepProbe()
    let transport = AuthenticationTransport()
    let client = try JanuaryClient(
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        clientTokenProvider: { try await provider.token() },
        now: { now },
        sleep: { await sleeper.sleep(for: $0) }
    )

    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected token-expiration validation failure")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.code == "invalid_client_token_expiration")
    }
    #expect(await provider.callCount() == 1)
    #expect(await sleeper.delays().isEmpty)
    #expect(await transport.requests().isEmpty)
}
