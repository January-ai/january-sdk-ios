# Overview

Add food search, food analysis, food, water, and weight logs, restaurant search, and glucose prediction to an iOS app, with native Swift models and `async`/`await` APIs.

## What you can build

* Food autocomplete, search, barcode lookup, and full food details with every serving
* Restaurant and menu-item search
* Food analysis of meal photos and descriptions, with corrections, plus a ready-made camera food scanner
* Food logs with daily or weekly summaries
* Water and weight logs with daily values
* Personalized glucose predictions

## Requirements

| Component | Requirement |
| --- | --- |
| Platform | iOS 15 or later |
| Build tools | Xcode 15 or later and Swift 5.9 or later |
| Runtime dependencies | None |
| Distribution | Swift Package Manager or CocoaPods |
| Production | A token endpoint on your backend that returns January client tokens |

## Start here

1. Create an API key and switch on **Enable client tokens** in the [January Developer Dashboard](https://dashboard.january.ai) ([API keys](https://docs.january.ai/docs/authentication#api-keys)).
2. [Install the SDK](getting-started/installation.md).
3. [Add a token endpoint to your backend](getting-started/backend-token-endpoint.md), or run the [token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay) while you develop.
4. [Write a token provider and create the client](getting-started/authentication.md).
5. [Make your first request](getting-started/quick-start.md).
6. Learn how [search, full food details, and portions](concepts/food-hydration-and-portions.md) fit together.

```swift
import Foundation
import January

let january = try JanuaryClient(
    endUserID: endUserID,
    timezone: TimeZone.current,
    clientTokenProvider: tokenProvider
)
let results = try await january.foods.search(.init(query: "greek yogurt"))
```

## SDK entry points

| API | Purpose |
| --- | --- |
| `JanuaryClient` | Holds authentication, the end-user ID, and the timezone, and exposes every resource |
| `foods` | Autocomplete, search, barcode lookup, full food details, and alternatives |
| `restaurants` | Nearby restaurants, menu-item search, and a restaurant's menu by ID |
| `foodAnalysis` | Food analysis of a photo or description, and corrections |
| `foodLogs` | Create, list, summarize, get, update, and delete food logs |
| `waterLogs` | Log water and list daily totals |
| `weightLogs` | Log weight and list each day's latest weight |
| `glucose` | Personalized glucose prediction |
| `JanuaryFoodScannerView` | Ready-made camera food scanner for meal photos and barcodes |
| `VoiceCaptureSession` | Records speech and transcribes it on the device; makes no January call |
| `JanuaryError` | Error category, code, message, and HTTP status |

## Security boundary

The app never holds your API key. It gets short-lived client tokens from your backend, and each token acts for one end user. See [Authentication](getting-started/authentication.md).
