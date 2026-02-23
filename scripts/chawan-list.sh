#!/usr/bin/env bash

# Output format (tab-separated): ID<tab>display
# Display: marker(*/space)  name(dynamic)  details...

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

# distribute_widths <available> <max_width1> <max_width2> ...
# Distributes available width among elastic columns based on content needs.
# Columns whose max content fits within equal share are shrunk to content width;
# freed space is redistributed to remaining columns.
# Output: width1 width2 ... (space-separated)
distribute_widths() {
  local available=$1
  shift
  local -a max_w=("$@")
  local n=${#max_w[@]}

  if ((available <= 0)); then
    local -a zeros=()
    local i
    for ((i = 0; i < n; i++)); do zeros+=(0); done
    echo "${zeros[*]}"
    return
  fi

  local -a result=()
  local -a fixed=()

  local i
  for ((i = 0; i < n; i++)); do
    result+=("${max_w[$i]}")
    fixed+=(0)
  done

  local remaining=$available
  local remaining_n=$n
  local changed=1

  while ((changed && remaining_n > 0)); do
    changed=0
    local share=$((remaining / remaining_n))

    for ((i = 0; i < n; i++)); do
      if ((fixed[i] == 0 && max_w[i] <= share)); then
        result[i]=${max_w[i]}
        fixed[i]=1
        remaining=$((remaining - result[i]))
        remaining_n=$((remaining_n - 1))
        changed=1
      fi
    done
  done

  if ((remaining_n > 0)); then
    local share=$((remaining / remaining_n))
    local leftover=$((remaining - share * remaining_n))
    local last=-1

    for ((i = 0; i < n; i++)); do
      if ((fixed[i] == 0)); then
        result[i]=$share
        last=$i
      fi
    done

    if ((last >= 0)); then
      result[last]=$((result[last] + leftover))
    fi
  fi

  echo "${result[*]}"
}

# _max_display_widths <data> <field_numbers...>
# Computes max display width for each specified field across all rows.
# Uses (max_byte_length + max_char_length) / 2 approximation, which is exact for
# ASCII and CJK (3-byte wide chars), and slightly overestimates for
# 2-byte narrow chars and emoji. Overestimation is safe (allocates extra space).
# Output: max_dw1 max_dw2 ... (space-separated)
_max_display_widths() {
  local data="$1"
  shift
  local field_spec="$*"
  local n=$#

  # Use -v to pass field indices to awk, avoiding shell expansion of $f[i]
  # shellcheck disable=SC2016
  local awk_script='
    BEGIN { n = split(fields, f, " "); for (i = 1; i <= n; i++) m[i] = 0 }
    { for (i = 1; i <= n; i++) { v = length($f[i]); if (v > m[i]) m[i] = v } }
    END { for (i = 1; i <= n; i++) { if (i > 1) printf " "; printf "%d", m[i] } print "" }
  '

  local byte_maxes char_maxes
  byte_maxes=$(echo "$data" | LC_ALL=C awk -F'\t' -v fields="$field_spec" "$awk_script")
  char_maxes=$(echo "$data" | awk -F'\t' -v fields="$field_spec" "$awk_script")

  # Combine: display_width ≈ (max_bytes + max_chars) / 2
  local -a bvals cvals
  read -ra bvals <<<"$byte_maxes"
  read -ra cvals <<<"$char_maxes"

  local out="" i
  for i in "${!bvals[@]}"; do
    ((i > 0)) && out+=" "
    out+="$(((bvals[i] + cvals[i]) / 2))"
  done
  echo "$out"
}

main() {
  local mode="${1:-}"
  local sep=$'\t'
  local cols="${CHAWAN_COLS:-80}"

  case "$mode" in
    session)
      local data
      data=$(tmux list-sessions \
        -F "#{session_name}${sep}#{?session_attached,1,0}${sep}#{session_windows}${sep}#{session_activity}")

      # Pre-scan: calculate max content widths (minimums = header label lengths)
      local max_name=4 max_win=3
      if [[ -n "$data" ]]; then
        # Display-width-aware measurement for text fields (CJK-safe)
        read -r max_name <<<"$(_max_display_widths "$data" 1)"
        ((max_name < 4)) && max_name=4

        # ASCII-only fields: char count is accurate
        read -r max_win <<<"$(echo "$data" | awk -F'\t' '
          BEGIN { mw = 3 }
          {
            att = ($2 == "1") ? 12 : 0
            w = length($3) + 1 + att
            if (w > mw) mw = w
          }
          END { print mw }
        ')"
      fi

      # Layout: PREFIX(3) + NAME(elastic) + SEP(2) + WIN(fixed=max_win)
      local available=$((cols - 3 - 2 - max_win))
      local name_w=$((available < max_name ? available : max_name))
      ((name_w < 4)) && name_w=4

      # Column header
      printf '\t   %-*.*s  %s\n' "$name_w" "$name_w" "NAME" "WIN"

      # Data (tmux format modifiers handle CJK alignment; lalign as fallback for tests)
      if [[ -n "$data" ]]; then
        tmux list-sessions \
          -F "#{session_name}${sep}#{?session_attached,1,0}${sep}#{session_windows}${sep}#{session_activity}${sep}#{p${name_w}:#{=${name_w}:session_name}}" |
          awk -F'\t' -v name_w="$name_w" "$_AWK_LALIGN"'{
            m   = ($2 == "1") ? "*" : " "
            att = ($2 == "1") ? "  (attached)" : ""
            fn  = ($5 != "") ? $5 : lalign($1, name_w)
            printf "%s\t%s  %s  %sw%s\t%s\t%s\n", $1, m, fn, $3, att, $1, $4
          }' | _apply_sort
      fi
      ;;
    window)
      local data
      data=$(tmux list-windows -a \
        -F "#{session_name}:#{window_index}${sep}#{?window_active,#{?session_attached,1,0},0}${sep}#{window_name}${sep}#{window_panes}${sep}#{window_activity}")

      # Pre-scan: calculate max content widths
      local max_id=2 max_name=4 max_pane=4
      if [[ -n "$data" ]]; then
        # Display-width-aware measurement for text fields
        read -r max_id max_name <<<"$(_max_display_widths "$data" 1 3)"
        ((max_id < 2)) && max_id=2
        ((max_name < 4)) && max_name=4

        # ASCII-only field
        read -r max_pane <<<"$(echo "$data" | awk -F'\t' '
          BEGIN { mp = 4 }
          { p = length($4) + 1; if (p > mp) mp = p }
          END { print mp }
        ')"
      fi

      # Layout: PREFIX(3) + ID(elastic) + SEP(2) + NAME(elastic) + SEP(2) + PANE(fixed)
      local available=$((cols - 3 - 2 - 2 - max_pane))
      local widths
      widths=$(distribute_widths "$available" "$max_id" "$max_name")
      local id_w name_w
      read -r id_w name_w <<<"$widths"
      ((id_w < 2)) && id_w=2
      ((name_w < 4)) && name_w=4

      # Column header
      printf '\t   %-*.*s  %-*.*s  %s\n' "$id_w" "$id_w" "ID" "$name_w" "$name_w" "NAME" "PANE"

      # Data (tmux format modifiers handle CJK alignment; lalign as fallback for tests)
      if [[ -n "$data" ]]; then
        local fmt_id="#{p${id_w}:#{=${id_w}:#{session_name}:#{window_index}}}"
        local fmt_name="#{p${name_w}:#{=${name_w}:window_name}}"
        tmux list-windows -a \
          -F "#{session_name}:#{window_index}${sep}#{?window_active,#{?session_attached,1,0},0}${sep}#{window_name}${sep}#{window_panes}${sep}#{window_activity}${sep}${fmt_id}${sep}${fmt_name}" |
          awk -F'\t' -v id_w="$id_w" -v name_w="$name_w" "$_AWK_LALIGN"'{
            m  = ($2 == "1") ? "*" : " "
            fi = ($6 != "") ? $6 : lalign($1, id_w)
            fn = ($7 != "") ? $7 : lalign($3, name_w)
            printf "%s\t%s  %s  %s  %sp\t%s\t%s\n", $1, m, fi, fn, $4, $3, $5
          }' | _apply_sort
      fi
      ;;
    pane)
      local data
      data=$(tmux list-panes -a \
        -F "#{session_name}:#{window_index}.#{pane_index}${sep}#{?pane_active,#{?window_active,#{?session_attached,1,0},0},0}${sep}#{pane_title}${sep}#{pane_current_command}${sep}#{pane_width}x#{pane_height}${sep}#{pane_activity}")

      # Pre-scan: calculate max content widths
      local max_id=2 max_title=5 max_cmd=3 max_size=4
      if [[ -n "$data" ]]; then
        # Display-width-aware measurement for text fields
        read -r max_id max_title max_cmd <<<"$(_max_display_widths "$data" 1 3 4)"
        ((max_id < 2)) && max_id=2
        ((max_title < 5)) && max_title=5
        ((max_cmd < 3)) && max_cmd=3

        # ASCII-only field
        read -r max_size <<<"$(echo "$data" | awk -F'\t' '
          BEGIN { ms = 4 }
          { s = length($5); if (s > ms) ms = s }
          END { print ms }
        ')"
      fi

      # Layout: PREFIX(3) + ID(elastic) + SEP(2) + TITLE(elastic) + SEP(2) + CMD(elastic) + SEP(2) + SIZE(fixed)
      local available=$((cols - 3 - 2 - 2 - 2 - max_size))
      local widths
      widths=$(distribute_widths "$available" "$max_id" "$max_title" "$max_cmd")
      local id_w title_w cmd_w
      read -r id_w title_w cmd_w <<<"$widths"
      ((id_w < 2)) && id_w=2
      ((title_w < 5)) && title_w=5
      ((cmd_w < 3)) && cmd_w=3

      # Column header
      printf '\t   %-*.*s  %-*.*s  %-*.*s  %s\n' \
        "$id_w" "$id_w" "ID" "$title_w" "$title_w" "TITLE" "$cmd_w" "$cmd_w" "CMD" "SIZE"

      # Data (tmux format modifiers handle CJK alignment; lalign as fallback for tests)
      if [[ -n "$data" ]]; then
        local fmt_id="#{p${id_w}:#{=${id_w}:#{session_name}:#{window_index}.#{pane_index}}}"
        local fmt_title="#{p${title_w}:#{=${title_w}:pane_title}}"
        local fmt_cmd="#{p${cmd_w}:#{=${cmd_w}:pane_current_command}}"
        tmux list-panes -a \
          -F "#{session_name}:#{window_index}.#{pane_index}${sep}#{?pane_active,#{?window_active,#{?session_attached,1,0},0},0}${sep}#{pane_title}${sep}#{pane_current_command}${sep}#{pane_width}x#{pane_height}${sep}#{pane_activity}${sep}${fmt_id}${sep}${fmt_title}${sep}${fmt_cmd}" |
          awk -F'\t' -v id_w="$id_w" -v title_w="$title_w" -v cmd_w="$cmd_w" "$_AWK_LALIGN"'{
            m  = ($2 == "1") ? "*" : " "
            fi = ($7 != "") ? $7 : lalign($1, id_w)
            ft = ($8 != "") ? $8 : lalign($3, title_w)
            fc = ($9 != "") ? $9 : lalign($4, cmd_w)
            printf "%s\t%s  %s  %s  %s  %s\t%s\t%s\n", $1, m, fi, ft, fc, $5, $3, $6
          }' | _apply_sort
      fi
      ;;
  esac
}

# Only run when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  set -euo pipefail
  main "$@"
fi
