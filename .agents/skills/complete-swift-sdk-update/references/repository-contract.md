# Swift SDK repository contract

## Ownership

- `partner-api-contract` owns the verified OpenAPI source, resolved SDK vocabulary, fixtures, and release archive.
- `partner-sdk-ios` owns Swift generation, the generated transport output, the handwritten public API, Swift tests, and live SDK smoke programs.
- GitHub automation copies the release lock, regenerates the transport and vocabulary inside this repository, and opens a draft PR when those files change.
- The coding agent completes the public SDK work in that draft PR.

## Generated inputs

- `Contract/sdk-contract.lock.json`: immutable contract release identity and SHA-256.
- `Contract/sdk-vocabulary.json`: required domain/resource, public method, input, result, generated operation ID, and Swift symbol vocabulary.
- `Sources/JanuaryPartnerTransport/Generated/`: package-private Apple Swift OpenAPI Generator output.
- `scripts/generate-transport.sh`: the only supported generation entry point.
- `scripts/check-generated-transport.sh`: regenerates and fails on drift.

Do not edit generated files or vocabulary by hand. If they are wrong, correct the contract or generator and regenerate.

## Public implementation layout

- `Sources/JanuarySDK/Core/JanuaryClient.swift`: public client and immutable domain resources.
- `Sources/JanuarySDK/Core/`: identifiers, authentication middleware, user agent, shared nutrition, transport support, and public errors.
- `Sources/JanuarySDK/Foods/`
- `Sources/JanuarySDK/Restaurants/`
- `Sources/JanuarySDK/PhotoScanning/`
- `Sources/JanuarySDK/FoodLogs/`
- `Sources/JanuarySDK/Glucose/`
- `Tests/JanuarySDKTests/PublicSurfaceTests.swift`: contract-wide public-operation routing proof.
- `Tests/JanuarySDKTests/<Domain>/` or domain test files: focused public behavior tests.
- `Sources/JanuaryPartnerFullSmoke/JanuaryPartnerFullSmoke.swift`: live development execution through the public SDK.

Follow the closest resource and model files instead of introducing a new pattern. Keep the generated target package-private and the public product organized by domain.

## Required public behavior

- Use native `async throws` for network operations.
- Route calls through `JanuaryClient` domain resources.
- Construct the exact generated input and invoke the exact contract `operationId`.
- Convert successful generated outputs into stable public result models.
- Convert documented API and transport failures through the existing `JanuaryError` path.
- Pass governed end-user ID and timezone headers only where the contract requires them.
- Preserve `SDKUserAgent.current` and development authentication middleware behavior.
- Avoid automatic retries unless an existing governed policy explicitly permits them.

## Vocabulary gate diagnostics

`scripts/check-public-api-vocabulary.mjs` reports the required fix directly:

- `missing public resource`: create and expose the governed resource.
- `missing public method`: add the exact governed method name.
- `public method is not mapped`: invoke the exact generated operation ID.
- `missing public type`: add the governed request or result type.
- `JanuaryClient does not expose`: add the immutable resource property.
- `generated transport operation is missing`: regenerate or fix the upstream contract; do not fabricate it.
- `public surface test coverage is missing`: call it from `PublicSurfaceTests.swift` and record the operation ID.

## Verification boundary

The deterministic checks prove contract alignment, compilation, mapping, and fixture behavior. The full smoke program proves the deployed development server accepts the public SDK requests and returns usable responses. Neither result authorizes publishing or production testing.
