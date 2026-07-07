#!/bin/sh
# Unit tests for resolve() dispatcher (P1.M1.T2.S4 — CORRECTION B).
# TDD discipline: case 1 demonstrates that WITHOUT the trailing `return 0`, a
# zoxide no-match (simulated non-zero exit) propagates as resolve's exit status
# (the bug); cases 2-8 prove correct output, and cases 9-14 prove exit 0 for
# every backend x {match, no-match} (the CORRECTION-B contract).
# Strategy: one fake `tmux` answers @zoxide-sessions-backend (from $ZS_BACKEND,
# default auto) and @zoxide-sessions-z-sh (baked path); a fake `zoxide` matches
# `proj` and exits 1 on no-match (simulates the version-dependent non-zero exit
# CORRECTION B defends against); a minimal `z.sh` fixture makes _z match `work`.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- minimal z.sh fixture: _z cds on `work`, no-op on a miss -----------------
ZFIX="$REPO_ROOT/tests/.zfix4"
ZSH="$ZFIX/z.sh"
mkdir -p "$ZFIX/work"
cat > "$ZSH" <<ZSH
_z() {
    case "\$1" in
        work) cd "$ZFIX/work" 2>/dev/null || cd / ;;
        *) ;;  # no-op on miss -> cwd unchanged
    esac
}
ZSH

# --- fake tmux: answers @zoxide-sessions-backend ($ZS_BACKEND, default auto)
#     and @zoxide-sessions-z-sh (baked $ZSH path) ----------------------------
TBIN="$REPO_ROOT/tests/.tbin4"
mkdir -p "$TBIN"
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
# Fake tmux implementing ONLY: tmux show-option -gqv <name>
if [ "\$1" = "show-option" ]; then
    shift
    name=""
    while [ \$# -gt 0 ]; do
        case "\$1" in -*) ;; *) name="\$1"; break ;; esac
        shift
    done
    case "\$name" in
        @zoxide-sessions-backend) printf '%s\n' "\${ZS_BACKEND:-auto}" ;;
        @zoxide-sessions-z-sh)    printf '%s\n' "$ZSH" ;;
        *)                        printf '' ;;
    esac
fi
exit 0
TMUX
chmod +x "$TBIN/tmux"

# --- fake zoxide: matches `proj` (exit 0); no-match -> empty + exit 1 --------
# (exit 1 on no-match simulates the version-dependent non-zero exit that
#  CORRECTION B's trailing `return 0` defends against — findings_and_risks.md §B)
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
    proj) printf '%s\n' "/home/user/projects/proj"; exit 0 ;;   # MATCH
    *)    printf ''; exit 1 ;;                                   # no-match: empty + NON-zero (CORRECTION B)
esac
ZOXIDE
chmod +x "$TBIN/zoxide"

cleanup() { rm -rf "$ZFIX" "$TBIN"; }
trap cleanup EXIT INT TERM

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# resolve stdout, with the backend selected via $ZS_BACKEND and fakes on PATH.
rout() {  # rout <backend> <query>
    sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3"' \
        "$RESOLVE" "$1" "$TBIN" "$2"
}
# resolve exit code (output discarded).
rexit() {  # rexit <backend> <query>
    sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3" >/dev/null 2>&1; echo $?' \
        "$RESOLVE" "$1" "$TBIN" "$2" | tail -1
}

# --- case 1: BUGGY form (no trailing return 0) -> zoxide no-match propagates -
# non-zero (the CORRECTION-B bug). Fake zoxide exits 1 on no-match, so a resolve
# WITHOUT `return 0` lets that status leak out of the zoxide branch.
buggy_rc=$(sh -c '
    . "$0"
    ZS_BACKEND="$1"; export ZS_BACKEND
    PATH="$2:$PATH"
    buggy_resolve() {
        backend=$(get_tmux_option "@zoxide-sessions-backend" "auto")
        case "$backend" in
            zoxide) _resolve_zoxide "$1" ;;
            z)      _resolve_z "$1" ;;
            auto)
                _r=$(_resolve_zoxide "$1")
                [ -z "$_r" ] && _r=$(_resolve_z "$1")
                printf "%s\n" "$_r"
                ;;
        esac
    }
    buggy_resolve "$3" >/dev/null 2>&1
    echo $?
' "$RESOLVE" zoxide "$TBIN" zzz)
check "buggy form (no return 0) leaks non-zero on zoxide no-match" "NONZERO" \
    "$( [ "$buggy_rc" != "0" ] && echo NONZERO || echo zero )"

# --- cases 2-3: zoxide backend -----------------------------------------------
check "zoxide match echoes the path"   "/home/user/projects/proj" "$(rout zoxide proj)"
check "zoxide no-match echoes empty"   ""                          "$(rout zoxide zzz)"

# --- cases 4-5: z backend ----------------------------------------------------
check "z match echoes the path"        "$ZFIX/work"                "$(rout z work)"
check "z no-match echoes empty"        ""                          "$(rout z zzz)"

# --- cases 6-8: auto backend (zoxide first, z fallback) ----------------------
check "auto match (zoxide) echoes path"    "/home/user/projects/proj" "$(rout auto proj)"
check "auto no-match echoes empty"          ""                          "$(rout auto zzz)"
check "auto fallback (zoxide miss->z) path" "$ZFIX/work"                "$(rout auto work)"

# --- exit-0 for every backend x {match, no-match} (CORRECTION B contract) ----
check "exit 0: zoxide match"      "0" "$(rexit zoxide proj)"
check "exit 0: zoxide no-match"   "0" "$(rexit zoxide zzz)"
check "exit 0: z match"           "0" "$(rexit z work)"
check "exit 0: z no-match"        "0" "$(rexit z zzz)"
check "exit 0: auto match"        "0" "$(rexit auto proj)"
check "exit 0: auto no-match"     "0" "$(rexit auto zzz)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
