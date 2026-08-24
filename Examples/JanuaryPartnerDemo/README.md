# January Partner Demo

The demo keeps development API-key authentication and adds a local
short-lived-token mode. Credentials are read from the Xcode scheme environment;
none are stored in source.

For the existing API-key flow, set:

```text
JANUARY_DEMO_API_KEY=<development-key>
```

For the complete local token simulation, first start `mock-january` on port
4010 and the Node partner example on port 4020 from the adjacent
`january-server-sdks` workspace. Then set these Xcode scheme variables:

```text
JANUARY_DEMO_AUTH_MODE=token
PARTNER_TOKEN_URL=http://127.0.0.1:4020/api/january/token
JANUARY_BASE_URL=http://127.0.0.1:4010
JANUARY_END_USER_ID=local-ios-user
```

The mock issues one-hour, in-memory tokens. Open
`JanuaryPartnerDemo.xcodeproj` and run the `JanuaryPartnerDemo` scheme on an
iOS 26 simulator.

The demo provides native screens for food and restaurant discovery, meal-photo
analysis and correction, food-log management, and glucose prediction. Set an
end user ID and timezone from the in-app Settings sheet before using Food Logs.
The Scan tab can use the bundled sample meal on the simulator; camera capture is
available on a physical device.

The visual tokens, reusable SwiftUI components, layout rules, and screen
requirements are documented in [DESIGN_SPEC.md](DESIGN_SPEC.md). New demo
screens should use that shared system rather than defining local colors,
typography, spacing, or button styles.

The project links the repository's `JanuaryPartnerSDK` library through a local
Swift Package dependency. In token mode the app calls the local partner route;
the SDK then caches the returned token in memory and calls the local January
food-search fixture directly.

Never embed a partner API key in an app distributed to customers.
