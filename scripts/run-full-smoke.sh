#!/bin/bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
environment_name="${1:-development}"

if [[ ! -f "$repository_root/.env" ]]; then
    echo "Create the gitignored $repository_root/.env file first." >&2
    exit 2
fi

set -a
source "$repository_root/.env"
set +a

case "$environment_name" in
    development)
        export JANUARY_API_KEY="$JANUARY_DEV_API_KEY"
        export JANUARY_BASE_URL="https://partners.dev.january.ai"
        ;;
    production)
        export JANUARY_API_KEY="$JANUARY_PROD_API_KEY"
        export JANUARY_BASE_URL="https://partners.january.ai"
        ;;
    *)
        echo "Usage: $0 [development|production]" >&2
        exit 2
        ;;
esac

cd "$repository_root"
swift run --disable-automatic-resolution JanuaryPartnerFullSmoke
