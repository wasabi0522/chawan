#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"

main() {
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

  tmux bind-key "$key" run-shell -b "$CURRENT_DIR/scripts/chawan-main.sh"
}
main
