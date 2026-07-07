#!/bin/sh
# Unit tests for _resolve_z (P1.M1.T2.S3 — CORRECTION A).
# TDD discipline: case 1 demonstrates the PRD §5.3 false positive (no-match -> NON-empty
# via the buggy `pwd` form); cases 2-5 prove the shipped CORRECTION-A fix (match -> path,
# no-match -> empty, short-circuit on unset, always exit 0).
# Strategy: a minimal `z.sh` fixture reproduces rupa/z's _z semantics (cd on match, no-op on
# miss), and a fake `tmux` answers @zoxide-sessions-z-sh. No live rupa/z or ~/.z required.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- minimal z.sh fixture: _z cds on a known match, no-op on a miss ------------
# (unquoted heredoc bakes $ZFIX/proj as a literal path; \$1 stays the function's param)
ZFIX="$REPO_ROOT/tests/.zfix"
mkdir -p "$ZFIX/proj"
cat > "$ZFIX/z.sh" <<ZSH
_z() {
    case "\$1" in
        proj) cd "$ZFIX/proj" 2>/dev/null || cd / ;;
        *) ;;  # no-op on miss -> cwd unchanged (the false-positive root cause)
    esac
}
ZSH

# --- fake tmux #1 (option SET): answers @zoxide-sessions-z-sh with the z.sh path
TBIN_SET="$REPO_ROOT/tests/.tmux-set"
mkdir -p "$TBIN_SET"
cat > "$TBIN_SET/tmux" <<TMUX
#!/bin/sh
[ "\$1" = "show-option" ] && printf '%s\n' "$ZFIX/z.sh"
exit 0
TMUX
chmod +x "$TBIN_SET/tmux"

# --- fake tmux #2 (option UNSET): answers nothing -----------------------------
TBIN_UNSET="$REPO_ROOT/tests/.tmux-unset"
mkdir -p "$TBIN_UNSET"
cat > "$TBIN_UNSET/tmux" <<'TMUX'
#!/bin/sh
exit 0
TMUX
chmod +x "$TBIN_UNSET/tmux"

cleanup() { rm -rf "$ZFIX" "$TBIN_SET" "$TBIN_UNSET"; }
trap cleanup EXIT INT TERM

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# _resolve_z stdout, with the SET fake tmux on PATH.
zout() {  # zout <query>
    sh -c 'PATH="'"$TBIN_SET"':$PATH" . "$0" >/dev/null; _resolve_z "$1"' "$RESOLVE" "$1"
}
# _resolve_z exit code (last stdout line).
zexit() {
    sh -c 'PATH="'"$TBIN_SET"':$PATH" . "$0" >/dev/null; _resolve_z "$1"; echo $?' "$RESOLVE" "$1" \
        | tail -1
}
# _resolve_z with the UNSET fake tmux on PATH (option unset -> short-circuit).
zout_unset() {
    sh -c 'PATH="'"$TBIN_UNSET"':$PATH" . "$0" >/dev/null; _resolve_z "$1"' "$RESOLVE" "$1"
}

# --- case 1: BUGGY PRD §5.3 form -> no-match is NON-empty (the false positive) -
buggy=$(sh -c 'PATH="'"$TBIN_SET"':$PATH" . "$0" >/dev/null
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    shell="sh"; command -v zsh >/dev/null 2>&1 && shell="zsh"
    "$shell" -c '"'"'. "$1"; _z "$2" >/dev/null 2>&1; pwd'"'"' _ "$z_sh" "zzz_nomatch" 2>/dev/null
' "$RESOLVE")
check "buggy form false-positive on no-match (NON-empty)" "NONEMPTY" \
    "$( [ -n "$buggy" ] && echo NONEMPTY || echo empty )"

# --- cases 2-5: the shipped CORRECTION-A fix ----------------------------------
check "_resolve_z match returns the path"       "$ZFIX/proj" "$(zout proj)"
check "_resolve_z no-match echoes empty"        ""          "$(zout zzz_nomatch_xyz_999)"
check "_resolve_z short-circuits empty (unset)" ""          "$(zout_unset proj)"
check "_resolve_z always exits 0"               "0"         "$(zexit zzz_nomatch_xyz_999)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
