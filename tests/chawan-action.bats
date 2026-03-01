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
  assert_success
  # No tmux calls should have been made
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-action: missing target exits 0 immediately" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch session
  assert_success
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- switch session ---

@test "chawan-action: switch session calls switch-client" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch session "my-project"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "switch-client -t =my-project"
  [ "${#lines[@]}" -eq 1 ]
}

# --- switch window ---

@test "chawan-action: switch window calls switch-client and select-window" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch window "my-project:2"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "switch-client -t =my-project"
  assert_line -n 1 "select-window -t =my-project:2"
  [ "${#lines[@]}" -eq 2 ]
}

@test "chawan-action: switch window with slash in session name" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch window "org/project:1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "switch-client -t =org/project"
  assert_line -n 1 "select-window -t =org/project:1"
}

# --- switch pane ---

@test "chawan-action: switch pane calls switch-client and select-pane" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch pane "my-project:2.1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "switch-client -t =my-project"
  assert_line -n 1 "select-pane -t =my-project:2.1"
  [ "${#lines[@]}" -eq 2 ]
}

@test "chawan-action: switch pane with slash in session name" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch pane "org/project:0.2"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "switch-client -t =org/project"
  assert_line -n 1 "select-pane -t =org/project:0.2"
  [ "${#lines[@]}" -eq 2 ]
}

@test "chawan-action: switch pane with dot in session name" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" switch pane "my.dotfiles:0.1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "switch-client -t =my.dotfiles"
  assert_line -n 1 "select-pane -t =my.dotfiles:0.1"
  [ "${#lines[@]}" -eq 2 ]
}

# --- delete session ---

@test "chawan-action: delete session calls kill-session" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  # First call: display-message to get current session
  assert_line -n 0 "display-message -p #S"
  # Second call: kill-session
  assert_line -n 1 "kill-session -t =my-project"
}

@test "chawan-action: delete session with hyphen-prefixed name" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "-my-session"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "kill-session -t =-my-session"
}

# --- delete current session: switch-client then kill ---

@test "chawan-action: delete current session switches client then kills" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session "my-project"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "switch-client -l"
  assert_line -n 2 "kill-session -t =my-project"
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
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "switch-client -l"
  assert_line -n 2 "switch-client -n"
  assert_line -n 3 "kill-session -t =my-project"
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
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "switch-client -l"
  assert_line -n 2 "switch-client -n"
  assert_line -n 3 "kill-session -t =my-project"
}

# --- delete window ---

@test "chawan-action: delete window in different session calls kill-window" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:2"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "kill-window -t =my-project:2"
  [ "${#lines[@]}" -eq 2 ]
}

@test "chawan-action: delete window in current session with multiple windows" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-windows)
        printf '.\n.\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:2"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-windows -t =my-project -F ."
  assert_line -n 2 "kill-window -t =my-project:2"
  [ "${#lines[@]}" -eq 3 ]
}

# --- delete last window ---

@test "chawan-action: delete last window in current session switches client then kills" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-windows)
        printf '.\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:0"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-windows -t =my-project -F ."
  assert_line -n 2 "switch-client -l"
  assert_line -n 3 "kill-window -t =my-project:0"
  [ "${#lines[@]}" -eq 4 ]
}

@test "chawan-action: delete last window falls back to switch-client -n" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-windows)
        printf '.\n'
        ;;
      switch-client)
        if [[ "$2" == "-l" ]]; then
          return 1
        fi
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete window "my-project:0"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-windows -t =my-project -F ."
  assert_line -n 2 "switch-client -l"
  assert_line -n 3 "switch-client -n"
  assert_line -n 4 "kill-window -t =my-project:0"
  [ "${#lines[@]}" -eq 5 ]
}

# --- delete pane ---

@test "chawan-action: delete pane in different session calls kill-pane" {
  MOCK_DISPLAY_MESSAGE="other-session"
  export MOCK_DISPLAY_MESSAGE

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "kill-pane -t =my-project:2.1"
  [ "${#lines[@]}" -eq 2 ]
}

@test "chawan-action: delete pane in current session with multiple panes" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-panes)
        printf '.\n.\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-panes -t =my-project:2 -F ."
  assert_line -n 2 "kill-pane -t =my-project:2.1"
  [ "${#lines[@]}" -eq 3 ]
}

@test "chawan-action: delete last pane in current session with multiple windows" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-panes)
        printf '.\n'
        ;;
      list-windows)
        printf '.\n.\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.0"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-panes -t =my-project:2 -F ."
  assert_line -n 2 "list-windows -t =my-project -F ."
  assert_line -n 3 "kill-pane -t =my-project:2.0"
  [ "${#lines[@]}" -eq 4 ]
}

# --- delete last pane ---

@test "chawan-action: delete last pane in last window switches client then kills" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-panes)
        printf '.\n'
        ;;
      list-windows)
        printf '.\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.0"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-panes -t =my-project:2 -F ."
  assert_line -n 2 "list-windows -t =my-project -F ."
  assert_line -n 3 "switch-client -l"
  assert_line -n 4 "kill-pane -t =my-project:2.0"
  [ "${#lines[@]}" -eq 5 ]
}

@test "chawan-action: delete last pane falls back to switch-client -n" {
  MOCK_DISPLAY_MESSAGE="my-project"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-panes)
        printf '.\n'
        ;;
      list-windows)
        printf '.\n'
        ;;
      switch-client)
        if [[ "$2" == "-l" ]]; then
          return 1
        fi
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:2.0"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  assert_line -n 1 "list-panes -t =my-project:2 -F ."
  assert_line -n 2 "list-windows -t =my-project -F ."
  assert_line -n 3 "switch-client -l"
  assert_line -n 4 "switch-client -n"
  assert_line -n 5 "kill-pane -t =my-project:2.0"
  [ "${#lines[@]}" -eq 6 ]
}

@test "chawan-action: delete pane with dot in session name extracts window correctly" {
  MOCK_DISPLAY_MESSAGE="my.dotfiles"
  export MOCK_DISPLAY_MESSAGE

  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      display-message)
        echo "$MOCK_DISPLAY_MESSAGE"
        ;;
      list-panes)
        printf '.\n'
        ;;
      list-windows)
        printf '.\n'
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my.dotfiles:0.1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_line -n 0 "display-message -p #S"
  # ${target%.*} should correctly extract "my.dotfiles:0" (not "my")
  assert_line -n 1 "list-panes -t =my.dotfiles:0 -F ."
  assert_line -n 2 "list-windows -t =my.dotfiles -F ."
  assert_line -n 3 "switch-client -l"
  assert_line -n 4 "kill-pane -t =my.dotfiles:0.1"
  [ "${#lines[@]}" -eq 5 ]
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
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message chawan:"
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
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message chawan:"
}

@test "chawan-action: delete pane shows error when kill-pane fails" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      kill-pane)
        echo "pane not found" >&2
        return 1
        ;;
    esac
  }
  export -f tmux

  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete pane "my-project:0.1"
  assert_success

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message chawan:"
}

@test "chawan-action: unknown action does nothing" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" unknown session "my-project"
  assert_success
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- delete with empty target ---

@test "chawan-action: delete with empty target exits 0 immediately" {
  run "$PROJECT_ROOT/scripts/chawan-action.sh" delete session ""
  assert_success
  [ ! -s "$MOCK_TMUX_CALLS" ]
}
