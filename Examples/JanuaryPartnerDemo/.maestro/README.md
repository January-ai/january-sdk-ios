# Demo end-to-end suite

Maestro flows that drive the demo app against the local fixture server, one
flow per user journey, mirroring the React Native SDK's suite (same flow names,
same kebab-case accessibility identifiers). They run on every pull request,
split across three simulator shards, and locally against any booted simulator.

## Run locally

```sh
# Terminal 1: deterministic API fixtures on the host
python3 Examples/JanuaryPartnerDemo/JanuaryPartnerDemoUITests/fixture_server.py 18768

# Terminal 2: build, install, and run every flow
xcodebuild -project Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj \
  -scheme JanuaryPartnerDemo -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/demo build
xcrun simctl install booted build/demo/Build/Products/Debug-iphonesimulator/JanuaryPartnerDemo.app
maestro test Examples/JanuaryPartnerDemo/.maestro/flows

# One flow, or the shard CI would run as "2 of 3"
maestro test Examples/JanuaryPartnerDemo/.maestro/flows/09-glucose.yaml
maestro test $(node Examples/JanuaryPartnerDemo/.maestro/shard.mjs 2 3)
```

`bootstrap.yaml` launches the app with the Debug-only `-ui-testing` argument,
which points the client at `http://127.0.0.1:18768` with a stub token and turns
animations off. Flows change the fixture server's behaviour through
`scripts/control-fixture.js` (HTTP status, delay, empty collections per route),
`seed-fixture.js` (one saved food log), `seed-history.js` (400 days of water
and weight before today, for the Tracking charts; list requests still honour
their dates and the 100-day limit) and `reset-fixture.js`, which the bootstrap
runs first so no flow inherits another's configuration.

## Conventions

- Select elements by accessibility identifier, never by position. The names
  are the React Native example's test IDs; the Tracking tab's `tracking-*`,
  `logs-day-*`, `water-*`, `weight-*`, and `food-logs-summary` identifiers
  (flows 26–28) were defined here first. The charts use `water-chart`,
  `weight-chart`, their `-empty` states, and `-range-week|month|year` buttons
  (flow 29); each chart's accessibility label summarizes what it shows. Segmented controls and tab items
  are matched by their visible labels where identifiers do not surface.
- Controls at the end of a scrolling screen go through `scroll-to.yaml`, which
  lifts them clear of the tab bar.
- Multiline editors cannot dismiss the keyboard with Return; tap the keyboard
  toolbar's `Done` before tapping a button below the editor.
- Assert on transient loading states with `optional: true`.
- Tag every flow `fixture` or `parity`; CI runs both tags.

## In CI

`.github/workflows/quality.yml` builds a Debug simulator app once, then
`ui-test-ios` runs three shards through `.github/scripts/ios-ui-suite.sh`.
Failed flows are rerun once and named in a workflow warning; each shard uploads
its JUnit report and Maestro's failure screenshots and view hierarchies as
`maestro-ios-N`. The `ui-tests` job summarizes the shards.
