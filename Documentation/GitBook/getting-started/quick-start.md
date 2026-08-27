# First iOS request

This walkthrough creates a complete minimal SwiftUI app. It obtains a client token from an explicit partner-backend URL, searches for a food, hydrates the selected result, calculates a portion, and renders the result.

{% hint style="warning" %}
The SDK repository is private during Controlled Preview. Xcode must use a GitHub account with access. Your partner token endpoint must already implement [Backend token endpoint](backend-token-endpoint.md).
{% endhint %}

## 1. Create the Xcode project

1. In Xcode, choose **File → New → Project**.
2. Select **iOS → App**.
3. Name it `JanuaryQuickstart`, choose **SwiftUI** for Interface and **Swift** for Language.
4. Set the deployment target to iOS 15 or later.
5. Choose **File → Add Package Dependencies**.
6. Enter `https://github.com/January-ai/january-sdk-ios.git`.
7. Select the latest release shown by Xcode.
8. Add the `JanuarySDK` product to the `JanuaryQuickstart` target.

## 2. Add required scheme configuration

Edit the `JanuaryQuickstart` scheme and add these Run environment variables:

```text
PARTNER_TOKEN_URL=https://your-backend.example.com/january-token
PARTNER_APP_SESSION_TOKEN=your-app-session-token
```

`PARTNER_TOKEN_URL` has no default. Replace both values with your configured backend endpoint and a valid session credential for that backend. January's private server-side token-issuance credentials never belong in the app.

## 3. Add the app source

Replace `JanuaryQuickstartApp.swift` with:

```swift
import SwiftUI

@main
struct JanuaryQuickstartApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Replace `ContentView.swift` with:

```swift
import Foundation
import JanuarySDK
import SwiftUI

enum QuickstartError: LocalizedError {
    case missingEnvironment(String)
    case invalidURL(String)
    case invalidResponse
    case tokenRequestFailed(Int)
    case noFoods

    var errorDescription: String? {
        switch self {
        case .missingEnvironment(let name):
            return "Set \(name) in the Xcode scheme."
        case .invalidURL(let value):
            return "Invalid partner token URL: \(value)"
        case .invalidResponse:
            return "The partner token endpoint returned an invalid response."
        case .tokenRequestFailed(let status):
            return "The partner token endpoint returned HTTP \(status)."
        case .noFoods:
            return "January returned no matching foods."
        }
    }
}

struct PartnerBackendTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String

    func fetchClientToken() async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET" // Match your backend contract.
        request.setValue(
            "Bearer \(appSessionToken)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw QuickstartError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw QuickstartError.tokenRequestFailed(http.statusCode)
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

@MainActor
final class QuickstartViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(name: String, servings: Int, calories: Double)
        case failed(String)
    }

    @Published private(set) var state: State = .loading

    func load() async {
        state = .loading
        do {
            let environment = ProcessInfo.processInfo.environment
            guard let rawURL = environment["PARTNER_TOKEN_URL"] else {
                throw QuickstartError.missingEnvironment("PARTNER_TOKEN_URL")
            }
            guard let endpoint = URL(string: rawURL) else {
                throw QuickstartError.invalidURL(rawURL)
            }
            guard let appSessionToken = environment["PARTNER_APP_SESSION_TOKEN"] else {
                throw QuickstartError.missingEnvironment("PARTNER_APP_SESSION_TOKEN")
            }

            let provider = PartnerBackendTokenProvider(
                endpoint: endpoint,
                appSessionToken: appSessionToken
            )
            let january = try JanuaryClient(
                clientTokenProvider: provider
            )

            let results = try await january.foods.search(
                .init(query: "greek yogurt", category: .branded, limit: 10)
            )
            guard let match = results.items.first else {
                throw QuickstartError.noFoods
            }

            let food = try await january.foods.getFood(
                .init(foodID: match.id)
            )
            let portion = try food.portion(quantity: 1)

            state = .loaded(
                name: food.name,
                servings: food.servings.count,
                calories: portion.nutrition.calories?.value ?? 0
            )
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

struct ContentView: View {
    @StateObject private var model = QuickstartViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("January SDK")
                .font(.title.bold())

            switch model.state {
            case .loading:
                ProgressView("Connecting…")
            case .loaded(let name, let servings, let calories):
                Text(name).font(.headline)
                Text("\(servings) serving options")
                Text("\(calories, specifier: "%.1f") calories")
            case .failed(let message):
                Text(message).foregroundStyle(.red)
                Button("Try Again") {
                    Task { await model.load() }
                }
            }
        }
        .padding()
        .task {
            await model.load()
        }
    }
}
```

## 4. Build and run

Select an iOS Simulator and press **Run**, or build from the project directory:

```sh
xcodebuild \
  -project JanuaryQuickstart.xcodeproj \
  -scheme JanuaryQuickstart \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Scheme environment variables are injected when Xcode runs the app. The command above proves the app compiles; use **Run** to exercise the configured token endpoint.

## Expected UI

The screen first shows **Connecting…**. A successful request then shows:

```text
January SDK
<hydrated food name>
<one or more> serving options
<numeric value> calories
```

On failure, the screen shows the localized error and a **Try Again** button. See [Errors](../reference/error-handling.md) and [Troubleshooting](../reference/troubleshooting.md).
