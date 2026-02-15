#!/usr/bin/env bash
set -euo pipefail

# Back-compat wrapper. Canonical script lives at:
#   scripts/devops/run-cycle-005-hosted-persistence-evidence.sh
#
# Many runbooks reference this path; keep it as a thin shim to minimize operator error.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$ROOT/scripts/devops/run-cycle-005-hosted-persistence-evidence.sh" "$@"

