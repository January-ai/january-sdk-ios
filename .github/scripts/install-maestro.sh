#!/usr/bin/env bash
# Installs the Maestro CLI named by MAESTRO_VERSION, checks it against
# MAESTRO_SHA256, and puts it on the PATH of the job's later steps.
set -euo pipefail

archive="$RUNNER_TEMP/maestro.zip"
curl --fail --location --silent --show-error --retry 3 \
  "https://github.com/mobile-dev-inc/Maestro/releases/download/cli-${MAESTRO_VERSION}/maestro.zip" \
  --output "$archive"
echo "${MAESTRO_SHA256}  ${archive}" | shasum -a 256 --check
unzip -q "$archive" -d "$RUNNER_TEMP/maestro"
"$RUNNER_TEMP/maestro/maestro/bin/maestro" --version
echo "$RUNNER_TEMP/maestro/maestro/bin" >> "$GITHUB_PATH"
