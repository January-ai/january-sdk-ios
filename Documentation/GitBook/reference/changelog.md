# Changelog

Read [Versioning and support](versioning-and-support.md) before you update.

## 0.3.1 - 2026-09-23

* Food, water, and weight logs send and read the API's `created_at`; the Swift names `timestampUTC`, `consumedAtUTC`, and `measuredAtUTC` are unchanged. Food, water, and weight logs in 0.3.0 don't work with the current API, so upgrade to 0.3.1
* Water logs accept 0.1–101.4 cups (was 0.125–101.4), matching the API

## 0.3.0 - 2026-09-23

* Water and weight logs: `waterLogs.create`/`list`/`delete` and `weightLogs.create`/`list`, with daily values over a date range
* `ServingSummary.weightGrams` on detected and alternative foods
* `foodAnalysis.correct` sends the API's correction shape and validates hand-built detections; `foodLogs.update` rejects an empty update; `glucose.predict` requires a finite, whole-number `age`
* A non-retryable `JanuaryTokenProviderError` fails the request as an authentication error (`client_token_provider_failed`) with the provider's message, instead of a transport failure
* Breaking: `ServingOption.id`, `AlternativeFood.id`, and `LoggedFood.id` are no longer optional; the API always returns them
* A photo analysis without `reasoningEffort` uses the API's default, now the reasoning-based analyzer; pass `.none` for the standard analyzer
* A `409` `conflict` response is a `validation` error with the code `conflict`, and every API error keeps the API's `code` and `message`

## 0.2.0 - 2026-09-16

* Breaking: `DetectedFood` exposes `serving` and `quantity` instead of `servings`, matching the January API; 0.1.0 fails to decode photo analyses
* `SearchFoodsRequest` gains `offset` for paging and accepts `limit` up to 50
* Food-log summaries per day or week with `foodLogs.getSummary`
* Optional reasoning-based photo analysis with `ScanFoodPhotoRequest.reasoningEffort`

## 0.1.0 - 2026-09-03

* Native Swift 5.9 package for iOS 15 and later, distributed through Swift Package Manager and CocoaPods, with no third-party runtime dependencies
* One configured client with typed `async`/`await` APIs for foods, restaurants, food analysis, food logs, and glucose prediction
* Short-lived client-token providers with in-memory caching and single-flight refresh
* Nine-attempt bounded exponential backoff with jitter for retryable provider failures
* Stable `JanuaryError` categories
* Food autocomplete, full food details, and local portion calculations
* Restaurant menu-item search and paginated menu lookup by restaurant ID
* Single food-log retrieval, and deletion with no response body
* Typed imperial and metric height and weight values
* Native photo and barcode food scanner, and image-preparation helpers
* Microphone capture, live audio metering, and Apple Speech transcription
* SwiftUI example app
