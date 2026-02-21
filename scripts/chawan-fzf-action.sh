#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shell-escape for safe embedding in fzf action strings
printf -v ESCAPED_SCRIPTS_DIR '%q' "$CURRENT_DIR"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

# Returns the next mode in the cycle: session -> window -> pane -> session
next_mode() {
  case "$1" in
    session) echo "window" ;;
    window) echo "pane" ;;
    pane) echo "session" ;;
    *) echo "session" ;;
  esac
}

# Returns the previous mode in the cycle: session -> pane -> window -> session
prev_mode() {
  case "$1" in
    session) echo "pane" ;;
    window) echo "session" ;;
    pane) echo "window" ;;
    *) echo "session" ;;
  esac
}

# Generates the fzf action string for switching to a given mode
switch_to_mode() {
  local mode="$1"
  local header_var
  case "$mode" in
    session) header_var="$HEADER_SESSION" ;;
    window) header_var="$HEADER_WINDOW" ;;
    pane) header_var="$HEADER_PANE" ;;
    *) return ;;
  esac
  echo "reload($ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)+change-prompt(> )+change-header(${header_var})+first"
}

main() {
  local action="${1:-}"
  local arg="${2:-}"
  local escaped_arg
  printf -v escaped_arg '%q' "$arg"

  case "$action" in
    tab)
      local current
      current=$(mode_from_id "$arg")
      switch_to_mode "$(next_mode "$current")"
      ;;
    shift-tab)
      local current
      current=$(mode_from_id "$arg")
      switch_to_mode "$(prev_mode "$current")"
      ;;
    click-header)
      case "$arg" in
        Session) switch_to_mode "session" ;;
        Window) switch_to_mode "window" ;;
        Pane) switch_to_mode "pane" ;;
      esac
      ;;
    delete)
      local mode
      mode=$(mode_from_id "$arg")
      echo "reload-sync($ESCAPED_SCRIPTS_DIR/chawan-action.sh delete $mode $escaped_arg >/dev/null 2>&1; $ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)"
      ;;
    new)
      local mode
      mode=$(mode_from_id "$arg")
      if [[ "$mode" == "session" ]]; then
        echo "execute($ESCAPED_SCRIPTS_DIR/chawan-create.sh session)+abort"
      else
        echo "reload-sync($ESCAPED_SCRIPTS_DIR/chawan-create.sh $mode $escaped_arg >/dev/null 2>&1; $ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)"
      fi
      ;;
    rename)
      local mode
      mode=$(mode_from_id "$arg")
      echo "execute($ESCAPED_SCRIPTS_DIR/chawan-rename.sh $mode $escaped_arg)+reload($ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)"
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
