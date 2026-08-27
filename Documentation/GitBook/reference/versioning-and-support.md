# Versioning and support

## Current distribution status

The iOS SDK is in **Controlled Preview**:

* repository visibility: private;
* default branch: `main`;
* semantic-version tags: none; and
* public GitHub release: none.

Install only the pinned revision on the [Installation](../getting-started/installation.md) page. Do not use a fictitious `from:` version or assume `main` is stable.

## Updating a preview revision

When January supplies a new revision:

1. review the SDK and documentation changes;
2. update the pinned dependency in a branch;
3. run your consumer build and token-provider tests;
4. exercise the user flows you ship; and
5. promote the revision through your normal release process.

## Future public release

Public installation instructions become valid only after the repository is publicly readable and a semantic-version tag exists. At that point January should publish release notes, compatibility expectations, and a version-based SwiftPM declaration together.

## Support request

Include:

* pinned SDK revision;
* Xcode, Swift, and platform version;
* failing public operation;
* `JanuaryError.category`, `code`, `httpStatus`, and `requestID`; and
* minimal reproduction steps.

Never include server-side credentials, client tokens, meal photos, user health profiles, or complete food-log payloads. Use the support channel supplied by your January partner contact.
