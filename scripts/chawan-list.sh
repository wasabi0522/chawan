#!/usr/bin/env bash

# Output format (tab-separated): ID<tab>display
# Display: marker(*/space)  name(25ch)  details...

# Sorts and strips the sort-key (third tab field) from formatted output.
# CHAWAN_SORT: "mru" (activity descending), "name" (alphabetical), default (no sort).
_apply_sort() {
  case "${CHAWAN_SORT:-default}" in
    mru) sort -t$'\t' -k4,4rn | cut -f1,2 ;;
    name) sort -t$'\t' -k3,3 | cut -f1,2 ;;
    *) cut -f1,2 ;;
  esac
}

main() {
  local mode="${1:-}"
  local sep=$'\t'

  case "$mode" in
    session)
      # Column header (non-selectable via fzf --header-lines 1)
      printf '\t   %-25.25s  %s\n' "NAME" "WIN"
      # tmux fields: name, attached(1/0), window_count, activity
      tmux list-sessions \
        -F "#{session_name}${sep}#{?session_attached,1,0}${sep}#{session_windows}${sep}#{session_activity}" |
        awk -F'\t' '{
          m   = ($2 == "1") ? "*" : " "
          att = ($2 == "1") ? "  (attached)" : ""
          printf "%s\t%s  %-25.25s  %sw%s\t%s\t%s\n", $1, m, $1, $3, att, $1, $4
        }' | _apply_sort
      ;;
    window)
      # Column header
      printf '\t   %-25.25s  %-15.15s  %-4s  %s\n' "ID" "NAME" "PANE" "PATH"
      # tmux fields: sess:idx, active(1/0), name, pane_count, path, activity
      tmux list-windows -a \
        -F "#{session_name}:#{window_index}${sep}#{?window_active,#{?session_attached,1,0},0}${sep}#{window_name}${sep}#{window_panes}${sep}#{s|$HOME|~|:pane_current_path}${sep}#{window_activity}" |
        awk -F'\t' '{
          m = ($2 == "1") ? "*" : " "
          printf "%s\t%s  %-25.25s  %-15.15s  %sp  %s\t%s\t%s\n", $1, m, $1, $3, $4, $5, $3, $6
        }' | _apply_sort
      ;;
    pane)
      # Column header
      printf '\t   %-25.25s  %-15.15s  %-12.12s  %s\n' "ID" "TITLE" "CMD" "SIZE"
      # tmux fields: sess:idx.pane, active(1/0), title, command, WxH, activity
      tmux list-panes -a \
        -F "#{session_name}:#{window_index}.#{pane_index}${sep}#{?pane_active,#{?window_active,#{?session_attached,1,0},0},0}${sep}#{pane_title}${sep}#{pane_current_command}${sep}#{pane_width}x#{pane_height}${sep}#{pane_activity}" |
        awk -F'\t' '{
          m = ($2 == "1") ? "*" : " "
          printf "%s\t%s  %-25.25s  %-15.15s  %-12.12s  %s\t%s\t%s\n", $1, m, $1, $3, $4, $5, $3, $6
        }' | _apply_sort
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
