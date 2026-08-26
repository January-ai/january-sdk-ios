import SwiftUI

private enum AppConfiguration {
    // Add your January Partner API key before building the demo app.
    static let apiKey = "<development-key>"

    static let authentication: AuthenticationConfiguration = .developmentAPIKey(apiKey)
}

@main
struct JanuaryPartnerDemoApp: App {
    @State private var model: AppModel

    init() {
        UserDefaults.standard.register(defaults: [
            "demo.authenticationMode": "Development API key",
            "demo.endUserID": "",
        ])
        _model = State(initialValue: AppModel(authentication: AppConfiguration.authentication))
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: model)
        }
    }
}
