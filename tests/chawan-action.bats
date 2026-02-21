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

@test "chawan-action: switch pane with dot in session name" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch pane "my.dotfiles:0.1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "switch-client -t =my.dotfiles" ]
  [ "${lines[1]}" = "select-window -t =my.dotfiles:0" ]
  [ "${lines[2]}" = "select-pane -t =my.dotfiles:0.1" ]
  [ "${#lines[@]}" -eq 3 ]
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

# --- delete current session: switch-client then kill ---

@test "chawan-action: delete current session switches client then kills" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "display-message -p #S" ]
  [ "${lines[1]}" = "switch-client -l" ]
  [ "${lines[2]}" = "kill-session -t =my-project" ]
}

@test "chawan-action: delete current session falls back to switch-client -n" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      switch-client)
        if [[ "$2" == "-l" ]]; then
          return 1
        fi
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "display-message -p #S" ]
  [ "${lines[1]}" = "switch-client -l" ]
  [ "${lines[2]}" = "switch-client -n" ]
  [ "${lines[3]}" = "kill-session -t =my-project" ]
}

# --- delete last session ---

@test "chawan-action: delete last session kills it (no safety guard)" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      switch-client)
        return 1
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "display-message -p #S" ]
  [ "${lines[1]}" = "switch-client -l" ]
  [ "${lines[2]}" = "switch-client -n" ]
  [ "${lines[3]}" = "kill-session -t =my-project" ]
}

# --- delete window ---

@test "chawan-action: delete window calls kill-window" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:2"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "kill-window -t =my-project:2" ]
  [ "${#lines[@]}" -eq 1 ]
}

# --- delete last window ---

@test "chawan-action: delete last window kills it (no safety guard)" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:0"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "kill-window -t =my-project:0" ]
  [ "${#lines[@]}" -eq 1 ]
}

# --- delete pane ---

@test "chawan-action: delete pane calls kill-pane" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "kill-pane -t =my-project:2.1" ]
  [ "${#lines[@]}" -eq 1 ]
}

# --- delete last pane ---

@test "chawan-action: delete last pane kills it (no safety guard)" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.0"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "kill-pane -t =my-project:2.0" ]
  [ "${#lines[@]}" -eq 1 ]
}

# --- unknown action ---

@test "chawan-action: delete session shows error when kill-session fails" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        if [[ "$2" == "-p" ]]; then
          echo "$MOCK_DISPLAY_MESSAGE"
        fi
        ;;
      kill-session)
        echo "session not found: no-such" >&2
        return 1
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "no-such"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"display-message chawan:"* ]]
}

@test "chawan-action: delete window shows error when kill-window fails" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      kill-window)
        echo "window not found" >&2
        return 1
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "no-such:0"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [[ "$output" == *"display-message chawan:"* ]]
}

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
