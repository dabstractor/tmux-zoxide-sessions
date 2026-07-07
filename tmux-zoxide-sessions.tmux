#!/usr/bin/env bash
# tmux-zoxide-sessions: run file (loaded by TPM or a plain run-shell line).
#
# Wires two features:
#   1. A key binding that opens a new window in a zoxide-resolved directory.
#   2. (default on) A session-created hook that relocates a new session from
#      $HOME to the zoxide-resolved directory matching its name. See PRD.md §3.2.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/scripts/lib/resolve.sh"

# --- 1. Window-jump binding ---------------------------------------------------
key=$(get_tmux_option "@zoxide-sessions-key" "g")
prompt=$(get_tmux_option "@zoxide-sessions-prompt" "z to:")

# The command-prompt result is delivered to z-window.sh via a transient tmux
# user option (@zoxide-sessions-last-query) rather than embedded raw in the
# run-shell argument. `%%%` (not `%%`) makes tmux escape quotation marks in
# the typed query, so values containing ', ", $, spaces, ;, or & survive the
# tmux command parser intact and are read back verbatim by the script. The
# option is unset immediately afterward so it never leaks across invocations.
tmux bind-key "$key" \
    command-prompt -p "$prompt" \
    "set-option -g @zoxide-sessions-last-query \"%%%\"; run-shell '$CURRENT_DIR/scripts/z-window.sh'; set-option -gu @zoxide-sessions-last-query"

# --- 2. Session auto-relocate hook -------------------------------------------
# Relocates a newly-created session's first pane from $HOME to the
# zoxide-resolved directory matching its name.
auto_session=$(get_tmux_option "@zoxide-sessions-auto-session" "on")
if [ "$auto_session" != "off" ]; then
    SESSION_SCRIPT="$CURRENT_DIR/scripts/z-session.sh"
    # Quoting mirrors tmux-session-history's proven hooks: the stored command
    # is `run-shell -b "/abs/path/z-session.sh \"#{session_name}\""`, passing
    # the (possibly spaced) session name through as a single $1.
    tmux set-hook -g session-created \
        "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'"
fi
