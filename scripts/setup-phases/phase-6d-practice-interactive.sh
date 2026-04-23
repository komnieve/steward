#!/usr/bin/env bash
# Phase 6d — optional: wire the installed Practice Layer into the user's
# runtime so interactive sessions (not just scheduled steward runs) load it.
#
# Generic across runtimes. For each runtime we know about, append a marked
# block to its global config file. Idempotent: the block is guarded by
# unique markers so re-running setup doesn't duplicate.
#
# Non-destructive: existing config is preserved verbatim; we only append.
# Removal is a single sed invocation bracketed by the same markers.

PL_MARK_BEGIN="<!-- steward:practice-layer:begin — managed by ./scripts/setup; edit outside these markers -->"
PL_MARK_END="<!-- steward:practice-layer:end -->"

phase_6d_practice_interactive() {
  [[ "${STEWARD_FEAT_PRACTICE_INTERACTIVE:-n}" != "y" ]] && return 0

  # Require some practice files to actually be installed.
  local practice_dir="$STEWARD_HOME/practice"
  if [[ ! -d "$practice_dir" ]] || [[ -z "$(ls -A "$practice_dir" 2>/dev/null)" ]]; then
    dim "  practice-interactive: no files in $practice_dir — skipping"
    return 0
  fi

  heading "Phase 6d — load Practice Layer in interactive sessions"

  case "$STEWARD_RUNTIME" in
    claude-code)
      _pl_wire_file "$HOME/.claude/CLAUDE.md" "$practice_dir"
      ;;
    codex)
      _pl_wire_file "$HOME/.codex/AGENTS.md" "$practice_dir"
      ;;
    *)
      dim "  runtime $STEWARD_RUNTIME — no known global config file for your agent."
      dim "  to get the Practice Layer loaded in interactive sessions, add this snippet"
      dim "  to your runtime's global context file (wherever that lives):"
      _pl_print_snippet "$practice_dir"
      ;;
  esac
  return 0
}

# Append (or refresh) a marker-bracketed practice-layer block in the target
# config file. Creates the file if missing. Idempotent.
_pl_wire_file() {
  local target="$1" practice_dir="$2"
  mkdir -p "$(dirname "$target")"
  local snippet
  snippet="$(_pl_render_snippet "$practice_dir")"

  if [[ ! -f "$target" ]]; then
    {
      echo "$PL_MARK_BEGIN"
      echo "$snippet"
      echo "$PL_MARK_END"
    } > "$target"
    sage "  wrote $target (new file)"
    return
  fi

  # If marker block already present, replace its contents in place.
  if grep -q "steward:practice-layer:begin" "$target"; then
    python3 - "$target" "$practice_dir" "$PL_MARK_BEGIN" "$PL_MARK_END" <<'PY'
import sys, re
target, practice_dir, begin, end = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
snippet_lines = [
    "",
    "## Practice Layer (loaded at session start)",
    "",
    f"Read these files when the session begins. They define how the user wants to be held:",
    "",
]
import os
for name in sorted(os.listdir(practice_dir)):
    if name.endswith(".md"):
        snippet_lines.append(f"- `{practice_dir}/{name}`")
snippet_lines += [
    "",
    "Use them as shaping priors — do not recite them back to the user.",
    "",
]
snippet = "\n".join(snippet_lines)
with open(target) as f:
    body = f.read()
pattern = re.compile(re.escape(begin) + r".*?" + re.escape(end), re.DOTALL)
replacement = begin + "\n" + snippet + end
new_body = pattern.sub(replacement, body)
with open(target, "w") as f:
    f.write(new_body)
PY
    sage "  refreshed practice-layer block in $target"
  else
    {
      echo ""
      echo "$PL_MARK_BEGIN"
      echo "$snippet"
      echo "$PL_MARK_END"
    } >> "$target"
    sage "  appended practice-layer block to $target"
  fi
}

# Render the markdown snippet listing all practice/*.md files.
_pl_render_snippet() {
  local practice_dir="$1"
  echo ""
  echo "## Practice Layer (loaded at session start)"
  echo ""
  echo "Read these files when the session begins. They define how the user wants to be held:"
  echo ""
  local f
  for f in "$practice_dir"/*.md; do
    [[ -f "$f" ]] && echo "- \`$f\`"
  done
  echo ""
  echo "Use them as shaping priors — do not recite them back to the user."
  echo ""
}

_pl_print_snippet() {
  local practice_dir="$1"
  echo ""
  echo "$PL_MARK_BEGIN"
  _pl_render_snippet "$practice_dir"
  echo "$PL_MARK_END"
  echo ""
}
