#!/bin/sh
# Integration test for scripts/z-window.sh (P1.M2.T1.S1).
#
# Strategy (item contract #5): drive an ISOLATED tmux server (tmux -L zxstest) so
# the user's live tmux is untouched; a fake `tmux` wrapper on PATH forwards every
# bare `tmux` call (from z-window.sh AND from resolve.sh's get_tmux_option) to
# that server; a fake `zoxide` makes resolve() deterministic; @zoxide-sessions-
# backend=zoxide is SET on the isolated server. The REAL z-window.sh + REAL
# resolve.sh run unmodified against this sandbox.
#
# Assertions: each invocation creates EXACTLY ONE new window (count delta == 1),
# with the correct NAME (#{window_name}) and start dir (#{pane_start_path}).
# These two formats are SYNCHRONOUS and reliable; #{pane_current_path} lags in a
# headless sandbox and is NOT used as a gate (research/verification_notes.md §2).
#
# Cases (item contract TDD #5): empty query -> cur; match -> resolved; no-match
# -> cur; spaced query recombines (query="$*") -> still 1 window.

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_window"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZWIN="$REPO_ROOT/scripts/z-window.sh"

# --- fixture: a REAL resolved dir (must exist or the active pane falls back to
#     $HOME and corrupts the next `cur` — verification_notes.md §3) -----------
FIX="$(mktemp -d)"
mkdir -p "$FIX/proj"                 # fake zoxide resolves `proj` -> here (REAL)
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

# fake `zoxide`: `proj` -> the real fixture dir; anything else -> empty (no match).
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift        # no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)
case "$1" in
    proj) printf '%s\n' "$FIX/proj"; exit 0 ;;   # MATCH (real dir)
    *)    printf ''; exit 0 ;;                    # no-match: empty, exit 0
esac
ZOX
chmod +x "$TBIN/zoxide"

export PATH="$TBIN:$PATH"
export FIX

# --- boot the isolated server; server cwd = $FIX (deterministic) ------------
cd "$FIX" || { echo "FATAL: cannot cd $FIX"; exit 2; }
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
sleep 0.2
"$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$FIX" || { echo "FATAL: new-session"; exit 2; }
sleep 0.3                                   # let the initial pane's cwd settle
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# run_case <args...>: invoke z-window.sh, echo "<delta>|<newest-window-index>"
run_case() {
    before=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    "$ZWIN" "$@" || true
    sleep 0.3                               # let the new pane's cwd settle
    after=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
    echo "$((after - before))|$idx"
}

# newest window's NAME and START_PATH, read via the REAL tmux (synchronous formats).
new_name()  { "$REAL_TMUX" -L "$SOCK" display-message -t "zs:$1" -p '#{window_name}'; }
new_start() { "$REAL_TMUX" -L "$SOCK" display-message -t "zs:$1" -p '#{pane_start_path}'; }

echo "=== CASE 1: empty query -> window in cur path, named basename(cur) ==="
CUR=$(tmux display-message -p '#{pane_current_path}')   # what z-window.sh will read as `cur`
res=$(run_case); delta=${res%%|*}; idx=${res##*|}
check "exactly 1 new window"        "1"                  "$delta"
check "NAME = basename(cur)"        "$(basename "$CUR")" "$(new_name "$idx")"
check "START_PATH = cur"            "$CUR"               "$(new_start "$idx")"

echo "=== CASE 2: match 'proj' -> window in resolved dir, named basename(resolved) ==="
res=$(run_case proj); delta=${res%%|*}; idx=${res##*|}
check "exactly 1 new window"        "1"         "$delta"
check "NAME = basename(resolved)"   "proj"      "$(new_name "$idx")"
check "START_PATH = resolved"       "$FIX/proj" "$(new_start "$idx")"

echo "=== CASE 3: no-match 'zzz' -> window in cur path (cur now = resolved/proj) ==="
CUR=$(tmux display-message -p '#{pane_current_path}')   # re-capture: active window shifted
res=$(run_case zzz); delta=${res%%|*}; idx=${res##*|}
check "exactly 1 new window"        "1"                  "$delta"
check "NAME = basename(cur)"        "$(basename "$CUR")" "$(new_name "$idx")"
check "START_PATH = cur"            "$CUR"               "$(new_start "$idx")"

echo "=== CASE 4: spaced query recombines (query=\"\$*\") -> exactly 1 window ==="
CUR=$(tmux display-message -p '#{pane_current_path}')
res=$(run_case foo bar); delta=${res%%|*}; idx=${res##*|}
check "spaced query -> exactly 1 window" "1"                  "$delta"
check "spaced no-match NAME = basename(cur)" "$(basename "$CUR")" "$(new_name "$idx")"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
