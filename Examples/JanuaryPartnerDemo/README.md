# January iOS Demo

This January-owned integration harness demonstrates food and restaurant
discovery, meal-photo analysis, food logs, and glucose prediction with the
`JanuarySDK` Swift package.

## Requirements

- Xcode 26
- iOS 26 simulator or device
- Access to the SDK repository
- A partner-backend token endpoint, or a local development API key for a Debug run

## Configure client-token authentication

Set these environment variables in the `JanuaryPartnerDemo` Run scheme:

```text
PARTNER_TOKEN_URL=https://your-backend.example.com/january-token
JANUARY_END_USER_ID=your-test-user-id
PARTNER_APP_SESSION_TOKEN=your-app-session-token
```

A real partner backend must authenticate the app session before minting a token
and derive the end-user identity from that session. The endpoint must return:

```json
{ "token": "ct-…", "expiresIn": 1800 }
```

`expires_in` is also accepted. Server API keys stay in the partner backend and
must never be added to this Xcode project, its scheme, or the app binary.

The demo refuses to start token mode when the endpoint or app-session token is
missing. The SDK does not guess a token endpoint.

## Local Debug token exchange

To exercise minting and automatic refresh before a partner backend is ready,
set these local Run-scheme variables in a Debug build:

```text
JANUARY_DEMO_API_KEY=your-local-development-key
JANUARY_END_USER_ID=your-test-user-id
JANUARY_DEMO_TOKEN_TTL_SECONDS=300
```

The demo uses `JanuaryDevelopmentTokenProvider` and the same `JanuaryClient`
token lifecycle as production. The key must stay in local scheme configuration.
Never commit it or distribute a build configured this way. Release builds
disable this mode.

## Run

Open `JanuaryPartnerDemo.xcodeproj`, select the `JanuaryPartnerDemo` scheme and
an iOS 26 simulator, then press **Run**.

Set an end-user ID and timezone from the in-app Settings sheet before using Food
Logs. The Scan tab can use the bundled sample meal on the simulator; camera
capture is available on a physical device.

The project links the repository's `JanuarySDK` product through a local Swift
Package dependency. The SDK caches the returned client token in memory,
refreshes it before expiration, and single-flights concurrent refreshes.
`PartnerBackendTokenProvider` is the relay-compatible demo implementation: it
posts to the configured endpoint, supplies the relay authorization and
`x-end-user-id` headers, and decodes the server response for the SDK. Keep the
endpoint and secret in local scheme configuration. Do not commit them.

For a self-hosted testing relay, deploy the public
[January token relay](https://github.com/January-ai/january-token-relay) and use
the URL and secret from your own deployment. The SDK and demo intentionally do
not contain a hosted test URL or shared test secret. A production partner
backend should authenticate the app session and derive the end-user identity
server-side.

The visual tokens, reusable SwiftUI components, layout rules, and screen
requirements are documented in [DESIGN_SPEC.md](DESIGN_SPEC.md).
