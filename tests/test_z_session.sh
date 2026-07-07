#!/bin/sh
# Integration test for scripts/z-session.sh (P1.M3.T1.S1) — the session-created handler.
#
# Strategy (item contract #5): drive an ISOLATED tmux server (tmux -L zxstest_session) so
# the user's live tmux is untouched; a fake `tmux` wrapper on PATH forwards every bare
# `tmux` call (from z-session.sh AND from resolve.sh's get_tmux_option/resolve) to that
# server; a fake `zoxide` makes resolve() deterministic; @zoxide-sessions-backend=zoxide
# and @zoxide-sessions-home-dir=<fixture> are SET on the isolated server. The REAL
# z-session.sh + REAL resolve.sh run unmodified against this sandbox.
#
# z-session.sh is invoked DIRECTLY as `$ZSESS "<name>"` — exactly what the session-created
# hook's `run-shell -b '<abs>/z-session.sh "#{session_name}"'` dispatch does (P1.M3.T2.S1).
# This subtask owns the handler + its direct-invocation test; it does NOT wire the hook.
#
# Assertion (item contract #5): pane cwd POST-RESPAWN via
# `display-message -p '#{pane_current_path}'`. respawn-pane -c <dir> -k RESTARTS the pane's
# shell at <dir> and tmux tracks it as current_path — reliably, after a >=0.4s settle sleep
# (research/verification_notes.md §2). NOTE: this is the OPPOSITE of test_z_window.sh, which
# used the synchronous #{pane_start_path} for a freshly new-window'd pane (current_path lags
# there). For respawn, current_path is the correct, reliable format.
#
# Cases (PRD §7 TDD scope 1-4,6,7,9): relocate-fires / skip-list / no-match / not-$HOME /
# master-off / window-name / spaced-name. (§7 cases 5 sessionx + 10 resurrect are external-
# plugin coexistence/restore-safety checks — manual-verify in P1.M4.T2.S1, not unit-testable.)

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_session"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZSESS="$REPO_ROOT/scripts/z-session.sh"

# fixture: a REAL home dir (the configured landing dir) + REAL resolved dirs.
FIX="$(mktemp -d)"
mkdir -p "$FIX/home" "$FIX/else" "$FIX/proj" "$FIX/twowords"
TBIN="$FIX/.tbin"; mkdir -p "$TBIN"

cleanup() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    rm -rf "$FIX"
}
trap cleanup EXIT INT TERM

# fake `tmux` wrapper: forward ALL bare `tmux` calls to the isolated server.
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
TMUX
chmod +x "$TBIN/tmux"

# fake `zoxide`: known names -> real fixture dirs; anything else -> empty (no match, exit 0).
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift        # no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)
case "$1" in
    proj)        printf '%s\n' "$FIX/proj"; exit 0 ;;     # MATCH (real dir)
    "two words") printf '%s\n' "$FIX/twowords"; exit 0 ;; # MATCH (spaced name; real dir)
    *)           printf ''; exit 0 ;;                     # no-match: empty, exit 0
esac
ZOX
chmod +x "$TBIN/zoxide"

export PATH="$TBIN:$PATH"
export FIX

# boot a fresh isolated server + set the options the handler reads.
# CRITICAL: boot with `tmux -f /dev/null` so the USER's tmux.conf is NOT sourced (a
# stray session-created hook from an installed plugin would pollute the assertions —
# see P1.M4.T2.S1 findings). The anchor session `zs` MUST stay alive for the whole
# case: killing the last session on a server destroys the server (tmux exits when no
# sessions remain), which would silently drop every `set -g` option we just applied.
# Options are set AFTER the anchor exists and are NOT cleared until the next boot.
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX" \
        || { echo "FATAL: boot new-session"; exit 2; }
    sleep 0.2
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-home-dir' "$FIX/home" 2>/dev/null
    # reset the toggleable options each boot (prior cases may have set them)
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -gu '@zoxide-sessions-window-name' 2>/dev/null
}

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# pane cwd (#{pane_current_path}) and window name of a session's first pane.
cwd_of()    { "$REAL_TMUX" -L "$SOCK" display-message -t "$1" -p '#{pane_current_path}'; }
winname_of() { "$REAL_TMUX" -L "$SOCK" display-message -t "$1" -p '#{window_name}'; }

echo "=== CASE 1: resolvable name landed at home -> relocate fires (§7 test 1) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/home"; sleep 0.3
check "C1a pre-relocate cwd = home"   "$FIX/home" "$(cwd_of proj)"
"$ZSESS" proj; sleep 0.5                                   # let respawn settle (§2)
check "C1b post-respawn cwd = resolved" "$FIX/proj" "$(cwd_of proj)"

echo "=== CASE 2: skip-list name (main) -> NO relocate (§7 test 2) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s main -c "$FIX/home"; sleep 0.3
"$ZSESS" main; sleep 0.3
check "C2 skip-list stays at home" "$FIX/home" "$(cwd_of main)"

echo "=== CASE 3: no-match name (zzznope) -> NO relocate (§7 test 3) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s zzznope -c "$FIX/home"; sleep 0.3
"$ZSESS" zzznope; sleep 0.3
check "C3 no-match stays at home" "$FIX/home" "$(cwd_of zzznope)"

echo "=== CASE 4: start dir != home -> NO relocate (§7 test 4) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/else"; sleep 0.3
"$ZSESS" proj; sleep 0.3
check "C4 not-home stays put" "$FIX/else" "$(cwd_of proj)"

echo "=== CASE 6: @zoxide-sessions-auto-session off -> NO relocate (§7 test 6) ==="
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' off 2>/dev/null
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/home"; sleep 0.3
"$ZSESS" proj; sleep 0.3
check "C6 master-off stays at home" "$FIX/home" "$(cwd_of proj)"

echo "=== CASE 7: window-name=session -> first window renamed to name (§7 test 7) ==="
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-window-name' session 2>/dev/null
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/home"; sleep 0.3
"$ZSESS" proj; sleep 0.5
check "C7a post-respawn cwd = resolved" "$FIX/proj" "$(cwd_of proj)"
check "C7b first window renamed to name" "proj"        "$(winname_of proj)"

echo "=== CASE 9: spaced name \"two words\" resolvable -> relocates; \$1 intact (§7 test 9) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s "two words" -c "$FIX/home"; sleep 0.3
"$ZSESS" "two words"; sleep 0.5
# If $1 had been split, resolve would get "two" (no match -> empty) and the pane would NOT
# relocate. A relocated pane PROVES name="$1" preserved "two words" through resolve->respawn.
check "C9 spaced-name relocates to resolved" "$FIX/twowords" "$(cwd_of "two words")"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
