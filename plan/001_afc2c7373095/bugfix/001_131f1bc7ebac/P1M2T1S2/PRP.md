# PRP — P1.M2.T1.S2 (bugfix): add the single-quote query regression test

## Goal

**Feature Goal**: Lock in the Issue-2 fix (PRD `h2.3`/`h3.1`: a single quote in a
window-jump query breaks resolution) at the **integration** level by adding a
committed regression case — actually two complementary cases — to
`tests/test_z_window.sh` that prove a query containing `'` (the `o'brien` repro)
is delivered intact to `scripts/z-window.sh` as `$1` and resolves to the correct
directory (window named `obrien`, started in `$FIX/obrien`). This closes the
"quote/special-character inputs are not [covered]" gap called out in PRD `h2.4`.

**Deliverable**: Edits to **one** test file only — `tests/test_z_window.sh`.
Three surgical changes: (1) create the real fixture dir `$FIX/obrien`; (2) add an
`"o'brien")` arm to the hardened fake-zoxide heredoc returning `$FIX/obrien`;
(3) append **CASE 7** (direct invocation — the contract's primary Approach A) and
**CASE 8** (run-shell dispatch — the contract's Approach-A dispatch variant). No
source changes, no new files.

**Success Definition**:
- `sh tests/test_z_window.sh` → `RESULTS: pass=23 fail=0` (was 17), exit 0.
- The full suite stays green: all 9 files exit 0 (aggregate 92 → **98 PASS / 0 FAIL**).
- CASE 7 + CASE 8 each assert the user-visible outcome: a query containing `'`
  opens exactly one window named `obrien` in `$FIX/obrien` (not the current dir).
- No source file, existing fake-token contract, or existing assertion altered.

> **Not blocked by P1.M2.T1.S1, and independent of its fix variant.** Both new
> cases **bypass the `%%` binding** (CASE 7 calls `z-window.sh` directly; CASE 8
> drives `run-shell` with a hand-built argument), so they pass whether S1 ships
> Fix A (`\"%%\"` inside `'…'`) or Fix A-alt (outer double quotes — the variant
> S1's own `verification_notes.md` §0 shows is the working one). See §"Why".

## User Persona

**Target User**: The implementing AI agent (2-point, test-only task). Downstream:
the bugfix-release validation (the new cases are the committed proof that an
apostrophe query resolves); P1.M3.T1 (README) references test counts.

**Use Case**: A developer runs `sh tests/test_z_window.sh` after any future change
to the resolver, the handler, or the binding, and is immediately alerted if an
apostrophe query ever again fails to resolve.

**Pain Points Addressed**: The original bug was invisible to the suite because the
fake-zoxide had no apostrophe token and no case asserted one. These cases complete
the loop by asserting the safe end-to-end behaviour for a query containing `'`.

## Why

- This is the **regression layer** of the Issue-2 fix
  (`architecture/research_issue2_quoting.md` §"Recommended fix A" + §"Verification
  commands"; PRD `h2.3`/`h3.1`). The binding-level fix is P1.M2.T1.S1 (+ its
  `test_run_file.sh` C3/C4 structural check); this task proves the *behaviour*
  survives end-to-end and prevents silent reversion.
- **Reliability over faithfulness (the contract's explicit choice).** The item
  contract (#3) offers Approach A (direct `$ZWIN "o'brien"`) and Approach B
  (`source-file` of the binding's emitted line) and says **"Use Approach A for
  reliability."** Approach A bypasses tmux's `%%` lexer entirely, so it cannot
  flake on tmux's version-dependent display re-quoting; Approach B is more
  faithful to the binding but brittle and binding-form-dependent. This PRP ships
  **both Approach-A forms the contract lists** — direct (CASE 7) and run-shell
  dispatch (CASE 8) — giving two reliable layers of coverage.
- The two case classes are **complementary**:
  - **CASE 7 (direct `$ZWIN "o'brien"`)** — proves `z-window.sh` + `resolve.sh` +
    the fake zoxide deliver and resolve an apostrophe query as `$1` (the handler
    layer). This is exactly the contract's specified assertion (a)(b)(c).
  - **CASE 8 (`run-shell "$ZWIN \"o'brien\""`)** — proves the **tmux `run-shell`
    → `sh -c`** quoting layer (the layer the binding fix protects) delivers the
    apostrophe intact. Closer to the production dispatch path; still reliable.
- **No hard dependency on the sibling binding fix.** P1.M2.T1.S1 is "Implementing"
  and its own research found the contract's Fix A broken (Fix A-alt needed).
  Because both new cases bypass the binding, this task can be implemented and
  validated before or after S1 lands, with no risk of a false failure.

## What

User-visible behaviour: **none** (test-only). What changes is the test file's
assertion count (17 → 23) and the fake-zoxide's token table (+1 `o'brien` arm).

### Success Criteria

- [ ] `sh tests/test_z_window.sh` prints `RESULTS: pass=23 fail=0` and exits 0.
- [ ] `tests/test_z_window.sh` creates a real `$FIX/obrien` dir (added to `mkdir -p`).
- [ ] The fake-zoxide positional `case` has an `"o'brien")` arm returning `$FIX/obrien`.
- [ ] **CASE 7** asserts: `run_case "o'brien"` → exactly 1 new window, NAME = `obrien`,
      START_PATH = `$FIX/obrien`.
- [ ] **CASE 8** asserts: `run-shell "$ZWIN \"o'brien\""` → exactly 1 new window,
      NAME = `obrien`, START_PATH = `$FIX/obrien`.
- [ ] No existing case/assertion/fake-token changed; full suite 9/9 exit 0.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to
implement this successfully?_ **Yes.** The exact current bytes (the `oldText`
anchors), the exact paste-ready new lines (validated green), the one non-obvious
trap (apostrophe must be BARE inside double quotes — `\'` inserts a literal
backslash and breaks the match), the helper signatures reused verbatim, the
verified assertion count (23), and the runnable validation commands are all below.
The single most likely failure — escaping the apostrophe — is proven by an
empirical before/after table in `research/verification_notes.md` §1.

### Documentation & References

```yaml
# MUST READ
- file: tests/test_z_window.sh
  why: THE FILE TO MODIFY. Contains the hardened fake (P1.M1.T1.S1) + the
       run_case/new_name/new_start helpers the new cases reuse. Baseline pass=17
       (CASE 5+6 from P1.M1.T3.S2). The new cases APPEND after CASE 6.
  pattern: "Per-case: res=$(run_case <args>); delta=${res%%|*}; idx=${res##*|}; then
            check delta / new_name(idx) / new_start(idx). run_case returns '<delta>|<idx>'."
  gotcha: "Cases that assert the CURRENT dir (1/3/4/5/6) re-capture CUR before run_case.
           CASE 7/8 assert the RESOLVED dir (like CASE 2), so NO CUR re-capture is needed."

- file: PRD.md  (bug-report PRD: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/prd_snapshot.md)
  why: Authoritative statement of Issue 2 + the o'brien repro.
  section: "h2.3/h3.1 Issue 2 (single quote breaks resolution); h2.4 Testing Summary
            ('quote/special-character inputs are not [covered]' = the gap this closes)."
  critical: "The repro token is o'brien. Expected: delivered to z-window.sh as $1 and
             resolved. Actual (pre-fix): lost/truncated. This task's CASE 7/8 are the
             committed proof of the Expected behaviour."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_issue2_quoting.md
  why: The validated analysis of the two-layer quoting chain + the recommended fix + the
       exact verification approach this task implements.
  section: "§ 'Recommended fix A' (Coverage table: apostrophe ✅ fixed); § 'Verification
            commands' (probe that a quote survives to the script)."
  critical: "The contract's Approach A (direct invocation) and Approach-A dispatch variant
             are exactly the two cases this PRP ships. Approach B (source-file of the
             emitted line) is more faithful but brittle — out of scope per the contract."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_test_baseline.md
  why: §1 (invocation = `sh tests/test_*.sh`, no runner), §3 (assertion format =
       check <desc> <expected> <actual>, exact-equality, RESULTS line + final
       `[ fail -eq 0 ]`), §4 (the integration harness: real isolated
       `tmux -f /dev/null -L zxstest*`, fake tmux wrapper, fake zoxide, REAL scripts).
  section: "§4 Fake zoxide vs real zoxide (integration pattern)"
  critical: "The fake is a QUOTED heredoc (<<'ZOX') — $FIX is written LITERALLY and expands
             at RUNTIME via `export FIX`. The new o'brien arm must keep the literal `$FIX`
             style and use a DOUBLE-QUOTED case pattern (a bare o'brien) is invalid shell)."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M2T1S1/research/verification_notes.md
  why: §0–§1 prove the contract's Fix A is BROKEN and Fix A-alt is the working fix;
       §5 warns the fake-zoxide o'brien pattern must be double-quoted. Establishes that
       THIS task's cases are independent of the binding variant (§0 here).
  critical: "Because CASE 7/8 bypass the binding, this task is NOT coupled to whether S1
             ships Fix A or Fix A-alt. Do NOT add a binding-level (Approach B) assertion."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T3S2/PRP.md
  why: The closest precedent — it added CASE 5 (-l) + CASE 6 (multiline) to this same
       file using the same run_case/new_name/new_start helpers and fake-arm pattern.
  critical: "Mirror its style: APPEND cases (no renumbering); insert the fake arm in the
             POSITIONAL case block only; create any new resolved dir as a REAL fixture."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M2T1S2/research/verification_notes.md
  why: Empirical proof every new line passes (pass=23, 5/5 stable, full suite 98,
       shellcheck clean), the apostrophe-escaping before/after table, and the
       negative control proving the dispatch quoting resolves obrien.
  section: "§1 (THE apostrophe-escaping trap), §3 (the two cases), §5 (results)"
  critical: "§1 is the crux: write the apostrophe BARE inside double quotes —
             `run_case \"o'brien\"` — NEVER `\"o\\'brien\"` (a literal backslash is
             inserted and the query never matches the fake)."
```

### Current Codebase tree (scope of this PRP)

```bash
tests/
  test_z_window.sh     # MODIFY: +$FIX/obrien mkdir, +"o'brien") fake arm, +CASE 7, +CASE 8
  test_*.sh            # NOT TOUCHED (incl. test_run_file.sh = P1.M2.T1.S1)
scripts/
  z-window.sh          # NOT TOUCHED (query="$*" + [ -d "$resolved" ] guard already correct)
  z-session.sh         # NOT TOUCHED
  lib/resolve.sh       # NOT TOUCHED
tmux-zoxide-sessions.tmux   # NOT TOUCHED (P1.M2.T1.S1 owns the binding)
README.md                   # NOT TOUCHED (P1.M3.T1)
```

### Desired Codebase tree with files to be modified

```bash
tests/test_z_window.sh   # +1 mkdir target, +1 fake arm, +2 cases (6 new checks: 17 -> 23)
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE apostrophe-escaping trap — the whole difficulty of this task): the query
#   must be written with a BARE ' inside double quotes. run_case "o'brien" -> z-window.sh
#   receives $1=o'brien. If you write "o\'brien" instead, POSIX sh treats \' inside double
#   quotes as a LITERAL backslash + apostrophe (backslash only escapes $ ` " \ newline),
#   so $1 becomes "o\'brien" (8 chars) which does NOT match the fake's "o'brien" pattern
#   (7 chars) -> resolve returns empty -> window falls back to cur -> C7b/C7c FAIL.
#   Empirically proven: bare ' = PASS (name=obrien); \' = FAIL (name=basename(cur)).
#   (research/verification_notes.md §1.) This applies to the CASE 7 echo header and to the
#   CASE 8 run-shell argument's embedded ' as well.

# CRITICAL (fake case pattern must be DOUBLE-QUOTED): the fake is a <<'ZOX' heredoc. The
#   new arm MUST be "o'brien") (double-quoted pattern) so the apostrophe is a literal
#   pattern character. A bare o'brien) pattern is itself invalid shell (the ' opens an
#   unterminated quote) — the same trap P1.M2.T1.S1's repro warned about (§5).

# CRITICAL ($FIX/obrien MUST be a real dir): z-window.sh's defence guard does
#   [ -d "$resolved" ] && dir="$resolved". If $FIX/obrien does not exist, the guard
#   rejects the (otherwise-correct) resolved value and the window falls back to cur,
#   corrupting C7c/C8c. Add it to the mkdir -p line (mirror the existing $FIX/proj).

# CRITICAL (quoted heredoc): the fake is <<'ZOX' (quoted). $FIX is written LITERALLY and
#   expands at RUNTIME via `export FIX`. The new arm must use literal `$FIX/obrien`
#   (NOT an expanded absolute path), exactly like the existing `proj)` arm.

# GOTCHA (no CUR re-capture for CASE 7/8): run_case makes its new window the active one,
#   so the active pane's cwd shifts after each case. Cases asserting the CURRENT dir
#   (1/3/4/5/6) re-capture CUR before run_case. CASE 7/8 assert the RESOLVED dir
#   ($FIX/obrien), which is independent of the active pane — exactly like CASE 2 — so
#   they do NOT re-capture CUR. (Adding a CUR capture is harmless but unnecessary.)

# GOTCHA (CASE 8 quoting): the run-shell argument "$ZWIN \"o'brien\"" is ONE double-quoted
#   sh word: \" -> a literal " around o'brien, and the ' is bare (literal). tmux receives
#   run-shell <ZWIN-path> "o'brien" as a single argv element; run-shell passes it to sh -c,
#   which sees <ZWIN-path> "o'brien" -> $1=o'brien. Do NOT escape the ' here either.

# GOTCHA (test flakiness is environmental): test_z_window.sh drives an isolated server on
#   socket zxstest_window. A CONCURRENT process using that socket kills the server mid-test
#   ("server exited unexpectedly"). That is NOT this change — kill stray
#   `tmux -L zxstest_window` servers and re-run. Validated 5/5 stable when run alone.

# FORBIDDEN: do NOT touch scripts/*, the run file, test_run_file.sh, README, .gitignore,
#   PRD.md, tasks.json, any prd_snapshot.md, or any other test file. Do NOT add a binding-
#   level (Approach B / source-file) assertion — that is brittle and out of scope; the
#   binding structural check is test_run_file.sh C3/C4 (P1.M2.T1.S1).
```

## Implementation Blueprint

### Data models and structure

N/A — pure POSIX `sh`. The only "model" is the assertion contract:
`check <desc> <expected> <actual>` (exact string equality), ending in
`echo "RESULTS: pass=$pass fail=$fail"` + `[ "$fail" -eq 0 ]`. The file already
defines `check`, `run_case`, `new_name`, `new_start`; the new cases reuse them
unchanged.

### Verbatim content — change 1 of 3: create the real `$FIX/obrien` fixture dir

Replace **exactly** this line (~line 28):

```sh
mkdir -p "$FIX/proj"                 # fake zoxide resolves `proj` -> here (REAL)
```

with:

```sh
mkdir -p "$FIX/proj" "$FIX/obrien"   # fake zoxide resolves proj / o'brien -> here (REAL dirs)
```

> `$FIX/obrien` must be a real directory or `z-window.sh`'s `[ -d "$resolved" ]`
> guard rejects the resolved value and the window falls back to `cur`.

### Verbatim content — change 2 of 3: add the `"o'brien")` fake arm

In the fake-zoxide **positional** `case "$1" in` block (the second case, AFTER the
`if [ "$1" = "--" ]` list-mode block), replace **exactly** this (~lines 59–61):

```sh
case "$1" in
    proj)      printf '%s\n' "$FIX/proj"; exit 0 ;;                                # MATCH (real dir)
    multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;   # MULTI-LINE (defence-in-depth probe)
    *)         printf ''; exit 0 ;;                                # no-match: empty, exit 0
esac
```

with (insert the `o'brien` arm BEFORE `multiline)`, keeping literal `$FIX`):

```sh
case "$1" in
    proj)      printf '%s\n' "$FIX/proj"; exit 0 ;;                                # MATCH (real dir)
    "o'brien") printf '%s\n' "$FIX/obrien"; exit 0 ;;                              # MATCH apostrophe query (Issue 2 regression)
    multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;   # MULTI-LINE (defence-in-depth probe)
    *)         printf ''; exit 0 ;;                                # no-match: empty, exit 0
esac
```

> The pattern **must** be the double-quoted `"o'brien"`: a bare `o'brien)` is
> invalid shell (the `'` opens an unterminated quote). This arm sits in the
> POSITIONAL case only (after the `--`/list-mode `if/else`), never in the
> list-mode block — mirroring the existing `multiline)` arm added by P1.M1.T3.S2.

### Verbatim content — change 3 of 3: append CASE 7 + CASE 8

Insert these two cases **after the CASE 6 block and BEFORE the closing
`echo ""; echo "RESULTS: pass=$pass fail=$fail"` lines** (paste verbatim — note
the **bare** apostrophe inside the double-quoted arguments):

```sh

echo "=== CASE 7: apostrophe query o'brien -> resolved dir, named obrien (Issue 2) ==="
# Single-quote regression (PRD h2.3/h3.1 Issue 2). Before the binding fix (P1.M2.T1.S1) a
# typed apostrophe closed the run-shell single-quote argument and the query was lost. This
# proves z-window.sh receives $1=o'brien intact and resolves it. Direct invocation (Approach A,
# reliable): the fake maps o'brien -> $FIX/obrien (a REAL dir). No CUR re-capture (mirrors CASE 2:
# it asserts the resolved dir, not cur). NOTE: 'o'brien' is written with a BARE apostrophe inside
# double quotes -- do NOT escape it (\' would insert a literal backslash and break the match).
res=$(run_case "o'brien"); delta=${res%%|*}; idx=${res##*|}
check "C7a exactly 1 new window"        "1"           "$delta"
check "C7b NAME = obrien"              "obrien"      "$(new_name "$idx")"
check "C7c START_PATH = resolved dir"  "$FIX/obrien" "$(new_start "$idx")"

echo "=== CASE 8: apostrophe query via run-shell dispatch -> resolved (Issue 2, production path) ==="
# Approach A dispatch variant: drive the REAL tmux run-shell with the post-%%-substitution
# argument the FIXED binding produces for o'brien (.../z-window.sh "o'brien"). Exercises tmux
# run-shell -> sh -c -> z-window.sh (the quoting layer the fix protects); independent of the
# exact binding form (we construct the quoted arg here). Same outcome as CASE 7 via dispatch.
before=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
"$REAL_TMUX" -L "$SOCK" run-shell "$ZWIN \"o'brien\""
sleep 0.4
after=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
check "C8a exactly 1 new window (dispatch)"        "1"           "$((after - before))"
check "C8b NAME = obrien (dispatch)"               "obrien"      "$(new_name "$idx")"
check "C8c START_PATH = resolved dir (dispatch)"   "$FIX/obrien" "$(new_start "$idx")"
```

> **Why two cases, not one:** the contract lists both forms of Approach A
> (`$ZWIN "o'brien"` and `$REAL_TMUX run-shell "$ZWIN \"o'brien\""`). CASE 7
> covers the handler/resolver layer; CASE 8 covers the `run-shell` → `sh -c`
> dispatch layer. Both are reliable (validated 5/5 stable) and both bypass the
> binding, so neither depends on P1.M2.T1.S1's fix variant. If a single case is
> strongly preferred, CASE 7 alone satisfies the contract's minimum; CASE 8 is
> the recommended strengthening (kept as a committed case for the extra layer).

### Implementation Tasks (ordered by dependencies)

```yaml
Task 0: BASELINE (run BEFORE editing)
  - RUN: sh tests/test_z_window.sh
    Expected: "RESULTS: pass=17 fail=0".
    IF NOT: STOP — a sibling change left the file red; get it green first or your edit is blamed.

Task 1: EDIT tests/test_z_window.sh — create $FIX/obrien (change 1)
  - FILE: tests/test_z_window.sh  (~line 28, the mkdir -p line)
  - ACTION: add "$FIX/obrien" to the mkdir -p targets (exact oldText/newText above).
  - WHY: z-window.sh's [ -d "$resolved" ] guard needs a REAL dir or it falls back to cur.
  - VERIFY: grep -n 'mkdir -p "\$FIX/proj" "\$FIX/obrien"' tests/test_z_window.sh  (expect 1 match).

Task 2: EDIT tests/test_z_window.sh — add the "o'brien") fake arm (change 2)
  - FILE: tests/test_z_window.sh  (~lines 59-61, the positional case "$1" in block)
  - ACTION: insert the "o'brien") arm BEFORE the multiline) arm (exact oldText/newText above).
  - CRITICAL: the pattern MUST be double-quoted ("o'brien")); literal $FIX; POSITIONAL case only.
  - VERIFY: grep -c '"o'\''brien") printf' tests/test_z_window.sh  (expect 1).

Task 3: EDIT tests/test_z_window.sh — append CASE 7 + CASE 8 (change 3)
  - FILE: tests/test_z_window.sh  (insert AFTER the CASE 6 block, BEFORE the RESULTS echo)
  - ACTION: paste the two case blocks verbatim. BARE apostrophe in all "o'brien" args; NEVER \'.
  - VERIFY: grep -c 'run_case "o'\''brien"' tests/test_z_window.sh  (expect 1)
            grep -c 'run-shell "\$ZWIN \\"o'\''brien\\""' tests/test_z_window.sh  (expect 1)

Task 4: VERIFY (no edits during verification — see Validation Loop).
```

### Implementation Patterns & Key Details

```sh
# (A) The fake gains ONE positional arm. It mirrors the existing `proj)` arm (single-line,
#     real dir) — the apostrophe is the only special thing, handled by the DOUBLE-QUOTED
#     pattern "o'brien". The arm returns $FIX/obrien, a dir created in the mkdir line.
#
#         "o'brien") printf '%s\n' "$FIX/obrien"; exit 0 ;;
#
# (B) Window cases reuse run_case/new_name/new_start UNCHANGED. run_case returns "<delta>|<idx>"
#     where idx is the newest (highest) window index. new_name/new_start read #{window_name} /
#     #{pane_start_path} via the REAL tmux (synchronous formats, reliable per the file header §2).
#     CASE 7/8 assert the RESOLVED dir (like CASE 2), so NO CUR re-capture is needed.
#
# (C) CASE 8 (dispatch) constructs the run-shell argument as ONE double-quoted sh word:
#         "$ZWIN \"o'brien\""
#     The test shell expands this to a single argv element <ZWIN-path> "o'brien" (\" -> literal ",
#     ' bare/literal). tmux run-shell passes it to sh -c, which parses <ZWIN-path> "o'brien" ->
#     $1=o'brien. This exercises the run-shell -> sh -c quoting layer (the layer the binding fix
#     protects) WITHOUT depending on the binding's %% wrapping (robust to Fix A / Fix A-alt).
#
# (D) Assertion counts: 17 -> 23 (C7×3 + C8×3). The full suite rises 92 -> 98 (all 9 files).
```

### Integration Points

```yaml
FAKE-ZOXIDE CONTRACT (test_z_window.sh, hardened by P1.M1.T1.S1):
  - argv form modelled: `query [--] <kw>` AND list-mode for `-l`/`--list` (no `--`).
  - NEW (this task): a `"o'brien")` positional arm returns the single real dir $FIX/obrien.
  - Existing tokens (`proj`, `multiline`, `-l`/`--list` list-mode, `--`) UNCHANGED.

PRODUCTION CODE (NOT modified by this task):
  - z-window.sh:   `query="$*"`; `resolved=$(resolve "$query")`;
                   `case "$resolved" in *"$NL"*) : ;; *) [ -d "$resolved" ] && dir="$resolved" ;; esac`
  - resolve.sh:    `_resolve_zoxide: zoxide query "$1"` (NO `--` guard; irrelevant here).
  Both cases pass with the production code as-is (the apostrophe flows query -> resolve -> zoxide).

DEPENDENCIES:
  - NONE hard. Both new cases bypass the `%%` binding, so they are independent of P1.M2.T1.S1's
    fix variant (Fix A vs Fix A-alt) and of whether S1 has landed. The only soft prerequisite is
    the existing P1.M1.T2.S1 `[ -d "$resolved" ]` guard (Complete) accepting the real $FIX/obrien.
```

## Validation Loop

### Level 0: Baseline (run BEFORE editing — proves a clean start)

```bash
cd <repo>
sh tests/test_z_window.sh   # Expected: RESULTS: pass=17 fail=0
```
Expected: 17/0. If red, STOP — fix the baseline first.

### Level 1: Syntax (after the edits)

```bash
cd <repo>
sh -n tests/test_z_window.sh && echo "window syntax ok"
shellcheck tests/test_z_window.sh; echo "shellcheck exit=$?"
```
Expected: "window syntax ok"; shellcheck exit 0 with **no output** (the file is clean —
no SC1091, no notes; validated). (ShellCheck is informational here, not the gate; the gate
is `sh -n` + the tests passing, matching the sibling P1.M1.T3.S2 convention.)

### Level 2: Targeted edit verification (the edits are exactly what was intended)

```bash
cd <repo>
echo "mkdir creates obrien (expect 1):"
grep -c 'mkdir -p "\$FIX/proj" "\$FIX/obrien"' tests/test_z_window.sh
echo "fake has o'brien arm (expect 1):"
grep -c "\"o'brien\") printf" tests/test_z_window.sh
echo "CASE 7 direct invocation (expect 1):"
grep -c 'run_case "o'\''brien"' tests/test_z_window.sh
echo "CASE 8 run-shell dispatch (expect 1):"
grep -c 'run-shell "\$ZWIN \\"o'\''brien\\""' tests/test_z_window.sh
echo "NO stray backslash-escaped apostrophe in invocations (expect 0):"
grep -c 'run_case "o..brien"\|run-shell.*o..brien' tests/test_z_window.sh | head -1   # eyeball for \'
```
Expected: `1`, `1`, `1`, `1`, then visually confirm no `\'` appears in any `o'brien`
invocation (the last grep is a human eyeball check — the apostrophe must be bare).

### Level 3: The test file (the gate)

```bash
cd <repo>
sh tests/test_z_window.sh   # Expected: RESULTS: pass=23 fail=0
```
Expected: 23/0, exit 0. If a new case FAILs, the most likely causes (in order):
1. **You escaped the apostrophe** — wrote `run_case "o\'brien"` (or `"o\'brien"` in the
   echo header / CASE 8 arg). The `\'` inserts a literal backslash; the query becomes
   `o\'brien` and never matches the fake. FIX: use a BARE `'` inside the double quotes.
2. **You forgot `mkdir -p "$FIX/obrien"`** — the `[ -d "$resolved" ]` guard rejects the
   resolved value and the window falls back to `cur` (C7c/C8c show `$FIX/proj` not
   `$FIX/obrien`). FIX: add `"$FIX/obrien"` to the mkdir line.
3. **The fake arm is not double-quoted** (`o'brien)` instead of `"o'brien")`) — invalid
   shell; `sh -n` would have caught it, but double-check. FIX: double-quote the pattern.
4. "server exited unexpectedly" — a CONCURRENT process on socket `zxstest_window` killed
   the server; NOT this change. Kill stray `tmux -L zxstest_window` servers and re-run.

### Level 4: Full suite (no regression to the other 8 files)

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
Expected: every file `fail=0`; TOTAL `pass=98 fail=0` (was 92; +6 from CASE 7+8). All 9 exit 0.

### Level 5: Stability + negative control (throwaway — proves the cases mean what they say)

```bash
cd <repo>
# (a) Stability: run 5x, expect pass=23 fail=0 every time (rules out the shared-socket flake).
for i in 1 2 3 4 5; do sh tests/test_z_window.sh 2>&1 | grep '^RESULTS:' | sed "s/^/run$i: /"; done
# (b) Negative control: the FIXED (double-quoted) dispatch resolves obrien. (The old unquoted
#     form would lose/truncate the query at the sh -c layer — that is the bug this guards.)
#     See research/verification_notes.md §3 for the exact throwaway script; expect name=[obrien].
```
Expected: 5 lines all `pass=23 fail=0`; negative control prints `name=[obrien]`.

## Final Validation Checklist

### Technical Validation
- [ ] Level 0 baseline was 17/0 (clean).
- [ ] `sh -n tests/test_z_window.sh` ok.
- [ ] `shellcheck tests/test_z_window.sh` exit 0, no output.
- [ ] Level 2 grep checks: `1`,`1`,`1`,`1`; no `\'` in any `o'brien` invocation.
- [ ] `sh tests/test_z_window.sh` → pass=23 fail=0 (exit 0).
- [ ] Full suite TOTAL pass=98 fail=0; all 9 files exit 0.

### Feature Validation
- [ ] CASE 7 (direct `o'brien`): exactly 1 window, NAME=obrien, START_PATH=$FIX/obrien.
- [ ] CASE 8 (run-shell dispatch `o'brien`): exactly 1 window, NAME=obrien, START_PATH=$FIX/obrien.
- [ ] `$FIX/obrien` is created as a real dir; the fake `"o'brien")` arm returns it.
- [ ] The apostrophe is delivered intact to z-window.sh as `$1` and resolves (the Issue-2 Expected behaviour).

### Code Quality Validation
- [ ] Reuses existing helpers verbatim (`run_case`/`new_name`/`new_start`).
- [ ] New `"o'brien")` arm uses literal `$FIX` (quoted heredoc), is double-quoted, sits in the positional case only.
- [ ] Apostrophe is BARE inside double quotes everywhere (no `\'`).
- [ ] No existing case/assertion/fake-token altered; cases appended only (no renumbering).
- [ ] No source file touched; no forbidden file touched (z-*.sh, resolve.sh, run file, test_run_file.sh, README, .gitignore, PRD.md, tasks.json, snapshots).

### Documentation & Deployment
- [ ] Inline comments explain the non-obvious bits: why the apostrophe must be bare (the `\'` trap);
      why no CUR re-capture (asserts resolved dir, like CASE 2); why CASE 8 is independent of the binding form.
- [ ] No README change (test-only; docs sync is P1.M3.T1).

---

## Anti-Patterns to Avoid

- ❌ Don't **escape the apostrophe** — `run_case "o\'brien"` inserts a literal backslash; the
  query becomes `o\'brien` and never matches the fake (C7b/C7c fail with NAME=basename(cur)).
  Use a BARE `'` inside the double quotes: `run_case "o'brien"`. (Same for the CASE 7 echo
  header and the CASE 8 `run-shell` argument's embedded `'`.) This is THE trap of this task.
- ❌ Don't write the fake arm as a **bare `o'brien)`** pattern — the `'` opens an unterminated
  quote (invalid shell; `sh -n` fails). Use the **double-quoted** `"o'brien")` pattern.
- ❌ Don't **forget `mkdir -p "$FIX/obrien"`** — `z-window.sh`'s `[ -d "$resolved" ]` guard
  rejects a non-existent dir and falls back to `cur`, corrupting C7c/C8c.
- ❌ Don't add the `"o'brien")` arm to the **list-mode** block or collapse the fake's `if/else`
  into a single `case` (breaks the `--`/list-mode ordering). **Positional case only** (after the
  `if/else`), mirroring the existing `multiline)` arm.
- ❌ Don't write the dump/resolved value with an **expanded absolute path** — the heredoc is
  quoted (`<<'ZOX'`), so `$FIX` must stay literal and expand at runtime via `export FIX`.
- ❌ Don't add a **CUR re-capture** to CASE 7/8 — they assert the resolved dir (like CASE 2),
  not `cur`. (Harmless if added, but unnecessary and misleading.)
- ❌ Don't add a **binding-level (Approach B / `source-file`)** assertion — it is brittle,
  binding-form-dependent, and out of scope per the contract's "Use Approach A for reliability."
  The binding structural check is `test_run_file.sh` C3/C4 (P1.M2.T1.S1).
- ❌ Don't touch `test_run_file.sh`, `scripts/*`, the run file, README, `.gitignore`, `PRD.md`,
  `tasks.json`, or any other test file.
- ❌ Don't conclude the change is broken if the suite reports **"server exited unexpectedly"** —
  that is a concurrent process on the `zxstest_window` socket killing the server mid-test, not
  this change. Kill stray `tmux -L zxstest_window` servers and re-run (validated 5/5 stable alone).
- ❌ Don't edit before confirming the **17/0 baseline** (Level 0).

---

## Scope Boundaries (explicit)

| Concern | This subtask (P1.M2.T1.S2) | Other subtasks |
| --- | --- | --- |
| `tests/test_z_window.sh` `o'brien` fake arm + `$FIX/obrien` + CASE 7 + CASE 8 | ✅ MODIFY | — |
| `tmux-zoxide-sessions.tmux` binding `%%` quoting (Issue 2 fix) | ❌ DO NOT | P1.M2.T1.S1 |
| `tests/test_run_file.sh` C3/C4 binding assertions | ❌ DO NOT | P1.M2.T1.S1 |
| binding-level (Approach B / `source-file`) behavioural test | ❌ DO NOT (brittle, out of scope) | n/a (optional future) |
| `scripts/z-window.sh` / `z-session.sh` / `lib/resolve.sh` | ❌ DO NOT (already correct) | P1.M2.T1.S1 / P1.M1 |
| `README.md`, `.gitignore`, `PRD.md`, `tasks.json` | ❌ FORBIDDEN / other tasks | P1.M3 / orchestrator |

---

**Confidence Score: 9.5/10** — Both cases were verified GREEN in an isolated mirror
(`pass=23 fail=0`, 5/5 stable; full suite `pass=98 fail=0`; `shellcheck` exit 0). The
single non-obvious trap — **escaping the apostrophe** (`\'` inserts a literal backslash
and breaks the fake match) — was hit during validation, root-caused (POSIX sh: backslash
before `'` inside double quotes is literal), and fixed with the bare-`'` form, with an
empirical before/after table in `research/verification_notes.md` §1. The exact `oldText`
anchors, the paste-ready new lines, the fake-arm double-quoting requirement, and the
real-dir prerequisite (`$FIX/obrien`) are all specified verbatim. Crucially, both cases
**bypass the `%%` binding**, so this task is **independent of P1.M2.T1.S1's fix variant**
(Fix A vs Fix A-alt) and has **no hard ordering dependency** on the still-implementing
sibling — eliminating the largest risk. The residual 0.5 is the usual editor risk
(escaping the apostrophe, or omitting the `mkdir`) — mitigated by the gotchas, the Level-2
grep checks (including the eyeball check for `\'`), and the Level-5 stability run.
