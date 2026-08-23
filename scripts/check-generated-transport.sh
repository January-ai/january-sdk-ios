#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
baseline="$(mktemp -d)"
trap 'rm -rf "$baseline"' EXIT

mkdir -p "$baseline/Generated" "$baseline/Contract"
cp -R "$repository_root/Sources/JanuaryPartnerTransport/Generated/." "$baseline/Generated/"
cp "$repository_root/Contract/sdk-vocabulary.json" "$baseline/Contract/sdk-vocabulary.json"
"$repository_root/scripts/generate-transport.sh"

if ! diff -ru "$baseline/Generated" "$repository_root/Sources/JanuaryPartnerTransport/Generated"; then
    echo "Generated transport drifted from the locked contract release." >&2
    exit 1
fi
if ! diff -u "$baseline/Contract/sdk-vocabulary.json" "$repository_root/Contract/sdk-vocabulary.json"; then
    echo "SDK vocabulary drifted from the locked contract release." >&2
    exit 1
fi

echo "Generated transport and SDK vocabulary are current."
