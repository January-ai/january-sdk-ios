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
5. Enter a development API key when prompted.

The example links the local Swift package. It validates the key through the SDK and stores the development credential in the device Keychain.

{% hint style="warning" %}
The example demonstrates a development workflow. Its API-key screen is not a production authentication design.
{% endhint %}

