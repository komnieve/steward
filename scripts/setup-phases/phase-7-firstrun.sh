#!/usr/bin/env bash
# Phase 7 — first run + local preview.

phase_7_firstrun() {
  heading "Phase 7 — meet your steward"

  # The interview is done. Before anything else, let the steward actually speak —
  # ending setup without a first run is how people conclude "it didn't do anything."
  local runchoice
  if [[ "$STEWARD_RUNTIME" != "none" ]]; then
    say "  the interview is done. your steward can do its first check-in right now —"
    dim "  it reads what you just wrote and says something back. takes a minute or two."
    ask_yn "  run your first steward check now?" runchoice y
    if [[ "$runchoice" == "y" ]]; then
      echo
      if FORCE=1 MODE=morning bash "$STEWARD_REPO/scripts/daily-check.sh"; then
        echo
        sage "  ✓ that was your steward's first check-in."
      else
        rust "  the first check didn't complete — setup itself is still fine."
        dim  "    look at $STEWARD_HOME/logs/morning.log, then try again with:"
        dim  "    bash $STEWARD_REPO/scripts/daily-check.sh"
      fi
    else
      dim "  skipped. run it anytime: bash $STEWARD_REPO/scripts/daily-check.sh"
    fi
  else
    dim "  no agent runtime installed, so skipping the first check."
    dim "  once you install one, run: bash $STEWARD_REPO/scripts/daily-check.sh"
  fi
  echo

  local choice
  ask_yn "  also write a local preview of what Steward reads each day?" choice n
  if [[ "$choice" != "y" ]]; then
    return 0
  fi

  local preview="$STEWARD_HOME/setup-preview.md"
  {
    echo "# Steward setup preview"
    echo
    echo "Created on $(date '+%Y-%m-%d %H:%M %Z')."
    echo
    echo "## What daily checks will read"
    echo
    echo "- $STEWARD_HOME/user-lens.md"
    echo "- $STEWARD_HOME/persona.md"
    echo "- $STEWARD_HOME/intention.md"
    echo "- $STEWARD_HOME/status.md"
    echo "- $STEWARD_HOME/activity.db"
    echo "- $STEWARD_HOME/practice/*.md"
    echo
    echo "## Installed practice files"
    if [[ -d "$STEWARD_HOME/practice" ]]; then
      local f
      for f in "$STEWARD_HOME"/practice/*.md; do
        [[ -f "$f" ]] && echo "- $f"
      done
    fi
    echo
    echo "## Runtime and delivery"
    echo
    echo "- runtime: $STEWARD_RUNTIME"
    echo "- delivery: $STEWARD_DELIVERY"
    echo "- schedule: $STEWARD_SCHEDULE"
    echo
    echo "## Manual commands"
    echo
    echo "\`\`\`bash"
    echo "bash $STEWARD_REPO/scripts/daily-check.sh"
    echo "bash $STEWARD_REPO/scripts/evening-check.sh"
    echo "\`\`\`"
  } > "$preview"
  sage "  wrote $preview"
  dim "  This preview is local only; it does not call your agent runtime."
  return 0
}
