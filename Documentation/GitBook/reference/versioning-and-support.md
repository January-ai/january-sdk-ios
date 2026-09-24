# Versioning and support

## Distribution

The SDK is released as versioned Swift Package Manager tags and as the `January` CocoaPods pod. Before 1.0, a minor release can include breaking changes, so allow patch updates only: **Up to Next Minor Version** in Xcode, or `~> 0.3.2` in CocoaPods ([Installation](../getting-started/installation.md)). Don't track `main`.

## Updating the SDK

When January publishes a release:

1. read the [changelog](changelog.md);
2. update the dependency on a branch;
3. run your consumer build and token provider tests ([Testing your integration](testing.md));
4. try the user flows you ship; and
5. release through your normal process.

## Support requests

Include:

* the SDK release you use;
* your Xcode, Swift, and iOS versions;
* the failing SDK call and the time it failed;
* the error's `category`, `code`, `httpStatus`, and `message`; and
* the smallest steps that reproduce it.

Never include API keys, client tokens, meal photos, health profiles, or complete food logs. Send the request to your January contact.
