#!/usr/bin/env bash
# Common helpers sourced by every setup phase.

# Colors (fall back to empty on non-tty).
if [[ -t 1 ]]; then
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RUST=$'\033[38;5;124m'
  C_SAGE=$'\033[38;5;65m'
  C_RESET=$'\033[0m'
else
  C_BOLD=''; C_DIM=''; C_RUST=''; C_SAGE=''; C_RESET=''
fi

say()    { printf '%s\n' "$*"; }
heading(){ printf '\n%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
dim()    { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
rust()   { printf '%s%s%s\n' "$C_RUST" "$*" "$C_RESET"; }
sage()   { printf '%s%s%s\n' "$C_SAGE" "$*" "$C_RESET"; }

# ask TEXT VAR [DEFAULT] — single-line prompt, stores in VAR.
ask() {
  local prompt="$1" varname="$2" default="${3:-}"
  local value
  if [[ -n "$default" ]]; then
    printf '%s %s[%s]%s ' "$prompt" "$C_DIM" "$default" "$C_RESET"
  else
    printf '%s ' "$prompt"
  fi
  read -r value || value=''
  value="${value:-$default}"
  printf -v "$varname" '%s' "$value"
}

# ask_yn TEXT VAR DEFAULT(y|n)
ask_yn() {
  local prompt="$1" varname="$2" default="${3:-n}"
  local value
  local hint
  if [[ "$default" == "y" ]]; then hint="[Y/n]"; else hint="[y/N]"; fi
  while true; do
    printf '%s %s%s%s ' "$prompt" "$C_DIM" "$hint" "$C_RESET"
    read -r value || value=''
    value="${value,,}"
    value="${value:-$default}"
    case "$value" in
      y|yes) printf -v "$varname" '%s' 'y'; return 0 ;;
      n|no)  printf -v "$varname" '%s' 'n'; return 0 ;;
      *) say "  please answer y or n" ;;
    esac
  done
}

# ask_multiline TEXT VAR — read until an empty line, stores in VAR.
ask_multiline() {
  local prompt="$1" varname="$2"
  dim "$prompt (finish with an empty line)"
  local line value=''
  while IFS= read -r line; do
    [[ -z "$line" ]] && break
    value+="$line"$'\n'
  done
  printf -v "$varname" '%s' "$value"
}

# write_file PATH CONTENT — creates parent dir, writes content.
write_file() {
  local path="$1"; shift
  mkdir -p "$(dirname "$path")"
  printf '%s' "$*" > "$path"
}

# append_file PATH CONTENT
append_file() {
  local path="$1"; shift
  mkdir -p "$(dirname "$path")"
  printf '%s' "$*" >> "$path"
}

# render_template SRC DST [VAR1=VAL1 VAR2=VAL2 ...]
# Substitutes {{VAR}} in SRC with VAL, writes to DST.
render_template() {
  local src="$1" dst="$2"; shift 2
  mkdir -p "$(dirname "$dst")"
  local content
  content="$(cat "$src")"
  while [[ $# -gt 0 ]]; do
    local kv="$1"; shift
    local key="${kv%%=*}"
    local val="${kv#*=}"
    # Escape | to avoid sed delimiter clash
    local esc_val
    esc_val="$(printf '%s' "$val" | sed 's/[|&\\]/\\&/g')"
    content="$(printf '%s' "$content" | sed "s|{{$key}}|$esc_val|g")"
  done
  printf '%s' "$content" > "$dst"
}

# require_cmd CMD [FRIENDLY_NAME]
require_cmd() {
  local cmd="$1" name="${2:-$1}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    say "${C_RUST}missing: $name${C_RESET}"
    return 1
  fi
  return 0
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ensure_dir PATH
ensure_dir() {
  mkdir -p "$1"
}
