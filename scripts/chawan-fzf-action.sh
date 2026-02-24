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

# Generates the fzf action string for switching to a given mode.
# Uses transform-header to dynamically build the right-aligned header
# using $FZF_COLUMNS for the actual finder area width.
switch_to_mode() {
  local mode="$1"
  case "$mode" in
    session | window | pane) ;;
    *) return ;;
  esac
  echo "reload($ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)+change-prompt(> )+transform-header($ESCAPED_SCRIPTS_DIR/chawan-main.sh --header $mode \$FZF_COLUMNS)+first"
}

main() {
  local action="${1:-}"
  local arg="${2:-}"
  local escaped_arg mode
  printf -v escaped_arg '%q' "$arg"
  mode=$(mode_from_id "$arg")

  case "$action" in
    tab)
      switch_to_mode "$(next_mode "$mode")"
      ;;
    shift-tab)
      switch_to_mode "$(prev_mode "$mode")"
      ;;
    click-header)
      case "$arg" in
        Session) switch_to_mode "session" ;;
        Window) switch_to_mode "window" ;;
        Pane) switch_to_mode "pane" ;;
      esac
      ;;
    delete)
      echo "reload-sync($ESCAPED_SCRIPTS_DIR/chawan-action.sh delete $mode $escaped_arg >/dev/null 2>&1; $ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)"
      ;;
    new)
      if [[ "$mode" == "session" ]]; then
        echo "execute($ESCAPED_SCRIPTS_DIR/chawan-create.sh session)+abort"
      else
        echo "reload-sync($ESCAPED_SCRIPTS_DIR/chawan-create.sh $mode $escaped_arg >/dev/null 2>&1; $ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)"
      fi
      ;;
    rename)
      echo "execute($ESCAPED_SCRIPTS_DIR/chawan-rename.sh $mode $escaped_arg)+reload($ESCAPED_SCRIPTS_DIR/chawan-list.sh $mode)"
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
