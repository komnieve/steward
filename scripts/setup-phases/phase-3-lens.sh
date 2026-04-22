#!/usr/bin/env bash
# Phase 3 — user lens.
# Short guided capture. Writes $STEWARD_HOME/user-lens.md.

phase_3_lens() {
  heading "Phase 3 — user lens"
  dim "A short file describing who you are when you're at your best and how to work with you."
  dim "The steward loads this every run. Edit freely; this is yours."
  echo

  local name role working_well trip_up witness communication
  ask "  Your name:" name
  echo
  dim "  What you do (one or two sentences):"
  ask_multiline "" role
  echo
  dim "  When you're working well, what's true about you?"
  ask_multiline "" working_well
  echo
  dim "  What trips you up?"
  ask_multiline "" trip_up
  echo
  dim "  What do you want the steward to witness when it shows up?"
  dim "  (a win? a pattern breaking? a quiet day honored?)"
  ask_multiline "" witness
  echo
  dim "  How do you communicate when you're at your best vs. drained?"
  ask_multiline "" communication
  echo

  local out="$STEWARD_HOME/user-lens.md"
  cat > "$out" <<EOF
# User lens — ${name:-[your name]}

Load this at the start of every session, steward run, or persona tick.
These are settled observations, not aspirations.

## What I do

${role:-[not answered]}

## When I'm working well

${working_well:-[not answered]}

## What trips me up

${trip_up:-[not answered]}

## What I want witnessed when it happens

${witness:-[not answered]}

## How I communicate

${communication:-[not answered]}

## Override — rest mode

When I name depletion (illness, grief, retreat after-effects, genuine overwhelm),
the tone shifts to rest, not push. Trust me when I name it.
EOF
  sage "  wrote $out"
  # Export for later phases.
  STEWARD_USER_NAME="${name:-user}"
  return 0
}
