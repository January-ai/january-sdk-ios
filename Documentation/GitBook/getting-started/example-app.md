# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Requirements

The demo is a January-owned integration harness, not a zero-configuration public sample. It requires Xcode 26, an iOS 26 simulator or device, repository access, and January-approved development configuration.

## Run with a local development key

1. Open `JanuaryPartnerDemo.xcodeproj` in Xcode 26 or later.
2. Edit the `JanuaryPartnerDemo` scheme.
3. Add this Run environment variable without committing its value:

```text
JANUARY_DEMO_API_KEY=<January-approved-development-key>
```

4. Run the `JanuaryPartnerDemo` scheme on an iOS 26 simulator or device.

Never distribute this configuration.

## Run the token-provider path

The demo supports January's local stand-in partner backend. Configure these Run environment variables explicitly:

```text
PARTNER_TOKEN_URL=http://127.0.0.1:8787/january-token
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai
JANUARY_END_USER_ID=local-ios-user
```

Start the stand-in backend using the instructions supplied by January, then run the app. The simulator can reach `127.0.0.1`; a physical device needs your Mac's LAN address and the same network.

The example links the local Swift package. In token mode it calls the explicitly configured partner backend, decodes `{ token, expiresIn }` directly as `JanuaryClientToken`, and lets the SDK cache and refresh it.

The demo imports a development-only SPI solely to target January's dev API. Partner applications must not import that SPI; public client initializers target production.

{% hint style="warning" %}
The development-key mode is not a production authentication design. Never ship
a partner key in the app.
{% endhint %}

The demo includes food and restaurant discovery, autocomplete, hydrated food
details and servings, meal scanning, food logs, glucose prediction, persistent
user context, and user-friendly height and weight unit controls.

On the simulator, the Scan tab can use the bundled sample meal. Camera capture requires a physical device and `NSCameraUsageDescription`.
