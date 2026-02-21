#!/usr/bin/env bash

main() {
  local mode="${1:-}"
  local target="${2:-}"

  case "$mode" in
    session)
      local name
      read -rp "New session name: " name

      # Empty input: skip
      [[ -z "$name" ]] && return 0

      # Forbidden characters: . and :
      if [[ "$name" == *.* || "$name" == *:* ]]; then
        echo "Error: session name cannot contain '.' or ':'" >&2
        return 1
      fi

      # Duplicate check
      if tmux has-session -t "=$name" 2>/dev/null; then
        echo "Error: session '$name' already exists" >&2
        return 1
      fi

      tmux new-session -d -s "$name"
      tmux switch-client -t "=$name"
      ;;
    window)
      # Empty target: exit immediately
      [[ -z "$target" ]] && return 0

      local session="${target%%:*}"
      tmux new-window -t "=${session}:"
      ;;
    pane)
      # Empty target: exit immediately
      [[ -z "$target" ]] && return 0

      tmux split-window -h -t "=$target"
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
