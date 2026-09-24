# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Requirements

The demo is an integration harness, not a zero-configuration sample. It requires Xcode 26, an iOS 26 simulator or device, and token-provider configuration. These demo requirements are independent of the SDK, which supports iOS 15 with Xcode 15 and Swift 5.9.

## Run the token-provider path

Follow the [SDK README](https://github.com/January-ai/january-sdk-ios#quick-start-run-the-demo-with-client-tokens) to run the standalone January Token Relay. Then set
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

## Run the local Debug API-key path

Before your backend or a token relay is available, remove the token-endpoint
variables from the Xcode Run scheme, set `JANUARY_API_KEY` to your `sk-` server
API key and `JANUARY_END_USER_ID` to a test user, then run a Debug build. The
demo creates `JanuaryClient(developmentAPIKey:endUserID:timezone:)`, which
sends the key directly. Never commit the key or distribute a build configured
this way. Release builds disable this mode. The demo emits a build warning and
the SDK logs a runtime warning whenever development authentication is used.

The demo includes food and restaurant discovery, autocomplete, hydrated food
details and servings, meal scanning, food logs, a per-day Tracking tab for the day's meals, water, and weight, glucose prediction, persistent
user context, and user-friendly height and weight unit controls.

The Tracking tab also charts water and weight over the last week, month, or
year, ending today in the user's timezone. Water is a bar chart of daily totals
(monthly totals for the year) in the unit selected on the water card. Weight is
a line of each day's latest weight, converted to the unit selected on the
weight card. Each list request returns at most 100 days, so the year view reads
the range in spans of up to 90 days and merges them.

On the simulator, the Scan tab can use the bundled sample meal. Camera capture requires a physical device and `NSCameraUsageDescription`.
