#!/usr/bin/env bash

# Output format (tab-separated): ID<tab>display
# Display: marker(*/space)  name(25ch)  details...

# Character-aware left-align for awk (fallback when tmux-formatted field is unavailable).
# Uses length()/substr() which operate on characters (not bytes) in UTF-8 locales.
# Note: CJK wide characters (2 display columns) are counted as 1, so alignment may be
# slightly off. For accurate alignment, tmux format modifiers (=N, pN) are preferred.
_AWK_LALIGN='function lalign(s, w) { if (length(s) > w) s = substr(s, 1, w); while (length(s) < w) s = s " "; return s } '

# Sorts and strips the sort-key (third tab field) from formatted output.
# CHAWAN_SORT: "mru" (activity descending), "name" (alphabetical), default (no sort).
_apply_sort() {
  case "${CHAWAN_SORT:-default}" in
    mru) LC_ALL=C sort -t$'\t' -k4,4rn | LC_ALL=C cut -f1,2 ;;
    name) LC_ALL=C sort -t$'\t' -k3,3 | LC_ALL=C cut -f1,2 ;;
    *) LC_ALL=C cut -f1,2 ;;
  esac
}

main() {
  local mode="${1:-}"
  local sep=$'\t'

  case "$mode" in
    session)
      # Column header (non-selectable via fzf --header-lines 1)
      printf '\t   %-25.25s  %s\n' "NAME" "WIN"
      # tmux fields: name, attached(1/0), window_count, activity, fmt_name(25)
      tmux list-sessions \
        -F "#{session_name}${sep}#{?session_attached,1,0}${sep}#{session_windows}${sep}#{session_activity}${sep}#{p25:#{=25:session_name}}" |
        awk -F'\t' "$_AWK_LALIGN"'{
          m   = ($2 == "1") ? "*" : " "
          att = ($2 == "1") ? "  (attached)" : ""
          fn  = ($5 != "") ? $5 : lalign($1, 25)
          printf "%s\t%s  %s  %sw%s\t%s\t%s\n", $1, m, fn, $3, att, $1, $4
        }' | _apply_sort
      ;;
    window)
      # Column header
      printf '\t   %-25.25s  %-15.15s  %s\n' "ID" "NAME" "PANE"
      # tmux fields: sess:idx, active(1/0), name, pane_count, activity, fmt_name(15)
      tmux list-windows -a \
        -F "#{session_name}:#{window_index}${sep}#{?window_active,#{?session_attached,1,0},0}${sep}#{window_name}${sep}#{window_panes}${sep}#{window_activity}${sep}#{p15:#{=15:window_name}}" |
        awk -F'\t' "$_AWK_LALIGN"'{
          m  = ($2 == "1") ? "*" : " "
          fn = ($6 != "") ? $6 : lalign($3, 15)
          printf "%s\t%s  %s  %s  %sp\t%s\t%s\n", $1, m, lalign($1, 25), fn, $4, $3, $5
        }' | _apply_sort
      ;;
    pane)
      # Column header
      printf '\t   %-25.25s  %-15.15s  %-12.12s  %s\n' "ID" "TITLE" "CMD" "SIZE"
      # tmux fields: sess:idx.pane, active(1/0), title, command, WxH, activity, fmt_title(15), fmt_cmd(12)
      tmux list-panes -a \
        -F "#{session_name}:#{window_index}.#{pane_index}${sep}#{?pane_active,#{?window_active,#{?session_attached,1,0},0},0}${sep}#{pane_title}${sep}#{pane_current_command}${sep}#{pane_width}x#{pane_height}${sep}#{pane_activity}${sep}#{p15:#{=15:pane_title}}${sep}#{p12:#{=12:pane_current_command}}" |
        awk -F'\t' "$_AWK_LALIGN"'{
          m  = ($2 == "1") ? "*" : " "
          ft = ($7 != "") ? $7 : lalign($3, 15)
          fc = ($8 != "") ? $8 : lalign($4, 12)
          printf "%s\t%s  %s  %s  %s  %s\t%s\t%s\n", $1, m, lalign($1, 25), ft, fc, $5, $3, $6
        }' | _apply_sort
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
