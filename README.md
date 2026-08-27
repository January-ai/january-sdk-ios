# January SDK for iOS

[![CI](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml/badge.svg)](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-blue)
![Swift 6.1+](https://img.shields.io/badge/Swift-6.1%2B-orange)

January's native Swift SDK for food discovery, restaurant search, meal scanning,
food logs, and glucose prediction.

> **Preview:** This repository and its prerelease versions are currently
> private. Your GitHub account must have access to install the package.

## Requirements

- iOS 15 or later
- Xcode 16.3 or later
- Swift 6.1 or later

## Install with Swift Package Manager

In Xcode, choose **File → Add Package Dependencies**, then enter:

```text
https://github.com/January-ai/january-sdk-ios.git
```

Select **Exact Version**, enter `0.1.0-beta.1`, and add the `JanuarySDK` product
to your app target. For a package manifest:

```swift
dependencies: [
    .package(
        url: "https://github.com/January-ai/january-sdk-ios.git",
        exact: "0.1.0-beta.1"
    ),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "JanuarySDK", package: "january-sdk-ios"),
        ]
    ),
]
```

Preview releases use exact prerelease versions. After the stable `0.1.0`
release, applications can adopt a compatible version requirement.

## Production authentication: client tokens

Never put a January server API key in a production iOS app. Your authenticated
backend exchanges its server-side credential for a short-lived client token.
When the SDK needs a token, your provider makes an authenticated API call to
your server and returns your server's response to the SDK:

```swift
import Foundation
import JanuarySDK

struct AppTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String

    func fetchClientToken() async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.setValue(
            "Bearer \(appSessionToken)",
            forHTTPHeaderField: "Authorization"
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

let provider = AppTokenProvider(
    endpoint: requiredTokenEndpoint,
    appSessionToken: signedInUser.sessionToken
)
let january = try JanuaryClient(clientTokenProvider: provider)
```

The endpoint is app configuration with no SDK default. Its stable response is:

```json
{ "token": "ct-…", "expiresIn": 1800 }
```

`JanuaryClientToken` also accepts `expires_in`. The SDK caches tokens in memory,
refreshes before expiry, single-flights concurrent refreshes, and retries token
provider failures with bounded exponential backoff.

## Local development with an API key

> **Warning:** `developmentAPIKey` is only for local testing. Do not ship an app
> with this key or commit one to source control. Production apps must use
> `JanuaryTokenProvider` as shown above.

The initializer remains available for local experiments and displays both an
Xcode warning and a runtime warning in the Xcode console. Neither warning ever
contains the key:

```swift
import Foundation
import JanuarySDK

guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"] else {
    fatalError("Set JANUARY_API_KEY in the local Xcode scheme.")
}
guard let rawUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set JANUARY_END_USER_ID in the local Xcode scheme.")
}

let january = try JanuaryClient(
    developmentAPIKey: apiKey,
    endUserID: PartnerUserID(rawValue: rawUserID)
)
```

The end-user ID is the stable, non-identifying ID from your own user system. In
development API-key mode the client applies it to every request. It is not the
SDK developer's personal ID, an email address, or a display name.

## Make a request

```swift
let results = try await january.foods.search(
    SearchFoodsRequest(query: "greek yogurt", limit: 10)
)

if let match = results.items.first {
    let food = try await january.foods.getFood(
        GetFoodRequest(foodID: match.id)
    )
    print(food.name, food.servings)
}
```

Search results are lightweight. Call `getFood` before presenting serving choices
so the selected food contains every available serving.

## Documentation

- [Installation](Documentation/GitBook/getting-started/installation.md)
- [Backend token endpoint](Documentation/GitBook/getting-started/backend-token-endpoint.md)
- [Authentication](Documentation/GitBook/getting-started/authentication.md)
- [First iOS request](Documentation/GitBook/getting-started/quick-start.md)
- [API reference](Documentation/GitBook/reference/client-and-resources.md)
- [Example app](Examples/JanuaryPartnerDemo/README.md) (iOS 26)

## Development

```sh
node scripts/check-coverage.mjs
xcodebuild -scheme JanuarySDK -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and
[SECURITY.md](SECURITY.md) for project policies.

## Support

For integration support, use your January partner support channel. Report
security issues through that private channel rather than a public issue.
