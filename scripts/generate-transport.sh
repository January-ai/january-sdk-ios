#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator_root="$repository_root/Tools/ContractGenerator"
generated_root="$generator_root/Sources/JanuaryPartnerTransport/GeneratedSources"
destination_root="$repository_root/Sources/JanuaryPartnerTransport/Generated"
lock_path="$repository_root/Contract/sdk-contract.lock.json"
generator_openapi="$generator_root/Sources/JanuaryPartnerTransport/openapi.yaml"
working_directory="$(mktemp -d)"

cleanup() {
    rm -rf "$working_directory"
    rm -f "$generator_openapi"
}
trap cleanup EXIT

lock_value() {
    /usr/bin/plutil -extract "$1" raw -o - "$lock_path"
}

contract_version="$(lock_value contractVersion)"
archive_name="$(lock_value artifact)"
archive_root="$(lock_value archiveRoot)"
expected_sha256="$(lock_value sha256)"
archive_path="${JANUARY_CONTRACT_ARCHIVE:-$repository_root/../partner-api-contract/artifacts/releases/$contract_version/$archive_name}"

if [[ ! -f "$archive_path" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "Set JANUARY_CONTRACT_ARCHIVE or install and authenticate GitHub CLI." >&2
        exit 1
    fi
    archive_path="$working_directory/$archive_name"
    gh api \
        -H "Accept: application/vnd.github.raw+json" \
        "repos/January-ai/partner-api-contract/contents/artifacts/releases/$contract_version/$archive_name" \
        > "$archive_path"
fi

actual_sha256="$(shasum -a 256 "$archive_path" | awk '{print $1}')"
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    echo "Contract archive SHA-256 does not match sdk-contract.lock.json." >&2
    exit 1
fi

tar -xzf "$archive_path" -C "$working_directory"
cp "$working_directory/$archive_root/openapi/partner-api.generator.yaml" "$generator_openapi"

# The deployed API omits individual nutrient keys when they are unavailable.
# The locked contract records that response decoders must remain tolerant until
# the shared MacroNutrientsDto requiredness is corrected upstream.
node --input-type=module - "$generator_openapi" <<'NODE'
import fs from "node:fs";

const path = process.argv[2];
const source = fs.readFileSync(path, "utf8");
const schemaStart = source.indexOf("    CompleteScanNutritionFacts:\n");
const schemaEnd = source.indexOf("\n    NaturalLanguageServing:\n", schemaStart);
if (schemaStart < 0 || schemaEnd < 0) {
    throw new Error("CompleteScanNutritionFacts schema was not found.");
}

const schema = source.slice(schemaStart, schemaEnd);
const requiredStart = schema.indexOf("\n      required:\n");
const metadataStart = schema.indexOf("\n      x-january-upstream-schema:", requiredStart);
if (requiredStart < 0 || metadataStart < 0) {
    throw new Error("CompleteScanNutritionFacts required block was not found.");
}

const tolerantSchema = schema.slice(0, requiredStart) + schema.slice(metadataStart);
fs.writeFileSync(
    path,
    source.slice(0, schemaStart) + tolerantSchema + source.slice(schemaEnd)
);
NODE

swift package \
    --package-path "$generator_root" \
    --disable-automatic-resolution \
    --allow-writing-to-package-directory \
    generate-code-from-openapi \
    --target JanuaryPartnerTransport

mkdir -p "$destination_root"
rsync -a --delete "$generated_root/" "$destination_root/"

echo "Generated the package-private Swift transport from contract release $contract_version."
