import Foundation
import SwiftUI

private enum AppConfiguration {
    private static let environment = ProcessInfo.processInfo.environment

    static var endUserID: String {
        environment["JANUARY_END_USER_ID"] ?? "local-ios-user"
    }

    static var authentication: AuthenticationConfiguration {
        if let rawURL = environment["PARTNER_TOKEN_URL"], let url = URL(string: rawURL) {
            guard
                let rawAPIBaseURL = environment["JANUARY_INTERNAL_API_BASE_URL"],
                let apiBaseURL = URL(string: rawAPIBaseURL)
            else {
                return .invalid(
                    "Set JANUARY_INTERNAL_API_BASE_URL when PARTNER_TOKEN_URL is configured."
                )
            }
            let usesDevelopmentStandIn = url.host == "127.0.0.1" || url.host == "localhost"
            let appSessionToken = environment["PARTNER_APP_SESSION_TOKEN"]
            if !usesDevelopmentStandIn && (appSessionToken?.isEmpty ?? true) {
                return .invalid(
                    "Set PARTNER_APP_SESSION_TOKEN for a non-local partner token endpoint."
                )
            }
            return .clientToken(
                partnerTokenURL: url,
                apiBaseURL: apiBaseURL,
                developmentEndUserID: usesDevelopmentStandIn ? endUserID : nil,
                appSessionToken: appSessionToken
            )
        }
        return .developmentAPIKey(
            environment["JANUARY_DEMO_API_KEY"] ?? "",
            endUserID: endUserID
        )
    }

    static var authenticationLabel: String {
        environment["PARTNER_TOKEN_URL"] == nil
            ? "Development API key"
            : "Short-lived token provider"
    }
}

@main
struct JanuaryPartnerDemoApp: App {
    @State private var model: AppModel

    init() {
        UserDefaults.standard.register(defaults: [
            "demo.authenticationMode": AppConfiguration.authenticationLabel,
            "demo.endUserID": AppConfiguration.endUserID,
        ])
        UserDefaults.standard.set(AppConfiguration.authenticationLabel, forKey: "demo.authenticationMode")
        _model = State(initialValue: AppModel(authentication: AppConfiguration.authentication))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
