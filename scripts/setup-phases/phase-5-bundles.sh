#!/usr/bin/env bash
# Phase 5 — optional feature bundles.

phase_5_bundles() {
  heading "Phase 5 — optional features"
  dim "Pick what you want. Most users start with defaults and add more later."
  echo

  STEWARD_FEAT_RESEARCH="n"
  STEWARD_FEAT_PEOPLE="n"
  STEWARD_FEAT_STUCK="y"
  STEWARD_FEAT_TIMEHOOK="y"
  STEWARD_FEAT_TOOLS="y"
  STEWARD_FEAT_DASH="n"
  STEWARD_FEAT_WATCHER="n"

  ask_yn "  stuck-item tracker (tracks items you keep flagging, escalates the nudge)" STEWARD_FEAT_STUCK y
  ask_yn "  time-awareness injection (stamps every prompt with current time + elapsed since last)" STEWARD_FEAT_TIMEHOOK y
  ask_yn "  research-query tracking (structured prompt/response folders for deep research)" STEWARD_FEAT_RESEARCH n
  ask_yn "  people table (relational CRM with 'intention' field per person)" STEWARD_FEAT_PEOPLE n

  echo
  dim "  ---"
  ask_yn "  desk + tokens CLIs (priorities editor + token counter)" STEWARD_FEAT_TOOLS y
  ask_yn "  focus-dash (browser dashboard at localhost:8888; requires your runtime's CLI)" STEWARD_FEAT_DASH n

  if [[ "$STEWARD_OS" == "macos" ]]; then
    ask_yn "  focus watcher (periodic screenshot → mindfulness nudges; macOS only)" STEWARD_FEAT_WATCHER n
  else
    dim "  focus watcher — skipped (macOS only)"
    STEWARD_FEAT_WATCHER="n"
  fi

  return 0
}
