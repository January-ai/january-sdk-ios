import Foundation
import SwiftUI
import UIKit

#warning("January demo authentication: the optional server API-key shortcut is for local Debug testing only. Never commit or ship a key; use JanuaryTokenProvider for production.")

private enum AppConfiguration {
    // MARK: Configure the demo here

    private static let environment = ProcessInfo.processInfo.environment
    // Connect the demo to your authenticated token endpoint.
    static let partnerTokenURL = environment["JANUARY_PARTNER_TOKEN_URL"].flatMap(URL.init(string:))
    static let partnerAppSessionToken = environment["JANUARY_PARTNER_SESSION_TOKEN"] ?? ""

    // Optional local Debug shortcut. Never commit or ship a server API key.
    static let debugServerAPIKey = environment["JANUARY_API_KEY"] ?? ""

    static let endUserID: String = {
        let candidates = [
            environment["JANUARY_END_USER_ID"],
        ]
        return candidates.compactMap { candidate in
            let normalized = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return normalized.isEmpty ? nil : normalized
        }.first ?? "january-sdk-demo-user"
    }()

    static var authentication: AuthenticationConfiguration {
        let sessionToken = partnerAppSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if let partnerTokenURL, !sessionToken.isEmpty {
            return .clientToken(
                partnerTokenURL: partnerTokenURL,
                appSessionToken: sessionToken,
                endUserID: endUserID
            )
        }

#if DEBUG
        let apiKey = debugServerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            return .developmentClientToken(apiKey, endUserID: endUserID)
        }
#else
        if !debugServerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .setupRequired(
                "Server API-key authentication is disabled in Release builds. Use the token provider configuration above."
            )
        }
#endif

        return .setupRequired()
    }

    static var authenticationLabel: String {
        if partnerTokenURL != nil,
           !partnerAppSessionToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Partner backend token provider"
        }
        if !debugServerAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Debug-only server API key"
        }
        return "Not configured"
    }
}

@main
struct JanuaryPartnerDemoApp: App {
    @StateObject private var model: AppModel

    init() {
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        if isUITesting {
            UIView.setAnimationsEnabled(false)
        }
        let authentication: AuthenticationConfiguration = isUITesting
            ? .fixture(URL(string: "http://127.0.0.1:18768")!)
            : AppConfiguration.authentication
        UserDefaults.standard.register(defaults: [
            "demo.authenticationMode": isUITesting ? "UI test fixture" : AppConfiguration.authenticationLabel,
            "demo.endUserID": AppConfiguration.endUserID,
        ])
        UserDefaults.standard.set(isUITesting ? "UI test fixture" : AppConfiguration.authenticationLabel, forKey: "demo.authenticationMode")
        _model = StateObject(wrappedValue: AppModel(authentication: authentication))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
