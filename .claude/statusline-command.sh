#!/bin/bash
# Claude Code status line — Powerlevel10k-inspired with Nerd Font icons

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
branch=$(git --no-optional-locks -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
git_status=$(git --no-optional-locks -C "$cwd" status --porcelain 2>/dev/null)

# ── Colors (256-color for richer palette) ────────────────────────────────────
bold='\033[1m'
dim='\033[2m'
reset='\033[0m'

# Foreground
blue='\033[38;5;75m'        # soft cornflower blue   — directory
cyan='\033[38;5;80m'        # bright cyan            — accents
green='\033[38;5;114m'      # muted green            — clean branch
yellow='\033[38;5;221m'     # warm yellow            — dirty branch / mid usage
red='\033[38;5;203m'        # soft red               — high usage
magenta='\033[38;5;183m'    # lavender               — model name
grey='\033[38;5;245m'       # mid grey               — separators / low usage

# ── Icons (Nerd Font) ────────────────────────────────────────────────────────
icon_folder=$(printf '\uf07b ')    # nf-fa-folder
icon_branch=$(printf '\ue0a0 ')   # nf-dev-git_branch
icon_dirty='󰦒 '   # nf-md-source_branch_sync (U+F0E18)  — pending changes
icon_model='󱙺 '   # nf-md-robot (U+F167A)  — model / AI icon
icon_ctx='󰾆 '     # nf-md-gauge (U+F0F86)  — context gauge
icon_5h='󱑂 '      # nf-md-clock_fast (U+F1442)  — 5-hour window
icon_7d='󰃰 '      # nf-md-calendar_clock (U+F00F0)  — 7-day window
icon_hook='󰒓 '    # nf-md-cog (U+F04D3)   — hook running
sep='│'            # U+2502 thin vertical bar

# ── Helpers ──────────────────────────────────────────────────────────────────
# pct_color <int>  →  echoes an ANSI color escape for the given percentage
pct_color() {
  pct="$1"
  if [ "$pct" -ge 80 ]; then
    printf '%b' "$red"
  elif [ "$pct" -ge 50 ]; then
    printf '%b' "$yellow"
  else
    printf '%b' "$grey"
  fi
}

# ── Directory segment ─────────────────────────────────────────────────────────
home="$HOME"
short_cwd="${cwd/#$home/~}"
dir_seg=$(printf "${blue}${bold}${icon_folder}${reset}${blue}%s${reset}" "$short_cwd")

# ── Git segment ───────────────────────────────────────────────────────────────
git_seg=""
if [ -n "$branch" ]; then
  if [ -n "$git_status" ]; then
    git_seg=$(printf "${yellow}${icon_dirty}${branch}${reset}")
  else
    git_seg=$(printf "${green}${icon_branch}${branch}${reset}")
  fi
fi

# ── Hook status segment ───────────────────────────────────────────────────────
hook_seg=""
if [ -f /tmp/claude-hook-status.txt ]; then
  hook_msg=$(cat /tmp/claude-hook-status.txt 2>/dev/null)
  if [ -n "$hook_msg" ]; then
    hook_seg=$(printf "${cyan}${icon_hook}${hook_msg}${reset}")
  fi
fi

# ── Left side: dir  sep  git  sep  hook ──────────────────────────────────────
left=$(printf "%b" "$dir_seg")
if [ -n "$git_seg" ]; then
  left=$(printf "%b  ${grey}${sep}${reset}  %b" "$left" "$git_seg")
fi
if [ -n "$hook_seg" ]; then
  left=$(printf "%b  ${grey}${sep}${reset}  %b" "$left" "$hook_seg")
fi

# ── Model segment ─────────────────────────────────────────────────────────────
right=""
if [ -n "$model" ]; then
  right=$(printf "${magenta}${dim}${icon_model}${model}${reset}")
fi

# ── Context segment ───────────────────────────────────────────────────────────
if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")
  color=$(pct_color "$used_int")
  ctx_seg=$(printf "${color}${icon_ctx}ctx %s%%${reset}" "$used_int")
  if [ -n "$right" ]; then
    right=$(printf "%b  ${grey}${sep}${reset}  %b" "$right" "$ctx_seg")
  else
    right=$(printf "%b" "$ctx_seg")
  fi
fi

# ── 5-hour rate limit segment ────────────────────────────────────────────────
if [ -n "$five_pct" ]; then
  five_int=$(printf "%.0f" "$five_pct")
  color=$(pct_color "$five_int")
  rl5_seg=$(printf "${color}${icon_5h}5h %s%%${reset}" "$five_int")
  if [ -n "$right" ]; then
    right=$(printf "%b  ${grey}${sep}${reset}  %b" "$right" "$rl5_seg")
  else
    right=$(printf "%b" "$rl5_seg")
  fi
fi

# ── 7-day rate limit segment ──────────────────────────────────────────────────
if [ -n "$week_pct" ]; then
  week_int=$(printf "%.0f" "$week_pct")
  color=$(pct_color "$week_int")
  rl7_seg=$(printf "${color}${icon_7d}7d %s%%${reset}" "$week_int")
  if [ -n "$right" ]; then
    right=$(printf "%b  ${grey}${sep}${reset}  %b" "$right" "$rl7_seg")
  else
    right=$(printf "%b" "$rl7_seg")
  fi
fi

# ── Final output (pad between left and right to fill terminal width) ─────────
# Strip ANSI escapes to measure visible character width
strip_ansi() { printf '%b' "$1" | sed $'s/\033\[[0-9;]*m//g'; }

# wc -m counts characters (not bytes), handling multi-byte correctly
left_len=$(strip_ansi "$left" | wc -m | tr -d ' ')
right_len=$(strip_ansi "$right" | wc -m | tr -d ' ')

# Try multiple methods to get terminal width
cols=${COLUMNS:-0}
[ "$cols" -eq 0 ] && cols=$(tput cols 2>/dev/null || echo 0)
[ "$cols" -eq 0 ] && cols=$(stty size 2>/dev/null | awk '{print $2}')
[ -z "$cols" ] || [ "$cols" -eq 0 ] && cols=120
padding=$((cols - left_len - right_len))
[ "$padding" -lt 2 ] && padding=2

printf "%b%*s%b\n" "$left" "$padding" "" "$right"
