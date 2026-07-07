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

tmux bind-key "$key" \
    command-prompt -p "$prompt" \
    "run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"

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
