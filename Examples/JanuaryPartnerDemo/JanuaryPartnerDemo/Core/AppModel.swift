import Foundation
@_spi(JanuaryDevelopment) import JanuaryPartnerSDK
import Observation

enum AuthenticationConfiguration: Sendable {
    case developmentAPIKey(String)
    case clientToken(partnerTokenURL: URL, apiBaseURL: URL, endUserID: String)
    case invalid(String)
}

@MainActor
@Observable
final class AppModel {
    enum State: Equatable {
        case loading
        case connecting
        case ready
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var client: JanuaryPartnerClient?
    let userSession = UserSession()

    private let authentication: AuthenticationConfiguration
    private var hasBootstrapped = false

    init(authentication: AuthenticationConfiguration) {
        self.authentication = authentication
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        connect(authentication: authentication)
    }

    private func connect(authentication: AuthenticationConfiguration) {
        state = .connecting

        do {
            switch authentication {
            case .developmentAPIKey(let apiKey):
                let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedAPIKey.isEmpty else {
                    state = .failed(
                        "Set JANUARY_DEMO_API_KEY or PARTNER_TOKEN_URL in the Xcode scheme."
                    )
                    return
                }
                client = try JanuaryPartnerClient(developmentAPIKey: normalizedAPIKey)
            case .clientToken(let partnerTokenURL, let apiBaseURL, let endUserID):
                client = try JanuaryPartnerClient(
                    clientTokenProvider: {
                        try await Self.fetchClientToken(
                            from: partnerTokenURL,
                            endUserID: endUserID
                        )
                    },
                    apiBaseURL: apiBaseURL
                )
            case .invalid(let message):
                state = .failed(message)
                return
            }
            state = .ready
        } catch {
            client = nil
            state = .failed(error.localizedDescription)
        }
    }

    private static func fetchClientToken(
        from url: URL,
        endUserID: String
    ) async throws -> JanuaryClientToken {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw TokenError.invalidURL
        }
        components.queryItems = (components.queryItems ?? []) + [
            URLQueryItem(name: "user", value: endUserID),
        ]
        guard let requestURL = components.url else { throw TokenError.invalidURL }
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw TokenError.requestFailed
        }
        let token = try JSONDecoder().decode(JanuaryClientToken.self, from: data)
        print("January demo fetched a short-lived token valid for \(token.expiresIn) seconds.")
        return token
    }
}

private enum TokenError: Error {
    case requestFailed
    case invalidURL
}
