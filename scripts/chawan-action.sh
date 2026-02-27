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
          tmux switch-client -t "=$session" && tmux select-pane -t "=$target"
          ;;
      esac
      ;;
    delete)
      case "$mode" in
        session)
          local current_session
          current_session=$(tmux display-message -p '#S')
          if [[ "$target" == "$current_session" ]]; then
            tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null || true
          fi
          local _err
          if ! _err=$(tmux kill-session -t "=$target" 2>&1); then
            display_message "chawan: ${_err:-delete failed}" 2>/dev/null || true
          fi
          ;;
        window)
          local current_session
          current_session=$(tmux display-message -p '#S')
          local target_session="${target%%:*}"
          if [[ "$target_session" == "$current_session" ]]; then
            local win_count
            win_count=$(tmux list-windows -t "=$target_session" -F '.' | wc -l)
            if ((win_count <= 1)); then
              tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null || true
            fi
          fi
          local _err
          if ! _err=$(tmux kill-window -t "=$target" 2>&1); then
            display_message "chawan: ${_err:-delete failed}" 2>/dev/null || true
          fi
          ;;
        pane)
          local current_session
          current_session=$(tmux display-message -p '#S')
          local target_session="${target%%:*}"
          if [[ "$target_session" == "$current_session" ]]; then
            local target_window="${target%.*}"
            local pane_count
            pane_count=$(tmux list-panes -t "=$target_window" -F '.' | wc -l)
            if ((pane_count <= 1)); then
              local win_count
              win_count=$(tmux list-windows -t "=$target_session" -F '.' | wc -l)
              if ((win_count <= 1)); then
                tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null || true
              fi
            fi
          fi
          local _err
          if ! _err=$(tmux kill-pane -t "=$target" 2>&1); then
            display_message "chawan: ${_err:-delete failed}" 2>/dev/null || true
          fi
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
