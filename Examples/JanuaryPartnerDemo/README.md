# January iOS Demo

This January-owned integration harness demonstrates food and restaurant
discovery, meal-photo analysis, food logs, and glucose prediction with the
`JanuarySDK` Swift package.

## Requirements

- Xcode 26
- iOS 26 simulator or device
- Access to the SDK repository
- A partner-backend token endpoint

## Configure client-token authentication

Set these environment variables in the `JanuaryPartnerDemo` Run scheme:

```text
PARTNER_TOKEN_URL=https://your-backend.example.com/january-token
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai
JANUARY_END_USER_ID=your-test-user-id
```

For local January development, `PARTNER_TOKEN_URL` may point to the stand-in
backend at `http://127.0.0.1:8787/january-token`. The endpoint must return:

```json
{ "token": "ct-…", "expiresIn": 1800 }
```

`expires_in` is also accepted. Server API keys stay in the partner backend and
must never be added to this Xcode project, its scheme, or the app binary.

The demo refuses to start token mode when either URL is missing. These URL
settings are January-owned demo configuration; the public SDK does not expose
an API-origin override or guess a token endpoint.

## Run

Open `JanuaryPartnerDemo.xcodeproj`, select the `JanuaryPartnerDemo` scheme and
an iOS 26 simulator, then press **Run**.

Set an end-user ID and timezone from the in-app Settings sheet before using Food
Logs. The Scan tab can use the bundled sample meal on the simulator; camera
capture is available on a physical device.

The project links the repository's `JanuarySDK` product through a local Swift
Package dependency. The SDK caches the returned client token in memory,
refreshes it before expiration, and single-flights concurrent refreshes.

The visual tokens, reusable SwiftUI components, layout rules, and screen
requirements are documented in [DESIGN_SPEC.md](DESIGN_SPEC.md).
