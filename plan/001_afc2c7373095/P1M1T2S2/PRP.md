# PRP — P1.M1.T2.S2: `_resolve_zoxide()` backend

## Goal

**Feature Goal**: Append the **second** function — `_resolve_zoxide()` — to the shared library `scripts/lib/resolve.sh` (created by P1.M1.T2.S1 with `get_tmux_option` only). This function is the `zoxide` backend resolver: given a query, it echoes zoxide's single best-match directory (one absolute path line) or empty, and **never errors if the `zoxide` binary is absent**. It is consumed by the `resolve()` dispatcher (P1.M1.T2.S4) for the `zoxide` branch and the `auto`-fallback's first leg.

**Deliverable**: Two artifacts —
1. `scripts/lib/resolve.sh` — **append** `_resolve_zoxide()` after the existing `get_tmux_option()`. Nothing else changes (shebang, header comment, `get_tmux_option` stay byte-for-byte; `_resolve_z` and `resolve` are NOT written — they belong to S3/S4).
2. `tests/test_resolve_zoxide.sh` — a dependency-free POSIX-`sh` unit test that injects a **fake `zoxide` shim** on `PATH` (match / no-match) and makes it unreachable (missing-binary), sourcing `resolve.sh` and asserting each branch. Establishes the backend-test pattern S3/S4 will extend.

**Success Definition**:
- `scripts/lib/resolve.sh` contains `get_tmux_option` (unchanged) **and** `_resolve_zoxide` (new), and is sourceable in plain `sh`.
- `_resolve_zoxide <query>` echoes zoxide's best match when `zoxide` is present and the query matches; echoes **empty** on no-match or when `zoxide` is absent. Callers check output, not status.
- `shellcheck scripts/lib/resolve.sh` exits 0 with **no** output (no exclusions/directives).
- `sh tests/test_resolve_zoxide.sh` prints `RESULTS: pass=3 fail=0` and exits 0.
- `.gitignore` and `PRD.md` are untouched; no other functions are added; nothing is chmod'd.

## User Persona

**Target User**: The implementing AI agent (subtask executor); the downstream `resolve()` dispatcher (P1.M1.T2.S4) which calls `_resolve_zoxide` directly; ultimately the run file + both handler scripts (P1.M2/P1.M3) which call `resolve()`.

**Use Case**: Translate a short human query (`tmux`, `proj`) into a concrete directory using the `zoxide` frecency index, so `new-window -c <dir>` / `respawn-pane -c <dir>` land in the right place without the user typing a path.

**Pain Points Addressed**: tmux's `new-window -c` / `new-session -c` need a literal path; zoxide already knows the user's most-used dirs. `_resolve_zoxide` is the safe, side-effect-free one-shot lookup that never crashes the plugin when zoxide isn't installed.

## Why

- This is the **second** of four functions built into the same file (S1 → S2 → S3 → S4). It is the primary, preferred backend: `auto` (the default) tries `_resolve_zoxide` first and only falls back to `_resolve_z` on an empty result (PRD §4).
- The function is a **pure lookup** (no `cd`, no state mutation) — far simpler and more robust than the rupa/z `_z` function (S3, which carries CORRECTION A for a no-match false-positive bug). Getting the simple one right first de-risks S3/S4.
- Two empirically-verified facts make the mandated form correct as written (see `findings_and_risks.md` #5 and the verification notes): (a) `zoxide query <q>` prints exactly one path line on match; (b) on no-match it yields **empty stdout + exit 0 + no stderr**. So `command -v zoxide … && zoxide query -- "$1" 2>/dev/null` is sufficient — no `|| true`, no `return 0` needed in this function.
- Ships the NOTE D `--` end-of-options guard (findings_and_risks.md) — cheap hardening so a query that happens to start with `-` (e.g. a dir named `-foo`) isn't parsed as a zoxide flag.

## What

User-visible behavior: none directly (sourced library function). Observable contract when sourced into any `sh` script:

- `_resolve_zoxide "<query>"` → if the `zoxide` binary is on `PATH` and the query has a match, writes **one line** (the best-match absolute path) to stdout; otherwise writes nothing. The function's exit status mirrors zoxide's (exit 0 on this version for both match and no-match), but **callers must check the output, not the status** (PRD §4: "The resolver returns empty on no match and always exits 0; callers check output, not status").
- When `zoxide` is **not** on `PATH`, `command -v zoxide` fails and the `&&` short-circuits — the function prints nothing and does not error.
- stderr from zoxide (if any) is suppressed by `2>/dev/null` (defensive hygiene; the installed version is quiet on a miss).

### Success Criteria

- [ ] `scripts/lib/resolve.sh` still starts with `#!/bin/sh`, the §5.3 header comment, and `get_tmux_option` — **unchanged**.
- [ ] `_resolve_zoxide` is **appended** after `get_tmux_option`, with the exact 2-line body and a one-line doc comment.
- [ ] `_resolve_zoxide` body is exactly: `command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null` (PRD §5.3 + NOTE D `--` guard, verbatim).
- [ ] No `local`, no `[[ ]]`, no arrays, no `==` in `[ ]`, no `echo -e`, no `|| true`, no `; return 0` (POSIX-clean; mandated form).
- [ ] `shellcheck scripts/lib/resolve.sh` → exit 0, no output.
- [ ] `sh tests/test_resolve_zoxide.sh` → `RESULTS: pass=3 fail=0`, exit 0.
- [ ] `get_tmux_option` still works after the append (re-run its test or source-check).
- [ ] `.gitignore` / `PRD.md` unmodified (`git status --short` shows only new/modified expected files).

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The exact function text is reproduced verbatim below; the mocking test is fully specified and was empirically verified to pass 3/3; the open exit-status discrepancy in the architecture research is resolved with the empirical result; the POSIX/append-only/`--`-guard constraints are explicit; `shellcheck` is the only required tool (confirmed installed, and confirmed clean on this exact form). No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source for the EXACT function text and the resolver contract.
  section: "§5.3 scripts/lib/resolve.sh (the _resolve_zoxide block only), §4 Options reference (the zoxide/auto backends), h2.1/h3.0 rationale"
  critical: "Append the _resolve_zoxide block byte-faithful. The contract 'callers check output, not status' (§4) is what makes exit-status irrelevant here."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: Primary-source, empirically-verified facts about zoxide behavior + NOTE D (-- guard).
  section: "✅ #5 (zoxide query: empty+exit0 on no-match, no stderr), ⚪ NOTE D (zoxide query -- guard)"
  critical: "#5 OVERRIDES the exit-1 claim in research_resolver_backends.md (that brief had no shell tool; #5 was tested on this machine). NOTE D: use `zoxide query -- \"$1\"` — cheap hardening, REQUIRED by this item contract."

- file: plan/001_afc2c7373095/architecture/research_resolver_backends.md
  why: Documents zoxide CLI semantics (best-match by default, --list/--score to avoid, -- separator honored by clap).
  section: "§1 zoxide query (subcommand/flags/output/exit), RISKS table row D/E/F"
  critical: "ONE claim here is empirically WRONG for the installed version: it says no-match -> exit 1. Findings #5 (exit 0) is authoritative. The `--` guard and `2>/dev/null` hygiene advice here ARE correct and are applied."

- file: plan/001_afc2c7373095/P1M1T2S1/PRP.md
  why: The S1 PRP that CREATED scripts/lib/resolve.sh (with get_tmux_option) and the tests/ harness pattern.
  section: "Verbatim content for resolve.sh, Verbatim test block, Known Gotchas (POSIX, em dash, sourced-not-exec)"
  critical: "This subtask ASSUMES resolve.sh already has the shebang + header comment + get_tmux_option (from S1, or the contract below if S1 runs concurrently). APPEND _resolve_zoxide; do NOT recreate the file's head. Reuse S1's fake-binary-on-PATH test idiom."

- docfile: plan/001_afc2c7373095/P1M1T2S2/research/verification_notes.md
  why: Empirical proof grounding every gate: shellcheck clean, no-match exit 0, empty-keyword clean, 3/3 test pass, AND a critical test false-pass bug (found+fixed).
  section: "§1 shellcheck, §2 exit-status resolution, §5 false-pass bug, §6 fake-zoxide arg parsing"
  critical: "§5: the missing-binary test MUST narrow PATH INSIDE the subshell (`. resolve.sh; PATH=$empty; f`), NOT via `PATH=$empty sh -c …` — the latter makes `sh` unresolvable and silently false-passes. Copy the fixed `without()` helper verbatim."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State AFTER P1.M1.T2.S1 has run (treat as contract):
$ ls scripts/lib tests 2>/dev/null
scripts/lib:
resolve.sh          # S1 wrote: shebang + header comment + get_tmux_option ONLY
tests:
test_resolve_get_tmux_option.sh   # S1's fake-tmux unit test (pattern to mirror)

# Tooling on this machine:
$ command -v shellcheck zoxide sh
/usr/bin/shellcheck            # ✅ required lint gate
/home/dustin/.local/bin/zoxide # ✅ present (fake shim still shadows it in tests)
/bin/sh -> bash                # dev note: dash-strictness observed via shellcheck, not runtime
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  scripts/
    lib/
      resolve.sh             # MODIFIED — APPEND _resolve_zoxide() after get_tmux_option()
  tests/
    test_resolve_get_tmux_option.sh   # (S1, unchanged — may re-run to confirm no regression)
    test_resolve_zoxide.sh            # NEW — fake-zoxide mocking unit test (3 cases)
```

`resolve.sh` now holds **two** functions. `_resolve_z` (CORRECTION A) and `resolve` (CORRECTION B)
are still NOT written — S3/S4 append them later. Do not pre-write them.

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL: APPEND only. Preserve the S1 content (shebang `#!/bin/sh`, the 2-line header
#   comment WITH its U+2014 em dash, and get_tmux_option) byte-for-byte. Insert _resolve_zoxide
#   AFTER get_tmux_option, separated by a blank line + a one-line doc comment.

# CRITICAL: The `--` end-of-options guard is REQUIRED by this item contract (NOTE D).
#   Write `zoxide query -- "$1"`, NOT `zoxide query "$1"`. A query literally named `-foo`
#   would otherwise be parsed as a zoxide flag. (zoxide uses clap, which honors `--`.)

# CRITICAL (exit status): The architecture research DISAGREES on zoxide's no-match exit code.
#   - research_resolver_backends.md (no shell tool, knowledge-only) claims exit 1.
#   - findings_and_risks.md #5 (tested on THIS machine) says exit 0, empty stdout, no stderr.
#   The EMPIRICAL truth on this machine is EXIT 0. Do NOT add `|| true` or `; return 0` to
#   _resolve_zoxide to "fix" a phantom exit-1: (a) it isn't needed here, (b) the item contract
#   mandates the exact 2-line form, (c) any residual exit-status risk is handled by S4's
#   CORRECTION B (resolve() ends with `return 0`) and by the fact that _resolve_zoxide is only
#   ever called inside `resolve()` (never directly by handler scripts).

# CRITICAL (test false-pass): The missing-binary test MUST narrow PATH INSIDE the subshell,
#   not via a command-prefix assignment. `PATH=$empty sh -c '…'` narrows PATH before `sh` is
#   resolved, so `sh` itself is "not found" (stderr noise) and the function never runs — yet
#   the empty output coincidentally matches the expected "". That is a SILENT FALSE PASS.
#   Fix: `sh -c '. "$0"; PATH="$1"; _resolve_zoxide "$2"' "$RESOLVE" "$EMPTY" "$q"` — resolve
#   `sh` via the outer PATH, then narrow PATH inside. (Verified: dropping a fake zoxide into
#   the "empty" bin then makes the function return its output — proving command -v is real.)

# GOTCHA: Do NOT chmod +x resolve.sh — it is SOURCED, never executed (S1 invariant; carried).
# GOTCHA: POSIX sh — NO `local`. This function has no scratch var anyway, but keep the
#   discipline for any future edit. Avoid [[ ]], arrays, `==` in [ ], `echo -e`, ${var//}.
# GOTCHA: No test framework exists. Do NOT pull in bats/shunit2. The mandated approach is a
#   dependency-free fake-binary-on-PATH mock (item contract #5), extending the S1 pattern.
# GOTCHA: The fake zoxide MUST honor the `--` separator: it receives args `query -- <keyword>`,
#   so parse by dropping `query`, dropping a leading `--`, then taking the keyword. A fake that
#   hardcodes the keyword as a fixed positional silently mis-parses and hides bugs.
# GOTCHA: `/bin/sh` -> bash on THIS dev machine (dash-strictness via shellcheck, not runtime).

# FORBIDDEN: Do NOT modify .gitignore or PRD.md.
# FORBIDDEN: Do NOT chmod anything, and do NOT modify get_tmux_option or S1's test.
# FORBIDDEN: Do NOT pre-write _resolve_z (S3, CORRECTION A) or resolve (S4, CORRECTION B).
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The only "structure" is the function's positional-parameter contract:
`$1` = query keyword (e.g. `tmux`). Output via stdout only (one absolute path line, or nothing).

### Verbatim content to APPEND to `scripts/lib/resolve.sh`

`scripts/lib/resolve.sh` already exists from S1 with this head (do not rewrite it):
```sh
#!/bin/sh
# lib/resolve.sh — shared helpers for tmux-zoxide-sessions.
# Sourced by the run file, scripts/z-window.sh, and scripts/z-session.sh.

# get_tmux_option <name> <default> -> option value, or default if unset/empty.
get_tmux_option() {
    _v=$(tmux show-option -gqv "$1" 2>/dev/null)
    [ -n "$_v" ] && echo "$_v" || echo "$2"
}
```
**Append** exactly the following block (one blank line + doc comment + function) after `get_tmux_option`:
```sh

# _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
}
```
> Implementing agent: this is the **verbatim** PRD §5.3 `_resolve_zoxide` with the NOTE D `--`
> guard. Do **not** add `local`, `if/else`, `|| true`, `; return 0`, shellcheck directives, or
> other functions. The whole function body is one `&&` chain; it returns zoxide's status (exit 0
> on this version for both match and miss), which is fine because callers check output.

### Verbatim content for `tests/test_resolve_zoxide.sh`

Write **exactly** this. It is self-verifying (prints `PASS`/`FAIL`, exits non-zero on any failure)
and was run during research: `RESULTS: pass=3 fail=0`, exit 0.

```sh
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
# Fake zoxide implementing ONLY: zoxide query [--] <keyword>
[ "$1" = "query" ] || exit 0
shift
[ "${1:-}" = "--" ] && shift        # honor the end-of-options guard
kw="$1"
case "$kw" in
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
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: MODIFY scripts/lib/resolve.sh  (APPEND _resolve_zoxide)
  - FILE: scripts/lib/resolve.sh (exists from S1; do NOT recreate the head)
  - ACTION: append the verbatim block above (blank line + doc comment + function) AFTER get_tmux_option.
  - FORM: exactly `command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null`.
  - GUARD: include the `--` end-of-options separator (NOTE D) — NOT `zoxide query "$1"`.
  - NAMING: function _resolve_zoxide (underscore-prefixed = internal backend helper; S3's _resolve_z mirrors it).
  - PRESERVE: shebang `#!/bin/sh`, the 2-line header comment (with U+2014 em dash), and get_tmux_option — byte-for-byte.
  - STOP: do NOT add _resolve_z (S3) or resolve (S4). Do NOT chmod +x.

Task 2: CREATE tests/test_resolve_zoxide.sh
  - FILE: tests/test_resolve_zoxide.sh
  - CONTENT: the verbatim block above (fake-zoxide mocking harness, 3 cases).
  - NAMING: test_resolve_<backend>.sh — extends S1's test_resolve_<function>.sh pattern.
  - PLACEMENT: tests/ at repo root (dev-only; not in PRD §5.1 ship tree — additive, like S1's test).
  - COVERAGE: match (fake zoxide echoes canned path), no-match (fake echoes empty), missing-binary (zoxide unreachable).
  - CRITICAL: use the fixed `withfake`/`without` helpers that narrow PATH INSIDE the subshell (see Known Gotchas false-pass bug). Copy them verbatim — do NOT write `PATH=$x sh -c …`.
  - SELF-VERIFY: prints PASS/FAIL per case; exit non-zero on any failure; cleans up its fake bin dirs via trap.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: shellcheck scripts/lib/resolve.sh                       # expect exit 0, no output
  - RUN: shellcheck tests/test_resolve_zoxide.sh                 # expect exit 0, no output
  - RUN: sh tests/test_resolve_zoxide.sh                         # expect "RESULTS: pass=3 fail=0", exit 0
  - RUN: sh tests/test_resolve_get_tmux_option.sh                # S1 test still passes (no regression to get_tmux_option)
  - RUN: sh -c '. scripts/lib/resolve.sh; type _resolve_zoxide; type get_tmux_option'  # both functions present
  - RUN: grep -nE '\blocal\b|\[\[|==|\becho -e\b|\|\| true' scripts/lib/resolve.sh     # expect NO matches
  - RUN: git status --short                          # only expected new/modified files; PRD.md/.gitignore untouched
```

### Implementation Patterns & Key Details

```sh
# The single pattern this subtask establishes — a safe one-shot external-binary lookup:
#   dir=$(_resolve_zoxide "$query")
#
# Why it works (empirically verified, findings_and_risks.md #5):
#   - `zoxide query <q>` prints ONE absolute path line on a match (exit 0).
#   - On a no-match it prints NOTHING (empty stdout, exit 0, no stderr).
#   So capturing stdout is a complete "did it match?" signal: non-empty == match.
#
# Why `command -v zoxide >/dev/null 2>&1 && …`:
#   - If zoxide isn't installed, `command -v` fails and the `&&` short-circuits — the
#     function prints nothing and NEVER errors. This is the "never errors if zoxide is
#     absent" guarantee (item contract #4). Critical for the `auto` backend on machines
#     without zoxide (PRD §4: "Works on machines without zoxide").
#   - The `>/dev/null 2>&1` on the `command -v` silences its (usually empty) output.
#
# Why the `--` (NOTE D):
#   - `zoxide query -- "$1"` prevents a query that starts with `-` (e.g. a dir named `-foo`)
#     from being parsed as a zoxide flag. zoxide uses clap, which honors `--`. Cheap, required.
#
# Why `2>/dev/null` on the zoxide call:
#   - Hygiene: suppress any diagnostic zoxide might write on a miss (the installed version is
#     quiet, but this is version-independent defense; keeps "empty output == miss" clean).
#
# Why NO `|| true` / `; return 0`:
#   - Not needed: this version exits 0 on a miss (empirical). And _resolve_zoxide is only ever
#     called inside resolve() (S4): the `auto` path uses `$(…)` (status discarded) and
#     CORRECTION B ends resolve() with `return 0`. Adding defense here would deviate from the
#     mandated form and lint as unnecessary. Keep it exactly as specified.
```

### Integration Points

```yaml
FILESYSTEM:
  - modify: "scripts/lib/resolve.sh   (APPEND _resolve_zoxide; sourced lib — NOT executable)"
  - create: "tests/test_resolve_zoxide.sh   (dev unit test; executable bit optional)"

NO DATABASE / CONFIG / ROUTES / BUILD CHANGES:
  - This subtask adds one sourced function + one test. No tmux options registered, no hooks,
    no keybindings. (Those belong to P1.M2/P1.M3.)
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only).

DOWNSTREAM CONSUMERS (contract this subtask guarantees):
  - S4 (resolve dispatcher, CORRECTION B): calls `_resolve_zoxide "$1"` in the `zoxide` branch
    and as the first leg of `auto` (`_r=$(_resolve_zoxide "$1")`; if empty, fall back to _resolve_z).
    So _resolve_zoxide MUST be defined, output a single path or empty, and never crash on a
    missing binary — all guaranteed by this contract.
  - P1.M2/P1.M3 handler scripts: call `resolve()` only (never _resolve_zoxide directly), so they
    are decoupled from this backend's exact exit status.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — POSIX-sh posture. MUST exit 0 with NO output (no -e, no directives).
shellcheck scripts/lib/resolve.sh
shellcheck tests/test_resolve_zoxide.sh
# (Verified during research: exit 0, zero findings on both.)

# Confirm POSIX-clean + mandated-form by inspection. Expect NO matches.
grep -nE '\blocal\b|\[\[|==|\becho -e\b|\$\{[a-zA-Z_]+//[^}]+/\}|\|\| true|return 0' \
    scripts/lib/resolve.sh
# Expected: nothing prints. (The `return 0`/`|| true` grep specifically guards against adding
# the phantom-exit-1 defense — neither belongs in _resolve_zoxide.)

# Expected: shellcheck exits 0 silently; grep prints nothing.
```

### Level 2: Unit Tests (Component Validation)

```bash
# The mocking-based unit test (item contract #5). No live zoxide, no bats, no deps.
sh tests/test_resolve_zoxide.sh
# Expected output ends with:  RESULTS: pass=3 fail=0   and exit code 0.
# (Verified during research: 3/3 PASS, with no "sh: command not found" on stderr — if you see
#  that error, the missing-binary helper is using `PATH=$x sh -c …`; switch to the verbatim
#  `without()` helper that narrows PATH inside the subshell.)

# Regression guard: S1's test must still pass (the append didn't touch get_tmux_option).
sh tests/test_resolve_get_tmux_option.sh
# Expected: RESULTS: pass=6 fail=0, exit 0.
```

### Level 3: Integration / Sourceability (System Validation)

```bash
# 3a. The lib sources cleanly in plain sh and BOTH functions are defined after sourcing.
sh -c '. scripts/lib/resolve.sh; type get_tmux_option; type _resolve_zoxide' | sed 's/is.*//'
# Expected: two lines — "get_tmux_option " and "_resolve_zoxide " (both functions present).

# 3b. No-zoxide-on-PATH -> empty output, no error (the core "never errors if absent" contract).
sh -c '. scripts/lib/resolve.sh; PATH=/nonexistent; r=$(_resolve_zoxide "tmux"); [ -z "$r" ]' \
  && echo "no-zoxide OK" || echo "no-zoxide FAIL"

# 3c. OPTIONAL live-zoxide smoke (only meaningful if the zoxide DB is populated). Skip cleanly
#     if the local DB has no match; this is a sanity check, not a gate (Level 2 is authoritative).
if command -v zoxide >/dev/null 2>&1; then
    live=$(sh -c '. scripts/lib/resolve.sh; _resolve_zoxide "tmux"')
    [ -n "$live" ] && echo "live-zoxide OK ($live)" || echo "live-zoxide: empty (DB cold — acceptable)"
else
    echo "skipped live-zoxide smoke (no binary) — Level 2 unit test is the authoritative gate"
fi
# Expected: sourceability OK (both funcs); no-zoxide OK; live smoke OK-or-noted-empty.
```

### Level 4: N/A

No runtime feature, performance, or security validation applies to a single sourced lookup.
Skipped intentionally (no user-facing behavior to exercise beyond Levels 1–3).

## Final Validation Checklist

### Technical Validation

- [ ] `shellcheck scripts/lib/resolve.sh` exits 0 with no output.
- [ ] `shellcheck tests/test_resolve_zoxide.sh` exits 0 with no output.
- [ ] `sh tests/test_resolve_zoxide.sh` prints `RESULTS: pass=3 fail=0` and exits 0.
- [ ] `sh tests/test_resolve_get_tmux_option.sh` still passes (S1 regression guard).
- [ ] Sourceability check (Level 3a) shows both `get_tmux_option` and `_resolve_zoxide`.
- [ ] No-zoxide check (Level 3b) returns empty with no error.
- [ ] POSIX-clean + no-`|| true`/`return 0` grep (Level 1) prints nothing.

### Feature Validation

- [ ] All success criteria from "What" met.
- [ ] `_resolve_zoxide` echoes zoxide's best-match path when zoxide is present and matches (case 1).
- [ ] `_resolve_zoxide` echoes empty on a no-match (case 2).
- [ ] `_resolve_zoxide` echoes empty and never errors when zoxide is absent (case 3).
- [ ] The function uses the `--` end-of-options guard (NOTE D) — verified by reading the line.
- [ ] `get_tmux_option` is unchanged and still the first function in the file.

### Code Quality Validation

- [ ] Follows PRD §5.3 verbatim (with the mandated NOTE D `--` guard).
- [ ] POSIX-`sh` clean (no `local`/`[[ ]]`/arrays/`==`/`echo -e`/`|| true`/`return 0`).
- [ ] Append-only — the S1 head (shebang, header comment with em dash, get_tmux_option) is byte-preserved.
- [ ] File placement matches the desired tree (`scripts/lib/resolve.sh` modified; `tests/test_resolve_zoxide.sh` new).
- [ ] No executable bit set on resolve.sh (sourced, not executed — S1 invariant carried).
- [ ] Fake-zoxide test honors the `--` separator in arg parsing (mirrors the real contract).

### Documentation & Deployment

- [ ] Inline doc comment documents the contract (`# _resolve_zoxide <query> -> dir from zoxide query, or empty.`).
- [ ] No user-facing/config surface (internal backend helper — no README/doc changes, per item contract #6).
- [ ] No new tmux options, hooks, or environment variables introduced.

---

## Anti-Patterns to Avoid

- ❌ Don't **recreate** `resolve.sh` from scratch (you'd clobber S1's `get_tmux_option`). APPEND the function.
- ❌ Don't drop the `--` guard — `zoxide query "$1"` is the PRD's unhardened form; NOTE D and the item contract require `zoxide query -- "$1"`.
- ❌ Don't add `|| true` or `; return 0` to "fix" a phantom exit-1. The empirical truth is exit 0 on a miss; CORRECTION B (S4) owns exit-status defense at the dispatcher. The item contract mandates the bare `&&` form.
- ❌ Don't write the missing-binary test as `PATH=$empty sh -c '…'` — it false-passes (`sh` becomes unresolvable). Narrow PATH **inside** the subshell (verbatim `without()` helper).
- ❌ Don't hardcode the fake zoxide's keyword as a fixed positional — parse past `query` and `--` so the `--` guard is genuinely exercised.
- ❌ Don't use `local` (non-POSIX), `[[ ]]`, `echo -e`, or `${var//}` — POSIX-`sh` only.
- ❌ Don't `chmod +x resolve.sh` — sourced, never executed (S1 invariant).
- ❌ Don't pull in bats/shunit2/sharness — dependency-free fake-binary mock is the mandated/established pattern.
- ❌ Don't modify `.gitignore` or `PRD.md`.
- ❌ Don't pre-write `_resolve_z` (S3, CORRECTION A) or `resolve` (S4, CORRECTION B) — their required corrections aren't in the PRD §5.3 text.

---

## Scope Boundaries (explicit)

| Item | This subtask (S2) | Other subtasks |
| --- | --- | --- |
| `scripts/lib/resolve.sh` (file) | ✅ MODIFY (append) | S1 created it; S3/S4 append more |
| shebang `#!/bin/sh` + header comment | (preserve, S1 owns) | — |
| `get_tmux_option()` | (preserve, S1 owns) | S2/S3/S4 consume it |
| `_resolve_zoxide()` (with `--` guard) | ✅ CREATE (append, verbatim PRD §5.3 + NOTE D) | S4 consumes it |
| `_resolve_z()` (CORRECTION A) | ❌ DO NOT | P1.M1.T2.S3 |
| `resolve()` dispatcher (CORRECTION B) | ❌ DO NOT | P1.M1.T2.S4 |
| `tests/test_resolve_zoxide.sh` | ✅ CREATE (additive dev artifact) | extends S1's test pattern |
| `tmux-zoxide-sessions.tmux`, `z-window.sh`, `z-session.sh`, `README.md` | ❌ DO NOT | P1.M2 / P1.M3 / P1.M4 |
| `chmod +x` on anything | ❌ DO NOT | P1.M4.T2.S1 |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 9.5/10** — The function text is reproduced verbatim and `shellcheck`-verified clean; the open exit-status discrepancy in the architecture research is **resolved empirically** (no-match → exit 0, matching findings_and_risks.md #5); the 3-case unit test is fully specified and was run during research (3/3 PASS); a subtle test false-pass bug (PATH-narrowing via command prefix) was found and fixed, with proof the missing-binary case genuinely exercises `command -v`; and the append-only / `--`-guard / no-defense-in-`_resolve_zoxide` boundaries are explicit. The residual half-point is the same as S1: `/bin/sh`→bash means strict-dash runtime behavior is observed via `shellcheck` rather than a real dash execution — mitigated by the function using only the most conservative POSIX subset (`command -v`, `&&`, command substitution, `2>/dev/null`).
