#!/usr/bin/env bash
# Phase 5 — optional feature bundles.

phase_5_bundles() {
  heading "Phase 5 — optional features and integrations"
  dim "The default path stays local to $STEWARD_HOME. Anything that edits runtime"
  dim "config, installs Python packages, or starts background services is off by default."
  echo

  STEWARD_FEAT_RESEARCH="n"
  STEWARD_FEAT_PEOPLE="n"
  STEWARD_FEAT_STUCK="y"
  STEWARD_FEAT_TIMEHOOK="n"
  STEWARD_FEAT_TOOLS="y"
  STEWARD_FEAT_DASH="n"
  STEWARD_FEAT_WATCHER="n"
  STEWARD_FEAT_PRACTICE_INTERACTIVE="n"
  STEWARD_FEAT_MEMORY="n"

  dim "  Local files only:"
  ask_yn "  stuck-item tracker (tracks items you keep flagging, escalates the nudge)" STEWARD_FEAT_STUCK y
  ask_yn "  research-query tracking (structured prompt/response folders for deep research)" STEWARD_FEAT_RESEARCH n
  ask_yn "  people table (relational CRM with 'intention' field per person)" STEWARD_FEAT_PEOPLE n

  echo
  dim "  Local tools:"
  ask_yn "  desk + tokens CLIs (copies scripts into $STEWARD_HOME/bin; may offer to install tiktoken later)" STEWARD_FEAT_TOOLS y

  echo
  dim "  Runtime/global integrations:"
  if [[ "$STEWARD_RUNTIME" == "claude-code" ]]; then
    dim "    time-awareness injection edits:"
    dim "      $HOME/.claude/hooks/inject-time.sh"
    dim "      $HOME/.claude/settings.json"
    ask_yn "  enable time-awareness injection for Claude Code sessions?" STEWARD_FEAT_TIMEHOOK n
  else
    dim "    time-awareness injection — skipped (requires claude-code runtime)"
    STEWARD_FEAT_TIMEHOOK="n"
  fi

  case "$STEWARD_RUNTIME" in
    claude-code) dim "    interactive Practice Layer would edit: $HOME/.claude/CLAUDE.md" ;;
    codex)       dim "    interactive Practice Layer would edit: $HOME/.codex/AGENTS.md" ;;
    *)           dim "    interactive Practice Layer has no known global target for runtime: $STEWARD_RUNTIME" ;;
  esac
  ask_yn "  load Practice Layer in interactive sessions?" STEWARD_FEAT_PRACTICE_INTERACTIVE n

  echo
  dim "  Heavier local features:"
  dim "    Steward Memory installs torch + sentence-transformers (~2GB) and downloads"
  dim "    ~600MB of model weights on first index. Skip on lighter machines."
  ask_yn "  Steward Memory (local hybrid search over selected files; opt-in, heavier install)" STEWARD_FEAT_MEMORY n

  echo
  dim "  Background/browser features:"
  ask_yn "  focus-dash (browser dashboard at localhost:8888; installs files now, launchd load is separate)" STEWARD_FEAT_DASH n

  if [[ "$STEWARD_OS" == "macos" && "$STEWARD_RUNTIME" == "claude-code" ]]; then
    dim "    focus watcher requires macOS Screen Recording and Accessibility permissions."
    ask_yn "  focus watcher (periodic screenshot → mindfulness nudges; macOS + claude-code only)" STEWARD_FEAT_WATCHER n
  elif [[ "$STEWARD_OS" != "macos" ]]; then
    dim "  focus watcher — skipped (macOS only)"
    STEWARD_FEAT_WATCHER="n"
  else
    dim "  focus watcher — skipped (the vision pass requires the claude-code runtime)"
    STEWARD_FEAT_WATCHER="n"
  fi

  return 0
}
