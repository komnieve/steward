#!/usr/bin/env bash
# Evening steward reflection. Thin wrapper over daily-check.sh with MODE=evening.
set -euo pipefail
MODE=evening exec "$(dirname "${BASH_SOURCE[0]}")/daily-check.sh" "$@"
