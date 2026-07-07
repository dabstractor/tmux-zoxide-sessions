# PRP — P1.M3.T2.S1 (REVISED): Append `session-created` hook to the run file (PART 2) + isolate the sibling test

> **REVISED after Attempt-1 issue.** The previous implementation was COMPLETE and CORRECT on its three
> deliverables (run-file PART 2 append, `test_session_hook.sh`, `test_run_file.sh` C0 flip) — all gates
> passed. It surfaced ONE issue that the orchestrator assigned to this subtask: the **parallel sibling**
> `tests/test_z_session.sh` (P1.M3.T1.S1's test) now fails C1a, because PART 2's correctly-wired global
> `session-created` hook fires on the sibling's test sessions. This PRP **adds a scoped Task 4** that
> applies the verified 2-line isolation fix to `test_z_session.sh`'s `boot()`, eliminating the
> interference. The three original tasks are kept (made **idempotent**, since the repo may already
> reflect them). Root cause + measured fix: `research/verification_notes.md` §15.

## Goal

**Feature Goal**: Wire the session auto-relocate hook into the run file (PRD §5.2 PART 2), AND ensure the
full test suite stays green by isolating the sibling handler test from the now-active global hook. Concretely:
(a) the run file contains the `# --- 2. Session auto-relocate hook` block (read `@zoxide-sessions-auto-session`,
default `on`; if not `off`, `tmux set-hook -g session-created "run-shell -b '<abs>/scripts/z-session.sh \"#{session_name}\"'"`);
(b) `test_session_hook.sh` verifies the wiring; (c) `test_run_file.sh` C0 reflects the complete file; and
**(d) — NEW —** `test_z_session.sh`'s `boot()` is hardened to isolate from the user's `tmux.conf` so the
real hook no longer interferes with it.

**Deliverable**: Four artifacts —
1. `tmux-zoxide-sessions.tmux` — **MODIFY (idempotent: ensure byte-identical to PRD §5.2)**: PART 2 present
   below PART 1. **Authoritative gate**: `diff <(sed -n '/^### 5.2/,/^### 5.3/p' PRD.md | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d') tmux-zoxide-sessions.tmux` is empty. If PART 2 already present, verify; if absent, APPEND.
2. `tests/test_session_hook.sh` — **NEW/ENSURE** (verbatim from this PRP; passes `pass=11 fail=0`).
3. `tests/test_run_file.sh` — **MODIFY/ENSURE** (flip C0 to assert PART 2 present; C1–C8 unchanged).
4. **`tests/test_z_session.sh` — MODIFY (the issue fix)**: harden `boot()` with `-f /dev/null` +
   `set -g exit-empty off` so the sibling handler test is isolated from the user's `tmux.conf` (and thus
   from this subtask's global hook). Verified `pass=9 fail=0`. See Task 4.

> **⚠️ REPO-STATE NOTE (read before acting).** At research time the repo was ALREADY in the complete
> post-implementation state for the three ORIGINAL deliverables (all UNCOMMITTED; last commit `6f29638`
> was P1.M3.T1.S1's handler): the run file is byte-identical to PRD §5.2, `test_run_file.sh` C0 is already
> flipped, `test_session_hook.sh` already exists and passes 11/11, and `scripts/z-session.sh` is shipped.
> A prior pass already did Tasks 1–3. **Therefore Tasks 1–3 are IDEMPOTENT (verify-then-act)**: if the
> target state is met, verify; if not, apply. **Task 4 (the issue fix) is the NEW work** — `test_z_session.sh`
> currently reports `pass=8 fail=1` and must be fixed. See `research/verification_notes.md` §13, §15.

**Success Definition**:
- `tmux-zoxide-sessions.tmux` is byte-identical to PRD §5.2 (diff empty); `shellcheck -x` rc 0; still `+x`.
- `sh tests/test_session_hook.sh` → `pass=11 fail=0`.
- `sh tests/test_run_file.sh` → `pass=9 fail=0` (C0 flipped).
- **`sh tests/test_z_session.sh` → `pass=9 fail=0`** (THE issue resolution — was `pass=8 fail=1`).
- `sh tests/test_z_window.sh` / `test_resolve_*.sh` still pass (no regression).
- No file outside the four listed is modified.

## Why

- P1.M3.T2.S1's hook is correct (PRD §5.2 verbatim; `set-hook -g` reload-idempotent per NOTE C). It is NOT
  the defect.
- The defect is in `test_z_session.sh`'s test harness, which was always **coupled to the user's `tmux.conf`**
  (it boots without `-f /dev/null` and relies on `tmux-sensible`'s `exit-empty off`, both loaded via the
  user config). PART 2's correct wiring merely **exposes** this latent flaw: the real hook now fires on the
  test's `proj` session and relocates it before the pre-relocate assertion (C1a). See §15 for the full chain.
- The fix is a **test-isolation hardening** (mirror what `test_session_hook.sh` already does), not a handler
  or hook change. It is assigned to this subtask by the orchestrator (P1.M3.T2.S1's work exposed it) and is
  minimal + verified. P1.M3.T1.S1 (the test's original owner) is COMPLETE/committed, so there is no parallel
  write-conflict risk.

## What

- The run file wires the hook exactly per PRD §5.2 PART 2 (item contract #3): `set-hook -g session-created
  "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'"`, gated by `@zoxide-sessions-auto-session != off`.
- `test_z_session.sh`'s `boot()` is changed to isolate the server: `-f /dev/null` (no user config → plugin
  does not load → no real hook) + `set -g exit-empty off` (keep the server alive after `_seed` is killed so
  boot's options persist). No other line in that file changes.

### Success Criteria

- [ ] `tmux-zoxide-sessions.tmux` byte-identical to PRD §5.2; `set-hook -g` (not `-ag`); exact quoting intact.
- [ ] `test_session_hook.sh` → `pass=11 fail=0`; `test_run_file.sh` → `pass=9 fail=0`.
- [ ] **`test_z_session.sh` → `pass=9 fail=0`** (C1a now passes; all other cases still pass).
- [ ] The `test_z_session.sh` change is ONLY in `boot()` (the `-f /dev/null` + `exit-empty off` lines); the
      cases, the fake zoxide, the assertions are unchanged.
- [ ] No regression: `test_z_window.sh`, `test_resolve_*.sh`, `test_session_hook.sh`, `test_run_file.sh` pass.
- [ ] Only `tmux-zoxide-sessions.tmux`, `tests/test_session_hook.sh`, `tests/test_run_file.sh`,
      `tests/test_z_session.sh` are touched; `z-session.sh`/`resolve.sh`/`z-window.sh`/`PRD.md`/`.gitignore` untouched.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this
successfully?_ **Yes.** The PART 2 block is PRD §5.2 verbatim and was exercised end-to-end (stored
`show-hooks` string, firing, spaced-`$1`, `-g` reload-idempotency, `off`-gate). The `test_z_session.sh`
fix is **measured**: the exact 2-line `boot()` change yields `pass=9 fail=0` (was `pass=8 fail=1`). The
single non-obvious trap — that `tmux`'s default `exit-empty on` makes the server EXIT when the only session
(`_seed`) is killed, which is why a naive `-f /dev/null`-only fix FAILS (`pass=5 fail=4`) — is fully
diagnosed with the verified remedy (`-f /dev/null` + `set -g exit-empty off`). `shellcheck` + `tmux` are the
only tools. See `research/verification_notes.md` (§1–§15).

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source — PART 2 is copied VERBATIM (appended below PART 1).
  section: "§5.2 tmux-zoxide-sessions.tmux — the '# --- 2. Session auto-relocate hook' block. §4 Options
            (@zoxide-sessions-auto-session default 'on'). §3.2 guard chain. §6.2 Coexistence (NOTE C). §7
            test 9 (spaced name). §9 Acceptance (show-hooks post-registration check)."
  critical: "Append §5.2 PART 2 VERBATIM below PART 1. KEEP set-hook -g (NOT -ag — NOTE C: -g overwrites =
             reload-idempotent; -ag duplicates). Keep the exact quoting. The result must diff-empty vs PRD §5.2."

- file: plan/001_afc2c7373095/P1M3T2S1/research/verification_notes.md
  why: Empirical proof for every gate. §15 is THE issue root-cause + verified fix.
  section: "§1 exact quoting + stored show-hooks (item contract #4); §2 assert on run-shell not name-count;
            §3 firing + spaced $1; §4 set-hook -g overwrite (NOTE C); §5 off-gate; §8 -f /dev/null clean boot;
            §13 repo already complete (idempotency); §15 THE ISSUE: test_z_session.sh C1a fails — exit-empty
            root cause + the verified 2-line boot() fix (pass=9 fail=0)."
  critical: "§15: the naive -f /dev/null-only fix is WRONG (server exits on _seed kill -> options lost ->
             pass=5 fail=4). The fix is -f /dev/null AND set -g exit-empty off (both in boot(), before the
             kill-session). Measured 9/9. §13: Tasks 1-3 may already be done -> verify-then-act."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: NOTE C — keep set-hook -g (reload-idempotent overwrite), not -ag. DOCS-only composition note.
  section: "🟡 NOTE C: set-hook -g overwrites; -ag duplicates on reload. Decision KEEP -g. Cost (pre-TPM
            global hook replaced) is a DOCS item (P1.M4.T1/T3). Also ✅1 (session-created timing), ✅2 (run-shell -b)."
  critical: "Do NOT switch to -ag. The NOTE C composition contradiction with PRD §6.2 is handled in README
             (P1.M4.T1/T3) — this subtask only FLAGS it (item contract #6), it does not change the mechanism."

- file: plan/001_afc2c7373095/architecture/external_deps.md
  why: TPM reload contract (re-runs run file → -g overwrite is reload-safe) + testing strategy (isolated server).
  section: "§2 TPM loading (runs once per init/reload; reload re-runs -> set-hook -g idempotent); §6 testing
            strategy (isolated tmux -L + fake binaries)."
  critical: "The run file is EXECUTED once per init/reload. set-hook -g on reload OVERWRITES (idempotent).
             Tests must use isolated sockets + fake binaries so the user's live tmux is untouched."

- file: scripts/lib/resolve.sh
  why: PART 2 reuses the already-sourced get_tmux_option (S1). NOT modified.
  critical: "get_tmux_option returns 'on' default for an unset @zoxide-sessions-auto-session -> gate passes.
             Do NOT reimplement option reading; do NOT modify resolve.sh."

- file: tests/test_z_session.sh   # (P1.M3.T1.S1 — the file Task 4 fixes)
  why: The failing sibling test. Its boot() is coupled to the user's tmux.conf (no -f /dev/null; relies on
       tmux-sensible's exit-empty off). Task 4 hardens boot() only.
  section: "boot() (lines ~67-77): kill-server; new-session -s _seed; set backend/home-dir/auto-session/
            window-name; kill-session -t _seed. The cases (C1-C9) invoke $ZSESS directly and assert cwd."
  critical: "Change ONLY boot(): add -f /dev/null to the _seed new-session, and add 'set -g exit-empty off'
             BEFORE 'kill-session -t _seed'. Do NOT touch the cases, fake zoxide, or assertions. The fix
             makes the server start clean (no plugin/hook) AND stay alive after _seed dies (options persist).
             Measured pass=9 fail=0. (verified_notes §15.)"

- file: tests/test_session_hook.sh   # (P1.M3.T2.S1's own test — the isolation template)
  why: The gold-standard isolated test whose boot() discipline Task 4 mirrors: -f /dev/null clean boot.
  section: "cleanboot(): -f /dev/null -L $SOCK new-session (no _seed-kill; it keeps the zs session alive,
             so exit-empty is a non-issue there). 11 asserts."
  critical: "test_session_hook.sh does NOT kill its boot session, so it never hit the exit-empty trap.
             test_z_session.sh DOES kill _seed, which is why it additionally needs 'set -g exit-empty off'."

- file: tmux-zoxide-sessions.tmux   # (the file Tasks 1 appends to — likely already complete)
  why: Current state of the run file. May already be byte-identical to PRD §5.2 (idempotent verify).
  critical: "If PART 2 is already present, VERIFY byte-identity and do NOT re-append (a blind append would
             duplicate the block and break the diff gate). PART 1 is preserved above."

- file: plan/001_afc2c7373095/P1M3T1S1/PRP.md
  why: The sibling PRP (z-session.sh handler). CONTRACT: z-session.sh exists, invoked as z-session.sh "<name>".
  critical: "The handler is correct (verified directly in isolation: z-session.sh proj relocates the pane).
            The test_z_session.sh failure is a HARNESS flaw, not a handler bug. Do NOT modify z-session.sh."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State: run file already byte-identical to PRD §5.2 (PART 1 + PART 2); test_session_hook.sh exists (11/11);
# test_run_file.sh C0 already flipped (9/9); z-session.sh shipped (P1.M3.T1.S1). test_z_session.sh FAILS (8/9).
$ ls -la tmux-zoxide-sessions.tmux
-rwxr-xr-x ... tmux-zoxide-sessions.tmux   # +x (the append preserves the bit)
$ ls scripts scripts/lib
scripts:
lib          z-window.sh     z-session.sh     # z-session.sh: P1.M3.T1.S1 (COMPLETE, +x) — the hook's target
scripts/lib:
resolve.sh   # COMPLETE (S1–S4)

# The run file (already complete — verify, don't duplicate):
$ diff <(sed -n '/^### 5.2/,/^### 5.3/p' PRD.md | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d') tmux-zoxide-sessions.tmux && echo "EMPTY = byte-identical to PRD §5.2"

$ ls tests
test_resolve_*.sh   test_z_window.sh   test_run_file.sh   test_z_session.sh   test_session_hook.sh
# test_z_session.sh: pass=8 fail=1 (C1a) <- THE ISSUE. Others green.

# Tooling:
$ command -v shellcheck tmux bash && tmux -V
/usr/bin/shellcheck (v0.11.0)   /usr/bin/tmux (3.6b)   /usr/bin/bash
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/
  tmux-zoxide-sessions.tmux      # idempotent VERIFY (or APPEND if PART 2 absent) -> byte-identical to PRD §5.2
  scripts/ (lib/resolve.sh, z-window.sh, z-session.sh — UNCHANGED)
  tests/
    test_session_hook.sh         # idempotent ENSURE (verbatim; pass=11 fail=0)
    test_run_file.sh             # idempotent ENSURE C0 flipped (pass=9 fail=0)
    test_z_session.sh            # MODIFY boot() (the issue fix): -f /dev/null + exit-empty off -> pass=9 fail=0
    test_resolve_*.sh test_z_window.sh  # UNCHANGED (regression)
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE ISSUE — exit-empty): tmux's DEFAULT `exit-empty` is ON -> killing the ONLY session EXITS the
#   server. test_z_session.sh's boot() kills _seed (the only session); it only survives because the user's
#   tmux.conf loads tmux-sensible (exit-empty off). So: (a) without -f /dev/null, the plugin loads and its
#   hook fires on test sessions (C1a fails); (b) with -f /dev/null ALONE, exit-empty reverts to ON, the server
#   exits on _seed kill, boot's options are lost, and case new-sessions restart the server with tmux.conf
#   (pass=5 fail=4). THE FIX needs BOTH -f /dev/null AND `set -g exit-empty off` (before kill-session).
#   Measured pass=9 fail=0. (verified_notes §15.)
# CRITICAL (VERBATIM PART 2): copy PRD §5.2 PART 2 byte-for-byte below PART 1. KEEP set-hook -g (NOT -ag).
#   KEEP the exact quoting: "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'" (outer double quotes
#   expand $SESSION_SCRIPT to the abs path; inner single quotes literal; \"#{session_name}\" delivers a
#   spaced name as one $1). Result must diff-empty vs PRD §5.2.
# CRITICAL (IDEMPOTENT): Tasks 1-3 may already be done. VERIFY the end-state gate; do NOT blindly re-append
#   PART 2 (would duplicate + break diff) or re-flip C0. Task 4 (test_z_session.sh) is the new work.
# CRITICAL (TEST — assert on run-shell, not name-count): show-hooks ALWAYS lists the bare `session-created`
#   name (even unset). Assert run-shell PRESENCE (on) / ABSENCE (off). (verified_notes §2.)
# GOTCHA: -f /dev/null must come BEFORE -L on the boot new-session (`tmux -f /dev/null -L $SOCK ...`).
# GOTCHA: `set -g exit-empty off` must be set AFTER the server starts (after new-session _seed) and BEFORE
#   `kill-session -t _seed` (so the server survives the _seed kill).
# GOTCHA: registration does NOT need z-session.sh to exist (set-hook stores a string). Firing assertions
#   (test_session_hook.sh C6/C7) use a staging copy + probe (decoupled from P1.M3.T1.S1).
# GOTCHA: run-shell -b is async; sleep >=0.4s (0.5s validated) after new-session before asserting the probe.
# GOTCHA: the append does NOT change the executable bit (already +x). Do NOT chmod anything.
# FORBIDDEN: Do NOT modify resolve.sh, z-window.sh, z-session.sh, PRD.md, .gitignore, test_resolve_*.sh,
#   test_z_window.sh. Do NOT switch set-hook to -ag. Do NOT write README (P1.M4.T1 — only FLAG NOTE C).
#   Do NOT change test_z_session.sh beyond the boot() -f /dev/null + exit-empty off lines.
```

## Implementation Blueprint

### Verbatim content to APPEND to `tmux-zoxide-sessions.tmux` (Task 1 — if PART 2 absent)

```bash

# --- 2. Session auto-relocate hook -------------------------------------------
# Relocates a newly-created session's first pane from $HOME to the
# zoxide-resolved directory matching its name.
auto_session=$(get_tmux_option "@zoxide-sessions-auto-session" "on")
if [ "$auto_session" != "off" ]; then
    SESSION_SCRIPT="$CURRENT_DIR/scripts/z-session.sh"
    # Quoting mirrors tmux-session-history's proven hooks: the stored command
    # is `run-shell -b "/abs/path/z-session.sh \"#{session_name}\""`, passing
    # the (possibly spaced) session name through as a single $1.
    tmux set-hook -g session-created \
        "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'"
fi
```

### The Task 4 fix for `tests/test_z_session.sh` `boot()` (THE issue resolution)

Change ONLY `boot()`. **Before** (current; pass=8 fail=1):
```sh
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    # seed then clear so option defaults are clean per-case
    "$REAL_TMUX" -L "$SOCK" new-session -d -s _seed -c "$FIX" 2>/dev/null || true
    sleep 0.1
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-home-dir' "$FIX/home" 2>/dev/null
    # reset the toggleable options each boot (prior cases may have set them)
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -gu '@zoxide-sessions-window-name' 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" kill-session -t _seed 2>/dev/null || true
}
```
**After** (pass=9 fail=0):
```sh
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    # seed then clear so option defaults are clean per-case. -f /dev/null isolates the
    # server from the user's tmux.conf (so TPM does NOT reload this plugin and its
    # session-created hook cannot fire on test sessions). exit-empty off keeps the
    # server alive after _seed is killed (tmux's default exit-empty ON would exit it
    # and discard these set -g options). (P1.M3.T2.S1 — research/verification_notes.md §15)
    "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s _seed -c "$FIX" 2>/dev/null || true
    sleep 0.1
    "$REAL_TMUX" -L "$SOCK" set -g exit-empty off 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-home-dir' "$FIX/home" 2>/dev/null
    # reset the toggleable options each boot (prior cases may have set them)
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -gu '@zoxide-sessions-window-name' 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" kill-session -t _seed 2>/dev/null || true
}
```
> Exactly TWO lines change: the `_seed` `new-session` gains `-f /dev/null`; a new
> `set -g exit-empty off` is inserted before the `@zoxide-sessions-backend` line. Nothing else in the file
> (cases, fake zoxide, assertions, cleanup) is touched. Measured `pass=9 fail=0`.

### `tests/test_session_hook.sh` (Task 2 — verbatim; the full test)

```sh
#!/bin/sh
# Integration test for the session-created hook wiring in tmux-zoxide-sessions.tmux (P1.M3.T2.S1).
# Drives an ISOLATED, CLEAN tmux server (tmux -L zxstest_hook, booted with -f /dev/null so the
# USER's tmux.conf does NOT load). A fake `tmux` wrapper forwards every bare `tmux` call to it.
# REGISTRATION/RELOAD/REGRESSION (C1-C5) run the REAL repo run file (set-hook stores a string;
# does not need z-session.sh). FIRING/$1 (C6-C7) use a staging copy + probe handler.
# Asserts on `run-shell` PRESENCE/ABSENCE in show-hooks, NOT a bare-name count (always lists).
set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_hook"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$REPO_ROOT/tmux-zoxide-sessions.tmux"
FIX="$(mktemp -d)"; mkdir -p "$FIX"
PLOG="$(mktemp)"
TBIN="$FIX/.tbin"; mkdir -p "$TBIN"
cleanup() { "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true; rm -rf "$FIX" "$PLOG"; }
trap cleanup EXIT INT TERM
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
TMUX
chmod +x "$TBIN/tmux"
export PATH="$TBIN:$PATH"
cleanboot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX" \
        || { echo "FATAL: cleanboot new-session"; exit 2; }
    sleep 0.2
}
pass=0; fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1)); else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi; }
contains() { if printf '%s' "$2" | grep -Fq -- "$3"; then echo "PASS  $1"; pass=$((pass+1)); else echo "FAIL  $1 (expected haystack to contain [$3]; got=[$2])"; fail=$((fail+1)); fi; }
notcontains() { if printf '%s' "$2" | grep -Fq -- "$3"; then echo "FAIL  $1 (expected ABSENCE of [$3]; got=[$2])"; fail=$((fail+1)); else echo "PASS  $1 ([$3] correctly absent)"; pass=$((pass+1)); fi; }
RUNFILE="$(cat "$RUN" 2>/dev/null)" || { echo "FATAL: $RUN missing"; exit 2; }

echo "=== C1: run file contains the PART 2 block (static) ==="
contains "C1a: set-hook -g session-created line present" "$RUNFILE" "set-hook -g session-created"
contains "C1b: #{session_name} quoting token present"    "$RUNFILE" "#{session_name}"
contains "C1c: @zoxide-sessions-auto-session gate option" "$RUNFILE" "@zoxide-sessions-auto-session"

echo "=== C2: auto-session=on -> exact stored command (item contract #4) ==="
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
"$RUN" >/dev/null 2>&1
HK=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created 2>&1)
contains "C2a: stored cmd contains 'run-shell -b'"          "$HK" "run-shell -b"
contains "C2b: stored cmd contains ABS scripts/z-session.sh" "$HK" "$REPO_ROOT/scripts/z-session.sh"
contains "C2c: stored cmd contains #{session_name}"          "$HK" "#{session_name}"

echo "=== C3: auto-session=off -> hook NOT set ==="
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' off 2>/dev/null
"$RUN" >/dev/null 2>&1
HK=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created 2>&1)
notcontains "C3: no run-shell when auto-session=off" "$HK" "run-shell"

echo "=== C4: reload-idempotent (set-hook -g overwrite; NOTE C) ==="
cleanboot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
"$RUN" >/dev/null 2>&1
"$RUN" >/dev/null 2>&1
n=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created 2>/dev/null | grep -c 'run-shell -b')
check "C4: single hook after 2x load (set-hook -g overwrite)" "1" "$n"

echo "=== C5: PART 1 binding preserved (regression) ==="
cleanboot
"$RUN" >/dev/null 2>&1
b=$("$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix g 2>&1)
contains "C5: window-jump binding on 'g' still registered" "$b" "bind-key -T prefix g"

echo "=== C6/C7: firing + spaced \$1 (staging copy + probe handler) ==="
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
contains "C7: spaced name \$1 intact (two words)" "$(cat "$PLOG" 2>/dev/null)" "FIRED arg1=[two words]"
rm -rf "$STAGE"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

### The Task 3 edit to `tests/test_run_file.sh` (C0 flip — idempotent)

If C0 is still the PART-1-only guard, flip it. **Before:**
```sh
echo "=== C0: PART 1 only — no session-hook code (PART 2 = P1.M3.T2.S1) ==="
if grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' "$RUN"; then
    echo "FAIL  C0: run file contains session-hook code (must be PART 1 only)"; fail=$((fail+1))
else
    echo "PASS  C0: no session-hook code (PART 1 only)"; pass=$((pass+1))
fi
```
**After:**
```sh
echo "=== C0: PART 2 present — session-created hook wired (P1.M3.T2.S1) ==="
if grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' "$RUN"; then
    echo "PASS  C0: PART 2 present (session-hook code)"; pass=$((pass+1))
else
    echo "FAIL  C0: run file missing PART 2 session-hook code (append is P1.M3.T2.S1)"; fail=$((fail+1))
fi
```
> C1–C8 unchanged; pass count stays 9.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: ENSURE tmux-zoxide-sessions.tmux is byte-identical to PRD §5.2  (IDEMPOTENT)
  - GATE: diff <(sed -n '/^### 5.2/,/^### 5.3/p' PRD.md | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d') tmux-zoxide-sessions.tmux
  - IF empty: PART 2 already present -> VERIFY only (do NOT re-append).
  - IF non-empty (PART 1 only): APPEND the verbatim PART 2 block above (below PART 1).
  - NO chmod (the file is already +x; appending preserves it).

Task 2: ENSURE tests/test_session_hook.sh exists and matches the verbatim test above  (IDEMPOTENT)
  - WRITE the verbatim test (overwrites any prior version; it is byte-identical). Expect pass=11 fail=0.

Task 3: ENSURE tests/test_run_file.sh C0 is flipped  (IDEMPOTENT)
  - IF C0 is the PART-1-only guard -> apply the flip above. IF already flipped -> verify. C1-C8 untouched.

Task 4: FIX tests/test_z_session.sh boot()  (THE ISSUE — new work; was pass=8 fail=1)
  - FILE: tests/test_z_session.sh  (MODIFY boot() ONLY)
  - CHANGE: (a) add `-f /dev/null` to the `_seed` new-session; (b) add `set -g exit-empty off` BEFORE the
            `@zoxide-sessions-backend` line (i.e., before kill-session -t _seed). Use the Before/After above.
  - DO NOT touch: the cases, the fake zoxide, cwd_of/winname_of, assertions, cleanup.
  - WHY: -f /dev/null isolates from user tmux.conf (no plugin load -> no real hook -> C1a passes); exit-empty
         off keeps the server alive after _seed dies (so boot's options persist -> C1b/C7/C9 pass). Measured 9/9.
  - VERIFY: sh tests/test_z_session.sh -> pass=9 fail=0.

Task 5: VERIFY ALL (do not modify during verification)
  - RUN: diff <(sed -n '/^### 5.2/,/^### 5.3/p' PRD.md | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d') tmux-zoxide-sessions.tmux   # empty
  - RUN: shellcheck -x tmux-zoxide-sessions.tmux; echo "rc=$?"           # rc=0
  - RUN: grep -nE 'set-hook -ag' tmux-zoxide-sessions.tmux               # nothing (-g not -ag)
  - RUN: sh tests/test_z_session.sh                                       # pass=9 fail=0  (THE FIX)
  - RUN: sh tests/test_session_hook.sh                                    # pass=11 fail=0
  - RUN: sh tests/test_run_file.sh                                        # pass=9 fail=0
  - RUN: sh tests/test_z_window.sh                                        # pass=11 fail=0 (regression)
  - RUN: sh tests/test_resolve_*.sh                                       # S1-S4 pass (regression)
  - RUN: git status --short   # tmux-zoxide-sessions.tmux + tests/test_run_file.sh + tests/test_z_session.sh
                               # (modified) + tests/test_session_hook.sh (new); nothing else.
```

### Implementation Patterns & Key Details

```bash
# PART 2 (the hook): one option read, one if, one set-hook. The quoting is load-bearing:
#   tmux set-hook -g session-created "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'"
#   OUTER double quotes -> $SESSION_SCRIPT expands to the ABS path at run time. INNER single quotes are
#   literal tmux-stored chars wrapping the run-shell arg as ONE token. \"#{session_name}\" -> literal "
#   around the format; at dispatch tmux expands #{session_name} and the quotes deliver a spaced name as
#   one $1. Stored: session-created[0] run-shell -b "<abs>/scripts/z-session.sh \"#{session_name}\"".
#   set-hook -g OVERWRITES (reload-idempotent). Do NOT use -ag (duplicates on reload — NOTE C).
#
# THE ISSUE FIX (test_z_session.sh boot): two coupled lines.
#   (1) -f /dev/null on the _seed new-session -> server starts with NO config -> the user's tmux.conf is
#       NOT sourced -> TPM does NOT load this plugin -> the global session-created hook is NOT set -> test
#       sessions are created clean (C1a passes).
#   (2) set -g exit-empty off (before kill-session -t _seed) -> the server does NOT exit when its only
#       session (_seed) is killed (tmux default exit-empty ON would exit it and DISCARD boot's set -g
#       options) -> backend/home-dir/auto-session/window-name PERSIST -> the handler's guards work (C1b/
#       C7/C9 pass).
#   BOTH are required: -f /dev/null alone -> pass=5 fail=4 (server exits, options lost, cases restart the
#   server with tmux.conf). exit-empty off alone -> pass=8 fail=1 (plugin still loads, hook fires, C1a
#   fails). Together -> pass=9 fail=0.
```

### Integration Points

```yaml
FILESYSTEM:
  - ensure: "tmux-zoxide-sessions.tmux byte-identical to PRD §5.2 (append PART 2 if absent; +x unchanged)"
  - ensure: "tests/test_session_hook.sh present (verbatim; pass=11 fail=0)"
  - ensure: "tests/test_run_file.sh C0 flipped (pass=9 fail=0; C1-C8 unchanged)"
  - modify: "tests/test_z_session.sh boot() ONLY (-f /dev/null + exit-empty off; pass=9 fail=0)"

DEPENDENCY (do NOT modify):
  - scripts/lib/resolve.sh: COMPLETE (S1-S4). PART 2 reuses get_tmux_option. test_z_session.sh fix needs no
    handler change (z-session.sh is correct in isolation — verified directly).

DOWNSTREAM:
  - P1.M4.T1 (README): documents session auto-relocate + the NOTE C composition note ('Scope & compatibility').
    This subtask FLAGS that note (item contract #6); it does NOT write the README.
  - P1.M4.T2.S1: runs the §7 matrix + §9 acceptance (incl. show-hooks post-registration check).

NO DATABASE / BUILD / CONFIG CHANGES beyond the four files. .gitignore/PRD.md: UNCHANGED (forbidden).
```

## Validation Loop

### Level 1: Syntax & Style

```bash
shellcheck -x tmux-zoxide-sessions.tmux; echo "rc=$?"                      # rc=0
shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -Eo 'SC[0-9]+' | sort -u  # SC1091 (only)
diff <(sed -n '/^### 5.2/,/^### 5.3/p' PRD.md | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d') tmux-zoxide-sessions.tmux  # empty
test -x tmux-zoxide-sessions.tmux && echo "executable OK"                  # executable OK
grep -nE '\bset -e\b|\beval\b|set-hook -ag' tmux-zoxide-sessions.tmux      # nothing
shellcheck tests/test_session_hook.sh tests/test_z_session.sh tests/test_run_file.sh  # all rc=0
# test_z_session.sh: confirm ONLY boot() changed (cases/fake-zoxide/assertions intact):
grep -nE 'new-session -d -s _seed|exit-empty|kill-session -t _seed' tests/test_z_session.sh
```

### Level 2: Integration Tests (the authoritative gates)

```bash
# Run each in isolation (no concurrent tmux -L zxstest_* servers) for determinism.
sh tests/test_z_session.sh        # THE FIX: pass=9 fail=0  (was pass=8 fail=1)
sh tests/test_session_hook.sh     # pass=11 fail=0
sh tests/test_run_file.sh         # pass=9 fail=0  (C0 flipped)
sh tests/test_z_window.sh         # pass=11 fail=0  (regression)
sh tests/test_resolve_dispatcher.sh test_resolve_z.sh test_resolve_zoxide.sh test_resolve_get_tmux_option.sh  # S4-S1 pass
# If test_z_session.sh C1a still fails: boot() -f /dev/null not applied (plugin still loads).
# If test_z_session.sh C1b/C7/C9 fail (pass=5 fail=4): exit-empty off missing (server exits on _seed kill).
```

### Level 3: Smoke (system validation)

```bash
# TPM-load the full run file on a CLEAN isolated server; confirm the exact show-hooks (item contract #4).
REAL_TMUX=/usr/bin/tmux; SOCK=zxssmoke_hook2
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
B=$(mktemp -d)
printf '#!/bin/sh\nexec "%s" -L %s "$@"\n' "$REAL_TMUX" "$SOCK" > "$B/tmux"; chmod +x "$B/tmux"
PATH="$B:$PATH" "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$HOME"; sleep 0.2
PATH="$B:$PATH" "$PWD/tmux-zoxide-sessions.tmux" >/dev/null 2>&1
"$REAL_TMUX" -L "$SOCK" show-hooks -g session-created   # session-created[0] run-shell -b "<PWD>/scripts/z-session.sh \"#{session_name}\""
"$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix g        # PART 1 binding preserved
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; rm -rf "$B"
```

### Level 4: N/A
No performance/security/API-doc validation applies. The feature + fix are fully covered by Levels 1-3.

## Final Validation Checklist

### Technical Validation
- [ ] `diff <(sed -n '/^### 5.2/,/^### 5.3/p' PRD.md | sed -n '/^```bash$/,/^```$/p' | sed '1d;$d') tmux-zoxide-sessions.tmux` → empty (byte-identical to PRD §5.2).
- [ ] `shellcheck -x tmux-zoxide-sessions.tmux` → rc 0; `test -x` → executable (bit preserved).
- [ ] `grep -nE 'set-hook -ag' tmux-zoxide-sessions.tmux` → nothing (`-g`, not `-ag`).
- [ ] `sh tests/test_z_session.sh` → **`pass=9 fail=0`** (THE issue resolution).
- [ ] `sh tests/test_session_hook.sh` → `pass=11 fail=0`.
- [ ] `sh tests/test_run_file.sh` → `pass=9 fail=0` (C0 flipped).
- [ ] `sh tests/test_z_window.sh` / `test_resolve_*.sh` → pass (no regression).
- [ ] `test_z_session.sh` change is confined to `boot()` (`-f /dev/null` + `exit-empty off`); cases/assertions untouched.

### Feature Validation
- [ ] After loading the run file with auto-session=on: `show-hooks -g session-created` prints
      `session-created[0] run-shell -b "/<abs>/scripts/z-session.sh \"#{session_name}\""` (item contract #4).
- [ ] auto-session=off → no `run-shell` in show-hooks.
- [ ] Reload (run file ×2) → single hook (set-hook -g overwrite).
- [ ] PART 1 binding on `g` preserved.
- [ ] test_z_session.sh's `proj` is NO LONGER relocated by the real hook before C1a (server isolated).

### Code Quality Validation
- [ ] PART 2 is PRD §5.2 verbatim; whole file diffs-empty vs PRD §5.2.
- [ ] test_z_session.sh fix mirrors test_session_hook.sh's isolation discipline (-f /dev/null) + adds
      exit-empty off (required because boot() kills its seed session).
- [ ] Only the four files change; nothing forbidden is touched.

### Documentation & Deployment
- [ ] PART 2 inline comment kept verbatim; NOTE C composition note FLAGGED for P1.M4.T1/T3 (not written here).
- [ ] No new tmux options; PART 2 reads the EXISTING `@zoxide-sessions-auto-session`.

---

## Anti-Patterns to Avoid

- ❌ Don't apply `-f /dev/null` to test_z_session.sh **without** `set -g exit-empty off` — the server EXITS
  when `_seed` (the only session) is killed (default `exit-empty on`), boot's options are lost, and case
  `new-session`s restart the server with tmux.conf → `pass=5 fail=4`. Both lines are required (verified §15).
- ❌ Don't modify test_z_session.sh beyond `boot()` — the cases, fake zoxide, and assertions are correct; the
  bug is purely the harness isolation. Touching them risks breaking P1.M3.T1.S1's coverage.
- ❌ Don't "fix" the issue by weakening the hook (e.g. defaulting auto-session off, or using -ag) — the hook
  is correct per PRD §5.2; the defect is the test harness.
- ❌ Don't switch `set-hook -g` to `-ag` (NOTE C: reload-duplicate). Don't change the quoting.
- ❌ Don't blindly re-append PART 2 if it's already present (idempotency) — verify the diff gate; duplication
  breaks byte-identity.
- ❌ Don't assert the hook via `grep -c 'session-created'` (the name always lists); assert on `run-shell`.
- ❌ Don't run tests against the user's live tmux — isolated sockets only.

---

## Scope Boundaries (explicit)

| Item | This subtask (P1.M3.T2.S1, REVISED) | Other subtasks |
| --- | --- | --- |
| `tmux-zoxide-sessions.tmux` PART 2 | ✅ ENSURE byte-identical to PRD §5.2 (idempotent) | P1.M2.T2.S1 owns PART 1 |
| `tests/test_session_hook.sh` | ✅ ENSURE present (verbatim; pass=11) | — |
| `tests/test_run_file.sh` C0 | ✅ ENSURE flipped (idempotent) | P1.M2.T2.S1 owns the rest |
| `tests/test_z_session.sh` `boot()` | ✅ **FIX** (`-f /dev/null` + `exit-empty off`; pass=9) — THE issue | P1.M3.T1.S1 owns the cases (unchanged) |
| `scripts/z-session.sh` / `resolve.sh` / `z-window.sh` | ❌ DO NOT (handler correct in isolation) | P1.M3.T1.S1 / S1-S4 / P1.M2.T1.S1 |
| README NOTE C composition note | ❌ FLAG only (item contract #6) | P1.M4.T1/T3 |
| `set-hook -g` vs `-ag` | ✅ KEEP `-g` | — |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN | — |

---

## Confidence Score

**9.5/10** — one-pass success likelihood. The three original deliverables were already implemented and
verified correct by the prior pass (this PRP makes them idempotent). The NEW issue resolution (Task 4) is
**measured**: the exact 2-line `boot()` change (`-f /dev/null` + `set -g exit-empty off`) takes
`test_z_session.sh` from `pass=8 fail=1` to `pass=9 fail=0`, with the full root-cause chain (tmux default
`exit-empty on` + tmux-sensible coupling) diagnosed and documented. The 0.5 reservation is for the inherent
parallel-execution coupling: if P1.M3.T1.S1 were to re-run and overwrite `test_z_session.sh`, the fix would
need re-applying — but P1.M3.T1.S1 is committed/complete, so this is low-risk.
