import SwiftUI

private enum DemoConfiguration {
    // Add your January Partner API key before building the demo app.
    static let apiKey = ""

    static let authentication: DemoAuthenticationConfiguration = .developmentAPIKey(apiKey)
}

@main
struct JanuaryPartnerDemoApp: App {
    @State private var model: DemoAppModel

    init() {
        UserDefaults.standard.register(defaults: [
            "demo.authenticationMode": "Development API key",
            "demo.endUserID": "",
        ])
        _model = State(initialValue: DemoAppModel(authentication: DemoConfiguration.authentication))
    }

    var body: some Scene {
        WindowGroup {
            DemoRootView(model: model)
        }
    }
}
