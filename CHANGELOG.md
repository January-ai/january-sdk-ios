# Changelog

All notable changes to the January SDK for iOS are documented here. This project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Added `waterLogs` (`create`, `list`, `delete`) and `weightLogs` (`create`,
  `list`) for water intake and body-weight logging, with daily totals over a
  date range. New models: `VolumeUnit`, `WaterAmount`, `Volume`, `WaterLog`,
  `DailyWaterTotal`, `WeightLog`, `DailyWeight`. Water is logged and totalled
  in fluid ounces, milliliters, or cups (`VolumeUnit.cups`, 0.125–101.4 per log).
- `ServingSummary` gains `weightGrams`, the weight of one catalog serving when
  the API reports it.
- `foodAnalysis.correct` sends the prior scan in the API's correction shape and
  rejects a hand-built detection that lacks its food ID, serving ID, serving
  quantity, or quantity before transport.
- `foodLogs.update` rejects an update that changes no field before transport,
  matching the API.
- `glucose.predict` rejects a fractional or non-finite `age` before transport;
  the API takes whole years.
- A token provider that throws `JanuaryTokenProviderError` with
  `retryable: false` now fails the request with an authentication error
  (`client_token_provider_failed`) carrying the provider's message. It was
  reported as a transport failure ("The request to the January API failed."),
  although no API request was made.
- The demo app adds a Tracking tab: a per-day view of the day's food logs
  with their nutrient totals, the day's water total (in fl oz, ml, or cups),
  and the day's weight.
- Regenerated the internal transport from contract release 1.2.0: water and
  weight logs, the correction request shape, `weight_grams` on logged servings,
  and the `water_logs:*` and `weight_logs:*` client-token scopes.

## [0.2.0] - 2026-09-16

- `SearchFoodsRequest` gains `offset` for paging and accepts `limit` up to 50,
  matching the API.

Breaking: the Partner API changed the shape of a detected food, and `0.1.0`
clients fail to decode photo scans and description analyses with a decoding
error. Update to this version to restore them.

- `DetectedFood` no longer has `servings`. It has `serving` (the selected
  catalog serving, a `ServingSummary`) and `quantity` (how many of that serving
  were eaten). `nutrients` are already scaled to `quantity`. `DetectedServing`
  is a deprecated alias of `ServingSummary`; its `selectedQuantity` moved to
  `DetectedFood.quantity`.
- Food alternatives are `AlternativeFood` values with `servings:
  [ServingSummary]`. `FoodAlternative` remains as an alias.
- Added `foodLogs.getSummary`: nutrients summed per day or week over a date
  range, with totals and a per-logged-day average (`FoodLogSummary`).
- Added `ScanFoodPhotoRequest.reasoningEffort` (`AnalysisEffort.xhigh`) to opt
  into the reasoning-based photo analyzer.
- Regenerated the internal transport from contract release 1.2.0
  (`searchFoods` paging, new error codes). The user agent now reports the
  released SDK version.

## [0.1.0] - 2026-09-03

- Promote the complete iOS SDK, CocoaPods packages, Swift Package Manager
  distribution, and demo app from beta to the first stable release.

## [0.1.0-beta.2] - 2026-09-03

- Add reusable microphone capture, live audio metering, and Apple Speech
  transcription through `VoiceCaptureSession`.
- Add the initial Swift Package Manager distribution for iOS 15 and later.
- Support Swift 5.9 and Xcode 15 with no third-party runtime dependencies.
- Distribute the SDK under the Apache License 2.0.
- Add short-lived client-token authentication with proactive refresh,
  single-flight coordination, and bounded exponential-backoff retries.
- Add a deprecated local-only development provider for exercising the complete
  client-token lifecycle without a partner backend.
- Support an optional end-user ID on `JanuaryClient`, default an omitted
  timezone to `TimeZone.current`, and reuse that context across
  every SDK resource.
- Add food discovery and hydration, restaurant search, native meal scanning,
  food logs, and glucose prediction resources.
- Add the example iOS app and integration documentation.
- Add typed, paginated restaurant-menu lookup by restaurant ID. The backend
  route remains deployment-gated during Controlled Preview.
