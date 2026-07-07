#!/bin/sh
# Integration test for the session-created hook wiring in tmux-zoxide-sessions.tmux
# (P1.M3.T2.S1 — APPEND of PRD §5.2 PART 2).
#
# Strategy (item contract #5): drive an ISOLATED, CLEAN tmux server (tmux -L zxstest_hook,
# booted with -f /dev/null so the USER's tmux.conf does NOT load — e.g. a tmux-session-history
# session-created hook would otherwise pollute the assertions; verified_notes §8). A fake `tmux`
# wrapper on PATH forwards every bare `tmux` call (the run file's bind-key/set-hook/get_tmux_option)
# to that server.
#
# Two decoupled strategies (parallel-safe vs P1.M3.T1.S1):
#   * REGISTRATION / RELOAD / REGRESSION (C1–C5): run the REAL repo run file. set-hook merely STORES
#     the command string; it does NOT need scripts/z-session.sh to exist (run-shell checks the file
#     only at dispatch). So show-hooks + list-keys work without P1.M3.T1.S1's deliverable.
#   * FIRING / $1 INTEGRITY (C6–C7): a STAGING COPY of the run file + a PROBE z-session.sh (logs $1).
#     The run file's SESSION_SCRIPT then points at the probe; creating a session fires it.
#
# Assertions key on `run-shell` PRESENCE/ABSENCE in show-hooks — NOT a grep -c of the bare
# `session-created` hook NAME, which ALWAYS lists (even when unset). (verified_notes §2.)

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_hook"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$REPO_ROOT/tmux-zoxide-sessions.tmux"

FIX="$(mktemp -d)"; mkdir -p "$FIX"
PLOG="$(mktemp)"                       # probe z-session.sh appends "FIRED arg1=[<name>]" here
TBIN="$FIX/.tbin"; mkdir -p "$TBIN"

cleanup() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    rm -rf "$FIX" "$PLOG"
}
trap cleanup EXIT INT TERM

# fake `tmux` wrapper: forward ALL bare `tmux` calls to the isolated server.
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
TMUX
chmod +x "$TBIN/tmux"
export PATH="$TBIN:$PATH"

# CLEAN boot: -f /dev/null BEFORE -L so NO user tmux.conf is sourced (verified_notes §8).
cleanboot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX" \
        || { echo "FATAL: cleanboot new-session"; exit 2; }
    sleep 0.2
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
notcontains() {  # notcontains <desc> <haystack> <needle>  (asserts ABSENCE)
    if printf '%s' "$2" | grep -Fq -- "$3"; then echo "FAIL  $1 (expected ABSENCE of [$3]; got=[$2])"; fail=$((fail+1));
    else echo "PASS  $1 ([$3] correctly absent)"; pass=$((pass+1)); fi
}

RUNFILE="$(cat "$RUN" 2>/dev/null)" || { echo "FATAL: $RUN missing"; exit 2; }

echo "=== C1: run file contains the PART 2 block (static — append landed) ==="
contains "C1a: set-hook -g session-created line present" "$RUNFILE" "set-hook -g session-created"
contains "C1b: #{session_name} quoting token present"    "$RUNFILE" "#{session_name}"
contains "C1c: @zoxide-sessions-auto-session gate option" "$RUNFILE" "@zoxide-sessions-auto-session"

echo "=== C2: auto-session=on -> hook registered with the EXACT stored command (item contract #4) ==="
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
"$RUN" >/dev/null 2>&1
HK=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created 2>&1)
contains "C2a: stored cmd contains 'run-shell -b'"          "$HK" "run-shell -b"
contains "C2b: stored cmd contains ABS scripts/z-session.sh" "$HK" "$REPO_ROOT/scripts/z-session.sh"
contains "C2c: stored cmd contains #{session_name}"          "$HK" "#{session_name}"

echo "=== C3: auto-session=off -> hook NOT set (the if-gate skips set-hook) ==="
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' off 2>/dev/null
"$RUN" >/dev/null 2>&1
HK=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created 2>&1)
notcontains "C3: no run-shell when auto-session=off" "$HK" "run-shell"

echo "=== C4: reload-idempotent — run file x2 -> still ONE hook (set-hook -g OVERWRITES; NOTE C) ==="
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
"$RUN" >/dev/null 2>&1
"$RUN" >/dev/null 2>&1                      # simulate a TPM reload
n=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created 2>/dev/null | grep -c 'run-shell -b')
check "C4: single hook after 2x load (set-hook -g overwrite)" "1" "$n"

echo "=== C5: PART 1 binding preserved after append (regression) ==="
cleanboot
"$RUN" >/dev/null 2>&1
b=$("$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix g 2>&1)
contains "C5: window-jump binding on 'g' still registered" "$b" "bind-key -T prefix g"

echo "=== C6: hook FIRES on session creation; \$1 = session name (probe log) ==="
echo "=== C7: spaced session name arrives as ONE \$1 (PRD §7 test 9) ==="
# Staging copy of the run file + a PROBE z-session.sh (decoupled from P1.M3.T1.S1).
STAGE="$(mktemp -d)"
cp "$RUN" "$STAGE/tmux-zoxide-sessions.tmux"
mkdir -p "$STAGE/scripts/lib"
cp "$REPO_ROOT/scripts/lib/resolve.sh" "$STAGE/scripts/lib/" 2>/dev/null \
    || { echo "FATAL: resolve.sh missing"; exit 2; }
cat > "$STAGE/scripts/z-session.sh" <<EOF
#!/bin/sh
echo "FIRED arg1=[\$1]" >> "$PLOG"
exit 0
EOF
chmod +x "$STAGE/scripts/z-session.sh"
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
"$STAGE/tmux-zoxide-sessions.tmux" >/dev/null 2>&1
: > "$PLOG"
"$REAL_TMUX" -L "$SOCK" new-session -d -s projhook -c "$FIX"; sleep 0.5
contains "C6: hook fired with \$1=projhook" "$(cat "$PLOG" 2>/dev/null)" "FIRED arg1=[projhook]"
: > "$PLOG"
"$REAL_TMUX" -L "$SOCK" new-session -d -s "two words" -c "$FIX"; sleep 0.5
# A spaced name that survived as ONE $1 proves the hook's \"#{session_name}\" quoting.
contains "C7: spaced name \$1 intact (two words)" "$(cat "$PLOG" 2>/dev/null)" "FIRED arg1=[two words]"
rm -rf "$STAGE"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
