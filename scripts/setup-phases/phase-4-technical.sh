#!/usr/bin/env bash
# Phase 4 — technical choices (runtime, delivery).
# Sets STEWARD_DELIVERY and STEWARD_SCHEDULE.

phase_4_technical() {
  heading "Phase 4 — technical choices"
  echo

  # --- Runtime confirmation (already detected in Phase 0). ---
  say "  runtime: $STEWARD_RUNTIME  (detected in Phase 0)"
  echo

  # --- Delivery channel ---
  dim "  delivery channel — how should the steward reach you?"
  dim "    1) terminal   — steward morning prints to stdout (default, zero setup)"
  dim "    2) slack      — slack incoming webhook (best for always-on notifications)"
  dim "  email and Signal are not wired in this version, so setup won't offer them yet."
  local choice
  ask "  pick 1-2:" choice "1"
  case "$choice" in
    2)
      STEWARD_DELIVERY="slack"
      local webhook
      dim "  paste your Slack incoming webhook URL (or leave blank to configure later):"
      ask "  webhook:" webhook ""
      if [[ -n "$webhook" ]]; then
        printf 'SLACK_WEBHOOK_URL=%s\n' "$webhook" >> "$STEWARD_HOME/.env"
      fi
      ;;
    *) STEWARD_DELIVERY="terminal" ;;
  esac
  sage "  delivery: $STEWARD_DELIVERY"
  echo

  # --- Schedule ---
  dim "  schedule — automatic daily scheduling is not wired into setup yet."
  dim "  Setup will leave Steward manual-only. You can run:"
  dim "    $STEWARD_REPO/scripts/daily-check.sh"
  dim "    $STEWARD_REPO/scripts/evening-check.sh"
  STEWARD_SCHEDULE="none"
  sage "  schedule: $STEWARD_SCHEDULE"
  return 0
}
