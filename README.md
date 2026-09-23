# January SDK for iOS

[![CI](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml/badge.svg)](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml)
[![CocoaPods](https://img.shields.io/cocoapods/v/January.svg)](https://cocoapods.org/pods/January)

The official Swift SDK for January food discovery, restaurants, meal scanning,
food, water, and weight logs, and glucose prediction. It supports iOS 15+, Xcode 15+, and Swift
5.9+, with no third-party runtime dependencies. The included demo currently
requires Xcode 26 and an iOS 26 simulator or device.

## Quick start: run the demo with client tokens

You can try the iOS SDK before your own backend is ready. The standalone
January Token Relay keeps the January API key off the app and temporarily
stands in for your production token endpoint.

You need two terminal windows: one for the January Token Relay, which holds
your API key and hands the app short-lived client tokens, and one for the
demo. The first run takes about ten minutes.

### Terminal 1: start the token relay

1. Open a terminal.
2. Download the relay and move into its folder. It needs Node.js 20.12 or
   newer and nothing else:

   ```bash
   git clone https://github.com/January-ai/january-token-relay.git
   cd january-token-relay
   ```

3. Start it:

   ```bash
   ./start.sh
   ```

   It checks your Node version and then asks
   `Paste your API key (input is hidden):`. Leave it waiting and create the
   key in the next two steps.

4. Create the API key. In a browser,
   [sign up](https://dashboard.january.ai/sign-up) or
   [sign in](https://dashboard.january.ai/sign-in) to the January Developer
   Dashboard, open **API keys → Create key**, and copy the full `sk-…` value.
   It is shown once.
5. Enable client tokens. Open
   [Client tokens](https://dashboard.january.ai/dashboard/client-tokens) and
   switch on **Enable client tokens**. Until this is on, January answers the
   relay with `403`.
6. Back in Terminal 1, paste the key and press Enter. Nothing appears while
   you type. You should see:

   ```text
   ✓ API key accepted by January (sk-abcd…wxyz)
   ✓ Saved to .env (readable only by you; git ignores it)

   January Token Relay is running on this machine (development only).
     Endpoint      http://localhost:8787/api/january/client-token
   ```

   Leave this window open for the whole session. The key is saved in a
   git-ignored `.env`, so the next `./start.sh` starts without asking.

### Terminal 2: run the iOS demo

7. Open a second terminal.
8. Download the SDK repository and move into it:

   ```bash
   git clone https://github.com/January-ai/january-sdk-ios.git
   cd january-sdk-ios
   ```

9. Open
   [`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj`](Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj)
   in Xcode and select the `JanuaryPartnerDemo` scheme.
10. Tell the demo where the relay is. Open
    **Product → Scheme → Edit Scheme → Run → Arguments** and add these
    environment variables:

    ```text
    JANUARY_PARTNER_TOKEN_URL=http://127.0.0.1:8787/api/january/client-token
    JANUARY_END_USER_ID=january-sdk-demo-user
    ```

11. Choose an iOS Simulator and press **Run**. When the app opens, search for
    `banana`. Terminal 1 prints `minted=true status=200` the first time the
    app asks for a token.

For production or any shared build, never put the `sk-…` key in an iOS app.
The private, debug-only shortcut at the end is the sole local exception.

### Optional: deploy the relay to Vercel

If localhost is inconvenient, follow the relay's
[Vercel deployment guide](https://github.com/January-ai/january-token-relay#deploy).
Set `JANUARY_API_KEY` and a long random `RELAY_TOKEN` in Vercel, then replace
the demo scheme values with:

```text
JANUARY_PARTNER_TOKEN_URL=https://YOUR-PROJECT.vercel.app/api/january/client-token
JANUARY_PARTNER_SESSION_TOKEN=YOUR_RELAY_TOKEN
JANUARY_END_USER_ID=january-sdk-demo-user
```

The demo sends that user ID to the relay in the canonical
`January-End-User-ID` header.

The hosted relay is also for development and testing only. Its relay token is
not a substitute for authenticating your users.

This relay is only for development. In production, keep the same SDK token
provider but point it to your authenticated backend. Your backend must verify
the app session and derive the end-user ID instead of trusting an ID supplied
by the app.

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
  pod "January", "~> 0.3.0"
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
        request.setValue("Bearer " + appSessionToken, forHTTPHeaderField: "Authorization")

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
    endpoint: URL(string: "https://your-backend.example/api/january/client-token")!,
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
- [Water and weight logs](Documentation/GitBook/guides/water-and-weight-logs.md)
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
to the local token relay or your authenticated backend before testing anything
outside your own machine.

## License

Apache 2.0. See [LICENSE](LICENSE).
