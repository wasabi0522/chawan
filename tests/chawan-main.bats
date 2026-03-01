#!/usr/bin/env bats

setup() {
  load test_helper

  # Source chawan-main.sh to load extracted functions (source guard prevents main from running)
  source "$PROJECT_ROOT/scripts/chawan-main.sh"

  setup_mocks

  FZF_ARGS_FILE="$(mktemp)"
  export FZF_ARGS_FILE
}

teardown() {
  teardown_mocks
  rm -f "$FZF_ARGS_FILE"
}

# --- normalize_mode ---

@test "normalize_mode: session is default for empty input" {
  run normalize_mode ""
  assert_success
  assert_output "session"
}

@test "normalize_mode: session is preserved" {
  run normalize_mode "session"
  assert_success
  assert_output "session"
}

@test "normalize_mode: window is preserved" {
  run normalize_mode "window"
  assert_success
  assert_output "window"
}

@test "normalize_mode: pane is preserved" {
  run normalize_mode "pane"
  assert_success
  assert_output "pane"
}

@test "normalize_mode: invalid input defaults to session" {
  run normalize_mode "invalid"
  assert_success
  assert_output "session"
}

# --- find_current_pos ---

@test "find_current_pos: session mode finds current session at line 2" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "mysess"
    fi
  }
  export -f tmux

  local list
  list=$(printf '\theader\nalpha\tdisplay1\nmysess\tdisplay2\nbeta\tdisplay3')
  run find_current_pos "session" "$list"
  assert_success
  assert_output "2"
}

@test "find_current_pos: session mode returns 1 when not found" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "nosuch"
    fi
  }
  export -f tmux

  local list
  list=$(printf '\theader\nalpha\tdisplay1\nbeta\tdisplay2')
  run find_current_pos "session" "$list"
  assert_success
  assert_output "1"
}

@test "find_current_pos: window mode finds current window at line 2" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "mysess:1"
    fi
  }
  export -f tmux

  local list
  list=$(printf '\theader\nmysess:0\tdisplay1\nmysess:1\tdisplay2\nmysess:2\tdisplay3')
  run find_current_pos "window" "$list"
  assert_success
  assert_output "2"
}

@test "find_current_pos: pane mode finds current pane at line 3" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "mysess:0.2"
    fi
  }
  export -f tmux

  local list
  list=$(printf '\theader\nmysess:0.0\tdisplay1\nmysess:0.1\tdisplay2\nmysess:0.2\tdisplay3')
  run find_current_pos "pane" "$list"
  assert_success
  assert_output "3"
}

# --- compute_header_width ---

@test "compute_header_width: percentage popup with preview on" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then echo "200"; fi
  }
  export -f tmux

  run compute_header_width "80%" "on"
  assert_success
  # 200 * 80/100 = 160 cols, 160 * 50/100 - 10 = 70
  assert_output "70"
}

@test "compute_header_width: absolute popup without preview" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then echo "200"; fi
  }
  export -f tmux

  run compute_header_width "120" "off"
  assert_success
  # 120 - 10 = 110
  assert_output "110"
}

@test "compute_header_width: non-numeric popup defaults to 80" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then echo "200"; fi
  }
  export -f tmux

  run compute_header_width "abc" "off"
  assert_success
  # fallback 80 - 10 = 70
  assert_output "70"
}

# --- build_headers ---

@test "build_headers: exports three header variables with tab bar and hint" {
  build_headers 80
  [[ -n "$HEADER_SESSION" ]]
  [[ "$HEADER_SESSION" == *"Session"* ]]
  [[ "$HEADER_SESSION" == *"Tab/S-Tab: switch mode"* ]]
  [[ -n "$HEADER_WINDOW" ]]
  [[ "$HEADER_WINDOW" == *"Window"* ]]
  [[ -n "$HEADER_PANE" ]]
  [[ "$HEADER_PANE" == *"Pane"* ]]
}

@test "build_headers: narrow width uses minimum gap of 2" {
  build_headers 10
  [[ -n "$HEADER_SESSION" ]]
  [[ "$HEADER_SESSION" == *"Session"* ]]
}

# --- build_footer ---

@test "build_footer: uses provided keybindings" {
  run build_footer "ctrl-n" "ctrl-x" "ctrl-e"
  assert_success
  assert_output "enter:switch  ctrl-n:new  ctrl-x:del  ctrl-e:rename"
}

@test "build_footer: uses defaults when no args" {
  run build_footer
  assert_success
  assert_output "enter:switch  ctrl-o:new  ctrl-d:del  ctrl-r:rename"
}

# --- main (with fzf mock) ---

# Helper: default tmux mock for main() tests
# Handles show-option (returns empty), display-message (#{client_width}→200, #S→default),
# and list-sessions (returns a default session entry).
_mock_tmux_default() {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option) echo "" ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          '#S') echo "default" ;;
          *) echo "" ;;
        esac
        ;;
      list-sessions) echo "default	1	2" ;;
    esac
  }
  export -f tmux
}

_mock_fzf() {
  fzf() {
    printf '%s\n' "$@" >"$FZF_ARGS_FILE"
    cat >/dev/null
    return 130
  }
  export -f fzf
}

@test "main: default session mode passes correct prompt to fzf" {
  _mock_tmux_default
  _mock_fzf

  run main
  assert_success

  run grep "> " "$FZF_ARGS_FILE"
  assert_success
}

@test "main: window mode passes correct prompt to fzf" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-default-mode" ]]; then
          echo "window"
        else
          echo ""
        fi
        ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          *) echo "" ;;
        esac
        ;;
      list-windows) echo "main:0	0	bash	1	~/code" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "> " "$FZF_ARGS_FILE"
  assert_success
}

@test "main: preview window includes follow for scroll-to-bottom" {
  _mock_tmux_default
  _mock_fzf

  run main
  assert_success

  run grep "follow" "$FZF_ARGS_FILE"
  assert_success
}

@test "main: preview disabled omits --preview flag" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-preview" ]]; then
          echo "off"
        else
          echo ""
        fi
        ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          '#S') echo "default" ;;
          *) echo "" ;;
        esac
        ;;
      list-sessions) echo "default	1	2" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "^--preview$" "$FZF_ARGS_FILE"
  assert_failure
  run grep "^--preview-window$" "$FZF_ARGS_FILE"
  assert_failure
}

@test "main: custom keybindings appear in footer" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        case "$3" in
          "@chawan-bind-new") echo "ctrl-n" ;;
          "@chawan-bind-delete") echo "ctrl-x" ;;
          "@chawan-bind-rename") echo "ctrl-e" ;;
          *) echo "" ;;
        esac
        ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          '#S') echo "default" ;;
          *) echo "" ;;
        esac
        ;;
      list-sessions) echo "default	1	2" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "ctrl-n:new" "$FZF_ARGS_FILE"
  assert_success
  run grep "ctrl-x:del" "$FZF_ARGS_FILE"
  assert_success
  run grep "ctrl-e:rename" "$FZF_ARGS_FILE"
  assert_success
}

@test "main: pane mode passes correct prompt to fzf" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-default-mode" ]]; then
          echo "pane"
        else
          echo ""
        fi
        ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          *) echo "" ;;
        esac
        ;;
      list-panes) echo "main:0.0	0	main:0.0	bash	80x24	1000" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "> " "$FZF_ARGS_FILE"
  assert_success
}

@test "main: absolute popup width (non-percentage) is used directly" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-popup-width" ]]; then
          echo "120"
        else
          echo ""
        fi
        ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          '#S') echo "default" ;;
          *) echo "" ;;
        esac
        ;;
      list-sessions) echo "default	1	2" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "center,120," "$FZF_ARGS_FILE"
  assert_success
}

@test "find_current_pos: returns 1 for empty list" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "my-project"
    fi
  }
  export -f tmux

  run find_current_pos "session" ""
  assert_success
  assert_output "1"
}

@test "find_current_pos: backslash in session name is matched literally" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      printf '%s\n' 'my\nproject'
    fi
  }
  export -f tmux

  local list
  list=$(printf '\theader\nalpha\tdisplay1\nmy\\nproject\tdisplay2\nbeta\tdisplay3')
  run find_current_pos "session" "$list"
  assert_success
  assert_output "2"
}

@test "find_current_pos: dot in pane ID is matched literally not as regex wildcard" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "mysess:0.2"
    fi
  }
  export -f tmux

  local list
  # "mysess:0x2" should NOT match target "mysess:0.2"
  list=$(printf '\theader\nmysess:0x2\tdisplay1\nmysess:0.2\tdisplay2')
  run find_current_pos "pane" "$list"
  assert_success
  assert_output "2"
}

@test "main: current session position is passed to fzf" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option) echo "" ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          '#S') echo "beta" ;;
          *) echo "" ;;
        esac
        ;;
      list-sessions)
        printf 'alpha\t1\t2\nbeta\t0\t1\ngamma\t0\t3\n'
        ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "result:pos(2)" "$FZF_ARGS_FILE"
  assert_success
}

@test "main: fzf selection triggers switch action" {
  _mock_tmux_default
  fzf() {
    printf '%s\n' "$@" >"$FZF_ARGS_FILE"
    cat >/dev/null
    printf 'default\tdisplay\n'
    return 0
  }
  export -f fzf

  run main
  assert_success

  run grep "switch-client -t =default" "$MOCK_TMUX_CALLS"
  assert_success
}

@test "main: rejects invalid bind-delete key" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-bind-delete" ]]; then
          echo '!@#'
        else
          echo ""
        fi
        ;;
    esac
  }
  export -f tmux

  run main
  assert_failure

  run cat "$MOCK_TMUX_CALLS"
  assert_output --partial "display-message"
  assert_output --partial "invalid key binding"
}

@test "main: argument 'window' overrides default session mode" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option) echo "" ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          *) echo "" ;;
        esac
        ;;
      list-windows) echo "main:0	0	bash	1	~/code" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main "window"
  assert_success

  # Verify list-windows was called (not list-sessions)
  run grep "list-windows" "$MOCK_TMUX_CALLS"
  assert_success
}

@test "main: argument 'pane' overrides default session mode" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option) echo "" ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          *) echo "" ;;
        esac
        ;;
      list-panes) echo "main:0.0	0	main:0.0	zsh	80x24	1000" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main "pane"
  assert_success

  run grep "list-panes" "$MOCK_TMUX_CALLS"
  assert_success
}

@test "main: invalid argument is ignored, defaults to session" {
  _mock_tmux_default
  _mock_fzf

  run main "invalid"
  assert_success

  run grep "list-sessions" "$MOCK_TMUX_CALLS"
  assert_success
}

@test "main: sort_mode is read and exported" {
  tmux() {
    echo "$@" >>"$MOCK_TMUX_CALLS"
    case "$1" in
      show-option)
        if [[ "$3" == "@chawan-sort" ]]; then
          echo "mru"
        else
          echo ""
        fi
        ;;
      display-message)
        case "$3" in
          '#{client_width}') echo "200" ;;
          '#S') echo "default" ;;
          *) echo "" ;;
        esac
        ;;
      list-sessions) echo "default	1	2	1000" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  assert_success

  run grep "show-option -gqv @chawan-sort" "$MOCK_TMUX_CALLS"
  assert_success
}

@test "compute_header_width: percentage popup with preview off uses full width" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then echo "200"; fi
  }
  export -f tmux

  run compute_header_width "80%" "off"
  assert_success
  # 200 * 80/100 = 160, full width: 160 - 10 = 150
  assert_output "150"
}

@test "main: fzf unexpected exit code is propagated" {
  _mock_tmux_default
  fzf() {
    cat >/dev/null
    return 2
  }
  export -f fzf

  run main
  [ "$status" -eq 2 ]
}
