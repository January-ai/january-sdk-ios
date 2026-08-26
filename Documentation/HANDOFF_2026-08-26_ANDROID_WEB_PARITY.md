# January Partner SDK and demo parity handoff — iOS to Android and web

Date: 2026-08-26

## Purpose

This handoff explains the iOS SDK and demo work completed in commit `a7005f7e0b1c5ebff95e20d37fb59414e0cefa78`, why the implementation was decomposed into small components, how it was validated, what is still not fully verified, and how to reproduce the same product structure in the Android SDK/demo and Node SDK/React demo.

The goal is behavioral and product parity, not a literal translation of SwiftUI. Android should use native Kotlin/Compose/CameraX patterns already established in its repository. Web should use the existing TypeScript/React patterns and browser primitives. The iOS implementation is the reference for interaction hierarchy, data flow, naming, loading behavior, image containment, and user-context ergonomics.

## Source-of-truth repositories

- iOS SDK and demo: `/Users/orenzitoun/Documents/github/partner-sdk-ios`
- Android SDK and demo: `/Users/orenzitoun/Documents/github/partner-sdk-android`
- Node SDK and React demo: `/Users/orenzitoun/Documents/github/partner-sdk-node`
- API contract: `/Users/orenzitoun/Documents/github/partner-api-contract`
- Original iOS camera/UI reference: `/Users/orenzitoun/Documents/github/ios-january`

Contract rollout details remain in:

`/Users/orenzitoun/Documents/github/partner-api-contract/docs/SDK_ROLLOUT_RUNBOOK.md`

## Repository state at handoff

### iOS

- Branch: `main`
- HEAD and `origin/main`: `a7005f7 feat: expand iOS SDK and demo flows`
- Working tree was clean before this handoff file was created.
- This handoff file itself is intentionally uncommitted unless the user asks to commit it.
- The hardcoded development key was removed before the commit. `JanuaryPartnerDemoApp.swift` now contains a non-secret development placeholder. Do not restore or commit a real Partner API key.

### Android

- Branch: `main`
- HEAD: `03535c670d97dd31c23321ab9327fa154def35e3`
- Dirty files that must be preserved and inspected before editing:
  - `demo/src/main/AndroidManifest.xml`
  - `demo/src/main/java/ai/january/partner/demo/DemoTheme.kt`
  - `demo/src/main/java/ai/january/partner/demo/ScanScreen.kt`
  - `sdk/build.gradle.kts`
  - `sdk/src/main/kotlin/ai/january/partner/photos/PhotoModels.kt`
  - untracked `sdk/src/main/kotlin/ai/january/partner/photos/PhotoScanImage.kt`

### Node and React web demo

- Branch: `main`
- HEAD: `ad22674c73aa34da9c663dc9f5a49afe60ba4b16`
- Dirty files that must be preserved and inspected before editing:
  - `examples/react-demo/src/routes/scan.tsx`
  - untracked `examples/react-demo/src/lib/photo-scan-image.ts`

### Contract

- Branch: `main`
- HEAD: `015826175bf005be6bc6062d0b016124e1a4ce23`
- Clean at handoff.
- Partner API remains v1.2.

Do not reset, clean, discard, clone, or create replacement worktrees in any repository. The Android and web dirty trees contain the beginnings of the image work and are the first implementation references to inspect.

## Product principles established on iOS

1. Keep the public SDK ergonomic and handwritten. Generated OpenAPI transport remains internal.
2. The integrating app owns authenticated user identity. The SDK accepts and reuses context but does not persist it.
3. Keep the scanner in the existing SDK product/artifact where practical. Do not invent a second SDK product solely for UI without first proving the platform requires it.
4. Use native asynchronous and lifecycle primitives for each platform.
5. Treat loading, empty, cached, refreshing, success, and failure as distinct UI states.
6. Show a full loading state only when no usable data exists. If cached data exists, keep it visible while refreshing.
7. Use one visual spinner everywhere in the demo. Do not mix default platform spinners with the design-system spinner.
8. Make the primary action obvious. Put secondary and developer-only inputs below it.
9. A result shown as a modal must be a real modal/sheet with correct dismissal semantics.
10. A container establishes image bounds before the image is rendered inside it. Never let a landscape image's intrinsic width size the parent.
11. Prefer native layout primitives. Avoid custom measurement/layout code when a row, column, grid, aspect ratio, crop, or overflow clip solves the problem.
12. Shared UI lives in small files with a focused API and a preview/story/example. Feature screens compose those pieces instead of redefining them.
13. Component names describe the product role and are not prefixed with `Demo`.
14. Technical API terminology must be translated into user-facing copy. For example, a detection pill says `High confidence`, not only `High`.

## SDK work completed on iOS

### User-scoped client

Files:

- `Sources/JanuaryPartnerSDK/Core/PartnerUserContext.swift`
- `Sources/JanuaryPartnerSDK/Core/JanuaryPartnerUserClient.swift`

`PartnerUserContext` holds the partner-owned `endUserID` and optional timezone. `JanuaryPartnerClient.forUser(...)` returns a lightweight scoped client that reuses the underlying transport and automatically applies this identity to Food Logs and Glucose requests.

The important boundary is deliberate:

- The app persists the active account ID and timezone.
- The SDK does not persist identity.
- The SDK reduces repetitive request wiring and prevents identity mismatches.
- Changing or signing out the active account means replacing or clearing the app-owned context.

Equivalent target APIs should feel natural on each platform while retaining these semantics:

```text
context = PartnerUserContext(endUserID, timezone)
userClient = client.forUser(context)
userClient.foodLogs.list(start, end)
userClient.glucose.predict(request)
```

Food Logs supports multiple foods in one log. Create and update accept an array/list of food selections. The demo builds the complete meal locally, lets the user choose a serving and quantity for each food, and submits the array once.

### Arbitrary food-log dates and ranges

Food-log create/update accepts an optional UTC timestamp. Listing accepts inclusive `start` and `end` calendar dates in `yyyy-MM-dd` format.

The iOS demo added app-level helpers rather than pushing presentation concepts into the SDK:

- `today`: one local calendar day
- `currentWeek`: Sunday through Saturday
- `lastMonth`: the previous complete calendar month

Files:

- `Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/Core/FoodLogTimeSpan.swift`
- `Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/FoodLogs/FoodLogTimeSpanPicker.swift`
- `scripts/test-food-log-time-span.swift`

Android and web should implement the same enum and range semantics in their demo layer. Make timezone/calendar behavior explicit and test dates at month/year boundaries. Do not interpret `lastMonth` as the trailing 30 days.

### Photo preprocessing

Files:

- `Sources/JanuaryPartnerSDK/PhotoScanning/PhotoScanImage.swift`
- `Sources/JanuaryPartnerSDK/PhotoScanning/PhotoScanningModels.swift`

`PhotoScanImage` normalizes orientation, preserves aspect ratio, constrains the longest dimension to 1,000 pixels by default, encodes JPEG at 0.7 quality by default, and can produce the data URI accepted by the scan endpoint.

Android parity should normalize EXIF orientation, downsample before allocating a large bitmap where possible, preserve aspect ratio, JPEG-compress, and test pixel bounds and MIME/data-URI output.

Web parity should expose a browser-safe helper around `File`/`Blob`/`ImageBitmap` or the repository's existing abstraction. It should constrain the longest dimension, preserve orientation where browser APIs expose it, JPEG-compress, and return upload-ready data without coupling the SDK core to React.

### Ready-to-use meal scanner

Files:

- `Sources/JanuaryPartnerSDK/PhotoScanning/JanuaryMealScanner.swift`
- `Sources/JanuaryPartnerSDK/PhotoScanning/MealCameraViewController.swift`
- `Sources/JanuaryPartnerSDK/PhotoScanning/ScannerLoadingSpinner.swift`

The existing `JanuaryPartnerSDK` product includes a scanner with Photo and Barcode modes. It validates host configuration, handles camera authorization, presents denial/restriction recovery, opens host-app Settings, captures a photo, preprocesses it, calls meal analysis, detects barcodes, performs barcode lookup, fetches full food details, and returns a typed result.

The public result distinguishes:

- analyzed meal plus the exact processed image sent to January
- barcode value plus the complete matching food record

UIKit and SwiftUI entry points wrap the same implementation.

AVFoundation work is serialized on a dedicated session queue. Configuration, start, stop, photo capture, and torch work are not run concurrently. The controller observes session interruption, interruption-ended, runtime-error, foreground, and background events. Do not repeatedly call `startRunning()` while interrupted.

Android should reproduce the behavior with CameraX and lifecycle-aware analysis/capture, not a line-by-line port of AVFoundation. Web should provide equivalent photo input and analysis orchestration; live barcode support should use supported browser primitives with a tested fallback rather than assuming `BarcodeDetector` exists everywhere.

### Model and contract coverage

Photo-scan models now include detection confidence and glucose-impact data. `FoodScan` is the preferred name; the old `PhotoScan` remains a deprecated alias. Public contract tests cover user-scoped identity, food-log request shapes, photo scanning, and generated vocabulary projection.

Generation tooling was tightened so reserved/incomplete operations cannot silently appear in the public SDK vocabulary:

- `scripts/build-sdk-vocabulary.mjs`
- `scripts/test-sdk-vocabulary-projection.mjs`
- `scripts/generate-transport.sh`

Apply equivalent contract-vocabulary checks in Android and Node instead of manually drifting public names from the v1.2 contract.

## Demo application architecture

The original demo concentrated most shared UI in a single `DemoComponents.swift`. That made small changes risky, encouraged feature screens to diverge, hid component boundaries, and made previews difficult to maintain. It was deleted.

The replacement uses:

- one reusable component per file
- narrow inputs and no feature-owned network state inside visual components
- native controls under a styling wrapper where possible
- a useful preview for each visual component
- feature-specific components beside their feature when they are not broadly reusable
- centralized tokens for color, spacing, radius, typography, and formatting

This is the structure to port, not necessarily the exact component names or file counts.

### Shared design-system components

All are under `Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/DesignSystem`.

| Component | Responsibility and reason for extraction |
| --- | --- |
| `AppFoundations` | Central colors, typography, spacing, radii, formatting, and small shared value types. Prevents visual constants and date/user normalization from drifting. |
| `AppNavigationBar` | Central native navigation title behavior with centered and leading variants. Keeps native navigation semantics while making every screen consistent. |
| `AppNavigationButton` | Shared back, close, cancel, done, add, edit, and settings actions with consistent icons, tint, labels, and accessibility. |
| `CardStyle` | Reusable surface, padding, border, radius, and shadow treatment through `appCard`/`appBackground`. |
| `ChipButtonStyle` | Selectable filter/preference chips with one pressed/selected treatment. |
| `EmptyStateCard` | Empty/error onboarding card with icon, title, explanation, and optional action context. Fixes unexplained placeholder glyphs and inconsistent blank states. |
| `ErrorNotice` | Consistent recoverable error presentation and retry action. |
| `FoodRow` | Common food identity row that composes image, name, subtitle, and disclosure without duplicating row spacing. |
| `LoadingSpinner` | Branded spinner used across root, lists, buttons, and requests. Removes mixed default spinners. |
| `MacroGrid` | Native 2×2 nutrient grid with four explicit 64-point cells. It wraps content instead of filling parent height. |
| `NetworkImage` | A clean URL-or-placeholder wrapper around asynchronous image loading. Feature code provides only the URL, placeholder, and content mode. |
| `NutritionList` | Reusable labeled nutrient rows and dividers. |
| `OutlinedButtonStyle` | Tertiary action style for less prominent choices. |
| `PredictionChart` | Owns glucose chart drawing, bounds, summary, peak annotation, timeline, and legend. Extracted because chart label collisions require one coordinated layout. |
| `PrimaryButton` | Main CTA with pressed feedback, disabled state, and branded loading state. Loading replaces the label but retains the enabled black surface and blocks duplicate taps. |
| `QuantityButtonStyle` | Compact plus/minus controls sized so the quantity value remains on one line. |
| `ScreenShell` | Shared horizontal screen inset and leading alignment. Prevents each screen from inventing margins. |
| `SearchField` | Search icon, text input, prompt styling, and field surface. |
| `SecondaryButtonStyle` | Secondary filled action hierarchy. |
| `SectionLabel` | Consistent uppercase eyebrow/section labeling. |
| `SegmentedControl` | Thin wrapper around the native iOS segmented `Picker`. This restored native selection behavior and animation instead of simulating a segment with ordinary buttons. |
| `WorkflowGuideCard` | Explains multi-step SDK workflows in plain language with numbered steps. Used where the user must understand identity, food selection, and prediction inputs. |

There are no custom SwiftUI `Layout` implementations left. `FillWidth` and `EqualColumns` were removed because they accepted unbounded parent proposals and caused components to consume unexpected height or width. Native `HStack`, `LazyVGrid`, normal frames, and clipping were sufficient.

### Feature-specific reusable pieces

| Component | Why it exists |
| --- | --- |
| `FoodLogTimeSpanPicker` | Keeps time-span selection and the resolved date range together so the API query is understandable. |
| `FoodLogUserCard` | Makes the required stable user ID explicit, supports initial setup, shows the active user/timezone, and links to Settings. |
| `ScanPhotoInstructions` | Replaces a large fake image placeholder with concise instructions. The empty state now explains what January does without pretending an image exists. |
| `ScanImagePreview` | Establishes a fixed 240-point container before rendering/clipping the image. This prevents landscape images from widening beyond screen bounds. |
| `RestaurantDetailViewModel` | Retains loaded menu items across navigation, loads once when needed, prevents duplicate loads, and shows full loading only when there is no cached data. |

### Core and shell structure

| Type | Role |
| --- | --- |
| `AppModel` | Bootstraps authentication once and owns the SDK client plus app user session. |
| `UserSession` | Persists partner user ID and timezone in app storage and creates `PartnerUserContext`/scoped clients. Production apps should source this from their authenticated account session. |
| `LocationProvider` | Owns location access/state instead of embedding it in search views. |
| `RootView` | Renders connecting, ready, and failed states using the shared spinner/empty state. |
| `AppTabView` | Owns Search, Scan, Food Logs, Glucose, and the shared Settings presentation. |
| `SettingsView` | Central place to inspect connection mode and edit the demo's reusable user ID/timezone. |

## Feature flows and UX decisions

### Search and restaurants

- Food/restaurant and name/description/barcode selectors use the native segmented control.
- Search filters are a designed sheet rather than a raw system form.
- Empty search states use a clear icon, title, explanation, and action.
- Rows use `NetworkImage`; failed/missing URLs fall back to an explicit food placeholder.
- Food details use a bounded, clipped image area. Missing images show only the placeholder inside the same box.
- Food details expose `Check glucose` and `Find alternatives` as explicit actions.
- Alternatives are a real modal flow with reusable rows, bounded images, readable macro layout, and refresh behavior.
- Restaurant menu data stays in `RestaurantDetailViewModel`. Navigating to a menu item and back does not blank the restaurant or show an initial loader again.
- A background refresh may occur while cached menu items remain visible.
- Menu items expose glucose impact from their detail view.

### Food Logs

- The screen first explains that one log represents one meal and can contain multiple foods.
- A stable partner-owned user ID is required and persisted by the demo.
- The current user and timezone are visible before list/create operations.
- Creating/editing builds an array of foods, each with serving and quantity, then saves once.
- The segmented span selector maps to Today, This week (Sunday–Saturday), and Last month (previous calendar month).
- API query dates and display dates are derived from the same range object.
- The list keeps usable data visible while refreshing and shows the branded loader only when there are no rows yet.

### Glucose

- A workflow guide explains how the profile, historical/selected food inputs, and prediction relate.
- The same persisted user context is reused so Food Logs and Glucose cannot accidentally target different demo users.
- Health/profile inputs are visually separated from foods being tested.
- Prediction results use the shared chart and explicit `Low impact`, `Medium impact`, or `High impact` language.

### Scan

- Empty state is compact and instruction-led, not a large faux photo frame.
- `Take photo` is primary; `Choose from library` is secondary.
- Sample meal and image URL are grouped under `Other ways`.
- Once an image exists, the UI shows only a fixed-height clipped preview, `Change photo`, `Remove`, and `Analyze meal`.
- The analysis result is a real modal sheet with a close action.
- Detected food confidence reads `High confidence`, `Medium confidence`, or `Low confidence`.
- Results use shared macro, nutrition, prediction, image, navigation, loading, and error components.
- The final landscape-image fix changed the preview from a size-participating stack to a parent-sized shape with image content overlaid and clipped. This detail matters on every platform.

Cross-platform image equivalent:

- Android Compose: parent `fillMaxWidth`, fixed height, clip first, child image with `ContentScale.Crop`.
- Web: parent `width: 100%`, fixed/min responsive height, `overflow: hidden`, rounded corners; image `width: 100%`, `height: 100%`, `object-fit: cover`, `display: block`.

## Validation performed

### Local SDK and build validation

- Contract/public-surface tests cover food logs, glucose, user-scoped clients, photo preprocessing, error mapping, and public resource operations.
- The package test run represented in CI executed 38 tests successfully.
- `scripts/test-food-log-time-span.swift` verifies:
  - Today on 2026-08-25 → `2026-08-25...2026-08-25`
  - This week → `2026-08-23...2026-08-29`
  - Last month → `2026-07-01...2026-07-31`
- The live full-smoke date mode created and queried food logs across day, week, month, and year ranges using a scoped user client. It uses explicit UTC timestamps and verifies returned IDs. It does not delete those date-smoke records, so repeated runs create additional records.
- The final demo simulator build after the image-bound fix succeeded with normal Xcode DerivedData.
- `git diff --check`, project-file linting, obsolete-layout reference searches, and the staged secret check were run during the work.

### Real-app visual validation

The demo was installed and launched on the actual iPhone Air simulator build. Flows were exercised with the app, not only SwiftUI previews. Maestro was used when Simulator accessibility did not expose tappable app elements.

Committed evidence under `Documentation`:

| Screenshot | What it validates |
| --- | --- |
| `native-segmented-control-simulator.png` | Native segmented picker styling and behavior. |
| `macro-grid-simulator.png` | 2×2 macro grid wraps its two explicit rows. |
| `network-image-simulator.png` | URL/placeholder image component in a real row. |
| `prediction-chart-layout-fixed.png` | Summary and peak labels no longer overlap. |
| `empty-state-fixed.png` | Empty-state placeholder and copy are intentional. |
| `designed-search-filters.png` | Search filter sheet design. |
| `navigation-root-large-title.png` | Root leading/large navigation variant. |
| `navigation-centered-text-action.png` | Centered title with text action. |
| `navigation-modal-centered.png` | Modal centered navigation. |
| `navigation-pushed-leading-title.png` | Pushed screen navigation treatment. |
| `food-detail-image-bounds.png` | Food image/missing image stays inside its box. |
| `scan-input-image-contained.png` | Scan input is clipped to the intended container. |
| `scan-result-modal.png` | Analysis is presented as a modal result. |
| `scan-empty-state-redesign.png` | Compact scan instructions and action hierarchy. |
| `scan-selected-image-redesign.png` | Final landscape image stays inside both horizontal screen insets. |
| `food-logs-guided-setup.png` | User identity and multi-food log explanation. |
| `food-log-time-span-segments.jpg` | Today/week/month selector and resolved dates. |
| `food-log-different-dates.jpg` | Logs created on distinct dates. |
| `user-session-persisted-food-logs.png` | Persisted user reused by Food Logs. |
| `user-session-reused-glucose.png` | Same user context reused by Glucose. |
| `glucose-guided-prediction.png` | Profile/food/prediction workflow explanation. |

### Camera validation status

Earlier physical-device work reached photo selection, barcode detection, barcode lookup, and food-detail presentation. The final source contains the serialized session runner and interruption handling. However, the complete final commit was not re-signed off across every physical-device case after all UI edits.

Treat these as required release checks, not completed assumptions:

- first camera permission grant
- denied/restricted permission and Settings recovery
- background/foreground interruption
- Photo mode capture, compression, upload, success, retry, and cancellation
- Barcode mode detection, lookup, full-food fetch, no-match, retry, and cancellation
- torch availability and state
- rotation/orientation and landscape source images
- VoiceOver/TalkBack/keyboard accessibility where supported

Android must run these on a physical Android device. Browser camera and file flows must be verified in at least Chrome and Safari, with mobile viewport/device coverage.

## Known blocker: iOS CI is currently red

GitHub Actions run:

`https://github.com/January-ai/partner-sdk-ios/actions/runs/32918251513`

Status for commit `a7005f7`: failed.

What passed in CI:

- secret scan
- SDK vocabulary projection
- public vocabulary check: 15 operations
- all 38 Swift tests

What failed:

- `Run package tests with 100% handwritten SDK coverage`

The repository enforces 100% line and region coverage for handwritten SDK code. The new user-client, photo-image, and scanner-related code lowered measured macOS package coverage. The iOS SDK and demo release builds were skipped after that failure.

Do not describe iOS as fully green until this is fixed. Resolve it in a focused iOS follow-up by either adding meaningful tests and correctly excluding platform UI that cannot execute in the macOS test job, or changing the coverage boundary only if that reflects an explicit policy decision. Do not merely lower the threshold to hide the gap.

Also reconcile two documentation drifts during that follow-up:

- `Package.swift` declares iOS 15, while `README.md` currently says iOS 16.
- The scanner README says the processed image is square; `PhotoScanImage` actually preserves aspect ratio, while the demo presentation crops into a bounded preview.

## Android parity plan

Work in `/Users/orenzitoun/Documents/github/partner-sdk-android` and preserve its six existing dirty changes.

1. Read the Android repository instructions and inspect every dirty diff before editing.
2. Compare the public Kotlin API against the v1.2 contract and the iOS behavior matrix.
3. Finish and test `PhotoScanImage.kt` first; reuse the dirty implementation where sound.
4. Add app-owned user-context ergonomics equivalent to `PartnerUserContext` and `client.forUser(...)` without storing identity in the SDK.
5. Verify Food Logs create/update accepts multiple selections and arbitrary UTC timestamps; verify inclusive list ranges.
6. Add Android demo date helpers with Today, This week Sunday–Saturday, and Last month calendar semantics.
7. Build a lifecycle-safe CameraX photo/barcode scanner using the existing SDK artifact and existing project conventions. Serialize operations through CameraX/lifecycle primitives rather than porting AVFoundation queues.
8. Split the demo design system into small Compose components with previews. Preserve the responsibilities in the component table, but use Material/native Android semantics.
9. Implement Search, Scan, Food Logs, and Glucose guidance and state behavior.
10. Ensure image parents determine bounds before `Image` content; test landscape and portrait images.
11. Unit-test SDK behavior, date boundaries, image processing, user scoping, and request shapes once.
12. Run the actual demo, inspect primary flows, capture screenshots, and verify physical-device Photo and Barcode flows.
13. Stop for review before committing or pushing unless explicitly asked.

Android design cautions:

- Do not create one giant `DemoComponents.kt`.
- Do not duplicate tokens or buttons in each screen.
- Hoist screen state into view models where it must survive navigation.
- Retain cached data during refresh.
- Use native segmented/tab patterns with correct semantics and animation.
- Use one branded progress indicator.
- Keep camera analysis backpressure bounded and lifecycle-aware.

## Node SDK and React web-demo parity plan

Work in `/Users/orenzitoun/Documents/github/partner-sdk-node` and preserve the existing dirty scan route and photo helper.

1. Read repository instructions and inspect both dirty files before editing.
2. Compare generated/public TypeScript APIs with the v1.2 contract and the iOS behavior matrix.
3. Keep React components out of the SDK core. SDK parity means user-context ergonomics, request helpers, typed results, image preprocessing interfaces appropriate to browser use, and complete API coverage.
4. Add an immutable/scoped `forUser` client that reuses transport and automatically applies user ID/timezone to Food Logs and Glucose.
5. Finish the browser photo helper with aspect-preserving resize, orientation handling where supported, JPEG compression, and tests.
6. Implement app-level date-range helpers with Today, Sunday–Saturday current week, and previous calendar month.
7. Split the React demo into tokens/primitives and feature components matching the responsibility table. Use the repository's existing styling approach rather than introducing a new framework.
8. Keep state that must survive route/modal navigation in the appropriate route store/context/query cache.
9. Make scan analysis a real dialog/sheet route state, with correct focus trapping, Escape/close behavior, and return focus.
10. Constrain media with CSS parent bounds and `object-fit: cover`; explicitly test wide landscape images at narrow mobile widths.
11. Explain stable user ID and timezone, multi-food logs, profile effects, selected foods, and prediction inputs in plain language.
12. Add component stories/examples if the repository already uses Storybook; otherwise provide focused route/component fixtures without adding a new system solely for previews.
13. Run unit tests once, run the real dev server, inspect Search/Scan/Food Logs/Glucose at desktop and mobile widths, capture screenshots, and run the primary browser flow.
14. Verify camera/file behavior in Chrome and Safari and provide a clear fallback when live barcode detection is unavailable.
15. Stop for review before committing or pushing unless explicitly asked.

Web accessibility requirements:

- native buttons and inputs
- visible keyboard focus
- real labels and descriptions
- segmented controls represented with appropriate grouping/selection semantics
- modal focus trap, Escape dismissal, and focus restoration
- loading announcements without replacing usable cached content
- meaningful image alt text or intentionally empty alt for decorative placeholders
- reduced-motion support for non-essential animation

## Cross-platform parity acceptance matrix

Do not call a platform complete until each applicable row is proven.

| Capability | iOS reference | Android target | Web target |
| --- | --- | --- | --- |
| Foods search/autocomplete/get full food | Public resources and demo Search | Kotlin SDK + Compose Search | TypeScript SDK + React Search |
| Serving/quantity nutrient scaling | `FoodPortion` and serving sheet | Same typed calculation and UI | Same typed calculation and UI |
| Restaurant/menu search | Search + retained detail view model | Retained view-model state | Retained route/query state |
| Network image + placeholder | `NetworkImage` | Reusable async image composable | Reusable image component |
| Bounded food/scan images | Parent-sized clipped containers | Fixed parent + `ContentScale.Crop` | Fixed parent + `object-fit: cover` |
| Alternatives | Real modal, filters, refresh, cached state | Modal/bottom sheet equivalent | Accessible dialog/route modal |
| Stable user context | `UserSession` + `PartnerUserContext` | App persistence + scoped client | local/auth session + scoped client |
| Multi-food log create/update | Array of `FoodSelection` | List of selections | Array of selections |
| Arbitrary timestamps | `timestampUTC` | ISO UTC timestamp | ISO UTC timestamp |
| Date ranges | Today/week/last month helpers | Same calendar semantics | Same calendar semantics |
| Glucose profile explanation | Workflow guide + profile/food separation | Same conceptual steps | Same conceptual steps |
| User-scoped glucose/log calls | `client.forUser` | Kotlin scoped client | TypeScript scoped client |
| Photo normalization | `PhotoScanImage` | EXIF/downsample/JPEG helper | browser resize/JPEG helper |
| Camera Photo flow | SDK scanner | CameraX SDK flow | camera/file flow |
| Barcode flow | SDK scanner + lookup + get full food | CameraX/ML barcode flow | supported detector + fallback |
| Scan result semantics | Real modal sheet | Real modal destination | Accessible dialog/route modal |
| Detection label | `High confidence` | Explicit confidence label | Explicit confidence label |
| Loading | Branded spinner; cached content retained | One indicator; stale data visible | One indicator; stale data visible |
| Navigation | Central native variants | Central native app-bar variants | Central header variants with router semantics |
| Component examples | SwiftUI `#Preview` | Compose previews | Stories/fixtures |
| Visual evidence | Committed screenshots | Required | Required desktop + mobile |
| Physical/browser verification | Final device sweep still required | Physical device required | Chrome + Safari required |

## Required implementation sequence

For each platform, follow this sequence exactly:

1. Inspect the working reference and existing dirty work.
2. Implement only the requested parity scope.
3. Run the relevant unit/contract checks once.
4. Run the actual demo application.
5. Inspect the primary user flow.
6. Capture visual evidence.
7. Report genuine blockers and stop for review.
8. Commit and push only when explicitly requested.

Do not work around a failed check by repeatedly rerunning it unchanged. Diagnose the one failure, make the smallest fix, and rerun that check once.

## Copy/paste prompt for the next coding session

```text
Continue January Partner cross-platform SDK and demo parity from:

/Users/orenzitoun/Documents/github/partner-sdk-ios/Documentation/HANDOFF_2026-08-26_ANDROID_WEB_PARITY.md

Read the entire file before taking action. Use the iOS commit a7005f7 as the behavioral and visual reference, not as code to translate literally.

Preserve all existing dirty work in:

/Users/orenzitoun/Documents/github/partner-sdk-android
/Users/orenzitoun/Documents/github/partner-sdk-node

Do not reset, clean, discard, clone, create replacement worktrees, commit, or push unless I explicitly ask. Inspect each repository's instructions and dirty diffs first.

Bring the Android SDK/demo and Node SDK/React demo to parity with the iOS structure and flows: app-owned persistent user identity with SDK-scoped clients; multi-food logs; arbitrary timestamps and Today/This week Sunday–Saturday/Last month helpers; clear Food Logs and Glucose guidance; retained cached data during refresh; one branded loader; native/accessible navigation and segmented controls; reusable one-purpose UI components with previews/stories; bounded network and scan images; real modal scan results; photo preprocessing; and Photo/Barcode workflows appropriate to each platform.

Use platform-native architecture: Kotlin/Compose/CameraX on Android and TypeScript/React/browser primitives on web. Keep React out of the Node SDK core. Do not introduce layout measurement hacks where normal grid/flex/constraints work.

Implement the requested scope, run relevant tests once, run each actual demo, inspect the primary flows, capture screenshots, verify Android on a physical device and web in Chrome and Safari, then stop for review.

Important: iOS CI run 32918251513 is red only at the enforced 100% handwritten SDK coverage step even though all 38 tests pass. Do not claim full cross-platform parity or a green release until that iOS coverage blocker and the documented README deployment/image wording drift are resolved.
```
