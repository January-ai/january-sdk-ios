# Changelog

See [Versioning and support](versioning-and-support.md) before installing or updating.

## Unreleased

* Water and weight logs: `waterLogs.create`/`list`/`delete` and `weightLogs.create`/`list`, with daily totals over a date range
* `ServingSummary.weightGrams` on detected and alternative foods
* `foodAnalysis.correct` sends the API's correction shape and validates hand-built detections; `foodLogs.update` rejects an empty update; `glucose.predict` requires a whole-number `age`
* A non-retryable `JanuaryTokenProviderError` fails the request as an authentication error (`client_token_provider_failed`) with the provider's message, instead of a transport failure

* Breaking: `DetectedFood` exposes `serving` and `quantity` instead of `servings`, matching the current Partner API; `0.1.0` fails to decode photo scans
* Food-log summaries per day or week with `foodLogs.getSummary`
* Optional reasoning-based photo analysis with `ScanFoodPhotoRequest.reasoningEffort`
* Reusable microphone capture, live audio metering, and Apple Speech transcription
* Native Swift 5.9 package for iOS 15+
* No third-party runtime dependencies
* Typed `async`/`await` resource APIs
* Food, restaurant, photo-scanning, food-log, and glucose-prediction coverage
* Stable `JanuaryError` categories and request metadata
* SwiftUI example application for development integration
* Short-lived client-token providers with in-memory caching and single-flight refresh
* Nine-attempt bounded exponential backoff with jitter for explicitly retryable provider failures
* One configured client covering foods, restaurants, photo scanning, Food Logs, and glucose
* Food autocomplete, full-food hydration, and local portion calculations
* Native photo/barcode scanner and image-preparation helpers
* Typed imperial and metric height and weight values
* Restaurant-menu lookup by restaurant ID

Use the latest release documented on [Installation](../getting-started/installation.md) and review changes before updating.
