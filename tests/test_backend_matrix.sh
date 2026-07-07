#!/bin/sh
# Backend matrix integration test (P1.M4.T2.S1) — PRD §9 acceptance bullet 5.
#
# Proves BOTH features (window-jump + session-relocate) resolve through
# lib/resolve.sh against ALL THREE supported backends, on an ISOLATED tmux
# server (tmux -f /dev/null -L zxstest_backend) so the user's live tmux and
# any installed plugin's session-created hook cannot contaminate the result:
#
#   A. on-PATH 'zoxide'    — whatever 'zoxide' resolves to via the resolver's
#                            EXACT invocation ('zoxide query -- <q>'). EXPECTED
#                            is captured at run time, so this proves correct
#                            integration with the real/shim binary on PATH,
#                            never a hardcoded path (PRP gotcha). If the
#                            on-PATH zoxide returns empty for the token (e.g.
#                            a shim that mishandles '--'), the features must
#                            still complete without relocating to a bogus dir.
#   B. 'zoxide' shim       — a fake 'zoxide' returning a canned fixture dir.
#                            Deterministic; asserts a real relocate/jump.
#   C. rupa/z ('z' backend) — seeded _Z_DATA, @zoxide-sessions-z-sh set,
#                             backend=z. Asserts the _z branch resolves.
#
# Harness conventions copied from tests/test_z_session.sh + tests/test_run_file.sh
# (the proven M2/M3 harness): REAL_TMUX/SOCK/cleanboot/fake-tmux wrapper/
# PATH-set-BEFORE-boot/check/cleanup trap, the respawn settle sleep (>=0.4s for
# session), and the session-target cwd read (no base-index dependency).
#
# Token: 'zxmatrix'. The fixture dir basename IS the token so rupa/z's _z
# (substring-of-path matcher) finds it, and zoxide's frecency index is seeded
# with the same dir. The fake zoxide (subtest B) returns it for the same token.

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_backend"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZWIN="$REPO_ROOT/scripts/z-window.sh"
ZSESS="$REPO_ROOT/scripts/z-session.sh"
Z_SH="${Z_SH:-/home/dustin/.config/znap/rupa/z/z.sh}"   # item contract #5 path
ZSH_BIN="${ZSH_BIN:-/usr/bin/zsh}"
TOKEN="zxmatrix"

# fixture: REAL temp tree. home = configured landing dir; <TOKEN> = resolved dir.
FIX="$(mktemp -d)"
mkdir -p "$FIX/home" "$FIX/$TOKEN"
TBIN="$FIX/.tbin"; mkdir -p "$TBIN"

cleanup() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    rm -rf "$FIX"
}
trap cleanup EXIT INT TERM

# fake 'tmux' wrapper: forward ALL bare 'tmux' calls to the isolated server, so
# z-session.sh / z-window.sh / resolve.sh read options + drive panes on it.
# (No fake 'zoxide' here — subtest A needs the real one; subtest B installs its
# own into $TBIN, and removes it again so it never leaks into A or C.)
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
TMUX
chmod +x "$TBIN/tmux"

export PATH="$TBIN:$PATH"     # set BEFORE boot so run-shell inherits it
export FIX

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# boot a fresh isolated server (NO user tmux.conf) + apply the shared options.
# The anchor session 'zs' stays alive for the whole subtest so the server is
# never destroyed mid-case (killing the last session exits tmux + drops opts).
# Mirrors tests/test_session_hook.sh cleanboot + tests/test_z_session.sh boot.
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX" \
        || { echo "FATAL: boot new-session"; exit 2; }
    sleep 0.2
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-home-dir' "$FIX/home"
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on
    "$REAL_TMUX" -L "$SOCK" set -gu '@zoxide-sessions-window-name' 2>/dev/null || true
}

# pane cwd of a session's active pane (session target -> no base-index dependency).
cwd_of() { "$REAL_TMUX" -L "$SOCK" display-message -t "$1" -p '#{pane_current_path}'; }

# --- WINDOW feature: run z-window.sh <q> (the binding's production dispatch) and
# assert the newest window's start_path == EXPECTED. new-window is synchronous,
# so #{pane_start_path} is reliable (respawn-pane would need current_path+settle).
window_jump() {  # window_jump <expected_dir_or_empty> <query>
    exp="$1"; q="$2"
    before=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    "$REAL_TMUX" -L "$SOCK" run-shell "$ZWIN $q"
    sleep 0.4
    after=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
    sp=$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{pane_start_path}')
    check "WINDOW[$q] opens 1 new window" "1" "$((after - before))"
    if [ -n "$exp" ]; then
        check "WINDOW[$q] start_path = resolved" "$exp" "$sp"
    else
        # backend returned empty -> window opens at current pane dir (the fixture),
        # NOT a bogus path. Assert it did not relocate to a nonexistent dir.
        if [ -d "$sp" ]; then
            check "WINDOW[$q] no-match stays at a real dir" "ok" "ok"
        else
            check "WINDOW[$q] no-match stays at a real dir" "ok" "BOGUS:$sp"
        fi
    fi
}

# --- SESSION feature: create a session at $HOME, run z-session.sh <q> (the hook's
# production dispatch), assert the pane relocates to EXPECTED. respawn-pane needs
# a >=0.4s settle before #{pane_current_path} reflects the new dir (PRP gotcha).
session_relocate() {  # session_relocate <expected_dir_or_empty> <session_name>
    exp="$1"; name="$2"
    "$REAL_TMUX" -L "$SOCK" new-session -d -s "$name" -c "$FIX/home"; sleep 0.3
    check "SESSION[$name] pre-relocate cwd = home" "$FIX/home" "$(cwd_of "$name")"
    "$ZSESS" "$name"; sleep 0.5                                   # let respawn settle
    if [ -n "$exp" ]; then
        check "SESSION[$name] post-respawn cwd = resolved" "$exp" "$(cwd_of "$name")"
    else
        # backend returned empty -> handler must no-op (pane stays at home).
        check "SESSION[$name] no-match stays at home" "$FIX/home" "$(cwd_of "$name")"
    fi
}

echo "############################################################"
echo "# SUBTEST A: on-PATH zoxide (resolver's real 'zoxide query -- <q>')"
echo "############################################################"
# Capture what the on-PATH 'zoxide' resolves the token to via the resolver's
# EXACT invocation, so the assertion tracks the real backend's behavior (never a
# hardcoded path). Seed the fixture dir into the frecency index first so there is
# a deterministic match on real zoxide; a shim that ignores 'add' is harmless.
ZOXIDE_ON_PATH="$(command -v zoxide 2>/dev/null || true)"
ZOXIDE_SEEDED=0
if [ -n "$ZOXIDE_ON_PATH" ]; then
    zoxide add "$FIX/$TOKEN" 2>/dev/null && ZOXIDE_SEEDED=1
fi
EXPECTED_A=$(zoxide query -- "$TOKEN" 2>/dev/null)
echo "on-PATH zoxide: ${ZOXIDE_ON_PATH:-(none)}"
echo "resolver captured EXPECTED_A=[$EXPECTED_A] for token '$TOKEN'"
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide
window_jump "$EXPECTED_A" "$TOKEN"
session_relocate "$EXPECTED_A" "$TOKEN"
# cleanup the seeded token from the user's frecency index (real zoxide only).
if [ "$ZOXIDE_SEEDED" = "1" ]; then zoxide remove "$FIX/$TOKEN" 2>/dev/null || true; fi

echo ""
echo "############################################################"
echo "# SUBTEST B: zoxide shim (fake zoxide -> canned fixture dir)"
echo "############################################################"
# Install the fake zoxide into $TBIN (already front-of-PATH): '<TOKEN>' -> the
# real fixture dir; anything else -> empty. Honors the resolver's '--' guard.
cat > "$TBIN/zoxide" <<ZOX
#!/bin/sh
[ "\$1" = "query" ] || exit 0
shift; [ "\${1:-}" = "--" ] && shift
case "\$1" in
    $TOKEN) printf '%s\n' "$FIX/$TOKEN"; exit 0 ;;
    *)      printf ''; exit 0 ;;
esac
ZOX
chmod +x "$TBIN/zoxide"
EXPECTED_B="$FIX/$TOKEN"
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide
window_jump "$EXPECTED_B" "$TOKEN"
session_relocate "$EXPECTED_B" "$TOKEN"
# remove the fake so it cannot leak into a re-run of subtest A or a later test.
rm -f "$TBIN/zoxide"

echo ""
echo "############################################################"
echo "# SUBTEST C: rupa/z (z backend, seeded _Z_DATA via set-environment)"
echo "############################################################"
if [ -r "$Z_SH" ] && [ -x "$ZSH_BIN" ]; then
    # Seed rupa/z's datafile with the fixture dir. rupa/z matches the query as a
    # substring of the stored path, so a dir whose basename IS the token resolves.
    ZDATA="$FIX/.zdata"
    _Z_DATA="$ZDATA" "$ZSH_BIN" -c ". '$Z_SH'; _z --add '$FIX/$TOKEN'" 2>/dev/null
    # Export _Z_DATA into the tmux server env so run-shell'd scripts (and the
    # resolver's subshell) inherit it. rupa/z defaults to ~/.z otherwise.
    boot
    "$REAL_TMUX" -L "$SOCK" set-environment -g _Z_DATA "$ZDATA"
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' z
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-z-sh' "$Z_SH"
    # Capture EXPECTED via the resolver's EXACT _resolve_z subshell form. _Z_DATA
    # is exported so the capture subshell matches what the resolver will compute.
    export _Z_DATA="$ZDATA"
    # shellcheck disable=SC2016 # inner $1/$2/$o/$n expand inside the subshell, not the parent
    EXPECTED_C=$("$ZSH_BIN" -c '. "$1" 2>/dev/null || exit 0; o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ] && printf "%s\n" "$n"; exit 0' _ "$Z_SH" "$TOKEN" 2>/dev/null)
    echo "rupa/z resolver captured EXPECTED_C=[$EXPECTED_C] for token '$TOKEN'"
    window_jump "$EXPECTED_C" "$TOKEN"
    session_relocate "$EXPECTED_C" "$TOKEN"
    unset _Z_DATA
else
    echo "SKIP  rupa/z subtest: z.sh ($Z_SH) or zsh ($ZSH_BIN) unavailable"
    fail=$((fail+1))
fi

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
