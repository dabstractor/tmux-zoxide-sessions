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
# The query may be supplied two ways:
#   - as command-line arguments (direct / scripted / test invocation), or
#   - via the @zoxide-sessions-last-query tmux user option, which the key
#     binding sets. The user-option path avoids lossy shell quoting of the
#     command-prompt result (queries containing ', ", $, etc. survive intact).
#
# With no query, or when no match is found, open the window in the current
# pane's directory and name it after that. This matches a plain
# `new-window -c "#{pane_current_path}"`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/resolve.sh"

# Single newline, POSIX-portable (avoids the bash-only $'\n' form).
NL='
'

query="$*"
# Fall back to the user option the binding sets when invoked without args.
[ -n "$query" ] || query=$(tmux show-option -gqv "@zoxide-sessions-last-query" 2>/dev/null)

# Pull the current pane's directory and session from the live tmux server.
cur=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
[ -z "$cur" ] && cur="$HOME"
session=$(tmux display-message -p '#{session_name}' 2>/dev/null)

dir="$cur"

if [ -n "$query" ]; then
    resolved=$(resolve "$query")
    # Defence in depth: accept `resolved` ONLY if it is a single line that is
    # an existing directory. A multi-line value (e.g. a zoxide list-mode dump)
    # or any non-directory falls back to the current pane path.
    case "$resolved" in
        *"$NL"*) : ;;                  # multi-line -> reject, keep dir=$cur
        *)        [ -d "$resolved" ] && dir="$resolved" ;;
    esac
fi

base=$(basename "$dir")
tmux new-window -t "$session:" -c "$dir" -n "$base"
