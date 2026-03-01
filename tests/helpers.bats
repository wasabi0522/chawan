#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
}

teardown() {
  teardown_mocks
}

# --- get_tmux_option ---

@test "get_tmux_option returns tmux value when option is set" {
  tmux() {
    if [[ "$1 $2" == "show-option -gqv" ]]; then
      echo "custom-value"
    fi
  }
  export -f tmux

  run get_tmux_option "@chawan-key" "S"
  assert_success
  assert_output "custom-value"
}

@test "get_tmux_option returns default when option is unset" {
  tmux() {
    if [[ "$1 $2" == "show-option -gqv" ]]; then
      echo ""
    fi
  }
  export -f tmux

  run get_tmux_option "@chawan-key" "S"
  assert_success
  assert_output "S"
}

# --- version_ge ---

@test "version_ge: same version returns success" {
  run version_ge "0.63" "0.63"
  assert_success
}

@test "version_ge: higher minor returns success" {
  run version_ge "0.64" "0.63"
  assert_success
}

@test "version_ge: lower minor returns failure" {
  run version_ge "0.62" "0.63"
  assert_failure
}

@test "version_ge: higher major returns success" {
  run version_ge "1.0" "0.63"
  assert_success
}

@test "version_ge: patch version is handled" {
  run version_ge "0.63.1" "0.63"
  assert_success
}

# --- mode_from_id ---

@test "mode_from_id: dotted ID returns pane" {
  run mode_from_id "sess:0.1"
  assert_output "pane"
}

@test "mode_from_id: colon ID returns window" {
  run mode_from_id "sess:0"
  assert_output "window"
}

@test "mode_from_id: plain ID returns session" {
  run mode_from_id "sess"
  assert_output "session"
}

@test "mode_from_id: session name with dot returns session (not pane)" {
  run mode_from_id "my.dotfiles"
  assert_output "session"
}

@test "mode_from_id: window ID with dotted session returns window" {
  run mode_from_id "my.dotfiles:0"
  assert_output "window"
}

@test "mode_from_id: pane ID with dotted session returns pane" {
  run mode_from_id "my.dotfiles:0.1"
  assert_output "pane"
}

# --- make_tab_bar ---

@test "make_tab_bar highlights session mode" {
  run make_tab_bar session
  assert_success
  # Session should be wrapped in bold+reverse ANSI codes
  assert_output --partial $'\e[1;7m Session \e[0m'
  # Window and Pane should NOT be highlighted
  refute_output --partial $'\e[1;7m Window \e[0m'
  refute_output --partial $'\e[1;7m Pane \e[0m'
}

@test "make_tab_bar highlights window mode" {
  run make_tab_bar window
  assert_success
  assert_output --partial $'\e[1;7m Window \e[0m'
  refute_output --partial $'\e[1;7m Session \e[0m'
}

@test "make_tab_bar highlights pane mode" {
  run make_tab_bar pane
  assert_success
  assert_output --partial $'\e[1;7m Pane \e[0m'
  refute_output --partial $'\e[1;7m Session \e[0m'
}

# --- display_message ---

@test "display_message calls tmux display-message with correct args" {
  mock_tmux_record_only

  display_message "hello world"

  run cat "$MOCK_TMUX_CALLS"
  assert_output "display-message hello world"
}

# --- TAB_BAR_VISIBLE_LEN ---

@test "TAB_BAR_VISIBLE_LEN matches actual make_tab_bar visible width" {
  local tab_bar
  tab_bar=$(make_tab_bar session)
  # Strip ANSI escape sequences to get visible characters
  local stripped
  stripped=$(printf '%s' "$tab_bar" | sed $'s/\x1b\[[0-9;]*m//g')
  local actual_len=${#stripped}
  [ "$actual_len" -eq "$TAB_BAR_VISIBLE_LEN" ]
}

# --- validate_name ---

@test "validate_name: valid session name succeeds" {
  run validate_name "my-project" "session"
  assert_success
}

@test "validate_name: session name with dot fails" {
  run validate_name "my.project" "session"
  assert_failure
}

@test "validate_name: session name with colon fails" {
  run validate_name "my:project" "session"
  assert_failure
}

@test "validate_name: window name with dot fails" {
  run validate_name "bad.name" "window"
  assert_failure
}

@test "validate_name: pane name with dot is allowed" {
  run validate_name "title.with.dots" "pane"
  assert_success
}

@test "validate_name: slash in session name is allowed" {
  run validate_name "org/project" "session"
  assert_success
}

# --- validate_printable ---

@test "validate_printable: normal name succeeds" {
  run validate_printable "my-project"
  assert_success
}

@test "validate_printable: name with tab fails" {
  run validate_printable $'my\tproject'
  assert_failure
  assert_output --partial "control characters"
}

@test "validate_printable: name with newline fails" {
  run validate_printable $'my\nproject'
  assert_failure
}

@test "validate_printable: name with null byte fails" {
  run validate_printable $'my\x01project'
  assert_failure
}

@test "validate_printable: unicode name succeeds" {
  run validate_printable "プロジェクト"
  assert_success
}

@test "validate_printable: name with spaces succeeds" {
  run validate_printable "my project"
  assert_success
}
