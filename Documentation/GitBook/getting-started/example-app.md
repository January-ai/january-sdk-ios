# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Requirements

The demo is a January-owned integration harness, not a zero-configuration public sample. It requires Xcode 26, an iOS 26 simulator or device, repository access, and token-provider configuration. These demo requirements are independent of the SDK, which supports iOS 15 with Xcode 15 and Swift 5.9.

## Run the token-provider path

Follow the root README to run the standalone January Token Relay. Then set
`JANUARY_PARTNER_TOKEN_URL` and `JANUARY_END_USER_ID` in the Xcode Run scheme
and run the app. The loopback relay does not require a session or relay token.

The example links the local Swift package. In token mode it posts to the explicitly configured endpoint with the configured authorization and `January-End-User-ID` test header, decodes `{ token, expiresIn }` directly as `JanuaryClientToken`, and lets the SDK cache and refresh it. A production backend must derive the user from the authenticated app session rather than trust that device-supplied header.

For a physical device or remotely hosted development relay, follow the public
[January Token Relay](https://github.com/January-ai/january-token-relay) guide
and place its URL in `JANUARY_PARTNER_TOKEN_URL` and its relay token in
`JANUARY_PARTNER_SESSION_TOKEN` in the Xcode Run scheme. Never commit either
value. For production, use an authenticated partner backend that derives the
end-user identity from the signed-in app session.

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
