# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Requirements

The demo is a January-owned integration harness, not a zero-configuration public sample. It requires Xcode 26, an iOS 26 simulator or device, repository access, and token-provider configuration. These demo requirements are independent of the SDK, which supports iOS 15 with Xcode 15 and Swift 5.9.

## Run the token-provider path

Configure the demo with the URL of your authenticated partner token endpoint:

```text
PARTNER_TOKEN_URL=https://your-backend.example.com/january-token
PARTNER_APP_SESSION_TOKEN=your-app-session-token
JANUARY_END_USER_ID=your-test-user
```

Authenticate the demo as a test user that your backend recognizes, then run the app.

The example links the local Swift package. In token mode it posts to the explicitly configured endpoint with the configured authorization and `x-end-user-id` test header, decodes `{ token, expiresIn }` directly as `JanuaryClientToken`, and lets the SDK cache and refresh it. A production backend must derive the user from the authenticated app session rather than trust that device-supplied header.

For local integration testing, you can deploy the public [January token relay](https://github.com/January-ai/january-token-relay) and place your deployment URL and relay secret in the Xcode scheme variables above. Never commit either value. No January-hosted test relay URL or shared test secret is included in the SDK, demo, or documentation. For production, use an authenticated partner backend that derives the end-user identity from the signed-in app session.

The public SDK targets January production and exposes no API-origin override.

## Run the local Debug token-exchange path

Before your backend is available, configure a local Debug run with:

```text
JANUARY_DEMO_API_KEY=your-local-development-key
JANUARY_END_USER_ID=your-test-user
JANUARY_DEMO_TOKEN_TTL_SECONDS=300
```

The demo creates `JanuaryDevelopmentTokenProvider`, mints short-lived client
tokens, and then uses the same `JanuaryClient` caching and refresh path as the
partner-backend mode. The key must remain in local Xcode scheme configuration.
Never commit it or distribute a build configured this way. Release builds
disable this mode.

The demo includes food and restaurant discovery, autocomplete, hydrated food
details and servings, meal scanning, food logs, glucose prediction, persistent
user context, and user-friendly height and weight unit controls.

On the simulator, the Scan tab can use the bundled sample meal. Camera capture requires a physical device and `NSCameraUsageDescription`.
