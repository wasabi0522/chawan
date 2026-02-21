#!/usr/bin/env bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# shellcheck source=scripts/helpers.sh
source "$PROJECT_ROOT/scripts/helpers.sh"

# --- Mock helpers ---

# Creates MOCK_TMUX_CALLS temp file and exports it.
setup_mocks() {
  MOCK_TMUX_CALLS="$(mktemp)"
  export MOCK_TMUX_CALLS
}

# Creates MOCK_TMUX_OUTPUT temp file and exports it.
setup_mock_output() {
  MOCK_TMUX_OUTPUT="$(mktemp)"
  export MOCK_TMUX_OUTPUT
}

# Removes all mock temp files.
teardown_mocks() {
  rm -f "${MOCK_TMUX_CALLS:-}" "${MOCK_TMUX_OUTPUT:-}"
}

# Installs a tmux mock that only records calls.
mock_tmux_record_only() {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
  }
  export -f tmux
}

# Installs a tmux mock that records calls and returns MOCK_TMUX_OUTPUT
# for list-sessions, list-windows, and list-panes.
mock_tmux_with_output() {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      list-sessions | list-windows | list-panes)
        cat "$MOCK_TMUX_OUTPUT"
        ;;
    esac
  }
  export -f tmux
}

# Installs fzf and command -v mocks for testing chawan.tmux.
# Default fzf version: 0.63.0
mock_fzf_available() {
  MOCK_FZF_VERSION="${1:-0.63.0 (brew)}"
  export MOCK_FZF_VERSION

  fzf() {
    echo "$MOCK_FZF_VERSION"
  }
  export -f fzf

  command() {
    if [[ "$1" == "-v" && "$2" == "fzf" ]]; then
      return 0
    fi
    builtin command "$@"
  }
  export -f command
}
