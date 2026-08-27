# Contributing

This repository is maintained by January. External contributions require prior
coordination through your January partner support channel.

## Development setup

Requirements: Xcode 15 or later and Swift 5.9 or later.

```sh
git clone https://github.com/January-ai/january-sdk-ios.git
cd january-sdk-ios
node scripts/check-coverage.mjs
```

Before opening a pull request, run:

```sh
node scripts/check-no-committed-secrets.mjs
node scripts/check-public-authentication.mjs
node scripts/check-coverage.mjs
xcodebuild -scheme JanuarySDK -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

Keep public API changes documented and add tests for behavior changes. Do not
commit API keys, client tokens, user data, generated build output, or local
environment files.

## Releases

Maintainers update `CHANGELOG.md`, confirm CI is green, and create a full
Semantic Versioning tag. GitHub Actions validates the tag and publishes the
corresponding GitHub release notes.
