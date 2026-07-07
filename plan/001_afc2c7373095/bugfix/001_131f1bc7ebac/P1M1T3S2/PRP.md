# PRP — P1.M1.T3.S2: Add `-l` and multi-line regression cases to the two integration tests

## Goal

**Feature Goal**: Lock in the Issue-1 fix (zoxide `-l`/`--list` flag absorption) at the
**integration** level by adding committed regression cases to the two end-to-end test files
that drive the REAL `scripts/z-window.sh` / `scripts/z-session.sh` against a sandboxed tmux
server. Two new cases per file: (a) a **leading-dash** query (`-l`) that must NOT corrupt the
window / must NOT relocate the pane, and (b) a **multi-line resolved value** (a fake token that
prints 3 lines) that the caller-side defence-in-depth guard must reject. This is **Layer 3**
(committed regression tests) of the three-layer Issue-1 remediation; Layers 1 (resolver `--`
guard) and 2 (caller guards) are already in place.

**Deliverable**: Edits to **two** test files only — `tests/test_z_window.sh` and
`tests/test_z_session.sh`. In each file: (1) add a `multiline)` arm to the existing hardened
fake-zoxide heredoc, and (2) append two new test cases that reuse the file's existing helpers
(`run_case`/`new_name`/`new_start` for the window file; `boot`/`cwd_of`/`$ZSESS` for the
session file). No source changes, no new files.

**Success Definition**:
- `sh tests/test_z_window.sh` → `RESULTS: pass=17 fail=0` (was 11; contract floor `>=15`). Exit 0.
- `sh tests/test_z_session.sh` → `RESULTS: pass=13 fail=0` (was 9; contract floor `>=12`). Exit 0.
- The full suite stays green: all 9 files exit 0 (aggregate 80 → 90 PASS / 0 FAIL).
- The four new cases each assert the user-visible outcome: window/pane lands in the current
  path (`$cur`) / at `$FIX/home` — **never** in a multi-line dump or a corrupt path.
- No source file, fake fixture contract, or existing assertion is altered.

> **CRITICAL — this task is NOT blocked by the absent resolver `--` guard.** The sibling UNIT
> task (P1.M1.T3.S1) HALTED because it asserts `resolve("-l") == ""`, which needs the `--` guard
> in `scripts/lib/resolve.sh` (P1.M1.T1.S2, still "Researching"). These **integration** tests
> assert the *end-to-end outcome* (window/pane not corrupted), which is guaranteed by the
> **defence-in-depth caller guards** (P1.M1.T2.S1/S2 = **Complete**): those reject any
> multi-line / non-directory `resolved` regardless of whether the resolver emits empty (with
> `--`) or a dump (without `--`). All four new cases were verified green against the CURRENT
> (guard-absent) repo — see `research/research_notes.md` §0 and the Level-0 baseline.

## User Persona

**Target User**: The implementing AI agent (2-point, test-only task). Downstream: the bugfix
release validation (the new cases are the committed proof that Issue 1 cannot recur); P1.M3.T1
(README) references the test counts.

**Use Case**: A developer runs `sh tests/test_z_window.sh` / `sh tests/test_z_session.sh`
(after any future change to the resolver or callers) and is immediately alerted if a leading-dash
query or a multi-line resolver output ever again corrupts a window or relocates a pane.

**Pain Points Addressed**: The original bug was invisible to the suite because the fake-zoxide
treated `-l` as a plain query string. The hardened fake (P1.M1.T1.S1) now models real zoxide
flag parsing; these cases complete the loop by asserting the safe end-to-end behaviour.

## Why

- This is **Layer 3** of the Issue-1 fix (`architecture/system_context.md §4`,
  `architecture/research_issue1_defense.md §B/§C`). Layers 1 (resolver `--`) and 2 (caller
  guards) are in place; Layer 3 commits the regression so the fix can never be silently reverted
  (as it was by commit `b93e776`).
- The two case classes are **complementary and independent**:
  - **`-l`** — exercises the leading-dash input path end-to-end (the exact user repro: `prefix g`,
    type `-l`). It documents the resolver's intended empty-return; until P1.M1.T1.S2 lands it
    passes via the caller guard instead. Either way the window/pane is safe.
  - **`multiline`** — a *non-leading-dash* token whose fake arm returns a 3-line dump. This
    **cannot** be rescued by the `--` guard (the dump comes from a normal positional query), so it
    is the **isolated, decisive test of the defence-in-depth caller guard** (P1.M1.T2.S1/S2).
- Coverage parity: `z-window.sh` and `z-session.sh` are the two callers of the shared
  `resolve()`; each gets its own `-l` + multi-line pair so the contract holds at both.

## What

User-visible behaviour: **none** (test-only). What changes is the test files' assertion count
and the fake-zoxide's token table (+1 `multiline` arm each).

### Success Criteria

- [ ] `sh tests/test_z_window.sh` prints `RESULTS: pass=17 fail=0` and exits 0 (floor `>=15`).
- [ ] `sh tests/test_z_session.sh` prints `RESULTS: pass=13 fail=0` and exits 0 (floor `>=12`).
- [ ] Window fake has a `multiline)` arm; session fake has a `multiline)` arm (each prints 3 lines).
- [ ] Window CASE 5 asserts: `run_case -l` → exactly 1 new window, NAME = `basename($cur)`,
      START_PATH = `$cur`.
- [ ] Window CASE 6 asserts: `run_case multiline` → exactly 1 new window, NAME = `basename($cur)`,
      START_PATH = `$cur` (guard rejects the multi-line value).
- [ ] Session CASE 11 asserts: a session named `-l` at `$FIX/home` → `$ZSESS -l` → pane stays at
      `$FIX/home` (no relocate).
- [ ] Session CASE 12 asserts: a session named `multiline` at `$FIX/home` → `$ZSESS multiline`
      → pane stays at `$FIX/home` (guard rejects the multi-line value).
- [ ] No existing case/assertion changed; full suite 9/9 exit 0.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement
this successfully?_ **Yes.** The exact current fake heredocs, the exact arm to insert (verbatim),
the exact paste-ready case blocks (with the two tmux leading-dash gotchas called out by name
and the verified working forms given), the helper signatures reused verbatim, the verified
assertion counts, and the runnable validation commands are all below. No broader codebase
knowledge required. The single most likely trap — creating a tmux session named `-l` — is
solved explicitly (§Known Gotchas, Gotcha A).

### Documentation & References

```yaml
# MUST READ
- file: tests/test_z_window.sh
  why: FILE 1 being edited. Contains the hardened fake (P1.M1.T1.S1) + the run_case/new_name/
       new_start helpers the new cases reuse. Baseline pass=11.
  pattern: "Per-case: capture CUR=$(tmux display-message -p '#{pane_current_path}'); res=$(run_case
            <args>); delta=${res%%|*}; idx=${res##*|}; then check delta / new_name / new_start."
  gotcha: "Cases that assert fallback-to-cur (1/3/4/5/6) MUST re-capture CUR immediately before
           run_case, because the active window shifts after each case (new-window becomes active).
           CASE 2 does not re-capture because it asserts the resolved dir, not cur."

- file: tests/test_z_session.sh
  why: FILE 2 being edited. Contains the hardened fake + boot/cwd_of helpers. Baseline pass=9.
       Cases mirror PRD §7 test numbers (1,2,3,4,6,7,9); §7 tests 5(sessionx)/10(resurrect) are
       external-plugin checks, skipped. New cases use numbers 11/12 (beyond §7's 1-10) to avoid
       any collision with PRD §7 numbering.
  pattern: "Per-case: boot; tmux new-session -d -s <name> -c $FIX/home; sleep; $ZSESS <name>;
            sleep; check '...' $FIX/home \"$(cwd_of <name>)\"."
  gotcha: "boot() reuses ONE anchor session `zs` across all cases (killing the last session
           destroys the server). A `-l` session is a SECOND session on that server; do NOT kill
           the anchor."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_test_baseline.md
  why: §1 (invocation = `sh tests/test_*.sh`, no runner), §3 (assertion format = check <desc>
       <expected> <actual>, exact-equality, RESULTS line + final `[ fail -eq 0 ]`), §4 (the
       integration harness: real isolated `tmux -f /dev/null -L zxstest*`, fake tmux wrapper,
       fake zoxide, REAL scripts unmodified).
  section: "§4 Fake zoxide vs real zoxide (integration pattern)"
  critical: "The fake is a QUOTED heredoc (<<'ZOX') — $FIX is written LITERALLY and expands at
       RUNTIME via `export FIX`. The new multiline) arm must keep the literal `$FIX` style."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T3S2/research/research_notes.md
  why: Empirical proof every new case passes in the CURRENT (guard-absent) repo; the two tmux
       leading-dash gotchas (session creation via rename trick; targeting via -t -l form 1);
       exact assertion counts (17 / 13).
  section: "§0 (not blocked), §2 (tmux gotchas), §4 (counts)"

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T1S1/research/fixture_hardening_notes.md
  why: Documents the hardened-fake contract the new multiline) arm must fit (quoted heredoc,
       literal $FIX; R2 ordering: `--` checked BEFORE list-mode; the fake's if/else form).
  critical: "Do NOT collapse the fake's if/else into a single case — that breaks R2 (a `query -- -l`
       would re-enter list-mode). The multiline) arm goes in the POSITIONAL case block only."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T2S1/PRP.md
  why: The z-window.sh guard this task's CASE 6 independently validates. §"Desired edits → Edit B"
       shows the exact `case \"$resolved\" in *\"$NL\"*) : ;; *) [ -d ] && dir= ;; esac` form.
  critical: "CASE 6's value is that it exercises THIS guard in isolation of the resolver -- fix —
       a normal positional query returning multi-line can ONLY be caught by this caller guard."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T2S2/PRP.md
  why: The z-session.sh guard CASE 12 independently validates (exit-0 form: *\"$NL\"*) exit 0 ;).
```

### Current Codebase tree (scope of this PRP)

```bash
tests/
  test_z_window.sh     # MODIFY: +multiline) fake arm, +CASE 5 (-l), +CASE 6 (multiline)
  test_z_session.sh    # MODIFY: +multiline) fake arm, +CASE 11 (-l session), +CASE 12 (multiline)
  test_*.sh            # NOT TOUCHED (incl. unit tests = P1.M1.T3.S1)
scripts/
  z-window.sh          # NOT TOUCHED (guard already in place, P1.M1.T2.S1 = Complete)
  z-session.sh         # NOT TOUCHED (guard already in place, P1.M1.T2.S2 = Complete)
  lib/resolve.sh       # NOT TOUCHED (resolver -- guard = P1.M1.T1.S2, not this task's concern)
tmux-zoxide-sessions.tmux   # NOT TOUCHED (P1.M2)
README.md                   # NOT TOUCHED (P1.M3.T1)
```

### Desired Codebase tree with files to be modified

```bash
tests/test_z_window.sh   # +1 fake arm, +2 cases (6 new checks: 11 -> 17)
tests/test_z_session.sh  # +1 fake arm, +2 cases (4 new checks: 9 -> 13)
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (tmux, leading-dash SESSION CREATION): `tmux new-session -s -l` FAILS with
#   "unknown flag -l" — tmux parses a leading-dash token as a flag. The ONLY reliable way to
#   create a session literally named `-l` is the RENAME TRICK:
#       tmux new-session -d -s tmpl -c "$FIX/home"
#       tmux rename-session -t tmpl -- -l        # `--` makes `-l` positional = the new name
#   (Verified: -s=-l creates a session named `=-l`; --session-name=-l is "invalid flag --".)

# CRITICAL (tmux, leading-dash SESSION TARGETING): you CAN target a `-l` session with
#   `display-message -t -l` — tmux's getopt CONSUMES `-l` as the argument to `-t` (it is NOT
#   treated as a flag once -t expects a value). This is EXACTLY what z-session.sh does
#   (`tmux display-message -t "$name"`, name=-l -> argv `display-message -t -l`), so the handler
#   REACHES `resolved=$(resolve "$name")` — the test exercises the real resolve->guard path,
#   it does NOT bail at pane lookup. The test's cwd_of() helper called as `cwd_of -l` produces
#   the identical argv.
#   DO NOT use `-t -- -l` (target becomes `--` -> not found) or `-t=-l` (empty).

# CRITICAL (quoted heredoc): both fakes are `<<'ZOX'` (quoted). `$FIX` is written LITERALLY and
#   expands at RUNTIME via `export FIX`. The new `multiline)` arm must use literal `$FIX/...`
#   (NOT an expanded absolute path), exactly like the existing `proj)` arm.

# CRITICAL (fake R2 ordering): keep the fake's if/else structure intact (-- checked BEFORE the
#   list-mode case). The `multiline)` arm is added ONLY to the POSITIONAL `case "$1"` block
#   (after the `if/else`), never to the list-mode block. A `multiline` query has no leading
#   dash, so it never touches list-mode.

# GOTCHA (re-capture CUR): every window case that asserts fallback-to-cur must re-capture
#   CUR=$(tmux display-message -p '#{pane_current_path}') immediately before run_case, because
#   each prior run_case made its new window the active one. (CASE 1/3/4 already do this.)

# GOTCHA (dump lines need not exist): the multiline dump is `$FIX/proj` + 2 non-existent dirs
#   (`$FIX/other1`, `$FIX/other2`). That is FINE and intentional — the caller guard's newline
#   arm rejects the value BEFORE the `-d` test, so it doesn't matter that lines 2-3 aren't dirs.
#   (Mirror the existing list-mode arm's exact content for consistency.)

# GOTCHA (no hard dependency on P1.M1.T1.S2): the resolver currently has NO `--` guard. A `-l`
#   query therefore returns a 3-line dump (list-mode), NOT empty. The integration assertions
#   still pass because the caller guards reject the dump. Do NOT edit resolve.sh, and do NOT
#   weaken the assertions. (See Goal box + research_notes.md §0.)

# FORBIDDEN: do NOT add the UNIT-test assertions (P1.M1.T3.S1 owns those; they DO require the
#   -- guard and are a separate, currently-halted item). This task is integration-only.
# FORBIDDEN: do NOT touch scripts/*, the run file, README, .gitignore, PRD.md, tasks.json,
#   any prd_snapshot.md, or any other test file.
```

## Implementation Blueprint

### Data models and structure

N/A — pure POSIX `sh` tests. The only "model" is the assertion contract:
`check <desc> <expected> <actual>` (exact string equality), ending in
`echo "RESULTS: pass=$pass fail=$fail"` + `[ "$fail" -eq 0 ]`. Both files already define
`check`; the new cases reuse it.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 0: BASELINE (run BEFORE editing)
  - RUN: sh tests/test_z_window.sh  ; sh tests/test_z_session.sh
    Expected: "RESULTS: pass=11 fail=0" and "RESULTS: pass=9 fail=0".
    IF NOT: STOP — a sibling change left the suite red; get it green first or your edit is blamed.

Task 1: EDIT tests/test_z_window.sh — add the `multiline)` fake arm
  - FIND the positional case block (the second `case "$1" in`, AFTER the `if [ "$1" = "--" ]`
    list-mode block):
        case "$1" in
            proj) printf '%s\n' "$FIX/proj"; exit 0 ;;   # MATCH (real dir)
            *)    printf ''; exit 0 ;;                    # no-match: empty, exit 0
        esac
  - INSERT the multiline arm BEFORE the `*)` arm (keep literal `$FIX`):
        case "$1" in
            proj)      printf '%s\n' "$FIX/proj"; exit 0 ;;                # MATCH (real dir)
            multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;  # MULTI-LINE (defence-in-depth probe)
            *)         printf ''; exit 0 ;;                                # no-match: empty, exit 0
        esac
  - DO NOT touch the if/else list-mode block (the `-l|--list)` arm) or the `--` handling.

Task 2: EDIT tests/test_z_window.sh — append CASE 5 and CASE 6
  - INSERT after the CASE 4 block and BEFORE the closing `echo ""; echo "RESULTS: ..."` lines.
  - Paste (verbatim — note CUR re-capture before each, matching CASE 1/3/4):

        echo "=== CASE 5: query '-l' -> window falls back to cur (Issue 1: leading-dash) ==="
        CUR=$(tmux display-message -p '#{pane_current_path}')
        res=$(run_case -l); delta=${res%%|*}; idx=${res##*|}
        check "C5a exactly 1 new window"   "1"                  "$delta"
        check "C5b NAME = basename(cur)"   "$(basename "$CUR")" "$(new_name "$idx")"
        check "C5c START_PATH = cur"       "$CUR"               "$(new_start "$idx")"

        echo "=== CASE 6: multi-line resolved value -> guard rejects, window falls back to cur ==="
        CUR=$(tmux display-message -p '#{pane_current_path}')
        res=$(run_case multiline); delta=${res%%|*}; idx=${res##*|}
        check "C6a exactly 1 new window"   "1"                  "$delta"
        check "C6b NAME = basename(cur)"   "$(basename "$CUR")" "$(new_name "$idx")"
        check "C6c START_PATH = cur"       "$CUR"               "$(new_start "$idx")"

Task 3: EDIT tests/test_z_session.sh — add the `multiline)` fake arm
  - FIND the positional case block:
        case "$1" in
            proj)        printf '%s\n' "$FIX/proj"; exit 0 ;;
            "two words") printf '%s\n' "$FIX/twowords"; exit 0 ;;
            *)           printf ''; exit 0 ;;
        esac
  - INSERT the multiline arm BEFORE the `*)` arm:
        case "$1" in
            proj)        printf '%s\n' "$FIX/proj"; exit 0 ;;
            "two words") printf '%s\n' "$FIX/twowords"; exit 0 ;;
            multiline)   printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;  # MULTI-LINE (defence-in-depth probe)
            *)           printf ''; exit 0 ;;
        esac

Task 4: EDIT tests/test_z_session.sh — append CASE 11 and CASE 12
  - INSERT after the CASE 9 block and BEFORE the closing `echo ""; echo "RESULTS: ..."` lines.
  - NOTE the rename trick for the `-l` session and the -t -l targeting in cwd_of (both verified).
  - Paste (verbatim):

        echo "=== CASE 11: session named '-l' at home -> NO relocate (Issue 1: leading-dash) ==="
        boot
        # A session literally named '-l' cannot be created with `new-session -s -l` (tmux parses
        # -l as a flag). Create under a placeholder, then rename via `--` (end-of-options).
        "$REAL_TMUX" -L "$SOCK" new-session -d -s tmpl -c "$FIX/home"; sleep 0.3
        "$REAL_TMUX" -L "$SOCK" rename-session -t tmpl -- -l; sleep 0.2
        check "C11a pre-relocate cwd = home"        "$FIX/home" "$(cwd_of -l)"
        "$ZSESS" -l; sleep 0.5
        check "C11b post-handler cwd = home (no relocate)" "$FIX/home" "$(cwd_of -l)"

        echo "=== CASE 12: multi-line resolved value -> guard rejects, NO relocate (Issue 1) ==="
        boot
        "$REAL_TMUX" -L "$SOCK" new-session -d -s multiline -c "$FIX/home"; sleep 0.3
        check "C12a pre-relocate cwd = home"        "$FIX/home" "$(cwd_of multiline)"
        "$ZSESS" multiline; sleep 0.5
        check "C12b post-handler cwd = home (no relocate)" "$FIX/home" "$(cwd_of multiline)"

Task 5: VERIFY (no edits) — see Validation Loop.
```

### Implementation Patterns & Key Details

```sh
# (A) The fake's positional case block gains ONE arm. The arm mirrors the EXISTING list-mode
#     dump (same 3 lines), because the dump's exact content is irrelevant — only its
#     multi-line-ness matters. The caller guard's newline arm rejects it before -d runs, so
#     the 2nd/3rd lines need not be real directories.
#
#         multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;
#
#     WHY a separate token (not reuse of -l): CASE 6 must test the caller guard INDEPENDENTLY
#     of the resolver -- fix. `-l` exercises the leading-dash path (which the -- guard would
#     also catch); `multiline` is a normal positional query whose multi-line output can ONLY
#     be caught by the caller guard. If someone later re-removes the -- guard, CASE 6 still
#     proves the window is safe. (research_notes.md §1.)

# (B) Window cases reuse run_case/new_name/new_start UNCHANGED. run_case returns "<delta>|<idx>"
#     where idx is the newest (highest) window index. new_name/new_start read #{window_name} /
#     #{pane_start_path} via the REAL tmux (synchronous, reliable formats per test header §2).
#     CUR is re-captured before each fallback-asserting case (the active window shifts per case).

# (C) Session `-l` creation = the RENAME TRICK (Gotcha A). Targeting = `cwd_of -l` which yields
#     `display-message -t -l` (Gotcha B, form 1 — the SAME argv z-session.sh produces internally,
#     so the handler genuinely reaches resolve; the test is meaningful, not a pane-lookup bail).

# (D) Assertion counts: window 11 -> 17 (C5×3 + C6×3); session 9 -> 13 (C11×2 + C12×2). Both
#     clear the contract floors (>=15 / >=12) with margin.
```

### Integration Points

```yaml
FAKE-ZOXIDE CONTRACT (both files, hardened by P1.M1.T1.S1):
  - argv form modelled: `query [--] <kw>`  AND  list-mode for `-l`/`--list` (no `--`).
  - `--` stripped (real zoxide honours end-of-options); after `--`, the next token is a POSITIONAL
    query and is NEVER treated as list-mode (R2 ordering — research_test_baseline / fixture notes).
  - NEW (this task): a `multiline)` positional arm prints 3 lines (defence-in-depth probe).
  - Existing tokens (`proj`, `"two words"`, `zzz`/`zzznope`, missing-binary) UNCHANGED.

PRODUCTION CODE (NOT modified by this task):
  - z-window.sh:   `case "$resolved" in *"$NL"*) : ;; *) [ -d "$resolved" ] && dir="$resolved" ;; esac`
  - z-session.sh:  `case "$resolved" in *"$NL"*) exit 0 ;; *) [ -d "$resolved" ] || exit 0 ;; esac`
  - resolve.sh:    `_resolve_zoxide: zoxide query "$1"` (NO -- guard yet; P1.M1.T1.S2 owns it).
  These cases pass with the resolver in EITHER state (see Goal box + research_notes.md §0).

DEPENDENCIES:
  - NONE hard. All four cases verified green against the CURRENT repo (no -- guard). The
    defence-in-depth caller guards (P1.M1.T2.S1/S2, Complete) carry the assertion; the resolver
    -- guard (P1.M1.T1.S2) is a soft, non-blocking prerequisite that only changes WHICH internal
    path produces the safe outcome (empty vs dump-rejected).
```

## Validation Loop

### Level 0: Baseline (run BEFORE editing — proves a clean start and confirms the not-blocked claim)

```bash
cd <repo>
sh tests/test_z_window.sh   # Expected: RESULTS: pass=11 fail=0
sh tests/test_z_session.sh  # Expected: RESULTS: pass=9 fail=0
# (These pass even though resolve.sh has NO -- guard right now — the caller guards do the work.)
```
Expected: 11/0 and 9/0. If red, STOP — fix the baseline first.

### Level 1: Syntax (after the edits)

```bash
cd <repo>
sh -n tests/test_z_window.sh  && echo "window syntax ok"
sh -n tests/test_z_session.sh && echo "session syntax ok"
# Optional (tests are POSIX sh; ShellCheck is informational here, not a gate):
shellcheck tests/test_z_window.sh tests/test_z_session.sh || true
```
Expected: both "syntax ok". (ShellCheck may emit SC1091/SC2086-style notes on the heredoc fakes
and unquoted expansions inside the test harness; these are pre-existing patterns in every test
file and are NOT introduced by this task. The gate is `sh -n` + the tests passing.)

### Level 2: Targeted edit verification (the fakes + cases are exactly what was intended)

```bash
cd <repo>
echo "window fake has multiline arm (expect 1):"
grep -c 'multiline) printf' tests/test_z_window.sh
echo "window CASE 5 + CASE 6 present (expect 1 each):"
grep -c "CASE 5: query '-l'" tests/test_z_window.sh
grep -c 'CASE 6: multi-line resolved value' tests/test_z_window.sh

echo "session fake has multiline arm (expect 1):"
grep -c 'multiline)   printf' tests/test_z_session.sh
echo "session CASE 11 + CASE 12 present (expect 1 each):"
grep -c "CASE 11: session named '-l'" tests/test_z_session.sh
grep -c 'CASE 12: multi-line resolved value' tests/test_z_session.sh

echo "session uses the rename trick (expect >=1):"
grep -c 'rename-session -t tmpl -- -l' tests/test_z_session.sh
```
Expected: `1`, `1`, `1`, `1`, `1`, `1`, `1`, `>=1`.

### Level 3: The two test files (the gate)

```bash
cd <repo>
sh tests/test_z_window.sh   # Expected: RESULTS: pass=17 fail=0   (floor >=15)
sh tests/test_z_session.sh  # Expected: RESULTS: pass=13 fail=0   (floor >=12)
```
Expected: 17/0 and 13/0, exit 0. If a new case FAILs, the most likely causes (in order):
1. Window case asserts the wrong CUR — you forgot to re-capture `CUR=$(tmux display-message -p
   '#{pane_current_path}')` immediately before `run_case` (the active window shifts per case).
2. Session `-l` case — you tried `new-session -s -l` (fails) instead of the rename trick, or you
   queried with `-t -- -l` (target=--) instead of `cwd_of -l` (-> `-t -l`).
3. The `multiline)` arm was added to the LIST-MODE block or collapsed the if/else — re-check it is
   in the POSITIONAL case only and `$FIX` is literal.

### Level 4: Full suite (no regression to the other 7 files)

```bash
cd <repo>
total_pass=0; total_fail=0
for t in tests/test_*.sh; do
  line=$(sh "$t" 2>&1 | grep -E '^RESULTS:')
  p=$(echo "$line" | sed -n 's/.*pass=\([0-9]*\).*/\1/p')
  f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')
  [ -n "$p" ] && total_pass=$((total_pass+p)); [ -n "$f" ] && total_fail=$((total_fail+f))
  echo "$(basename "$t"): $line"
done
echo "TOTAL: pass=$total_pass fail=$total_fail"
```
Expected: every file `fail=0`; TOTAL `pass=90 fail=0` (was 80; +6 window, +4 session). All 9 exit 0.

### Level 5: Defence-in-depth proof (throwaway — proves the four cases mean what they say)

This reproduces each case's reasoning against the CURRENT repo WITHOUT relying on the test
harness, so you can see WHY each assertion holds. (Do NOT save this as a committed test.)

```bash
cd <repo>
# (1) The fake returns a MULTI-LINE value for `multiline`, and empty/dump for -l per the guard:
FIX=$(mktemp -d); mkdir -p "$FIX/proj"; TBIN="$FIX/.tbin"; mkdir -p "$TBIN"
cat > "$TBIN/zoxide" <<ZOX
#!/bin/sh
[ "\$1" = "query" ] || exit 0
shift
if [ "\$1" = "--" ]; then shift
else
  case "\$1" in -l|--list) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;; esac
fi
case "\$1" in
  proj)      printf '%s\n' "$FIX/proj"; exit 0 ;;
  multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;
  *)         printf ''; exit 0 ;;
esac
ZOX
chmod +x "$TBIN/zoxide"
echo "query multiline -> line count (expect 3):"; "$TBIN/zoxide" query multiline | wc -l | tr -d ' '
echo "query -l        -> line count (expect 3, list-mode, NO -- in resolver):"; "$TBIN/zoxide" query -l | wc -l | tr -d ' '
echo "query -- -l     -> line count (expect 0, the S2 fix path):";            "$TBIN/zoxide" query -- -l | wc -l | tr -d ' '
# (2) The caller guard rejects a multi-line value regardless of the resolver path:
NL='
'
guard_accepts() { case "$1" in *"$NL"*) echo no ;; *) [ -d "$1" ] && echo yes || echo no ;; esac; }
DUMP="$FIX/proj
$FIX/other1
$FIX/other2"
echo "guard accepts multiline dump? (expect no): $(guard_accepts "$DUMP")"
echo "guard accepts empty?         (expect no): $(guard_accepts "")"
echo "guard accepts real single dir? (expect yes): $(guard_accepts "$FIX/proj")"
rm -rf "$FIX"
```
Expected: `3`, `3`, `0`, then `no`, `no`, `yes`. This shows: the fake models list-mode (`-l`→3),
the `--` path returns empty (the P1.M1.T1.S2 intended flow), and the caller guard rejects any
multi-line value — which is why all four integration cases pass with or without the resolver fix.

## Final Validation Checklist

### Technical Validation
- [ ] Level 0 baseline was 11/0 and 9/0 (clean; confirms the not-blocked claim).
- [ ] `sh -n` ok on both edited files.
- [ ] Level 2 grep checks: `1`,`1`,`1`,`1`,`1`,`1`,`1`,`>=1`.
- [ ] `sh tests/test_z_window.sh` → pass=17 fail=0 (exit 0).
- [ ] `sh tests/test_z_session.sh` → pass=13 fail=0 (exit 0).
- [ ] Full suite TOTAL pass=90 fail=0; all 9 files exit 0.

### Feature Validation
- [ ] Window CASE 5 (`-l`): exactly 1 window, NAME=basename(cur), START_PATH=cur.
- [ ] Window CASE 6 (`multiline`): exactly 1 window, NAME=basename(cur), START_PATH=cur (guard).
- [ ] Session CASE 11 (`-l`): pane stays at `$FIX/home` after `$ZSESS -l`.
- [ ] Session CASE 12 (`multiline`): pane stays at `$FIX/home` after `$ZSESS multiline`.
- [ ] The `-l` cases document the leading-dash repro; the `multiline` cases isolate the caller guard.

### Code Quality Validation
- [ ] Reuses existing helpers verbatim (`run_case`/`new_name`/`new_start`, `boot`/`cwd_of`).
- [ ] New `multiline)` arm uses literal `$FIX` (quoted heredoc) and sits in the positional case only.
- [ ] No existing case/assertion/fake-token altered.
- [ ] No source file touched; no forbidden file touched (resolve.sh, z-*.sh, run file, README,
      .gitignore, PRD.md, tasks.json, snapshots, unit tests).

### Documentation & Deployment
- [ ] Inline comments explain the non-obvious bits: why `multiline` is a separate token (independent
      of the `--` fix); why the `-l` session needs the rename trick; why `cwd_of -l` targets correctly.
- [ ] No README change (test-only; docs sync is P1.M3.T1).

---

## Anti-Patterns to Avoid

- ❌ Don't create the `-l` session with `new-session -s -l` / `-s=-l` / `--session-name=-l` — all
  fail or mis-name. Use the **rename trick**: `new-session -s tmpl` then `rename-session -t tmpl -- -l`.
- ❌ Don't target the `-l` session with `-t -- -l` (target becomes `--`) or `-t=-l` (empty). Use
  `-t -l` — which is what `cwd_of -l` and `z-session.sh`'s own `display-message -t "$name"` produce.
- ❌ Don't forget to **re-capture CUR** before each window fallback case — the active window shifts
  after every `run_case`, so a stale CUR makes the NAME/START_PATH checks fail spuriously.
- ❌ Don't add the `multiline)` arm to the LIST-MODE block, or collapse the fake's `if/else` into a
  single `case` — that breaks R2 (`query -- -l` would re-enter list-mode). Positional case ONLY.
- ❌ Don't write the dump with expanded absolute paths — the heredoc is quoted (`<<'ZOX`), so `$FIX`
  must stay literal and expand at runtime via `export FIX` (mirror the existing `proj)` arm).
- ❌ Don't edit `scripts/lib/resolve.sh` to "make `-l` return empty" — that's P1.M1.T1.S2's job, and
  these integration assertions don't need it anyway (the caller guards carry the safety).
- ❌ Don't weaken the assertions to "pass without the guard" — they ALREADY pass with or without it;
  weakening them would destroy the regression's meaning.
- ❌ Don't add the unit-test assertions (P1.M1.T3.S1) here — they're a separate (currently-halted)
  item that DOES require the `--` guard.
- ❌ Don't renumber/touch existing cases; append only.
- ❌ Don't edit before confirming the 11/0 + 9/0 baseline (Level 0).

---

## Scope Boundaries (explicit)

| Concern | This subtask (P1.M1.T3.S2) | Other subtasks |
| --- | --- | --- |
| `tests/test_z_window.sh` `-l` + multi-line cases + fake arm | ✅ MODIFY | — |
| `tests/test_z_session.sh` `-l` + multi-line cases + fake arm | ✅ MODIFY | — |
| Unit-test `-l`/`--list` assertions (resolve_zoxide/dispatcher) | ❌ DO NOT | P1.M1.T3.S1 |
| fake-zoxide fixture hardening (strip `--`, list-mode) | ❌ DO NOT (already Complete) | P1.M1.T1.S1 |
| `scripts/lib/resolve.sh` `--` guard | ❌ DO NOT (not required by these cases) | P1.M1.T1.S2 |
| `scripts/z-window.sh` / `z-session.sh` caller guards | ❌ DO NOT (already Complete) | P1.M1.T2.S1/S2 |
| `tmux-zoxide-sessions.tmux` `%%` quoting (Issue 2) | ❌ DO NOT | P1.M2.T1 |
| `README.md`, `.gitignore`, `PRD.md`, `tasks.json` | ❌ FORBIDDEN / other tasks | P1.M3 / orchestrator |

---

**Confidence Score: 9.5/10** — All four new cases were verified GREEN against the CURRENT repo
(no resolver `--` guard), eliminating the prerequisite risk that halted the sibling unit task.
The two non-obvious tmux traps (leading-dash session creation → rename trick; leading-dash
targeting → `-t -l`) are solved and proven, with the wrong forms enumerated so they aren't
repeated. The exact fake-arm insert and the paste-ready case blocks are given verbatim, reusing
the files' existing helpers unchanged. Assertion counts (17 / 13) clear the contract floors
(>=15 / >=12) with margin, and the full suite rises cleanly 80 → 90. The residual 0.5 is the
usual editor risk (collapsing the quoted-heredoc literal `$FIX`, or mis-placing the `multiline)`
arm) — mitigated by the gotchas, the Level-2 grep checks, and the Level-5 proof.
