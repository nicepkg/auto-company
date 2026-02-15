#!/usr/bin/env bash
set -euo pipefail

# Back-compat shim. Canonical script lives at:
#   scripts/devops/run-cycle-005-hosted-runtime-env-sync.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$ROOT/scripts/devops/run-cycle-005-hosted-runtime-env-sync.sh" "$@"

