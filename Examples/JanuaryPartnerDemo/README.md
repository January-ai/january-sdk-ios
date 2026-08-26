# January Partner Demo

The demo supports development API-key authentication and the production-shaped
short-lived-token provider. Credentials are read from the Xcode scheme
environment; none are stored in source.

For the existing API-key flow, set:

```text
JANUARY_DEMO_API_KEY=<development-key>
```

To exercise the token provider with January's local stand-in backend, set these
Xcode scheme variables explicitly:

```text
PARTNER_TOKEN_URL=http://127.0.0.1:8787/january-token
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai
JANUARY_END_USER_ID=local-ios-user
```

The demo refuses to start token mode when either URL is missing. The token
endpoint must return `{ "token": "ct-…", "expiresIn": 1800 }` (snake-case
`expires_in` is also accepted). These development URL settings belong to the
January-owned demo and are not public SDK configuration.
Open `JanuaryPartnerDemo.xcodeproj` and run the `JanuaryPartnerDemo` scheme on
an iOS 26 simulator.

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
Swift Package dependency. In token mode the app calls the partner route; the
SDK then caches the returned token in memory and calls the explicitly configured
January development API through a development-only SPI.

Never embed a partner API key in an app distributed to customers.

## Live token-refresh smoke test

Run the stand-in backend with January's minimum client-token lifetime:

```sh
cd ../partner-proxy-service
JANUARY_API_KEY="$JANUARY_API_KEY" TTL_SECONDS=300 \
  node scripts/mock-partner-backend.js
```

For a fast live proof that the SDK calls the provider again, the smoke executable
can report a 61-second cache lifetime while the real token remains valid for 300
seconds. After two seconds, the SDK is inside its 60-second refresh window:

```sh
PARTNER_TOKEN_URL=http://127.0.0.1:8787/january-token \
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai \
JANUARY_END_USER_ID=refresh-smoke-user \
JANUARY_TEST_REPORTED_EXPIRES_IN=61 \
JANUARY_TEST_SECOND_REQUEST_DELAY_SECONDS=2 \
swift run JanuaryPartnerTokenSmoke
```

The output must report two provider calls, and the stand-in backend must report
two token mints. To exercise January's real `401 token_expired` response, report
a longer cache lifetime than the real token and wait just over five minutes:

```sh
PARTNER_TOKEN_URL=http://127.0.0.1:8787/january-token \
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai \
JANUARY_END_USER_ID=refresh-smoke-user \
JANUARY_TEST_REPORTED_EXPIRES_IN=3600 \
JANUARY_TEST_SECOND_REQUEST_DELAY_SECONDS=305 \
swift run JanuaryPartnerTokenSmoke
```

That second mode deliberately prevents proactive refresh in the smoke process:
the second search sends the actually expired token, the SDK receives
`token_expired`, calls the provider, and retries once with the newly minted token.
These lifetime overrides exist only in the smoke executable and do not alter SDK
production behavior.

To prove provider retry and backoff in the real executable without making the
stand-in backend unreliable, deliberately fail the first two provider calls:

```sh
PARTNER_TOKEN_URL=http://127.0.0.1:8787/january-token \
JANUARY_INTERNAL_API_BASE_URL=https://partners.dev.january.ai \
JANUARY_END_USER_ID=retry-smoke-user \
JANUARY_TEST_PROVIDER_FAILURES=2 \
swift run JanuaryPartnerTokenSmoke
```

The process must succeed with three provider calls while the stand-in backend
reports one token mint. The failure switch exists only in this smoke executable.
