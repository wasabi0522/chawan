#!/usr/bin/env bash

get_tmux_option() {
  local option="$1"
  local default_value="$2"
  local value
  value=$(tmux show-option -gqv "$option")
  if [[ -n "$value" ]]; then
    echo "$value"
  else
    echo "$default_value"
  fi
}

version_ge() {
  local v1="$1" v2="$2"
  local IFS='.'
  read -ra parts1 <<<"$v1"
  read -ra parts2 <<<"$v2"

  local len=${#parts1[@]}
  [[ ${#parts2[@]} -gt $len ]] && len=${#parts2[@]}

  local i
  for ((i = 0; i < len; i++)); do
    local n1=$((10#${parts1[i]:-0}))
    local n2=$((10#${parts2[i]:-0}))
    if ((n1 > n2)); then
      return 0
    elif ((n1 < n2)); then
      return 1
    fi
  done
  return 0
}

display_message() {
  tmux display-message "$@"
}

# Determines mode from a tmux target ID format:
#   colon+dot → pane (e.g. "sess:0.1")
#   colon → window (e.g. "sess:0")
#   otherwise → session (e.g. "sess", "my.dotfiles")
mode_from_id() {
  local id="$1"
  if [[ "$id" == *:*.* ]]; then
    echo "pane"
  elif [[ "$id" == *:* ]]; then
    echo "window"
  else
    echo "session"
  fi
}

make_tab_bar() {
  local active="$1"
  local hl=$'\e[1;7m' rs=$'\e[0m'
  local s=" Session " w=" Window " p=" Pane "
  [[ "$active" == "session" ]] && s="${hl}${s}${rs}"
  [[ "$active" == "window" ]] && w="${hl}${w}${rs}"
  [[ "$active" == "pane" ]] && p="${hl}${p}${rs}"
  printf ' %s  %s  %s' "$s" "$w" "$p"
}
