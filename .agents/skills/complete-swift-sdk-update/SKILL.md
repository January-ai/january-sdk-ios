---
name: complete-swift-sdk-update
description: Complete a January Partner Swift SDK update after the contract automation generates or changes the internal transport. Use when finishing an automated contract PR, adding or changing a Partner API endpoint, creating a new public SDK domain/resource, repairing vocabulary-gate failures, updating public Swift models or async methods, or validating the SDK against the live development API.
---

# Complete Swift SDK Update

Finish the consumer-facing Swift SDK work that deterministic OpenAPI generation cannot decide. Treat `Contract/sdk-vocabulary.json` as the required public API vocabulary and the generated transport as immutable input.

## Load the repository guidance

Read both references completely before editing:

- [references/repository-contract.md](references/repository-contract.md) for ownership, layout, implementation patterns, and verification commands.
- [references/live-development-validation.md](references/live-development-validation.md) for credential handling and live API validation.

## Establish the update

1. Work from the `partner-sdk-ios` repository root.
2. Inspect `git status`, the live remote default branch, its latest commit date, and the current PR or branch before changing files.
3. Preserve unrelated and uncommitted work.
4. Inspect the contract-driven diff first:
   - `Contract/sdk-contract.lock.json`
   - `Contract/sdk-vocabulary.json`
   - `Sources/JanuaryPartnerTransport/Generated/`
5. Run `node scripts/check-public-api-vocabulary.mjs` once. Treat each diagnostic as required work, not an optional suggestion.
6. Compare changed vocabulary operations with neighboring public resources, models, tests, and documentation before designing anything new.

## Respect ownership boundaries

- Never hand-edit `Sources/JanuaryPartnerTransport/Generated/`.
- Never invent an operation, field, enum value, validation rule, header, retry rule, or server behavior absent from the locked contract or observed live response.
- Keep Partner API version 1.2 unless the contract lock explicitly changes it.
- Keep the public product API in `Sources/JanuarySDK/`; do not expose the generated transport target.
- Preserve native Swift structured concurrency. Every public network operation must be `async throws`, nonblocking, and free of callback-only alternatives.
- Keep credentials client-scoped. Do not add globals, singletons, hardcoded keys, committed `.env` files, or credential logging.

## Implement the public surface

For every new or changed vocabulary operation:

1. Use `resource`, `resourceType`, `publicMethod`, `publicInput`, and `publicResult` exactly as recorded in `Contract/sdk-vocabulary.json`.
2. Add the method to the matching domain resource. If the resource is new:
   - Create `Sources/JanuarySDK/<Domain>/`.
   - Create the public resource and its public models there.
   - Expose one immutable resource property from `JanuaryClient`.
3. Copy the closest existing domain pattern for request construction, generated response handling, error conversion, headers, and public model mapping.
4. Map the public method to the exact generated `operationId`.
5. Make public request, result, model, and identifier types `Sendable` where the surrounding API does.
6. Preserve wire optionality and output-enum forward compatibility using the existing repository patterns. Do not add speculative abstractions.
7. Update partner-facing DocC or README material only when the public usage changes. Do not expose internal generation or contract-maintenance details in product documentation.

## Add verification

1. Add the operation to `Tests/JanuarySDKTests/PublicSurfaceTests.swift` so the test calls the public method and observes the generated operation ID.
2. Add focused domain tests for request mapping, response decoding, error mapping, and any changed public behavior.
3. Add or update sanitized fixtures under the matching test domain when needed.
4. Update `JanuaryPartnerFullSmoke` so every new operation executes through `JanuaryClient`, validates meaningful response fields, and safely cleans up mutations.
5. Keep photo scanning coverage for both the committed base64 fixture and the governed image URL whenever photo input is affected.

## Verify once in this order

Run the existing repository checks, diagnosing only the first failing check before continuing:

```bash
./scripts/check-generated-transport.sh
node scripts/check-public-api-vocabulary.mjs
swift test --disable-automatic-resolution
xcodebuild \
  -scheme JanuarySDK \
  -destination 'generic/platform=iOS' \
  -configuration Release \
  -disableAutomaticPackageResolution \
  -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Then run the live development flow through the public SDK as specified in the live-validation reference. Do not substitute `curl` or manually constructed HTTP requests for SDK execution.

## Deliver the update

1. Inspect the final diff and confirm generator-owned files differ only because the repository generator produced them.
2. Report which vocabulary operations changed and which public files implement them.
3. Report each command actually run and its real result. Never claim an interrupted, skipped, or failed check passed.
4. Commit and push to the existing SDK update PR branch only when requested or already authorized by the task.
5. Do not merge, tag, publish, or run production live tests without explicit authorization.
6. Stop for review with any untested live behavior called out plainly.

The update is complete only when generation is deterministic, the vocabulary gate passes, public tests cover every contract operation, Swift tests pass, the iOS Release build passes, and every changed live operation has executed successfully through the public development SDK—or the exact external blocker is reported.
