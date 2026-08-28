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
                let appSessionToken = environment["PARTNER_APP_SESSION_TOKEN"],
                !appSessionToken.isEmpty
            else {
                return .invalid(
                    "Set PARTNER_APP_SESSION_TOKEN when PARTNER_TOKEN_URL is configured."
                )
            }
            return .clientToken(
                partnerTokenURL: url,
                appSessionToken: appSessionToken,
                endUserID: endUserID
            )
        }

#if DEBUG
        if let apiKey = environment["JANUARY_DEMO_API_KEY"], !apiKey.isEmpty {
            let ttlSeconds = environment["JANUARY_DEMO_TOKEN_TTL_SECONDS"]
                .flatMap(Int.init) ?? 300
            return .developmentClientToken(
                apiKey,
                endUserID: endUserID,
                ttlSeconds: ttlSeconds
            )
        }
#endif

        return .invalid(
            "Set PARTNER_TOKEN_URL and PARTNER_APP_SESSION_TOKEN. " +
            "For a local Debug run, set JANUARY_DEMO_API_KEY instead."
        )
    }

    static var authenticationLabel: String {
        if environment["PARTNER_TOKEN_URL"] != nil {
            return "Partner backend token provider"
        }
        if environment["JANUARY_DEMO_API_KEY"] != nil {
            return "Development client-token provider"
        }
        return "Not configured"
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
