# January SDK — iOS camera and demo UI handoff

Date: 2026-08-25

Primary repository: `/Users/orenzitoun/Documents/github/partner-sdk-ios`

Related repositories:

- Contract: `/Users/orenzitoun/Documents/github/partner-api-contract`
- Android: `/Users/orenzitoun/Documents/github/partner-sdk-android`
- Node and web demo: `/Users/orenzitoun/Documents/github/partner-sdk-node`
- Working iOS reference implementation: `/Users/orenzitoun/Documents/github/ios-january`

## Read this first

The iOS repository is on local `main` at `f0c1536`, matching `origin/main`, but it has a large uncommitted working tree. Preserve it. Do not reset, checkout, clean, or overwrite it.

The demo app currently has a hardcoded development API key in:

`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/App/JanuaryPartnerDemoApp.swift`

Treat that file as secret-bearing. Do not print it, quote it, include it in logs, or commit the key. The repository has unfinished secret-scan and local-hook work intended to prevent accidental commits.

Do not use a temporary DerivedData location. Build the one real checkout at the path above and let Xcode use its normal DerivedData. The user explicitly rejected duplicate checkouts, copied packages, and `/tmp/...DerivedData` builds because they made it impossible to know which SDK source Xcode was compiling.

## Product decisions already made

- Partner API stays v1.2.
- The public Swift SDK uses native `async`/`await`.
- The SDK ships its Foundation/URLSession transport without third-party runtime dependencies. Apple Swift OpenAPI packages are isolated to maintainer-only code generation tooling.
- Minimum iOS support needs to be iOS 15.
- The camera and barcode UI must be bundled into the existing `JanuaryPartnerSDK` product. Do not introduce or advertise a second product named `JanuaryPartnerSDKUI`.
- The client app should only need to provide required Info.plist permission descriptions and present the SDK scanner.
- The scanner must handle camera authorization, denied/restricted access, a Settings deep link using the host app name, photo capture, barcode capture, and return the result plus captured image.
- The demo app is intentionally light-mode-only for now.
- Meal images should be compressed before upload.
- A chosen or captured image must render center-cropped in a simple square image container. Do not distort it and do not add custom `Layout`, `GeometryReader`, or complicated placement code for this.
- The camera preview itself is full-screen and is not constrained to the square. The square requirement applies to selected/result image presentation.
- Shared UI should be extracted into small reusable components, one component per file, each with a useful `#Preview`.
- Component/type/file names should not be prefixed with `Demo`. These are normal app design-system components.

## Contract and SDK rollout work completed

The contract repository is clean on `main` at `0158261`, matching `origin/main`.

The latest contract rollout added and verified the v1.2 food discovery changes, including:

- autocomplete food suggestions
- get full food by ID
- live chain proof: search/autocomplete result to get-food
- portion/serving calculations in all SDKs
- contract release and generated transport synchronization
- a production-oriented contract README and detailed rollout runbook

The runbook is in:

`/Users/orenzitoun/Documents/github/partner-api-contract/docs/SDK_ROLLOUT_RUNBOOK.md`

The contract PR was merged. Android, iOS, and Node generated transport/public food APIs were brought to the new contract and merged to their respective `main` branches before the current uncommitted UI work began.

## iOS SDK and demo work in the current uncommitted tree

### SDK scanner API

New untracked SDK files:

- `Sources/JanuaryPartnerSDK/PhotoScanning/JanuaryMealScanner.swift`
- `Sources/JanuaryPartnerSDK/PhotoScanning/MealCameraViewController.swift`
- `Sources/JanuaryPartnerSDK/PhotoScanning/PhotoScanImage.swift`

Related modified files:

- `Sources/JanuaryPartnerSDK/PhotoScanning/PhotoScanningModels.swift`
- `Tests/JanuaryPartnerSDKTests/PhotoScanningResourceTests.swift`
- `Package.swift`
- `README.md`

The intended scanner supports Photo and Barcode modes in one SDK-provided experience. The demo has been integrated with it.

### Camera debugging history

The original implementation repeatedly called `startRunning()` while the capture session was interrupted. Logs showed interruption reason `1`, which is `videoDeviceNotAvailableInBackground`. Research against Apple documentation established:

- all `AVCaptureSession` setup/start/stop work must be serialized off the main actor
- never retry `startRunning()` while interrupted
- wait for `AVCaptureSession.interruptionEndedNotification`
- keep preview-layer/UI work on `MainActor`
- Swift 6 actor custom-executor patterns are modern, but the final implementation must still compile and behave on iOS 15

The implementation was reworked toward a serialized camera service and later physical-device flows did reach photo selection, barcode detection, barcode lookup, and food detail presentation. However, the scanner still needs a focused cleanup and a fresh physical-device verification after all current source edits. Copy established capture patterns from `/Users/orenzitoun/Documents/github/ios-january` before inventing new camera architecture.

Useful prior diagnostic symptoms:

- `AVCaptureSessionInterruptionReason` raw value `1`
- `FigXPCUtilities err=-17281`
- capture session configured but `running=false, interrupted=true`

Do not treat private Fig errors as stable public error codes. The main app-side error was incorrect lifecycle/retry behavior and confusion caused by Xcode compiling stale package/checkouts.

### Image behavior

Work was added for client-side image normalization/compression and scan-image resource tests. The chosen/result image has repeatedly shown unwanted top/bottom whitespace because custom layout abstractions were given unbounded or oversized proposals. The desired implementation is intentionally simple:

```swift
ZStack {
    AppPalette.control
    image
        .resizable()
        .scaledToFill()
}
.aspectRatio(1, contentMode: .fit)
.clipped()
.clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
```

No custom square `Layout`. No `GeometryReader`. The full-screen camera preview is separate from this result-image component.

### Design-system extraction and renaming

The app previously scattered reusable UI and prefixed almost every component with `Demo`. The current working tree mechanically renamed the app/design-system types and split components into individual files under:

`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/DesignSystem`

Current files include:

- `AppFoundations.swift`
- `CardStyle.swift`
- `ChipButtonStyle.swift`
- `EmptyStateCard.swift`
- `EqualColumns.swift`
- `ErrorNotice.swift`
- `FillWidth.swift` (obsolete; delete it)
- `FoodRow.swift`
- `LoadingSpinner.swift`
- `MacroGrid.swift`
- `NutritionList.swift`
- `OutlinedButtonStyle.swift`
- `PredictionChart.swift`
- `PrimaryButton.swift`
- `QuantityButtonStyle.swift`
- `ScreenShell.swift`
- `SearchField.swift`
- `SecondaryButtonStyle.swift`
- `SectionLabel.swift`
- `SegmentedControl.swift`
- `ToolbarSettingsButton.swift`

Core and shell types were also renamed:

- `DemoAppModel` → `AppModel`
- `DemoLocationProvider` → `LocationProvider`
- `DemoRootView` → `RootView`
- `DemoTabView` → `AppTabView`
- `DemoSettingsView` → `SettingsView`
- `DemoPalette`, `DemoTypography`, etc. → `AppPalette`, `AppTypography`, etc.

The Xcode project file was mechanically updated for these renamed files. Xcode may still display stale old names until the project is closed and reopened.

### CTA loading state

`PrimaryButton` is the shared CTA. Loading must:

- keep the same black enabled background
- replace the label with the custom white `LoadingSpinner`
- prevent duplicate taps while loading
- not visually look disabled

Disabled and loading are separate states.

### Macro component

The old horizontal macro strip had poor spacing and scaling. It was renamed to `MacroGrid` and changed to a 2×2 grid.

The latest edit, not yet built, changed it to native `LazyVGrid` rows with an explicit `64` point height per row:

`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/DesignSystem/MacroGrid.swift`

This prevents the preview or parent from stretching each metric cell vertically.

## The layout problem being fixed at handoff

The custom `FillWidth: Layout` is the immediate source of the latest bug. It returned the parent proposal's height:

```swift
CGSize(width: width, height: proposal.height ?? measured.height)
```

In Xcode Preview that allowed the macro content to consume nearly the full device height. The user explicitly does not want this abstraction.

At the handoff point:

- all call sites in regular Swift source were removed
- `rg` still finds only the definition/preview in `DesignSystem/FillWidth.swift`
- the file and four Xcode project references still exist
- the file must be deleted and its PBX build-file, file-reference, group, and sources entries removed
- the last patch touching `FoodLogsView.swift` and `PredictionChart.swift` has not been compiled yet

There is one other custom SwiftUI `Layout` component:

`Examples/JanuaryPartnerDemo/JanuaryPartnerDemo/DesignSystem/EqualColumns.swift`

It is used for equal-width sibling controls/content. Review its usages. Prefer native `HStack` or `LazyVGrid` where that is sufficient; do not retain a custom `Layout` merely for abstraction. The macro grid no longer uses it.

## Exact next steps

1. Preserve the dirty tree and stay on the single real checkout/local `main`.
2. Delete `DesignSystem/FillWidth.swift` using `apply_patch`.
3. Remove all four `FillWidth.swift` references from `Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj/project.pbxproj`.
4. Confirm `rg -n '\\bFillWidth\\b|FillWidth\\.swift' Examples/JanuaryPartnerDemo` returns no matches.
5. Inspect the just-edited brace structure in `FoodLogsView.swift` and `PredictionChart.swift`; the last patch was not compiled before this handoff.
6. Run `git diff --check`.
7. Run the relevant iOS simulator build once using normal Xcode DerivedData, not a temporary path.
8. Open/reopen the real Xcode project so renamed files appear correctly.
9. Visually verify `MacroGrid` in its preview and in a food/scan result. Each row should be 64 points, the component should wrap content, and it must not grow to the full parent height. Capture a screenshot.
10. Audit the remaining `EqualColumns` usages and replace only those where native layout is clearer.
11. Continue the scanner/result UI verification on a physical iPhone: camera feed, Photo mode, Barcode mode, permission denial and Settings flow, capture, compression, upload, lookup, result image, correction, alternatives, and CTA loading.
12. Verify every extracted design-system component has a useful `#Preview`.
13. Run SDK tests and the demo build once after the UI/camera work is complete.
14. Before any commit, ensure the development API key is not staged or present in the diff. Run the secret scan.
15. Do not commit or push until explicitly requested.

## Current repository states

### iOS

- Branch: `main`
- HEAD/origin: `f0c1536 feat: add food autocomplete and portion calculations`
- Dirty with the SDK scanner, demo UI extraction/renaming, image work, scripts, tests, and workflow changes described above
- No extra local branches
- Last known simulator build passed after the broad `Demo` renaming, before the final `FillWidth` removal patch
- The current latest source has not been built or visually verified

### Contract

- Clean `main`, matching origin
- HEAD: `0158261 Clarify contract repository architecture and SDK rollout`

### Android

- `main`, matching origin at `03535c6`
- Dirty uncommitted photo/image-compression and demo changes:
  - `demo/src/main/AndroidManifest.xml`
  - `demo/src/main/java/ai/january/partner/demo/DemoTheme.kt`
  - `demo/src/main/java/ai/january/partner/demo/ScanScreen.kt`
  - `sdk/build.gradle.kts`
  - `sdk/src/main/kotlin/ai/january/partner/photos/PhotoModels.kt`
  - untracked `PhotoScanImage.kt`

### Node

- `main`, matching origin at `ad22674`
- Dirty uncommitted web photo/image changes:
  - `examples/react-demo/src/routes/scan.tsx`
  - untracked `examples/react-demo/src/lib/photo-scan-image.ts`

The current priority is iOS. Do not expand into Android/Node until the iOS camera and UI are stable unless the user explicitly changes priority.

## Working style required by the user

- Inspect and copy the working `ios-january` pattern first.
- Make the smallest direct fix; do not invent architecture when a native SwiftUI component works.
- Use native SwiftUI/UIKit/AVFoundation patterns and support iOS 15.
- Do not use custom layouts, `GeometryReader`, `.infinity`, temporary clones, or temporary DerivedData without a strict need.
- Build the actual app from the one real SDK checkout.
- For every UI change: build, run, inspect the actual flow, and capture a screenshot compared with the supplied design/reference.
- Keep updates short and concrete.
- Never claim tests/builds passed unless they actually ran and passed after the latest edits.

## Copy/paste prompt for the next session

```text
Continue the January Partner iOS SDK and demo work from this handoff:

/Users/orenzitoun/Documents/github/partner-sdk-ios/Documentation/HANDOFF_2026-08-25_IOS_SDK_CAMERA_UI.md

Read the entire file before taking action. Work only in the single real checkout:

/Users/orenzitoun/Documents/github/partner-sdk-ios

Preserve the existing dirty working tree and stay on local main. Do not reset, clean, discard, clone, create another worktree, use temporary DerivedData, commit, or push unless I explicitly ask. Do not print or expose the hardcoded API key in JanuaryPartnerDemoApp.swift.

First finish the exact interrupted layout task: delete the obsolete FillWidth custom Layout and its Xcode project references, confirm no references remain, inspect the most recent FoodLogsView/PredictionChart edits for correct braces, and build once. MacroGrid must be a native 2×2 LazyVGrid with two explicit 64-point rows and must wrap its content instead of filling the parent height. Then run the real demo, visually inspect that component, and capture a screenshot.

After that, continue the iOS-only priority work described in the handoff. Use /Users/orenzitoun/Documents/github/ios-january as the working camera/UI reference. Keep the scanner bundled in the existing JanuaryPartnerSDK product, support iOS 15, use native async/await and serialized AVFoundation session work, and verify the actual physical-device Photo and Barcode flows. Keep UI components small, reusable, one per file, with previews; do not prefix them with Demo. Do not use custom Layout, GeometryReader, or .infinity where ordinary SwiftUI layout works.

Follow the sequence: implement the requested scope, run the relevant tests once, run the actual app, inspect the primary flow, capture visual evidence, and stop for review. Do not work on Android or Node unless I ask.
```
