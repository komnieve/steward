#!/usr/bin/env bash
# Phase 8 — handoff summary.

phase_8_handoff() {
  heading "Phase 8 — you're set up"
  echo
  sage "  ✓ Setup is complete. Your steward is ready."
  echo
  say  "  The one thing to do next — run this each morning:"
  say  "    bash $STEWARD_REPO/scripts/daily-check.sh"
  dim  "  (or schedule it so it arrives on its own — see guides/getting-started.md.)"
  echo
  sage "  Steward home:    $STEWARD_HOME"
  sage "  Runtime:         $STEWARD_RUNTIME"
  sage "  Delivery:        $STEWARD_DELIVERY"
  sage "  Schedule:        $STEWARD_SCHEDULE"
  echo
  say "  Files you now own (edit freely — this is yours):"
  say "    $STEWARD_HOME/intention.md       — what you want from this"
  say "    $STEWARD_HOME/user-lens.md       — who you are at your best"
  say "    $STEWARD_HOME/persona.md         — how the steward speaks to you"
  say "    $STEWARD_HOME/status.md          — your active threads"
  say "    $STEWARD_HOME/practice/          — the practice components you chose"
  say "    $STEWARD_HOME/activity.db        — your event log (sqlite)"
  say "    $STEWARD_HOME/config.json        — runtime/delivery/feature config"
  if [[ -f "$STEWARD_HOME/setup-preview.md" ]]; then
    say "    $STEWARD_HOME/setup-preview.md   — local preview of what checks will read"
  fi
  echo
  say "  Day-to-day:"
  say "    $STEWARD_REPO/scripts/daily-check.sh      — morning steward check"
  say "    $STEWARD_REPO/scripts/evening-check.sh    — evening steward check"
  echo
  say "  Re-shape later:"
  say "    ./scripts/setup --force           — re-run setup and overwrite generated files"
  say "    edit $STEWARD_HOME/*.md           — directly"
  echo
  dim "  Intentions shift. That's the point. Come back whenever something needs to change."
  echo
}
