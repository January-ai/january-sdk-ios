import Foundation
import SwiftUI
import UIKit

#warning("January demo authentication: development API keys are for local Debug testing only. Never commit or ship one. Use JanuaryTokenProvider for production authentication.")

private enum AppConfiguration {
    // MARK: Configure the demo here

    private static let environment = ProcessInfo.processInfo.environment
    private static let bundle = Bundle.main
    private static let localDefaults = UserDefaults.standard

    // Recommended: connect the demo to your authenticated token endpoint.
    static let partnerTokenURL = environment["JANUARY_PARTNER_TOKEN_URL"].flatMap(URL.init(string:))
    static let partnerAppSessionToken = environment["JANUARY_PARTNER_SESSION_TOKEN"] ?? ""

    // Local Debug testing only. Never commit or ship a development API key.
    static let developmentAPIKey = environment["JANUARY_API_KEY"]
        ?? bundle.object(forInfoDictionaryKey: "JanuaryDevelopmentAPIKey") as? String
        ?? localDefaults.string(forKey: "JanuaryDevelopmentAPIKey")
        ?? ""

    static let endUserID: String = {
        let candidates = [
            environment["JANUARY_END_USER_ID"],
            bundle.object(forInfoDictionaryKey: "JanuaryEndUserID") as? String,
            localDefaults.string(forKey: "JanuaryEndUserID"),
        ]
        return candidates.compactMap { candidate in
            let normalized = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return normalized.isEmpty ? nil : normalized
        }.first ?? "your-ios-user-id"
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
        let apiKey = developmentAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !apiKey.isEmpty {
            return .developmentClientToken(
                apiKey,
                endUserID: endUserID
            )
        }
#else
        if !developmentAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .setupRequired(
                "Development API-key authentication is disabled in Release builds. Use the token provider configuration above."
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
        if !developmentAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Development client-token provider"
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
