# Example app

The [SDK repository](https://github.com/January-ai/january-sdk-ios) includes a SwiftUI demo app, `Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj`, that exercises the SDK's features. The demo needs Xcode 26 and an iOS 26 simulator or device; your own app needs only the SDK's [requirements](../README.md#requirements).

## Run it with the token relay

1. Start the [token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay).
2. Clone `https://github.com/January-ai/january-sdk-ios.git` and open the demo project in Xcode.
3. Choose **Product → Scheme → Edit Scheme → Run → Arguments** and add these environment variables:

   ```text
   JANUARY_PARTNER_TOKEN_URL=http://localhost:8787/api/january/client-token
   JANUARY_END_USER_ID=january-sdk-demo-user
   ```

4. Choose an iOS Simulator and press **Run**.

If the relay is reachable from other devices, also set `JANUARY_PARTNER_SESSION_TOKEN` to its relay token. Never commit either value.

To run the demo against your own token endpoint, set `JANUARY_PARTNER_TOKEN_URL` to it and `JANUARY_PARTNER_SESSION_TOKEN` to a valid app session token.

## Run it with an API key

In a Debug build, you can instead leave out the token variables and set `JANUARY_API_KEY` to your API key. The demo then uses `developmentAPIKey` ([local development](authentication.md#local-development)).

On the Simulator, the Scan tab can analyze a bundled sample meal; camera capture needs a physical device.

Next: [Core concepts](https://docs.january.ai/ios-sdk/concepts).
