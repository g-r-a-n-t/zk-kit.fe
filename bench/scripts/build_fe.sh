#!/bin/bash
# Build the Fe workspace and report artifact paths.
# Called by Foundry via FFI during test setUp.
set -euo pipefail

OPT="${FE_SONA_OPT_LEVEL:-2}"
cd "$(dirname "$0")/../.."
fe build 2>/dev/null || true

# Print the binary path for the requested contract
CONTRACT="${1:-PoseidonBench}"
printf '0x'
tr -d '\n' < "out/${CONTRACT}.bin"
