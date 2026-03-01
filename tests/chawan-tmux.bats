#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
  mock_fzf_available

  # Mock tmux: record calls and handle show-option and -V
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      -V) echo "tmux 3.4" ;;
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

# --- tmux version too old ---

@test "chawan.tmux: error when tmux version is too old (3.2)" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      -V) echo "tmux 3.2" ;;
      show-option) echo "" ;;
    esac
  }
  export -f tmux

  run "$CHAWAN_TMUX"
  assert_failure

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message"
  assert_output --partial "3.3"
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
  assert_failure

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message"
  assert_output --partial "fzf"
}

# --- fzf version too old ---

@test "chawan.tmux: error when fzf version is too old (0.62)" {
  mock_fzf_available "0.62.0 (brew)"

  run "$CHAWAN_TMUX"
  assert_failure

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message"
  assert_output --partial "0.63"
}

# --- fzf OK: bind-key is called ---

@test "chawan.tmux: bind-key is called when fzf is available" {
  run "$CHAWAN_TMUX"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "bind-key"
}

# --- default key ---

@test "chawan.tmux: uses default key S when @chawan-key is unset" {
  run "$CHAWAN_TMUX"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "bind-key S "
}

# --- custom key ---

@test "chawan.tmux: error when @chawan-key is invalid" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      -V) echo "tmux 3.4" ;;
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
  assert_failure

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message"
  assert_output --partial "invalid key binding"
}

@test "chawan.tmux: uses custom key F when @chawan-key is set" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      -V) echo "tmux 3.4" ;;
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
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "bind-key F "
}

@test "chawan.tmux: only one bind-key call is made" {
  run "$CHAWAN_TMUX"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  local bind_count
  bind_count=$(grep -c "bind-key" "$MOCK_TMUX_CALLS")
  [ "$bind_count" -eq 1 ]
}
