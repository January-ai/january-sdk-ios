#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator_root="$repository_root/scripts/contract-generator"
generated_root="$generator_root/Sources/JanuaryPartnerTransport/GeneratedSources"
destination_root="$repository_root/Sources/JanuaryPartnerTransport/Generated"
lock_path="${JANUARY_CONTRACT_LOCK:-$repository_root/.january-internal/sdk-contract.lock.json}"
generator_openapi="$generator_root/Sources/JanuaryPartnerTransport/openapi.yaml"
working_directory="$(mktemp -d)"

cleanup() {
    rm -rf "$working_directory" "$generated_root"
    rm -f "$generator_openapi"
}
trap cleanup EXIT

if [[ ! -f "$lock_path" ]]; then
    echo "Missing internal contract lock. Set JANUARY_CONTRACT_LOCK or place it at .january-internal/sdk-contract.lock.json." >&2
    exit 1
fi

lock_value() {
    node -e 'process.stdout.write(String(require(process.argv[1])[process.argv[2]]))' "$lock_path" "$1"
}

contract_version="$(lock_value contractVersion)"
archive_name="$(lock_value artifact)"
archive_root="$(lock_value archiveRoot)"
expected_sha256="$(lock_value sha256)"
archive_path="${JANUARY_CONTRACT_ARCHIVE:-$repository_root/../partner-api-contract/artifacts/releases/$contract_version/$archive_name}"

if [[ ! -f "$archive_path" ]]; then
    archive_path="$working_directory/$archive_name"
    gh api -H "Accept: application/vnd.github.raw+json" \
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

node --input-type=module - "$generator_openapi" <<'NODE'
import fs from "node:fs";

const path = process.argv[2];
let source = fs.readFileSync(path, "utf8");
const developmentServer = "  - url: https://partners.dev.january.ai\n    description: Development\n";
if (!source.includes(developmentServer)) throw new Error("Development server block was not found.");
source = source.replace(developmentServer, "");
const schemaStart = source.indexOf("    CompleteScanNutritionFacts:\n");
if (schemaStart >= 0) {
    const remainder = source.slice(schemaStart + 1);
    const nextSchema = remainder.search(/^    [A-Za-z0-9_]+:\n/m);
    const schemaEnd = nextSchema < 0 ? source.length : schemaStart + 1 + nextSchema;
    const schema = source.slice(schemaStart, schemaEnd);
    const requiredStart = schema.indexOf("\n      required:\n");
    const metadataStart = schema.indexOf("\n      x-january-upstream-schema:", requiredStart);
    if (requiredStart < 0 || metadataStart < 0) throw new Error("CompleteScanNutritionFacts required block was not found.");
    source = source.slice(0, schemaStart) + schema.slice(0, requiredStart) + schema.slice(metadataStart) + source.slice(schemaEnd);
}

const servingStart = source.indexOf("    ServingOption:\n");
const servingEnd = source.indexOf("\n    FoodSearchItem:\n", servingStart);
if (servingStart < 0 || servingEnd < 0) throw new Error("ServingOption schema was not found.");
const servingSchema = source.slice(servingStart, servingEnd);
const requiredScalingFactor = "        - scaling_factor\n";
if (servingSchema.includes(requiredScalingFactor)) {
    source = source.slice(0, servingStart) + servingSchema.replace(requiredScalingFactor, "") + source.slice(servingEnd);
}
fs.writeFileSync(path, source);
NODE

swift package \
    --package-path "$generator_root" \
    --disable-automatic-resolution \
    --allow-writing-to-package-directory \
    generate-code-from-openapi \
    --target JanuaryPartnerTransport

mkdir -p "$destination_root"
rsync -a --delete "$generated_root/" "$destination_root/"

node --input-type=module - "$destination_root" <<'NODE'
import fs from "node:fs";
import path from "node:path";

const directory = process.argv[2];
for (const name of ["Client.swift", "Types.swift"]) {
    const file = path.join(directory, name);
    let source = fs.readFileSync(file, "utf8");
    source = source
        .replaceAll("@_spi(Generated) package import", "@_spi(Generated) import")
        .replaceAll("@preconcurrency package import", "@preconcurrency import")
        .replaceAll("package import struct Foundation.", "import struct Foundation.")
        .replace(/^@_spi\(Generated\) import OpenAPIRuntime\n/gm, "")
        .replace(/^import HTTPTypes\n/gm, "");
    fs.writeFileSync(file, source);
}
NODE

echo "Generated the package-private Swift transport from contract release $contract_version."
