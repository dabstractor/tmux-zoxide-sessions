#!/bin/sh
# Integration test for tmux-zoxide-sessions.tmux (P1.M2.T2.S1) — PART 1 only.
#
# Strategy (item contract #5): drive an ISOLATED tmux server (tmux -L zxstest_run) so the
# user's live tmux is untouched. A fake `tmux` wrapper on PATH forwards every bare `tmux`
# call (the run file's bind-key, resolve.sh's get_tmux_option, z-window.sh's
# display-message/new-window) to that server. A fake `zoxide` makes resolve() deterministic.
# PATH with fakes is set BEFORE the server boots so `run-shell` (the binding's production
# dispatch path) inherits it (research/verification_notes.md §4).
#
# The run file is EXECUTED directly (`"$RUN"`), exactly as TPM does ($tmux_file >/dev/null 2>&1).
#
# Assertions: C0 PART-1-only (no session-hook code); C1–C3 default binding registered on 'g'
# with prompt 'z to:' + the correct ABSOLUTE path to scripts/z-window.sh + %% (via
# `list-keys -1 -T prefix g` — the -1 is mandatory, §1); C4–C5 custom
# @zoxide-sessions-key/@zoxide-sessions-prompt override; C6–C8 triggering the prompt path
# (run-shell '<path>/z-window.sh proj', the production dispatch after %% substitution) opens
# exactly one window in the zoxide-resolved dir (PRD §7 test #8).

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_run"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$REPO_ROOT/tmux-zoxide-sessions.tmux"
ZWIN="$REPO_ROOT/scripts/z-window.sh"

# fixture: a REAL resolved dir (must exist or the active pane falls back to $HOME —
# P1.M2.T1.S1 finding §3).
FIX="$(mktemp -d)"
mkdir -p "$FIX/proj"                 # fake zoxide resolves `proj` -> here (REAL dir)
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
shift; [ "${1:-}" = "--" ] && shift        # honor the end-of-options guard
case "$1" in
    proj) printf '%s\n' "$FIX/proj"; exit 0 ;;   # MATCH (real dir)
    *)    printf ''; exit 0 ;;                    # no-match: empty, exit 0
esac
ZOX
chmod +x "$TBIN/zoxide"

# CRITICAL: set PATH with fakes BEFORE booting the server, so `run-shell` inherits it.
export PATH="$TBIN:$PATH"
export FIX

# boot a fresh isolated server; set backend=zoxide so resolve() takes the zoxide branch.
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    "$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$FIX" || { echo "FATAL: new-session"; exit 2; }
    sleep 0.2
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
}

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}
contains() {  # contains <desc> <haystack> <needle>  (fixed-string substring match)
    if printf '%s' "$2" | grep -Fq -- "$3"; then echo "PASS  $1"; pass=$((pass+1));
    else echo "FAIL  $1 (expected haystack to contain [$3]; got=[$2])"; fail=$((fail+1)); fi
}

echo "=== C0: PART 2 present — session-created hook wired (P1.M3.T2.S1) ==="
if grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' "$RUN"; then
    echo "PASS  C0: PART 2 present (session-hook code)"; pass=$((pass+1))
else
    echo "FAIL  C0: run file missing PART 2 session-hook code (append is P1.M3.T2.S1)"; fail=$((fail+1))
fi

echo "=== CASE 1: default options -> binding on 'g', prompt 'z to:', abs path + %% ==="
boot
"$RUN" >/dev/null 2>&1
b=$("$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix g 2>&1)
contains "C1: bind-key on 'g' registered"        "$b" "bind-key -T prefix g"
contains "C2: default prompt 'z to:'"            "$b" 'command-prompt -p "z to:"'
contains "C3: abs path to z-window.sh + %% kept" "$b" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"

echo "=== CASE 2: custom @zoxide-sessions-key / @zoxide-sessions-prompt ==="
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-key' Z
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-prompt' "jump to"
"$RUN" >/dev/null 2>&1
bz=$("$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix Z 2>&1)
contains "C4: binding on custom key 'Z'" "$bz" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
contains "C5: custom prompt 'jump to'"   "$bz" 'command-prompt -p "jump to"'

echo "=== CASE 3: trigger the prompt path (run-shell ... z-window.sh <query>) -> window opens ==="
if [ -x "$ZWIN" ]; then
    boot
    before=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    # Simulate: user types `proj` at the prompt -> tmux substitutes %% and runs
    # `run-shell '<abs>/scripts/z-window.sh proj'` (the binding's production dispatch).
    "$REAL_TMUX" -L "$SOCK" run-shell "$REPO_ROOT/scripts/z-window.sh proj"
    sleep 0.4                               # let the new pane's cwd settle
    after=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
    check "C6: exactly 1 new window"                 "1"         "$((after - before))"
    check "C7: window named basename(resolved)=proj" "proj"      \
        "$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{window_name}')"
    check "C8: window start_path = resolved dir"     "$FIX/proj" \
        "$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{pane_start_path}')"
else
    echo "FAIL  C6/C7/C8: z-window.sh missing ($ZWIN) — run P1.M2.T1.S1 first"; fail=$((fail+3))
fi

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
