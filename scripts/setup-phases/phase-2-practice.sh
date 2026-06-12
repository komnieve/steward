#!/usr/bin/env bash
# Phase 2 — practice layer components.
# User picks which components to install from the menu.
# Every selected component becomes a file in $STEWARD_HOME/practice/.

phase_2_practice() {
  heading "Phase 2 — practice layer"
  dim "Steward assumes you're holding work as practice. Each component below is a"
  dim "plain markdown file written to \$STEWARD_HOME/practice/, loaded into Steward's"
  dim "context so it knows what you're trying to live by. Files start as scaffolding"
  dim "with prompts — you rewrite them in your own voice. Delete or edit any of them"
  dim "later; they're just text files."
  echo

  # Each entry: key|short_label|long_description
  # The long description prints before the y/n prompt so the user knows what's
  # actually IN the file before deciding.
  local components=(
"true-north|True North compass|\
A long-horizon orientation — the life you're moving toward, not a deadline-bound goal.
The template asks: what 'further along' looks like in 5–10 years, what you'd let go of
to move toward it, and the cue-question you ask yourself when a choice arises.
Steward uses it to test whether your current focus is moving toward or away from this."

"ambition-as-question|Ambition-as-question|\
Frames ambition as a question you keep returning to, not a fixed answer.
The template asks: what 'the bigger play' could look like for you, and what answers
would feel like a regression from where you are.
Steward surfaces this when you're choosing between low-leverage and high-leverage work."

"wholesomeness-lens|Wholesomeness lens|\
Names the patterns (anger, conceit, complacency, fear, etc.) that — when running —
tend to make your work less skillful. A negative test, not a positive one.
The template asks for 3–5 of your operative patterns, what each looks like in your
day, and a cue-question for each.
Steward uses it to flag when an action you're about to take feeds one of those patterns."

"maintenance-as-practice|Maintenance-as-practice|\
Reframes upkeep — sleep, exercise, inbox, dishes, finances, infrastructure — as
practice rather than overhead.
The template asks: which maintenance domains matter most for you, and how you want
to relate to them.
Steward uses it to keep maintenance on the radar without nagging you about it."

"wholesome-intention|Wholesome intention check|\
A diagnostic frame for the question 'is this wholesome?' — light-touch, not ritualized.
The template asks: when you can't articulate positive intent for an action, what
craving you can release, and the soft check you want Steward to apply.
Steward uses it as a brief check when you commit to a new piece of work — not a gate."

"people-matter|People matter|\
Names the relationships that matter to you and the intention you want to bring to each.
The template asks: per-person notes on how you want to show up — distinct from a CRM
'last contact' field. About *how*, not *when*.
Steward uses it to surface relational moves alongside work moves."

"work-as-practice|Work-as-practice (UPEKHA)|\
The framing that the *how* of work matters as much as the *what* you ship.
The template asks: what 'work as practice' means to you, restraint vs. release, and
the structures you want to surrender into rather than discipline yourself through.
Steward uses it to keep the inner dimension visible as a first-class lens, not an
afterthought to productivity."
  )

  PRACTICE_SELECTED=()

  local line key short_desc long_desc rest choice
  for line in "${components[@]}"; do
    key="${line%%|*}"
    rest="${line#*|}"
    short_desc="${rest%%|*}"
    long_desc="${rest#*|}"
    echo
    printf '%s  %s%s\n' "$C_BOLD" "$short_desc" "$C_RESET"
    while IFS= read -r descline; do
      dim "    $descline"
    done <<< "$long_desc"
    ask_yn "  install $key" choice y
    if [[ "$choice" == "y" ]]; then
      PRACTICE_SELECTED+=("$key")
    fi
  done

  # Always install the spine minimum: a user-lens marker + a placeholder for the negative test.
  # If user deselected everything, warn but proceed.
  if [[ ${#PRACTICE_SELECTED[@]} -eq 0 ]]; then
    rust "  you selected zero components — the practice layer will be empty."
    dim  "  that's allowed, but consider at least one. You can add files to $STEWARD_HOME/practice/ later."
  fi

  # Render each selected template into $STEWARD_HOME/practice/.
  local tpl_dir="$STEWARD_REPO/practice-layer/templates"
  local out_dir="$STEWARD_HOME/practice"
  # ${arr[@]+...} guard: expanding an empty array under set -u is fatal on bash 3.2 (macOS default).
  for key in ${PRACTICE_SELECTED[@]+"${PRACTICE_SELECTED[@]}"}; do
    local src="$tpl_dir/$key.md"
    local dst="$out_dir/$key.md"
    if [[ -f "$src" ]]; then
      cp "$src" "$dst"
      sage "  wrote $dst"
    else
      rust "  missing template: $src (skipped)"
    fi
  done

  # Write a manifest so other phases know what's installed.
  if [[ ${#PRACTICE_SELECTED[@]} -gt 0 ]]; then
    printf '%s\n' "${PRACTICE_SELECTED[@]}" > "$STEWARD_HOME/practice/.installed"
  else
    : > "$STEWARD_HOME/practice/.installed"
  fi
  return 0
}
