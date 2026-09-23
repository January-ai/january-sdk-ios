# Demo end-to-end suite

Maestro flows that drive the demo app against the local fixture server, one
flow per user journey, mirroring the React Native SDK's suite (same flow names,
same kebab-case accessibility identifiers). They run on every pull request,
split across three simulator shards, and locally against any booted simulator.

## Run locally

```sh
# Terminal 1: deterministic API fixtures on the host
python3 Examples/JanuaryPartnerDemo/JanuaryPartnerDemoUITests/fixture_server.py 18768

# Terminal 2: build, install, and run every fixture flow
xcodebuild -project Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj \
  -scheme JanuaryPartnerDemo -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build/demo build
xcrun simctl install booted build/demo/Build/Products/Debug-iphonesimulator/JanuaryPartnerDemo.app
maestro test Examples/JanuaryPartnerDemo/.maestro/flows --include-tags fixture,parity

# One flow, or the shard CI would run as "2 of 3"
maestro test Examples/JanuaryPartnerDemo/.maestro/flows/09-glucose.yaml
maestro test $(node Examples/JanuaryPartnerDemo/.maestro/shard.mjs 2 3) --include-tags fixture,parity
```

`bootstrap.yaml` launches the app with the Debug-only `-ui-testing` argument,
which points the client at `http://127.0.0.1:18768` with a stub token and turns
animations off. Flows change the fixture server's behaviour through
`scripts/control-fixture.js` (HTTP status, delay, empty collections per route),
`seed-fixture.js` (one saved food log, eaten just after midnight today),
`seed-history.js` (400 days of water
and weight before today, for the Tracking charts; list requests still honour
their dates and the 100-day limit) and `reset-fixture.js`, which the bootstrap
runs first so no flow inherits another's configuration. `assert-request.js`
checks the last request the fixture server received on a route (its end user,
a query parameter, or part of its body), and `wait.js` waits on the host, for
example until a delayed response has arrived. Food name suggestions come back
only for queries that start with `fix`, so other flows never see them.

## Coverage

```sh
node scripts/check-ui-coverage.mjs          # "UI coverage: N/M (P%)", fails below 100%
node scripts/check-ui-coverage.mjs --list   # every identifier and the flows that reach it
```

The check reads the demo's Swift sources for every accessibility identifier
and the flows for every identifier they tap, type into, or require to be
visible, and fails unless each identifier is reached by a `fixture` or `parity`
flow. Optional commands, `assertNotVisible`, and `when` conditions do not
count. An interpolated identifier such as `food-result-\(index)` must be listed
in the script with the identifiers that stand for it. CI runs the check on
every pull request; it needs no simulator.

## Conventions

- Select elements by accessibility identifier, never by position. The names
  are the React Native example's test IDs; the Tracking tab's `tracking-*`,
  `logs-day-*`, `water-*`, `weight-*`, and `food-logs-summary` identifiers
  (flows 26–28) were defined here first. The charts use `water-chart`,
  `weight-chart`, their `-empty` states, and `-range-week|month|year` buttons
  (flow 29); each chart's accessibility label summarizes what it shows.
- Controls at the end of a scrolling screen go through `scroll-to.yaml`, which
  lifts them clear of the tab bar. After scrolling up to a control, center it
  (`centerElement: true`) so it is not left under the navigation bar.
- Return submits a search field and closes its keyboard. Number fields close
  theirs with the keyboard's `Done` button, and so do multiline editors; tap
  `Done` before tapping a button below the field.
- Cover every screen's loading, empty, error, and success states. Assert a
  loading state deterministically: delay the route with `control-fixture.js`
  (`DELAY: "8"`, longer than Maestro waits for the screen to settle after a
  tap), then wait for the loading identifier.
- Tag every flow `fixture` or `parity`; CI runs both tags.

## In CI

`.github/workflows/quality.yml` checks UI coverage, builds a Debug simulator
app once, then `ui-test-ios` runs three shards through
`.github/scripts/ios-ui-suite.sh`. Failed flows are rerun once and named in a
workflow warning; each shard uploads its JUnit report and Maestro's failure
screenshots and view hierarchies as `maestro-ios-N`. The `ui-tests` job
summarizes the shards.
