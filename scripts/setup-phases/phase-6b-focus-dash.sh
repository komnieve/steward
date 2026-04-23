#!/usr/bin/env bash
# Phase 6b — install focus-dash if opted in.

phase_6b_focus_dash() {
  [[ "${STEWARD_FEAT_DASH:-n}" != "y" ]] && return 0
  heading "Phase 6b — focus-dash"

  local src="$STEWARD_REPO/focus-dash"
  local dst="$STEWARD_HOME/focus-dash"
  ensure_dir "$dst"
  ensure_dir "$dst/fonts"
  ensure_dir "$STEWARD_HOME/log"

  cp "$src/server.py"   "$dst/server.py"
  cp "$src/index.html"  "$dst/index.html"
  cp "$src/refresh.sh"  "$dst/refresh.sh"
  cp "$src/prompt.md"   "$dst/prompt.md"
  cp "$src/README.md"   "$dst/README.md"
  chmod +x "$dst/refresh.sh"

  # fonts (if present)
  if [[ -d "$src/fonts" ]]; then
    cp -r "$src/fonts/." "$dst/fonts/"
  fi

  # priorities.json — only install skeleton if user doesn't already have one
  if [[ ! -f "$dst/priorities.json" ]]; then
    cp "$src/priorities.skeleton.json" "$dst/priorities.json"
    sage "  wrote $dst/priorities.json (starter)"
  else
    dim "  priorities.json already exists — kept as-is"
  fi

  sage "  installed focus-dash → $dst"

  # Launchd plists (macOS only)
  if [[ "$STEWARD_OS" == "macos" ]]; then
    local plist_src="$src/launchd"
    local plist_dst="$STEWARD_HOME/focus-dash/launchd"
    ensure_dir "$plist_dst"
    render_template "$plist_src/com.steward.focus-dash.plist.template" \
      "$plist_dst/com.steward.focus-dash.plist" \
      "STEWARD_HOME=$STEWARD_HOME" \
      "STEWARD_PROJECT_ROOT=${STEWARD_PROJECT_ROOT:-}" \
      "STEWARD_RUNTIME=$STEWARD_RUNTIME"
    render_template "$plist_src/com.steward.focus-dash-refresh.plist.template" \
      "$plist_dst/com.steward.focus-dash-refresh.plist" \
      "STEWARD_HOME=$STEWARD_HOME" \
      "STEWARD_PROJECT_ROOT=${STEWARD_PROJECT_ROOT:-}" \
      "STEWARD_RUNTIME=$STEWARD_RUNTIME"
    sage "  rendered launchd plists → $plist_dst/"

    local install_agents
    ask_yn "  copy plists to ~/Library/LaunchAgents and launchctl load now?" install_agents n
    if [[ "$install_agents" == "y" ]]; then
      cp "$plist_dst/com.steward.focus-dash.plist"         "$HOME/Library/LaunchAgents/"
      cp "$plist_dst/com.steward.focus-dash-refresh.plist" "$HOME/Library/LaunchAgents/"
      launchctl unload "$HOME/Library/LaunchAgents/com.steward.focus-dash.plist"          2>/dev/null || true
      launchctl unload "$HOME/Library/LaunchAgents/com.steward.focus-dash-refresh.plist"  2>/dev/null || true
      launchctl load   "$HOME/Library/LaunchAgents/com.steward.focus-dash.plist"
      launchctl load   "$HOME/Library/LaunchAgents/com.steward.focus-dash-refresh.plist"
      sage "  loaded. open http://localhost:8888/"
    else
      dim "  to install later:"
      dim "    cp $plist_dst/com.steward.focus-dash.plist         ~/Library/LaunchAgents/"
      dim "    cp $plist_dst/com.steward.focus-dash-refresh.plist ~/Library/LaunchAgents/"
      dim "    launchctl load ~/Library/LaunchAgents/com.steward.focus-dash.plist"
      dim "    launchctl load ~/Library/LaunchAgents/com.steward.focus-dash-refresh.plist"
    fi
  else
    dim "  non-macOS: use systemd/cron/tmux to run server.py + schedule refresh.sh"
    dim "    server:  STEWARD_HOME=$STEWARD_HOME python3 $dst/server.py"
    dim "    refresh: STEWARD_HOME=$STEWARD_HOME STEWARD_RUNTIME=$STEWARD_RUNTIME $dst/refresh.sh cron"
  fi

  return 0
}
