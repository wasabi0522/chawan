#!/usr/bin/env bats

setup() {
  load test_helper

  setup_mocks
  setup_mock_output
  mock_tmux_with_output

  CHAWAN_LIST="$PROJECT_ROOT/scripts/chawan-list.sh"
}

teardown() {
  teardown_mocks
}

# --- Session mode ---

@test "chawan-list session: first line is column header" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto	0	3
EOF

  run "$CHAWAN_LIST" session
  assert_success
  # Header line: empty ID + tab + column labels
  local id display
  id="$(echo "${lines[0]}" | cut -f1)"
  [ -z "$id" ]
  display="$(echo "${lines[0]}" | cut -f2)"
  [[ "$display" == *"NAME"* ]]
  [[ "$display" == *"WIN"* ]]
}

@test "chawan-list session: formats list-sessions output correctly" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto	0	3
dotfiles	0	1
EOF

  run "$CHAWAN_LIST" session
  assert_success
  [ "${#lines[@]}" -eq 3 ]
  # Each line has ID<tab>display format (skip header at index 0)
  [[ "${lines[1]}" == prezto$'\t'"   "* ]]
  [[ "${lines[2]}" == dotfiles$'\t'"   "* ]]
}

@test "chawan-list session: attached session gets * marker" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto	0	3
my-project	1	2
EOF

  run "$CHAWAN_LIST" session
  assert_success
  # Non-attached: space marker
  [[ "${lines[1]}" == prezto$'\t'" "* ]]
  # Attached: * marker and (attached) suffix
  [[ "${lines[2]}" == my-project$'\t'"*"* ]]
  assert_line -n 2 --partial "(attached)"
}

@test "chawan-list session: non-attached session has no (attached) suffix" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto	0	3
EOF

  run "$CHAWAN_LIST" session
  assert_success
  refute_line -n 1 --partial "(attached)"
}

@test "chawan-list session: output is ID<tab>display two-field format" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto	0	3
EOF

  run "$CHAWAN_LIST" session
  assert_success
  # Split by tab: should have exactly 2 fields (check data line, not header)
  local id display
  id="$(echo "${lines[1]}" | cut -f1)"
  display="$(echo "${lines[1]}" | cut -f2)"
  [ "$id" = "prezto" ]
  [ -n "$display" ]
  # No additional tabs in display portion
  local tab_count
  tab_count="$(echo "${lines[1]}" | awk -F'\t' '{print NF}')"
  [ "$tab_count" -eq 2 ]
}

@test "chawan-list session: displays window count with 'w' suffix" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
my-project	0	5
EOF

  run "$CHAWAN_LIST" session
  assert_success
  assert_line -n 1 --partial "5w"
}

@test "chawan-list session: handles slash in session name" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
org/project	1	3
EOF

  run "$CHAWAN_LIST" session
  assert_success
  local id
  id="$(echo "${lines[1]}" | cut -f1)"
  [ "$id" = "org/project" ]
  assert_line -n 1 --partial "*"
  assert_line -n 1 --partial "(attached)"
}

@test "chawan-list session: display portion contains no literal backslash-t" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto	0	3
dotfiles	1	1
EOF

  run "$CHAWAN_LIST" session
  assert_success
  for line in "${lines[@]}"; do
    local display
    display="$(echo "$line" | cut -f2)"
    [[ "$display" != *\\t* ]]
  done
}

# --- Window mode ---

@test "chawan-list window: first line is column header" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	zsh	1
EOF

  run "$CHAWAN_LIST" window
  assert_success
  local id display
  id="$(echo "${lines[0]}" | cut -f1)"
  [ -z "$id" ]
  display="$(echo "${lines[0]}" | cut -f2)"
  [[ "$display" == *"ID"* ]]
  [[ "$display" == *"NAME"* ]]
  [[ "$display" == *"PANE"* ]]
}

@test "chawan-list window: formats list-windows output correctly" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	zsh	1
prezto:1	0	vim	2
EOF

  run "$CHAWAN_LIST" window
  assert_success
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[1]}" == prezto:0$'\t'* ]]
  [[ "${lines[2]}" == prezto:1$'\t'* ]]
}

@test "chawan-list window: active window in attached session gets * marker" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	zsh	1
my-project:0	1	vim	1
my-project:1	0	zsh	2
EOF

  run "$CHAWAN_LIST" window
  assert_success
  # prezto:0 not active
  [[ "${lines[1]}" == prezto:0$'\t'" "* ]]
  # my-project:0 is active in attached session
  [[ "${lines[2]}" == my-project:0$'\t'"*"* ]]
  # my-project:1 not active (even though session is attached)
  [[ "${lines[3]}" == my-project:1$'\t'" "* ]]
}

@test "chawan-list window: output is ID<tab>display two-field format" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	zsh	1
EOF

  run "$CHAWAN_LIST" window
  assert_success
  local tab_count
  tab_count="$(echo "${lines[1]}" | awk -F'\t' '{print NF}')"
  [ "$tab_count" -eq 2 ]
}

@test "chawan-list window: displays pane count" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	zsh	3
EOF

  run "$CHAWAN_LIST" window
  assert_success
  assert_line -n 1 --partial "3p"
}

@test "chawan-list window: displays window name" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	vim	1
EOF

  run "$CHAWAN_LIST" window
  assert_success
  assert_line -n 1 --partial "vim"
}

@test "chawan-list window: display portion contains no literal backslash-t" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0	0	zsh	1
prezto:1	0	vim	2
EOF

  run "$CHAWAN_LIST" window
  assert_success
  for line in "${lines[@]}"; do
    local display
    display="$(echo "$line" | cut -f2)"
    [[ "$display" != *\\t* ]]
  done
}

# --- Pane mode ---

@test "chawan-list pane: first line is column header" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0.0	0	prezto:0.0	zsh	212x103
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  local id display
  id="$(echo "${lines[0]}" | cut -f1)"
  [ -z "$id" ]
  display="$(echo "${lines[0]}" | cut -f2)"
  [[ "$display" == *"ID"* ]]
  [[ "$display" == *"TITLE"* ]]
  [[ "$display" == *"CMD"* ]]
  [[ "$display" == *"SIZE"* ]]
}

@test "chawan-list pane: formats list-panes output correctly" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0.0	0	prezto:0.0	zsh	212x103
prezto:0.1	0	prezto:0.1	vim	106x103
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[1]}" == prezto:0.0$'\t'* ]]
  [[ "${lines[2]}" == prezto:0.1$'\t'* ]]
}

@test "chawan-list pane: focused pane (active pane + active window + attached session) gets * marker" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0.0	0	prezto:0.0	zsh	212x103
my-project:0.0	1	my-project:0.0	claude	159x40
my-project:0.1	0	my-project:0.1	zsh	159x40
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  # prezto:0.0 not active
  [[ "${lines[1]}" == prezto:0.0$'\t'" "* ]]
  # my-project:0.0 focused (active pane + active window + attached session)
  [[ "${lines[2]}" == my-project:0.0$'\t'"*"* ]]
  # my-project:0.1 not active
  [[ "${lines[3]}" == my-project:0.1$'\t'" "* ]]
}

@test "chawan-list pane: active pane in non-active window does not get * marker" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
my-project:0.0	1	my-project:0.0	claude	159x40
my-project:1.0	0	my-project:1.0	zsh	159x40
my-project:1.1	0	my-project:1.1	vim	159x40
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  # my-project:0.0 focused pane (active pane + active window + attached session)
  [[ "${lines[1]}" == my-project:0.0$'\t'"*"* ]]
  # my-project:1.0 active pane in non-active window — no marker
  [[ "${lines[2]}" == my-project:1.0$'\t'" "* ]]
  # my-project:1.1 not active at all
  [[ "${lines[3]}" == my-project:1.1$'\t'" "* ]]
}

@test "chawan-list pane: output is ID<tab>display two-field format" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0.0	0	prezto:0.0	zsh	212x103
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  local tab_count
  tab_count="$(echo "${lines[1]}" | awk -F'\t' '{print NF}')"
  [ "$tab_count" -eq 2 ]
}

@test "chawan-list pane: displays title, command, and dimensions" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0.0	0	my-pane	zsh	212x103
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  assert_line -n 1 --partial "my-pane"
  assert_line -n 1 --partial "zsh"
  assert_line -n 1 --partial "212x103"
}

@test "chawan-list pane: display portion contains no literal backslash-t" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
prezto:0.0	0	prezto:0.0	zsh	212x103
prezto:0.1	0	prezto:0.1	vim	106x103
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  for line in "${lines[@]}"; do
    local display
    display="$(echo "$line" | cut -f2)"
    [[ "$display" != *\\t* ]]
  done
}

# --- MRU sort ---

@test "chawan-list session: mru sort orders by activity descending" {
  export CHAWAN_SORT=mru
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
alpha	0	2	1000
beta	0	1	3000
gamma	0	3	2000
EOF

  run "$CHAWAN_LIST" session
  assert_success
  [[ "${lines[1]}" == beta$'\t'* ]]
  [[ "${lines[2]}" == gamma$'\t'* ]]
  [[ "${lines[3]}" == alpha$'\t'* ]]
}

@test "chawan-list window: mru sort orders by activity descending" {
  export CHAWAN_SORT=mru
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
alpha:0	0	zsh	1	1000
beta:0	0	vim	2	3000
gamma:0	0	zsh	1	2000
EOF

  run "$CHAWAN_LIST" window
  assert_success
  [[ "${lines[1]}" == beta:0$'\t'* ]]
  [[ "${lines[2]}" == gamma:0$'\t'* ]]
  [[ "${lines[3]}" == alpha:0$'\t'* ]]
}

@test "chawan-list pane: mru sort orders by activity descending" {
  export CHAWAN_SORT=mru
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
alpha:0.0	0	alpha:0.0	zsh	80x24	1000
beta:0.0	0	beta:0.0	vim	80x24	3000
gamma:0.0	0	gamma:0.0	zsh	80x24	2000
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  [[ "${lines[1]}" == beta:0.0$'\t'* ]]
  [[ "${lines[2]}" == gamma:0.0$'\t'* ]]
  [[ "${lines[3]}" == alpha:0.0$'\t'* ]]
}

# --- Name sort ---

@test "chawan-list session: name sort orders alphabetically" {
  export CHAWAN_SORT=name
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
gamma	0	3	2000
alpha	0	2	1000
beta	0	1	3000
EOF

  run "$CHAWAN_LIST" session
  assert_success
  [[ "${lines[1]}" == alpha$'\t'* ]]
  [[ "${lines[2]}" == beta$'\t'* ]]
  [[ "${lines[3]}" == gamma$'\t'* ]]
}

@test "chawan-list window: name sort orders by window name" {
  export CHAWAN_SORT=name
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
sess:0	0	zsh	1	1000
sess:1	0	bash	2	3000
sess:2	0	vim	1	2000
EOF

  run "$CHAWAN_LIST" window
  assert_success
  [[ "${lines[1]}" == sess:1$'\t'* ]]
  [[ "${lines[2]}" == sess:2$'\t'* ]]
  [[ "${lines[3]}" == sess:0$'\t'* ]]
}

@test "chawan-list pane: name sort orders by pane title" {
  export CHAWAN_SORT=name
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
sess:0.0	0	z-title	zsh	80x24	1000
sess:0.1	0	a-title	vim	80x24	3000
sess:0.2	0	m-title	zsh	80x24	2000
EOF

  run "$CHAWAN_LIST" pane
  assert_success
  [[ "${lines[1]}" == sess:0.1$'\t'* ]]
  [[ "${lines[2]}" == sess:0.2$'\t'* ]]
  [[ "${lines[3]}" == sess:0.0$'\t'* ]]
}

# --- Default sort ---

@test "chawan-list session: default sort preserves tmux order" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
gamma	0	3	2000
alpha	0	2	1000
beta	0	1	3000
EOF

  run "$CHAWAN_LIST" session
  assert_success
  [[ "${lines[1]}" == gamma$'\t'* ]]
  [[ "${lines[2]}" == alpha$'\t'* ]]
  [[ "${lines[3]}" == beta$'\t'* ]]
}

# --- Unknown mode ---

@test "chawan-list session: handles space in session name" {
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
my project	0	2	1000
EOF

  run "$CHAWAN_LIST" session
  assert_success
  local id
  id="$(echo "${lines[1]}" | cut -f1)"
  [ "$id" = "my project" ]
}

@test "chawan-list unknown mode: returns empty output with exit 0" {
  run "$CHAWAN_LIST" unknown
  assert_success
  assert_output ""
}

@test "chawan-list no argument: returns empty output with exit 0" {
  run "$CHAWAN_LIST"
  assert_success
  assert_output ""
}

# --- distribute_widths ---

@test "distribute_widths: all columns fit within equal share" {
  source "$CHAWAN_LIST"
  run distribute_widths 60 5 10 15
  assert_success
  assert_output "5 10 15"
}

@test "distribute_widths: some columns need truncation" {
  source "$CHAWAN_LIST"
  run distribute_widths 60 5 30 50
  assert_success
  # Pass1: share=20, col0(5<=20) fixed=5, remaining=55
  # Pass2: share=27, col1(30>27) unfixed, col2(50>27) unfixed
  # Final: col1=27, col2=27+1=28
  assert_output "5 27 28"
}

@test "distribute_widths: zero available returns all zeros" {
  source "$CHAWAN_LIST"
  run distribute_widths 0 10 20
  assert_success
  assert_output "0 0"
}

@test "distribute_widths: negative available returns all zeros" {
  source "$CHAWAN_LIST"
  run distribute_widths -5 10 20
  assert_success
  assert_output "0 0"
}

@test "distribute_widths: single column gets all available" {
  source "$CHAWAN_LIST"
  run distribute_widths 40 100
  assert_success
  assert_output "40"
}

@test "distribute_widths: single column fits within available" {
  source "$CHAWAN_LIST"
  run distribute_widths 40 10
  assert_success
  assert_output "10"
}

# --- CHAWAN_COLS dynamic width ---

@test "chawan-list session: CHAWAN_COLS controls column width" {
  export CHAWAN_COLS=40
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
short	0	2
EOF

  run "$CHAWAN_LIST" session
  assert_success
  [[ "${lines[1]}" == short$'\t'* ]]
  assert_line -n 1 --partial "2w"
}

@test "chawan-list session: narrow CHAWAN_COLS truncates long name" {
  export CHAWAN_COLS=20
  cat >"$MOCK_TMUX_OUTPUT" <<'EOF'
very-long-session-name-here	0	2
EOF

  run "$CHAWAN_LIST" session
  assert_success
  # Name should be truncated but still present as ID
  local id
  id="$(echo "${lines[1]}" | cut -f1)"
  [ "$id" = "very-long-session-name-here" ]
}
