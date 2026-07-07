# PRP — P1.M1.T2.S1: Add newline-reject + directory-exists guard to `z-window.sh`

## Goal

**Feature Goal**: Add a POSIX-portable defence-in-depth guard to `scripts/z-window.sh` so that a `resolved` value from `resolve()` is accepted as the new window's directory **only if** it is (1) a single line (no embedded newline) and (2) an existing directory (`-d`). If either check fails — e.g. a multi-line zoxide list-mode database dump (the Issue-1 symptom) or any non-directory string — `dir` stays at the current pane path (`$cur`). This is **Layer 2 (caller-side defence-in-depth)** of the Issue-1 remediation; the root fix (the resolver `--` guard) is owned by P1.M1.T1.S2.

**Deliverable**: A single surgical edit to **one** file — `scripts/z-window.sh`. Two logical changes:
1. Insert a POSIX newline literal `NL='<newline>'` after the `. resolve.sh` source line.
2. Replace the `if [ -n "$query" ] … fi` block (the unguarded `dir="$resolved"` assignment) with a `case`/`-d` guard that validates `resolved` before using it.

**Success Definition**:
- `z-window.sh` accepts a single-line, existing-directory `resolved` (normal match → window opens in resolved dir, named after basename). **No behavior change for normal queries.**
- `z-window.sh` rejects (falls back to `$cur`) any `resolved` that contains a newline **or** is not an existing directory.
- Empty / no-match still falls back to `$cur` (unchanged).
- `shellcheck scripts/z-window.sh scripts/lib/resolve.sh` reports nothing (no new findings vs original).
- `sh tests/test_z_window.sh` → `RESULTS: pass=11 fail=0` (the existing suite; verified green at baseline).
- No other file is modified; no new committed test assertions (those belong to P1.M1.T3).

## User Persona

**Target User**: The implementing AI agent (1-point task). Downstream: P1.M1.T2.S2 (symmetric guard in `z-session.sh`) and P1.M1.T3.S1/S2 (committed regression tests).

**Use Case**: A tmux user presses `prefix g`, types any query. If the resolver ever regresses (or any future backend returns a non-directory / multi-line value), the window still opens in a sane, single, existing directory (the current pane path) instead of being corrupted.

**Pain Points Addressed**: Eliminates the single-point-of-failure where `tmux new-window -c "$dir"` could receive a 146-line database dump (Issue 1's exact symptom: `pane_start_path` = whole dump, window named after a random last-line basename).

## Why

- This is **Layer 2** of the three-layer Issue-1 fix defined in `architecture/system_context.md §4` and detailed in `architecture/research_issue1_defense.md §B`. Layer 1 (resolver `--` guard) is P1.M1.T1.S2; Layer 3 (regression tests) is P1.M1.T3. Each layer is independently effective.
- **Defence-in-depth is the contract**: even if the resolver is later re-broken (as it was by commit `b93e776`), the caller refuses to act on a corrupt value. The guard validates `resolve()`'s output, so it works whether or not Layer 1 is present — it is genuinely order-independent (no hard dependency on P1.M1.T1.S2).
- It is cheap (4-line idiom), POSIX-portable, and the same pattern P1.M1.T2.S2 mirrors in `z-session.sh` for symmetry.

## What

User-visible behavior: **no change for normal queries**. The only observable difference is in the failure/edge modes — a multi-line or non-directory `resolved` that previously corrupted the window now silently falls back to the current pane path (the documented PRD §3.1 contract: "no-match must fall back to the current pane path").

### Success Criteria

- [ ] `grep -c "NL='" scripts/z-window.sh` → `1` (the newline literal exists).
- [ ] `grep -c '\*"\$NL"\*' scripts/z-window.sh` → `1` (the newline-reject case arm exists).
- [ ] `grep -c '\[ -d "\$resolved" \] && dir="\$resolved"' scripts/z-window.sh` → `1` (the directory test + conditional assignment).
- [ ] `grep -c '\[ -n "\$resolved" \] && dir="\$resolved"' scripts/z-window.sh` → `0` (the OLD unguarded line is gone).
- [ ] `grep -c "\$'\\\\n'" scripts/z-window.sh` → `0` (no bash-only `$'\n'` ANSI-C quote introduced).
- [ ] `shellcheck scripts/z-window.sh scripts/lib/resolve.sh` → no errors/warnings.
- [ ] `sh -n scripts/z-window.sh` → ok.
- [ ] `sh tests/test_z_window.sh` → `RESULTS: pass=11 fail=0`.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The exact current content of the target lines, the exact replacement block (verbatim, paste-ready), the POSIX constraint (with the forbidden bashism called out by name), the validation commands (all verified working), the empirical guard-logic proof, and the scope boundaries (do-not-touch list) are all below. No broader codebase knowledge is required.

### Documentation & References

```yaml
# MUST READ
- file: scripts/z-window.sh
  why: THE file being edited. See "Current target block" below for exact lines.
  pattern: "#!/bin/sh POSIX script. Sources lib/resolve.sh; reads pane path/session via
            `tmux display-message -p`; sets dir=$cur as default; resolves query; new-window."
  gotcha: "dir=$cur is set BEFORE the if-block (line 27), so 'fall back to $cur' = 'don't
           reassign dir'. Do NOT add an else/return — just don't touch dir on failure."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_issue1_defense.md
  why: §B is the authoritative design for THIS guard (newline-reject + -d). Explains why the
       case-first ordering matters (a dump of REAL dirs is rejected by the newline arm alone).
  section: "§B z-window.sh — defence-in-depth guard design (incl. the net-behavior table)"
  critical: "Order matters: newline check FIRST (case arm), then -d. A 146-line dump whose every
       line is a real dir must still be rejected — only the newline arm catches that."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/findings_and_risks.md
  why: §F4 documents WHY the PRD's suggested one-liner is rejected (bashism + inverted logic).
  section: "§F4 (the non-POSIX one-liner)"
  critical: "Do NOT copy `[ -n \"\$resolved\" ] && [ -z \"\${resolved##*\$'\\n'*}\" ] || {...}`. It uses
       the bash/ksh-only \$'\\n' and its logic is inverted. Use the case/\"\$NL\" idiom instead."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T2S1/research/research_notes.md
  why: Empirical proof: guard logic 4/4 pass; shellcheck adds no findings; baseline test_z_window.sh
       is pass=11; the guard is order-independent of the resolver -- fix (both states verified).
  section: "§3 guard logic table, §2 shellcheck, §4 no-dependency-on-T1.S2, §7 NL literal gotcha"

- file: tests/test_z_window.sh
  why: The test that must keep passing (pass=11). Its fake-zoxide is ALREADY hardened (P1.M1.T1.S1
        Complete): strips `--`, dumps 3 lines for `-l`/`--list`. So a `-l` query already produces
        the dump this guard catches.
  critical: "Do NOT add a committed `-l` regression case here — P1.M1.T3.S1/S2 own those assertions.
             This task only modifies z-window.sh; the test stays at its current 4 cases / 11 checks."

- file: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T1S2/PRP.md
  why: The parallel resolver -- guard PRP. Documents that this task (Layer 2) is independent of it
        (Layer 1) — confirmed by §4 of research_notes.md.
  critical: "NO hard ordering dependency. This guard validates resolve()'s output, so it is correct
             whether or not resolve.sh has the -- guard. Do NOT edit resolve.sh here (T1.S2 owns it)."
```

### Current target block (verified live, `scripts/z-window.sh` lines 17–35)

```sh
17  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
18  . "$SCRIPT_DIR/lib/resolve.sh"
19
20  query="$*"
21
22  # Pull the current pane's directory and session from the live tmux server.
23  cur=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
24  [ -z "$cur" ] && cur="$HOME"
25  session=$(tmux display-message -p '#{session_name}' 2>/dev/null)
26
27  dir="$cur"
28
29  if [ -n "$query" ]; then
30      resolved=$(resolve "$query")
31      [ -n "$resolved" ] && dir="$resolved"      # <-- UNGUARDED: accepts ANY non-empty value
32  fi
33
34  base=$(basename "$dir")
35  tmux new-window -t "$session:" -c "$dir" -n "$base"
```

### Desired edits (two changes, paste-ready)

**Edit A** — insert the `NL` literal between line 18 (`. resolve.sh`) and line 20 (`query="$*"`):

```sh
. "$SCRIPT_DIR/lib/resolve.sh"

# Single newline, POSIX-portable (avoids the bash-only $'\n' form).
NL='
'

query="$*"
```

> The `NL='` … `'` block contains a **real newline** between the quotes (a genuine line break).
> It is NOT `NL='\n'` (that 2-char backslash-n literal would never match a real newline and the
> guard would never fire). The edit tool must preserve the literal newline byte.

**Edit B** — replace lines 29–32 (the `if … fi` block) with:

```sh
if [ -n "$query" ]; then
    resolved=$(resolve "$query")
    # Defence in depth: accept `resolved` ONLY if it is a single line that is
    # an existing directory. A multi-line value (e.g. a zoxide list-mode dump)
    # or any non-directory falls back to the current pane path.
    case "$resolved" in
        *"$NL"*) : ;;                  # multi-line -> reject, keep dir=$cur
        *)        [ -d "$resolved" ] && dir="$resolved" ;;
    esac
fi
```

> Diff vs current: the old `[ -n "$resolved" ] && dir="$resolved"` (line 31) is replaced by the
> `case`/`-d` guard. The `if [ -n "$query" ]`, `resolved=$(resolve "$query")`, the closing `fi`,
> and lines 34–35 (`base`/`new-window`) are **unchanged**. The `[ -n "$resolved" ]` emptiness
> check is now subsumed: an empty `resolved` hits the `*)` arm and `[ -d "" ]` is false → `dir`
> stays `$cur`.

### Current Codebase tree (scope of this PRP)

```bash
scripts/
  z-window.sh          # MODIFY: add NL literal + replace if-block guard (this task)
  z-session.sh         # NOT TOUCHED (owned by P1.M1.T2.S2 — symmetric guard)
  lib/
    resolve.sh         # NOT TOUCHED (owned by P1.M1.T1.S2 — resolver -- guard)
tests/
  test_z_window.sh     # NOT TOUCHED (already hardened by P1.M1.T1.S1; regression cases = P1.M1.T3)
  test_*.sh            # NOT TOUCHED
tmux-zoxide-sessions.tmux   # NOT TOUCHED (owned by P1.M2 — Issue 2 quoting)
README.md                   # NOT TOUCHED (owned by P1.M3.T1)
```

### Desired Codebase tree with files to be modified

```bash
scripts/z-window.sh   # ONLY this file. Two edits (NL literal + case/-d guard).
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (POSIX): The script is #!/bin/sh. Do NOT use $'\n' (bash/ksh-only ANSI-C quote),
#   [[ ]], or =~. The case "$resolved" in *"$NL"* idiom with a literal-newline NL variable is
#   the portable newline-containment test (research_issue1_defense.md §B, findings §F4).

# CRITICAL (ordering): newline check FIRST (case arm), -d SECOND. A zoxide list-mode dump may
#   consist entirely of REAL directory paths — only the newline arm rejects it; -d alone would
#   wrongly accept the first line. The case arm short-circuits before -d on any multi-line value.

# CRITICAL (NL literal): NL must hold a REAL newline (line break between the quotes), not the
#   2-char backslash-n. Don't let an editor/formatter collapse it onto one line as NL='\n'.

# GOTCHA (fallback is a no-op): dir=$cur is set on line 27 BEFORE the if-block. "Fall back to
#   $cur" therefore means "do not reassign dir" — no else branch, no return, no exit. The
#   *) arm's `&& dir="$resolved"` only fires when -d is true; otherwise dir is untouched.

# GOTCHA (shellcheck SC1091): shellcheck emits SC1091 (info) on the PRE-EXISTING
#   `. "$SCRIPT_DIR/lib/resolve.sh"` line ("not following: sourced file"). This is NOT from your
#   edit — the original has it too. For a fully clean run, pass both files:
#     shellcheck scripts/z-window.sh scripts/lib/resolve.sh
#   (or `shellcheck -x scripts/z-window.sh` in-repo). Your edits add ZERO findings.

# GOTCHA (no test dependency): The existing tests/test_z_window.sh fake is ALREADY hardened
#   (P1.M1.T1.S1 = Complete): it strips `--` and models list-mode. So the suite is green at
#   baseline and stays green after your edit. Do NOT harden/edit the test here.

# FORBIDDEN: Do NOT add a committed `-l`/`--list` regression assertion to any test file —
#   P1.M1.T3.S1/S2 own those. Provide only a throwaway Level-4 proof (see Validation Loop).
# FORBIDDEN: Do NOT touch resolve.sh, z-session.sh, the run file, README, .gitignore, PRD.md,
#   tasks.json, or any prd_snapshot.md.
```

## Implementation Blueprint

### Data models and structure

N/A — pure shell. The only "model" is the validation contract on `resolved`: accept iff
(single-line) AND (existing directory). Represented as a 2-arm `case` + a `[ -d ]` test.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 0: BASELINE CHECK (run BEFORE editing — proves a clean starting point)
  - RUN: sh tests/test_z_window.sh
    Expected: "RESULTS: pass=11 fail=0".
    IF NOT 11/0: STOP. The suite is already red (most likely a half-applied sibling change);
      get it green before editing, or your edit will be blamed for the failure.

Task 1: EDIT scripts/z-window.sh — insert the NL literal (Edit A)
  - INSERT between the `. "$SCRIPT_DIR/lib/resolve.sh"` line and the `query="$*"` line:
        # Single newline, POSIX-portable (avoids the bash-only $'\n' form.
        NL='<newline>'
    where <newline> is a REAL line break between the quotes.
  - PRESERVE: the existing blank line structure; the `query="$*"` line and everything below.

Task 2: EDIT scripts/z-window.sh — replace the if-block guard (Edit B)
  - REPLACE the block:
        if [ -n "$query" ]; then
            resolved=$(resolve "$query")
            [ -n "$resolved" ] && dir="$resolved"
        fi
    WITH the case/-d guard shown in "Desired edits → Edit B".
  - PRESERVE: `resolved=$(resolve "$query")`, the `if`/`fi`, and lines 34-35 (base/new-window).
  - DO NOT: add `else`, `return`, `exit`, `local`, or any other file edit.

Task 3: VERIFY (no edits) — see Validation Loop.
```

### Implementation Patterns & Key Details

```sh
# The load-bearing change (before -> after), inside the if [ -n "$query" ] block:
#   BEFORE:  [ -n "$resolved" ] && dir="$resolved"
#   AFTER:   case "$resolved" in
#                *"$NL"*) : ;;                       # multi-line -> reject (dir stays $cur)
#                *)        [ -d "$resolved" ] && dir="$resolved" ;;
#            esac
#
# Why case-first: a zoxide list-mode dump can be 146 REAL directory paths. `-d` on such a value
# would test only... actually -d tests the WHOLE multi-line string as one path (false) — but relying
# on that is fragile. The newline arm is the explicit, readable, portable "this is multi-line" gate;
# it fires before -d and documents intent. (research_issue1_defense.md §B net-behavior table.)
#
# Why [ -d "$resolved" ] (not -e): we want a DIRECTORY specifically. A regular file, a broken
# symlink, or a non-existent path all fail -d -> fall back to $cur. Empty string also fails -d.
#
# Why && dir="$resolved" (one-liner): if -d fails, dir is simply not reassigned — it keeps the
# $cur value set on line 27. No else needed. This mirrors the original idiom's brevity.
```

### Integration Points

```yaml
CALLER CONTRACT (z-window.sh, unchanged surface):
  - Reads:    query="$*" (recombines spaces); cur/session via tmux display-message.
  - Resolves: resolved=$(resolve "$query").
  - NEW:      validates resolved (single-line + -d) before assigning dir.
  - Acts:     tmux new-window -t "$session:" -c "$dir" -n "$(basename "$dir")".
  - Net: normal matches unchanged; corrupt/multi-line/non-dir resolved -> window in $cur.

SIBLING GUARD (symmetry, not owned here):
  - scripts/z-session.sh gets the SAME idiom before `tmux respawn-pane -c "$resolved"`
    in P1.M1.T2.S2. This task establishes the canonical form (NL literal + case/-d) for S2 to mirror.

DEPENDENCIES:
  - NONE hard. Works with or without the resolver `--` guard (P1.M1.T1.S2) — verified both states
    (research_notes.md §4). The hardened fake (P1.M1.T1.S1, already Complete) means a `-l` query
    already yields the dump this guard catches.
```

## Validation Loop

### Level 0: Baseline (run BEFORE editing)

```bash
cd <repo>
sh tests/test_z_window.sh
# Expected: "RESULTS: pass=11 fail=0". If not green, STOP — fix the baseline first.
```

### Level 1: Syntax & Style (immediate, after the edits)

```bash
cd <repo>
sh -n scripts/z-window.sh && echo "syntax ok"

# ShellCheck — give it BOTH files so it can follow the sourced resolve.sh (otherwise it emits
# a benign SC1091 info on the pre-existing source line). Expected: no errors/warnings.
shellcheck scripts/z-window.sh scripts/lib/resolve.sh
# (Equivalently: shellcheck -x scripts/z-window.sh  — works in-repo where scripts/lib/resolve.sh exists.)
```
Expected: `syntax ok`; ShellCheck reports nothing.

### Level 2: Targeted edit verification (the change is exactly what was intended)

```bash
cd <repo>
echo "NL literal present (expect 1):"
grep -c "^NL='" scripts/z-window.sh

echo "newline-reject case arm present (expect 1):"
grep -c '\*"\$NL"\*' scripts/z-window.sh

echo "directory-test conditional assignment present (expect 1):"
grep -c '\[ -d "\$resolved" \] && dir="\$resolved"' scripts/z-window.sh

echo "OLD unguarded line GONE (expect 0):"
grep -c '\[ -n "\$resolved" \] && dir="\$resolved"' scripts/z-window.sh

echo "no bash-only \$'\\n' ANSI-C quote (expect 0):"
grep -c "\$'\\\\n'" scripts/z-window.sh
```
Expected: `1`, `1`, `1`, `0`, `0`.

### Level 3: Existing test suite (no regression — the gate)

```bash
cd <repo>
sh tests/test_z_window.sh
# Expected: "RESULTS: pass=11 fail=0".

# Optionally, the full suite (unchanged from baseline; this edit touches only z-window.sh):
total_pass=0; total_fail=0
for t in tests/test_*.sh; do
  line=$(sh "$t" 2>&1 | grep -E '^RESULTS:')
  p=$(echo "$line" | sed -n 's/.*pass=\([0-9]*\).*/\1/p')
  f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')
  [ -n "$p" ] && total_pass=$((total_pass+p)); [ -n "$f" ] && total_fail=$((total_fail+f))
  echo "$(basename "$t"): $line"
done
echo "TOTAL: pass=$total_pass fail=$total_fail"
# Expected TOTAL: pass=80 fail=0 (the same baseline P1.M1.T1.S2's PRP targets; all green).
```
Expected: `test_z_window.sh` 11/0; full suite 80/0. If `test_z_window.sh` regresses, the most
likely cause is the guard mis-rejecting the normal `proj` match — re-check that the `*)` arm's
`[ -d "$resolved" ]` is intact and `$FIX/proj` is a real dir (the test creates it).

### Level 4: Defence-in-depth proof (throwaway — proves the guard fires; NOT committed)

This directly demonstrates the guard logic against simulated `resolve()` outputs, including the
Issue-1 multi-line dump. It is deterministic and needs no tmux server. (Do **not** save this as a
committed test — P1.M1.T3.S1/S2 own the committed regression assertions.)

```bash
cd <repo>
NL='
'
PROJ=$(mktemp -d); mkdir -p "$PROJ/proj" "$PROJ/other1" "$PROJ/other2"; CUR="$PROJ/curbase"
check_guard() {  # check_guard <desc> <resolved> <expected-dir>
    resolved="$2"; dir="$CUR"
    case "$resolved" in *"$NL"*) : ;; *) [ -d "$resolved" ] && dir="$resolved" ;; esac
    if [ "$dir" = "$3" ]; then echo "PASS  $1 -> dir=[$(basename "$dir")]"; else echo "FAIL  $1 -> dir=[$dir]"; fi
}
check_guard "normal single-line dir"   "$PROJ/proj"        "$PROJ/proj"
check_guard "empty / no-match"         ""                  "$CUR"
check_guard "non-existent single line" "$PROJ/does-not-exist" "$CUR"
DUMP="$PROJ/proj
$PROJ/other1
$PROJ/other2"
check_guard "multi-line DB dump (-l)"  "$DUMP"             "$CUR"
echo "(every dump line above is a REAL dir, yet the newline arm rejects the whole value)"
rm -rf "$PROJ"
```
Expected: 4× PASS. The dump case is the key — it proves a multi-line value is rejected by the
newline arm alone, even when each line is a real directory.

For an optional **end-to-end** check against a live isolated tmux server + the hardened fake
(mirrors `tests/test_z_window.sh`'s machinery but invokes `-l` directly), query `-l` and assert
the newest window's `pane_start_path` equals `$cur` (NOT a 3-line dump) and `window_name` equals
`basename($cur)`. This is exactly what P1.M1.T3.S2's committed integration regression will encode;
running it manually here is a confidence check only.

## Final Validation Checklist

### Technical Validation

- [ ] Level 0 baseline was 11/0 (clean starting point).
- [ ] `sh -n scripts/z-window.sh` ok.
- [ ] `shellcheck scripts/z-window.sh scripts/lib/resolve.sh` reports nothing.
- [ ] Level 2 grep checks return `1`, `1`, `1`, `0`, `0`.
- [ ] `sh tests/test_z_window.sh` → pass=11 fail=0.

### Feature Validation

- [ ] A single-line, existing-directory `resolved` is accepted (normal match) — no behavior change.
- [ ] A multi-line `resolved` (zoxide `-l` dump) is rejected → window opens in `$cur`.
- [ ] A non-existent / non-directory `resolved` is rejected → window opens in `$cur`.
- [ ] Empty / no-match `resolved` falls back to `$cur` (unchanged).
- [ ] Level 4 proof shows 4/4 PASS including the multi-line-dump rejection.

### Code Quality Validation

- [ ] POSIX-`sh` clean (no `$'\n'`, no `[[ ]]`, no `=~`, no `local`).
- [ ] No new ShellCheck findings (SC1091 on the source line is pre-existing).
- [ ] No other file modified (scope = `scripts/z-window.sh` only).
- [ ] Guard ordering is newline-first then `-d` (correct for dumps of real dirs).

### Documentation & Deployment

- [ ] Inline comment explains WHY the guard exists ("defence in depth … multi-line dump … non-directory").
- [ ] No README/config change (internal hardening; the PRD §3.1 fallback contract is unchanged in
      observable behavior for normal queries). Docs sync is P1.M3.T1 — out of scope here.

---

## Anti-Patterns to Avoid

- ❌ Don't use the PRD's suggested one-liner (`[ -n ] && [ -z "${…##*$'\n'*}" ] || { … }`) — it
  uses the bash-only `$'\n'` AND has inverted logic (findings_and_risks.md §F4). Use the
  `case "$resolved" in *"$NL"*` idiom.
- ❌ Don't put the `-d` test before the newline check. A list-mode dump can be all real dirs;
  the newline arm is the only thing that reliably rejects it. Order: newline-first.
- ❌ Don't collapse `NL='` + newline + `'` into `NL='\n'` — that 2-char literal never matches a
  real newline and the guard silently never fires.
- ❌ Don't add an `else dir="$cur"` / `return` / `exit` — `dir=$cur` is already the default set
  before the block; "fallback" = "don't reassign". Adding `else` is harmless but noisy/needless.
- ❌ Don't add a committed `-l`/`--list` regression test assertion — P1.M1.T3.S1/S2 own those.
- ❌ Don't touch `resolve.sh` (P1.M1.T1.S2), `z-session.sh` (P1.M1.T2.S2), the run file (P1.M2),
  or any test file (P1.M1.T1.S1 done; P1.M1.T3 pending).
- ❌ Don't edit before confirming the 11/0 baseline (Level 0) — a red baseline will be misattributed.
- ❌ Don't modify `.gitignore`, `PRD.md`, `tasks.json`, or any `prd_snapshot.md`.

---

## Scope Boundaries (explicit)

| Concern | This subtask (P1.M1.T2.S1) | Other subtasks |
| --- | --- | --- |
| `scripts/z-window.sh` newline-reject + `-d` guard | ✅ MODIFY (NL literal + if-block) | — |
| `scripts/z-session.sh` symmetric guard | ❌ DO NOT | P1.M1.T2.S2 |
| `scripts/lib/resolve.sh` `--` guard + comment | ❌ DO NOT | P1.M1.T1.S2 |
| fake-zoxide fixture hardening (strip `--`, list-mode) | ❌ DO NOT (already Complete) | P1.M1.T1.S1 |
| `-l`/`--list` committed regression test assertions | ❌ DO NOT | P1.M1.T3.S1 (unit) / S2 (integration) |
| `tmux-zoxide-sessions.tmux` `%%` quoting (Issue 2) | ❌ DO NOT | P1.M2.T1 |
| `README.md`, `.gitignore`, `PRD.md`, `tasks.json` | ❌ FORBIDDEN / other tasks | P1.M3 / orchestrator |

---

**Confidence Score: 9.5/10** — The edit is a self-contained 4-line idiom in one file, with the
exact old/new blocks given verbatim and line numbers verified live. The guard logic is proven
4/4 (including the critical multi-line-dump-of-real-dirs case). ShellCheck adds zero new findings
(the lone SC1091 is the pre-existing source line). The baseline test is confirmed pass=11 fail=0,
and the change is behavior-preserving for all 4 existing cases. The task has no hard dependency
on the parallel resolver fix (it validates output, not the resolver internals). The residual 0.5
is the inherent risk that an editor collapses the load-bearing `NL` newline literal onto one line
— mitigated by an explicit gotcha and the Level-2 grep check (`grep -c "^NL='"` → 1, which would
fail if `NL='\n'` were written instead, since that line wouldn't start with `NL='` followed by a
newline... note: `grep "^NL='"` matches both `NL='<newline>` and `NL='\n'`; the definitive check
is the Level-4 dump-rejection proof, which only passes with a real newline).
