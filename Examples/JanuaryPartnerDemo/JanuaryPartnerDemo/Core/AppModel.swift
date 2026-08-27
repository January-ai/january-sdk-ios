import Foundation
@_spi(JanuaryDevelopment) import JanuarySDK
import Observation

enum AuthenticationConfiguration: Sendable {
    case developmentAPIKey(String, endUserID: String)
    case clientToken(
        partnerTokenURL: URL,
        apiBaseURL: URL,
        developmentEndUserID: String?,
        appSessionToken: String?
    )
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
    private(set) var client: JanuaryClient?
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
            case .developmentAPIKey(let apiKey, let endUserID):
                let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedAPIKey.isEmpty else {
                    state = .failed(
                        "Set JANUARY_DEMO_API_KEY or PARTNER_TOKEN_URL in the Xcode scheme."
                    )
                    return
                }
                client = try JanuaryClient(
                    developmentAPIKey: normalizedAPIKey,
                    endUserID: PartnerUserID(rawValue: endUserID)
                )
            case .clientToken(
                let partnerTokenURL,
                let apiBaseURL,
                let developmentEndUserID,
                let appSessionToken
            ):
                let provider = PartnerBackendTokenProvider(
                    endpoint: partnerTokenURL,
                    developmentEndUserID: developmentEndUserID,
                    appSessionToken: appSessionToken
                )
                client = try JanuaryClient(
                    clientTokenProvider: provider,
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

}
