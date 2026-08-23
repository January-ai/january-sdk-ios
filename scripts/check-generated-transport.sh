#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
baseline="$(mktemp -d)"
trap 'rm -rf "$baseline"' EXIT

cp -R "$repository_root/Sources/JanuaryPartnerTransport/Generated/." "$baseline/"
"$repository_root/scripts/generate-transport.sh"

if ! diff -ru "$baseline" "$repository_root/Sources/JanuaryPartnerTransport/Generated"; then
    echo "Generated transport drifted from contract release 1.2.0." >&2
    exit 1
fi

echo "Generated transport is current."
