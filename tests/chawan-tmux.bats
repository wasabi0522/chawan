#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
  mock_fzf_available

  # Mock tmux: record calls and handle show-option
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        # Default: return empty (use default values)
        echo ""
        ;;
    esac
  }
  export -f tmux

  CHAWAN_TMUX="$PROJECT_ROOT/chawan.tmux"
}

teardown() {
  teardown_mocks
}

# --- fzf not installed ---

@test "chawan.tmux: error when fzf is not installed" {
  # Override: fzf not found
  fzf() {
    return 1
  }
  export -f fzf

  command() {
    if [[ "$1" == "-v" && "$2" == "fzf" ]]; then
      return 1
    fi
    builtin command "$@"
  }
  export -f command

  run "$CHAWAN_TMUX"
  [ "$status" -eq 1 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"display-message"* ]]
  [[ "$output" == *"fzf"* ]]
}

# --- fzf version too old ---

@test "chawan.tmux: error when fzf version is too old (0.62)" {
  mock_fzf_available "0.62.0 (brew)"

  run "$CHAWAN_TMUX"
  [ "$status" -eq 1 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"display-message"* ]]
  [[ "$output" == *"0.63"* ]]
}

# --- fzf OK: bind-key is called ---

@test "chawan.tmux: bind-key is called when fzf is available" {
  run "$CHAWAN_TMUX"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"bind-key"* ]]
}

# --- default key ---

@test "chawan.tmux: uses default key S when @chawan-key is unset" {
  run "$CHAWAN_TMUX"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"bind-key S "* ]]
}

# --- custom key ---

@test "chawan.tmux: error when @chawan-key is invalid" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-key" ]]; then
          echo '!@#'
        else
          echo ""
        fi
        ;;
    esac
  }
  export -f tmux

  run "$CHAWAN_TMUX"
  [ "$status" -eq 1 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"display-message"* ]]
  [[ "$output" == *"invalid key binding"* ]]
}

@test "chawan.tmux: uses custom key F when @chawan-key is set" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-key" ]]; then
          echo "F"
        else
          echo ""
        fi
        ;;
    esac
  }
  export -f tmux

  run "$CHAWAN_TMUX"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"bind-key F "* ]]
}
