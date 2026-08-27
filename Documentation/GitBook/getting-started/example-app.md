# Example app

The repository includes a native SwiftUI example application at:

```text
Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj
```

## Run it

1. Clone `January-ai/partner-sdk-ios`.
2. Open `JanuaryPartnerDemo.xcodeproj` in Xcode 26 or later.
3. Select the `JanuaryPartnerDemo` scheme.
4. Run on an iOS 26 simulator or device.
5. Configure either the token-provider environment or a local development key in
   the scheme, then run.

The example links the local Swift package. In token mode it calls the explicitly
configured partner backend, returns `{ token, expiresIn }` directly to the SDK,
and lets the SDK cache and refresh the token. No token-server URL is built into
the public SDK.

{% hint style="warning" %}
The development-key mode is not a production authentication design. Never ship
a partner key in the app.
{% endhint %}

The demo includes food and restaurant discovery, autocomplete, hydrated food
details and servings, meal scanning, food logs, glucose prediction, persistent
user context, and user-friendly height and weight unit controls.
