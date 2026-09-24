# First request

Build a small SwiftUI app that gets a client token from your token endpoint, searches for a food, fetches its full details, computes a portion, and shows the result.

## 1. Create the Xcode project

1. In Xcode, choose **File → New → Project → iOS → App**.
2. Name it `JanuaryQuickstart`, with **SwiftUI** for Interface, **Swift** for Language, and iOS 15 or later as the deployment target.
3. [Add the SDK](installation.md) to the `JanuaryQuickstart` target.

## 2. Set the scheme's environment variables

Choose **Product → Scheme → Edit Scheme → Run → Arguments** and add these environment variables:

```text
JANUARY_PARTNER_TOKEN_URL=https://your-backend.example.com/january/client-token
JANUARY_PARTNER_SESSION_TOKEN=your-app-session-token
JANUARY_END_USER_ID=acme-user-8271
```

Use your token endpoint's URL, a valid session token for it, and the end-user ID your backend mints tokens for.

{% hint style="info" %}
No backend yet? Start the [token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay), set `JANUARY_PARTNER_TOKEN_URL=http://localhost:8787/api/january/client-token`, and leave out `JANUARY_PARTNER_SESSION_TOKEN`.
{% endhint %}

## 3. Add the source

Add a file named `BackendTokenProvider.swift` containing the `BackendTokenProvider` from [Authentication](authentication.md#write-the-token-provider). Leave `JanuaryQuickstartApp.swift` as Xcode created it, and replace `ContentView.swift` with:

```swift
import Foundation
import January
import SwiftUI

struct QuickstartError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

@MainActor
final class QuickstartModel: ObservableObject {
    enum State {
        case loading
        case loaded(name: String, servings: Int, calories: Double)
        case failed(String)
    }

    @Published private(set) var state: State = .loading
    private var client: JanuaryClient?

    func load() async {
        state = .loading
        do {
            let client = try self.client ?? makeClient()
            self.client = client

            let results = try await client.foods.search(
                .init(query: "greek yogurt", category: .branded, limit: 10)
            )
            guard let match = results.items.first else {
                state = .failed("January returned no matching foods.")
                return
            }

            let food = try await client.foods.get(id: match.id)
            let portion = try food.portion() // One primary serving
            state = .loaded(
                name: food.name ?? "Unnamed food",
                servings: food.servings.count,
                calories: portion.nutrition.calories?.value ?? 0
            )
        } catch is CancellationError {
            return
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func makeClient() throws -> JanuaryClient {
        let environment = ProcessInfo.processInfo.environment
        guard let rawURL = environment["JANUARY_PARTNER_TOKEN_URL"],
              let tokenEndpoint = URL(string: rawURL) else {
            throw QuickstartError("Set JANUARY_PARTNER_TOKEN_URL in the Xcode scheme.")
        }
        guard let endUserID = environment["JANUARY_END_USER_ID"] else {
            throw QuickstartError("Set JANUARY_END_USER_ID in the Xcode scheme.")
        }
        let sessionToken = environment["JANUARY_PARTNER_SESSION_TOKEN"] ?? ""

        return try JanuaryClient(
            endUserID: endUserID,
            timezone: TimeZone.current,
            clientTokenProvider: BackendTokenProvider(
                tokenEndpoint: tokenEndpoint,
                appSessionToken: { sessionToken }
            )
        )
    }
}

struct ContentView: View {
    @StateObject private var model = QuickstartModel()

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

The model creates the client once and reuses it on **Try Again**, as a real app should ([Client lifecycle](../concepts/client-lifecycle.md)).

## 4. Run it

Choose an iOS Simulator and press **Run**. The screen shows **Connecting…**, then:

```text
January SDK
<food name>
<number> serving options
<number> calories
```

On failure, it shows the error message and a **Try Again** button. An error from your token endpoint shows the provider's message, such as "Your token endpoint returned HTTP 401." If the endpoint can't be reached, the SDK retries for about 45 seconds before showing the error. See [Errors](../reference/error-handling.md) and [Troubleshooting](../reference/troubleshooting.md).

Next: [Example app](example-app.md), or skip to [Core concepts](https://docs.january.ai/ios-sdk/concepts).
