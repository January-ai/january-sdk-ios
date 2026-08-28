import Foundation
import SwiftUI

#warning("January demo authentication: development API keys are for local Debug testing only. Never commit or ship one. Use JanuaryTokenProvider for production authentication.")

private enum AppConfiguration {
    // MARK: Configure the demo here

    // Recommended: connect the demo to your authenticated token endpoint.
    static let partnerTokenURL: URL? = nil
    static let partnerAppSessionToken = ""

    // Local Debug testing only. Never commit or ship a development API key.
    static let developmentAPIKey = ""

    static let endUserID = "your-ios-user-id"

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
        UserDefaults.standard.register(defaults: [
            "demo.authenticationMode": AppConfiguration.authenticationLabel,
            "demo.endUserID": AppConfiguration.endUserID,
        ])
        UserDefaults.standard.set(AppConfiguration.authenticationLabel, forKey: "demo.authenticationMode")
        _model = StateObject(wrappedValue: AppModel(authentication: AppConfiguration.authentication))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
