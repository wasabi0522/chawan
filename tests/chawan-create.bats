#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks

  # Default tmux mock: record calls, has-session always fails (session does not exist)
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      has-session)
        return 1
        ;;
    esac
  }
  export -f tmux

  CREATE_SCRIPT="$PROJECT_ROOT/scripts/chawan-create.sh"
}

teardown() {
  teardown_mocks
}

# --- session mode: new session ---

@test "chawan-create: session mode creates new session and switches to it" {
  echo "my-project" | "$CREATE_SCRIPT" session
  status=$?
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "has-session -t =my-project" ]
  [ "${lines[1]}" = "new-session -d -s my-project" ]
  [ "${lines[2]}" = "switch-client -t =my-project" ]
  [ "${#lines[@]}" -eq 3 ]
}

# --- session mode: empty input ---

@test "chawan-create: session mode with empty input does nothing" {
  echo "" | "$CREATE_SCRIPT" session
  status=$?
  [ "$status" -eq 0 ]

  # No tmux calls should have been made
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- session mode: duplicate session name ---

@test "chawan-create: session mode rejects duplicate session name" {
  # Override tmux mock: has-session succeeds (session exists)
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      has-session)
        return 0
        ;;
    esac
  }
  export -f tmux

  local exit_status=0
  echo "existing-session" | "$CREATE_SCRIPT" session 2>/dev/null || exit_status=$?
  [ "$exit_status" -eq 1 ]

  # Should have called has-session but NOT new-session
  run grep "has-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 0 ]
  run grep "new-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

# --- session mode: forbidden characters ---

@test "chawan-create: session mode with whitespace-only input does nothing" {
  echo "   " | "$CREATE_SCRIPT" session
  status=$?
  [ "$status" -eq 0 ]

  # No tmux calls should have been made
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- session mode: forbidden characters ---

@test "chawan-create: session mode rejects name containing dot" {
  local exit_status=0
  echo "my.project" | "$CREATE_SCRIPT" session 2>/dev/null || exit_status=$?
  [ "$exit_status" -eq 1 ]

  # Should NOT call has-session or new-session
  run grep "new-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

@test "chawan-create: session mode rejects name containing colon" {
  local exit_status=0
  echo "my:project" | "$CREATE_SCRIPT" session 2>/dev/null || exit_status=$?
  [ "$exit_status" -eq 1 ]

  # Should NOT call has-session or new-session
  run grep "new-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

# --- session mode: slash in session name is allowed ---

@test "chawan-create: session mode allows slash in name" {
  echo "org/project" | "$CREATE_SCRIPT" session
  status=$?
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "has-session -t =org/project" ]
  [ "${lines[1]}" = "new-session -d -s org/project" ]
  [ "${lines[2]}" = "switch-client -t =org/project" ]
}

# --- window mode ---

@test "chawan-create: window mode creates new window in target session" {
  run "$CREATE_SCRIPT" window "my-project:2"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "new-window -t =my-project:" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "chawan-create: window mode with slash in session name" {
  run "$CREATE_SCRIPT" window "org/project:1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "new-window -t =org/project:" ]
}

# --- window mode: empty target ---

@test "chawan-create: window mode with empty target exits 0" {
  run "$CREATE_SCRIPT" window ""
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-create: window mode with missing target exits 0" {
  run "$CREATE_SCRIPT" window
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- pane mode ---

@test "chawan-create: pane mode splits window horizontally at target" {
  run "$CREATE_SCRIPT" pane "my-project:2.1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "split-window -h -t =my-project:2.1" ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "chawan-create: pane mode with slash in session name" {
  run "$CREATE_SCRIPT" pane "org/project:0.2"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "split-window -h -t =org/project:0.2" ]
}

# --- pane mode: empty target ---

@test "chawan-create: pane mode with empty target exits 0" {
  run "$CREATE_SCRIPT" pane ""
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-create: pane mode with missing target exits 0" {
  run "$CREATE_SCRIPT" pane
  [ "$status" -eq 0 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}
