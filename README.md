# January Partner SDK for Swift

Private Swift 6 SDK for all 13 operations in the January Partner API v1.2.
Every public network operation uses native `async`/`await`.

## Requirements

- Swift 6.1 or newer
- iOS 16 or newer
- macOS 13 or newer

## Add the package locally

In Xcode, add this repository as a local package and import the single library
product:

```swift
import JanuaryPartnerSDK
```

Create a development-only client and search foods:

```swift
let client = try JanuaryPartnerClient(developmentAPIKey: developmentAPIKey)

let results = try await client.foods.search(
    SearchFoodsRequest(
        query: "banana",
        category: .branded,
        endUserID: PartnerUserID(rawValue: partnerUserID)
    )
)
```

The package does not provide a production mobile authentication flow yet.
Never commit or embed the development bearer key in an application, example,
test fixture, or distributed binary.

## Verify

```sh
swift test --disable-automatic-resolution
./scripts/check-generated-transport.sh
```

The tests use two domain-scoped fixtures under
`Tests/JanuaryPartnerSDKTests/Fixtures/Foods` and require no credentials.

To run the read-only development smoke test, inject a development key and a
synthetic end-user ID through the process environment:

```sh
JANUARY_API_KEY='<development-key>' \
JANUARY_END_USER_ID='<synthetic-user-id>' \
swift run JanuaryPartnerSmoke
```

The command never prints the key or end-user ID.

## Contract provenance

`Contract/sdk-contract.lock.json` pins contract release `1.2.0`, source commit
`7f40d0fd07857058b11f805c16b4aa7d5846c9de`, and archive SHA-256
`959ab95b4a95218fd4e3948ac0841748ec81534eb1c4476c8165920e94a3e361`.

The SDK repository keeps only this lock, not a second copy of the OpenAPI
contract or its complete fixture set. Generation reads the verified archive
from an adjacent `partner-api-contract` checkout when available, or downloads
the pinned private artifact with an authenticated GitHub CLI session.

Generated transport types use Swift `package` visibility in the non-product
`JanuaryPartnerTransport` target. Regenerate them with:

```sh
./scripts/generate-transport.sh
```

You may also provide the archive explicitly with `JANUARY_CONTRACT_ARCHIVE`.
Do not edit files under `Sources/JanuaryPartnerTransport/Generated` by hand.

## Source layout

```text
Sources/
├── JanuaryPartnerSDK/
│   ├── Core/
│   ├── Foods/
│   ├── Restaurants/
│   ├── PhotoScanning/
│   ├── FoodLogs/
│   ├── Glucose/
│   └── JanuaryPartnerSDK.docc/
├── JanuaryPartnerTransport/
│   └── Generated/
└── JanuaryPartnerSmoke/
```

`JanuaryPartnerSDK` contains the handwritten consumer API organized by domain.
`JanuaryPartnerTransport` contains the two large generator-owned files; it is
an implementation target and is not exposed as a package product.

## Current scope

- The public client covers all 13 Partner API v1.2 operations across Foods,
  Restaurants, Photo Scanning, Food Logs, and Glucose.
- The SwiftUI demo remains a separate next step.
