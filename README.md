# January Partner SDK for iOS

Controlled-preview iOS SDK for January food discovery, restaurants, meal
scanning, food logs, and glucose prediction.

> **Distribution status:** `January-ai/partner-sdk-ios` is private and has no
> release tags. Authorized evaluators must use the exact-revision Swift Package
> Manager workflow in the
> [installation guide](Documentation/GitBook/getting-started/installation.md).

## Documentation

The [iOS SDK GitBook](Documentation/GitBook/README.md) covers installation,
the required partner-backend token exchange, a complete token provider, food
hydration and portions, native scanning, retries, errors, testing, security, and
troubleshooting.

## Evaluate the repository

```bash
git clone https://github.com/January-ai/partner-sdk-ios.git
cd partner-sdk-ios
git checkout c5e4725503eae7bdda85e7ad3786222c42f57d14
swift test
```

The library requires Swift 6.1 and supports iOS 15 or later. The example app
has separate Xcode 26 and iOS 26 requirements.

## Authentication rule

Never ship a long-lived January partner key in an app. A production app obtains
a short-lived client token from its own authenticated backend and supplies a
`JanuaryTokenProvider`. Start with the
[backend token endpoint](Documentation/GitBook/getting-started/backend-token-endpoint.md).
