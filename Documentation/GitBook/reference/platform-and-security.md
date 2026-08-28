# Platform and security

## Availability

| Capability | iOS 15+ |
| --- | --- |
| Core client and all API resources | Yes |
| `PhotoScanImage` preparation | Yes |
| `JanuaryMealScannerView` | Yes |
| `JanuaryMealScanner.makeViewController` | Yes |

The repository demo uses the latest tab-bar APIs and targets iOS 26 independently of the SDK deployment target.

The SDK supports iOS 15 and later only. It does not support macOS, Mac Catalyst,
tvOS, watchOS, or visionOS.

## Credential handling

* Keep January's server-side token-issuance credentials outside the app and SDK integration.
* Keep client tokens in memory and out of logs and persistent storage.
* Inject the partner-backend URL; do not ship a fallback endpoint.
* Authenticate the app to the partner backend with the app's existing session.
* Rebuild the client when the signed-in app account changes.

## User and health data

Meal images, food logs, glucose profiles, CGM readings, and predictions may be sensitive. Minimize collection and retention, obtain the permissions appropriate to your product, and exclude these values from general-purpose analytics and crash reports.

Use partner-owned opaque IDs rather than email addresses or names. Client tokens already carry the January end-user identity.

## Camera privacy

The iOS native scanner requires `NSCameraUsageDescription`. Present a clear purpose string that matches the actual feature. Do not request camera permission before the user initiates scanning.
