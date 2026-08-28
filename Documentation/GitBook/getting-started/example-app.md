# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Requirements

The demo is a January-owned integration harness, not a zero-configuration public sample. It requires Xcode 26, an iOS 26 simulator or device, repository access, and token-provider configuration. These demo requirements are independent of the SDK, which supports iOS 15 with Xcode 15 and Swift 5.9.

## Run the token-provider path

Open `JanuaryPartnerDemoApp.swift` and edit the `AppConfiguration` block at the
top of the file. Set `partnerTokenURL`, `partnerAppSessionToken`, and
`endUserID`, then run the app. The demo does not require Xcode scheme variables
or an in-app credential form.

Authenticate the demo as a test user that your backend recognizes, then run the app.

The example links the local Swift package. In token mode it posts to the explicitly configured endpoint with the configured authorization and `x-end-user-id` test header, decodes `{ token, expiresIn }` directly as `JanuaryClientToken`, and lets the SDK cache and refresh it. A production backend must derive the user from the authenticated app session rather than trust that device-supplied header.

For local integration testing, you can deploy the public [January token relay](https://github.com/January-ai/january-token-relay) and place your deployment URL and relay secret in the demo configuration block. Never commit either value. No January-hosted test relay URL or shared test secret is included in the SDK, demo, or documentation. For production, use an authenticated partner backend that derives the end-user identity from the signed-in app session.

The public SDK targets January production and exposes no API-origin override.

## Run the local Debug token-exchange path

Before your backend is available, set `developmentAPIKey` and `endUserID` in the
same `AppConfiguration` block, then run a Debug build.

The demo creates `JanuaryDevelopmentTokenProvider`, mints short-lived client
tokens, and then uses the same `JanuaryClient` caching and refresh path as the
partner-backend mode. Never commit the key or distribute a build configured
this way. Release builds disable this mode. The demo emits a build warning and
the SDK logs a runtime warning whenever development authentication is used.

The demo includes food and restaurant discovery, autocomplete, hydrated food
details and servings, meal scanning, food logs, glucose prediction, persistent
user context, and user-friendly height and weight unit controls.

On the simulator, the Scan tab can use the bundled sample meal. Camera capture requires a physical device and `NSCameraUsageDescription`.
