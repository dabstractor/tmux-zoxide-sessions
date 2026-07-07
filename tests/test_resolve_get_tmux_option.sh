#!/bin/sh
# Unit tests for get_tmux_option (P1.M1.T2.S1).
# Strategy: inject a fake `tmux` earlier on PATH that answers `show-option -gqv <name>`
# with canned output, source resolve.sh, and assert each branch. No live tmux required.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- fake tmux ---------------------------------------------------------------
TBIN="$REPO_ROOT/tests/.tmux-bin"
mkdir -p "$TBIN"
cat > "$TBIN/tmux" <<'TMUX'
#!/bin/sh
# Fake tmux implementing ONLY: tmux show-option -gqv <name>
if [ "$1" = "show-option" ]; then
    shift                       # drop 'show-option'
    name=""
    while [ $# -gt 0 ]; do      # name = first non-flag arg (skip -g -q -v ...)
        case "$1" in -*) ;; *) name="$1"; break ;; esac
        shift
    done
    case "$name" in
        @set-nonempty) printf '%s\n' "thevalue" ;;
        @set-empty)    printf '' ;;           # set, but value is empty
        @set-space)    printf '%s\n' "with space" ;;
        *)             printf '' ;;           # unset -> empty stdout, exit 0
    esac
fi
exit 0
TMUX
chmod +x "$TBIN/tmux"

cleanup() { rm -rf "$TBIN"; }
trap cleanup EXIT INT TERM
PATH="$TBIN:$PATH"
export PATH

# --- harness -----------------------------------------------------------------
pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}
run() { sh -c '. "$0"; get_tmux_option "$1" "$2"' "$RESOLVE" "$1" "$2"; }
# variant with no default arg:
run1() { sh -c '. "$0"; get_tmux_option "$1"' "$RESOLVE" "$1"; }

# --- cases -------------------------------------------------------------------
check "set non-empty option echoes the value" "thevalue"    "$(run @set-nonempty DEFAULT)"
check "unset option echoes default"           "DEFAULT"     "$(run @unset-opt DEFAULT)"
check "set-to-empty option echoes default"    "DEFAULT"     "$(run @set-empty DEFAULT)"
check "value with spaces preserved"           "with space"  "$(run @set-space DEFAULT)"
check "empty default + unset -> empty"        ""            "$(run @unset-opt '')"
check "default omitted + unset -> empty"      ""            "$(run1 @unset-opt)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
