#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
  mock_tmux_record_only

  PREVIEW_SCRIPT="$PROJECT_ROOT/scripts/chawan-preview.sh"
}

teardown() {
  teardown_mocks
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
