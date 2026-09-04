# January SDK for iOS

[![CI](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml/badge.svg)](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml)
[![CocoaPods](https://img.shields.io/cocoapods/v/January.svg)](https://cocoapods.org/pods/January)

The official Swift SDK for January food discovery, restaurants, meal scanning,
food logs, and glucose prediction. It supports iOS 15+, Xcode 15+, and Swift
5.9+, with no third-party runtime dependencies. The included demo currently
requires Xcode 26 and an iOS 26 simulator.

## Quick start: run the demo with client tokens

You can try the iOS SDK before your own backend is ready. A small local Node
server keeps the January API key off the app and issues the same short-lived
client tokens your production backend will issue.

### 1. Create the credentials

Complete both steps—they are on separate dashboard pages:

1. [Sign up](https://dashboard.january.ai/sign-up) or
   [sign in](https://dashboard.january.ai/sign-in), then open
   **API keys → Create key** and copy the full `sk-…` value.
2. Open [Client tokens](https://dashboard.january.ai/dashboard/client-tokens)
   and select **Enable client tokens**.

For production or any shared build, never put the `sk-…` key in an iOS app.
The private, debug-only shortcut at the end is the sole local exception.

### 2. Start the local token server

Install Node.js 22 or newer. In a first terminal:

```bash
git clone https://github.com/January-ai/january-server-sdk-node.git
cd january-server-sdk-node
npm ci
cp .env.example .env
# Edit .env and set JANUARY_API_KEY to the key you just created.
npm run demo:token-server
```

Leave it running. The server binds only to your computer and exchanges the API
key for short-lived tokens using the January Server SDK.

### 3. Run the iOS demo

In a second terminal, clone the demo repository if needed:

```bash
git clone https://github.com/January-ai/january-sdk-ios.git
cd january-sdk-ios
```

Open
[`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj`](Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj),
select the `JanuaryPartnerDemo` scheme, and add these environment variables to
**Product → Scheme → Edit Scheme → Run → Arguments**:

```text
JANUARY_PARTNER_TOKEN_URL=http://127.0.0.1:8787/api/january/token
JANUARY_PARTNER_SESSION_TOKEN=january-local-demo
JANUARY_END_USER_ID=january-sdk-demo-user
```

Choose an iOS Simulator, press **Run**, and search for `banana`.

## Add the SDK to your app

### 1. Install

With Swift Package Manager, choose **File → Add Package Dependencies** in Xcode
and enter:

```text
https://github.com/January-ai/january-sdk-ios.git
```

Select the latest release and add the `January` product to your app target.

With CocoaPods:

```ruby
platform :ios, "15.0"

target "YourApp" do
  pod "January", "~> 0.1.0"
end
```

Then run `pod install --repo-update` and open the generated `.xcworkspace`.

### 2. Connect and make the first request

Implement `JanuaryTokenProvider` around the authenticated call to your own
backend:

```swift
import Foundation
import January

struct AppTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String

    func fetchClientToken(for _: String) async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(appSessionToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JanuaryTokenProviderError("Token endpoint is unavailable.", retryable: true)
        }
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode
            throw JanuaryTokenProviderError(
                "Token endpoint rejected the request.",
                retryable: status == 408 || status == 429 || (status ?? 0) >= 500
            )
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

let provider = AppTokenProvider(
    endpoint: URL(string: "https://your-backend.example/api/january/token")!,
    appSessionToken: session.token
)
let january = try JanuaryClient(
    endUserID: session.user.id,
    clientTokenProvider: provider
)

let foods = try await january.foods.search(.init(query: "banana"))
print("Found \(foods.items.count) foods")
```

A successful request prints a result count; an empty result is still a successful
connection. Create one `JanuaryClient` for the signed-in user and reuse it.
The SDK caches and refreshes client tokens automatically. The
[authentication guide](Documentation/GitBook/getting-started/authentication.md)
contains production retry and error mapping.

Your production endpoint returns `{ "token": "ct-…", "expiresIn": 1800 }`,
derives the stable end-user ID from the verified app session, and chooses scopes
on the server. See the
[backend token endpoint guide](Documentation/GitBook/getting-started/backend-token-endpoint.md)
for the complete contract.

## Common tasks

- [Foods](Documentation/GitBook/guides/foods.md)
- [Restaurants](Documentation/GitBook/guides/restaurants.md)
- [Photo scanning](Documentation/GitBook/guides/photo-scanning.md)
- [Native meal scanner](Documentation/GitBook/guides/native-meal-scanner.md)
- [Food logs](Documentation/GitBook/guides/food-logs.md)
- [Glucose prediction](Documentation/GitBook/guides/glucose-prediction.md)
- [Voice capture](Documentation/GitBook/guides/voice-capture.md)

For every resource, token lifecycle, errors, retries, and troubleshooting, see
the [complete iOS SDK guide](Documentation/GitBook/README.md).

For SDK development and testing, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Optional: fastest debug-only shortcut

If you only want to make a request immediately, the demo can use a server API
key directly in a local Debug build. This bypasses the recommended client-token
flow above. Remove the token-endpoint variables from the Xcode scheme, then add:

```text
JANUARY_API_KEY=sk-your-server-api-key
JANUARY_END_USER_ID=january-sdk-demo-user
```

Press **Run** and search for `banana`. Never commit the key, share an archive,
or distribute any build containing it. Release builds disable this path. Move
to the local token server or your authenticated backend before testing anything
outside your own machine.

## License

Apache 2.0. See [LICENSE](LICENSE).
