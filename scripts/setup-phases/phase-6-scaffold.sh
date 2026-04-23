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
  # Schema: activity_log (with source/outcome) + research_queries (with
  # slug/tags/paths for the research workflow). Promoted from the previous
  # setup/create-activity-db.sh orphan.
  local db="$STEWARD_HOME/activity.db"
  if [[ ! -f "$db" ]]; then
    sqlite3 "$db" <<'SQL'
CREATE TABLE activity_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT DEFAULT (datetime('now', 'localtime')),
    project TEXT,
    category TEXT,
    activity TEXT,
    duration_min INTEGER,
    notes TEXT,
    source TEXT DEFAULT 'manual',
    outcome TEXT
);

CREATE INDEX idx_activity_ts ON activity_log(timestamp);
CREATE INDEX idx_activity_project ON activity_log(project);
CREATE INDEX idx_activity_category ON activity_log(category);

-- Research query tracking
-- Use this to track prompts you send to external models (e.g., GPT, Claude)
-- and their responses. Helps you maintain a library of deep research queries.
CREATE TABLE research_queries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    project TEXT,
    status TEXT DEFAULT 'draft',  -- draft, sent, received, reviewed
    model TEXT,                    -- e.g., gpt-5-pro, claude-opus
    tags TEXT,                     -- comma-separated
    summary TEXT,
    prompt_path TEXT,              -- relative path to prompt.md
    response_path TEXT,            -- relative path to response.md
    created_at TEXT DEFAULT (datetime('now', 'localtime')),
    updated_at TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE INDEX idx_rq_project ON research_queries(project);
CREATE INDEX idx_rq_status ON research_queries(status);
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
  # Avoid silently adopting the steward clone itself: the getting-started path
  # tells users to run `cd ~/repos/steward && ./scripts/setup`, so $PWD often IS
  # the steward repo — which is not what they want as `project_root`.
  #
  # Always initialize (empty string) so the config.json heredoc is safe under
  # set -u, even when neither dash nor watcher are enabled.
  : "${STEWARD_PROJECT_ROOT:=}"
  if [[ "${STEWARD_FEAT_DASH:-n}" == "y" || "${STEWARD_FEAT_WATCHER:-n}" == "y" ]]; then
    if [[ -z "$STEWARD_PROJECT_ROOT" ]]; then
      local default_pr=""
      # Resolve both paths and compare (handles symlinks).
      local pwd_real repo_real
      pwd_real="$(cd "$PWD" 2>/dev/null && pwd -P || echo "$PWD")"
      repo_real="$(cd "$STEWARD_REPO" 2>/dev/null && pwd -P || echo "$STEWARD_REPO")"
      if [[ "$pwd_real" != "$repo_real" ]]; then
        default_pr="$PWD"
      fi
      echo
      dim "  git-aware features need a 'project_root' — the path to YOUR work repo."
      dim "  This is what focus-dash/watcher will 'git log' from. It should NOT be the steward clone."
      # Two-step flow so "skip" is actually reachable. `ask` with a non-empty
      # default substitutes blank input → the default, which would silently
      # lock the user into $PWD even when they wanted to skip.
      if [[ -n "$default_pr" ]]; then
        local use_default
        ask_yn "  use current directory ($default_pr) as project_root?" use_default y
        if [[ "$use_default" == "y" ]]; then
          STEWARD_PROJECT_ROOT="$default_pr"
        else
          ask "  project_root (absolute path to your work repo; blank to skip):" STEWARD_PROJECT_ROOT ""
        fi
      else
        dim "  (current directory is the steward repo — won't suggest it as default.)"
        ask "  project_root (absolute path to your work repo; blank to skip):" STEWARD_PROJECT_ROOT ""
      fi
      # Validate a non-blank choice
      if [[ -n "$STEWARD_PROJECT_ROOT" && ! -d "$STEWARD_PROJECT_ROOT" ]]; then
        rust "  warning: '$STEWARD_PROJECT_ROOT' is not a directory — storing anyway; fix in config.json later."
      fi
    fi
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
  "project_root": "${STEWARD_PROJECT_ROOT:-}",
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

  # --- time-awareness hook (opt-in; Claude Code only) ---
  # If the user said yes in phase 5 AND they're on claude-code, install the
  # inject-time.sh hook into ~/.claude/hooks/ and register it in
  # ~/.claude/settings.json. Merges into an existing settings.json if present.
  if [[ "${STEWARD_FEAT_TIMEHOOK:-n}" == "y" ]] && [[ "$STEWARD_RUNTIME" == "claude-code" ]]; then
    local cc_hooks="$HOME/.claude/hooks"
    local cc_settings="$HOME/.claude/settings.json"
    local hook_src="$STEWARD_REPO/hooks/inject-time.sh"
    local hook_dst="$cc_hooks/inject-time.sh"
    ensure_dir "$cc_hooks"
    if [[ -f "$hook_src" ]]; then
      cp "$hook_src" "$hook_dst"
      chmod +x "$hook_dst"
      sage "  installed time hook → $hook_dst"
    fi
    # Merge hook registration into settings.json (preserve existing hooks/config).
    python3 - "$cc_settings" <<'PY' || rust "  could not merge $cc_settings; add the hook manually (see templates/settings.json)"
import json, os, sys
path = sys.argv[1]
want = {
  "type": "command",
  "command": "~/.claude/hooks/inject-time.sh",
  "timeout": 5
}
try:
    if os.path.exists(path):
        with open(path) as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError("settings.json is not an object")
    else:
        data = {}
except Exception as e:
    print(f"(could not parse {path}: {e}); skipping merge", file=sys.stderr)
    sys.exit(1)

hooks = data.setdefault("hooks", {})
ups = hooks.setdefault("UserPromptSubmit", [])

# Look for an existing entry that already registers our command.
def has_cmd(node):
    if not isinstance(node, dict):
        return False
    for h in node.get("hooks", []):
        if isinstance(h, dict) and h.get("command") == want["command"]:
            return True
    return False

if not any(has_cmd(entry) for entry in ups):
    ups.append({"matcher": "", "hooks": [want]})

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print(f"  registered time hook in {path}")
PY
  elif [[ "${STEWARD_FEAT_TIMEHOOK:-n}" == "y" ]] && [[ "$STEWARD_RUNTIME" != "claude-code" ]]; then
    dim "  time hook: skipped (requires claude-code runtime)"
  fi

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
