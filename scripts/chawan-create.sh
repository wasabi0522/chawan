#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

main() {
  local mode="${1:-}"
  local target="${2:-}"

  case "$mode" in
    session)
      local name
      read -rp "New session name: " name

      # Empty or whitespace-only input: cancel
      [[ "$name" =~ ^[[:space:]]*$ ]] && return 0

      # Validate characters
      validate_printable "$name" || return 1
      validate_name "$name" "session" || return 1

      # Duplicate check
      if tmux has-session -t "=$name" 2>/dev/null; then
        echo "Error: session '$name' already exists" >&2
        return 1
      fi

      if ! tmux new-session -d -s "$name"; then
        echo "Error: failed to create session '$name'" >&2
        return 1
      fi
      tmux switch-client -t "=$name"
      ;;
    window)
      # Empty target: exit immediately
      [[ -z "$target" ]] && return 0

      local session="${target%%:*}"
      if ! tmux new-window -t "=${session}:"; then
        echo "Error: failed to create window" >&2
        return 1
      fi
      ;;
    pane)
      # Empty target: exit immediately
      [[ -z "$target" ]] && return 0

      if ! tmux split-window -h -t "=$target"; then
        echo "Error: failed to split pane" >&2
        return 1
      fi
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
