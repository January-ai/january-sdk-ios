import Combine
import Foundation
import January

enum AuthenticationConfiguration: Sendable {
    case developmentClientToken(String, endUserID: String)
    case clientToken(
        partnerTokenURL: URL,
        appSessionToken: String,
        endUserID: String
    )
    case setupRequired(String? = nil)
}

@MainActor
final class AppModel: ObservableObject {
    enum State: Equatable {
        case loading
        case connecting
        case ready
        case setupRequired(String?)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var client: JanuaryClient?
    @Published private(set) var isUsingDevelopmentAuthentication = false
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
        isUsingDevelopmentAuthentication = false

        do {
            switch authentication {
            case .developmentClientToken(let apiKey, let endUserID):
#if DEBUG
                let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedAPIKey.isEmpty else {
                    state = .setupRequired(nil)
                    return
                }
                let provider = try JanuaryDevelopmentTokenProvider(
                    apiKey: normalizedAPIKey
                )
                client = try JanuaryClient(
                    endUserID: endUserID,
                    timezone: TimeZone(identifier: userSession.timezone) ?? .current,
                    clientTokenProvider: provider
                )
                isUsingDevelopmentAuthentication = true
#else
                state = .setupRequired(
                    "Development API-key authentication is disabled in Release builds. Use the token provider configuration in JanuaryPartnerDemoApp.swift."
                )
                return
#endif
            case .clientToken(
                let partnerTokenURL,
                let appSessionToken,
                let endUserID
            ):
                let provider = PartnerBackendTokenProvider(
                    endpoint: partnerTokenURL,
                    appSessionToken: appSessionToken
                )
                client = try JanuaryClient(
                    endUserID: endUserID,
                    timezone: TimeZone(identifier: userSession.timezone) ?? .current,
                    clientTokenProvider: provider
                )
            case .setupRequired(let message):
                state = .setupRequired(message)
                return
            }
            state = .ready
        } catch {
            client = nil
            state = .failed(error.localizedDescription)
        }
    }

}
