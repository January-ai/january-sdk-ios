# Releasing the iOS SDK

## One-time CocoaPods setup

1. Register and verify the `oren@january.ai` CocoaPods Trunk account.
2. Copy that account's Trunk token into the repository secret
   `COCOAPODS_TRUNK_TOKEN`.

## Release

1. Set the same release version in `January.podspec` and
   `JanuaryPartnerTransport.podspec`.
2. Record the release in `CHANGELOG.md` on `main`.
3. Create and push a SemVer tag without a `v` prefix, such as `0.2.0` or
   `0.2.0-beta.1`.

The release workflow accepts tags whose commits are contained in `main`'s history,
validates the Swift package manifest, runs the SDK coverage gate and complete
example-app UI suite, validates both podspecs together, publishes
`JanuaryPartnerTransport` followed by `January` to CocoaPods Trunk, and creates
the GitHub Release. Prerelease tags create prerelease GitHub Releases. The
workflow also resolves the exact tag from GitHub in a clean Swift package and
builds a consumer target before publishing the release.
