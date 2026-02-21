#!/usr/bin/env bats

setup() {
  load test_helper

  source "$PROJECT_ROOT/scripts/chawan-fzf-action.sh"
}

# --- next_mode ---

@test "next_mode: session -> window" {
  run next_mode "session"
  [ "$output" = "window" ]
}

@test "next_mode: window -> pane" {
  run next_mode "window"
  [ "$output" = "pane" ]
}

@test "next_mode: pane -> session" {
  run next_mode "pane"
  [ "$output" = "session" ]
}

# --- prev_mode ---

@test "prev_mode: session -> pane" {
  run prev_mode "session"
  [ "$output" = "pane" ]
}

@test "prev_mode: window -> session" {
  run prev_mode "window"
  [ "$output" = "session" ]
}

@test "prev_mode: pane -> window" {
  run prev_mode "pane"
  [ "$output" = "window" ]
}

# --- tab action (next mode) ---

@test "tab: from session (plain ID) switches to window" {
  run main tab "mysess"
  [[ "$output" == *"chawan-list.sh window"* ]]
  [[ "$output" == *"change-header"* ]]
}

@test "tab: from window (colon ID) switches to pane" {
  run main tab "mysess:0"
  [[ "$output" == *"chawan-list.sh pane"* ]]
}

@test "tab: from pane (dot ID) switches to session" {
  run main tab "mysess:0.1"
  [[ "$output" == *"chawan-list.sh session"* ]]
}

# --- shift-tab action (prev mode) ---

@test "shift-tab: from session (plain ID) switches to pane" {
  run main shift-tab "mysess"
  [[ "$output" == *"chawan-list.sh pane"* ]]
}

@test "shift-tab: from window (colon ID) switches to session" {
  run main shift-tab "mysess:0"
  [[ "$output" == *"chawan-list.sh session"* ]]
}

@test "shift-tab: from pane (dot ID) switches to window" {
  run main shift-tab "mysess:0.1"
  [[ "$output" == *"chawan-list.sh window"* ]]
}

# --- click-header action ---

@test "click-header: Session word switches to session" {
  run main click-header "Session"
  [[ "$output" == *"chawan-list.sh session"* ]]
}

@test "click-header: Window word switches to window" {
  run main click-header "Window"
  [[ "$output" == *"chawan-list.sh window"* ]]
}

@test "click-header: Pane word switches to pane" {
  run main click-header "Pane"
  [[ "$output" == *"chawan-list.sh pane"* ]]
}

@test "click-header: unknown word produces no output" {
  run main click-header "Unknown"
  [ -z "$output" ]
}

# --- delete action ---

@test "delete: session target generates reload-sync with delete session" {
  run main delete "mysess"
  [[ "$output" == "reload-sync("*"chawan-action.sh delete session mysess"* ]]
  [[ "$output" == *"chawan-list.sh session)" ]]
}

@test "delete: window target generates reload-sync with delete window" {
  run main delete "mysess:0"
  [[ "$output" == "reload-sync("*"chawan-action.sh delete window mysess:0"* ]]
  [[ "$output" == *"chawan-list.sh window)" ]]
}

@test "delete: pane target generates reload-sync with delete pane" {
  run main delete "mysess:0.1"
  [[ "$output" == "reload-sync("*"chawan-action.sh delete pane mysess:0.1"* ]]
  [[ "$output" == *"chawan-list.sh pane)" ]]
}

# --- new action ---

@test "new: session target generates execute+abort pattern" {
  run main new "mysess"
  [[ "$output" == "execute("*"chawan-create.sh session)+abort" ]]
}

@test "new: window target generates reload-sync with create window" {
  run main new "mysess:0"
  [[ "$output" == "reload-sync("*"chawan-create.sh window mysess:0"* ]]
  [[ "$output" == *"chawan-list.sh window)" ]]
}

@test "new: pane target generates reload-sync with create pane" {
  run main new "mysess:0.1"
  [[ "$output" == "reload-sync("*"chawan-create.sh pane mysess:0.1"* ]]
  [[ "$output" == *"chawan-list.sh pane)" ]]
}

# --- rename action ---

@test "rename: session target generates execute+reload" {
  run main rename "mysess"
  [[ "$output" == "execute("*"chawan-rename.sh session mysess)+reload("*"chawan-list.sh session)" ]]
}

@test "rename: window target generates execute+reload" {
  run main rename "mysess:0"
  [[ "$output" == "execute("*"chawan-rename.sh window mysess:0)+reload("*"chawan-list.sh window)" ]]
}

@test "rename: pane target generates execute+reload" {
  run main rename "mysess:0.1"
  [[ "$output" == "execute("*"chawan-rename.sh pane mysess:0.1)+reload("*"chawan-list.sh pane)" ]]
}

# --- switch_to_mode generates correct fzf actions ---

# --- shell escaping for safety ---

@test "delete: target with space is shell-escaped in action output" {
  run main delete "a b"
  local escaped
  printf -v escaped '%q' "a b"
  echo "$output" | grep -qF "chawan-action.sh delete session ${escaped}"
}

@test "rename: target with semicolon is shell-escaped in action output" {
  run main rename "a;b"
  local escaped
  printf -v escaped '%q' "a;b"
  echo "$output" | grep -qF "chawan-rename.sh session ${escaped}"
}

@test "new: window target with space is shell-escaped in action output" {
  run main new "a b:0"
  local escaped
  printf -v escaped '%q' "a b:0"
  echo "$output" | grep -qF "chawan-create.sh window ${escaped}"
}

@test "delete: target with dollar sign is shell-escaped" {
  run main delete 'a$b'
  local escaped
  printf -v escaped '%q' 'a$b'
  echo "$output" | grep -qF "chawan-action.sh delete session ${escaped}"
}

@test "rename: target with backtick is shell-escaped" {
  run main rename 'a`b'
  local escaped
  printf -v escaped '%q' 'a`b'
  echo "$output" | grep -qF "chawan-rename.sh session ${escaped}"
}

@test "delete: target with single quote is shell-escaped" {
  run main delete "a'b"
  local escaped
  printf -v escaped '%q' "a'b"
  echo "$output" | grep -qF "chawan-action.sh delete session ${escaped}"
}

# --- next_mode / prev_mode default case ---

@test "next_mode: unknown input defaults to session (returns window)" {
  run next_mode "invalid"
  [ "$output" = "session" ]
}

@test "prev_mode: unknown input defaults to session" {
  run prev_mode "invalid"
  [ "$output" = "session" ]
}

# --- switch_to_mode ---

# --- empty argument ---

@test "main: empty action produces no output" {
  run main "" ""
  [ -z "$output" ]
}

@test "tab: empty arg treats as session mode" {
  run main tab ""
  [[ "$output" == *"chawan-list.sh window"* ]]
}

@test "delete: empty arg treats as session mode" {
  run main delete ""
  [[ "$output" == "reload-sync("*"chawan-action.sh delete session"* ]]
}

# --- switch_to_mode ---

@test "switch_to_mode: includes reload, change-prompt, change-header, first" {
  run switch_to_mode "session"
  [[ "$output" == "reload("* ]]
  [[ "$output" == *"change-prompt(> )"* ]]
  [[ "$output" == *"change-header("* ]]
  [[ "$output" == *"+first" ]]
}
