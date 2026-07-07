#!/bin/sh
# lib/resolve.sh — shared helpers for tmux-zoxide-sessions.
# Sourced by the run file, scripts/z-window.sh, and scripts/z-session.sh.

# get_tmux_option <name> <default> -> option value, or default if unset/empty.
get_tmux_option() {
    _v=$(tmux show-option -gqv "$1" 2>/dev/null)
    [ -n "$_v" ] && echo "$_v" || echo "$2"
}

# _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
}
