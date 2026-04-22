#!/usr/bin/env bash
# Phase 4 — technical choices (runtime, delivery, schedule).
# Sets STEWARD_DELIVERY, STEWARD_SCHEDULE, and writes runtime adapter config.

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
  dim "    3) email      — docs only for v0.2, not wired yet"
  dim "    4) signal     — signal-cli or SignalWire (high friction, see guides/delivery-signal.md)"
  local choice
  ask "  pick 1-4:" choice "1"
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
    3) STEWARD_DELIVERY="email"; dim "  email is docs-only in v0.2 — see guides/delivery-email.md when wired" ;;
    4) STEWARD_DELIVERY="signal"; dim "  see guides/delivery-signal.md for signal-cli setup" ;;
    *) STEWARD_DELIVERY="terminal" ;;
  esac
  sage "  delivery: $STEWARD_DELIVERY"
  echo

  # --- Schedule ---
  dim "  schedule — when should the steward run on its own?"
  dim "    1) none      — manual only, you run 'steward morning' when you want"
  dim "    2) morning   — 9:00 local"
  dim "    3) evening   — 18:00 local"
  dim "    4) both      — 9:00 and 18:00 local"
  ask "  pick 1-4:" choice "1"
  case "$choice" in
    2) STEWARD_SCHEDULE="morning" ;;
    3) STEWARD_SCHEDULE="evening" ;;
    4) STEWARD_SCHEDULE="both" ;;
    *) STEWARD_SCHEDULE="none" ;;
  esac
  sage "  schedule: $STEWARD_SCHEDULE"

  if [[ "$STEWARD_SCHEDULE" != "none" ]]; then
    dim  "  (cron/launchd installation deferred to Phase 6; you'll confirm before anything is installed)"
  fi
  return 0
}
