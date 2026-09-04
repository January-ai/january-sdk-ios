import Combine
import Foundation
@_spi(JanuaryDevelopment) import January

enum AuthenticationConfiguration: Sendable {
    case fixture(URL)
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
            case .fixture(let apiBaseURL):
#if DEBUG
                client = try JanuaryClient(
                    endUserID: "ui-test-user",
                    timezone: TimeZone(identifier: "America/New_York"),
                    clientTokenProvider: { _ in JanuaryClientToken(token: "fixture-client-token", expiresIn: 3_600) },
                    apiBaseURL: apiBaseURL
                )
                isUsingDevelopmentAuthentication = true
#else
                state = .setupRequired("UI fixtures are available only in Debug builds.")
                return
#endif
            case .developmentClientToken(let apiKey, let endUserID):
#if DEBUG
                let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedAPIKey.isEmpty else {
                    state = .setupRequired(nil)
                    return
                }
                client = try JanuaryClient(
                    developmentAPIKey: normalizedAPIKey,
                    endUserID: endUserID,
                    timezone: TimeZone(identifier: userSession.timezone) ?? .current
                )
                isUsingDevelopmentAuthentication = true
#else
                state = .setupRequired(
                    "The debug-only server API-key shortcut is disabled in Release builds. Set the partner token URL and session token in the Xcode Run scheme."
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
