# Releasing the iOS SDK

1. Record the release in `CHANGELOG.md` on `main`.
2. Create and push a SemVer tag without a `v` prefix, such as `0.2.0` or
   `0.2.0-beta.1`.

The release workflow accepts tags whose commits are contained in `main`'s history,
validates the Swift package manifest, runs the SDK coverage gate and complete
example-app UI suite, and creates the GitHub Release. Prerelease tags create
prerelease GitHub Releases. When the repository is public, the workflow also
resolves the exact tag from GitHub in a clean Swift package and builds a consumer
target before publishing the release.
