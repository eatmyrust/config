#!/bin/bash
# Claude Code status line
# Shows: current directory | git branch | model | context remaining %

input=$(cat)

DIM='\033[2m'
RESET='\033[0m'
CYAN='\033[2;36m'
YELLOW='\033[2;33m'
GREEN='\033[2;32m'
MAGENTA='\033[2;35m'

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
dir_display=$(basename "$cwd" 2>/dev/null)
[ -z "$dir_display" ] && dir_display="$cwd"

branch=""
if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
fi

model=$(echo "$input" | jq -r '.model.display_name // empty')

tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')

parts=()
parts+=("$(printf "${CYAN}%s${RESET}" "$dir_display")")
[ -n "$branch" ] && parts+=("$(printf "${GREEN}(%s)${RESET}" "$branch")")
[ -n "$model" ] && parts+=("$(printf "${MAGENTA}%s${RESET}" "$model")")
if [ -n "$tokens" ]; then
  if [ "$tokens" -ge 1000 ]; then
    tokens_display=$(awk -v t="$tokens" 'BEGIN { printf "%.1fk", t/1000 }')
  else
    tokens_display="$tokens"
  fi
  parts+=("$(printf "${YELLOW}%s tokens${RESET}" "$tokens_display")")
fi

out=""
for p in "${parts[@]}"; do
  if [ -z "$out" ]; then
    out="$p"
  else
    out="$out ${DIM}|${RESET} $p"
  fi
done

printf "%b" "$out"
