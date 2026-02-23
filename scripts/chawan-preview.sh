#!/usr/bin/env bash

main() {
  local target="${1:-}"

  # Safety guard: empty target
  [[ -z "$target" ]] && return 0

  # Session targets have no colon; append ":" to target the active pane
  if [[ "$target" != *:* ]]; then
    target="${target}:"
  fi

  # Strip trailing visually-blank lines (empty, whitespace-only, or
  # ANSI-escape-only) so fzf's scroll-to-bottom shows actual content.
  tmux capture-pane -ep -t "=$target" 2>/dev/null | awk '
    {
      lines[NR] = $0
      clean = $0
      gsub("\033\\[[0-9;]*[a-zA-Z]", "", clean)
      if (clean ~ /[^[:space:]]/) last = NR
    }
    END { for (i = 1; i <= last; i++) print lines[i] }
  '
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
