#!/usr/bin/env bash
# Runs one shard of the Maestro suite against the demo on an iOS simulator.
#
#   ios-ui-suite.sh <path to JanuaryPartnerDemo.app> <shard index> <shard count>
set -euo pipefail

app="$1"
shard="$2"
shards="$3"

device_id="$(xcrun simctl list devices available | sed -nE 's/.*iPhone[^()]* \(([0-9A-F-]+)\) \(Shutdown\).*/\1/p' | head -1)"
test -n "$device_id"
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app"

# The app reaches the fixture server on the simulator's loopback, which is the
# host's; Maestro's scripts use the same address for the control endpoints.
python3 Examples/JanuaryPartnerDemo/JanuaryPartnerDemoUITests/fixture_server.py 18768 > "$RUNNER_TEMP/ios-fixture.log" 2>&1 &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 40); do
  curl --fail --silent http://127.0.0.1:18768/__reset >/dev/null && break
  sleep 0.5
done
curl --fail --silent http://127.0.0.1:18768/__reset >/dev/null

flows="$(node Examples/JanuaryPartnerDemo/.maestro/shard.mjs "$shard" "$shards")"
echo "Flows in shard $shard of $shards: $flows"
test -n "$flows"

# shellcheck disable=SC2086 # the shard is a space-separated list of files
.github/scripts/run-maestro-shard.sh "$device_id" ios-results $flows
