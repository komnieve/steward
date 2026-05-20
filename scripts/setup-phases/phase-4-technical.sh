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
  dim "    3) signal     — send-only Signal message via signal-cli (to yourself or anyone)"
  dim "  email is not wired in this version, so setup won't offer it yet."
  local choice
  ask "  pick 1-3:" choice "1"
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
    3)
      STEWARD_DELIVERY="signal"
      dim "  Signal needs signal-cli installed and a registered/linked number."
      dim "  See guides/tools-setup.md for install + linking (macOS, Linux, WSL)."
      local signal_number signal_recipient
      dim "  the number steward sends *from* (registered/linked), e.g. +12025550123:"
      ask "  signal number:" signal_number ""
      dim "  who receives it (leave blank to send to yourself):"
      ask "  recipient:" signal_recipient ""
      if [[ -n "$signal_number" ]]; then
        printf 'SIGNAL_NUMBER=%s\n' "$signal_number" >> "$STEWARD_HOME/.env"
        printf 'SIGNAL_RECIPIENT=%s\n' "${signal_recipient:-$signal_number}" >> "$STEWARD_HOME/.env"
      else
        dim "  no number entered — configure SIGNAL_NUMBER/SIGNAL_RECIPIENT in $STEWARD_HOME/.env later."
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
