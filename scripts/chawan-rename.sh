#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

main() {
  local mode="${1:-}"
  local target="${2:-}"

  # Safety guard: empty target
  [[ -z "$target" ]] && return 0

  local new_name
  read -rp "New name: " new_name

  # Empty or whitespace-only input: cancel
  [[ "$new_name" =~ ^[[:space:]]*$ ]] && return 0

  # Validate forbidden characters for session/window rename
  if [[ "$mode" == "session" || "$mode" == "window" ]]; then
    validate_name "$new_name" "$mode" || return 1
  fi

  # Duplicate session name check
  if [[ "$mode" == "session" && "$new_name" != "$target" ]]; then
    if tmux has-session -t "=$new_name" 2>/dev/null; then
      echo "Error: session '$new_name' already exists" >&2
      return 1
    fi
  fi

  case "$mode" in
    session)
      tmux rename-session -t "=$target" "$new_name"
      ;;
    window)
      tmux rename-window -t "=$target" "$new_name"
      ;;
    pane)
      tmux select-pane -t "=$target" -T "$new_name"
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
