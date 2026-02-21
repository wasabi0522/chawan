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
            tmux switch-client -l 2>/dev/null || tmux switch-client -n 2>/dev/null || true
          fi
          tmux kill-session -t "=$target" 2>/dev/null || true
          ;;
        window)
          tmux kill-window -t "=$target" 2>/dev/null || true
          ;;
        pane)
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
