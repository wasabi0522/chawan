#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
  MOCK_DISPLAY_MESSAGE=""
  export MOCK_DISPLAY_MESSAGE

  # Default tmux mock: record calls and handle display-message
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
    esac
  }
  export -f tmux
}

teardown() {
  teardown_mocks
}

# --- Empty target ---

@test "chawan-action: empty target exits 0 immediately" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch session ""
  [ "$status" -eq 0 ]
  # No tmux calls should have been made
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-action: missing target exits 0 immediately" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch session
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- switch session ---

@test "chawan-action: switch session calls switch-client" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch session "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "switch-client -t =my-project" ]
  [ "${#lines[@]}" -eq 1 ]
}

# --- switch window ---

@test "chawan-action: switch window calls switch-client and select-window" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch window "my-project:2"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "switch-client -t =my-project" ]
  [ "${lines[1]}" = "select-window -t =my-project:2" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "chawan-action: switch window with slash in session name" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch window "org/project:1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "switch-client -t =org/project" ]
  [ "${lines[1]}" = "select-window -t =org/project:1" ]
}

# --- switch pane ---

@test "chawan-action: switch pane calls switch-client, select-window, and select-pane" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch pane "my-project:2.1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "switch-client -t =my-project" ]
  [ "${lines[1]}" = "select-window -t =my-project:2" ]
  [ "${lines[2]}" = "select-pane -t =my-project:2.1" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "chawan-action: switch pane with slash in session name" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch pane "org/project:0.2"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "switch-client -t =org/project" ]
  [ "${lines[1]}" = "select-window -t =org/project:0" ]
  [ "${lines[2]}" = "select-pane -t =org/project:0.2" ]
}

# --- delete session ---

@test "chawan-action: delete session calls kill-session" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  # First call: display-message to get current session
  [ "${lines[0]}" = "display-message -p #S" ]
  # Second call: kill-session
  [ "${lines[1]}" = "kill-session -t =my-project" ]
}

@test "chawan-action: delete session with hyphen-prefixed name" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "-my-session"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "display-message -p #S" ]
  [ "${lines[1]}" = "kill-session -t =-my-session" ]
}

# --- delete session: safety guard ---

@test "chawan-action: delete current session is skipped (safety guard)" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  # Should have display-message call to get current session
  [ "${lines[0]}" = "display-message -p #S" ]
  # Should have display-message call for warning (not kill-session)
  [[ "${lines[1]}" == display-message* ]]
  # Should NOT contain kill-session
  run grep "kill-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

# --- delete window ---

@test "chawan-action: delete window calls kill-window" {
  # Mock: list-windows returns 2 windows so deletion is allowed
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      list-windows)
        printf 'win1\nwin2\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:2"
  [ "$status" -eq 0 ]

  run grep "kill-window" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kill-window -t =my-project:2"* ]]
}

# --- delete window: safety guard ---

@test "chawan-action: delete last window is skipped (safety guard)" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      list-windows)
        printf 'win1\n'
        ;;
      display-message)
        echo ""
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:0"
  [ "$status" -eq 0 ]

  run grep "kill-window" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

# --- delete pane ---

@test "chawan-action: delete pane calls kill-pane" {
  # Mock: list-panes returns 2 panes so deletion is allowed
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      list-panes)
        printf 'pane1\npane2\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.1"
  [ "$status" -eq 0 ]

  run grep "kill-pane" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 0 ]
  [[ "$output" == *"kill-pane -t =my-project:2.1"* ]]
}

# --- delete pane: safety guard ---

@test "chawan-action: delete last pane is skipped (safety guard)" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      list-panes)
        printf 'pane1\n'
        ;;
      display-message)
        echo ""
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.0"
  [ "$status" -eq 0 ]

  run grep "kill-pane" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

# --- unknown action ---

@test "chawan-action: unknown action does nothing" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" unknown session "my-project"
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- delete with empty target ---

@test "chawan-action: delete with empty target exits 0 immediately" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session ""
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}
