#!/usr/bin/env bash
# Phase 6c — install focus watcher (macOS only) if opted in.

phase_6c_watcher() {
  [[ "${STEWARD_FEAT_WATCHER:-n}" != "y" ]] && return 0
  if [[ "$STEWARD_OS" != "macos" ]]; then
    dim "  focus watcher: skipped (macOS only, detected $STEWARD_OS)"
    return 0
  fi
  # The vision pass needs multimodal input; only claude-code's CLI shape is
  # wired for it today. Gate instead of installing a silently-broken bundle.
  if [[ "$STEWARD_RUNTIME" != "claude-code" ]]; then
    dim "  focus watcher: skipped (requires STEWARD_RUNTIME=claude-code; got $STEWARD_RUNTIME)"
    return 0
  fi
  heading "Phase 6c — focus watcher"

  local src="$STEWARD_REPO/personas/focus"
  local dst="$STEWARD_HOME/personas/focus"
  ensure_dir "$dst"
  ensure_dir "$dst/screenshots"
  ensure_dir "$STEWARD_HOME/log"

  cp "$src/CLAUDE.md"        "$dst/CLAUDE.md"
  cp "$src/focus-check.sh"   "$dst/focus-check.sh"
  cp "$src/focus-loop.sh"    "$dst/focus-loop.sh"
  cp "$src/quote-finder.sh"  "$dst/quote-finder.sh"
  cp "$src/quotes.md"        "$dst/quotes.md"
  cp "$src/README.md"        "$dst/README.md"
  cp "$src/.gitignore"       "$dst/.gitignore" 2>/dev/null || true
  chmod +x "$dst/focus-check.sh" "$dst/focus-loop.sh" "$dst/quote-finder.sh"

  # Initialize focus.db
  if [[ ! -f "$dst/focus.db" ]]; then
    sqlite3 "$dst/focus.db" <<'SQL'
CREATE TABLE IF NOT EXISTS focus_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp TEXT NOT NULL,
  active_app TEXT,
  active_window TEXT,
  all_windows TEXT,
  assessment TEXT,
  is_drift INTEGER DEFAULT 0,
  screenshot_path TEXT,
  acknowledged_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_focus_ts ON focus_log(timestamp);
SQL
    sage "  initialized focus.db"
  fi

  sage "  installed watcher → $dst"

  # Render launchd plists
  local plist_src="$src/launchd"
  local plist_dst="$dst/launchd"
  ensure_dir "$plist_dst"
  render_template "$plist_src/com.steward.focus-loop.plist.template" \
    "$plist_dst/com.steward.focus-loop.plist" \
    "STEWARD_HOME=$STEWARD_HOME" \
    "STEWARD_PROJECT_ROOT=${STEWARD_PROJECT_ROOT:-}" \
    "STEWARD_RUNTIME=$STEWARD_RUNTIME"
  render_template "$plist_src/com.steward.quote-finder.plist.template" \
    "$plist_dst/com.steward.quote-finder.plist" \
    "STEWARD_HOME=$STEWARD_HOME" \
    "STEWARD_RUNTIME=$STEWARD_RUNTIME"
  sage "  rendered launchd plists → $plist_dst/"

  rust "  IMPORTANT: the watcher needs two macOS permissions:"
  dim  "    1. Screen Recording (for screencapture of all monitors)"
  dim  "    2. Accessibility / Automation (for AppleScript to read window titles)"
  dim  "    Both will be prompted on first run. Grant them, then restart the loop."
  echo

  local install_agents
  ask_yn "  copy plists to ~/Library/LaunchAgents and launchctl load now?" install_agents n
  if [[ "$install_agents" == "y" ]]; then
    cp "$plist_dst/com.steward.focus-loop.plist"    "$HOME/Library/LaunchAgents/"
    cp "$plist_dst/com.steward.quote-finder.plist"  "$HOME/Library/LaunchAgents/"
    launchctl unload "$HOME/Library/LaunchAgents/com.steward.focus-loop.plist"   2>/dev/null || true
    launchctl unload "$HOME/Library/LaunchAgents/com.steward.quote-finder.plist" 2>/dev/null || true
    launchctl load   "$HOME/Library/LaunchAgents/com.steward.focus-loop.plist"
    launchctl load   "$HOME/Library/LaunchAgents/com.steward.quote-finder.plist"
    sage "  loaded. first tick will trigger macOS permission prompts."
  else
    dim "  to install later:"
    dim "    cp $plist_dst/com.steward.focus-loop.plist   ~/Library/LaunchAgents/"
    dim "    cp $plist_dst/com.steward.quote-finder.plist ~/Library/LaunchAgents/"
    dim "    launchctl load ~/Library/LaunchAgents/com.steward.focus-loop.plist"
    dim "    launchctl load ~/Library/LaunchAgents/com.steward.quote-finder.plist"
  fi

  return 0
}
