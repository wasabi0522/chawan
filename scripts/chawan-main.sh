#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Shell-escape for safe embedding in fzf action strings
printf -v ESCAPED_SCRIPTS_DIR '%q' "$CURRENT_DIR"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/helpers.sh"

# Normalizes mode name; invalid values default to "session".
normalize_mode() {
  local mode="${1:-}"
  case "$mode" in
    window | pane) echo "$mode" ;;
    *) echo "session" ;;
  esac
}

# Finds the 1-based cursor position for the current item in the list.
find_current_pos() {
  local mode="${1:-}"
  local list="${2:-}"
  local current_target pos
  case "$mode" in
    session)
      current_target=$(tmux display-message -p '#S')
      ;;
    window)
      current_target=$(tmux display-message -p '#{session_name}:#{window_index}')
      ;;
    pane)
      current_target=$(tmux display-message -p '#{session_name}:#{window_index}.#{pane_index}')
      ;;
  esac
  # NR - 1 adjusts for the header line (first line) added by chawan-list.sh
  pos=$(printf '%s\n' "$list" | awk -F'\t' -v target="$current_target" '$1 == target { print NR - 1; exit }')
  echo "${pos:-1}"
}

# Builds the footer text showing available keybindings.
build_footer() {
  local bind_new="${1:-ctrl-o}"
  local bind_delete="${2:-ctrl-d}"
  local bind_rename="${3:-ctrl-r}"
  echo "enter:switch  ${bind_new}:new  ${bind_delete}:del  ${bind_rename}:rename"
}

# Reads all tmux user options and sets local variables via nameref.
# shellcheck disable=SC2034
read_options() {
  default_mode=$(get_tmux_option "@chawan-default-mode" "session")
  default_mode=$(normalize_mode "$default_mode")
  popup_width=$(get_tmux_option "@chawan-popup-width" "80%")
  popup_height=$(get_tmux_option "@chawan-popup-height" "70%")
  preview_enabled=$(get_tmux_option "@chawan-preview" "on")
  preview_position=$(get_tmux_option "@chawan-preview-position" "right,50%")
  bind_new=$(get_tmux_option "@chawan-bind-new" "ctrl-o")
  bind_delete=$(get_tmux_option "@chawan-bind-delete" "ctrl-d")
  bind_rename=$(get_tmux_option "@chawan-bind-rename" "ctrl-r")
}

# Computes the available header width (visible columns) for the finder area,
# accounting for popup size, preview pane, and fzf border/padding.
compute_header_width() {
  local popup_w="$1" preview_on="$2" preview_pos="$3"
  local term_width popup_cols
  term_width=$(tmux display-message -p '#{client_width}')

  local raw_value="${popup_w%\%}"
  if [[ ! "$raw_value" =~ ^[0-9]+$ ]]; then
    popup_cols=80
  elif [[ "$popup_w" == *% ]]; then
    popup_cols=$((term_width * raw_value / 100))
  else
    popup_cols=$raw_value
  fi

  # 8 = fzf border + padding (4 left + 4 right)
  local fzf_chrome=8
  if [[ "$preview_on" == "on" && "$preview_pos" =~ ^(left|right) ]]; then
    local preview_pct=50
    if [[ "$preview_pos" =~ ([0-9]+)% ]]; then
      preview_pct="${BASH_REMATCH[1]}"
    fi
    echo $((popup_cols * (100 - preview_pct) / 100 - fzf_chrome))
  else
    echo $((popup_cols - fzf_chrome))
  fi
}

# Generates and exports HEADER_SESSION, HEADER_WINDOW, HEADER_PANE with
# right-aligned Tab/S-Tab hint.
build_headers() {
  local header_width="$1"
  local dim=$'\e[2m' rs_ansi=$'\e[0m'
  local hint="${dim}Tab/S-Tab: switch mode${rs_ansi}"

  # Visible character widths (excluding ANSI escape sequences):
  #   make_tab_bar output: defined by TAB_BAR_VISIBLE_LEN in helpers.sh
  #   hint text: "Tab/S-Tab: switch mode" = 22 chars
  local tab_visible_len=$TAB_BAR_VISIBLE_LEN hint_visible_len=22
  local gap=$((header_width - tab_visible_len - hint_visible_len))
  ((gap < 2)) && gap=2

  local padding
  printf -v padding '%*s' "$gap" ""

  HEADER_SESSION="$(make_tab_bar session)${padding}${hint}"
  HEADER_WINDOW="$(make_tab_bar window)${padding}${hint}"
  HEADER_PANE="$(make_tab_bar pane)${padding}${hint}"
  export HEADER_SESSION HEADER_WINDOW HEADER_PANE
}

main() {
  local default_mode popup_width popup_height
  local preview_enabled preview_position
  local bind_new bind_delete bind_rename
  read_options

  local header_width
  header_width=$(compute_header_width "$popup_width" "$preview_enabled" "$preview_position")
  build_headers "$header_width"

  # Determine initial header
  local initial_header
  case "$default_mode" in
    window) initial_header="$HEADER_WINDOW" ;;
    pane) initial_header="$HEADER_PANE" ;;
    *) initial_header="$HEADER_SESSION" ;;
  esac

  # Generate initial list and calculate current position
  local initial_list current_pos
  initial_list=$("$CURRENT_DIR/chawan-list.sh" "$default_mode")
  current_pos=$(find_current_pos "$default_mode" "$initial_list")

  # Preview options (auto-detects mode from target format)
  local preview_opts=()
  if [[ "$preview_enabled" == "on" ]]; then
    preview_opts=(
      --preview "$ESCAPED_SCRIPTS_DIR/chawan-preview.sh {1}"
      --preview-window "${preview_position},border-left"
      --preview-label ''
      --bind 'focus:transform-preview-label:echo " Preview: {2} "'
    )
  fi

  # Build footer from keybind settings
  local footer
  footer=$(build_footer "$bind_new" "$bind_delete" "$bind_rename")

  # Launch fzf (enter:accept outputs selected line; other actions handled by chawan-fzf-action.sh)
  # fzf exits 0 on selection, 1 on no match, 130 on abort (esc/ctrl-c)
  local selected fzf_exit=0
  selected=$(fzf --tmux "center,${popup_width},${popup_height}" \
    --layout reverse --header-first \
    --border rounded --border-label ' chawan ' \
    --header "$initial_header" --header-border line \
    --footer "$footer" \
    --prompt '> ' \
    --ansi --highlight-line --info right \
    --pointer '▍' \
    --color 'header:bold,footer:dim,pointer:bold,prompt:bold' \
    "${preview_opts[@]}" \
    --header-lines 1 \
    --with-nth '2..' --delimiter '\t' \
    --bind 'esc:abort' \
    --bind "result:pos($current_pos)" \
    --bind "tab:transform:$ESCAPED_SCRIPTS_DIR/chawan-fzf-action.sh tab {1}" \
    --bind "shift-tab:transform:$ESCAPED_SCRIPTS_DIR/chawan-fzf-action.sh shift-tab {1}" \
    --bind "click-header:transform:$ESCAPED_SCRIPTS_DIR/chawan-fzf-action.sh click-header \$FZF_CLICK_HEADER_WORD" \
    --bind "${bind_delete}:transform:$ESCAPED_SCRIPTS_DIR/chawan-fzf-action.sh delete {1}" \
    --bind "${bind_new}:transform:$ESCAPED_SCRIPTS_DIR/chawan-fzf-action.sh new {1}" \
    --bind "${bind_rename}:transform:$ESCAPED_SCRIPTS_DIR/chawan-fzf-action.sh rename {1}" \
    <<<"$initial_list") || fzf_exit=$?
  # Exit silently on user abort (1=no match, 130=esc/ctrl-c); propagate unexpected errors
  if [[ $fzf_exit -ne 0 && $fzf_exit -ne 1 && $fzf_exit -ne 130 ]]; then
    return "$fzf_exit"
  fi

  # Handle enter selection: switch to the chosen target
  if [[ -n "$selected" ]]; then
    local target mode
    target=$(printf '%s' "$selected" | cut -f1)
    mode=$(mode_from_id "$target")
    "$CURRENT_DIR/chawan-action.sh" switch "$mode" "$target"
  fi
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main
fi
