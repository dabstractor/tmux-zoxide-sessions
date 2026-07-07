# PRP — P1.M1.T2.S2: Add symmetric defence-in-depth guard to `z-session.sh`

## Goal

**Feature Goal**: Add a POSIX-portable defence-in-depth guard to `scripts/z-session.sh` so that a `resolved` value from `resolve()` is acted upon (the pane is relocated) **only if** it is (1) a single line (no embedded newline) and (2) an existing directory (`-d`). If either check fails — e.g. a multi-line zoxide list-mode database dump (the Issue-1 symptom) or any non-directory string — the handler **`exit 0`s** (no-op: the pane stays where it landed), consistent with its existing "nothing to do" contract. This is **Layer 2 (caller-side defence-in-depth)** of the Issue-1 remediation, symmetric with the `z-window.sh` guard in P1.M1.T2.S1; the root fix (resolver `--` guard) is owned by P1.M1.T1.S2.

**Deliverable**: A single surgical edit to **one** file — `scripts/z-session.sh`. Two logical changes:
1. Insert a POSIX newline literal `NL='<newline>'` (a real newline between the quotes) after the `. "$SCRIPT_DIR/lib/resolve.sh"` source line.
2. Insert a `case`/`-d` guard **between** the existing `[ -n "$resolved" ] || exit 0` check and the `# Relocate: …` / `respawn-pane` block.

**Success Definition**:
- `z-session.sh` still relocates when `resolved` is a single-line, existing directory (normal match → pane respawns in resolved dir). **No behavior change for normal sessions.**
- `z-session.sh` now `exit 0`s (no relocate) when `resolved` contains a newline **or** is not an existing directory.
- Empty / no-match still `exit 0`s early (unchanged — the pre-existing `[ -n "$resolved" ] || exit 0` runs first).
- `sh -n scripts/z-session.sh` → ok; `shellcheck` adds **no new findings** vs the original (only the pre-existing SC1091 info on the source line).
- `sh tests/test_z_session.sh` → `RESULTS: pass=9 fail=0` (the existing suite; verified green at baseline).
- No other file is modified; no new committed test assertions (those belong to P1.M1.T3.S2).

## User Persona

**Target User**: The implementing AI agent (1-point task). Downstream: P1.M1.T3.S2 (the committed `-l`/multi-line integration regression for z-session) and P1.M3.T1 (README sync).

**Use Case**: A new tmux session is created (any way: `tmux new -s foo`, `prefix :` `new-session`, ssh-then-tmux) that lands in `$HOME`. The `session-created` hook fires `z-session.sh`. If the resolver ever regresses (or any future backend returns a non-directory / multi-line value), the pane is left at `$HOME` instead of being respawned into a corrupt path.

**Pain Points Addressed**: Eliminates the single-point-of-failure where `tmux respawn-pane -t "$pane" -c "$resolved" -k` could receive a 146-line database dump (Issue 1's symptom class) — which would respawn the pane's shell in a bogus path or be rejected by tmux, leaving the session in a broken state. Symmetric hardening with `z-window.sh` so the "resolver returns a single directory" contract holds at **both** callers.

## Why

- This is **Layer 2** of the three-layer Issue-1 fix (`architecture/system_context.md §4`, detailed in `architecture/research_issue1_defense.md §C`). Layer 1 (resolver `--` guard) = P1.M1.T1.S2; Layer 3 (regression tests) = P1.M1.T3. Each layer is independently effective.
- **Defence-in-depth is the contract**: even if the resolver is later re-broken (as it was by commit `b93e776`), the caller refuses to act on a corrupt value. The guard validates `resolve()`'s output, so it works whether or not Layer 1 is present — genuinely order-independent (no hard dependency on P1.M1.T1.S2).
- **Symmetry / future-proofing** (`research_issue1_defense.md §C`): the z-session attack surface is *lower* than the window path (session names are rarely leading-dash like `-l`, though tmux permits it). But `resolve()` is **shared and backend-pluggable** — any future backend/fixture regression could return a non-directory or multi-line value here too. The README/PRD promise "the resolver returns a single directory" should hold at both callers, not just one. It is the same 4-line idiom; do not skip it.
- Cheap, POSIX-portable, mirrors the canonical form P1.M1.T2.S1 establishes for `z-window.sh`.

## What

User-visible behavior: **no change for normal sessions**. The only observable difference is in the failure/edge modes — a multi-line or non-directory `resolved` that previously fed a corrupt path to `respawn-pane` now silently leaves the pane where it is (the documented "nothing to do → exit 0" contract). This is strictly more conservative and matches the PRD §3.2 guard-chain intent (relocate only when safe).

### Success Criteria

- [ ] `grep -c "^NL='" scripts/z-session.sh` → `1` (the newline literal exists).
- [ ] `grep -Fc '*"$NL"*) exit 0' scripts/z-session.sh` → `1` (the newline-reject case arm exists).
- [ ] `grep -Fc '[ -d "$resolved" ] || exit 0' scripts/z-session.sh` → `1` (the directory test + no-op-on-failure arm exists).
- [ ] `grep -Fc "\$'\\\\n'" scripts/z-session.sh` → `0` (no bash-only `$'\n'` ANSI-C quote introduced).
- [ ] The pre-existing `[ -n "$resolved" ] || exit 0` line is **still present** and runs **before** the new guard.
- [ ] `sh -n scripts/z-session.sh` → ok.
- [ ] `shellcheck` on the edited file emits **only** the pre-existing SC1091 (info) on the `. resolve.sh` line — identical to the unmodified original (zero new findings).
- [ ] `sh tests/test_z_session.sh` → `RESULTS: pass=9 fail=0`.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The exact current content of the target lines (verbatim), the exact guard block (paste-ready), the critical POSIX constraint (with the forbidden bashism named), the failure-action adaptation (`exit 0`, not the `dir="$resolved"` form used by the sibling z-window.sh task — called out explicitly), the verified-working validation commands, the empirical guard-logic proof, and the scope boundaries (do-not-touch list) are all below. No broader codebase knowledge is required.

### Documentation & References

```yaml
# MUST READ
- file: scripts/z-session.sh
  why: THE file being edited. See "Current target block" below for exact lines.
  pattern: "#!/bin/sh POSIX session-created handler. Sources lib/resolve.sh; guard chain
            (master toggle -> name -> skip-list -> pane -> path -> not-$HOME -> resolve);
            respawn-pane -c $resolved -k; optional window rename. Exits 0 on every no-op."
  gotcha: "The failure action is `exit 0` (do nothing), NOT `dir=$cur`. The handler's whole
           job is to RELOCATE; if it can't safely, it no-ops and leaves the pane where it
           landed. Do NOT copy the z-window.sh `&& dir=\"$resolved\"` form — it is wrong here."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_issue1_defense.md
  why: §C is the AUTHORITATIVE design for THIS guard. Gives the exact recommended block and
       explains why z-session needs it despite its lower attack surface.
  section: "§C z-session.sh — does it need the same guard? (Yes)"
  critical: "§C gives the verbatim guard with `exit 0` on both arms (NOT the `&& dir=` form).
       Order matters: newline check FIRST (case arm), then -d. A list-mode dump may have a
       real dir on line 1 — only the newline arm rejects the whole multi-line value."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/findings_and_risks.md
  why: §F4 documents WHY the PRD's suggested one-liner is rejected (bashism + inverted logic).
  section: "§F4 (the non-POSIX one-liner)"
  critical: "Do NOT copy `[ -n \"\$resolved\" ] && [ -z \"\${resolved##*\$'\\n'*}\" ] || {...}`. It uses
       the bash/ksh-only \$'\\n' and its logic is inverted. Use the case/\"\$NL\" idiom instead."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T2S2/research/verification_notes.md
  why: Empirical proof: guard applied to a temp copy, full integration harness passes 9/0,
       guard logic 4/4 (incl. the multi-line-dump-of-real-dirs rejection), shellcheck adds
       zero new findings, exact insert points verified live.
  section: "§2 the exit-0-vs-dir adaptation, §3 integration 9/0, §4 guard logic 4/4, §7 insert points"
  critical: "§2: this task's failure action is `exit 0` — DIFFERENT from the sibling z-window.sh
       task (P1.M1.T2.S1) which uses `&& dir=\"$resolved\"`. Copy the §C/verbatim block, not S1's."

- file: tests/test_z_session.sh
  why: The test that must keep passing (pass=9). Its fake-zoxide is ALREADY hardened
        (P1.M1.T1.S1 = Complete): strips `--`, dumps 3 lines for `-l`/`--list`.
  critical: "Do NOT add a committed `-l` regression case here — P1.M1.T3.S2 owns those assertions.
             This task only modifies z-session.sh; the test stays at its current 7 cases / 9 checks."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T2S1/PRP.md
  why: The SIBLING task's PRP (z-window.sh guard). Establishes the canonical NL-literal + case/`-d`
       idiom this task mirrors. Read it to confirm the PATTERN, then apply the exit-0 adaptation.
  critical: "The IDIOM (NL literal + case newline-first + -d) is shared. The FAILURE ACTION differs:
       S1 uses `&& dir=\"$resolved\"` (keep default); S2 uses `|| exit 0` (skip respawn). Do not
       copy S1's arm verbatim — use the exit-0 form mandated by this item contract and §C."
```

### Current target block (verified live, `scripts/z-session.sh`)

The relevant tail of the guard chain (anchored on `resolved=$(resolve "$name")`):
```sh
# Resolve the name via the shared backend. Empty = no match -> nothing to do.
resolved=$(resolve "$name") || exit 0
[ -n "$resolved" ] || exit 0

# Relocate: restart the pane's shell in the resolved directory.
tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
```
And the file head (where the `NL` literal goes):
```sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/resolve.sh"

# Master toggle.
[ "$(get_tmux_option "@zoxide-sessions-auto-session" "on")" = "off" ] && exit 0
```

### Desired edits (two changes, paste-ready)

**Edit A** — insert the `NL` literal between the `. "$SCRIPT_DIR/lib/resolve.sh"` line and the `# Master toggle.` line:

```sh
. "$SCRIPT_DIR/lib/resolve.sh"

# Single newline, POSIX-portable (avoids the bash-only $'\n' form).
NL='
'

# Master toggle.
```
> The `NL='` … `'` block contains a **real newline** between the quotes (a genuine line break).
> It is NOT `NL='\n'` (that 2-char backslash-n literal would never match a real newline and the
> guard would never fire). The edit tool must preserve the literal newline byte.

**Edit B** — insert the guard **between** `[ -n "$resolved" ] || exit 0` and the `# Relocate:` comment:
```sh
# Resolve the name via the shared backend. Empty = no match -> nothing to do.
resolved=$(resolve "$name") || exit 0
[ -n "$resolved" ] || exit 0

# Defence in depth: accept `resolved` ONLY if it is a single existing
# directory; otherwise no-op (pane stays where it is).
case "$resolved" in
    *"$NL"*) exit 0 ;;                 # multi-line dump -> refuse to relocate
    *)       [ -d "$resolved" ] || exit 0 ;;
esac

# Relocate: restart the pane's shell in the resolved directory.
tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
```
> Diff vs current: ONLY the 6-line guard block (comment + `case`/`esac`) is inserted. The
> `resolved=$(resolve "$name") || exit 0` line, the `[ -n "$resolved" ] || exit 0` line, the
> `# Relocate:` comment, the `respawn-pane` line, and everything after it (the optional
> window-rename `case` + final `exit 0`) are **unchanged**.

### Current Codebase tree (scope of this PRP)

```bash
scripts/
  z-session.sh         # MODIFY: add NL literal + case/-d guard (this task)
  z-window.sh          # NOT TOUCHED (owned by P1.M1.T2.S1 — symmetric guard)
  lib/
    resolve.sh         # NOT TOUCHED (owned by P1.M1.T1.S2 — resolver -- guard)
tests/
  test_z_session.sh    # NOT TOUCHED (already hardened by P1.M1.T1.S1; -l regression = P1.M1.T3.S2)
  test_*.sh            # NOT TOUCHED
tmux-zoxide-sessions.tmux   # NOT TOUCHED (owned by P1.M2 — Issue 2 quoting)
README.md                   # NOT TOUCHED (owned by P1.M3.T1)
```

### Desired Codebase tree with files to be modified

```bash
scripts/z-session.sh   # ONLY this file. Two edits (NL literal + case/-d guard).
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (FAILURE ACTION): This task uses `exit 0` on failure, NOT the `dir="$resolved"` form.
#   The sibling z-window.sh task (S1) keeps a default dir (`*) [ -d ] && dir="$resolved"`); this
#   task MUST use `*) [ -d "$resolved" ] || exit 0` + `*"$NL"*) exit 0`. Why: z-session's job is
#   to RELOCATE an existing pane; if unsafe, the correct action is to DO NOTHING (exit 0), not to
#   fall back to a directory. Copy the §C/verbatim block above — do NOT copy S1's arm.

# CRITICAL (POSIX): The script is #!/bin/sh. Do NOT use $'\n' (bash/ksh-only ANSI-C quote),
#   [[ ]], or =~. The case "$resolved" in *"$NL"* idiom with a literal-newline NL variable is
#   the portable newline-containment test (research_issue1_defense.md §B/§C, findings §F4).

# CRITICAL (ordering): newline check FIRST (case arm), -d SECOND. A zoxide list-mode dump may
#   have a REAL directory on line 1 (the test fixture's dump is `$FIX/proj` + 2 non-existent
#   dirs). Only the newline arm rejects the whole multi-line value; a -d-only guard would test
#   only line 1 and could wrongly accept a truncated path. The case arm short-circuits first.

# CRITICAL (NL literal): NL must hold a REAL newline (line break between the quotes), not the
#   2-char backslash-n. Don't let an editor/formatter collapse it onto one line as NL='\n'.

# GOTCHA (no-op is exit 0): every other guard in this handler ends with `exit 0` on the "nothing
#   to do" path (master-off, no-name, skip-list, no-pane, not-$HOME, no-match). This guard is
#   CONSISTENT with that contract — `exit 0`, not `return`, not `dir=...`.

# GOTCHA (shellcheck SC1091): shellcheck emits SC1091 (info) on the PRE-EXISTING
#   `. "$SCRIPT_DIR/lib/resolve.sh"` line ("not following: sourced file"). This is NOT from your
#   edit — the original has it too; `-x` and passing resolve.sh as a second input do NOT silence
#   it (the source path is dynamic: `$SCRIPT_DIR`). The gate is "no NEW findings vs the original"
#   (diff shellcheck output before/after — identical). Your edits add ZERO findings.

# GOTCHA (no test dependency): tests/test_z_session.sh's fake-zoxide is ALREADY hardened
#   (P1.M1.T1.S1 = Complete): strips `--` and models list-mode (`-l`/`--list` -> 3-line dump).
#   So the suite is green at baseline and stays green after your edit (verified 9/0). Do NOT
#   edit the test.

# FORBIDDEN: Do NOT add a committed `-l`/`--list` regression assertion to any test file —
#   P1.M1.T3.S2 owns the z-session integration regression. Provide only a throwaway Level-4 proof.
# FORBIDDEN: Do NOT touch z-window.sh, resolve.sh, the run file, README, .gitignore, PRD.md,
#   tasks.json, or any prd_snapshot.md.
```

## Implementation Blueprint

### Data models and structure

N/A — pure shell. The only "model" is the validation contract on `resolved`: accept iff
(single-line) AND (existing directory), else `exit 0`. Represented as a 2-arm `case` + a `[ -d ]`
test, with `exit 0` (no-op) on either failure.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 0: BASELINE CHECK (run BEFORE editing — proves a clean starting point)
  - RUN: sh tests/test_z_session.sh
    Expected: "RESULTS: pass=9 fail=0".
    IF NOT 9/0: STOP. The suite is already red (most likely a half-applied sibling change);
      get it green before editing, or your edit will be blamed for the failure.

Task 1: EDIT scripts/z-session.sh — insert the NL literal (Edit A)
  - INSERT between the `. "$SCRIPT_DIR/lib/resolve.sh"` line and the `# Master toggle.` line:
        # Single newline, POSIX-portable (avoids the bash-only $'\n' form).
        NL='<newline>'
    where <newline> is a REAL line break between the quotes.
  - PRESERVE: the existing blank line structure; the `# Master toggle.` line and everything below.

Task 2: EDIT scripts/z-session.sh — insert the guard (Edit B)
  - INSERT the 6-line guard block (comment + case/esac) BETWEEN the
        [ -n "$resolved" ] || exit 0
    line and the
        # Relocate: restart the pane's shell in the resolved directory.
    comment, exactly as shown in "Desired edits -> Edit B".
  - PRESERVE: `resolved=$(resolve "$name") || exit 0`, `[ -n "$resolved" ] || exit 0`, the
    `# Relocate:` comment, the `respawn-pane` line, and the optional window-rename case + exit 0.
  - USE the EXIT-0 form: `*"$NL"*) exit 0 ;;` and `*) [ -d "$resolved" ] || exit 0 ;;`.
    Do NOT use the z-window.sh `&& dir="$resolved"` form — it is wrong here.
  - DO NOT: add `return`, `local`, `dir=`, an else branch, or any other file edit.

Task 3: VERIFY (no edits) — see Validation Loop.
```

### Implementation Patterns & Key Details

```sh
# The load-bearing change (before -> after), between the emptiness check and respawn-pane:
#
#   BEFORE:
#       resolved=$(resolve "$name") || exit 0
#       [ -n "$resolved" ] || exit 0
#       tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
#
#   AFTER:
#       resolved=$(resolve "$name") || exit 0
#       [ -n "$resolved" ] || exit 0
#       case "$resolved" in
#           *"$NL"*) exit 0 ;;                 # multi-line dump -> refuse to relocate
#           *)       [ -d "$resolved" ] || exit 0 ;;
#       esac
#       tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
#
# Why exit 0 (not the z-window.sh `&& dir=` form): z-session RELOCATES an existing pane. If the
#   resolved value is unsafe, the correct action is to DO NOTHING (pane stays where it landed) and
#   exit 0 — matching every other guard in this handler. There is no "default directory" to fall
#   back to; respawn is conditional, not guaranteed.
#
# Why case-first: a zoxide list-mode dump can have a REAL directory on line 1 (the test fixture's
#   dump is `$FIX/proj` then two non-existent dirs). The newline arm rejects the whole multi-line
#   value before `-d` is consulted; a -d-only guard would test line 1 and might accept a truncated
#   path. (research_issue1_defense.md §B/§C net-behavior table.)
#
# Why [ -d "$resolved" ] (not -e): we want a DIRECTORY. A regular file, broken symlink, or
#   non-existent path all fail -d -> exit 0 (no relocate). Empty string also fails -d, though the
#   pre-existing `[ -n "$resolved" ] || exit 0` already handles the empty case earlier.
```

### Integration Points

```yaml
CALLER CONTRACT (z-session.sh, unchanged surface):
  - Invoked by: the session-created hook: run-shell -b '<abs>/z-session.sh "#{session_name}"'.
  - Reads:      name="$1"; master toggle; skip-list; pane/path via tmux display-message;
                home-dir; resolves name via resolve().
  - NEW:        validates resolved (single-line + -d) before respawn-pane.
  - Acts:       tmux respawn-pane -t "$pane" -c "$resolved" -k; optional rename-window.
  - Net: normal matches relocate as before; corrupt/multi-line/non-dir resolved -> no-op (exit 0).

SIBLING GUARD (symmetry, not owned here):
  - scripts/z-window.sh gets the SAME NL-literal + case/-d idiom in P1.M1.T2.S1, but with the
    `&& dir="$resolved"` failure action (keep the default dir). This task mirrors the PATTERN
    with the `|| exit 0` adaptation. Both together enforce the contract at both callers.

DEPENDENCIES:
  - NONE hard. Works with or without the resolver `--` guard (P1.M1.T1.S2) — the guard validates
    resolve()'s output, not the resolver internals. The hardened fake-zoxide (P1.M1.T1.S1, already
    Complete) means a `-l`-named session would already yield the 3-line dump this guard catches.
```

## Validation Loop

### Level 0: Baseline (run BEFORE editing)

```bash
cd <repo>
sh tests/test_z_session.sh
# Expected: "RESULTS: pass=9 fail=0". If not green, STOP — fix the baseline first.
```

### Level 1: Syntax & Style (immediate, after the edits)

```bash
cd <repo>
sh -n scripts/z-session.sh && echo "syntax ok"

# ShellCheck — SC1091 (info) on the PRE-EXISTING source line is expected and present in the
# original too. Confirm your edits add NOTHING new: diff before/after.
shellcheck scripts/z-session.sh > /tmp/sc_after.txt 2>&1 || true
git stash >/dev/null 2>&1 && shellcheck scripts/z-session.sh > /tmp/sc_before.txt 2>&1 || true
git stash pop >/dev/null 2>&1 || true
if diff -u /tmp/sc_before.txt /tmp/sc_after.txt; then echo "shellcheck: ZERO new findings (identical to baseline)"; fi
# Expected: "syntax ok"; the diff is EMPTY (both before and after emit only the SC1091 info line).
```

### Level 2: Targeted edit verification (the change is exactly what was intended)

```bash
cd <repo>
echo "NL literal present (expect 1):"
grep -Fc "NL='" scripts/z-session.sh

echo "newline-reject case arm present (expect 1):"
grep -Fc '*"$NL"*) exit 0' scripts/z-session.sh

echo "directory-test no-op arm present (expect 1):"
grep -Fc '[ -d "$resolved" ] || exit 0' scripts/z-session.sh

echo "no bash-only \$'\\n' ANSI-C quote (expect 0):"
grep -Fc "\$'\\n'" scripts/z-session.sh

echo "pre-existing emptiness check still present BEFORE the guard (expect >=1):"
grep -Fc '[ -n "$resolved" ] || exit 0' scripts/z-session.sh
```
Expected: `1`, `1`, `1`, `0`, `>=1`.

### Level 3: Existing test suite (no regression — the gate)

```bash
cd <repo>
sh tests/test_z_session.sh
# Expected: "RESULTS: pass=9 fail=0".

# Optionally, the full suite (unchanged from baseline; this edit touches only z-session.sh):
total_pass=0; total_fail=0
for t in tests/test_*.sh; do
  line=$(sh "$t" 2>&1 | grep -E '^RESULTS:')
  p=$(echo "$line" | sed -n 's/.*pass=\([0-9]*\).*/\1/p')
  f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')
  [ -n "$p" ] && total_pass=$((total_pass+p)); [ -n "$f" ] && total_fail=$((total_fail+f))
  echo "$(basename "$t"): $line"
done
echo "TOTAL: pass=$total_pass fail=$total_fail"
# Expected: test_z_session.sh 9/0; full suite all-green (the same baseline as P1.M1.T2.S1).
```
Expected: `test_z_session.sh` 9/0. If it regresses, the most likely cause is the `-d` arm
mis-rejecting the normal `proj` match — re-check that the fake resolves to `$FIX/proj` (a real
dir) and that the guard's `[ -d "$resolved" ] || exit 0` is intact (not inverted to `&& exit 0`).

### Level 4: Defence-in-depth proof (throwaway — proves the guard fires; NOT committed)

This directly demonstrates the guard logic against simulated `resolve()` outputs, including the
Issue-1 multi-line dump. It is deterministic and needs no tmux server. (Do **not** save this as a
committed test — P1.M1.T3.S2 owns the committed z-session integration regression.)

```bash
NL='
'
FIX=$(mktemp -d); mkdir -p "$FIX/proj" "$FIX/other1" "$FIX/other2"
# Emulate the guard: returns 0 = RELOCATE, 1 = NO-OP (exit 0).
guard() {
    case "$1" in
        *"$NL"*) return 1 ;;                 # multi-line dump -> refuse
        *)       [ -d "$1" ] || return 1 ;;
    esac
    return 0
}
check() {  # check <desc> <resolved> <expect: relocate|noop>
    guard "$2"; rc=$?
    got=$([ $rc -eq 0 ] && echo relocate || echo noop)
    if [ "$got" = "$3" ]; then echo "PASS  $1 -> $got"; else echo "FAIL  $1 -> $got (want $3)"; fi
}
check "normal single-line dir"   "$FIX/proj"            relocate
check "empty / no-match"         ""                     noop
check "non-existent single line" "$FIX/does-not-exist"  noop
DUMP="$FIX/proj
$FIX/other1
$FIX/other2"
check "multi-line DB dump (-l)"  "$DUMP"                noop
echo "(the dump's first line IS a real dir, yet the newline arm rejects the whole value)"
rm -rf "$FIX"
```
Expected: 4× PASS. The dump case is the key — it proves a multi-line value is rejected by the
newline arm alone, even when line 1 is a real directory.

For an optional **end-to-end** check against a live isolated tmux server + the hardened fake
(mirrors `tests/test_z_session.sh`'s machinery but invokes a `-l`-named session directly): create a
session named `-l` in `$HOME`, run `z-session.sh -l`, and assert the pane's `#{pane_current_path}`
stays at `$HOME` (NOT relocated to the dump's first line). This is exactly what P1.M1.T3.S2's
committed integration regression will encode; running it manually here is a confidence check only.

## Final Validation Checklist

### Technical Validation

- [ ] Level 0 baseline was 9/0 (clean starting point).
- [ ] `sh -n scripts/z-session.sh` ok.
- [ ] ShellCheck diff (before/after) is EMPTY — edits add zero new findings (only pre-existing SC1091).
- [ ] Level 2 grep checks return `1`, `1`, `1`, `0`, `>=1`.
- [ ] `sh tests/test_z_session.sh` → pass=9 fail=0.

### Feature Validation

- [ ] A single-line, existing-directory `resolved` is accepted (normal match relocates) — no behavior change.
- [ ] A multi-line `resolved` (zoxide `-l` dump) is rejected → handler exits 0, pane stays put.
- [ ] A non-existent / non-directory `resolved` is rejected → handler exits 0, pane stays put.
- [ ] Empty / no-match `resolved` still `exit 0`s early (unchanged).
- [ ] Level 4 proof shows 4/4 PASS including the multi-line-dump rejection.

### Code Quality Validation

- [ ] POSIX-`sh` clean (no `$'\n'`, no `[[ ]]`, no `=~`, no `local`).
- [ ] No new ShellCheck findings (SC1091 on the source line is pre-existing).
- [ ] No other file modified (scope = `scripts/z-session.sh` only).
- [ ] Guard uses the EXIT-0 failure action (`|| exit 0`), NOT the z-window.sh `&& dir=` form.
- [ ] Guard ordering is newline-first then `-d` (correct for dumps with a real dir on line 1).

### Documentation & Deployment

- [ ] Inline comment explains WHY the guard exists ("defence in depth … multi-line dump … non-directory").
- [ ] No README/config change (internal hardening; observable behavior for normal sessions is unchanged).
      Docs sync is P1.M3.T1 — out of scope here.

---

## Anti-Patterns to Avoid

- ❌ Don't copy the z-window.sh (S1) guard's `&& dir="$resolved"` arm — it is wrong here. z-session's
  failure action is `exit 0` (do nothing), because the handler relocates conditionally. Use
  `*"$NL"*) exit 0 ;;` and `*) [ -d "$resolved" ] || exit 0 ;;` (the §C/verbatim block).
- ❌ Don't use the PRD's suggested one-liner (`[ -n ] && [ -z "${…##*$'\n'*}" ] || { … }`) — it uses
  the bash-only `$'\n'` AND has inverted logic (findings_and_risks.md §F4). Use the `case "$resolved"
  in *"$NL"*` idiom.
- ❌ Don't put the `-d` test before the newline check. A list-mode dump can have a real dir on line 1;
  the newline arm is the only thing that reliably rejects the whole value. Order: newline-first.
- ❌ Don't collapse `NL='` + newline + `'` into `NL='\n'` — that 2-char literal never matches a real
  newline and the guard silently never fires.
- ❌ Don't remove the pre-existing `[ -n "$resolved" ] || exit 0` line — the item contract says INSERT
  the guard BETWEEN it and `respawn-pane`. The emptiness check runs first; the guard handles the
  multi-line/non-dir cases.
- ❌ Don't add `return` / `dir=` / an else branch — this is a sourced? No, executed handler; `exit 0`
  is the no-op idiom used by every other guard in the file.
- ❌ Don't add a committed `-l`/`--list` regression test assertion — P1.M1.T3.S2 owns those.
- ❌ Don't touch `z-window.sh` (P1.M1.T2.S1), `resolve.sh` (P1.M1.T1.S2), the run file (P1.M2),
  README (P1.M3.T1), or any test file (P1.M1.T1.S1 done; P1.M1.T3 pending).
- ❌ Don't edit before confirming the 9/0 baseline (Level 0) — a red baseline will be misattributed.
- ❌ Don't modify `.gitignore`, `PRD.md`, `tasks.json`, or any `prd_snapshot.md`.

---

## Scope Boundaries (explicit)

| Concern | This subtask (P1.M1.T2.S2) | Other subtasks |
| --- | --- | --- |
| `scripts/z-session.sh` newline-reject + `-d` guard | ✅ MODIFY (NL literal + guard block) | — |
| `scripts/z-window.sh` symmetric guard | ❌ DO NOT | P1.M1.T2.S1 |
| `scripts/lib/resolve.sh` `--` guard + comment | ❌ DO NOT | P1.M1.T1.S2 |
| fake-zoxide fixture hardening (strip `--`, list-mode) | ❌ DO NOT (already Complete) | P1.M1.T1.S1 |
| `-l`/`--list` committed regression test assertions | ❌ DO NOT | P1.M1.T3.S1 (unit) / S2 (integration) |
| `tmux-zoxide-sessions.tmux` `%%` quoting (Issue 2) | ❌ DO NOT | P1.M2.T1 |
| `README.md`, `.gitignore`, `PRD.md`, `tasks.json` | ❌ FORBIDDEN / other tasks | P1.M3 / orchestrator |

---

**Confidence Score: 9.5/10** — The edit is a self-contained 6-line guard (NL literal already shared
with the sibling task's idiom) in one file, with the exact old/new blocks given verbatim and the
insert points verified live. The guard logic is proven 4/4 (including the critical multi-line-dump
whose first line is a real dir). The **full integration harness was run against a guarded temp copy
and passed 9/0** (no regression to any of the 7 cases). ShellCheck adds zero new findings (the lone
SC1091 is pre-existing on the source line, identical before/after). The task has no hard dependency
on the parallel resolver fix (it validates output, not resolver internals). The residual 0.5 is the
inherent risk that an editor collapses the load-bearing `NL` newline literal onto one line —
mitigated by an explicit gotcha, the Level-2 grep (`grep -Fc "NL='"` → 1), and the Level-4
dump-rejection proof (which only passes with a real newline).
