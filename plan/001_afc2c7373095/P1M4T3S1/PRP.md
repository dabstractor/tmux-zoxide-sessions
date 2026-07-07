name: "P1.M4.T3.S1 — Reconcile README with shipped behavior (Mode B final doc sweep)"
description: >
  SOW §5 Mode B changeset-level documentation-sync task (runs LAST; depends on every
  implementing subtask P1.M1–P1.M3 + the README authored in P1.M4.T1.S1 + the acceptance
  report from P1.M4.T2.S1). Its job: guarantee README.md is internally consistent with
  shipped v1.0 — i.e., it matches what the code actually does after Corrections A & B
  and the NOTE C composition nuance were applied. DOC-ONLY edit (one file: README.md);
  no source/script/run-file/test changes.

---

## Goal

**Feature Goal**: README.md reflects the *actual* shipped behavior of tmux-zoxide-sessions
v1.0 exactly — every option default, the `$HOME`-guard model, the coexistence claims, the
backend behavior (incl. Correction A), the reload-safe hook model (NOTE C), and a
**complete** Known-limitations list. No stale, contradicted, or missing claims.

**Deliverable**: A surgical edit to `README.md` (repo root). Specifically, **append two
missing bullets to the existing "Known limitations" section**:
1. the GNU `readlink -f` limitation (PRD §8 bullet 4), and
2. the degenerate restored-`$HOME` false-positive case (the consequence of the
   `$HOME`-guard model when a restored session's saved cwd *was* `$HOME`).

All other README sections are already faithful to shipped behavior and PRD §5.6 — leave
them untouched. (A full drift audit is in `research/drift_audit.md`; verdict: 7/8 checks
PASS, the one DRIFT is the incomplete Known-limitations list.)

**Success Definition**:
- README's "Known limitations" section lists all five items required by the work item:
  respawn flicker ✓ (already present), whitespace `skip-names` ✓ (already present), single
  `home-dir` ✓ (already present), GNU `readlink -f` ✗ → ADD, degenerate restored-`$HOME`
  ✗ → ADD.
- Every other claim in README is verified consistent with shipped code (no edits needed).
- No source/script/run-file/test/LICENSE/PRD/tasks.json/.gitignore changes. README is the
  ONLY file edited.

## User Persona

**Target User**: A downstream reader of the repo (plugin user or reviewer) who reads
README to understand the plugin's exact behavior, defaults, and edge cases — and a future
maintainer who needs README to stay a faithful mirror of shipped behavior.

**Use Case**: "I cloned this plugin; what are its real limitations and gotchas, and do the
documented defaults/options match what the code actually does?"

**User Journey**: Open README → Options table → Backends → Scope & compatibility → Known
limitations; every claim in each section is accurate against the code they can also read.

**Pain Points Addressed**: Stale/contradictory docs that mislead users (e.g., a user with a
symlinked `$HOME` on macOS/BSD wondering why relocate behaves oddly; a resurrect user
surprised a session got relocated when its saved cwd was `$HOME`).

## Why

- **Mode B final doc sweep** (SOW §5): runs after all implementing subtasks ship, so its
  sole job is doc/behavior parity. An incomplete Known-limitations list is the one place
  the authored README (P1.M4.T1.S1, faithful to PRD §5.6) drifts from PRD §8 + the
  validated risk register.
- **The two missing bullets are real, shipped behaviors.** They are not speculative:
  - `readlink -f` is called in `scripts/z-session.sh` `_norm()` — non-GNU systems fall
    back to literal comparison (PRD §8 documents this; README omitted it).
  - The degenerate restored-`$HOME` case is the *direct consequence* of the documented
    `$HOME`-guard model: resurrect restores the saved pane cwd; if that saved cwd *was*
    `$HOME`, z-session.sh's `path == home-dir` guard passes and it relocates. The risk
    register in `findings_and_risks.md` explicitly instructs: "document in README
    known-limitations."
- **Scope/cohesion:** This is the LAST task in P1 (M4.T3). Every implementing subtask is
  complete (resolver Correction A in P1.M1.T2.S3, Correction B in P1.M1.T2.S4, hook wiring
  NOTE C in P1.M3.T2.S1). Editing README here — and ONLY here — keeps a single owner of
  the doc-sync change and avoids race conditions with the parallel README-authoring
  (P1.M4.T1.S1, complete) and acceptance (P1.M4.T2.S1) tasks. This task does not re-author
  README; it appends two validated bullets.

## What

A surgical edit to **one file**: `README.md` (repo root). **Add two bullets** to the
"Known limitations" section, after the three existing bullets (respawn flicker,
whitespace skip-names, single home-dir). Do not remove or reword the existing three — they
are accurate. Do not edit any other section — every other claim in README is verified
consistent with shipped code (see `research/drift_audit.md`).

The two new bullets (text TBD by the implementer but MUST convey these facts — wording
should be faithful to PRD §8 / findings_and_risks.md, concise, in the README's existing
tone):

1. **GNU `readlink -f`** — symlinked `$HOME` may not canonicalize on systems without GNU
   `readlink` (e.g., some BSDs/macOS default `readlink`); the plugin falls back to a
   literal path comparison, which still normalizes trailing slashes but may not follow
   symlinks. (Source of truth: PRD §8 bullet 4; code: `scripts/z-session.sh` `_norm()`.)
2. **Degenerate restored-`$HOME`** — a session restored by resurrect/continuum whose
   *saved* pane cwd was literally `$HOME` will be relocated (it passes the `$HOME`-guard).
   This is a benign false positive of the guard model, not a bug; arguably desirable.
   (Source of truth: `findings_and_risks.md` Risk register; rationale: z-session.sh
   `path == home-dir` guard.)

### Success Criteria

- [ ] README "Known limitations" section contains bullets covering ALL five: respawn
      flicker, whitespace `skip-names`, single `home-dir`, GNU `readlink -f` (new),
      degenerate restored-`$HOME` (new).
- [ ] The two new bullets are factually consistent with shipped code (`scripts/z-session.sh`
      `_norm()` + the `$HOME`-guard; `findings_and_risks.md` risk register).
- [ ] No other README section is changed (Options, Backends, Scope & compatibility, Usage,
      Install all left as-is — they are verified accurate).
- [ ] No file other than `README.md` is modified.

## All Needed Context

### Context Completeness Check

If someone knew nothing about this codebase, would they have everything needed to
implement this successfully? **Yes** — the drift audit (`research/drift_audit.md`)
pre-computes every check with exact quotes and verdicts; the two missing bullets' source
of truth (PRD §8 + findings_and_risks.md risk register) and the exact README anchor to
append after are specified below. The implementer's only judgment is phrasing two
sentences faithfully in the README's existing tone.

### Documentation & References

```yaml
# MUST READ — primary sources of truth for the two new bullets
- docfile: PRD.md
  why: "§8 bullet 4 is the verbatim source for the GNU readlink -f limitation bullet.
        Copy its phrasing. §8 also lists the three already-present bullets (flicker,
        skip-names, home-dir) — match their style/format."
  section: "§8 Known limitations (bullet 4: readlink -f is GNU...)"

- docfile: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: "Risk register (final bullets) is the source of truth for the degenerate
        restored-$HOME false-positive bullet — it explicitly says 'document in README
        known-limitations'. NOTE C is the source for the (already-present, do-not-touch)
        Scope & compatibility reload-safe wording."
  section: "Risk register bullet 4 (readlink -f) + bullet 5 (degenerate restored-$HOME);
            🟡 NOTE C (composition — DO NOT change README's existing wording, it's correct)."

# MUST READ — the audit that proves this is the ONLY drift (so the implementer doesn't
# "helpfully" rewrite other sections and introduce NEW drift)
- docfile: plan/001_afc2c7373095/P1M4T3S1/research/drift_audit.md
  why: "Pre-computed PASS/DRIFT table for 8 checks. Verdict: 7/8 PASS (leave them alone);
        only check 4 (Known limitations completeness) DRIFTs. Lists exactly the two
        missing bullets. Reading this prevents over-editing."

# MUST READ — the shipped code the two bullets describe (cite/quote to stay faithful)
- file: scripts/z-session.sh
  why: "The `_norm()` function (readlink -f || fallback) is what the GNU-readlink bullet
        describes; the `path == home-dir` guard is what the restored-$HOME bullet
        describes. Quote the behavior, not the implementation."
  pattern: "_norm() uses readlink -f with a printf fallback; the \$HOME-guard is
            [ \"\$(_norm \"\$path\")\" = \"\$(_norm \"\$home_dir\")\" ]"
  gotcha: "Do NOT change scripts/z-session.sh — this is a DOC-only task."

- file: README.md
  why: "The file being edited. The 'Known limitations' section (around line 133-138)
        currently has 3 bullets; append the 2 new bullets after them, matching the
        existing bullet style (markdown `- ` list, bold lead-in term, en-dash or
        em-dash per existing convention)."
  pattern: "Existing bullet format: '- **<term>** — <one-sentence explanation>.' Match it."
  gotcha: "The existing three bullets are accurate — do NOT reword or remove them. This
           task only APPENDS two bullets."

# CONTEXT (no action needed — verifies the other README sections are already correct)
- file: scripts/lib/resolve.sh
  why: "Confirms Correction A (_resolve_z before/after-pwd delta) and Correction B
        (resolve() ends with `return 0`) — README's 'Backends' para and 'empty + exit 0'
        contract already describe these accurately. DO NOT edit README's Backends section."

- docfile: plan/001_afc2c7373095/P1M4T2S1/PRP.md
  why: "The parallel acceptance task. Its README gate (Task 6) greps for the 8 options +
        the \$HOME-guard sentence; this task does NOT need to satisfy that gate (README
        already passes it) — this task only fixes Known-limitations completeness. Confirm
        we are not duplicating acceptance work."
  section: "Task 6 (README gate) — DEFERRED-SAFE; our edit does not affect it."

- docfile: plan/001_afc2c7373095/prd_snapshot.md
  why: "If phrasing the bullets, the PRD §8 verbatim text is the gold standard for the
        readlink -f bullet. (The README's own existing bullets are slightly reworded from
        PRD §8 — match README's tone, not PRD's, so the new bullets read consistently.)"
  section: "§8 Known limitations"
```

### Current Codebase tree (run `ls` in the repo root)

```bash
tmux-zoxide-sessions/
  .gitignore
  LICENSE                       # MIT (M1.T1) — DO NOT TOUCH
  PRD.md                        # READ-ONLY spec — DO NOT TOUCH
  README.md                     # <-- THE ONLY FILE THIS TASK EDITS
  tmux-zoxide-sessions.tmux     # run file (100755) — DO NOT TOUCH
  scripts/
    lib/resolve.sh              # shared resolver (100644, sourced) — DO NOT TOUCH
    z-window.sh                 # window handler (100755) — DO NOT TOUCH
    z-session.sh                # session handler (100755) — DO NOT TOUCH (cite only)
  tests/                        # POSIX-sh integration tests — DO NOT TOUCH
  plan/001_afc2c7373095/        # plan + PRPs + architecture/ — DO NOT TOUCH (read only)
```

### Desired Codebase tree with files to be added/modified

```bash
tmux-zoxide-sessions/
  README.md                     # MODIFIED: +2 bullets in "Known limitations" section.
                                #   No other file changes. No new files.
# NOTE: this is the ONLY change. Everything else is untouched.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL: this is a DOC-ONLY task. The ONLY file you may modify is README.md.
#   Do NOT touch: PRD.md, tasks.json, prd_snapshot.md, .gitignore, LICENSE,
#   any scripts/, any tmux-zoxide-sessions.tmux, any tests/, any plan/ file.
#   Violating this breaks the work-item contract and harms parallel/completed tasks.

# CRITICAL: do NOT over-edit README. The drift audit (research/drift_audit.md) proves
#   7/8 checks already PASS — Options table, Backends, Scope & compatibility, Usage,
#   Install, the $HOME-guard model, the empty+exit0 contract are ALL already correct.
#   "Helpfully" rewording a passing section introduces NEW drift. Edit ONLY the
#   "Known limitations" section (append two bullets).

# GOTCHA: the three existing Known-limitations bullets (respawn flicker, whitespace
#   skip-names, single home-dir) are accurate and faithful to PRD §5.6/§8. Do NOT remove
#   or reword them. Append AFTER them.

# GOTCHA (wording): match the existing bullet format exactly. Current README bullets use
#   '- <sentence>.' (plain prose, no bold lead-in) — e.g. "- Relocation uses `respawn-pane
#   -k`, so there is a brief flicker...". Match that style (NOT PRD §8's bold-term style)
#   so the section reads consistently. Quote PRD §8's FACTS, not its formatting.

# GOTCHA (the degenerate-restore bullet must be TRUE to shipped behavior): it is the
#   consequence of the $HOME-guard model, NOT a bug. Phrase it as a known/false-positive
#   edge case, consistent with findings_and_risks.md ("Arguably desirable; document in
#   README known-limitations"). Do not frame it as a defect to be fixed.

# GOTCHA (the readlink -f bullet): cite that it is GNU and that the fallback is literal
#   path comparison with trailing-slash normalization (matches _norm()'s `|| printf '%s'`
#   fallback + the sed trailing-slash normalizer). Do not promise behavior the code doesn't
#   have.
```

## Implementation Blueprint

### Data models and structure

N/A — documentation-only task. No data models, no code.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: RE-VERIFY the drift audit (no edits — confirm scope is still just 2 bullets)
  - READ: plan/001_afc2c7373095/P1M4T3S1/research/drift_audit.md (the verdict table).
  - RE-RUN the 8 checks inline to confirm nothing changed since the audit was written:
      * Options table (8 opts, defaults): `grep -n '@zoxide-sessions-' README.md` (expect 8) +
        diff defaults against `grep 'get_tmux_option' scripts/lib/resolve.sh tmux-zoxide-sessions.tmux scripts/z-session.sh`.
      * Known-limitations count: `sed -n '/^## Known limitations/,/^## /p' README.md | grep -c '^- '`
        (expect 3 currently → will be 5 after Task 2).
      * Backends/exit0 contract: `grep -n 'before and after calling rupa/z' README.md` (Correction A, present).
      * NOTE C reload-safe: `grep -n 'reload-safe' README.md` (present).
  - IF any of the 7 PASS checks now show DRIFT (e.g., a parallel task changed code): STOP,
    re-audit, and expand the edit to cover the new drift — but ONLY the new drift. Do not
    blanket-rewrite. Document any added change in the commit message.
  - EXPECTED OUTCOME: only Known-limitations completeness DRIFTs. Proceed to Task 2.

Task 2: EDIT README.md — append 2 bullets to "Known limitations"  [the task's primary OUTPUT]
  - FILE: README.md (repo root).
  - LOCATION: the "## Known limitations" section. The section currently has 3 bullets
    (respawn flicker, skip-names whitespace, single home-dir). Append the 2 new bullets
    AFTER the third (single home-dir) bullet, BEFORE the "## License" heading.
  - BULLET 1 (GNU readlink -f):
      * FACT (from PRD §8 bullet 4 + scripts/z-session.sh _norm): the path-normalization
        uses `readlink -f`, which is GNU; on systems without it (some BSDs / macOS default
        `readlink`), symlinked `$HOME` may not canonicalize, and the plugin falls back to a
        literal path comparison (trailing slashes still normalized).
      * PHRASING: one bullet, plain prose, matching the section's existing `- <sentence>.`
        style. Do not use bold lead-in (the existing bullets don't). Keep it under ~2 lines.
  - BULLET 2 (degenerate restored-$HOME):
      * FACT (from findings_and_risks.md risk register): a session restored by
        resurrect/continuum whose saved pane cwd was literally `$HOME` passes the
        `$HOME`-guard and is relocated — a benign false positive (arguably desirable), not
        a bug.
      * PHRASING: one bullet, plain prose, same style. Frame as a known edge case.
  - VERIFY after editing: the section now has 5 bullets; the 3 originals are unchanged;
    no other README section was touched (`git diff README.md` should show ONLY added lines
    in the Known-limitations block).
  - REFERENCE: PRD §8 (bullet 4 for readlink -f), findings_and_risks.md (risk register
    for the restored-$HOME case), README's own bullet style for formatting.

Task 3: FINAL consistency sweep (read README end-to-end, no edits unless new drift found)
  - READ README.md top-to-bottom once more.
  - CONFIRM every claim still matches shipped code: Options (8 defaults), Backends
    (Correction A before/after-cwd), empty+exit0 contract, Scope & compatibility (NOTE C
    reload-safe + how to combine), Usage ($HOME-guard, skip-list), Install (zoxide/z.sh).
  - IF you find a claim that drifted that the Task-1 audit missed: fix ONLY that claim,
    minimally, and note it. Otherwise, make NO further edits.
  - EXPECTED OUTCOME: README is now fully consistent with shipped v1.0; no stale claims.
```

### Implementation Patterns & Key Details

```markdown
<!-- Pattern: the existing Known-limitations bullet style in README.md (MATCH THIS) -->
<!-- (verbatim from current README, lines ~133-138) -->
## Known limitations
- Relocation uses `respawn-pane -k`, so there is a brief flicker as the first
  pane restarts in the new directory (unavoidable — tmux permits no pre-creation
  interception).
- `skip-names` is whitespace-separated, so entries cannot contain spaces.
- `home-dir` is a single directory, not a list.

<!-- Pattern to FOLLOW for the two NEW bullets: same `- <prose>.` style, no bold lead-in,
     multi-line wrapping consistent with the existing bullets. Example shape (implementer
     finalizes exact wording, but MUST convey the two facts below): -->
- Path normalization uses `readlink -f`, which is GNU; on systems without it, a
  symlinked `$HOME` may not fully canonicalize and the comparison falls back to the
  literal path (trailing slashes are still normalized).
- A session restored by resurrect/continuum whose saved pane directory *was* `$HOME`
  passes the `$HOME` guard and is relocated — a benign false positive rather than a bug.

<!-- GOTCHA: do NOT use PRD §8's "**bold-term** —" format; README's existing bullets are
     plain prose. Consistency within the section matters more than matching the PRD. -->
```

### Integration Points

```yaml
DOCS:
  - "ONLY README.md is modified. No migration, no config, no routes, no source, no tests."

GIT:
  - "Commit the README.md change with a message like:
     'docs(README): document GNU readlink -f and restored-$HOME edge cases (§8 / Mode B sync)'.
     Do NOT commit any other file. If `git status` shows unrelated changes (e.g., the
     P1.M3.T2.S1 run-file append or a P1.M4.T2.S1 executable-bit commit), leave them for
     their owning tasks — `git add README.md` explicitly before committing."

# NOTHING ELSE: no PRD.md / tasks.json / prd_snapshot.md / .gitignore / source / tests.
```

## Validation Loop

This is a Markdown documentation task. There is no compiler/linter/test runner for prose
beyond: (a) grep content gates confirming the 5 limitations are present and the 8 options
unchanged, (b) a `git diff` confirming ONLY the Known-limitations section changed, and
(c) an optional markdown linter if the repo has one (it does not — skip).

### Level 1: Content gates (deterministic)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# GATE A — Known-limitations section now has 5 bullets.
count=$(sed -n '/^## Known limitations/,/^## License/p' README.md | grep -c '^- ')
echo "limitations bullets: $count"
[ "$count" -eq 5 ] || echo "FAIL: expected 5 bullets, got $count"
# Expected: limitations bullets: 5

# GATE B — the two new facts are present.
grep -qi 'readlink' README.md && echo "OK readlink" || echo "MISSING readlink bullet"
grep -qi 'restored' README.md && echo "OK restored-\$HOME" || echo "MISSING restored-\$HOME bullet"
# Expected: both OK. (Use case-insensitive grep so the implementer's exact phrasing passes;
#  but READ the matching lines to confirm the FACTS are right, not just the keywords.)

# GATE C — the three original limitations are still present (not removed/rewritten).
grep -q 'respawn-pane -k' README.md && echo "OK flicker" || echo "LOST flicker bullet"
grep -q 'whitespace-separated' README.md && echo "OK skip-names" || echo "LOST skip-names bullet"
grep -q 'single directory, not a list' README.md && echo "OK home-dir" || echo "LOST home-dir bullet"
# Expected: all three OK.

# GATE D — the 8 options are still present with correct defaults (regression check).
for opt in key prompt backend z-sh auto-session home-dir skip-names window-name; do
  grep -q "@zoxide-sessions-${opt}" README.md || echo "MISSING option $opt"
done
grep -q '| `g` |' README.md && echo "OK default g" || echo "default g lost"
# Expected: no MISSING lines; OK default g.

# GATE E — Correction A / NOTE C / exit0 wording untouched (regression check).
grep -q 'before and after calling rupa/z' README.md && echo "OK Correction A" || echo "LOST Correction A"
grep -q 'reload-safe' README.md && echo "OK NOTE C" || echo "LOST NOTE C"
grep -qi 'empty result (and exit 0)' README.md && echo "OK exit0 contract" || echo "LOST exit0 contract"
# Expected: all OK.
```

### Level 2: Diff scope gate (the change is surgical)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# The ONLY changed file must be README.md.
git status --porcelain
# Expected: exactly one line beginning with ' M README.md' (and any unrelated changes from
# parallel/owning tasks — those are NOT this task's concern; verify only that README.md is
# the only file THIS task touched). Do NOT stage or commit other tasks' changes.

# The diff must touch ONLY the "Known limitations" section.
git diff README.md
# Expected: ONLY `+` lines inside the "## Known limitations" .. "## License" block.
# No `-` lines (we append, never remove). No changes in Options/Backends/Scope/Usage/Install.
# Sanity grep on the diff:
git diff README.md | grep -E '^[-+]' | grep -vE '^(\+\+\+|---)' \
  | grep -vE 'readlink|restored|resurrect|continuum|symlink|canonicalize|literal|false positive|guard'
# Expected: empty (every changed line mentions one of the two new facts' vocabulary).
```

### Level 3: Human read-through (final consistency)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions
# Read the whole README once. Confirm every claim matches shipped code:
#   - Options defaults (g / 'z to:' / auto / unset / on / $HOME / 'home main' / off)
#       vs scripts/lib/resolve.sh + tmux-zoxide-sessions.tmux + scripts/z-session.sh
#   - Backends: zoxide query / _z before-after-cwd / auto fallback
#       vs scripts/lib/resolve.sh (_resolve_zoxide, _resolve_z, resolve)
#   - Scope & compatibility: set-hook -g reload-safe + how-to-combine
#       vs tmux-zoxide-sessions.tmux (set-hook -g ... "run-shell -b ...")
#   - Usage: $HOME-guard, skip-list, skip on no-match
#       vs scripts/z-session.sh (path == home-dir guard, skip_names loop, resolved empty)
# Expected: no contradictions. If any are found, fix ONLY that claim minimally (Task 3).
```

### Level 4: Cross-check against acceptance report (deferred-safe)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions
# If the parallel acceptance report exists, confirm this task does not break §9 bullet 6
# ("README documents every option and the $HOME-guard model"):
if [ -f plan/001_afc2c7373095/P1M4T2S1/acceptance_report.md ]; then
  for opt in key prompt backend z-sh auto-session home-dir skip-names window-name; do
    grep -q "@zoxide-sessions-${opt}" README.md || echo "REGRESSION: option $opt missing"
  done
  grep -qi 'home' README.md && grep -qi 'guard\|land.*home\|\$HOME' README.md \
    && echo "OK \$HOME-guard still documented" || echo "REGRESSION: \$HOME-guard lost"
fi
# Expected: no REGRESSION lines. Adding limitations cannot remove the options/guard docs.
```

## Final Validation Checklist

### Technical Validation

- [ ] Level 1: all 5 content gates pass (5 limitations; readlink + restored present; 3
      originals intact; 8 options + default `g` present; Correction A + NOTE C + exit0
      wording untouched).
- [ ] Level 2: `git diff README.md` shows ONLY `+` lines inside the Known-limitations
      section; no `-` lines; no other section changed; no other file touched by this task.
- [ ] Level 3: full README read-through — every claim consistent with shipped code.
- [ ] Level 4: §9 bullet 6 not regressed (8 options + `$HOME`-guard still documented).

### Feature Validation

- [ ] README "Known limitations" lists all five required items (flicker, skip-names
      whitespace, single home-dir, GNU readlink -f, degenerate restored-`$HOME`).
- [ ] The two new bullets are factually accurate against shipped code
      (`scripts/z-session.sh` `_norm()` + `$HOME`-guard; `findings_and_risks.md` register).
- [ ] No stale or contradicted claims remain anywhere in README.
- [ ] The degenerate-restore bullet is framed as a known edge case, not a defect.

### Code Quality / Scope Validation

- [ ] The two new bullets match the section's existing prose style (no bold lead-in;
      consistent wrapping with the existing bullets).
- [ ] README is the ONLY file modified.
- [ ] `PRD.md`, `tasks.json`, `prd_snapshot.md`, `.gitignore`, `LICENSE`, all `scripts/`,
      `tmux-zoxide-sessions.tmux`, all `tests/`, all `plan/` files untouched.
- [ ] No duplication of the parallel acceptance task's (P1.M4.T2.S1) or README-authoring
      task's (P1.M4.T1.S1) work — this task only fixes the Known-limitations gap.

### Documentation & Deployment

- [ ] README reads as a single consistent voice (the new bullets don't feel pasted in).
- [ ] Commit message references §8 / Mode B sync and lists only README.md.

---

## Anti-Patterns to Avoid

- ❌ **Don't edit any file other than README.md.** This is doc-only. Touching source,
  tests, PRD, tasks.json, .gitignore, or LICENSE violates the work-item contract and
  harms parallel/completed tasks.
- ❌ **Don't over-edit README.** The drift audit proves 7/8 checks already PASS. Rewording
  a passing section (Options, Backends, Scope & compatibility, Usage, Install) introduces
  NEW drift. Append ONLY the two missing bullets.
- ❌ **Don't remove or reword the three existing limitations bullets.** They are accurate
  and faithful to PRD §5.6/§8. Append after them.
- ❌ **Don't copy PRD §8's bold-term formatting.** README's existing bullets are plain prose
  (`- <sentence>.`); match the section's style, not the PRD's.
- ❌ **Don't frame the degenerate restored-`$HOME` case as a bug.** It is the documented,
  arguably-desirable consequence of the `$HOME`-guard model. Phrase it as a known edge case.
- ❌ **Don't commit unrelated changes** (e.g., the P1.M3.T2.S1 run-file append or a
  P1.M4.T2.S1 executable-bit commit if present in the worktree). `git add README.md`
  explicitly; leave other tasks' changes to their owners.
- ❌ **Don't re-audit from scratch and "improve" passing claims.** Trust the drift audit;
  if you suspect new drift, verify narrowly and fix only that, with a note.

---

## Confidence Score

**9/10** — one-pass success is near-certain. The task is a surgical 2-bullet append to one
Markdown section; the drift audit pre-computes every check with exact quotes and verdicts;
the source of truth for both bullets (PRD §8 + findings_and_risks.md risk register) and the
shipped code they describe (`scripts/z-session.sh` `_norm()` + `$HOME`-guard) are fully
specified; and the validation gates deterministically confirm the edit (5 bullets present,
3 originals intact, only Known-limitations block changed, no other file touched). The
residual 1/10 is purely wording-judgment risk (the implementer must phrase two sentences
faithfully in the README's voice) — which the Level 3 human read-through and the
content-gate grep vocabulary lists mitigate.
