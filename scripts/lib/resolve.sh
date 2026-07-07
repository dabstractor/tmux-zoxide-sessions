#!/bin/sh
# lib/resolve.sh — shared helpers for tmux-zoxide-sessions.
# Sourced by the run file, scripts/z-window.sh, and scripts/z-session.sh.

# get_tmux_option <name> <default> -> option value, or default if unset/empty.
get_tmux_option() {
    _v=$(tmux show-option -gqv "$1" 2>/dev/null)
    [ -n "$_v" ] && echo "$_v" || echo "$2"
}

# _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
# A query that begins with `-` (e.g. `-l` / `--list`, which real zoxide would
# interpret as list mode and use to dump the entire frecency DB) is rejected
# up front and returns empty, honoring the documented contract that the
# resolver returns empty on a no-match / non-directory query. We deliberately
# do NOT insert a `--` end-of-options guard before the query: this plugin
# supports rupa/z-backed `zoxide` shims (see PRD §9 / README "Backends") that
# do not parse `--` and would treat it as part of the query, silently
# breaking resolution for every legitimate query. Rejecting leading-dash
# queries instead fixes the dump symptom for both real zoxide and the shim,
# without breaking either. The `z` backend never calls zoxide, so this guard
# has no effect on it.
_resolve_zoxide() {
    [ -n "$1" ] || return 0
    case "$1" in -*) return 0 ;; esac
    command -v zoxide >/dev/null 2>&1 && zoxide query "$1" 2>/dev/null
}

# _resolve_z <query> -> dir from rupa/z (_z), or empty. Always exits 0.
_resolve_z() {
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    [ -n "$z_sh" ] && [ -r "$z_sh" ] || return 0
    shell="sh"; command -v zsh >/dev/null 2>&1 && shell="zsh"
    # shellcheck disable=SC2016 # inner $1/$2/$o/$n expand inside the subshell, not the parent
    "$shell" -c '. "$1" 2>/dev/null || exit 0; o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ] && printf "%s\n" "$n"; exit 0' \
        _ "$z_sh" "$1" 2>/dev/null
}

# resolve <query> -> best frecency-match directory (empty if no match).
# Always exits 0 — callers must check the output, not the exit status.
# Backend selected by @zoxide-sessions-backend (default "auto"):
#   zoxide -> zoxide only
#   z      -> rupa/z only
#   auto   -> zoxide if present, then rupa/z as fallback
resolve() {
    backend=$(get_tmux_option "@zoxide-sessions-backend" "auto")
    case "$backend" in
        zoxide) _resolve_zoxide "$1" ;;
        z)      _resolve_z "$1" ;;
        auto)
            _r=$(_resolve_zoxide "$1")
            [ -z "$_r" ] && _r=$(_resolve_z "$1")
            printf '%s\n' "$_r"
            ;;
    esac
    return 0   # honor the documented contract regardless of backend exit status
}
