# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Requirements

The demo is a January-owned integration harness, not a zero-configuration public sample. It requires Xcode 26, an iOS 26 simulator or device, repository access, and token-provider configuration.

## Run the token-provider path

Configure the demo with the URL of your authenticated partner token endpoint:

```text
PARTNER_TOKEN_URL=https://your-backend.example.com/january-token
JANUARY_END_USER_ID=your-test-user
```

Authenticate the demo as a test user that your backend recognizes, then run the app.

The example links the local Swift package. In token mode it calls the explicitly configured partner backend, decodes `{ token, expiresIn }` directly as `JanuaryClientToken`, and lets the SDK cache and refresh it.

The public SDK targets January production and exposes no API-origin override.

The demo includes food and restaurant discovery, autocomplete, hydrated food
details and servings, meal scanning, food logs, glucose prediction, persistent
user context, and user-friendly height and weight unit controls.

On the simulator, the Scan tab can use the bundled sample meal. Camera capture requires a physical device and `NSCameraUsageDescription`.
