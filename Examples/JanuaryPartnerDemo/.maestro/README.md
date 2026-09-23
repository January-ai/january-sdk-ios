# Demo end-to-end suite

Maestro flows that drive the demo app against the local fixture server, one
flow per user journey, mirroring the React Native SDK's suite (same flow names,
same kebab-case accessibility identifiers). They run on every pull request,
split across three simulator shards, and locally against any booted simulator.
Flows tagged `live` run the same app against the January API through a token
relay; they never run in CI (see [Live flows](#live-flows)).

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
- Tag every flow `fixture`, `parity`, or `live`; CI runs `fixture` and
  `parity`.

## Live flows

Flows `90`–`96` are tagged `live`. They run the demo as a fresh install in
client-token mode against the January API, exercise search, food detail,
alternatives, barcode, meal description, photo scan and correction,
restaurants and menus, glucose prediction, food logs, water, weight, and the
Tracking charts, and check every change they make against the API with
`scripts/live-api.js`, which gets a token for the same user from the same
token endpoint and never prints it.

They write to the end user you pass, so use a dedicated test user. The flows
delete the food logs and water they create; weight logs cannot be deleted, so
each complete run adds that day's weights.

```sh
# Terminal 1: the token relay (see the demo README)
cd january-token-relay && ./start.sh

# Terminal 2: a Debug build installed on a booted simulator, as above
node Examples/JanuaryPartnerDemo/.maestro/run-live.mjs --end-user your-test-user
```

`run-live.mjs` checks with one token request and one API request that the API
is answering, then runs the flows one at a time with a pause between them and
stops at the first failure, printing the `--from` command that resumes the run
there. If the API answers `429 rate_limited`, the flow stops at that step
instead of failing every later one. The weight flow runs last, so a run that
stops earlier logs no weight. Screenshots of each step, Maestro's debug output,
and a log of the API checks land in the output directory (`--output`).

A complete run makes about 150 to 165 January API requests, including the
client tokens it requests (`--rehearse` counts them flow by flow), and at most
about 35 in any minute; the food-log, water, and weight flows make most of
them. Accounts also have a daily request allowance, so check yours before a
run, or run the flows in parts with `--only`.

`--token-url` points the flows at another token endpoint, and `TIMEZONE=...`
sets the timezone of the API checks when the simulator's differs from this
machine's. The water flow first asks the API whether it accepts daily totals
in cups: if it does, it logs and deletes a cup; if not, it checks that the
Tracking card reports the refusal and logs nothing.

To rehearse the live flows without the January API, `--rehearse` lets the
fixture server stand in for both the token endpoint and the API (Debug builds
only) and prints how many requests each flow made.

## In CI

`.github/workflows/quality.yml` checks UI coverage, builds a Debug simulator
app once, then `ui-test-ios` runs three shards through
`.github/scripts/ios-ui-suite.sh`. Failed flows are rerun once and named in a
workflow warning; each shard uploads its JUnit report and Maestro's failure
screenshots and view hierarchies as `maestro-ios-N`. The `ui-tests` job
summarizes the shards.
