#!/usr/bin/env bash

main() {
  local target="${1:-}"

  # Safety guard: empty target
  [[ -z "$target" ]] && return 0

  # Session targets have no colon; append ":" to target the active pane
  if [[ "$target" != *:* ]]; then
    target="${target}:"
  fi

  tmux capture-pane -ep -t "=$target"
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
