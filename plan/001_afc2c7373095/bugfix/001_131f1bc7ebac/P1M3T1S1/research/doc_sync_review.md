# README Doc-Sync Review — P1.M3.T1.S1 (bugfix 001)

> Review of `README.md` against the bugfix-001 changeset (Issue 1: zoxide flag
> absorption; Issue 2: single-quote query). The item contract's stated outcome is
> "likely no changes — document why." This file records the per-section review and
> the decision. **Conclusion: NO README CHANGES REQUIRED.** The README is already
> accurate after the fixes. Rationale per section below.
>
> **Re-verified against the LIVE files at execution time** (commit `97d3251`).
> All four README accuracy grep gates pass, all 9 test files exit 0, and the
> README is byte-identical to its pre-task state. One live-state update to §1
> below: the `--` guard is no longer "pending" — it was **deliberately removed**
> (commit `b93e776`), which makes the NO-CHANGE decision even more robust.

## 0. What the changeset changed (user-visible behavior)

| Fix | Code change | User-visible effect |
|-----|-------------|---------------------|
| **Issue 1** (Layer 2, SHIPPED) | `z-window.sh` + `z-session.sh` reject a multi-line / non-directory `resolved` (defence-in-depth `case … *"$NL"*` + `[ -d ]`). | A leading-dash query (`-l`, `--list`) or any non-directory resolver output **falls back to the current pane dir** (window) / **no-op** (session), instead of corrupting a window. This is the SAME end-user outcome the README already documents for "no match." |
| **Issue 1** (Layer 1, PENDING — `--` guard in `_resolve_zoxide`) | `zoxide query "$1"` → `zoxide query -- "$1"` (P1.M1.T1.S2, still "Researching" at review time). | Makes `resolve()` itself return empty for `-l` (belt-and-braces at the resolver level). **Not required for the user-visible fix** — Layer 2 already guarantees the correct outcome. |
| **Issue 2** (SHIPPED) | binding `%%` → `\"%%\"` (Fix A-alt: `run-shell '…/z-window.sh "%%"'`). | A query containing `'` (e.g. `o'brien`, `Mary's Project`) now resolves correctly instead of being lost. |

**Key fact for the README decision:** the user-visible behavior after the fixes is that
queries with no real directory match fall back to the current pane dir, and special
characters (`'`, spaces) survive. **This is exactly what the README already says** — so
the fixes make the README's existing claims TRUE, not stale.

## 1. The `--` guard status (RESOLVED — not a blocker for this task)

At PRP planning time, the item contract (#2) asserted "the codebase now has: (a) `--`
guard in `_resolve_zoxide`" and §1 of this review flagged a "state discrepancy": the guard
was assumed PENDING in P1.M1.T1.S2, with resolve.sh reading `zoxide query "$1"` (no `--`).

**LIVE state at execution time (verified, commit `b93e776`):** the `--` guard is no longer
pending — it was **deliberately removed**. resolve.sh:12–17 now carries an explanatory
comment block and the call (resolve.sh:18) is `zoxide query "$1"`, with the `--` omitted
**by design**, not by accident. The rationale (recorded in the comment) is that the `--`
guard breaks the rupa/z-backed zoxide shim (which does not parse `--` and treats it as part
of the query), silently no-op'ing BOTH features against the plugin's primary support target;
zoxide itself already rejects a leading-`-` query safely (empty output + exit 0).

**Why this still does not affect the README decision:** the decision is **independent** of
the `--` guard's status — and is now strictly simpler, since "no `--`" is the committed,
intended end state rather than a transient gap:
1. The README's high-level description ("zoxide runs `zoxide query <query>`") is the exact
   form in the code. There is nothing to add or retract — `--` is not present, and even
   if it were, it would be an invisible implementation detail of safe argument passing,
   not a user-facing flag.
2. The **defence-in-depth caller guards ARE shipped** (z-window.sh:36–39, z-session.sh:53–56),
   so the **end-user behavior is correct regardless** of any resolver-level guard. A
   leading-dash query yields a multi-line/empty resolver result that the caller rejects,
   falling back to the current pane dir / no-op.
3. The README documents the **end-user contract** (no-match → fallback), which holds.

So the README needs no change. The explanatory comment at resolve.sh:12–17 is a code-level
artifact owned by P1.M1.T1.S2; the README never quoted it, so it is not a README concern.

## 2. Per-section review matrix

| README section (line range) | Current text (essence) | Fixed behavior | Decision | Rationale |
|---|---|---|---|---|
| Overview / Why (1–22) | "get a new window in the directory zoxide resolves" | Unchanged | **NO CHANGE** | Behavior unchanged. |
| Install (24–54) | "zoxide must be installed…" | Unchanged | **NO CHANGE** | Behavior unchanged. |
| Usage / Window jump (58–67) | "type a query… An empty query or a no-match opens the window in the current pane's directory" | `-l`/no-match now correctly fall back to current dir; `'`/spaces survive | **NO CHANGE** | The fix makes this claim TRUE (pre-fix, `-l` violated it). The README never promised arbitrary-character support, so making `'` work is a strict improvement with no text change. |
| Usage / Session auto-relocate (69–82) | "whose name doesn't resolve, are left at `$HOME`" | Unchanged (defence-in-depth adds a no-op guard) | **NO CHANGE** | Behavior unchanged. |
| Options table (88–97) | 8 options w/ defaults | Unchanged | **NO CHANGE** | No new options; no default changed. |
| **Backends** (106–111) | "`zoxide` runs `zoxide query <query>`. Needs the `zoxide` binary on `$PATH`." | `_resolve_zoxide` calls `zoxide query "$1"` (the `--` guard was tried and **deliberately removed** — it broke the rupa/z shim; see §1) | **NO CHANGE** | The high-level `<query>` form is the exact form in the code. `--` is not present and would be an invisible implementation detail if it were — not a user-visible flag. The no-match→empty→fallback guarantee is already stated in the paragraph below (113–118). |
| Backends / contract paragraph (113–118) | "All three backends return an empty result (and exit 0) when a query has no match… falls back to the current pane's directory" | Holds for the end-user (Layer 2 guarantees it) | **NO CHANGE** | This describes the end-user CONTRACT for no-match queries. It holds for the shipped behavior (Layer 2 rejects any non-directory/multiline, falling back). A leading-dash query is a flag-misparse, not a "no match" — the README makes no claim about flag-like queries, and the fix makes them fall back too. |
| Scope & compatibility (120–131) | `set-hook -g` reload-safe / overwrite note | Unchanged | **NO CHANGE** | Behavior unchanged (this text was added in v1.0; the bugfix doesn't touch the hook). |
| **Known limitations** (133–145) | 5 items: flicker; skip-names whitespace; home-dir single dir; readlink -f GNU; resurrect/continuum `$HOME` false-positive | None resolved or amended by the fixes | **NO CHANGE** | The fixes are defensive hardening; none of the 5 limitations is touched. The leading-dash and single-quote bugs were never documented limitations (they were BUGS, now fixed). Per the contract: "If no limitation is affected, do NOT add or remove anything." |
| License (147–148) | MIT | Unchanged | **NO CHANGE** | — |

## 3. The residual-edge-case question (deliberately NOT added to the README)

Findings §F5 notes the `%%` double-quoting fix leaves residual edge cases: queries
containing `$`, backtick (`` ` ``), backslash (`\`), or double-quote (`"`) may still not
survive the `%%`→`sh -c` chain. These are documented as "vanishingly rare for zoxide
directory queries" (directories essentially never contain these), and full robustness
(bypassing `%%` via `display-popup -E` / `read </dev/tty`) is explicitly **out of scope**
for this bugfix.

**Should the README document this as a Known limitation? NO.**
1. The contract (#3) says: "The fixes are defensive hardening and do not change documented
   behavior for normal queries. If no limitation is affected, do NOT add or remove anything."
2. The README makes **no promise** of arbitrary-character query support (usage says "type a
   query" with no character restriction). Adding a limitation about characters the README
   never claimed to support would be **manufacturing churn** — the exact thing the contract
   forbids ("Do NOT manufacture documentation churn").
3. These characters are genuinely absent from real directory names (`/`, the path
   separator, can't appear in a single path component; `$`, `` ` ``, `\`, `"` are exotic).
4. The `'` (apostrophe) case — which IS realistic (`o'brien`) — now works, so there is no
   realistic regression to warn about.

This residual is documented HERE (in the review notes) so it is not lost, but it is **not**
surfaced into the README. If a future release wants to over-promise arbitrary-character
support, it would add a corresponding limitation then; today the README is accurate by
omission.

## 4. Decision and output

**DECISION: NO README CHANGES.** The README is already accurate after the bugfix changeset.
Every section was reviewed against the fixed (and in-flight) behavior; none is stale, none
contradicts the fixed behavior, and none needs amendment. The fixes are defensive
hardening that make the README's existing claims hold for adversarial inputs.

**Required output of this task:**
- `README.md`: **UNTOUCHED** (no edit). (If, contrary to this analysis, the implementer
  finds a genuinely stale statement, make the minimal surgical fix and document it — but
  the review found none.)
- Record this decision + rationale (this review matrix) so the changeset-level doc-sync is
  accounted for and the "no churn" outcome is explicit, not an oversight.

**Anti-churn guard:** the single most likely failure mode for this task is an
implementer who *feels obligated to add documentation* ("we fixed two bugs, surely the
README must say something"). It must not. The contract's explicit guidance — "If the
README is already accurate after the fixes, make NO changes and document why… Do NOT
manufacture documentation churn" — is the governing instruction. No edit is the correct,
contract-compliant outcome.

## 5. Validation (what "done" looks like) — EXECUTED

All gates run at execution time against the live files (commit `97d3251`). Results:

- `git diff --stat README.md` → **empty** (README byte-identical to pre-task state).
- A written decision record (this file) exists, naming each reviewed section and the
  "NO CHANGE" rationale, plus the §1 `--`-guard status and §3 residual note.
- Test suite (regression sanity — a doc-only task cannot regress code):
  all 9 `tests/test_*.sh` exit 0:
  `OK test_backend_matrix.sh`, `OK test_resolve_dispatcher.sh`, `OK test_resolve_get_tmux_option.sh`,
  `OK test_resolve_zoxide.sh`, `OK test_resolve_z.sh`, `OK test_run_file.sh`,
  `OK test_session_hook.sh`, `OK test_z_session.sh`, `OK test_z_window.sh`.
- README accuracy grep gates:
  - (a) `grep -n 'zoxide query' README.md` → two matches (line 76 usage example
    `zoxide query sellario`; line 107 the Backends description `` `zoxide query <query>` ``).
    Both high-level `<query>` form; **no `--` leak**.
  - (b) `grep -niE "single quote|apostrophe|leading.dash|end-of-options|-- guard|flag absor" README.md`
    → **empty** (exit 1). The README never documented the now-fixed bugs, so nothing to retract.
  - (c) `sed -n '/^## Known limitations/,/^## /p' README.md | grep -cE '^- '` → **5**
    (flicker; skip-names whitespace; home-dir single dir; readlink -f GNU; resurrect $HOME
    false-positive). Unchanged.
  - (d) The "no-match → current pane dir" claim is intact at README lines 66–67:
    "An empty query or a no-match opens the window in the current pane's directory".
    (Note: this sentence wraps across a line break, so a single-line `grep -n` of the full
    sentence returns nothing — the claim IS present, just wrapped. Verified with `grep -n
    'no-match'` → line 66.)

**Outcome: all gates pass; NO README CHANGES.**
