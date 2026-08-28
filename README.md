# January SDK for iOS

[![CI](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml/badge.svg)](https://github.com/January-ai/january-sdk-ios/actions/workflows/quality.yml)
![iOS 15+](https://img.shields.io/badge/iOS-15%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)

January's native Swift SDK for food discovery, restaurant search, meal scanning,
food logs, and glucose prediction. The package has no third-party runtime
dependencies.

> **Preview:** This repository and its prerelease versions are currently
> private. Your GitHub account must have access to install the package.

## Requirements

- iOS 15 or later
- Xcode 15 or later
- Swift 5.9 or later

## Install with Swift Package Manager

In Xcode, choose **File → Add Package Dependencies**, then enter:

```text
https://github.com/January-ai/january-sdk-ios.git
```

Select the latest release shown by Xcode and add the `JanuarySDK` product to
your app target. Swift Package Manager has no symbolic `latest` requirement for
manifest-only integrations; use the current release tag shown in the repository
rather than copying a version number from this README.

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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JanuaryTokenProviderError("Token endpoint is unavailable.", retryable: true)
        }
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
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
    endpoint: requiredTokenEndpoint,
    appSessionToken: signedInUser.sessionToken
)
let january = try JanuaryClient(clientTokenProvider: provider)
```

Set the signed-in user once after creating the client, then use the scoped
resources instead of repeating an ID in every request:

```swift
let user = january.forUser(
    PartnerUserID(rawValue: signedInUser.stableID),
    timezone: TimeZone.current.identifier
)

let results = try await user.foods.search(.init(query: "greek yogurt"))
let logs = try await user.foodLogs.list(
    start: "2026-08-01",
    end: "2026-08-31"
)
```

Recreate this lightweight scoped value when the active app account changes.
With client-token authentication, January derives identity from the token and
the SDK prevents a per-request ID from contradicting it.

The endpoint is app configuration with no SDK default. Its stable response is:

```json
{ "token": "ct-…", "expiresIn": 1800 }
```

`JanuaryClientToken` also accepts `expires_in`. The SDK caches tokens in memory,
refreshes before expiry, single-flights concurrent refreshes, and retries token
provider failures explicitly marked retryable with bounded exponential backoff.

To verify this flow before your backend is ready, deploy the public
[January token relay](https://github.com/January-ai/january-token-relay) and
configure the demo app with your deployment URL, relay secret, and test user ID.
Those values belong only in local Xcode scheme configuration and must never be
committed. The SDK contains no hosted test-relay URL or shared test secret. Use
an authenticated backend that derives the user identity server-side in
production.

## Test the client-token lifecycle locally

`JanuaryDevelopmentTokenProvider` lets a local Debug build exercise the same
mint, cache, refresh, and replay path without first implementing a partner
backend. It exchanges a development API key for short-lived client tokens
against January production. The token lifetime must be between 300 and 7,200
seconds.

> **Warning:** This provider sends the API key from the app process. Use it only
> in a local Debug build. Never commit the key, include it in an app binary, or
> distribute an app configured this way.

```swift
#if DEBUG
guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"],
      let rawUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set the local January development credentials in the Xcode scheme.")
}

let provider = try JanuaryDevelopmentTokenProvider(
    apiKey: apiKey,
    endUserID: PartnerUserID(rawValue: rawUserID),
    ttlSeconds: 300
)
let january = try JanuaryClient(clientTokenProvider: provider)
#endif
```

For production, replace this helper with the backend-backed
`AppTokenProvider` shown above. No other client lifecycle code changes.

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

## License

January SDK for iOS is available under the [Apache License 2.0](LICENSE).

## Support

For integration support, use your January partner support channel. Report
security issues through that private channel rather than a public issue.
