# January iOS Demo

This January-owned integration harness demonstrates food and restaurant
discovery, meal-photo analysis, food logs, and glucose prediction with the
`January` Swift package.

## Requirements

- Xcode 26
- iOS 26 simulator or device
- Access to the SDK repository
- A client-token endpoint (the local setup below provides one)

## Quick local setup

After you [sign up](https://dashboard.january.ai/sign-up) or
[sign in](https://dashboard.january.ai/sign-in), create a January API key from
**API keys → Create key**, then separately open
[Client tokens](https://dashboard.january.ai/dashboard/client-tokens) and select
**Enable client tokens**.

Clone the standalone [January Token Relay](https://github.com/January-ai/january-token-relay)
and start it:

```sh
git clone https://github.com/January-ai/january-token-relay.git
cd january-token-relay
./start.sh
```

In Xcode, add these environment variables to
**Product → Scheme → Edit Scheme → Run → Arguments**:

```text
JANUARY_PARTNER_TOKEN_URL=http://127.0.0.1:8787/api/january/client-token
JANUARY_END_USER_ID=january-sdk-demo-user
```

Leave the server running, open `JanuaryPartnerDemo.xcodeproj`, select the
`JanuaryPartnerDemo` scheme and an iOS Simulator, then press **Run**. Search for
`banana` to make the first SDK request.

## Production authentication

A real partner backend must authenticate the app session before minting a token
and derive the end-user identity from that session. The endpoint returns:

```json
{ "token": "ct-…", "expiresIn": 1800 }
```

`expires_in` is also accepted. Server API keys stay in the partner backend and
must never be added to this Xcode project or the app binary. The demo refuses to
start token mode when the endpoint is missing; the SDK does not guess a token
endpoint. The local loopback relay needs no relay token.

The SDK caches the returned client token in memory, refreshes it before
expiration, and single-flights concurrent refreshes. `PartnerBackendTokenProvider`
posts to the configured endpoint, supplies the selected end-user ID for local
relay testing, and decodes the server response for the SDK. It also supports an
optional authorization value for a relay that is reachable from another device.

You can override the end-user ID and timezone from the in-app Settings sheet.
The Scan tab can use the bundled sample meal on the simulator; camera capture is
available on a physical device.

For a physical device, follow the relay's `HOST=0.0.0.0 ./start.sh` instructions
and set `JANUARY_PARTNER_SESSION_TOKEN` to the generated relay token. A
production partner backend should authenticate the app session and derive the
end-user identity server-side.

The visual tokens, reusable SwiftUI components, layout rules, and screen
requirements are documented in [DESIGN_SPEC.md](DESIGN_SPEC.md).

The Search tab includes a microphone button for every text-based search mode.
It demonstrates `VoiceCaptureSession` permission handling, live recording
feedback, cancellation, and appending the Apple Speech transcript to the query.

## Optional debug-only shortcut

For the absolute fastest local test, remove the token-endpoint variables from
the Xcode scheme and set `JANUARY_API_KEY=sk-your-server-api-key`. The demo uses
it only in Debug builds and displays a warning. Never commit the key, share an
archive, or distribute the build; switch back to client tokens afterward.
