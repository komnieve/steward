#!/usr/bin/env bash
# Phase 2 — practice layer components.
# User picks which components to install from the menu.
# Every selected component becomes a file in $STEWARD_HOME/practice/.

phase_2_practice() {
  heading "Phase 2 — practice layer"
  dim "Steward assumes you're holding work as practice. The question is which components"
  dim "you want installed. Each is a short markdown file you'll edit to fit you."
  dim "You can always add, remove, or edit these later."
  echo

  local components=(
    "true-north|True North compass — a long-horizon orientation you're moving toward"
    "ambition-as-question|Ambition-as-question — 'what's the bigger play?' as a reflective prompt, not doctrine"
    "wholesomeness-lens|Wholesomeness lens — name your operative patterns; test actions against them"
    "maintenance-as-practice|Maintenance-as-practice — caring for the infrastructure of your life IS practice"
    "wholesome-intention|Wholesome intention check — light, non-ritualized 'is this wholesome?' reflection"
    "people-matter|People matter — how you want to show up in each relationship"
    "work-as-practice|Work-as-practice (UPEKHA) — how you do the work matters as much as what you ship"
  )

  PRACTICE_SELECTED=()

  local line key desc choice
  for line in "${components[@]}"; do
    key="${line%%|*}"
    desc="${line#*|}"
    ask_yn "  install: $desc" choice y
    if [[ "$choice" == "y" ]]; then
      PRACTICE_SELECTED+=("$key")
    fi
  done

  # Always install the spine minimum: a user-lens marker + a placeholder for the negative test.
  # If user deselected everything, warn but proceed.
  if [[ ${#PRACTICE_SELECTED[@]} -eq 0 ]]; then
    rust "  you selected zero components — the practice layer will be empty."
    dim  "  that's allowed, but consider at least one. you can re-run ./scripts/setup --practice-only later."
  fi

  # Render each selected template into $STEWARD_HOME/practice/.
  local tpl_dir="$STEWARD_REPO/practice-layer/templates"
  local out_dir="$STEWARD_HOME/practice"
  for key in "${PRACTICE_SELECTED[@]}"; do
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
  printf '%s\n' "${PRACTICE_SELECTED[@]}" > "$STEWARD_HOME/practice/.installed"
  return 0
}
