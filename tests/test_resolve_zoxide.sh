#!/bin/sh
# Unit tests for _resolve_zoxide (P1.M1.T2.S2).
# Strategy: inject a fake `zoxide` earlier on PATH (match / no-match) or make it
# unreachable (missing-binary), source resolve.sh, and assert each branch.
# No live zoxide or tmux required.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- fake zoxide (match / no-match) ------------------------------------------
TBIN="$REPO_ROOT/tests/.zoxide-bin"
mkdir -p "$TBIN"
cat > "$TBIN/zoxide" <<'ZOXIDE'
#!/bin/sh
# Fake zoxide: models query [--] <kw> AND list-mode for -l/--list, like real zoxide.
# Strip -- (real zoxide honors end-of-options); model list-mode for -l/--list.
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then
    shift      # -- consumed; everything after is a POSITIONAL query (NEVER list-mode after --)
else
    case "$1" in
        -l|--list) printf '%s\n' "/home/user/projects/proj" "/home/user/projects/other1" "/home/user/projects/other2"; exit 0 ;;
    esac
fi
case "$1" in
    proj) printf '%s\n' "/home/user/projects/proj" ;;   # MATCH
    *)    printf '' ;;                                   # no-match -> empty stdout, exit 0
esac
exit 0
ZOXIDE
chmod +x "$TBIN/zoxide"

# Empty dir to prove the missing-binary path (zoxide unreachable).
EMPTY_BIN="$REPO_ROOT/tests/.empty-bin"
mkdir -p "$EMPTY_BIN"

cleanup() { rm -rf "$TBIN" "$EMPTY_BIN"; }
trap cleanup EXIT INT TERM

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# MATCH / NO-MATCH: fake zoxide prepended to PATH INSIDE the subshell (shadows any
# real zoxide). Resolve `sh` via the outer PATH first.
withfake() {
    sh -c '. "$0"; PATH="$1:$PATH"; _resolve_zoxide "$2"' \
        "$RESOLVE" "$TBIN" "$1"
}

# MISSING-BINARY: narrow PATH to the empty dir INSIDE the subshell (so `sh` is resolved
# by the outer PATH, and only `command -v zoxide` fails). This genuinely exercises the
# function — proving "absent binary -> empty, never errors".
without() {
    sh -c '. "$0"; PATH="$1"; _resolve_zoxide "$2"' \
        "$RESOLVE" "$EMPTY_BIN" "$1"
}

# --- cases -------------------------------------------------------------------
check "match echoes zoxide's path"   "/home/user/projects/proj" "$(withfake proj)"
check "no-match echoes empty"        ""                          "$(withfake zzz_nomatch)"
check "missing-binary echoes empty"  ""                          "$(without proj)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
