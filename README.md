# January SDK for iOS

Controlled-preview iOS SDK for January food discovery, restaurants, meal
scanning, food logs, and glucose prediction.

> **Distribution status:** `January-ai/january-sdk-ios` is private and has no
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
git clone https://github.com/January-ai/january-sdk-ios.git
cd january-sdk-ios
git checkout 9dca0d5523ab8a0898922e80645ef15bd5fea98e
swift test
```

The library requires Swift 6.1 and supports iOS 15 or later. The example app
has separate Xcode 26 and iOS 26 requirements.

## Authentication rule

Public SDK authentication uses short-lived client tokens only. An app obtains
its token from its own authenticated backend and supplies a
`JanuaryTokenProvider`. Start with the
[backend token endpoint](Documentation/GitBook/getting-started/backend-token-endpoint.md).
