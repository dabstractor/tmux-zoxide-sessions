name: "P1.M1.T3.S1 — Add `-l`/`--list` regression cases to unit tests"
description: Test-only task. Append 7 `check` regression assertions to two unit test files proving the resolver rejects leading-dash queries (`-l`/`--list`) to empty and the hardened fake models zoxide list-mode.

---

## Goal

**Feature Goal**: Lock the Issue-1 fix (`zoxide` flag absorption) at the unit
level by adding regression assertions that prove (a) `_resolve_zoxide` resolves
leading-dash queries `-l` and `--list` to **empty**, (b) the `auto` and `zoxide`
dispatchers return empty (never a multi-line DB dump) for `-l`, and (c) the
hardened fake zoxide models real-zoxide **list-mode** (multi-line) for a bare
`query -l`.

**Deliverable**: 3 new `check` lines appended to `tests/test_resolve_zoxide.sh`
(pass 3 → 6) and 4 new `check` lines appended to `tests/test_resolve_dispatcher.sh`
(pass 14 → 18). No source changes, no new files, no fixture/helper edits.

**Success Definition**:
- `sh tests/test_resolve_zoxide.sh`     → `RESULTS: pass=6 fail=0`, exit 0
- `sh tests/test_resolve_dispatcher.sh` → `RESULTS: pass=18 fail=0`, exit 0
- Full suite `for t in tests/test_*.sh; do sh "$t"; done` → **105 pass / 0 fail**, all exit 0
- `shellcheck` on both files unchanged (clean modulo SC1091)

## Re-planning note (read first — this is Attempt 2)

**Attempt 1 halted** at its Level-0a gate because it mandated a
**mechanism-specific** prerequisite ("`resolve.sh` must call `zoxide query -- "$1"`"),
but the code deliberately does NOT use the `--` guard. See `issue_feedback.md`
and `research/revalidation_case_guard.md` §1.

**What changed / why this attempt succeeds**: `P1.M1.T1.S2` (restore the guard)
is now **Complete** and landed as a **leading-dash `case`-rejection guard**, NOT
the `--` guard — a deliberate resolution of the T1.S2 environment conflict
(this machine's on-PATH `zoxide` is the rupa/z shim, which breaks on `--`).
This task's assertions test **behavior** (empty resolution for `-l`/`--list`),
which is satisfied by EITHER guard mechanism. All 7 assertions were
**empirically validated to pass** against the current HEAD (see
`research/revalidation_case_guard.md` §4) before this PRP was written.

**Implication for the implementer**: Do NOT grep for or require `--`. Do NOT
edit `resolve.sh`. Gate only on the *behavior* (Level 0 probe below). If that
behavioral probe passes — it does at HEAD — append the assertions and you are done.

## Why

- **Prevents recurrence of Issue 1.** Commit `b93e776` removed the resolver
  guard and the suite stayed green because **no test ever queried a leading-dash
  token**. These assertions make that class of regression visible at the unit
  level (fast, no tmux/zoxide required).
- **Documents the contract.** The `list-mode` check records *why* leading-dash
  rejection exists: a bare `query -l` dumps the entire frecency database.
- **Completes the Issue-1 test matrix.** Integration coverage (window/pane
  fallback) already landed in `P1.M1.T3.S2`; this adds the missing unit-level
  resolver/dispatcher coverage.

## What

Append exactly the assertion blocks in §"Implementation Blueprint" below to the
two named unit test files. The blocks are **verbatim, copy-paste, pre-validated**.
Do not paraphrase the descriptions, reorder arguments, or "improve" them.

### Success Criteria

- [ ] `tests/test_resolve_zoxide.sh` prints `pass=6 fail=0` (was 3; floor ≥5)
- [ ] `tests/test_resolve_dispatcher.sh` prints `pass=18 fail=0` (was 14; floor ≥17)
- [ ] Both scripts exit 0
- [ ] No other test file changes; no source files touched
- [ ] Full suite remains 105 pass / 0 fail (98 baseline + 7 new)

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed
to implement this successfully?_ **Yes.** The two edits are fully specified with
exact text anchors, the helpers they call are already defined in-file, and every
assertion's expected value is justified by a live trace in this PRP.

### Documentation & References

```yaml
# MUST READ — load into context before editing
- file: scripts/lib/resolve.sh
  why: Confirms the resolver guard mechanism this task validates.
  pattern: |
    _resolve_zoxide() {
        [ -n "$1" ] || return 0
        case "$1" in -*) return 0 ;; esac        # leading-dash REJECTION guard
        command -v zoxide >/dev/null 2>&1 && zoxide query "$1" 2>/dev/null
    }
  gotcha: |
    The guard is a `case`-rejection, NOT `zoxide query -- "$1"`. A leading-dash
    query ($1 starting with `-`) returns empty BEFORE zoxide is called. Do NOT
    grep for `--`; the assertions test the empty-resolution BEHAVIOR, which this
    guard satisfies. Editing resolve.sh is out of scope (owned by P1.M1.T1.S2,
    already Complete).

- file: tests/test_resolve_zoxide.sh
  why: Target file #1. Contains the `withfake` helper and the hardened fake zoxide.
  pattern: |
    withfake() { sh -c '. "$0"; PATH="$1:$PATH"; _resolve_zoxide "$2"' "$RESOLVE" "$TBIN" "$1"; }
    # fake zoxide: query [--] <kw>; -l/--list (no --) -> 3-line dump; -- -l -> empty
  gotcha: |
    `withfake -l` calls `_resolve_zoxide "-l"`; the case guard returns empty
    WITHOUT calling zoxide. The fake's direct `query -l` (no `--`) still dumps
    3 lines — that is the list-mode behavior the 3rd assertion pins.

- file: tests/test_resolve_dispatcher.sh
  why: Target file #2. Contains `rout`/`rexit` helpers and the hardened fake zoxide.
  pattern: |
    rout()  { sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3"' "$RESOLVE" "$1" "$TBIN" "$2"; }
    rexit() { sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3" >/dev/null 2>&1; echo $?' "$RESOLVE" "$1" "$TBIN" "$2" | tail -1; }
  gotcha: |
    `resolve()` always ends with `return 0` (CORRECTION B), so `rexit * -l` is 0
    regardless of the guard — those two checks document the exit contract. The
    `rout * -l` checks are the real regression signal (empty only with the guard).

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_test_baseline.md
  why: §3 = exact `check <desc> <expected> <actual>` helper contract; §4 = fake-vs-real classification.
  section: "§3 Assertion format" and "§4 Fake zoxide vs real zoxide"

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_issue1_defense.md
  why: §D1-§D2 = exact pre-hardening fake state and the list-mode modeling spec.
  section: "§D1 (test_resolve_zoxide.sh)" and "§D2 (test_resolve_dispatcher.sh)"
  gotcha: §A/§B/§C assume the `--` guard; SUPERSEDED for the guard mechanism by
          the case-rejection actually landed. Trust §D (fixture spec) + this PRP.

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T3S1/research/revalidation_case_guard.md
  why: Live validation that all 7 assertions PASS against current HEAD; the
       behavioral prerequisite probe; the full-suite baseline counts.
  section: "§4 Assertion validation" and "§5 Full-suite baseline"
```

### Current codebase tree (relevant subset)

```bash
scripts/
  lib/
    resolve.sh            # _resolve_zoxide (case guard), _resolve_z, resolve() dispatcher  [READ ONLY — not edited]
tests/
  test_resolve_zoxide.sh       # TARGET #1 — currently pass=3; append 3 checks -> 6
  test_resolve_dispatcher.sh   # TARGET #2 — currently pass=14; append 4 checks -> 18
  test_z_window.sh             # integration (P1.M1.T3.S2) — DO NOT TOUCH
  test_z_session.sh            # integration — DO NOT TOUCH
  test_backend_matrix.sh       # integration — DO NOT TOUCH
  (other unit tests)           # DO NOT TOUCH
```

No files are created or deleted. Only the two TARGET files are edited (appended-to).

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL: the resolver guard is a leading-dash `case` REJECTION, not `--`.
#   case "$1" in -*) return 0 ;; esac   (resolve.sh)
# `--list` matches the `-*` glob (it starts with `-`), so it is rejected too.
# Do NOT "fix" resolve.sh to use `--` — that breaks the rupa/z shim that is the
# on-PATH zoxide in this environment (see P1.M1.T1.S2/issue_feedback.md).

# CRITICAL: command substitution strips ONLY trailing newlines.
#   The list-mode check compares the fake's `query -l` output (3 lines, 2 internal
#   \n) against a `printf '%s\n' a b c` literal. Both sides keep the 2 internal
#   newlines after $(...) stripping, so exact `[ a = b ]` equality holds and
#   PROVES the value is multi-line. Do not "simplify" to a wc -l token check.

# CRITICAL: exact insertion point. Each file ends with:
#     <last check line>
#  <blank>
#     echo ""
#     echo "RESULTS: pass=$pass fail=$fail"
#     [ "$fail" -eq 0 ]
# Insert the new block AFTER the last existing `check` and BEFORE `echo ""`.

# The `withfake`/`rout`/`rexit` helpers and the hardened fakes already exist in
# both files (P1.M1.T1.S1 = Complete). Reuse them VERBATIM. Do not add helpers.
```

## Implementation Blueprint

### Data models and structure

None. This is a POSIX-shell test-only change; no types, schemas, or models.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 0: VERIFY behavioral prerequisite (do NOT skip — it is the whole point of the re-plan)
  - RUN the Level 0 probe in the Validation Loop below.
  - EXPECT: `-l` -> empty, `--list` -> empty, `proj` -> a path.
  - IF it fails (resolver does NOT reject leading-dash): STOP. File an issue.
    Do NOT edit resolve.sh (owned by P1.M1.T1.S2). Do NOT weaken assertions.
  - IF it passes (it does at HEAD): proceed to Task 1.

Task 1: APPEND 3 regression checks to tests/test_resolve_zoxide.sh
  - EDIT: replace the exact oldText anchor with newText (see "Edit #1" below).
  - RESULT: file now has 6 checks (3 existing + 3 new).
  - DEPENDENCIES: the `withfake` helper and the hardened `$TBIN/zoxide` fake
    already present in the file (lines defining `withfake` and the `ZOXIDE` heredoc).

Task 2: APPEND 4 regression checks to tests/test_resolve_dispatcher.sh
  - EDIT: replace the exact oldText anchor with newText (see "Edit #2" below).
  - RESULT: file now has 18 checks (14 existing + 4 new).
  - DEPENDENCIES: the `rout`/`rexit` helpers and the hardened `$TBIN/zoxide` fake
    already present in the file.

Task 3: VALIDATE (run Validation Loop Levels 0-3). No further edits expected.
```

#### Edit #1 — `tests/test_resolve_zoxide.sh`

oldText (exact, unique in file):
```sh
check "missing-binary echoes empty"  ""                          "$(without proj)"

echo ""
```

newText:
```sh
check "missing-binary echoes empty"  ""                          "$(without proj)"

# --- leading-dash regression (Issue 1: zoxide flag absorption) --------------
# The resolver rejects leading-dash queries (case "$1" in -*) before zoxide is
# invoked, so -l / --list resolve to empty and can never trigger list-mode.
check "leading-dash -l resolves to empty"     ""  "$(withfake -l)"
check "leading-dash --list resolves to empty" ""  "$(withfake --list)"
# Document WHY leading-dash rejection is required: WITHOUT it, real zoxide (and
# this hardened fake) enter list-mode for `query -l` and dump a MULTI-LINE DB.
# (Direct fake invocation; the resolver is not in this path.)
check "fake models list-mode: query -l -> multi-line dump" \
    "$(printf '%s\n' "/home/user/projects/proj" "/home/user/projects/other1" "/home/user/projects/other2")" \
    "$("$TBIN/zoxide" query -l)"

echo ""
```

#### Edit #2 — `tests/test_resolve_dispatcher.sh`

oldText (exact, unique in file):
```sh
check "exit 0: auto no-match"     "0" "$(rexit auto zzz)"

echo ""
```

newText:
```sh
check "exit 0: auto no-match"     "0" "$(rexit auto zzz)"

# --- leading-dash regression (Issue 1): the auto/zoxide dispatchers must
# resolve -l to empty (NOT a multi-line DB dump) because the resolver rejects
# leading-dash queries before they ever reach zoxide. ----------------------
check "zoxide: -l resolves empty" "" "$(rout zoxide -l)"
check "exit 0: zoxide -l"         "0" "$(rexit zoxide -l)"
check "auto: -l resolves empty"   "" "$(rout auto -l)"
check "exit 0: auto -l"           "0" "$(rexit auto -l)"

echo ""
```

### Implementation Patterns & Key Details

```sh
# Pattern: every assertion uses the in-file `check <desc> <expected> <actual>`
# helper (exact string equality; PASS/FAIL + RESULTS line + final [ fail -eq 0 ]).
# Copied verbatim from research_test_baseline.md §3.

# Why `withfake -l` returns empty (trace, current resolver):
#   withfake -l  ->  sh -c '. resolve.sh; PATH=$TBIN:$PATH; _resolve_zoxide "-l"'
#   _resolve_zoxide "-l":  [ -n "-l" ] && case "-l" in -*) return 0  -> EMPTY
#   (zoxide is never called; the case guard short-circuits.)

# Why the list-mode check is MULTI-LINE and still passes exact equality:
#   $TBIN/zoxide query -l   (no `--`) -> the fake's `-l|--list` arm prints 3 lines:
#       /home/user/projects/proj\n/home/user/projects/other1\n/home/user/projects/other2\n
#   $(...) strips the single TRAILING newline -> 2 internal newlines remain.
#   The expected side is the SAME printf literal -> identical 2-internal-newline string.
#   POSIX [ "$2" = "$3" ] compares full strings incl. embedded newlines -> EQUAL -> PASS.
#   Passing therefore proves the value is multi-line AND non-empty.

# Why `rout auto -l` returns empty (trace, current resolver):
#   resolve "-l" backend=auto:
#     _r=$(_resolve_zoxide "-l")   -> EMPTY (case guard)
#     [ -z "$_r" ] && _r=$(_resolve_z "-l")
#       _resolve_z: z.sh fixture _z "-l" -> case *) no-op -> cwd unchanged -> empty
#     printf '%s\n' ""             -> single newline -> $(...) -> ""
#   So `auto` does NOT short-circuit on a dump (the Issue-1 bug); it correctly
#   falls through and resolves empty.
```

### Integration Points

```yaml
DATABASE: none
CONFIG:   none
ROUTES:   none
# This task touches ONLY the two named test files. No production code, no other
# tests, no docs (P1.M3 handles docs separately; this is a test-only change).
```

## Validation Loop

### Level 0: Behavioral prerequisite gate (mechanism-agnostic)

This is the gate that Attempt 1 got wrong (it grepped for `--`). Gate on
BEHAVIOR instead:

```sh
cd <repo>
TBIN=$(mktemp -d)
cat > "$TBIN/zoxide" <<'Z'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then shift
else case "$1" in -l|--list) printf '%s\n' a b c; exit 0;; esac; fi
case "$1" in proj) printf '%s\n' /home/user/projects/proj;; *) printf '';; esac
Z
chmod +x "$TBIN/zoxide"
fail=0
for q in -l --list; do
  out=$(sh -c '. "$0"; PATH="$1:$PATH"; _resolve_zoxide "$2"' scripts/lib/resolve.sh "$TBIN" "$q")
  [ -z "$out" ] || { echo "PREREQ FAIL: _resolve_zoxide $q -> [$out] (expected empty)"; fail=1; }
done
out=$(sh -c '. "$0"; PATH="$1:$PATH"; _resolve_zoxide "$2"' scripts/lib/resolve.sh "$TBIN" proj)
[ "$out" = "/home/user/projects/proj" ] || { echo "PREREQ FAIL: proj regression -> [$out]"; fail=1; }
rm -rf "$TBIN"
[ "$fail" -eq 0 ] && echo "PREREQ OK: resolver rejects leading-dash, proj still resolves" || exit 1
# Expected: PREREQ OK. If it fails, STOP and file an issue — do NOT edit resolve.sh.
```

### Level 1: Syntax & Style

```sh
# ShellCheck the two edited files. Expect clean modulo SC1091 (sourced resolve.sh).
shellcheck tests/test_resolve_zoxide.sh tests/test_resolve_dispatcher.sh
# (SC1091 "Not following: resolve.sh was not specified as input" is pre-existing
#  and inherent to the sourced architecture — NOT a regression. Exit 1 from
#  SC1091 info-level is normal; there must be NO warnings/errors/style notes.)
```

### Level 2: Unit Tests (the deliverable)

```sh
sh tests/test_resolve_zoxide.sh     2>&1 | tail -8   # Expected: RESULTS: pass=6 fail=0
sh tests/test_resolve_dispatcher.sh 2>&1 | tail -8   # Expected: RESULTS: pass=18 fail=0
echo "exit codes: zoxide=$(sh tests/test_resolve_zoxide.sh >/dev/null 2>&1; echo $?) dispatcher=$(sh tests/test_resolve_dispatcher.sh >/dev/null 2>&1; echo $?)"
# Expected: exit codes: zoxide=0 dispatcher=0
```

### Level 3: Full-suite non-regression

```sh
for t in tests/test_*.sh; do
  printf '%-42s ' "$t"
  sh "$t" >/tmp/_o.$$ 2>&1; rc=$?
  grep -E 'RESULTS: pass=' /tmp/_o.$$ | tail -1 | sed 's/RESULTS: //'
  [ "$rc" -eq 0 ] || echo "  !! $t exited $rc"
done
rm -f /tmp/_o.$$
# Expected (post-edit): every file exit 0; zoxide=6, dispatcher=18, others unchanged.
# Aggregate: 105 pass / 0 fail (baseline 98 + 7 new).
```

### Level 4: Domain-specific (regression intent) — manual spot check

```sh
# Prove the list-mode assertion actually exercises the absorption path: the fake
# MUST dump multi-line for a bare `query -l`, and MUST return empty for `query -- -l`.
TBIN=$(mktemp -d); ZX="$TBIN/zoxide"
# (use the real hardened fake body from tests/test_resolve_zoxide.sh)
cat > "$ZX" <<'Z'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then shift
else case "$1" in -l|--list) printf '%s\n' /home/user/projects/proj /home/user/projects/other1 /home/user/projects/other2; exit 0;; esac; fi
case "$1" in proj) printf '%s\n' /home/user/projects/proj;; *) printf '';; esac
Z
chmod +x "$ZX"
echo "query -l lines:        $("$ZX" query -l | wc -l | tr -d ' ')"   # Expected: 3 (list-mode dump)
echo "query -- -l lines:     $("$ZX" query -- -l | wc -l | tr -d ' ')" # Expected: 0 (guard works)
rm -rf "$TBIN"
```

## Final Validation Checklist

### Technical Validation

- [ ] Level 0 behavioral probe prints `PREREQ OK`
- [ ] `shellcheck tests/test_resolve_zoxide.sh tests/test_resolve_dispatcher.sh` — no new findings (SC1091 info only)
- [ ] `sh tests/test_resolve_zoxide.sh` → `pass=6 fail=0`, exit 0
- [ ] `sh tests/test_resolve_dispatcher.sh` → `pass=18 fail=0`, exit 0
- [ ] Full suite → 105 pass / 0 fail, all exit 0

### Feature Validation

- [ ] Exactly 3 new checks in `test_resolve_zoxide.sh` (total 6)
- [ ] Exactly 4 new checks in `test_resolve_dispatcher.sh` (total 18)
- [ ] No other files modified (`git diff --stat` shows only the two test files)
- [ ] `resolve.sh` untouched (`git diff scripts/lib/resolve.sh` empty)
- [ ] Level 4 spot check: fake `query -l` → 3 lines; `query -- -l` → 0 lines

### Code Quality Validation

- [ ] New assertions reuse existing `withfake`/`rout`/`rexit` helpers verbatim (no new helpers)
- [ ] Descriptions are the exact strings in this PRP (do not paraphrase)
- [ ] `check` argument order is `<desc> <expected> <actual>` in every new line
- [ ] Comments explain WHY (leading-dash rejection) without referencing the `--` guard as the active mechanism

### Documentation & Deployment

- [ ] No docs changes (test-only; `P1.M3` owns docs separately)
- [ ] No new env vars, config, or dependencies

---

## Anti-Patterns to Avoid

- ❌ **Do NOT grep for or require the `--` guard.** That mechanism-specific gate
  is exactly what halted Attempt 1. The resolver uses `case "$1" in -*) return 0`.
  Gate on behavior (Level 0 probe), not on a code string.
- ❌ **Do NOT edit `scripts/lib/resolve.sh`.** Owned by P1.M1.T1.S2 (Complete).
  Touching it crosses an ownership boundary and will be rejected.
- ❌ **Do NOT weaken the empty-resolution assertions** (e.g. asserting "non-empty"
  or removing the `-l`/`--list` cases) to accommodate a missing guard. If Level 0
  fails, the prerequisite is missing — file an issue, do not paper over it.
- ❌ **Do NOT paraphrase assertion descriptions or reorder `check` arguments.**
  The exact strings are the regression contract; copy them verbatim.
- ❌ **Do NOT replace the exact-equality list-mode check with a weaker substring
  or `wc -l` token check.** The exact-equality form is pre-validated and proves
  both multi-line AND non-empty in one assertion.
- ❌ **Do NOT touch the integration tests** (`test_z_window.sh`, `test_z_session.sh`,
  `test_backend_matrix.sh`) — those are P1.M1.T3.S2's scope (already Complete).
- ❌ **Do NOT add the `contains` substring helper** to these two files; they use
  only `check` (exact equality), matching their existing convention.
