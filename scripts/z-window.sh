#!/bin/sh
# Open a new tmux window in the current session, in a zoxide-frecency-matched
# directory.
#
# Usage: z-window.sh [query ...]
#
# With a query, resolve it to its best frecency match and open the window
# there, named after the directory basename. The query is a zoxide query, not
# a literal window name.
#
# With no query, or when no match is found, open the window in the current
# pane's directory and name it after that. This matches a plain
# `new-window -c "#{pane_current_path}"`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/resolve.sh"

query="$*"

# Pull the current pane's directory and session from the live tmux server.
cur=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
[ -z "$cur" ] && cur="$HOME"
session=$(tmux display-message -p '#{session_name}' 2>/dev/null)

dir="$cur"

if [ -n "$query" ]; then
    resolved=$(resolve "$query")
    [ -n "$resolved" ] && dir="$resolved"
fi

base=$(basename "$dir")
tmux new-window -t "$session:" -c "$dir" -n "$base"
