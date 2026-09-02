# Versioning and support

## Distribution

The iOS SDK is distributed as versioned Swift Package Manager releases. Install
the latest release shown by Xcode as described on
[Installation](../getting-started/installation.md). Pin a release version for
production builds instead of tracking `main`.

## Updating the SDK

When January publishes a new release:

1. review the SDK and documentation changes;
2. update the pinned dependency in a branch;
3. run your consumer build and token-provider tests;
4. exercise the user flows you ship; and
5. promote the release through your normal release process.

## Support request

Include:

* installed SDK release;
* Xcode, Swift, and platform version;
* failing public operation;
* `JanuaryError.category`, `code`, `httpStatus`, and `requestID`; and
* minimal reproduction steps.

Never include server-side credentials, client tokens, meal photos, user health profiles, or complete food-log payloads. Use the support channel supplied by your January partner contact.
