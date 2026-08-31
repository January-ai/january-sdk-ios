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

Select the latest release shown by Xcode and add the `January` product to
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
import January

struct AppTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String

    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(appSessionToken)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(endUserID, forHTTPHeaderField: "x-end-user-id")

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
let january = try JanuaryClient(
    endUserID: signedInUser.id,
    clientTokenProvider: provider
)

let results = try await january.foods.search(.init(query: "greek yogurt"))
let logs = try await january.foodLogs.list(
    start: "2026-08-01",
    end: "2026-08-31"
)
```

Create one `JanuaryClient` for the signed-in user and reuse it. `endUserID` is
the required stable string from your user system. The SDK passes it to the
provider whenever a new client token is needed. The SDK uses
`TimeZone.current` when `timezone` is omitted.

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
against January production. Token lifetime is managed internally and is not
part of the public configuration.

> **Warning:** This provider sends the API key from the app process. Use it only
> in a local Debug build. Never commit the key, include it in an app binary, or
> distribute an app configured this way.

```swift
#if DEBUG
guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"],
      let rawUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set the local January development credentials in the Xcode scheme.")
}

let provider = try JanuaryDevelopmentTokenProvider(apiKey: apiKey)
let january = try JanuaryClient(
    endUserID: rawUserID,
    clientTokenProvider: provider
)
#endif
```

For production, replace this helper with the backend-backed
`AppTokenProvider` shown above. No other client lifecycle code changes.

## Local development with an API key

> **Warning:** `developmentAPIKey` is only for local testing. Do not ship an app
> with this key or commit one to source control. Production apps must use
> `JanuaryTokenProvider` as shown above.

The initializer remains supported for local experiments and writes a runtime
warning to the Xcode console whenever a nonempty key is provided. The warning
never contains the key. Release builds reject this initializer at compile time,
preventing a development API key from being shipped:

```swift
import Foundation
import January

guard let apiKey = ProcessInfo.processInfo.environment["JANUARY_API_KEY"],
      let endUserID = ProcessInfo.processInfo.environment["JANUARY_END_USER_ID"] else {
    fatalError("Set the local January development credentials in the Xcode scheme.")
}
let january = try JanuaryClient(
    developmentAPIKey: apiKey,
    endUserID: endUserID
)
```

`endUserID` is required and must be a stable, non-identifying string from your
own user system. It must never be an email address or display name. If
`timezone` is omitted, the SDK uses `TimeZone.current`.

## Make a request

```swift
let results = try await january.foods.search(
    SearchFoodsRequest(query: "greek yogurt", limit: 10)
)

if let match = results.items.first {
    let food = try await january.foods.get(id: match.id)
    print(food.name, food.servings)
}
```

Search results are lightweight. Call `get` before presenting serving choices
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
xcodebuild -scheme January -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and
[SECURITY.md](SECURITY.md) for project policies.

## License

January SDK for iOS is available under the [Apache License 2.0](LICENSE).

## Support

For integration support, use your January partner support channel. Report
security issues through that private channel rather than a public issue.

## Menu items by restaurant ID

Use the ID of a `restaurant` search result to load its menu, independently of search text and location.

```swift
let page = try await client.restaurants.getMenuItems(.init(restaurantID: restaurant.id, limit: 100, offset: 0))
```

The response contains `items` and `totalCount` (`total_count` on the wire). Request subsequent pages by advancing `offset` by the number of items received, until it reaches the total or a page is empty. An unknown restaurant returns 404; an existing restaurant with no menu returns an empty list.

This operation requires the backend restaurant-ID menu endpoint; deployment is pending for this unreleased change.
