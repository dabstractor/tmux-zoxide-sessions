#!/bin/sh
# z-session.sh — session-created handler for tmux-zoxide-sessions.
#
# Relocates the first pane of a newly-created session from $HOME to the
# zoxide-resolved directory matching the session name. Acts ONLY when the
# session landed in $HOME with a resolvable, non-whitelisted name — so
# sessions placed by resurrect/continuum, sessionx/sesh, or created from a
# project directory are left untouched. See PRD.md §3.2 for the rationale.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/resolve.sh"

# Single newline, POSIX-portable (avoids the bash-only $'\n' form).
NL='
'

# Master toggle.
[ "$(get_tmux_option "@zoxide-sessions-auto-session" "on")" = "off" ] && exit 0

name="$1"
[ -n "$name" ] || exit 0

# Whitelist of names that legitimately live in $HOME.
skip_names="$(get_tmux_option "@zoxide-sessions-skip-names" "home main")"
for s in $skip_names; do
    [ "$s" = "$name" ] && exit 0
done

# Locate the session's first pane (the only pane at creation time).
pane=$(tmux display-message -t "$name" -p '#{pane_id}' 2>/dev/null) || exit 0
[ -n "$pane" ] || exit 0

path=$(tmux display-message -t "$pane" -p '#{pane_current_path}' 2>/dev/null) || exit 0
[ -n "$path" ] || exit 0

# The "home" directory where bare/unresolved sessions land.
home_dir="$(get_tmux_option "@zoxide-sessions-home-dir" "$HOME")"
[ -n "$home_dir" ] || home_dir="$HOME"

# Normalize both for comparison (resolve symlinks, collapse trailing slashes).
_norm() {
    _p=$(readlink -f "$1" 2>/dev/null || printf '%s' "$1")
    printf '%s/' "$_p" | sed 's#//*#/#g'
}
[ "$(_norm "$path")" = "$(_norm "$home_dir")" ] || exit 0

# Resolve the name via the shared backend. Empty = no match -> nothing to do.
resolved=$(resolve "$name") || exit 0
[ -n "$resolved" ] || exit 0

# Defence in depth: accept `resolved` ONLY if it is a single existing
# directory; otherwise no-op (pane stays where it is).
case "$resolved" in
    *"$NL"*) exit 0 ;;                 # multi-line dump -> refuse to relocate
    *)       [ -d "$resolved" ] || exit 0 ;;
esac

# Relocate: restart the pane's shell in the resolved directory.
tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0

# Optional: rename the first window to the session name.
case "$(get_tmux_option "@zoxide-sessions-window-name" "off")" in
    session)
        win=$(tmux display-message -t "$pane" -p '#{window_id}' 2>/dev/null)
        [ -n "$win" ] && tmux rename-window -t "$win" "$name" 2>/dev/null
        ;;
esac

exit 0
