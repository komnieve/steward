#!/usr/bin/env bash
# Phase 1 — intention capture.
# Six questions, free text. Writes $STEWARD_HOME/intention.md.

phase_1_intention() {
  heading "Phase 1 — intention"
  dim "Six questions. Take your time. Skip any by pressing enter."
  dim "These answers seed the steward's understanding of what you actually want from this."
  echo

  local q1 q2 q3 q4 q5 q6
  dim "1. What are you hoping this system does for you?"
  ask_multiline "" q1
  echo

  dim "2. If this is working well a year from now, what's different in your life?"
  ask_multiline "" q2
  echo

  dim "3. What do you want this to help you live in line with?"
  dim "   (ethics, values, aspirational ways of being — whatever resonates)"
  ask_multiline "" q3
  echo

  dim "4. What pattern do you most want it to notice when it shows up?"
  dim "   (avoidance, grinding, bargaining, over-preparation — whatever fits)"
  ask_multiline "" q4
  echo

  dim "5. When you're at your best, what's in place?"
  ask_multiline "" q5
  echo

  dim "6. What practice do you lean on?"
  dim "   (meditation, journaling, community, embodied practices, or nothing yet — all valid)"
  ask_multiline "" q6
  echo

  local out="$STEWARD_HOME/intention.md"
  cat > "$out" <<EOF
# Intention

Captured during setup. Edit freely as your sense of things sharpens.

## What I'm hoping this system does for me

${q1:-[not answered]}

## If this is working well a year from now

${q2:-[not answered]}

## What I want this to help me live in line with

${q3:-[not answered]}

## The pattern I most want it to notice

${q4:-[not answered]}

## What's in place when I'm at my best

${q5:-[not answered]}

## The practice I lean on

${q6:-[not answered]}
EOF
  sage "  wrote $out"
  return 0
}
