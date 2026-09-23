import Combine
import Foundation
@_spi(JanuaryDevelopment) import January

enum AuthenticationConfiguration: Sendable {
    case fixture(URL)
    case developmentClientToken(String, endUserID: String)
    case clientToken(
        partnerTokenURL: URL,
        appSessionToken: String,
        endUserID: String,
        apiBaseURL: URL? = nil
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
    private var sessionChanges: AnyCancellable?

    init(authentication: AuthenticationConfiguration) {
        self.authentication = authentication
        // The SDK applies the client's end user and timezone to every request, so a change in
        // Settings takes effect by creating a client for the new user and timezone. The values
        // arrive before the session stores them, in the same update, so views reload with the
        // new client.
        sessionChanges = userSession.$endUserID
            .combineLatest(userSession.$timezone)
            .dropFirst()
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] endUserID, timezone in
                guard let self, self.hasBootstrapped, self.state == .ready else { return }
                self.connect(authentication: self.authentication, sessionEndUserID: endUserID, timezone: timezone)
            }
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        connect(
            authentication: authentication,
            sessionEndUserID: userSession.endUserID,
            timezone: userSession.timezone
        )
    }

    /// Creates the client for the Settings end user (or the configured one while Settings has
    /// none) and the Settings timezone.
    private func connect(
        authentication: AuthenticationConfiguration,
        sessionEndUserID: String,
        timezone timezoneIdentifier: String
    ) {
        let sessionEndUserID = AppFormatting.endUserID(sessionEndUserID)?.rawValue
        let timezone = TimeZone(identifier: timezoneIdentifier) ?? .current
        if client == nil { state = .connecting }
        isUsingDevelopmentAuthentication = false

        do {
            switch authentication {
            case .fixture(let apiBaseURL):
#if DEBUG
                client = try JanuaryClient(
                    endUserID: sessionEndUserID ?? "ui-test-user",
                    timezone: timezone,
                    // The fixture server records the bearer token, so flows can check which user a request was for.
                    clientTokenProvider: { endUserID in
                        JanuaryClientToken(token: "fixture-client-token.\(endUserID)", expiresIn: 3_600)
                    },
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
                    endUserID: sessionEndUserID ?? endUserID,
                    timezone: timezone
                )
                isUsingDevelopmentAuthentication = true
#else
                state = .setupRequired(
                    "The debug-only server API-key shortcut is disabled in Release builds. Set JANUARY_PARTNER_TOKEN_URL and, when the endpoint requires authorization, JANUARY_PARTNER_SESSION_TOKEN in the Xcode Run scheme."
                )
                return
#endif
            case .clientToken(
                let partnerTokenURL,
                let appSessionToken,
                let endUserID,
                let apiBaseURL
            ):
                let provider = PartnerBackendTokenProvider(
                    endpoint: partnerTokenURL,
                    appSessionToken: appSessionToken
                )
#if DEBUG
                if let apiBaseURL {
                    client = try JanuaryClient(
                        endUserID: sessionEndUserID ?? endUserID,
                        timezone: timezone,
                        clientTokenProvider: provider,
                        apiBaseURL: apiBaseURL
                    )
                    break
                }
#endif
                client = try JanuaryClient(
                    endUserID: sessionEndUserID ?? endUserID,
                    timezone: timezone,
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
