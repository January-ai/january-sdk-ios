#!/usr/bin/env bash
# Runs one shard of the Maestro suite and reruns the flows that failed once.
#
#   run-maestro-shard.sh <device id> <results name> <flow file>...
#
# The first pass writes <results name>.xml; a rerun of the failed flows writes
# <results name>-rerun.xml. The shard passes when the rerun passes, and the log
# names every flow that only passed on the second attempt so flakiness stays
# visible instead of silently absorbed.
set -euo pipefail

device="$1"
results="$2"
shift 2

artifacts=Examples/JanuaryPartnerDemo/.maestro/artifacts
mkdir -p "$artifacts"

run_flows() {
  local output="$1"
  shift
  # shellcheck disable=SC2068 # each argument is one flow file
  maestro test --device "$device" $@ \
    --include-tags fixture,parity \
    --debug-output "$artifacts/debug" --flatten-debug-output \
    --format JUNIT --output "$output"
}

failed_flows() {
  node -e '
    const fs = require("fs");
    const xml = fs.readFileSync(process.argv[1], "utf8");
    const files = new Set();
    for (const testcase of xml.match(/<testcase\b[^>]*>/g) ?? []) {
      if (/status="SUCCESS"/.test(testcase)) continue;
      const file = testcase.match(/file="([^"]+)"/);
      if (file) files.add(file[1]);
    }
    console.log([...files].join(" "));
  ' "$1"
}

if run_flows "$artifacts/$results.xml" "$@"; then
  exit 0
fi

failed="$(failed_flows "$artifacts/$results.xml")"
if [[ -z "$failed" ]]; then
  echo "Maestro failed without a failing flow in the report; see the debug output."
  exit 1
fi

echo "::warning::Flows that failed on the first attempt and are rerun once: $failed"
if [[ "$device" == emulator-* ]]; then
  # The hosted emulator has gone offline mid-shard. Give it a chance to come
  # back before the rerun, and restore the Metro port forward it loses.
  adb -s "$device" wait-for-device
  for _ in $(seq 1 60); do
    [[ "$(adb -s "$device" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
    sleep 5
  done
  adb -s "$device" reverse tcp:8081 tcp:8081
fi
# shellcheck disable=SC2086 # the list is space-separated flow files
run_flows "$artifacts/$results-rerun.xml" $failed
echo "::warning::Flaky: these flows passed only on the second attempt: $failed"
