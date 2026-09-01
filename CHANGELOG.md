# Changelog

All notable changes to the January SDK for iOS are documented here. This project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
