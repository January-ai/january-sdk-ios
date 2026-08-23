# ``JanuaryPartnerSDK``

Build food and metabolic intelligence into Swift applications with native
Swift concurrency.

## Overview

Create a development client with a runtime-injected key, then call resource
methods with `async`/`await`:

```swift
let client = try JanuaryPartnerClient(developmentAPIKey: developmentAPIKey)
let foods = try await client.foods.search(
    SearchFoodsRequest(query: "banana")
)
```

The current package is private and intended for non-distributable development
integration only. Never embed a January bearer key in an application binary.

The public API is handwritten and grouped into resource domains. The generated
OpenAPI transport is package-private and cannot be imported by SDK consumers.
