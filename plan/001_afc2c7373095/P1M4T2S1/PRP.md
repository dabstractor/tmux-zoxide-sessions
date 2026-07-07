name: "P1.M4.T2.S1 — Executable bits, §7 test matrix, §9 acceptance verification"
description: >
  Verification task (Mode B): confirm the tmux-zoxide-sessions MVP meets PRD §9 by
  (a) ensuring the executable bit is COMMITTED for the 3 runnable files, (b) running the
  PRD §7 test matrix (10 cases) and recording outcomes, (c) producing an acceptance report
  satisfying every §9 criterion. No user-facing source changes; one new automated test
  (backend matrix) + one acceptance-report artifact.

---

## Goal

**Feature Goal**: Prove, via deterministic automated tests + documented manual checks, that
the shipped tmux-zoxide-sessions plugin satisfies **all** PRD §9 acceptance criteria, and
that the executable bit is committed to git for every runnable file (so TPM does not
silently no-op the run file after a fresh clone).

**Deliverable** (three artifacts):
1. `tests/test_backend_matrix.sh` — NEW POSIX-sh integration test that exercises BOTH the
   window feature and the session feature against all three resolver backends (real
   `zoxide`, a `zoxide` shim, and real rupa/z via `@zoxide-sessions-z-sh`), on an
   isolated tmux server. This is the only §9 criterion with NO existing automated coverage.
2. `plan/001_afc2c7373095/P1M4T2S1/acceptance_report.md` — the acceptance report:
   executable-bit verification, the full §7 10-case matrix results, the §9 checklist
   (each criterion PASS / DEFERRED-to-parallel / FAIL with evidence), and the backend-matrix
   evidence.
3. A git commit (only if needed) recording corrected executable bits — see Task 1.

**Success Definition**:
- All existing tests in `tests/` pass (they ARE the §7 matrix for cases 1–4, 6, 7, 8, 9).
- The new `tests/test_backend_matrix.sh` passes for all three backends.
- `git ls-files -s` shows `100755` for `tmux-zoxide-sessions.tmux`,
  `scripts/z-window.sh`, `scripts/z-session.sh` and `100644` for `scripts/lib/resolve.sh`.
- Manual cases 5 (sessionx) & 10 (resurrect) recorded with evidence/reasoning.
- The acceptance report marks every §9 criterion. The README criterion is marked
  **DEFERRED-to-parallel (P1.M4.T1.S1)** if `README.md` is absent, never as a failure here.

## User Persona

**Target User**: The downstream reviewer/orchestrator reading the acceptance report to gate
release of the v1.0 MVP, plus any future maintainer re-running the matrix after a change.

**Use Case**: "Has the MVP met its own spec? Show me the pass/fail evidence for every §7
case and every §9 criterion, including a fresh-clone-safe executable bit."

**User Journey**: Run `sh tests/test_backend_matrix.sh` (and the existing suite); read the
acceptance report; each §9 bullet points at the test/check that proves it.

**Pain Points Addressed**: Without this task, §7 case coverage is scattered across 8 test
files with no single recorded matrix, the executable bit's *committed* state (vs worktree
state) is unverified, the backend-agnostic §9 criterion is unproven, and §9 as a whole has
no signed-off report.

## Why

- **Executable bit = linchpin.** Per `architecture/external_deps.md §2`, TPM globs and
  *executes* `*.tmux`; the bit must be COMMITTED (`git update-index --chmod=+x`) or it is
  lost on clone and TPM silently no-ops the run file (session feature never wires).
- **§9 is the release gate** for the whole MVP (M1–M4). P1.M4.T2.S1 is the only task whose
  job is to *prove* §9, end to end, on an isolated server.
- **Scope/cohesion:** All implementation subtasks (M1 resolver, M2 window, M3 session hook)
  are complete; P1.M4.T1.S1 (README) runs in parallel. This task must not duplicate their
  work or edit source. Any failure it finds loops back to the OWNING subtask (per the work
  item contract), it does not patch source itself — EXCEPT the executable-bit commit, which
  is explicitly this task's deliverable.

## What

A verification pass with one new test file + one report. Concretely:

1. **Verify & commit executable bits** (§9 bullet 1). At PRP time they are already correct
   (`100755` / `100755` / `100755` / `100644`) — this is a verify-and-confirm; fix only if
   a regression is found.
2. **Run the §7 matrix** by executing the full existing `tests/` suite (covers cases 1–4,
   6, 7, 8, 9) PLUS the new backend-matrix test, PLUS manual reasoning for cases 5 & 10.
3. **Verify §9 holistically:** 6 files at §5.1 paths; executable scripts/run-file; §7 pass;
   `show-hooks` form; shared `lib/resolve.sh` with no duplicated resolver; backend matrix;
   README (deferred-safe).
4. **Write the acceptance report.**

### Success Criteria

- [ ] `git ls-files -s -- tmux-zoxide-sessions.tmux scripts/z-window.sh scripts/z-session.sh`
      shows `100755` for all three; `scripts/lib/resolve.sh` shows `100644`.
- [ ] Every file in `tests/test_*.sh` passes when run with `sh`.
- [ ] `tests/test_backend_matrix.sh` passes (all 3 backends × both features).
- [ ] Manual cases 5 & 10 recorded in the report with evidence or primary-source reasoning.
- [ ] `tmux show-hooks -g session-created` (isolated server, `auto-session != off`) shows
      `run-shell -b "<abs>/scripts/z-session.sh \"#{session_name}\""`; shows nothing when `off`.
- [ ] No duplicated resolver: `zoxide query` and `_z` appear ONLY in `scripts/lib/resolve.sh`.
- [ ] Acceptance report exists at the work-item path and records every §9 bullet.
- [ ] **No source/script/run-file edits** (except an executable-bit commit if a regression
      is found). `PRD.md`, `tasks.json`, `.gitignore`, `LICENSE` untouched.

## All Needed Context

### Context Completeness Check

If someone knew nothing about this codebase, would they have everything needed to
implement this successfully? **Yes** — the §7 matrix is quoted verbatim from the PRD, the
isolated-tmux harness pattern is fully specified (with a proven reference test to copy), the
manual-case reasoning is supplied, and every §9 criterion is mapped to an executable check.
The only judgment call is faithfully transcribing the harness conventions into the new test.

### Documentation & References

```yaml
# MUST READ — primary sources of truth
- docfile: PRD.md
  why: "§7 is the verbatim 10-case test matrix (table + the read-pane-cwd snippet). §9 is the
        acceptance checklist this task must satisfy. §5.1 is the canonical 6-file tree. §6.3
        lists the three backend forms. §3.2 is the session guard chain the tests assert."
  section: "§5.1 File tree; §6.3 Requirements; §7 Test matrix; §9 Acceptance criteria."

- docfile: plan/001_afc2c7373095/architecture/external_deps.md
  why: "§2 = the executable-bit COMMIT requirement (git update-index --chmod=+x) and TPM's
        glob-and-execute contract. §3 = resurrect uses `-c \"$saved_dir\"` (case 10 reasoning).
        §4 = sessionx/sesh place via `-c` (case 5 reasoning). §6 = the isolated-server testing
        strategy this task must follow."
  section: "§2 TPM loading contract; §3 resurrect linchpin; §4 sessionx/sesh; §6 testing strategy."

- docfile: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: "✅ list item 1 confirms session-created hook timing (pane exists, cwd readable) — the
        basis for asserting relocate. ✅ item 5 confirms zoxide empty+exit0 on no-match (case 3).
        🟡 NOTE C confirms set-hook -g OVERWRITES + is reload-safe (the show-hooks form check)."

- file: plan/001_afc2c7373095/P1M4T2S1/research/verification_findings.md
  why: "THIS task's raw research: committed-mode-bit table, the §7↔existing-test coverage map,
        the manual-case reasoning, and the README deferred-safe rule. Mirror it into the report."

# Reference tests — COPY these patterns verbatim for the new backend-matrix test
- file: tests/test_z_session.sh
  why: "The PROVEN harness for driving the REAL z-session.sh on an isolated server with a
        zoxide shim. Copy its: REAL_TMUX/SOCK/cleanboot/fake-tmux-wrapper/fake-zoxide/check/
        contains helpers, the respawn settle sleep, and the pane-cwd assertion form."
  pattern: "REAL_TMUX=${REAL_TMUX:-/usr/bin/tmux}; SOCK=zxstest_session; cleanboot() with
            tmux -f /dev/null -L; PATH=\\$TBIN:\\$PATH set BEFORE boot; display-message -t
            <session> -p #{pane_current_path} (session target, not :1.0, to dodge base-index)."
  gotcha: "respawn-pane needs a >=0.4s settle before #{pane_current_path} reflects the new dir."

- file: tests/test_run_file.sh
  why: "The PROVEN harness for the WINDOW feature on an isolated server: executing the run
        file directly ($RUN), asserting the binding via list-keys -1 -T prefix g, and
        triggering z-window.sh via run-shell to assert a new-window lands in the resolved dir."
  pattern: "Fake zoxide returns a REAL fixture dir (mkdir -p it) for a known query; execute
            the run file as \"$RUN\" >/dev/null 2>&1 exactly as TPM does."
  gotcha: "list-keys -1 (the -1 is mandatory) — without it the lookup is ambiguous."

- file: tests/test_session_hook.sh
  why: "The PROVEN harness for the show-hooks FORM check (§9 bullet 3). Copy its assertion
        that show-hooks contains 'run-shell -b' + the ABS path + #{session_name} when
        auto-session=on, and contains nothing when off."

# Shipped source under test (read-only — do NOT edit)
- file: scripts/lib/resolve.sh
  why: "The shared resolver. §9 bullet 4 requires NO duplicated resolver: confirm the only
        `zoxide query` / `_z` calls in the repo live HERE. The backend dispatch (zoxide/z/auto)
        is what the backend-matrix test drives by flipping @zoxide-sessions-backend."

- file: scripts/z-session.sh
  why: "The session guard chain under test. Its `path == $HOME` exit is the basis for cases
        4/5/10 (not-$HOME skip). Invoked by the hook as `z-session.sh \"#{session_name}\"`."

- file: scripts/z-window.sh
  why: "The window handler under test. `query=\"$*\"` recombines spaces (case 9 basis)."

- file: tmux-zoxide-sessions.tmux
  why: "The run file TPM executes. Must be 100755 in git. Its set-hook -g line is what the
        show-hooks form check verifies."

# Parallel-task contract (README may not exist yet at run time)
- docfile: plan/001_afc2c7373095/P1M4T1S1/PRP.md
  why: "Defines README.md (authored in parallel). §9's last bullet ('README documents every
        option and the $HOME-guard model') is OWNED by P1.M4.T1.S1. If README.md is absent at
        run time, mark that bullet DEFERRED-to-parallel, not FAIL."
```

### Current Codebase tree (run `ls` in the repo root)

```bash
tmux-zoxide-sessions/
  .gitignore
  LICENSE                       # MIT (M1.T1) — one of the 6 §5.1 files
  PRD.md                        # READ-ONLY spec
  README.md                     # authored by PARALLEL P1.M4.T1.S1 — may be absent at run time
  tmux-zoxide-sessions.tmux     # run file (100755 committed) — window binding + session hook
  scripts/
    lib/resolve.sh              # shared resolver (100644 committed — SOURCED, no +x)
    z-window.sh                 # window-jump handler (100755 committed)
    z-session.sh                # session-created handler (100755 committed)
  tests/                        # POSIX-sh integration tests (8 files)
    test_resolve_*.sh           # resolver unit tests (M1.T2)
    test_z_window.sh            # window handler (M2.T1)
    test_run_file.sh            # run file binding + §7 case 8 (M2.T2)
    test_z_session.sh           # session handler + §7 cases 1-4,6,7,9 (M3.T1)
    test_session_hook.sh        # hook wiring + show-hooks form + §7 cases 6,9 (M3.T2)
  plan/001_afc2c7373095/        # plan + PRPs + architecture/{external_deps,findings_and_risks}.md
```

### Desired Codebase tree with files to be added/modified

```bash
tmux-zoxide-sessions/
  tests/
    test_backend_matrix.sh      # NEW (this task). 3 backends × {window,session} on isolated server.
  plan/001_afc2c7373095/P1M4T2S1/
    acceptance_report.md        # NEW (this task). §7 matrix + §9 checklist + evidence.
# POSSIBLE (only if a mode-bit regression is found): a git commit updating file mode bits.
#   No other source/doc/config files are touched by this task.
```

### Known Gotchas of our codebase & Library Quirks

```bash
# CRITICAL (external_deps §2): the executable bit must be COMMITTED, not just present in the
# worktree. A worktree `chmod +x` that is never `git add`-ed is LOST on clone and TPM silently
# no-ops the run file. Verify with `git ls-files -s -- <file>` (100755), NOT `ls -l`.
# Fix with: git update-index --chmod=+x <file>   (then commit). resolve.sh stays 100644 (sourced).

# CRITICAL: drive an ISOLATED tmux server (`tmux -L zxstest...`), NEVER the user's live server.
# The user's server has their session-created hooks, sessions, and cwd — asserting against it
# is destructive and non-deterministic. Every test in tests/ already uses this pattern.

# CRITICAL: boot the isolated server with `tmux -f /dev/null -L <sock> ...` so the USER's
# tmux.conf is NOT sourced (a stray session-created hook would pollute show-hooks assertions).
# (test_session_hook.sh verified_notes §8.)

# GOTCHA: `display-message -t '<session>:1.0'` (PRD §7 literal) assumes base-index=1. The
# isolated server defaults to base-index=0, so the first pane is :0.0. Target the SESSION
# instead: `display-message -t '<session>' -p '#{pane_current_path}'` (active pane, no index).

# GOTCHA: respawn-pane needs a >=0.4s settle sleep before #{pane_current_path} reflects the
# new cwd. The window feature (new-window) is synchronous — use #{pane_start_path} there.

# GOTCHA: `tmux show-hooks -g session-created` ALWAYS prints the `session-created` hook NAME
# line even when no command is set. Assert on 'run-shell -b' PRESENCE, not on hook-name count.

# GOTCHA: real-zoxide results are environment-specific. Do NOT hardcode a resolved path;
# capture `zoxide query <q>` at run time and assert the pane cwd EQUALS that captured value.

# GOTCHA (rupa/z backend): set BOTH @zoxide-sessions-z-sh=<abs z.sh> AND backend=z (or remove
# zoxide from PATH with backend=auto). _resolve_z short-circuits to empty if z-sh is unset.

# CRITICAL: this task must NOT edit source. If a §7 case FAILS, record it and route to the
# OWNING subtask (per the work-item contract) — do not patch the script here. The ONLY source-
# touching action permitted is the executable-bit commit (Task 1), and only if regressed.
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. This task produces shell tests + a Markdown report.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 0: SNAPSHOT the baseline (record-keeping, no changes)
  - RUN: `git ls-files -s -- tmux-zoxide-sessions.tmux scripts/z-window.sh scripts/z-session.sh scripts/lib/resolve.sh`
    and save the output into the acceptance report's "Executable bits" section.
  - RUN: `ls -1 tests/test_*.sh` to enumerate the existing suite.
  - WHY: gives a before-state for the report so any later mode-bit commit is auditable.

Task 1: VERIFY + (only if needed) COMMIT executable bits  [§9 bullet 1]
  - CHECK committed mode: `git ls-files -s -- tmux-zoxide-sessions.tmux scripts/z-window.sh scripts/z-session.sh`
    must show `100755` for all three. `git ls-files -s -- scripts/lib/resolve.sh` must show `100644`.
  - IF any executable is `100644`: run `git update-index --chmod=+x <file>` for each, then
    `git commit -m "Set executable bit on runnable scripts (§9 acceptance)"`. Leave resolve.sh at 100644.
  - IF the run file `tmux-zoxide-sessions.tmux` shows ` M` in `git status` (uncommitted P1.M3.T2.S1
    append): that content change is OUT OF SCOPE here — do NOT commit it on this task's behalf
    unless it is strictly the mode bit. Stage via `git add` only if committing a mode fix, and
    re-run `git ls-files -s` after staging to confirm `100755` survived.
  - VERIFY after any commit: `git ls-files -s` again — all three still `100755`.
  - EVIDENCE: paste the final `git ls-files -s` output into the acceptance report.
  - REFERENCE: external_deps.md §2 ("the executable bit must be committed").

Task 2: RUN the existing §7 coverage (cases 1-4, 6, 7, 8, 9)  [§9 bullet 2]
  - RUN every test: `for t in tests/test_*.sh; do echo "--- $t ---"; sh "$t" || echo "FAILED: $t"; done`
    (exclude test_backend_matrix.sh until Task 3 creates it; or run it last once it exists).
  - RECORD pass/fail per file. Map each file to its §7 cases using the table in
    research/verification_findings.md §2 (e.g. test_z_session.sh → cases 1,2,3,4,6,7,9).
  - NOTE: test_session_hook.sh C6/C7 use a PROBE z-session.sh; the REAL-handler relocate proof
    is in test_z_session.sh. Both must pass.
  - IF a case fails: record the failing assertion verbatim and route to the owning subtask
    (M1.T2 resolver / M2.T1 z-window / M2.T2 run file / M3.T1 z-session / M3.T2 hook wiring).
    Do NOT patch source here.

Task 3: CREATE tests/test_backend_matrix.sh  [§9 bullet 5 — the only NEW automated work]
  - GOAL: prove BOTH features work with (a) real zoxide, (b) a zoxide shim, (c) rupa/z.
  - COPY the harness skeleton from tests/test_z_session.sh + tests/test_run_file.sh:
      REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"; SOCK="zxstest_backend"
      cleanboot() { kill old server; sleep 0.2; tmux -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX"; sleep 0.2; }
      fake-tmux wrapper on $TBIN/tmux forwarding to -L "$SOCK"; export PATH="$TBIN:$PATH" BEFORE boot.
      check()/contains() helpers; trap cleanup kill-server + rm -rf.
  - FIXTURE: a REAL temp dir tree: $FIX/home, $FIX/seed (a dir you will add to BOTH the
    zoxide index and the rupa/z index under a known query token, e.g. "zxmatrix"). mkdir all.
  - SUBTEST A — real zoxide:
      * Ensure a deterministic match: `zoxide add "$FIX/seed"` (seeds the REAL index — acceptable;
        it is the user's frecency DB; or use the already-resolvable `tmux` token and capture its
        value at runtime). Capture EXPECTED=$(zoxide query zxmatrix).
      * cleanboot; set @zoxide-sessions-backend zoxide; @zoxide-sessions-home-dir "$FIX/home".
      * WINDOW: run-shell "$REPO_ROOT/scripts/z-window.sh zxmatrix"; sleep 0.4; assert the newest
        window's #{pane_start_path} == EXPECTED and window_name == basename.
      * SESSION: new-session -d -s zxmatrix -c "$FIX/home"; run "$ZSESS" zxmatrix; sleep 0.5;
        assert display-message -t zxmatrix -p #{pane_current_path} == EXPECTED.
  - SUBTEST B — zoxide shim:
      * Remove real zoxide from PATH (PATH without /home/dustin/.local/bin) OR rely on $TBIN/tmux
        shadowing + a $TBIN/zoxide shim returning "$FIX/seed" for "zxmatrix", empty otherwise.
      * Repeat the WINDOW + SESSION assertions; EXPECTED="$FIX/seed".
  - SUBTEST C — rupa/z (z backend):
      * Set @zoxide-sessions-z-sh "/home/dustin/.config/znap/rupa/z/z.sh" AND backend=z.
      * Seed the rupa/z index: run a shell that sources z.sh, cd into $FIX/seed, to populate _Z_DATA
        (rupa/z ranks on cd). Capture EXPECTED via: zsh -c '. "<z.sh>"; _z zxmatrix' after seeding
        (compare pwd before/after, mirroring _resolve_z). Use the SAME known token.
      * Repeat WINDOW + SESSION assertions; EXPECTED == captured rupa/z resolve.
  - EXIT: `echo "RESULTS: pass=$pass fail=$fail"; [ "$fail" -eq 0 ]`.
  - NAMING: `tests/test_backend_matrix.sh`, `#!/bin/sh`, functions check/contains/cleanboot.
  - PLACEMENT: tests/ (sibling of the other test_*.sh files).
  - GOTCHA: real-zoxide index is shared with the user — prefer a throwaway token ("zxmatrix")
    and `zoxide add`/`zoxide remove` around the test, OR document that the test seeds+cleans its
    own token. rupa/z uses a per-process _Z_DATA unless $ _Z_DATA is set; seed inside the subshell
    the resolver spawns (set _Z_DATA to a temp file) for determinism.

Task 4: MANUAL verify cases 5 (sessionx) & 10 (resurrect)  [§7 — not unit-testable]
  - CASE 5 reasoning (record in report): sessionx/sesh create via `new-session -d -s <n> -c <resolved>`
    (external_deps §4) so pane_current_path != $HOME → z-session.sh exits at the path guard. The
    design keys off OBSERVED cwd, not tool identity. OPTIONAL live probe on the isolated server:
    `tmux -L zxstest_backend new-session -d -s sxprobe -c "$FIX/seed"`, run z-session.sh, assert
    NO respawn (cwd unchanged). Record the probe result if run.
  - CASE 10 reasoning (record): resurrect restore.sh uses `new-session -d -s <n> -c "$saved_dir"`
    (external_deps §3, primary-source quote); continuum delegates to resurrect. Restored sessions
    land at saved cwd → path guard exits. Only a session whose saved cwd WAS $HOME relocates
    (documented false positive). OPTIONAL live probe: skip unless resurrect is installed; otherwise
    cite external_deps §3 as primary-source evidence.
  - EVIDENCE: a one-paragraph rationale + the external_deps section anchor for each case.

Task 5: VERIFY §9 bullets 3 & 4 (hook form + shared resolver)  [§9 bullets 3,4]
  - BULLET 3 (show-hooks form): on the isolated server, cleanboot, set auto-session on, run the
    REAL run file; `tmux -L zxstest_backend show-hooks -g session-created` must contain
    `run-shell -b "<abs repo>/scripts/z-session.sh \"#{session_name}\""`. Then set auto-session off,
    re-run the run file; show-hooks must NOT contain `run-shell -b`. (Mirror test_session_hook.sh C2/C3.)
  - BULLET 4 (no duplicated resolver): `grep -RnE 'zoxide query|_z ' scripts/ tmux-zoxide-sessions.tmux`
    must show matches ONLY inside scripts/lib/resolve.sh. Confirm z-window.sh and z-session.sh both
    source it: `grep -n 'lib/resolve.sh' scripts/z-window.sh scripts/z-session.sh`.

Task 6: README gate (DEFERRED-SAFE)  [§9 bullet 6 — owned by parallel P1.M4.T1.S1]
  - IF README.md exists at repo root: run the content gate from P1.M4.T1.S1's PRP Validation —
    grep for all 8 @zoxide-sessions-* options + the `never land in \`$HOME\`` sentence; record PASS.
  - IF README.md is ABSENT: record the bullet as "DEFERRED to P1.M4.T1.S1 (parallel)" with a note
    that it is NOT a failure of P1.M4.T2.S1. Do NOT create README.md here.

Task 7: WRITE acceptance_report.md  [the task's primary OUTPUT]
  - PATH: plan/001_afc2c7373095/P1M4T2S1/acceptance_report.md
  - SECTIONS (in order):
      1. Header + date + tmux/zoxide/rupa-z versions discovered.
      2. Executable bits: the `git ls-files -s` table (before/after if a commit was made).
      3. §7 matrix: a 10-row table (Case | Automated by | Result | Evidence).
      4. Backend matrix: the 3×2 grid (backend × feature) result + which test proves it.
      5. §9 checklist: each of the 6 bullets → PASS / DEFERRED-to-parallel / FAIL + pointer.
      6. Failures & routing: any FAIL → named owning subtask (do not patch here).
      7. Sign-off line.
  - EVIDENCE: paste actual command output (git ls-files -s, show-hooks, test RESULTS: lines).
```

### Implementation Patterns & Key Details

```sh
# Pattern: isolated-server harness (copy from tests/test_z_session.sh / test_run_file.sh)
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_backend"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$(mktemp -d)"; mkdir -p "$FIX/home" "$FIX/seed"
TBIN="$FIX/.tbin"; mkdir -p "$TBIN"
cleanup() { "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true; rm -rf "$FIX"; }
trap cleanup EXIT INT TERM
# fake tmux wrapper -> forwards every bare `tmux` to the isolated server
printf '#!/bin/sh\nexec "%s" -L "%s" "$@"\n' "$REAL_TMUX" "$SOCK" > "$TBIN/tmux"; chmod +x "$TBIN/tmux"
export PATH="$TBIN:$PATH"   # set BEFORE boot so run-shell inherits it
cleanboot() { "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true; sleep 0.2
  "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX" || exit 2; sleep 0.2; }

# Pattern: assert a SESSION relocate (respawn) — target the SESSION, settle >=0.4s
"$REAL_TMUX" -L "$SOCK" new-session -d -s zxmatrix -c "$FIX/home"
"$REPO_ROOT/scripts/z-session.sh" zxmatrix        # exactly what the hook dispatches
sleep 0.5
got=$("$REAL_TMUX" -L "$SOCK" display-message -t zxmatrix -p '#{pane_current_path}')
[ "$got" = "$EXPECTED" ]   # EXPECTED captured from the backend at run time

# Pattern: assert a WINDOW jump — new-window is synchronous, use pane_start_path
"$REAL_TMUX" -L "$SOCK" run-shell "$REPO_ROOT/scripts/z-window.sh zxmatrix"; sleep 0.4
idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
got=$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{pane_start_path}')

# Pattern: show-hooks FORM check (§9 bullet 3) — assert run-shell PRESENCE, not hook-name count
hk=$("$REAL_TMUX" -L "$SOCK" show-hooks -g session-created)
printf '%s' "$hk" | grep -Fq 'run-shell -b'                                # when auto-session != off
printf '%s' "$hk" | grep -Fq "$REPO_ROOT/scripts/z-session.sh"
printf '%s' "$hk" | grep -Fq '#{session_name}'

# Pattern: executable-bit COMMIT check (§9 bullet 1) — git ls-files -s, NOT ls -l
git ls-files -s -- tmux-zoxide-sessions.tmux scripts/z-window.sh scripts/z-session.sh
# expect: 100755 for all three
git ls-files -s -- scripts/lib/resolve.sh
# expect: 100644 (sourced, not executed)
# fix a regression: git update-index --chmod=+x <file>   (then commit)

# Pattern: no duplicated resolver (§9 bullet 4)
grep -RnE 'zoxide query|[^_a-zA-Z]_z ' scripts/ tmux-zoxide-sessions.tmux   # only in lib/resolve.sh
```

### Integration Points

```yaml
GIT:
  - "If a mode-bit regression is found: `git update-index --chmod=+x tmux-zoxide-sessions.tmux
      scripts/z-window.sh scripts/z-session.sh` then `git commit -m 'Set executable bit on runnable
      scripts (§9 acceptance)'`. Leave scripts/lib/resolve.sh at 100644."

TESTS:
  - "New file: tests/test_backend_matrix.sh (POSIX sh, #!/bin/sh, executable bit not required for
     `sh <file>` invocation, but set 100755 for consistency with the rest of tests/ and commit it)."

REPORT:
  - "New file: plan/001_afc2c7373095/P1M4T2S1/acceptance_report.md (Markdown; the task's OUTPUT)."

# NOTHING ELSE: no PRD.md / tasks.json / .gitignore / source edits / README creation.
```

## Validation Loop

There is no Python/ruff/mypy here (POSIX-sh project). The validators are `sh` test runs,
`shellcheck`, `git ls-files -s`, and grep content checks.

### Level 1: Syntax & Style

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# Lint the new test with the project's available linter.
shellcheck tests/test_backend_matrix.sh
# Expected: no errors. (Existing tests pass shellcheck; match their style — `set -u`,
# quoted expansions, no bashisms since #!/bin/sh.)

# Sanity: it has a shebang and the standard RESULTS line.
head -1 tests/test_backend_matrix.sh | grep -qx '#!/bin/sh'
grep -q '^RESULTS: pass=' tests/test_backend_matrix.sh
```

### Level 2: The existing §7 suite (cases 1-4, 6, 7, 8, 9)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions
for t in tests/test_resolve_dispatcher.sh tests/test_resolve_get_tmux_option.sh \
         tests/test_resolve_zoxide.sh tests/test_resolve_z.sh \
         tests/test_z_window.sh tests/test_run_file.sh \
         tests/test_z_session.sh tests/test_session_hook.sh; do
  echo "=== $t ==="; sh "$t" || echo "!!! FAILED: $t"
done
# Expected: every file ends with "RESULTS: pass=<n> fail=0" and exits 0.
# Record each result in the acceptance report's §7 table.
```

### Level 3: The new backend matrix (§9 bullet 5)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions
sh tests/test_backend_matrix.sh
# Expected: "RESULTS: pass=<n> fail=0", exit 0. Covers real zoxide + shim + rupa/z,
# each × {window feature, session feature}.
```

### Level 4: §9 holistic checks (executable bits, hook form, shared resolver, README)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# §9 bullet 1 — committed executable bits.
git ls-files -s -- tmux-zoxide-sessions.tmux scripts/z-window.sh scripts/z-session.sh \
  | awk '{print $1}' | sort -u
# Expected output: exactly "100755".
git ls-files -s -- scripts/lib/resolve.sh | awk '{print $1}'
# Expected output: "100644".

# §9 bullet 3 — show-hooks form (drive an isolated server; one-shot inline check).
SOCK=zxstest_verify; REPO="$PWD"
tmux -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
tmux -f /dev/null -L "$SOCK" new-session -d -s v -c /tmp
tmux -L "$SOCK" set -g '@zoxide-sessions-auto-session' on
"$REPO/tmux-zoxide-sessions.tmux" >/dev/null 2>&1
tmux -L "$SOCK" show-hooks -g session-created \
  | grep -F "run-shell -b \"$REPO/scripts/z-session.sh \\\"#{session_name}\\\"\"" \
  && echo "OK hook form (on)"
tmux -L "$SOCK" set -g '@zoxide-sessions-auto-session' off
"$REPO/tmux-zoxide-sessions.tmux" >/dev/null 2>&1
tmux -L "$SOCK" show-hooks -g session-created | grep -q 'run-shell -b' \
  && echo "FAIL: hook still set when off" || echo "OK hook absent (off)"
tmux -L "$SOCK" kill-server 2>/dev/null

# §9 bullet 4 — no duplicated resolver.
grep -RnE 'zoxide query|[^_a-zA-Z]_z ' scripts/ tmux-zoxide-sessions.tmux
# Expected: matches ONLY on lines inside scripts/lib/resolve.sh.
grep -n 'lib/resolve.sh' scripts/z-window.sh scripts/z-session.sh
# Expected: both files source it.

# §9 bullet 6 — README gate (DEFERRED-SAFE).
if [ -f README.md ]; then
  for opt in key prompt backend z-sh auto-session home-dir skip-names window-name; do
    grep -q "@zoxide-sessions-${opt}" README.md || echo "MISSING opt $opt"
  done
  grep -q 'never land in `$HOME`' README.md && echo "OK README gate" || echo "MISSING home-guard"
else
  echo "DEFERRED: README.md authored by parallel P1.M4.T1.S1 — not a failure of this task."
fi

# §9 bullet 2 — the 6 §5.1 files all exist.
for f in tmux-zoxide-sessions.tmux scripts/lib/resolve.sh scripts/z-window.sh \
         scripts/z-session.sh README.md LICENSE; do
  [ -f "$f" ] && echo "OK $f" || echo "MISSING $f"
done
```

## Final Validation Checklist

### Technical Validation

- [ ] Level 1: `shellcheck tests/test_backend_matrix.sh` clean; shebang + RESULTS line present.
- [ ] Level 2: all 8 existing `tests/test_*.sh` pass (`fail=0`).
- [ ] Level 3: `tests/test_backend_matrix.sh` passes (3 backends × 2 features).
- [ ] Level 4: executable bits `100755`/`100644` committed; show-hooks form correct on/off;
      no duplicated resolver; README gate run (PASS or DEFERRED); 6 §5.1 files present.

### Feature Validation

- [ ] §7 cases 1, 2, 3, 4, 6, 7, 8, 9 each map to a PASSING existing test (recorded in report).
- [ ] §7 cases 5 & 10 recorded with evidence/primary-source reasoning.
- [ ] §9 bullet 5 (all three backends) proven by `tests/test_backend_matrix.sh`.
- [ ] §9 bullet 3 (show-hooks absolute path + `\"#{session_name}\"` form) verified on/off.

### Code Quality / Scope Validation

- [ ] `tests/test_backend_matrix.sh` follows the existing harness conventions (isolated server,
      `tmux -f /dev/null -L`, fake-tmux wrapper, `set -u`, `check/contains/cleanup`).
- [ ] `tests/test_backend_matrix.sh` is committed with `100755` (consistent with `tests/`).
- [ ] Acceptance report at `plan/001_afc2c7373095/P1M4T2S1/acceptance_report.md`.
- [ ] **No** source/script/run-file edits (except an executable-bit commit if regressed).
- [ ] `PRD.md`, `tasks.json`, `.gitignore`, `LICENSE` untouched; README not created here.

### Documentation & Deployment

- [ ] Acceptance report is self-contained: versions, bit table, §7 table, backend grid,
      §9 checklist, failure routing, sign-off.
- [ ] Any FAIL routes to the named owning subtask (no silent in-task patches).

---

## Anti-Patterns to Avoid

- ❌ **Don't touch the user's live tmux server.** Always `tmux -L zxstest...` + `tmux -f /dev/null`.
- ❌ **Don't verify the executable bit with `ls -l`.** Use `git ls-files -s` — only the COMMITTED
  mode survives a clone (external_deps §2). A worktree `chmod +x` that isn't committed is the bug.
- ❌ **Don't hardcode `:1.0`** to read a pane cwd. Target the session (`-t <name>`) to avoid
  base-index fragility; the PRD §7 literal assumes base-index=1.
- ❌ **Don't assert on the `session-created` hook-name line count** — it always lists. Assert on
  `run-shell -b` presence (test_session_hook.sh verified_notes §2).
- ❌ **Don't hardcode a real-zoxide resolved path** — it is environment-specific. Capture
  `zoxide query <token>` at run time and compare.
- ❌ **Don't patch source to make a failing §7 case pass.** Record it and route to the owning
  subtask. The only source-touching action allowed is the executable-bit commit.
- ❌ **Don't create README.md** — it is owned by parallel P1.M4.T1.S1. Mark its §9 bullet
  DEFERRED-to-parallel if absent.
- ❌ **Don't commit the uncommitted `tmux-zoxide-sessions.tmux` content change** (the P1.M3.T2.S1
  append) on this task's behalf — that is M3.T2's deliverable. Only commit a MODE-bit fix, and
  re-verify the index mode after staging.
- ❌ **Don't run `zoxide add` without cleaning up** if you seed a throwaway token — remove it
  after the test so the user's frecency index is not polluted.

---

## Confidence Score

**8/10** — one-pass success is likely: the harness pattern is already proven by 8 existing
tests, the §7↔coverage map is pre-computed, the manual-case reasoning is supplied, and every
§9 criterion maps to an executable check. The residual 2/10 risk is concentrated in
`test_backend_matrix.sh` subtest C (rupa/z seeding): rupa/z's `_Z_DATA` and `_z`'s silent-cd
semantics can be finicky to seed deterministically inside the resolver's subshell; if it proves
flaky, fall back to asserting the `z` branch via `backend=z` with a pre-seeded `_Z_DATA` temp
file, and cite `findings_and_risks.md` 🔴 CORRECTION A (the before/after-cwd fix is what makes
the `z` backend reliable). The executable-bit and §7-existing-tests portions are near-certain.
