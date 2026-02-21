#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks

  # Default tmux mock: record calls, has-session fails (no duplicate)
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      has-session) return 1 ;;
    esac
  }
  export -f tmux

  RENAME_SCRIPT="$PROJECT_ROOT/scripts/chawan-rename.sh"
}

teardown() {
  teardown_mocks
}

# --- session rename ---

@test "chawan-rename.sh: session mode calls rename-session with new name" {
  echo "new-session-name" | "$RENAME_SCRIPT" session "old-session"
  run cat "$MOCK_TMUX_CALLS"
  [ "${lines[0]}" = "has-session -t =new-session-name" ]
  [ "${lines[1]}" = "rename-session -t =old-session new-session-name" ]
}

# --- window rename ---

@test "chawan-rename.sh: window mode calls rename-window with new name" {
  echo "new-window-name" | "$RENAME_SCRIPT" window "my-project:1"
  result=$(cat "$MOCK_TMUX_CALLS")
  [ "$result" = "rename-window -t =my-project:1 new-window-name" ]
}

# --- pane rename (title) ---

@test "chawan-rename.sh: pane mode calls select-pane -T with new title" {
  echo "my-pane-title" | "$RENAME_SCRIPT" pane "my-project:1.2"
  result=$(cat "$MOCK_TMUX_CALLS")
  [ "$result" = "select-pane -t =my-project:1.2 -T my-pane-title" ]
}

# --- empty input (cancel) ---

@test "chawan-rename.sh: empty input skips rename" {
  echo "" | "$RENAME_SCRIPT" session "my-session"
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: whitespace-only input skips rename" {
  echo "   " | "$RENAME_SCRIPT" session "my-session"
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- tmux forbidden characters ---

@test "chawan-rename.sh: session rename rejects name containing dot" {
  local exit_code=0
  echo "bad.name" | "$RENAME_SCRIPT" session "my-session" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: session rename rejects name containing colon" {
  local exit_code=0
  echo "bad:name" | "$RENAME_SCRIPT" session "my-session" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: window rename rejects name containing dot" {
  local exit_code=0
  echo "bad.name" | "$RENAME_SCRIPT" window "my-project:1" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: window rename rejects name containing colon" {
  local exit_code=0
  echo "bad:name" | "$RENAME_SCRIPT" window "my-project:1" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: pane rename allows dot and colon in title" {
  echo "title.with:special" | "$RENAME_SCRIPT" pane "my-project:1.2"
  result=$(cat "$MOCK_TMUX_CALLS")
  [ "$result" = "select-pane -t =my-project:1.2 -T title.with:special" ]
}

# --- duplicate session name ---

@test "chawan-rename.sh: session rename rejects duplicate name" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      has-session) return 0 ;;
    esac
  }
  export -f tmux

  local exit_code=0
  echo "existing-session" | "$RENAME_SCRIPT" session "old-session" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]

  run grep "has-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 0 ]
  run grep "rename-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

@test "chawan-rename.sh: session rename allows same name (no duplicate check)" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      has-session) return 0 ;;
    esac
  }
  export -f tmux

  echo "same-session" | "$RENAME_SCRIPT" session "same-session"

  run grep "rename-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 0 ]
  # has-session should NOT be called when new_name == target
  run grep "has-session" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 1 ]
}

# --- empty target safety guard ---

@test "chawan-rename.sh: session rename rejects name with control characters" {
  local exit_code=0
  printf 'bad\tname' | "$RENAME_SCRIPT" session "my-session" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: pane rename rejects title with control characters" {
  local exit_code=0
  printf 'bad\x01name' | "$RENAME_SCRIPT" pane "my-project:1.2" 2>/dev/null || exit_code=$?
  [ "$exit_code" -eq 1 ]
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

@test "chawan-rename.sh: empty target exits 0 without calling tmux" {
  echo "new-name" | "$RENAME_SCRIPT" session ""
  [ ! -s "$MOCK_TMUX_CALLS" ]
}
