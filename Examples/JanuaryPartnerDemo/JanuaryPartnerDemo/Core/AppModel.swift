import Foundation
import JanuarySDK
import Observation

enum AuthenticationConfiguration: Sendable {
    case developmentClientToken(String, endUserID: String, ttlSeconds: Int)
    case clientToken(
        partnerTokenURL: URL,
        appSessionToken: String,
        endUserID: String
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
            case .developmentClientToken(let apiKey, let endUserID, let ttlSeconds):
#if DEBUG
                let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedAPIKey.isEmpty else {
                    state = .failed(
                        "Set JANUARY_DEMO_API_KEY or PARTNER_TOKEN_URL in the Xcode scheme."
                    )
                    return
                }
                let provider = try JanuaryDevelopmentTokenProvider(
                    apiKey: normalizedAPIKey,
                    endUserID: PartnerUserID(rawValue: endUserID),
                    ttlSeconds: ttlSeconds
                )
                client = try JanuaryClient(
                    endUserID: PartnerUserID(rawValue: endUserID),
                    timezone: userSession.timezone,
                    clientTokenProvider: provider
                )
#else
                state = .failed(
                    "Development API keys are disabled in Release builds. Configure PARTNER_TOKEN_URL instead."
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
                    appSessionToken: appSessionToken,
                    endUserID: PartnerUserID(rawValue: endUserID)
                )
                client = try JanuaryClient(
                    endUserID: PartnerUserID(rawValue: endUserID),
                    timezone: userSession.timezone,
                    clientTokenProvider: provider
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
