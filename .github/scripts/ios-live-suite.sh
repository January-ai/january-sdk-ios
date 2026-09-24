#!/usr/bin/env bash
# Runs the demo's live flows on an iOS simulator against the January API,
# through the token relay the job started on 127.0.0.1:8787.
#
#   ios-live-suite.sh <path to JanuaryPartnerDemo.app> <end user> <output directory>
set -euo pipefail

app="$1"
end_user="$2"
output="$3"

device_id="$(xcrun simctl list devices available | sed -nE 's/.*iPhone[^()]* \(([0-9A-F-]+)\) \(Shutdown\).*/\1/p' | head -1)"
test -n "$device_id"
xcrun simctl boot "$device_id"
xcrun simctl bootstatus "$device_id" -b
xcrun simctl install "$device_id" "$app"

node Examples/JanuaryPartnerDemo/.maestro/run-live.mjs \
  --end-user "$end_user" \
  --device "$device_id" \
  --output "$output"
