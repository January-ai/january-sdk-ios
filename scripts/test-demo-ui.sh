#!/bin/sh
set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fixture="$repository_root/Examples/JanuaryPartnerDemo/JanuaryPartnerDemoUITests/fixture_server.py"
destination=${IOS_UI_TEST_DESTINATION:-"platform=iOS Simulator,name=iPhone 17 Pro,OS=latest"}

python3 "$fixture" 18768 &
fixture_pid=$!
trap 'kill "$fixture_pid" 2>/dev/null || true' EXIT INT TERM

xcodebuild \
  -project "$repository_root/Examples/JanuaryPartnerDemo/JanuaryPartnerDemo.xcodeproj" \
  -scheme JanuaryPartnerDemoUITests \
  -destination "$destination" \
  test
