#!/usr/bin/env bash
# Phase 7 — first run smoke test. Optional.

phase_7_firstrun() {
  heading "Phase 7 — first run (optional smoke test)"
  local choice
  ask_yn "  run a first steward check now so you can see if it works?" choice y
  if [[ "$choice" != "y" ]]; then
    dim "  skipped. run ./scripts/daily-check.sh whenever you're ready."
    return 0
  fi

  if [[ "$STEWARD_RUNTIME" == "none" ]]; then
    rust "  no agent runtime installed — can't run a real steward check."
    dim  "  you'll see files scaffolded, but nothing to drive them yet. install claude-code or codex."
    return 0
  fi

  dim "  (a full first-run invocation is deferred to v0.3 — this is a setup script,"
  dim "   and your runtime may need its own auth step first.)"
  dim "  when you're ready, run one of:"
  say "    bash $STEWARD_REPO/scripts/daily-check.sh"
  say "    bash $STEWARD_REPO/scripts/evening-check.sh"
  return 0
}
