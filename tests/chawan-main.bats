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
  [ "$status" -eq 0 ]
  [ "$output" = "session" ]
}

@test "normalize_mode: session is preserved" {
  run normalize_mode "session"
  [ "$status" -eq 0 ]
  [ "$output" = "session" ]
}

@test "normalize_mode: window is preserved" {
  run normalize_mode "window"
  [ "$status" -eq 0 ]
  [ "$output" = "window" ]
}

@test "normalize_mode: pane is preserved" {
  run normalize_mode "pane"
  [ "$status" -eq 0 ]
  [ "$output" = "pane" ]
}

@test "normalize_mode: invalid input defaults to session" {
  run normalize_mode "invalid"
  [ "$status" -eq 0 ]
  [ "$output" = "session" ]
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
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
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
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
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
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
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
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

# --- build_footer ---

@test "build_footer: uses provided keybindings" {
  run build_footer "ctrl-n" "ctrl-x" "ctrl-e"
  [ "$status" -eq 0 ]
  [ "$output" = "enter:switch  ctrl-n:new  ctrl-x:del  ctrl-e:rename" ]
}

@test "build_footer: uses defaults when no args" {
  run build_footer
  [ "$status" -eq 0 ]
  [ "$output" = "enter:switch  ctrl-o:new  ctrl-d:del  ctrl-r:rename" ]
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
  [ "$status" -eq 0 ]

  run grep "> " "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
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
  [ "$status" -eq 0 ]

  run grep "> " "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
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
  [ "$status" -eq 0 ]

  run grep "^--preview$" "$FZF_ARGS_FILE"
  [ "$status" -eq 1 ]
  run grep "^--preview-window$" "$FZF_ARGS_FILE"
  [ "$status" -eq 1 ]
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
  [ "$status" -eq 0 ]

  run grep "ctrl-n:new" "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
  run grep "ctrl-x:del" "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
  run grep "ctrl-e:rename" "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
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
      list-panes) echo "main:0.0	0	bash	80x24	~/code" ;;
    esac
  }
  export -f tmux
  _mock_fzf

  run main
  [ "$status" -eq 0 ]

  run grep "> " "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
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
  [ "$status" -eq 0 ]

  run grep "center,120," "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
}

@test "find_current_pos: returns 1 for empty list" {
  tmux() {
    if [[ "$1" == "display-message" ]]; then
      echo "my-project"
    fi
  }
  export -f tmux

  run find_current_pos "session" ""
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
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
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
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
  [ "$status" -eq 0 ]

  run grep "result:pos(2)" "$FZF_ARGS_FILE"
  [ "$status" -eq 0 ]
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
  [ "$status" -eq 0 ]

  run grep "switch-client -t =default" "$MOCK_TMUX_CALLS"
  [ "$status" -eq 0 ]
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
