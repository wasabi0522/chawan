#!/usr/bin/env bash

# Output format (tab-separated): ID<tab>display
# Display: marker(*/space)  name(25ch)  details...
main() {
  local mode="${1:-}"
  local sep=$'\t'

  case "$mode" in
    session)
      # Column header (non-selectable via fzf --header-lines 1)
      printf '\t   %-25.25s  %s\n' "NAME" "WIN"
      # tmux fields: name, attached(1/0), window_count
      tmux list-sessions \
        -F "#{session_name}${sep}#{?session_attached,1,0}${sep}#{session_windows}" |
        awk -F'\t' '{
          m   = ($2 == "1") ? "*" : " "
          att = ($2 == "1") ? "  (attached)" : ""
          printf "%s\t%s  %-25.25s  %sw%s\n", $1, m, $1, $3, att
        }'
      ;;
    window)
      # Column header
      printf '\t   %-25.25s  %-15.15s  %-4s  %s\n' "ID" "NAME" "PANE" "PATH"
      # tmux fields: sess:idx, active(1/0), name, pane_count, path
      tmux list-windows -a \
        -F "#{session_name}:#{window_index}${sep}#{?window_active,#{?session_attached,1,0},0}${sep}#{window_name}${sep}#{window_panes}${sep}#{s|$HOME|~|:pane_current_path}" |
        awk -F'\t' '{
          m = ($2 == "1") ? "*" : " "
          printf "%s\t%s  %-25.25s  %-15.15s  %sp  %s\n", $1, m, $1, $3, $4, $5
        }'
      ;;
    pane)
      # Column header
      printf '\t   %-25.25s  %-12.12s  %-10s  %s\n' "ID" "CMD" "SIZE" "PATH"
      # tmux fields: sess:idx.pane, active(1/0), command, WxH, path
      tmux list-panes -a \
        -F "#{session_name}:#{window_index}.#{pane_index}${sep}#{?pane_active,#{?window_active,#{?session_attached,1,0},0},0}${sep}#{pane_current_command}${sep}#{pane_width}x#{pane_height}${sep}#{s|$HOME|~|:pane_current_path}" |
        awk -F'\t' '{
          m = ($2 == "1") ? "*" : " "
          printf "%s\t%s  %-25.25s  %-12.12s  %-10s  %s\n", $1, m, $1, $3, $4, $5
        }'
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
