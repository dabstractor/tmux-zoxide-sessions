# PRP — P1.M2.T1.S1 (bugfix): double-quote `%%` in the run-shell binding + update `test_run_file.sh`

## Goal

**Feature Goal**: Fix Issue 2 (a single quote in a window-jump query breaks resolution) with the minimal, low-risk **Fix A** from `architecture/research_issue2_quoting.md`: in `tmux-zoxide-sessions.tmux`, wrap the `command-prompt` `%%` token in shell **double quotes** inside the existing single-quoted `run-shell` argument, so a typed apostrophe (e.g. `o'brien`, `Mary's Project`) survives the tmux `%%` textual-substitution layer AND the `sh -c` layer and reaches `z-window.sh` as `$1`. Then update `tests/test_run_file.sh` so the binding-registration assertions (C3 **and** C4) match the new emitted form and the suite stays green.

**Deliverable**: Two **modified** files (no new files) —
1. `tmux-zoxide-sessions.tmux` — change ONE line (the window-jump binding): `%%` → `\"%%\"` (bash source; `\"` emits a literal `"` so the stored tmux template becomes `run-shell '<abspath>/scripts/z-window.sh "%%"'`).
2. `tests/test_run_file.sh` — update the C3 (default key `g`) AND C4 (custom key `Z`) assertions, which both needle the old `%%` form, to match the new binding. The robust, validated form splits each into two backslash-free substring checks (path prefix + `%%` token).

**Success Definition**:
- A window-jump query containing `'` (e.g. `o'brien`) is delivered to `z-window.sh` as `$1` and resolves (window opens in the matched dir, named after its basename). Empty query still falls back to the current dir with no parse error.
- `tmux list-keys -1 -T prefix g` shows the binding with `%%` wrapped in `"..."`.
- `shellcheck tmux-zoxide-sessions.tmux` → only `SC1091` (info, sourcing resolve.sh); `shellcheck tests/test_run_file.sh` → clean (exit 0).
- `sh tests/test_run_file.sh` → `RESULTS: pass=11 fail=0`, exit 0.
- The full existing suite stays green (9/9 tests); `z-window.sh`/`z-session.sh`/`resolve.sh`/README/options are unchanged.

## User Persona

**Target User**: The implementing AI agent (subtask executor); ultimately the end user pressing `prefix g` and typing a zoxide query that happens to contain an apostrophe (a directory like `o'brien` or `Mary's Project`).

**Use Case**: `prefix g`, type `o'brien`, Enter → a window opens in zoxide's match for `o'brien`. Today this fails (tmux `returned 2`, no window) or silently truncates the query to empty (window opens in the current dir).

**Pain Points Addressed**: The `command-prompt` `%%` substitution is **raw textual** with no escaping; the binding wraps it in single quotes, so a typed `'` closes that argument prematurely and the query is lost at the tmux layer (before any shell runs). Wrapping `%%` in double quotes makes `'` and spaces survive both quoting layers.

## Why

- This is the **direct fix for Issue 2** (`PRD`/bug-report §h2.3 "Minor Issues", reproduced verbatim in `architecture/research_issue2_quoting.md`). The shipped code faithfully reproduces a **spec-level** limitation (PRD §5.2's literal quoting); Fix A resolves it at the binding level with a one-line change and zero behavioural change for normal/space queries.
- **Minimal blast radius, preserves UX**: Fix A keeps tmux's status-line `command-prompt` (no `display-popup`, no `read </dev/tty`, no tmux-version bump). It fixes the reported cases (`'` and spaces) exactly; the only residual is `$`/`"`/`` ` ``/`\` in a query (vanishingly rare for directory-name fragments), which is explicitly out of scope and tracked in the research doc (Fix B/C).
- The binding is the **transport** of the query; the resolver (`resolve()`) and handler (`z-window.sh`'s `query="$*"`) are already correct and **must not change**. The bug is purely in how `%%` is quoted.
- **Updating the test is mandatory and subtler than it looks** (the whole non-trivial part of this subtask): `tmux list-keys` re-quotes the stored template with backslashes (`\"%%\"`), so the naïve needle from the item contract (sh-value `"%%"`, no backslash) does **not** match. The PRP specifies the validated, robust needle form and flags that **both C3 and C4** (not just C3) must be updated.

## What

User-visible behaviour:
- `prefix g` + query + Enter: the query is delivered intact to `z-window.sh` even when it contains `'` or spaces; zoxide resolves it; a window opens in the matched dir (named after its basename).
- Empty query / no-match: unchanged — window opens in the current pane's dir (the `"%%"` → `""` → empty `$1` → `query="$*"` empty → fallback).

Technical change:
- `tmux-zoxide-sessions.tmux`, binding template argument: `"run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"` → `"run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"`.
- `tests/test_run_file.sh`: C3 and C4 needles updated to match the new form.

### Success Criteria

- [ ] `tmux-zoxide-sessions.tmux` line ~18 uses `\"%%\"` (bash source) in the window-jump binding; `$CURRENT_DIR` is intact; nothing else in the file changes.
- [ ] `tmux list-keys -1 -T prefix g` (via the isolated test server) contains `run-shell '<abspath>/scripts/z-window.sh "%%"'` (i.e. `%%` is now wrapped in `"..."`).
- [ ] `tests/test_run_file.sh` C3 and C4 pass with the new binding (both updated — not just C3).
- [ ] `shellcheck tmux-zoxide-sessions.tmux` → only `SC1091`; `shellcheck tests/test_run_file.sh` → clean.
- [ ] `sh tests/test_run_file.sh` → `RESULTS: pass=11 fail=0`, exit 0; full suite stays green.
- [ ] `z-window.sh`, `z-session.sh`, `resolve.sh`, README, options, and `.gitignore`/`PRD.md` are unchanged.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The fix is one bash line, reproduced verbatim, and was `shellcheck`-verified (only SC1091) and exercised end-to-end (apostrophe query resolves; empty query falls back). The test-update is fully specified with the exact old/new bytes, and the one non-obvious trap — `list-keys` re-quotes the display with backslashes so the contract's literal `"%%"` needle does **not** match — is explained, proven by a candidate-needle probe, and resolved with a validated backslash-free form (`research/verification_notes.md` §2–§3). The second non-obvious fact — **C4 uses the same needle as C3 and must also be updated** — is called out (§4). All gates were run against a staging copy: `test_run_file.sh` 11/11, full suite 9/9 (92 assertions), o'brien repro confirms the fix.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md  (bug-report PRD: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/prd_snapshot.md)
  why: Authoritative statement of Issue 2 + the verbatim binding that causes it.
  section: "h2.3/h3.1 Issue 2 (single quote breaks resolution) — Expected vs Actual + repro; h2.4 Testing Summary (Issue 2 coverage gap)"
  critical: "The bug originates in the PRD §5.2 binding's literal quoting; Fix A amends it. The repro in h2.3/h3.1 is the acceptance test for THIS subtask's manual smoke (o'brien must resolve). h2.4 lists 'quote/special-character inputs are not [covered]' as the gap this closes (binding-level) — the full apostrophe REGRESSION TEST is the NEXT subtask (P1.M2.T1.S2); this one only fixes the binding + updates test_run_file.sh."

- file: tmux-zoxide-sessions.tmux
  why: THE FILE TO MODIFY — the window-jump binding lives here (line ~18).
  section: "--- 1. Window-jump binding ---  (the `tmux bind-key ... command-prompt ... run-shell '...z-window.sh %%'` block)"
  critical: "Change ONLY the run-shell argument string: %% -> \\\"%%\\\" (bash source; \\\" emits a literal \"). Do NOT touch the key/prompt reads, the session-hook block (PART 2), SCRIPT_DIR, or the resolve.sh source line. Keep $CURRENT_DIR intact."

- file: tests/test_run_file.sh
  why: THE TEST TO UPDATE — C3 (line ~103) and C4 (line ~111) both needle the old `%%` form and break after the fix.
  section: "CASE 1 (C1–C3, default key g) and CASE 2 (C4–C5, custom key Z) — the two `contains` calls that assert `run-shell '$REPO_ROOT/scripts/z-window.sh %%'`"
  critical: "BOTH C3 and C4 must be updated (the item contract names only C3 — C4 has the identical needle). Use the backslash-free two-substring form (path prefix + %%); see Known Gotchas for why the contract's literal `\"%%\"` needle does NOT match list-keys output."

- file: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_issue2_quoting.md
  why: The validated analysis of the two-layer quoting chain (tmux lexer + sh -c) and why Fix A is the minimal correct fix.
  section: "§ 'The exact pipeline (why it breaks)', §3d 'Double quotes instead of single quotes?', § 'Recommended fix A', § 'Verification commands'"
  critical: "%% is RAW textual substitution with NO escaping (unlike #{…} which has :q). The single-quote wrapping closes prematurely on a typed '. Fix A = wrap %% in double quotes inside the existing single quotes. Trace for o'brien: run-shell '.../z-window.sh \"o'brien\"' -> tmux lex strips outer '' -> sh -c gets .../z-window.sh \"o'brien\" -> $1=o'brien. Fix B (display-popup/read) and Fix C (session hook #{:q}) are OUT OF SCOPE."

- file: scripts/z-window.sh
  why: The handler that RECEIVES the query — confirms it tolerates the fix (query=\"$*\" recombines; empty $1 -> fallback). NOT modified.
  section: "query=\"$*\"; the `if [ -n \"$query\" ]` branch; the cur/dir/base/new-window logic"
  critical: "z-window.sh is ALREADY correct for this fix: query=\"$*\" turns the one delivered arg ($1) into the query; an empty delivered arg -> empty query -> fallback to cur. Do NOT modify z-window.sh. (Note: the P1.M1.T2 defence guards — newline-reject, directory-exists — are upstream and unaffected by quoting.)"

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M2T1S1/research/verification_notes.md
  why: Empirical proof of every gate — the list-keys backslash re-quoting, the candidate-needle probe, the validated test form, the 11/11 + 9/9 runs, the o'brien repro.
  section: "§1 the fix line + shellcheck; §2 THE list-keys backslash gotcha + candidate-needle table; §3 the recommended test form; §4 BOTH C3 and C4; §5 empirical results; §6 scope"
  critical: "§2 is the crux: list-keys DISPLAYS the stored template with backslash-escaped quotes (\\\"%%\\\"), so a needle whose VALUE is \"%%\" (no backslash) does NOT match. §3: the robust fix is two backslash-free substring checks (path prefix + %%). §4: C4 shares C3's old needle — update both."
```

### Current Codebase tree (relevant slice)

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# Files this subtask touches (MODIFY only — no new files):
tmux-zoxide-sessions.tmux     # run file; line ~18 = the window-jump binding (the fix)
tests/test_run_file.sh        # lines ~103 (C3) and ~111 (C4) = the two needles to update

# Files this subtask does NOT touch (confirm unchanged at the end):
scripts/z-window.sh           # handler; query="$*" already correct
scripts/z-session.sh          # session hook (separate feature)
scripts/lib/resolve.sh        # resolver (S1–S4 complete)
README.md                     # no doc change (Mode A)
tests/ (all other tests)      # no other test references the %% binding form

# Exact current bytes (the anchors for the edits):
$ grep -n 'z-window.sh' tmux-zoxide-sessions.tmux | grep run-shell
18:    "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
$ grep -nE 'contains "C[34]:' tests/test_run_file.sh
103:contains "C3: abs path to z-window.sh + %% kept" "$b"  "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
111:contains "C4: binding on custom key 'Z'"          "$bz" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"

# Tooling (the test is self-contained; these power it):
$ command -v shellcheck tmux sh
/usr/bin/shellcheck   # v0.11.0 — lint gate (run file: only SC1091 info expected; test: clean)
/usr/bin/tmux         # tmux 3.6b — drives the ISOLATED test server (never the live one)
/bin/sh -> bash       # dev note: dash-strictness via shellcheck, not runtime
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  tmux-zoxide-sessions.tmux  # MODIFIED — 1 line: %% -> \"%%\"  (bash source emits "...")
  tests/
    test_run_file.sh         # MODIFIED — C3 and C4 needles updated (2 lines -> 4 substring checks)
  (everything else unchanged)
```

No new files. No chmod (the run file is already executable from P1.M2.T2.S1). No deletions.

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE FIX — bash escaping in the run file): the whole run-shell argument is a
#   DOUBLE-QUOTED bash string: "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'". To put a
#   literal " around %% in the EMITTED template, the bash source must be \" (backslash-quote),
#   i.e. \"%%\". Do NOT use a bare " (shellcheck SC2140 "A"B"C"; also wrong at runtime). Do NOT
#   use \\\"%%\\\" in the run file (that would emit \"...\" with literal backslashes — wrong;
#   the run file needs exactly ONE level of bash-escaping: \"%%\").
# CRITICAL (THE TEST — list-keys re-quotes with backslashes): after the fix, `tmux list-keys -1
#   -T prefix g` DISPLAYS the binding as  run-shell '.../z-window.sh \"%%\"'  (backslash-quote),
#   because tmux re-escapes the literal " when serialising the line. So a `contains` needle whose
#   VALUE is ...sh "%%"' (NO backslash) does NOT match. The item contract's literal suggested
#   needle (sh-source \"%%\" -> value "%%") therefore FAILS. FIX: assert two backslash-free
#   substrings instead — the path prefix `run-shell '$REPO_ROOT/scripts/z-window.sh` and the
#   token `%%` — both of which appear verbatim regardless of tmux's re-quoting. (Validated 11/11.)
# CRITICAL (BOTH C3 AND C4 — not just C3): C4 (custom key Z) uses the IDENTICAL old needle as C3.
#   The fix wraps %% in "..." for BOTH the default and custom bindings, so BOTH needles break.
#   Update BOTH lines (~103 and ~111). Updating only C3 leaves C4 failing -> suite red.
# GOTCHA (the fix is correct, the residual is documented): Fix A makes ' and spaces survive
#   exactly; $/"/`/\ in a query are still sh-expanded/transformed (rare for dir names) — this is
#   the accepted, documented residual (research_issue2_quoting.md Fix A coverage table); Fix B/C
#   are out of scope. Do NOT try to "also fix" those here.
# GOTCHA (don't touch the transport targets): z-window.sh's query="$*" already turns the one
#   delivered arg into the query and falls back on empty. z-session.sh, resolve.sh, the
#   session-created hook, README, and the options are all OUT OF SCOPE. The key 'g', prompt
#   'z to:', and behaviour for normal/space queries are IDENTICAL before/after.
# GOTCHA (test flakiness is environmental, not the fix): `test_run_file.sh` drives an isolated
#   server on socket `zxstest_run`. A CONCURRENT process using the same socket (e.g. a leftover
#   flake-loop) will kill the server mid-test ("server exited unexpectedly"). If you see that,
#   it is NOT the fix — kill stray `tmux -L zxstest_run` servers / use a unique socket to confirm,
#   then re-run. The shipped test keeps `zxstest_run`.
# GOTCHA (shellcheck on the run file): expect exactly ONE finding, SC1091 (info: "Not following:
#   resolve.sh was not specified as input") for the `. "$CURRENT_DIR/scripts/lib/resolve.sh"`
#   line. This is pre-existing and expected for any sourcing script — NOT a warning/error, and
#   NOT introduced by this change. `shellcheck ... | grep -v SC1091` must print nothing.
# FORBIDDEN: Do NOT modify z-window.sh, z-session.sh, resolve.sh, README, options, .gitignore,
#   PRD.md, or any other test. Do NOT change the key, prompt, or query-handling. Do NOT add a
#   new regression test file (that is P1.M2.T1.S2) — this subtask only fixes the binding + the
#   existing test_run_file.sh assertions.
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The change is two string literals (one bash template argument, two sh test needles).

### Verbatim content — change 1 of 2: `tmux-zoxide-sessions.tmux` (the fix)

Replace **exactly** this line (window-jump binding, ~line 18):

```bash
    "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
```

with:

```bash
    "run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"
```

> The whole token is a double-quoted **bash** string. `\"` → a literal `"` at
> runtime, so the emitted/stored tmux template is
> `run-shell '<abspath>/scripts/z-window.sh "%%"'`. `$CURRENT_DIR` still expands
> (bash), `%%` is literal to bash. `shellcheck` is clean except the pre-existing
> SC1091. **Do not** also change the `key`/`prompt` reads, the session-hook
> block, `SCRIPT_DIR`, or the resolve.sh source line.

#### Why each piece is exactly so

```sh
# "run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"
#   ^ outer "..." = a single bash argument (the command-prompt template) passed to `tmux bind-key`.
#     '...'           = tmux single quotes around the run-shell argument (kept from PRD §5.2;
#                       tmux strips them and passes the inner string to sh -c).
#     $CURRENT_DIR    = expands in bash to the plugin's abs path (unchanged).
#     \"              = bash escapes to a literal " in the emitted template.
#     %%              = tmux command-prompt's first-prompt placeholder (raw textual substitution).
#     \"              = bash escapes to a literal ".
# Trace (user types o'brien): substitute -> run-shell '.../z-window.sh "o'brien"'
#   -> tmux lex strips outer '' -> shell cmd .../z-window.sh "o'brien"
#   -> sh -c: "o'brien" is one double-quoted word -> z-window.sh $1=o'brien  ✅
# Trace (empty query, Enter): substitute -> run-shell '.../z-window.sh ""'
#   -> sh -c: "" is one empty word -> z-window.sh $1="" -> query="$*"="" -> fallback to cur  ✅
```

### Verbatim content — change 2 of 2: `tests/test_run_file.sh` (C3 and C4)

Replace **exactly** this C3 line (~line 103):

```sh
contains "C3: abs path to z-window.sh + %% kept" "$b" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
```

with these two lines:

```sh
contains "C3: run-shell + abs path to z-window.sh" "$b"  "run-shell '$REPO_ROOT/scripts/z-window.sh"
contains "C3: %% substitution token kept"          "$b"  "%%"
```

And replace **exactly** this C4 line (~line 111):

```sh
contains "C4: binding on custom key 'Z'" "$bz" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
```

with these two lines:

```sh
contains "C4: run-shell + abs path to z-window.sh on 'Z'" "$bz" "run-shell '$REPO_ROOT/scripts/z-window.sh"
contains "C4: %% substitution token kept"                  "$bz" "%%"
```

> **Why two substrings, not one:** `list-keys` re-quotes the stored template with
> backslashes (`...sh \"%%\"'`), so a single needle matching the full `"%%"`
> form would need `\\\"%%\\\"` in the sh source (value `\"%%\"`) — escaping-prone
> and tied to tmux's display re-quoting. The path prefix and the `%%` token both
> appear verbatim regardless, so asserting them separately is robust and
> backslash-free. (Both forms were probed against real `list-keys` output; only
> the backslashed value or the two-substring form match — see
> `research/verification_notes.md` §2.) `shellcheck tests/test_run_file.sh` is
> clean on this form. The assertion count rises by 2 (C3→2, C4→2); the gate is
> `fail=0`, and the validated total is `pass=11`.

> Alternative (single-needle, exact displayed form — only if a single assertion
> per case is preferred): needle source
> `"run-shell '$REPO_ROOT/scripts/z-window.sh \\\"%%\\\"'"` (sh evaluates to the
> backslashed value `run-shell '...sh \"%%\"'`, which matches). More faithful to
> the original one-needle structure but triples the backslash nesting; the
> two-substring form above is recommended.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: MODIFY tmux-zoxide-sessions.tmux  (the binding — Fix A)
  - FILE: tmux-zoxide-sessions.tmux  (window-jump binding, ~line 18)
  - ACTION: replace `%%` with `\"%%\"` inside the run-shell argument (exact oldText/newText above).
  - PRESERVE: the leading `    "run-shell '` and trailing `'"` wrappers, $CURRENT_DIR, the
              key/prompt reads, SCRIPT_DIR, the resolve.sh source line, and the ENTIRE session-hook
              block (PART 2). Change ONLY the %% token's quoting.
  - VERIFY: `grep -n 'z-window.sh' tmux-zoxide-sessions.tmux | grep run-shell` shows `\"%%\"` with $CURRENT_DIR intact.

Task 2: MODIFY tests/test_run_file.sh  (update C3 AND C4 — both, not just C3)
  - FILE: tests/test_run_file.sh  (~line 103 = C3; ~line 111 = C4)
  - ACTION: replace each single old needle line with the two backslash-free substring checks above
            (path prefix `run-shell '$REPO_ROOT/scripts/z-window.sh` + token `%%`).
  - WHY TWO: list-keys re-quotes the display with backslashes; the contract's literal `\"%%\"`
             needle (sh-value `"%%"`, no backslash) does NOT match. (verification_notes §2.)
  - PRESERVE: C0, C1, C2, C5, C6, C7, C8 and all harness setup (fake tmux/zoxide, boot(), SOCK,
              trap). Only the two needle lines change.
  - VERIFY: `sh tests/test_run_file.sh` -> RESULTS: pass=11 fail=0, exit 0.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -v SC1091   # expect NO output (only SC1091 info)
  - RUN: shellcheck tests/test_run_file.sh                            # expect exit 0, no output
  - RUN: sh tests/test_run_file.sh                                    # expect RESULTS: pass=11 fail=0, exit 0
  - RUN: for t in tests/test_*.sh; do echo "== $t =="; sh "$t" 2>&1 | grep '^RESULTS'; done   # full suite green
  - RUN: git status --short   # expect ONLY tmux-zoxide-sessions.tmux + tests/test_run_file.sh modified; nothing else
  - RUN (optional manual smoke — Issue 2 repro): sh plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M2T1S1/research/verification_notes.md
        # (the repro script pattern is in verification_notes §5; adapt $STAGE to $REPO_ROOT) —
        # expect "ISSUE 2 FIXED: apostrophe query delivered intact and resolved"
```

### Implementation Patterns & Key Details

```sh
# The two-layer quoting chain (why the bug exists and why Fix A works):
#   Layer 1 = tmux command lexer: %% is RAW textual substitution (no escaping, unlike #{…}:q).
#              The binding's single quotes '...' wrap %% ; a typed ' closes them prematurely.
#   Layer 2 = sh -c: run-shell passes its (tmux-quote-stripped) argument to /bin/sh -c.
#   Fix A keeps tmux single quotes (so tmux passes the inner "..." through UNTOUCHED to sh -c)
#   and adds shell double quotes around %% (so sh -c protects ' and spaces inside "...").
#
# Why double quotes (not escaping ' -> '\''): there is NO in-template hook to rewrite the
#   user's typed text before tmux lexes the line, so '\' escaping of %% content is impossible.
#   Double-quoting %% is the only minimal change that makes ' survive both layers.
#
# Why the test must use backslash-free substrings: tmux serialises the stored template for
#   `list-keys` by re-escaping the literal " as \" -> displayed form is ...sh \"%%\"'. A fixed-
#   string `contains` needle must therefore either (a) include the backslashes (escaping-prone) or
#   (b) avoid the quotes entirely by matching the path prefix and the %% token separately. (b) is
#   robust and is what this PRP specifies.
```

### Integration Points

```yaml
FILESYSTEM:
  - modify: "tmux-zoxide-sessions.tmux   (1 line: %% -> \\\"%%\\\" in the window-jump binding)"
  - modify: "tests/test_run_file.sh      (C3 + C4 needles -> backslash-free path + %% substring checks)"

NO DATABASE / CONFIG / ROUTES / BUILD CHANGES:
  - This is a quoting fix to one binding template string + its test assertions. It changes NO
    option default (key 'g', prompt 'z to:'), NO resolver, NO handler, NO hook, NO README.
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only).

DOWNSTREAM / SIBLING SCOPE:
  - P1.M2.T1.S2 (next): adds the dedicated single-quote-query REGRESSION test (the full o'brien
    e2e). This subtask only fixes the binding + the existing test_run_file.sh assertions; it does
    NOT add a new test file.
  - The resolver (P1.M1) and the defence guards (P1.M1.T2: newline-reject, directory-exists) are
    upstream of quoting and unaffected.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Run file: the ONLY expected finding is SC1091 (info, sourcing resolve.sh — pre-existing).
shellcheck tmux-zoxide-sessions.tmux
# To confirm "only SC1091": this must print NOTHING:
shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -v SC1091
# (If SC2140 appears, you used a bare " instead of \" in the bash string — re-apply the exact newText.)

# Test: must be clean (exit 0).
shellcheck tests/test_run_file.sh
# Expected: exit 0, no output.

# Confirm the exact bytes of the fix:
grep -n 'z-window.sh' tmux-zoxide-sessions.tmux | grep run-shell
# Expected:     "run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"   (single backslash, $CURRENT_DIR intact)
```

### Level 2: Unit / Integration Test (Component Validation — authoritative)

```bash
# The binding-registration test (isolated tmux server; does NOT touch the user's live tmux).
# NOTE: if you see "server exited unexpectedly", a concurrent process is using the `zxstest_run`
# socket — kill stray `tmux -L zxstest_run` servers and re-run (it is NOT the fix).
sh tests/test_run_file.sh
# Expected: RESULTS: pass=11 fail=0, exit 0. C3 (path) + C3 (%%) + C4 (path) + C4 (%%) all PASS.
# If C3/C4 fail with "expected haystack to contain [...%%...]", the needle still has the old form
# or the wrong escaping — re-apply the two-substring form exactly.

# Full suite — no regressions (the fix touches only the binding format string):
for t in tests/test_*.sh; do printf '%-42s ' "$t"; sh "$t" 2>&1 | grep '^RESULTS' || echo "NO-RESULTS"; done
# Expected: every line ends with fail=0.
```

### Level 3: Behavioural / Manual Smoke (Issue 2 reproduction)

```bash
# Confirm the apostrophe query now survives. (Run as a SCRIPT FILE, not bash -c, to avoid
# nested-quote hell; the fake `zoxide` case pattern MUST be double-quoted: "o'brien" — a bare
# o'brien) pattern is itself invalid shell.) Full script pattern in
# research/verification_notes.md §5. Skeleton:
REAL_TMUX=/usr/bin/tmux; SOCK=issue2_smoke_$$
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
D=$(mktemp -d); mkdir -p "$D/obrien"; TB=$(mktemp -d)
# fake zoxide (double-quoted case pattern so the apostrophe matches):
cat > "$TB/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = query ] || exit 0
shift; [ "${1:-}" = -- ] && shift
case "$1" in
    "o'brien") printf '%s\n' "$OBRIEN_DIR"; exit 0 ;;
    *)         printf ''; exit 0 ;;
esac
ZOX
cat > "$TB/tmux" <<TMUX
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
TMUX
chmod +x "$TB/zoxide" "$TB/tmux"
export PATH="$TB:$PATH" OBRIEN_DIR="$D/obrien"
cd "$D"; "$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$D" >/dev/null 2>&1; sleep 0.3
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
# the post-%%-substitution dispatch the fixed binding produces for `o'brien`:
"$REAL_TMUX" -L "$SOCK" run-shell "$PWD/scripts/z-window.sh \"o'brien\""; sleep 0.5
idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
echo "name=[$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{window_name}')] \
start=[$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{pane_start_path}')]"
# Expected: name=[obrien] start=[<…>/obrien]  -> "ISSUE 2 FIXED".
# Empty query: run-shell "$PWD/scripts/z-window.sh \"\"" -> 1 window, name=basename(cur), no error.
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; rm -rf "$D" "$TB"
```

### Level 4: N/A

No performance, security-scan, or API-doc validation applies to a one-line quoting fix + test-needle
update. (The documented `$`/`"`/`` ` ``/`\` residual is accepted and out of scope; it is not a
regression introduced here.) The behavioural coverage is Level 2 (binding registered correctly) +
Level 3 (apostrophe query resolves, empty query falls back).

## Final Validation Checklist

### Technical Validation

- [ ] `shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -v SC1091` prints nothing (only SC1091 info).
- [ ] `shellcheck tests/test_run_file.sh` exits 0 with no output.
- [ ] `sh tests/test_run_file.sh` → `RESULTS: pass=11 fail=0`, exit 0.
- [ ] Full suite (`for t in tests/test_*.sh; do sh "$t"; done`) → every test `fail=0`.
- [ ] `git status --short` shows ONLY `tmux-zoxide-sessions.tmux` and `tests/test_run_file.sh` modified.

### Feature Validation

- [ ] `tmux list-keys -1 -T prefix g` shows `%%` wrapped in `"..."` (i.e. `...z-window.sh \"%%\"'`).
- [ ] An apostrophe query (`o'brien`) reaches z-window.sh as `$1` and resolves (window named `obrien` in the matched dir) — Level 3 smoke.
- [ ] An empty query still falls back to the current dir with no parse error.
- [ ] C3 (default key g) AND C4 (custom key Z) both pass with the new binding (both updated, not just C3).

### Code Quality Validation

- [ ] The run-file change is exactly `%%` → `\"%%\"` (bash source); `$CURRENT_DIR`, the `run-shell '...'` wrappers, and all other lines are byte-preserved.
- [ ] The test change uses backslash-free substring needles (path prefix + `%%`); no fragile `\\\"%%\\\"` escaping.
- [ ] No new files; no chmod; no changes to resolver/handler/hook/README/options.
- [ ] The fix follows `research_issue2_quoting.md` Fix A (the recommended minimal fix); Fix B/C are explicitly out of scope.

### Documentation & Deployment

- [ ] No README/doc change (Mode A — the 'Window jump' section does not document the binding's exact quoting; key/prompt/behaviour are identical). The full apostrophe regression test is P1.M2.T1.S2.
- [ ] No new tmux options, hooks, or environment variables.

---

## Anti-Patterns to Avoid

- ❌ Don't use a **bare `"`** inside the bash run-shell string (e.g. `...sh "%%"'"`) — shellcheck flags SC2140 ("A"B"C") and bash mis-parses it. The bash source must be `\"%%\"` (escaped) so it emits a single literal `"`. (If you see SC2140, you used a bare quote.)
- ❌ Don't use **`\\\"%%\\\"`** in the **run file** — that emits literal backslashes into the template (`\"%%\"`), which is wrong. The run file needs exactly ONE level of bash escaping: `\"%%\"`.
- ❌ Don't use the item contract's **literal** test needle `"run-shell '$REPO_ROOT/scripts/z-window.sh \"%%\"'"` as-is — when the **sh** test parses it, `\"`→`"` so the VALUE is `...sh "%%"'` (no backslash), which does NOT match `list-keys`' backslashed display `...sh \"%%\"'`. Use the two-substring form (path prefix + `%%`), or the exact `\\\"%%\\\"` sh-source if you insist on one needle.
- ❌ Don't update **only C3** — C4 (custom key Z) has the identical old needle and also breaks. Update BOTH (~line 103 and ~line 111).
- ❌ Don't "also fix" `$`/`"`/`` ` ``/`\` in queries — that needs Fix B (`display-popup`/`read </dev/tty`, bypassing `%%`) and is out of scope; it would change the UX and raise the tmux version floor. Fix A is the scoped fix for Issue 2 (`'` and spaces).
- ❌ Don't touch `z-window.sh` (`query="$*"` is already correct), `z-session.sh`, `resolve.sh`, the session-created hook, README, or the options. The bug is purely in the `%%` quoting.
- ❌ Don't add a new regression-test file — that is **P1.M2.T1.S2**. This subtask fixes the binding + updates the existing `test_run_file.sh` assertions only.
- ❌ Don't write the Issue-2 repro as inline `bash -c` — the nested quotes (apostrophe inside `$(...)` inside `-c`) break parsing. Write it as a script file, and double-quote the fake `zoxide` case pattern (`"o'brien"`), since a bare `o'brien)` pattern is itself invalid shell.
- ❌ Don't conclude the fix is broken if `test_run_file.sh` reports "server exited unexpectedly" — that is a **concurrent process** on the `zxstest_run` socket killing the server mid-test, not the fix. Kill stray `tmux -L zxstest_run` servers (or run on a unique socket) and re-run.
- ❌ Don't modify `.gitignore` or `PRD.md`.

---

## Scope Boundaries (explicit)

| Item | This subtask (P1.M2.T1.S1) | Other subtasks |
| --- | --- | --- |
| `tmux-zoxide-sessions.tmux` (window-jump binding) | ✅ MODIFY (1 line: `%%` → `\"%%\"`) | originally P1.M2.T2.S1; session-hook block owned by P1.M3.T2.S1 (untouched) |
| `tests/test_run_file.sh` (C3 + C4 needles) | ✅ MODIFY (both → backslash-free substrings) | created in P1.M2.T2.S1 |
| single-quote-query **regression test** (new file) | ❌ DO NOT | P1.M2.T1.S2 |
| `z-window.sh`, `z-session.sh`, `resolve.sh` | ❌ DO NOT | P1.M2.T1.S1 (orig) / P1.M3 / P1.M1 |
| README / options / `.gitignore` / `PRD.md` | ❌ FORBIDDEN | P1.M3.T1 / human-owned |

---

**Confidence Score: 9.5/10** — The fix is a single, empirically-validated bash line (`%%` → `\"%%\"`), `shellcheck`-clean on the run file (only the pre-existing SC1091 info) and on the test, and proven end-to-end: registering the fixed binding and dispatching `run-shell '.../z-window.sh "o'brien"'` delivers `o'brien` to z-window.sh as `$1` and resolves it (window named `obrien` in the matched dir); an empty query falls back with no parse error. The full existing suite is green (9/9 tests, 92 assertions) on a staging copy with the fix applied. The two non-obvious traps — (1) `list-keys` re-quotes the display with backslashes so the contract's literal `"%%"` needle does NOT match (resolved with a validated backslash-free two-substring form), and (2) **C4 shares C3's needle and must also be updated** — are surfaced, proven by a candidate-needle probe and a repo-wide grep, and fixed. `test_run_file.sh` prints `RESULTS: pass=11 fail=0`. Residual half-point: the documented `$`/`"`/`` ` ``/`\` query residual is accepted (Fix B/C out of scope), and the one environmental flake (a concurrent process on the shared `zxstest_run` socket causing "server exited unexpectedly") is environmental, not the fix, and is called out. This subtask closes Issue 2 at the binding level and unblocks P1.M2.T1.S2 (the dedicated regression test).
