import Foundation
import JanuaryPartnerSDK
import Observation

enum AuthenticationConfiguration: Sendable {
    case developmentAPIKey(String)
    case clientToken(partnerTokenURL: URL, januaryServerURL: URL, endUserID: String)
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
                        "Set AppConfiguration.apiKey in JanuaryPartnerDemoApp.swift."
                    )
                    return
                }
                client = try JanuaryPartnerClient(developmentAPIKey: normalizedAPIKey)
            case .clientToken(let partnerTokenURL, let januaryServerURL, let endUserID):
                client = try JanuaryPartnerClient(serverURL: januaryServerURL) {
                    try await Self.fetchClientToken(
                        from: partnerTokenURL,
                        endUserID: endUserID
                    )
                }
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
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Local simulation only. A production partner route uses the app's
        // existing authenticated session and derives the user on its server.
        request.setValue(endUserID, forHTTPHeaderField: "x-demo-user-id")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw TokenError.requestFailed
        }
        let wire = try JSONDecoder().decode(TokenResponse.self, from: data)
        guard let expiresAt = parseISO8601(wire.expiresAt) else {
            throw TokenError.invalidExpiration
        }
        return JanuaryClientToken(value: wire.accessToken, expiresAt: expiresAt)
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

nonisolated private struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let expiresAt: String
}

private enum TokenError: Error {
    case requestFailed
    case invalidExpiration
}
