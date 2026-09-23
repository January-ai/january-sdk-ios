import Foundation
import SwiftUI
import UIKit

#warning("January demo authentication: the optional server API-key shortcut is for local Debug testing only. Never commit or ship a key; use JanuaryTokenProvider for production.")

private enum AppConfiguration {
    // MARK: Configure the demo here

    private static let environment = ProcessInfo.processInfo.environment
    /// The token URL and end-user ID can also be passed as launch arguments
    /// (`-JANUARY_PARTNER_TOKEN_URL http://…`), for example by `xcrun simctl launch`
    /// or a UI test runner. Credentials are read from the environment only.
    private static let launchArguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)

    private static func setting(_ name: String) -> String? {
        environment[name] ?? launchArguments[name] as? String
    }

    // Connect the demo to your authenticated token endpoint.
    static let partnerTokenURL = setting("JANUARY_PARTNER_TOKEN_URL").flatMap(URL.init(string:))
    static let partnerAppSessionToken = environment["JANUARY_PARTNER_SESSION_TOKEN"] ?? ""

    // Optional local Debug shortcut. Never commit or ship a server API key.
    static let debugServerAPIKey = environment["JANUARY_API_KEY"] ?? ""

    /// Debug builds only: send API requests to another origin, such as the local fixture server,
    /// to rehearse the client-token flow without calling the January API.
    static let debugAPIBaseURL: URL? = {
#if DEBUG
        guard let value = setting("JANUARY_API_BASE_URL")?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return URL(string: value)
#else
        return nil
#endif
    }()

    static let endUserID: String = {
        let candidates = [
            setting("JANUARY_END_USER_ID"),
        ]
        return candidates.compactMap { candidate in
            let normalized = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return normalized.isEmpty ? nil : normalized
        }.first ?? "january-sdk-demo-user"
    }()

    static var authentication: AuthenticationConfiguration {
        let sessionToken = partnerAppSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if let partnerTokenURL {
            return .clientToken(
                partnerTokenURL: partnerTokenURL,
                appSessionToken: sessionToken,
                endUserID: endUserID,
                apiBaseURL: debugAPIBaseURL
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
                "The debug-only server API-key shortcut is disabled in Release builds. Set the partner token URL and session token in the Xcode Run scheme."
            )
        }
#endif

        return .setupRequired()
    }

    static var apiLabel: String {
        guard partnerTokenURL != nil, let debugAPIBaseURL else { return "Production" }
        return debugAPIBaseURL.host.map { host in debugAPIBaseURL.port.map { "\(host):\($0)" } ?? host }
            ?? debugAPIBaseURL.absoluteString
    }

    static var authenticationLabel: String {
        if partnerTokenURL != nil {
            return "Client token provider"
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
        UserDefaults.standard.set(
            isUITesting ? "Local fixture server" : AppConfiguration.apiLabel,
            forKey: "demo.apiOrigin"
        )
        _model = StateObject(wrappedValue: AppModel(authentication: authentication))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
