import Foundation
@_spi(JanuaryDevelopment) import JanuarySDK

@main
enum JanuaryPartnerTokenSmoke {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let rawPartnerURL = environment["PARTNER_TOKEN_URL"],
            let partnerURL = URL(string: rawPartnerURL),
            let rawAPIBaseURL = environment["JANUARY_INTERNAL_API_BASE_URL"],
            let apiBaseURL = URL(string: rawAPIBaseURL)
        else {
            throw SmokeError.missingConfiguration
        }
        let endUserID = environment["JANUARY_END_USER_ID"] ?? "local-ios-user"
        let reportedExpiresIn = environment["JANUARY_TEST_REPORTED_EXPIRES_IN"]
            .flatMap(TimeInterval.init)
        let secondRequestDelay = environment["JANUARY_TEST_SECOND_REQUEST_DELAY_SECONDS"]
            .flatMap(TimeInterval.init)
        let simulatedProviderFailures = environment["JANUARY_TEST_PROVIDER_FAILURES"]
            .flatMap(Int.init) ?? 0
        let providerCalls = ProviderCallCounter()

        let client = try JanuaryClient(
            clientTokenProvider: {
                let call = await providerCalls.incrementAndValue()
                if call <= simulatedProviderFailures {
                    throw SmokeError.simulatedProviderFailure
                }
                guard var components = URLComponents(url: partnerURL, resolvingAgainstBaseURL: false) else {
                    throw SmokeError.invalidURL
                }
                components.queryItems = (components.queryItems ?? []) + [.init(name: "user", value: endUserID)]
                guard let requestURL = components.url else { throw SmokeError.invalidURL }
                var request = URLRequest(url: requestURL)
                request.httpMethod = "GET"
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                    throw SmokeError.tokenRequestFailed
                }
                let token = try JSONDecoder().decode(JanuaryClientToken.self, from: data)
                return JanuaryClientToken(
                    token: token.token,
                    expiresIn: reportedExpiresIn ?? token.expiresIn
                )
            },
            apiBaseURL: apiBaseURL
        )

        let results = try await client.foods.search(
            SearchFoodsRequest(
                query: "banana",
                endUserID: PartnerUserID(rawValue: endUserID)
            )
        )
        guard results.items.first?.name.lowercased() == "banana" else {
            throw SmokeError.unexpectedFoodResponse
        }

        if let secondRequestDelay {
            try await Task.sleep(nanoseconds: UInt64(secondRequestDelay * 1_000_000_000))
            _ = try await client.foods.search(
                SearchFoodsRequest(
                    query: "apple",
                    endUserID: PartnerUserID(rawValue: endUserID)
                )
            )
            guard await providerCalls.value == simulatedProviderFailures + 2 else {
                throw SmokeError.providerDidNotRefresh
            }
        } else if await providerCalls.value != simulatedProviderFailures + 1 {
            throw SmokeError.providerDidNotRetryAsExpected
        }

        print(
            "Client-token smoke passed for \(endUserID) with " +
            "\(await providerCalls.value) provider call(s); token values were not logged."
        )
    }

}

private enum SmokeError: Error {
    case missingConfiguration
    case invalidURL
    case tokenRequestFailed
    case simulatedProviderFailure
    case unexpectedFoodResponse
    case providerDidNotRefresh
    case providerDidNotRetryAsExpected
}

private actor ProviderCallCounter {
    private(set) var value = 0

    func incrementAndValue() -> Int {
        value += 1
        return value
    }
}
