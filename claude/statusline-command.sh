#!/bin/bash
# Claude Code statusline: model | effort | context% | git branch | dir | worktree
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
worktree=$(echo "$input" | jq -r '.worktree.name // empty')

dir_display=$(basename "$cwd")

branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
fi

RESET='\033[0m'
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
MAGENTA='\033[35m'
BLUE='\033[34m'
GRAY='\033[2m'

sep=" ${GRAY}|${RESET} "

out="${CYAN}${model}${RESET}"

if [ -n "$effort" ]; then
  out="${out}${sep}${YELLOW}${effort}${RESET}"
fi

if [ -n "$used_pct" ]; then
  ctx=$(printf '%.0f' "$used_pct")
  out="${out}${sep}${GREEN}${ctx}% ctx${RESET}"
fi

if [ -n "$branch" ]; then
  out="${out}${sep}${MAGENTA}${branch}${RESET}"
fi

out="${out}${sep}${BLUE}${dir_display}${RESET}"

if [ -n "$worktree" ]; then
  out="${out}${sep}${GRAY}wt:${worktree}${RESET}"
fi

printf "%b\n" "$out"
