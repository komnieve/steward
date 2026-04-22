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

  ask_yn "  stuck-item tracker (tracks items you keep flagging, escalates the nudge)" STEWARD_FEAT_STUCK y
  ask_yn "  time-awareness injection (stamps every prompt with current time + elapsed since last)" STEWARD_FEAT_TIMEHOOK y
  ask_yn "  research-query tracking (structured prompt/response folders for deep research)" STEWARD_FEAT_RESEARCH n
  ask_yn "  people table (relational CRM with 'intention' field per person)" STEWARD_FEAT_PEOPLE n

  dim "  tools: desk and tokens CLIs are installed by default (they're small and portable)"
  return 0
}
