#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"

main() {
  local tmux_version
  tmux_version=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if ! version_ge "$tmux_version" "3.3"; then
    display_message "chawan: tmux 3.3+ is required (found $tmux_version)"
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    display_message "chawan: fzf is not installed"
    return 1
  fi

  local fzf_version
  fzf_version=$(fzf --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
  if ! version_ge "$fzf_version" "0.63"; then
    display_message "chawan: fzf 0.63+ is required (found $fzf_version)"
    return 1
  fi

  local key
  key=$(get_tmux_option "@chawan-key" "S")
  if [[ ! "$key" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*$ ]]; then
    display_message "chawan: invalid key binding: $key"
    return 1
  fi

  local escaped_main
  printf -v escaped_main '%q' "$CURRENT_DIR/scripts/chawan-main.sh"
  tmux bind-key "$key" run-shell -b "$escaped_main"

  # Mode-specific direct keybindings
  local key_window key_pane
  key_window=$(get_tmux_option "@chawan-key-window" "")
  key_pane=$(get_tmux_option "@chawan-key-pane" "")

  if [[ -n "$key_window" ]]; then
    if [[ ! "$key_window" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*$ ]]; then
      display_message "chawan: invalid key binding: $key_window"
      return 1
    fi
    tmux bind-key "$key_window" run-shell -b "$escaped_main window"
  fi

  if [[ -n "$key_pane" ]]; then
    if [[ ! "$key_pane" =~ ^[a-zA-Z0-9][-a-zA-Z0-9]*$ ]]; then
      display_message "chawan: invalid key binding: $key_pane"
      return 1
    fi
    tmux bind-key "$key_pane" run-shell -b "$escaped_main pane"
  fi
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main
fi
