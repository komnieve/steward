#!/usr/bin/env bash
# Phase 0 — prerequisite check.
# Inputs:  STEWARD_HOME, STEWARD_REPO, FORCE (y/n).
# Outputs: STEWARD_RUNTIME ("claude-code"|"codex"|"none"), STEWARD_OS, $STEWARD_HOME/ created.

phase_0_check() {
  heading "Phase 0 — checking your environment"

  # OS detection.
  case "$(uname -s)" in
    Darwin) STEWARD_OS="macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then STEWARD_OS="wsl"; else STEWARD_OS="linux"; fi
      ;;
    *) STEWARD_OS="unknown" ;;
  esac
  say "  os: $STEWARD_OS"

  # Agent runtime detection.
  STEWARD_RUNTIME="none"
  if have_cmd claude; then
    STEWARD_RUNTIME="claude-code"
    say "  runtime: claude-code (claude CLI on PATH)"
  elif have_cmd codex; then
    STEWARD_RUNTIME="codex"
    say "  runtime: codex (codex CLI on PATH)"
  else
    rust "  runtime: NONE detected."
    dim  "    Steward works best with an agent runtime like Claude Code or Codex."
    dim  "    Install one:"
    dim  "      claude-code: https://claude.com/product/claude-code"
    dim  "      codex:       https://github.com/openai/codex"
    local cont
    ask_yn "  continue anyway? (setup can still scaffold files, but daily use needs a runtime)" cont n
    if [[ "$cont" != "y" ]]; then
      say "  stopping. install a runtime and re-run ./scripts/setup"
      return 1
    fi
  fi

  # sqlite3 check.
  if ! have_cmd sqlite3; then
    rust "  sqlite3 not found"
    dim  "    Steward uses SQLite for the activity log. Install sqlite3 and re-run."
    dim  "      macos: brew install sqlite"
    dim  "      linux/wsl: sudo apt install sqlite3  (or your pkg manager)"
    return 1
  fi
  say "  sqlite3: ok"

  # API key check (informational — we don't fail if missing; user may set via runtime config).
  if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    say "  api key: ANTHROPIC_API_KEY detected"
  elif [[ -n "${OPENAI_API_KEY:-}" ]]; then
    say "  api key: OPENAI_API_KEY detected"
  else
    dim "  api key: none in env (your runtime may have its own config; that's fine)"
  fi

  # $STEWARD_HOME creation.
  if [[ -d "$STEWARD_HOME" ]]; then
    if [[ "${FORCE:-n}" == "y" ]]; then
      rust "  $STEWARD_HOME already exists — --force given, will overwrite files as needed"
    else
      rust "  $STEWARD_HOME already exists"
      dim  "    re-run with --force to overwrite, or back it up first and remove it."
      return 1
    fi
  else
    mkdir -p "$STEWARD_HOME"
    say "  created $STEWARD_HOME"
  fi

  ensure_dir "$STEWARD_HOME/practice"
  ensure_dir "$STEWARD_HOME/personas"
  ensure_dir "$STEWARD_HOME/logs"
  return 0
}
