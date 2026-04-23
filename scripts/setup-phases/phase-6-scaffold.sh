#!/usr/bin/env bash
# Phase 6 — render templates, initialize DB, write runtime adapter config.

phase_6_scaffold() {
  heading "Phase 6 — scaffolding"

  # --- Persona file (the main context document for every steward run) ---
  local persona_src="$STEWARD_REPO/templates/steward-persona.md"
  local persona_dst="$STEWARD_HOME/persona.md"
  if [[ -f "$persona_src" ]]; then
    cp "$persona_src" "$persona_dst"
    sage "  wrote $persona_dst"
  fi

  # --- Status.md starter ---
  local status_dst="$STEWARD_HOME/status.md"
  if [[ ! -f "$status_dst" ]]; then
    cat > "$status_dst" <<EOF
# Status — ${STEWARD_USER_NAME:-your} work

Primary state file the steward reads every run.

## Deadlines

| Date | Item | Project |
|------|------|---------|

## Active threads

| Thread | Status | Next action |
|--------|--------|-------------|

## Work log

One line per shipped thing. Answers "what did I actually do this week?"
EOF
    sage "  wrote $status_dst"
  fi

  # --- activity.db ---
  local db="$STEWARD_HOME/activity.db"
  if [[ ! -f "$db" ]]; then
    sqlite3 "$db" <<'SQL'
CREATE TABLE activity_log (
  id INTEGER PRIMARY KEY,
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  project TEXT,
  category TEXT,
  activity TEXT,
  duration_min INTEGER,
  notes TEXT
);
CREATE INDEX idx_activity_timestamp ON activity_log(timestamp);
CREATE INDEX idx_activity_project ON activity_log(project);

CREATE TABLE research_query (
  id INTEGER PRIMARY KEY,
  timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  folder TEXT,
  title TEXT,
  status TEXT,
  model TEXT,
  notes TEXT
);
SQL
    sage "  wrote $db"
  fi

  # --- stuck.json ---
  if [[ "${STEWARD_FEAT_STUCK:-y}" == "y" ]]; then
    local stuck="$STEWARD_HOME/stuck.json"
    [[ -f "$stuck" ]] || printf '{"items":{}}\n' > "$stuck"
    sage "  wrote $stuck"
  fi

  # --- project root (used by focus-dash + watcher to locate the git repo) ---
  if [[ -z "${STEWARD_PROJECT_ROOT:-}" ]]; then
    STEWARD_PROJECT_ROOT="$PWD"
    export STEWARD_PROJECT_ROOT
  fi

  # --- config.json ---
  local cfg="$STEWARD_HOME/config.json"
  cat > "$cfg" <<EOF
{
  "user": "${STEWARD_USER_NAME:-user}",
  "runtime": "$STEWARD_RUNTIME",
  "delivery": "$STEWARD_DELIVERY",
  "schedule": "$STEWARD_SCHEDULE",
  "project_root": "$STEWARD_PROJECT_ROOT",
  "features": {
    "stuck_tracker": "${STEWARD_FEAT_STUCK:-n}",
    "time_hook":     "${STEWARD_FEAT_TIMEHOOK:-n}",
    "research":      "${STEWARD_FEAT_RESEARCH:-n}",
    "people_table":  "${STEWARD_FEAT_PEOPLE:-n}",
    "tools":         "${STEWARD_FEAT_TOOLS:-n}",
    "focus_dash":    "${STEWARD_FEAT_DASH:-n}",
    "focus_watcher": "${STEWARD_FEAT_WATCHER:-n}"
  }
}
EOF
  sage "  wrote $cfg"

  # --- runtime adapter ---
  case "$STEWARD_RUNTIME" in
    claude-code)
      local cc_src="$STEWARD_REPO/runtimes/claude-code/CLAUDE.md.template"
      local cc_dst="$STEWARD_HOME/CLAUDE.md"
      if [[ -f "$cc_src" ]]; then
        cp "$cc_src" "$cc_dst"
        sage "  wrote $cc_dst (Claude Code adapter)"
      fi
      ;;
    codex)
      local cx_src="$STEWARD_REPO/runtimes/codex/AGENTS.md.template"
      local cx_dst="$STEWARD_HOME/AGENTS.md"
      if [[ -f "$cx_src" ]]; then
        cp "$cx_src" "$cx_dst"
        sage "  wrote $cx_dst (Codex adapter)"
      fi
      ;;
  esac

  # --- scheduler install (with confirmation) ---
  if [[ "$STEWARD_SCHEDULE" != "none" ]]; then
    local confirm
    ask_yn "  install $STEWARD_OS scheduler entries for $STEWARD_SCHEDULE checks?" confirm n
    if [[ "$confirm" == "y" ]]; then
      dim "  (scheduler install not yet wired — see guides/scheduling.md for manual setup)"
      dim "  you can add cron/launchd entries later pointing at $STEWARD_REPO/scripts/daily-check.sh"
    fi
  fi

  return 0
}
