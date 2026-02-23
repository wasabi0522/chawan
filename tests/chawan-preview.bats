#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
  mock_tmux_record_only

  PREVIEW_SCRIPT="$PROJECT_ROOT/scripts/chawan-preview.sh"
  PREVIEW_OUT="$(mktemp)"
}

teardown() {
  teardown_mocks
  rm -f "$PREVIEW_OUT"
}

# --- session target (no colon) ---

@test "chawan-preview.sh: session target calls capture-pane with {name}:" {
  run "$PREVIEW_SCRIPT" "my-project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "$output" = "capture-pane -ep -t =my-project:" ]
}

# --- window target (colon, no dot) ---

@test "chawan-preview.sh: window target calls capture-pane with {sess}:{idx}" {
  run "$PREVIEW_SCRIPT" "my-project:1"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "$output" = "capture-pane -ep -t =my-project:1" ]
}

# --- pane target (colon and dot) ---

@test "chawan-preview.sh: pane target calls capture-pane with {sess}:{idx}.{pane}" {
  run "$PREVIEW_SCRIPT" "my-project:1.2"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "$output" = "capture-pane -ep -t =my-project:1.2" ]
}

# --- empty target safety guard ---

@test "chawan-preview.sh: session target with space calls capture-pane correctly" {
  run "$PREVIEW_SCRIPT" "my project"
  [ "$status" -eq 0 ]

  run cat "$MOCK_TMUX_CALLS"
  [ "$output" = "capture-pane -ep -t =my project:" ]
}

@test "chawan-preview.sh: empty target exits 0 without calling tmux" {
  run "$PREVIEW_SCRIPT" ""
  [ "$status" -eq 0 ]

  # MOCK_TMUX_CALLS file should be empty (no tmux calls)
  [ ! -s "$MOCK_TMUX_CALLS" ]
}

# --- trailing blank line stripping ---
# NOTE: Use file-based output checking (not bats "run") because bash command
# substitution strips trailing newlines, making it impossible to verify
# trailing blank lines were actually removed.

@test "chawan-preview.sh: strips trailing blank lines from output" {
  tmux() {
    printf '%s\n' "$*" >>"$MOCK_TMUX_CALLS"
    if [[ "$1" == "capture-pane" ]]; then
      printf 'line1\nline2\n\n\n\n'
    fi
  }
  export -f tmux

  "$PREVIEW_SCRIPT" "my-project" >"$PREVIEW_OUT"
  [ "$(wc -l <"$PREVIEW_OUT")" -eq 2 ]
  [ "$(sed -n '1p' "$PREVIEW_OUT")" = "line1" ]
  [ "$(sed -n '2p' "$PREVIEW_OUT")" = "line2" ]
}

@test "chawan-preview.sh: strips trailing lines with only ANSI sequences" {
  MOCK_ESC=$'\033'
  export MOCK_ESC
  tmux() {
    printf '%s\n' "$*" >>"$MOCK_TMUX_CALLS"
    if [[ "$1" == "capture-pane" ]]; then
      printf 'content\n%s[0m\n\n' "$MOCK_ESC"
    fi
  }
  export -f tmux

  "$PREVIEW_SCRIPT" "my-project" >"$PREVIEW_OUT"
  [ "$(wc -l <"$PREVIEW_OUT")" -eq 1 ]
  [ "$(sed -n '1p' "$PREVIEW_OUT")" = "content" ]
}

@test "chawan-preview.sh: preserves all lines when no trailing blanks" {
  tmux() {
    printf '%s\n' "$*" >>"$MOCK_TMUX_CALLS"
    if [[ "$1" == "capture-pane" ]]; then
      printf 'line1\nline2\nline3\n'
    fi
  }
  export -f tmux

  "$PREVIEW_SCRIPT" "my-project" >"$PREVIEW_OUT"
  [ "$(wc -l <"$PREVIEW_OUT")" -eq 3 ]
}

@test "chawan-preview.sh: all-blank output produces no output" {
  tmux() {
    printf '%s\n' "$*" >>"$MOCK_TMUX_CALLS"
    if [[ "$1" == "capture-pane" ]]; then
      printf '\n\n\n\n'
    fi
  }
  export -f tmux

  "$PREVIEW_SCRIPT" "my-project" >"$PREVIEW_OUT"
  [ ! -s "$PREVIEW_OUT" ]
}
