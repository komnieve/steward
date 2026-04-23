#!/usr/bin/env bash
# Phase 6a — install desk + tokens CLIs if opted in.

phase_6a_tools() {
  [[ "${STEWARD_FEAT_TOOLS:-n}" != "y" ]] && return 0
  heading "Phase 6a — tools (desk + tokens)"

  ensure_dir "$STEWARD_HOME/bin"
  cp "$STEWARD_REPO/tools/desk"   "$STEWARD_HOME/bin/desk"
  cp "$STEWARD_REPO/tools/tokens" "$STEWARD_HOME/bin/tokens"
  chmod +x "$STEWARD_HOME/bin/desk" "$STEWARD_HOME/bin/tokens"
  cp "$STEWARD_REPO/tools/README-desk.md" "$STEWARD_HOME/bin/README-desk.md"
  sage "  installed desk + tokens → $STEWARD_HOME/bin/"

  # tiktoken check (tokens dependency)
  if ! python3 -c 'import tiktoken' 2>/dev/null; then
    dim "  tokens requires the tiktoken Python package."
    local install_tt
    ask_yn "    install tiktoken now via: pip install --user tiktoken?" install_tt y
    if [[ "$install_tt" == "y" ]]; then
      if python3 -m pip install --user tiktoken >/dev/null 2>&1; then
        sage "  tiktoken installed"
      else
        rust "  tiktoken install failed — you can install it later: pip install --user tiktoken"
      fi
    else
      dim "  skipped. run 'pip install --user tiktoken' when you want the tokens CLI to work."
    fi
  else
    sage "  tiktoken: already installed"
  fi

  # PATH hint
  case "$PATH" in
    *"$STEWARD_HOME/bin"*) ;;
    *)
      dim "  add to your shellrc:  export PATH=\"$STEWARD_HOME/bin:\$PATH\""
      ;;
  esac

  return 0
}
