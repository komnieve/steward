#!/usr/bin/env bash
# Phase 7 — local preview. Optional.

phase_7_firstrun() {
  heading "Phase 7 — local preview"
  local choice
  ask_yn "  write a local preview of what Steward will read?" choice y
  if [[ "$choice" != "y" ]]; then
    dim "  skipped. run ./scripts/daily-check.sh whenever you're ready."
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
  dim "  When you're ready for a real steward check, run:"
  say "    bash $STEWARD_REPO/scripts/daily-check.sh"
  return 0
}
