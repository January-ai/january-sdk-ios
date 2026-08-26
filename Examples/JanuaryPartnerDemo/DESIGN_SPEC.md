# January Partner Demo — screen specification

## Purpose

Design a polished, partner-facing iOS sample app that demonstrates the January Partner SDK through real SDK calls. The app should feel like a small, coherent product—not an API console—and should use the Jan Companion visual language supplied in the design reference.

Platform: iOS 26+, SwiftUI, iPhone-first. Use native navigation, controls, sheets, menus, photo picking, and tab behavior. Layouts must adapt cleanly to larger phones, Dynamic Type, and iPad without creating a separate iPad experience in this phase.

## Product rules

- Keep the existing four-tab structure: **Search**, **Scan**, **Food Logs**, and **Glucose**.
- Use the native iOS 26 `TabView` with four persistent, labeled tabs. Do not assign Search the special system search role, draw a custom tab bar, or fake glass effects.
- Every tab uses its own `NavigationStack`. Do not add persistent toolbar controls that are absent from the approved screen composition. The missing-user Food Logs callout is the contextual entry to Settings.
- Do not design an API-key entry screen or an API-key gate. The API key is a compile-time constant and an empty value is a build error.
- Never display, log, copy, or partially reveal the API key.
- The app may show returned IDs and request IDs in a subdued **Technical details** disclosure, but raw API implementation language should not dominate the product UI.
- Do not add onboarding, account creation, medication, coaching, chat, CGM connection, or health dashboards. Those capabilities are outside this SDK demo.

## Design language

The demo uses one shared SwiftUI token layer in `Core/DemoComponents.swift`. Screens must consume these semantic tokens instead of introducing one-off colors, spacing, radii, or button treatments.

### Color tokens

| Role | Token | Value | Use |
|---|---|---:|---|
| Canvas | `canvas` | `#EFEBE2` | Outer presentation canvas and design references |
| App background | `paper` | `#FAF8F2` | Every tab and pushed screen |
| Surface | `surface` | `#FFFFFF` | Cards and raised controls |
| Primary ink | `ink` | `#1D1A14` | Titles, primary text, primary buttons |
| Body | `body` | `#3E3A2E` | Long-form and supporting copy |
| Muted | `muted` | `#55503F` | Labels and secondary information |
| Subdued | `subdued` | `#8F887A` | Disabled and tertiary information |
| Border | `border` | `#E0DACB` | Card and control outlines |
| Divider | `divider` | `#F1EDE2` | Rows within grouped cards |
| Control | `control` | `#F3F0E7` | Search fields and secondary controls |
| Strong control | `controlStrong` | `#EBE5D8` | Selected neutral controls |
| Event yellow | `yellow` | `#F4C63F` | Meal/event markers only—not primary buttons |
| Positive green | `green` | `#54724F` | Positive/in-range and supported actions |
| Elevated rust | `rust` | `#A85F3D` | Elevated glucose and recoverable errors |
| Gold callout | `goldBackground` / `goldText` | `#FBF0CB` / `#6E5613` | Required setup guidance |

### Type, spacing, and shape

- Use system serif display type for screen, sheet, and card titles; use system sans for body and controls.
- Use monospaced numerals for nutrition, measurements, glucose values, quantities, and chart annotations.
- Body copy is 17 pt. Short uppercase eyebrow labels are 13 pt bold with tracking.
- Every screen uses a fixed 16 pt left/right gutter so every title, control, and card shares the same horizontal center and equal outer gutters. Use native stacks and flexible `LazyVGrid` columns; do not use custom `Layout`, `GeometryReader`, or `.frame(maxWidth: .infinity)` for ordinary screen layout.
- Use 20 pt section rhythm, 22 pt card insets, 18 pt control horizontal insets, 24 pt card corners, 28 pt feature corners, and 18 pt control corners.
- Compact custom sheets show the native drag indicator and keep at least 28 pt between the sheet’s content boundary and the first custom header row.
- Primary actions are 56 pt-high ink buttons with paper text. Secondary actions use the pale control surface. Tertiary actions use white outlined controls. Yellow is not a button fill.
- Empty-state cards center the entire icon/title/body group horizontally within the card. Centering text alone is insufficient; the group must have symmetric leading and trailing space.
- Sentence case everywhere except short eyebrow labels. Copy is calm and plain-spoken: no exclamation marks, emoji, cheerleading, blame, or medical promises.
- Motion is restrained and native. Honor Reduce Motion and avoid decorative bounce.

### Charts

- Prediction curves use a **solid**, 3.5 pt round-cap line with a restrained vertical fill fading toward the chart baseline.
- Use the green target band behind the data, a small yellow meal marker, and a small outlined peak marker with a data-backed label.
- Show four x-axis time labels from 0 through 120 minutes and allow the curve to reach the full plot width.
- Use color together with text and shape; impact labels and annotations must remain legible at WCAG AA contrast.

## Global runtime context

### Settings sheet

Use a medium/large native sheet with an inline title. Open it contextually from setup guidance rather than repeating a gear button on every approved screen.

Show:

- **Connection**: “API key configured” with a success icon. Never show the key.
- **End user ID**: editable text field. Explain that this is the partner’s stable identifier for the person represented by the requests. It is optional for discovery calls and required for Food Logs.
- **Timezone**: default to the device timezone; allow selection from system timezones.
- **Restaurant location**: status for location permission and a “Use current location” action. Manual coordinates belong in the restaurant filter sheet, not the main Settings screen.
- **About**: SDK version and app version.

Save non-secret demo context locally. If Food Logs is opened without an end user ID, show an inline setup card with an action that opens Settings.

## Tab 1 — Search

The Search tab covers food discovery and nearby restaurant discovery. At the top of the content, use the shared warm-surface segmented control: **Foods** / **Restaurants**.

### 1. Food search

Use a second mode selector with:

- **Name** — standard food database search.
- **Meal description** — parses a sentence such as “oatmeal with honey and a banana.”
- **Barcode** — looks up a 6–14 digit UPC/EAN/GTIN.

#### Name mode

Show:

- Native search field.
- Optional category chips: All, General, Branded, Recipe.
- Result limit defaults to 10 and may be changed from the populated-results header; it does not appear in the untouched state.
- Results count appears only after a successful search.
- Result cards/rows with photo when available, food name, brand, calories, protein, carbohydrates, fat, and primary serving summary. Omit absent values rather than showing placeholders.

States: untouched prompt, typing, loading skeleton, populated results, no matches, validation error, and request error with Retry.

#### Meal description mode

Show a multiline input with example copy and a **Parse meal** button. The result screen contains:

- Aggregate nutrition summary when returned.
- A detected-food list with name, brand, nutrients, and selected serving quantity when available.
- A compact nutrition card for each detected food.

#### Barcode mode

Show:

- Barcode camera action.
- Manual numeric barcode field and **Look up** button.
- Permission-denied state with a direct manual-entry fallback.
- Results use the same food-result component as Name mode.

### 2. Food detail

Opened from any food result. Show:

- Photo, name, brand, and selected serving.
- Serving picker plus quantity stepper.
- Prominent calories and a compact protein/carbohydrates/fat summary.
- Full nutrition section containing only values returned by the SDK: net carbohydrates, saturated fat, fiber, total and added sugars, sodium, potassium, cholesterol, glycemic index, and glycemic load.
- Food and serving IDs under **Technical details**.
- Primary action: **Find alternatives**.

### 3. Alternatives setup and results

Present setup as a sheet before making the request:

- Multi-select dietary restrictions.
- Multi-select dietary preferences.
- “None” is the default for each group and is mutually exclusive with other selections.
- Primary action: **Find alternatives**.

Display alternatives as food cards with name, brand, nutrition, and servings. Support an honest empty state: “No suitable alternatives were found.” Selecting an alternative opens the standard Food detail screen.

### 4. Restaurant search

Use a mode selector: **Restaurants** / **Menu items**.

Both modes show:

- Search field.
- Location row showing the current place or coordinates.
- Filter sheet with **Use current location**, manual latitude/longitude, radius in miles with the meter value available as secondary text, and result limit.
- Location permission request only after the user chooses current location; always retain manual coordinate entry.
- Current-location access uses the shared one-shot `DemoLocationProvider`: request only the accuracy needed for nearby search, stop after one result, surface denied/restricted states, and provide a direct Settings recovery action.

Restaurant results show name, chain indicator when returned, distance, city, and address. Menu-item results show image when available, item name, restaurant name, distance, calories, core macros, and primary serving.

Selecting a menu-item result opens a read-only detail screen containing all fields returned in that search result. Selecting a restaurant loads the existing menu-item search operation with the restaurant name and active location, then shows the returned items beneath the restaurant details. Do not invent restaurant hours, ratings, maps, or a separate detail API.

## Tab 2 — Scan

### 5. Meal photo input

The default screen should make all supported image paths obvious without exposing base64 text:

- Large meal-photo preview area.
- Primary action: **Take photo**.
- Secondary actions: **Choose photo**, **Use sample meal**, and **Use image URL**.
- Image URL opens a small sheet with URL validation.
- A selected local or camera photo is encoded to a base64 data URI by the app; do not show the encoded string.
- Show brief guidance that the image should be clear and contain the whole meal.
- Primary submission action: **Analyze meal**.

Include camera-denied, photo-library-denied, invalid URL, unsupported image, and oversized-image states with a clear recovery action.

### 6. Scan processing

Keep the selected photo visible with a restrained progress treatment and the copy “Analyzing this meal…” Explain that complex meals can take a little longer. Provide Cancel. Do not show fake percentage progress.

### 7. Scan result

Show:

- Meal name when returned; otherwise “Meal analysis.”
- Selected photo thumbnail.
- Aggregate calories and nutrition summary when returned.
- Detected foods as cards with name, brand, serving, nutrients, and confidence (High, Medium, Low) when returned. Confidence must use text as well as color.
- Glucose impact label and predicted curve when returned. Use the shared solid prediction chart and label it as an estimate.
- Primary action: **Correct result**.
- Secondary action: **Scan another meal**.

### 8. Correct scan

Present a pushed screen or large sheet containing:

- Editable meal name.
- Read-only summary of the current detections being corrected.
- Required multiline field labeled **What should change?**, with a concrete example.
- Primary action: **Submit correction**.

After success, replace the prior result with the corrected result and show a quiet confirmation. Preserve the original photo. Provide retry without losing the entered correction if the request fails.

## Tab 3 — Food Logs

### 9. Food log list

Show:

- Date-range control with sensible initial range and a calendar sheet for custom start/end dates.
- Add button in the toolbar.
- Chronological log cards showing log name or “Meal,” local date/time, food count, food names, and calorie/core-macro summary when values are available.

States: missing end user ID setup card, loading, populated list, valid empty range, request failure, and pull-to-refresh.

### 10. Create food log

Use a form-style pushed screen or large sheet:

- Optional meal name.
- Date and time; default to now.
- Selected-food list.
- **Add food** action opening the shared Food picker.
- For every selected food: serving picker, quantity stepper/editor, and Remove action.
- Primary action: **Save food log**. Require at least one selected food.

### 11. Shared Food picker

Reusable from Food Logs and Glucose prediction:

- Search by food name.
- Results use compact food rows.
- The untouched state contains the centered shared empty-state card and no separate submit button. Submit from the keyboard Search action.
- Populated results use one grouped white card under the eyebrow **Results · January food database**.
- Food selection opens a serving/quantity sheet.
- The serving selector is a compact medium sheet with a centered **Choose serving** eyebrow, serif food name, outlined serving/quantity card, circular minus/plus controls, unboxed macro strip, and a black **Add to meal** action.
- Preserve already-selected foods when returning to the parent form.

Only food records with the required food and serving IDs can be added to a log or prediction.

### 12. Food log detail

Show:

- Name, local date/time, and log ID under Technical details.
- Every logged food with image when available, brand, consumed serving, calories, full returned nutrition, glycemic index, and glycemic load.
- Toolbar **Edit** action.
- Bottom destructive **Delete food log** action.

Deletion requires a native destructive confirmation dialog. On success, return to the list and remove the item. The edit screen reuses the Create layout and supports changing the name, time, foods, servings, and quantities.

## Tab 4 — Glucose

### 13. Prediction setup

This is a structured form, not a dashboard.

#### Profile

- Age.
- Gender: Female / Male, matching the current API vocabulary.
- Height in inches.
- Weight in pounds.
- Optional health conditions: Type 2 diabetes, Prediabetes, None of the above. “None of the above” is mutually exclusive with other selections.

#### Meal

- Selected-food list using the shared Food picker.
- Serving and quantity for every food.
- Meal start date/time with timezone.
- Require at least one food.

Primary action: **Predict glucose response**.

### 14. Prediction result

Show:

- Back action: **Glucose**. Heading: **Estimated response**.
- The chart card begins with a large monospaced likely-peak value, impact/timing context, and a data-backed delta from meal start.
- Impact classification: Low, Medium, or High. Use green, gold, or rust plus text; do not use safety red for High.
- Predicted glucose curve with minutes after the meal on the x-axis and mg/dL on the y-axis.
- Use a solid prediction line. The API’s lower and upper values are suggested chart/target bounds, not observed minimum and maximum; use them to scale or shade the chart and do not label them as measured extrema.
- Meal summary follows the chart. A gold **Worth knowing** card may explain only data-backed behavior; do not invent medical advice.
- Quiet note: “This is a prediction, not a medical recommendation.”
- Present **Adjust meal** and **Start over** as equal-width bottom actions.

## Shared result components

Use the same components in Search, Scan, Logs, and Glucose wherever the data overlaps:

- Food identity row: image, name, brand.
- Serving picker and quantity editor.
- Nutrition summary: calories plus protein/carbohydrates/fat.
- Expandable nutrition facts list with value and unit.
- Glycemic summary for GI/GL when available.
- Glucose prediction chart.
- Technical details disclosure for resource IDs and request IDs.

Absent optional fields disappear cleanly. Do not render `0`, “null,” dashes, or empty cards for values the API omitted.

## Shared states and errors

Every SDK-backed screen must be designed in these states:

- Initial/untouched.
- Loading without destroying entered data.
- Success with full data.
- Success with sparse optional data.
- Valid empty result.
- Inline validation failure.
- Authentication/authorization failure.
- Not found.
- Rate limited, including retry timing when provided.
- Timeout/network/server failure with Retry.

Use calm, specific copy. Validation stays next to the field. Recoverable request failures use an inline callout or `ContentUnavailableView`, not an alarming full-screen red state. Authentication failures should say that the configured API key could not be used and that the developer must update the project configuration and rebuild. Include server message, status, error code, and request ID only inside Technical details.

## Accessibility and platform behavior

- Support Dynamic Type without truncating values or actions.
- Every icon-only control needs an accessibility label.
- Never rely on color alone for confidence, glucose impact, success, or errors.
- Nutrition and chart values need VoiceOver-readable labels and units.
- Respect Reduce Motion and Increase Contrast.
- Keep content reachable with keyboard avoidance and scrolling.
- Use native confirmation dialogs for destructive actions and native permission prompts only at the moment a feature needs them.
- Preserve in-progress form data through sheets, navigation, retries, and temporary app backgrounding.

## Required design deliverables

Provide annotated, high-fidelity iPhone frames for:

1. Search: food-name results, meal-description result, barcode input, food detail, alternatives setup/results.
2. Search: restaurant results, menu-item results, restaurant filters, result detail.
3. Scan: source selection, processing, full result, correction.
4. Food Logs: list, empty state, create/edit, shared Food picker, detail, delete confirmation.
5. Glucose: basic form, optional-history form, populated result.
6. Global: Settings, representative loading state, sparse-data state, validation error, request error, and missing end-user-ID state.

Also provide a compact component/state sheet for food rows, nutrient cards, serving controls, impact/confidence labels, callouts, empty states, and the prediction chart. Include spacing, typography, colors, component variants, and navigation/transition annotations sufficient for a SwiftUI coding agent to implement without guessing.
