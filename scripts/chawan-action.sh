#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

main() {
  local action="${1:-}"
  local mode="${2:-}"
  local target="${3:-}"

  # Empty target: skip
  [[ -z "$target" ]] && return 0

  case "$action" in
    switch)
      case "$mode" in
        session)
          tmux switch-client -t "=$target"
          ;;
        window)
          local session="${target%%:*}"
          tmux switch-client -t "=$session" && tmux select-window -t "=$target"
          ;;
        pane)
          local session="${target%%:*}"
          local window="${target%%.*}"
          tmux switch-client -t "=$session" && tmux select-window -t "=$window" && tmux select-pane -t "=$target"
          ;;
      esac
      ;;
    delete)
      case "$mode" in
        session)
          local current_session
          current_session=$(tmux display-message -p '#S')
          if [[ "$target" == "$current_session" ]]; then
            local session_count
            session_count=$(tmux list-sessions 2>/dev/null | wc -l)
            if ((session_count <= 1)); then
              display_message "Cannot delete last session: $target"
              return 0
            fi
            tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null
          fi
          tmux kill-session -t "=$target" 2>/dev/null || true
          ;;
        window)
          local win_session="${target%%:*}"
          local win_count
          win_count=$(tmux list-windows -t "=$win_session" 2>/dev/null | wc -l) || win_count=0
          if ((win_count <= 1)); then
            display_message "Cannot delete last window in session: $win_session"
            return 0
          fi
          tmux kill-window -t "=$target" 2>/dev/null || true
          ;;
        pane)
          local pane_window="${target%%.*}"
          local pane_count
          pane_count=$(tmux list-panes -t "=$pane_window" 2>/dev/null | wc -l) || pane_count=0
          if ((pane_count <= 1)); then
            display_message "Cannot delete last pane in window: $pane_window"
            return 0
          fi
          tmux kill-pane -t "=$target" 2>/dev/null || true
          ;;
      esac
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
