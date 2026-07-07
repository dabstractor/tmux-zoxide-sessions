# PRP — P1.M3.T1.S1 (bugfix 001): Review and update README.md to reflect bugfix changes

## Goal

**Feature Goal**: Perform the **changeset-level documentation sync** (Mode B) for bugfix 001
(Issue 1: zoxide flag absorption; Issue 2: single-quote query breakage). Sweep **all** of
`README.md` for any overview/feature/limitation content that the bugfix changeset rendered
stale or contradictory, and update **only what is genuinely inaccurate**. The item contract's
expected outcome — confirmed by this research — is **"the README is already accurate; NO
edits are required."** The deliverable is therefore primarily a **decision record**, not a
diff: confirm each section still matches the fixed behavior, and if (against expectation) a
statement is stale, make the minimal surgical fix.

**Deliverable**: Two possible outcomes, in priority order —
1. **(EXPECTED — this research's finding)** `README.md` **UNTOUCHED** + a written decision
   record (in `research/doc_sync_review.md`, already authored during planning) that names
   every reviewed section and the "NO CHANGE" rationale. This is the correct,
   contract-compliant outcome: "If the README is already accurate after the fixes, make NO
   changes and document why… Do NOT manufacture documentation churn."
2. **(ONLY if a section is genuinely stale)** a minimal, surgical edit to `README.md`
   correcting the one inaccurate statement, plus a note in the decision record explaining
   the edit. The review below found **no** such statement, so this branch is not expected to
   fire — but the criteria are specified so the implementer can reach it confidently if a
   fresh read disagrees.

**Success Definition**:
- Every README section (Overview/Why, Install, Usage/Window-jump, Usage/Session-relocate,
  Options table, **Backends**, Scope & compatibility, **Known limitations**, License) has
  been compared against the fixed behavior and the comparison is recorded.
- `README.md` either has **zero diff** (expected) or a minimal justified edit.
- The README contains **no statement that contradicts the fixed behavior** (verified by the
  grep gates in the Validation Loop).
- The decision record explains the (likely null) outcome and documents the two non-obvious
  points: (a) the `--` guard state discrepancy and why the decision is robust to it; (b) the
  residual-edge-case (`$`/`` ` ``/`\`/`"` queries) deliberately NOT added as a limitation.
- No source file, test file, `.gitignore`, `PRD.md`, or any other artifact is touched. This
  is a **docs-only** task.

## User Persona

**Target User**: The implementing AI agent (1-point, docs-only task). Downstream: anyone
reading the shipped README for v1.0.1, and the release validation (which checks the README
doesn't contradict the fixed behavior).

**Use Case**: A user reads the README to understand what the plugin does and its limits.
After the bugfix, the README must still be truthful — no claim should describe the old
(buggy) behavior, and no limitation should be stale (resolved) or missing (a now-real risk).

**Pain Points Addressed**: Documentation drift. The bugfix hardened two behaviors; a
mechanical "we fixed bugs, update the README" reflex can introduce churn (e.g. advertising a
defensive fix, or leaking the `--` implementation detail into user docs). This task's job is
to verify accuracy and **resist churn** — the README already describes the correct
end-user behavior.

## Why

- This is the **Mode B changeset-level doc sync** — the single task that sweeps README for
  whole-changeset-spanning content. Per-file (Mode A) doc updates were handled inline by the
  implementing subtasks; none needed any. (system_context.md §5 lists `README.md` as the only
  doc file in the changeset scope.)
- The bugfix changed **user-visible behavior** in exactly one way: leading-dash/no-match and
  special-character queries now behave **as the README already documents** (fall back to the
  current pane dir; `'` and spaces survive). The fixes make the README's existing claims
  **true**, not stale — so the dominant correct outcome is "no edit."
- The two non-obvious risks this task must navigate: (1) the `--` guard (P1.M1.T1.S2) is
  **still pending** at planning time, but the decision is independent of it (see Context §1);
  (2) the single-quote fix has residual edge cases (`$`/`` ` ``/`\`/`"`) that the contract
  says NOT to document (findings §F5; this PRP §Known-limitations criteria).

## What

User-visible behavior: **none** (docs-only; the README either stays as-is or gets a minimal
correction). What this task produces is a **verified decision** that the README is accurate.

### Success Criteria

- [ ] All 9 README sections reviewed against the fixed behavior; the per-section decision is
      recorded in `research/doc_sync_review.md`.
- [ ] `README.md` has either **no diff** (expected) or a minimal justified edit.
- [ ] `grep -n 'zoxide query' README.md` shows the high-level `<query>` form — the README
      neither leaks the `--` implementation detail nor contradicts it.
- [ ] `grep -niE "single quote|apostrophe|leading.dash|flag|end-of-options" README.md`
      → empty (the README never documented the now-fixed bugs, so nothing to retract/update).
- [ ] No README statement contradicts the fixed behavior (Backends contract, Known
      limitations, Usage/Window-jump all hold).
- [ ] `git status --short` shows at most `README.md` (only if edited) — never any source
      file, test file, `.gitignore`, `PRD.md`, `tasks.json`, or `prd_snapshot.md`.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to do this
review successfully?_ **Yes.** The full current README (148 lines) is reproduced section-by-
section below with line numbers, the exact fixed behavior is stated per section, and the
per-section decision criteria are explicit. The two non-obvious points (the `--` guard state
discrepancy, and why the residual special-character edge case is deliberately not
documented) are surfaced with their rationale. The validation gates are concrete grep
commands. No codebase knowledge beyond this PRP is required to reach and verify the
(no-change) decision.

### Documentation & References

```yaml
# MUST READ
- file: README.md
  why: THE FILE UNDER REVIEW. 148 lines. Reproduced section-by-section in the Implementation
       Blueprint below with line numbers, but the implementer MUST open it fresh to confirm
       the line numbers (they shift with any prior edit) and to do an honest read.
  section: "Backends (106-118): 'zoxide runs `zoxide query <query>`' + the no-match->empty->
           fallback contract paragraph. Known limitations (133-145): 5 items. Usage/Window
           jump (58-67): 'An empty query or a no-match opens the window in the current pane's
           directory.' Scope & compatibility (120-131): set-hook -g reload note."
  critical: "The README describes the END-USER contract (no-match -> fallback), which the
             fixes make TRUE. Do NOT add the `--` implementation detail to 'Backends' (churn).
             Do NOT add leading-dash/single-quote to 'Known limitations' (they were bugs, now
             fixed; never documented as limitations). If a fresh read finds a genuinely stale
             statement, make the MINIMAL surgical edit and document why."

- file: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M3T1S1/research/doc_sync_review.md
  why: The completed review matrix + decision (authored during planning). The implementer's
       primary job is to RE-VERIFY this against the live README + live code, then record the
       outcome. It already contains the per-section table, the state discrepancy, and the
       residual-edge-case rationale.
  section: "§0 what changed; §1 the -- guard state discrepancy (decision is robust to it);
            §2 per-section matrix (9 sections, all NO CHANGE); §3 why the residual edge case
            is NOT documented; §4 decision + output; §5 validation."
  critical: "§4 + §5 are the spec for the task output and gates. §2 is the per-section
             rationale to re-verify. Re-derive the decision from the LIVE files — do not
             trust the matrix blindly; line numbers shift."

- file: PRD.md  (bug-report PRD: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/prd_snapshot.md)
  why: Authoritative statement of the two bugs + the fixed behavior, so the implementer can
       judge README accuracy without guessing.
  section: "h2.0 Overview (quality verdict + the 2 issues); h2.2/h3.0 Issue 1 (zoxide flag
            absorption -> expected: no-match returns empty, falls back); h2.3/h3.1 Issue 2
            (single quote -> expected: query delivered intact, resolves); h2.4 Testing Summary."
  critical: "The PRD's 'Expected Behavior' for both issues is ALREADY what the README documents
             (no-match -> current pane dir; query resolves). So the README matches the spec."

- file: scripts/lib/resolve.sh
  why: To verify what _resolve_zoxide ACTUALLY does now (the -- guard status — see Context §1).
       NOT modified by this task.
  section: "_resolve_zoxide (lines ~12-22): currently `zoxide query \"$1\"` (NO -- guard; PENDING
            in P1.M1.T1.S2). The false comment block at 12-17 is a resolve.sh-comment issue for
            P1.M1.T1.S2 to fix, NOT a README issue (the README never quoted the comment)."
  critical: "The README decision does NOT depend on the -- guard: the high-level 'zoxide runs
             `zoxide query <query>`' is accurate either way, and the defence-in-depth caller
             guards (shipped) make the user-visible behavior correct either way."

- file: scripts/z-window.sh
  why: To verify the SHIPPED defence-in-depth guard (Layer 2 of Issue 1) — the thing that makes
       the user-visible behavior correct RIGHT NOW, independent of the -- guard.
  section: "lines 18-40: NL variable + `case \"$resolved\" in *\"$NL\"*) : ;; *) [ -d \"$resolved\" ]
            && dir=\"$resolved\" ;; esac`. A multi-line (list-mode dump) or non-directory value
            is rejected -> window falls back to cur. This is why the README's no-match->fallback
            guarantee holds end-to-end."
  critical: "This guard is the user-visible fix. It makes a leading-dash query fall back to the
             current pane dir (the README's documented behavior). Confirm it is present (it is)."

- file: scripts/z-session.sh
  why: Symmetric defence-in-depth guard for the session handler.
  section: "lines 51-56: `case \"$resolved\" in *\"$NL\"*) exit 0 ;; *) [ -d \"$resolved\" ] ||
            exit 0 ;; esac`. A non-directory/multi-line value -> no-op (session stays put)."
  critical: "Same rationale as z-window.sh. Confirms session relocate's documented 'no-match ->
             left at $HOME' holds end-to-end."

- file: tmux-zoxide-sessions.tmux
  why: To verify the SHIPPED Issue 2 fix (the binding's double-quoted %%).
  section: "line 18: `\"run-shell '$CURRENT_DIR/scripts/z-window.sh \\\"%%\\\"'\"` (Fix A-alt: %%
            wrapped in escaped double quotes inside the single-quoted run-shell arg)."
  critical: "This makes a typed apostrophe/space survive to z-window.sh as $1 (P1.M2.T1.S1 +
             regression test P1.M2.T1.S2). Transparent to the user -> no usage-text change."

- file: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/findings_and_risks.md
  why: §F5 documents the RESIDUAL edge cases of the %% fix ($, backtick, backslash, double-quote)
       and states full robustness is out of scope. This is the basis for NOT documenting them.
  section: "F5: 'Residual edge cases ($, backtick, backslash) are vanishingly rare for zoxide
            directory queries. Full robustness would require bypassing %% entirely (out of scope).'"
  critical: "These residual cases are NOT added to Known limitations: the README never promised
             arbitrary-character support, and adding a limitation for characters never claimed
             would be manufactured churn (contract-forbidden). Documented in research notes only."

- file: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/system_context.md
  why: §5 lists the changeset's file-change scope (README is the only doc file) and §4 the
       intended behavior post-fix.
  section: "§5 Files to change (README = 'Review/update known limitations (Mode B final task)');
            §4 architecture decisions (Issue 1 three-layer fix; Issue 2 binding quoting)."
  critical: "§5 frames the README task narrowly as 'known limitations,' but the ITEM CONTRACT is
             broader: review ALL README sections for changeset-spanning staleness. Do the full
             sweep (Overview, Usage, Options, Backends, Scope, Known limitations), not just
             Known limitations."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root (bugfix 001, v1.0.1)

$ ls -la README.md scripts/lib/resolve.sh scripts/z-window.sh scripts/z-session.sh tmux-zoxide-sessions.tmux
-rw-r--r-- ... README.md                          # THE FILE UNDER REVIEW (148 lines, v1.0 ship)
-rw-r--r-- ... scripts/lib/resolve.sh             # _resolve_zoxide: `zoxide query "$1"` (-- guard PENDING, P1.M1.T1.S2)
-rwxr-xr-x ... scripts/z-window.sh                # defence-in-depth guard PRESENT (Layer 2, shipped)
-rwxr-xr-x ... scripts/z-session.sh               # defence-in-depth guard PRESENT (Layer 2, shipped)
-rwxr-xr-x ... tmux-zoxide-sessions.tmux          # binding: `\"%%\"` (Issue 2 fix PRESENT, shipped)

$ ls plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M3T1S1/
PRP.md  research/doc_sync_review.md   # this task's PRP + the review matrix/decision

# What the changeset touched (system_context.md §5): resolve.sh (pending --), z-window.sh,
# z-session.sh, 6 test files, the run file, README.md (THIS task). PRD.md/.gitignore untouched.

# Test baseline: 9 files, all green (count in flux — P1.M2.T1.S2 in parallel adds CASE 7+8).
```

### Desired Codebase tree with files to be added/modified

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  README.md                  # EITHER unchanged (expected) OR a minimal surgical edit (if stale)
  # (no other file touched by this docs-only task)
plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M3T1S1/
  PRP.md                     # this PRP
  research/
    doc_sync_review.md       # the review matrix + decision (authored; implementer re-verifies + finalizes)
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE anti-churn guard — the #1 failure mode of this task): an implementer who feels
#   obligated to "add documentation because we fixed two bugs" will MANUFACTURE churn. The
#   contract's governing instruction is: "If the README is already accurate after the fixes,
#   make NO changes and document why. Do NOT manufacture documentation churn." NO EDIT is the
#   correct, expected outcome. Every section was reviewed; none is stale.
# CRITICAL (do NOT leak the `--` implementation detail into 'Backends'): the README says
#   "zoxide runs `zoxide query <query>`". Adding `--` would expose a safe-argument-passing
#   detail to users (churn). The high-level description is accurate AS-IS. The `--` is invisible
#   to the user and to the high-level contract. Leave it.
# CRITICAL (do NOT add leading-dash/single-quote to 'Known limitations'): those were BUGS, now
#   fixed — never documented as limitations. The fixes make the README's no-match->fallback claim
#   TRUE. Adding them as limitations would (a) describe the OLD buggy behavior as a current limit
#   (wrong) or (b) advertise a defensive fix (churn). Neither is correct.
# CRITICAL (the `--` guard state discrepancy is NOT a blocker): at planning time resolve.sh still
#   has `zoxide query "$1"` (P1.M1.T1.S2 is "Researching", not yet landed). The README decision
#   is INDEPENDENT of this: the high-level description is accurate either way, and the SHIPPED
#   defence-in-depth caller guards (z-window.sh/z-session.sh) make the user-visible behavior
#   correct right now. Do NOT block this task on P1.M1.T1.S2, and do NOT edit the README based on
#   the guard's presence/absence. (The false comment at resolve.sh:12-17 is a resolve.sh-comment
#   edit owned by P1.M1.T1.S2 — the README never quoted it, so it's not a README concern.)
# CRITICAL (residual special-character edge cases are deliberately NOT documented): the `%%`
#   double-quote fix leaves `$`/backtick/`\`/`"` queries possibly broken (findings §F5), but
#   these are "vanishingly rare for zoxide directory queries," full robustness is out of scope,
#   and the README never promised arbitrary-character support. Documenting them = manufactured
#   churn. Keep them in research notes ONLY. (The realistic case — apostrophe `o'brien` — now
#   works, so there is no realistic regression to warn about.)
# GOTCHA (re-verify line numbers from the LIVE README): the line ranges in this PRP and in
#   research/doc_sync_review.md were captured at planning time. Open README.md fresh; the section
#   HEADINGS are stable, but exact line numbers shift with any prior edit.
# GOTCHA (docs-only): do NOT run any test-file edit, source edit, or chmod. The only file this
#   task may touch is README.md (and even that, only if a section is genuinely stale — it isn't).
# FORBIDDEN: PRD.md, **/tasks.json, **/prd_snapshot.md, .gitignore, all scripts/*, all tests/*,
#   the run file. This task reviews README.md only.
```

## Implementation Blueprint

### Data models and structure

N/A — pure documentation review. The "model" is the per-section decision matrix (current text
→ fixed behavior → decision → rationale), recorded in `research/doc_sync_review.md` §2.

### The README under review (section-by-section, with the decision)

Reproduced from the live `README.md` at planning time. **Re-open the file fresh** to confirm
line numbers; the headings are stable.

```markdown
## Backends   (README lines 106-118)   — DECISION: NO CHANGE
- `zoxide` runs `zoxide query <query>`. Needs the `zoxide` binary on `$PATH`.
- `z` sources a rupa/z `z.sh` (set via `@zoxide-sessions-z-sh`) and calls `_z`.
  Uses zsh when available, otherwise sh.
- `auto` (default) uses zoxide when present, then rupa/z when a `z.sh` path is
  set. Keeps working on machines without zoxide.

All three backends return an empty result (and exit 0) when a query has
no match; callers check the output, never the exit status. (The `z` backend
achieves this by comparing the working directory before and after calling
rupa/z's `_z`, which changes directory only on a match.) An empty result
means a window-jump query falls back to the current pane's directory and
session relocate is a no-op.
```
**Rationale (NO CHANGE):** "`zoxide query <query>`" is a high-level description; `--` is an
invisible implementation detail of safe argument passing (don't leak it — churn). The
no-match→empty→fallback contract paragraph describes the **end-user** behavior, which the
SHIPPED defence-in-depth guards (z-window.sh/z-session.sh) make hold for ALL inputs
(including leading-dash, which the caller guards reject). A leading-dash query is a
flag-misparse, not a "no match"; the README makes no claim about flag-like queries, and the
fix makes them fall back too. Accurate as-is.

```markdown
## Known limitations   (README lines 133-145)   — DECISION: NO CHANGE
- Relocation uses `respawn-pane -k`, so there is a brief flicker as the first
  pane restarts in the new directory (unavoidable — tmux permits no pre-creation
  interception).
- `skip-names` is whitespace-separated, so entries cannot contain spaces.
- `home-dir` is a single directory, not a list.
- Path normalization uses `readlink -f`, which is GNU; on systems without it
  (some BSDs, or macOS default `readlink`), a symlinked `$HOME` may not fully
  canonicalize and the comparison falls back to the literal path (trailing
  slashes are still normalized).
- A session restored by resurrect/continuum whose saved pane directory *was*
  `$HOME` passes the `$HOME` guard and is relocated — a benign false positive
  of the guard model rather than a bug, and arguably desirable.
```
**Rationale (NO CHANGE):** 5 items. **None** is resolved or amended by the bugfix (the fixes
are defensive hardening of the resolver/caller, unrelated to flicker/skip-names/home-dir/
readlink/resurrect-false-positive). The leading-dash and single-quote bugs were **never**
documented limitations (they were bugs, now fixed) — so there is nothing to retract, and
adding them would describe the OLD buggy behavior as a current limit (wrong) or advertise a
fix (churn). Per the contract: "If no limitation is affected, do NOT add or remove anything."
The residual special-character edge case (`$`/`` ` ``/`\`/`"`) is deliberately NOT added
(see Known Gotchas + findings §F5).

```markdown
### Window jump   (README lines 58-67)   — DECISION: NO CHANGE
Press `prefix + g` (default), type a query, press Enter:
    z to: tmux
A window opens in the current session, in zoxide's best match for `tmux`, named
after the directory basename. An empty query or a no-match opens the window in
the current pane's directory (same as `new-window -c "#{pane_current_path}"`).
```
**Rationale (NO CHANGE):** The Issue 2 fix (double-quoted `%%`) is **transparent to the user**
— a typed apostrophe/space now survives to `z-window.sh` and resolves, instead of being lost.
The usage text makes **no character-restriction claim** ("type a query"), so making `'` work is
a strict improvement with no text change. The Issue 1 fix makes the "no-match opens the window
in the current pane's directory" claim **TRUE** (pre-fix, `-l` violated it by dumping the DB).

**All other sections** (Overview/Why 1–22, Install 24–54, Session auto-relocate 69–82,
Options table 88–97, Scope & compatibility 120–131, License 147–148) describe behavior the
bugfix did **not** change → **NO CHANGE**. (Scope & compatibility's `set-hook -g` reload note
was added in v1.0 and is untouched by this bugfix.)

### Implementation Tasks (ordered)

```yaml
Task 1: RE-VERIFY the review against the LIVE files (do not trust the matrix blindly)
  - OPEN: README.md (fresh — confirm headings + the Backends/Known-limitations/Usage text above).
  - OPEN: scripts/z-window.sh (lines 18-40) -> CONFIRM the defence-in-depth guard is present
          (the NL var + `case "$resolved" in *"$NL"*) : ;; *) [ -d "$resolved" ] && dir=...`).
  - OPEN: scripts/z-session.sh (lines 51-56) -> CONFIRM the symmetric guard is present.
  - OPEN: tmux-zoxide-sessions.tmux (line 18) -> CONFIRM `\"%%\"` (Issue 2 fix) is present.
  - OPEN: scripts/lib/resolve.sh (lines 12-22) -> NOTE the `--` guard status (pending per
          P1.M1.T1.S2). The README decision is INDEPENDENT of this (see Known Gotchas).
  - For EACH README section: state current text -> fixed behavior -> decision (NO CHANGE expected).

Task 2: DECIDE per section (expected: all NO CHANGE)
  - Backends: NO CHANGE (high-level `zoxide query <query>` accurate; `--` is impl detail).
  - Known limitations: NO CHANGE (none of the 5 affected; bugs-never-documented-as-limits).
  - Usage/Window jump: NO CHANGE (fix is transparent; no character-restriction claim existed).
  - All other sections: NO CHANGE (bugfix didn't change their behavior).
  - IF (contrary to expectation) a fresh read finds a genuinely stale/contradictory statement:
    make the MINIMAL surgical edit to README.md and document the exact change + rationale in
    research/doc_sync_review.md. (Review found none; this branch is not expected to fire.)

Task 3: RECORD the decision (finalize research/doc_sync_review.md)
  - ENSURE research/doc_sync_review.md reflects the LIVE re-verification (update line numbers if
    they shifted; confirm the per-section table matches what you actually read).
  - ENSURE the two non-obvious points are documented: (a) the `--` guard state discrepancy and
    why the decision is robust to it (§1); (b) the residual special-character edge case and why
    it is deliberately NOT a README limitation (§3).
  - STATE the outcome unambiguously: "DECISION: NO README CHANGES" (or, if an edit was made,
    the exact diff + why).

Task 4: VERIFY (no edits during verification — see Validation Loop).
```

### Implementation Patterns & Key Details

```sh
# The single "pattern" of this task is a DISCIPLINED REVIEW, not a code change:
#
#   for each README section:
#     compare current_text vs fixed_behavior
#     if current_text contradicts fixed_behavior  -> minimal surgical edit + rationale
#     else                                       -> NO CHANGE (record the rationale)
#
# Why the dominant outcome is NO CHANGE: the bugfix changed user-visible behavior in exactly
#   one direction — leading-dash/no-match/special-char queries now behave AS THE README ALREADY
#   DOCUMENTS (fall back to current pane dir; ' and spaces survive). The fixes make the README's
#   existing claims TRUE, not stale.
#
# Why `--` is NOT added to 'Backends': it is an invisible implementation detail of safe argument
#   passing. The high-level "zoxide runs `zoxide query <query>`" is the user-facing contract.
#   Leaking `--` into user docs is churn and confuses readers (it's not a flag they pass).
#
# Why leading-dash/single-quote are NOT added to 'Known limitations': they were BUGS (now fixed),
#   never documented limitations. Adding them would either describe the old buggy behavior as a
#   current limit (wrong) or advertise a defensive fix (churn). The contract forbids both.
#
# Why the residual special-character edge case ($/`/\/") is NOT documented: the README never
#   promised arbitrary-character support; those chars are absent from real directory names; full
#   robustness is out of scope (findings §F5). Documenting = manufactured churn (contract-forbidden).
#
# Why the decision is robust to the pending `--` guard: the high-level description is accurate
#   either way, and the SHIPPED defence-in-depth caller guards make the user-visible behavior
#   correct RIGHT NOW (a leading-dash query falls back to cur, matching the README). So whether
#   P1.M1.T1.S2 lands before or after this task, the README needs no change.
```

### Integration Points

```yaml
FILESYSTEM:
  - review: "README.md   (the ONLY file this task may edit, and only if a section is genuinely stale)"
  - finalize: "plan/.../P1M3T1S1/research/doc_sync_review.md   (the decision record)"

DEPENDENCIES (already shipped — verify present, do NOT modify):
  - scripts/z-window.sh:   defence-in-depth guard (Layer 2 of Issue 1) — PRESENT.
  - scripts/z-session.sh:  symmetric defence-in-depth guard — PRESENT.
  - tmux-zoxide-sessions.tmux: double-quoted `%%` binding (Issue 2) — PRESENT.

DEPENDENCY (PENDING — does NOT block this task):
  - scripts/lib/resolve.sh: `--` guard (Layer 1 of Issue 1) is PENDING in P1.M1.T1.S2. The README
    decision is independent of it (high-level desc accurate either way; Layer 2 guarantees the
    user-visible fix). Do NOT block on it; do NOT edit the README based on its status. The false
    comment at resolve.sh:12-17 is P1.M1.T1.S2's concern (a code-comment edit), not a README edit.

PARALLEL CONTEXT (P1.M2.T1.S2, implementing in parallel):
  - Adds CASE 7+8 (single-quote regression) to tests/test_z_window.sh. Does NOT touch README. No
    conflict with this task. It confirms (via its regression test) that ' queries now resolve —
    i.e. the README's "type a query" usage is accurate. (Read its PRP as a contract; it produced
    no README change and no claim this task must honor.)

NO DATABASE / BUILD / CONFIG / TEST CHANGES:
  - This is a docs-only task. It touches at most README.md. No test run is required FOR the change
    (the test suite is a regression sanity check only — a doc change cannot regress code).
```

## Validation Loop

### Level 1: README accuracy grep gates (the authoritative checks)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# (a) The Backends description is high-level (does NOT leak/stale-reference the `--` detail):
grep -n 'zoxide query' README.md
# Expected: TWO lines, both accurate —
#   line  76: "The session's first pane moves from `$HOME` to `zoxide query sellario`."   (Usage example)
#   line 107: "- `zoxide` runs `zoxide query <query>`. Needs the `zoxide` binary on `$PATH`."   (Backends)
# Neither leaks `--`; neither makes a stale flag claim. (Line 76 is the session-relocate usage
# example, which is correct.) Accurate either way re: the -- guard.

# (b) The README never documented the now-fixed bugs, so there is nothing stale to retract:
grep -niE "single quote|apostrophe|leading.dash|end-of-options|-- guard|flag absor" README.md
# Expected: NO matches (empty). The README never mentioned these — confirming nothing to update.

# (c) The Known limitations section still has exactly the 5 v1.0 items (none added/removed):
sed -n '/^## Known limitations/,/^## /p' README.md | grep -cE '^- '
# Expected: 5  (flicker; skip-names whitespace; home-dir single dir; readlink -f GNU; resurrect $HOME false-positive).

# (d) The Usage/Window-jump no-match->fallback claim is intact (the fix makes it TRUE).
#     NOTE: the sentence wraps across lines 66-67 in the README, so grep on a single line must
#     target a fragment that sits on ONE line:
grep -n "An empty query or a no-match" README.md          # expect 1 match (line 66; the claim opens here)
grep -c "current pane.s directory" README.md             # expect 2 (line 67 Usage + line 117 Backends contract)
# Both fragments unchanged -> the no-match->fallback claim and the Backends contract paragraph are intact.
```

### Level 2: README ↔ fixed-behavior consistency (manual read — the real review)

```bash
# Open README.md and confirm, per section, that no statement contradicts the fixed behavior:
#   - Backends (106-118):    high-level `zoxide query <query>` + no-match->empty->fallback -> HOLDS
#                            (Layer 2 caller guards make it hold for ALL inputs).
#   - Known limitations:     5 items, none touched by the bugfix -> HOLDS.
#   - Usage/Window jump:     "no-match opens in current pane dir" -> HOLDS (fix made it TRUE);
#                            "type a query" makes no char claim -> ' working is a strict improvement.
#   - All other sections:    unchanged behavior -> HOLDS.
# Record the per-section decision in research/doc_sync_review.md.
```

### Level 3: Regression sanity (the doc task must not break anything)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions
# A docs-only change cannot regress code, but confirm the suite is green (no NEW failures).
# NOTE: the assertion COUNT is in flux — P1.M2.T1.S2 (parallel) adds CASE 7+8 to test_z_window.sh
# (17->23). The gate is "all files exit 0," not a fixed count.
for t in tests/test_*.sh; do
  sh "$t" >/dev/null 2>&1 && echo "OK   $(basename "$t")" || echo "FAIL $(basename "$t")"
done
# Expected: 9 lines, all "OK". (If a file FAILs, it is a sibling/code issue, NOT this doc task —
# this task touched no code. Report it; do not "fix" it here.)
```

### Level 4: N/A

No performance, security, or API-doc validation applies to a README review. The feature (the
README truthfully describes the shipped behavior, with no churn) is fully covered by Level 1's
grep gates + Level 2's manual per-section read + Level 3's green-suite sanity check.

## Final Validation Checklist

### Technical Validation

- [ ] `grep -n 'zoxide query' README.md` → TWO lines (Usage example line 76 + Backends line 107), both the high-level `<query>` form (no `--` leak).
- [ ] `grep -niE "single quote|apostrophe|leading.dash|end-of-options|flag absor" README.md` → empty.
- [ ] `sed -n '/^## Known limitations/,/^## /p' README.md | grep -cE '^- '` → 5 (unchanged).
- [ ] `grep -n "An empty query or a no-match" README.md` → one match (line 66; the claim is intact — the sentence wraps to line 67, so grep the single-line fragment).
- [ ] `git status --short` → at most `README.md` (only if edited); NEVER any script/test/run-file/PRD/.gitignore/tasks.json/snapshot.
- [ ] Full test suite: all 9 `tests/test_*.sh` exit 0 (regression sanity; count in flux).

### Feature Validation

- [ ] Every README section reviewed against the fixed behavior; per-section decision recorded.
- [ ] No README statement contradicts the fixed behavior (Backends, Known limitations, Usage all hold).
- [ ] The decision record (`research/doc_sync_review.md`) states the outcome: "NO README CHANGES"
      (expected) or the exact minimal diff + rationale (if a stale statement was found).
- [ ] The `--` guard state discrepancy is documented (decision robust to it).
- [ ] The residual special-character edge case is documented as deliberately NOT a README limitation.

### Code Quality Validation

- [ ] (If NO edit — expected) README.md is byte-identical to its pre-task state (`git diff README.md` empty).
- [ ] (If an edit was made) the diff is minimal, surgical, justified, and documented — no churn.
- [ ] The decision record is self-contained (a reader can see WHAT was reviewed and WHY no change).

### Documentation & Deployment

- [ ] The README continues to truthfully describe the shipped v1.0.1 behavior.
- [ ] No manufactured churn (no advertising of defensive fixes; no leaking of `--`; no spurious limits).
- [ ] The changeset-level doc sync (Mode B) is accounted for: the sweep was performed and recorded.

---

## Anti-Patterns to Avoid

- ❌ Don't **manufacture documentation churn** — "we fixed two bugs, so the README must change" is the #1 failure mode. The contract is explicit: if the README is already accurate, make NO changes and document why. The fixes make the README's existing claims TRUE; no edit is the correct outcome.
- ❌ Don't **leak the `--` implementation detail** into the 'Backends' section ("zoxide runs `zoxide query <query>`" is the user-facing contract; `--` is invisible safe-argument-passing). Adding it confuses readers and is churn.
- ❌ Don't **add leading-dash / single-quote to 'Known limitations'** — they were BUGS (now fixed), never documented limitations. Adding them describes the OLD buggy behavior as a current limit (wrong) or advertises a fix (churn).
- ❌ Don't **document the residual special-character edge case** (`$`/`` ` ``/`\`/`"`) as a limitation — the README never promised arbitrary-character support, those chars are absent from real directory names, and full robustness is out of scope (findings §F5). Keep it in research notes only.
- ❌ Don't **block on or edit for the pending `--` guard** (P1.M1.T1.S2) — the README decision is independent of it (high-level desc accurate either way; Layer 2 caller guards guarantee the user-visible fix). The false comment at resolve.sh:12-17 is P1.M1.T1.S2's code-comment concern, not a README concern.
- ❌ Don't **trust the planning-time line numbers blindly** — re-open README.md fresh; headings are stable but line numbers shift with any prior edit. Re-derive each decision from the live text.
- ❌ Don't **touch any file other than README.md** — this is docs-only. No scripts/*, tests/*, the run file, PRD.md, .gitignore, tasks.json, prd_snapshot.md.
- ❌ Don't **"fix" a failing test** if Level 3 reports one — a docs-only task cannot regress code; a failure is a sibling/code issue. Report it; do not edit code here.
- ❌ Don't **narrow the review to only 'Known limitations'** (system_context.md §5's framing) — the item contract is broader: sweep ALL README sections (Overview, Usage, Options, Backends, Scope, Known limitations) for changeset-spanning staleness.

---

## Scope Boundaries (explicit)

| Concern | This subtask (P1.M3.T1.S1) | Other subtasks |
| --- | --- | --- |
| `README.md` review + (only-if-stale) edit | ✅ REVIEW (expected: NO edit) | — |
| `scripts/lib/resolve.sh` (`--` guard, false comment) | ❌ DO NOT (PENDING in P1.M1.T1.S2; README-independent) | P1.M1.T1.S2 |
| `scripts/z-window.sh` / `z-session.sh` (defence-in-depth) | ❌ DO NOT (verify present; already shipped) | P1.M1.T2.S1/S2 |
| `tmux-zoxide-sessions.tmux` (binding `%%`) | ❌ DO NOT (verify present; already shipped) | P1.M2.T1.S1 |
| `tests/test_*.sh` (regression tests) | ❌ DO NOT | P1.M1.T1/T3, P1.M2.T1.S2 |
| per-file (Mode A) inline doc comments in source | ❌ DO NOT (handled inline by implementing subtasks; none needed any) | P1.M1/P1.M2 subtasks |
| `PRD.md`, `.gitignore`, `tasks.json`, `prd_snapshot.md` | ❌ FORBIDDEN (read-only/orchestrator) | orchestrator |

---

## Confidence Score

**9/10** — one-pass success likelihood. The review was performed during planning against the
live README + live code, and every section was found accurate (no churn needed). The two
non-obvious traps — (1) the pending `--` guard (handled: the decision is robust to it) and
(2) the impulse to manufacture doc churn (handled: explicit anti-churn guard + grep gates) —
are surfaced with their rationale. The deliverable is primarily a decision record, which is
low-risk. The −1 is the residual chance a fresh read surfaces a statement the planning review
judged accurate but a stricter reader flags — mitigated by the per-section criteria and the
grep gates (which prove the README never referenced the now-fixed bugs). No code change is
involved, so there is no implementation-failure risk.
