# Verification notes — P1.M3.T2.S1 (append session-created hook to run file)

All findings below were confirmed **empirically** on this machine (tmux 3.6b, shellcheck 0.11.0)
against an **isolated** tmux server (`tmux -L zxs_research_hook*`). The user's live tmux was never
touched. The repo was never modified during research (all run-file testing used `/tmp` staging copies).

## §0 — RESULT (summary)

Every gate in the PRP is grounded in a measurement:

| Claim | Measurement | Status |
|---|---|---|
| Exact PRD quoting stores the hook correctly (item contract #4) | `show-hooks -g session-created` → `session-created[0] run-shell -b "<abs>/z-session.sh \"#{session_name}\""` (§2) | ✅ |
| Hook FIRES on session creation, `$1` = session name | probe log `FIRED arg1=[sellario]` after `new-session -s sellario` (§3) | ✅ |
| Spaced session name arrives as ONE `$1` (PRD §7 test 9) | probe log `FIRED arg1=[two words]` after `new-session -s "two words"` (§3) | ✅ |
| `set-hook -g` OVERWRITES → reload-idempotent (NOTE C) | `show-hooks` run-shell count stays **1** after 2× `set-hook -g` (§4) | ✅ |
| if-gate: auto-session=off → hook NOT set | `show-hooks -g session-created` contains NO `run-shell` when gate skips (§5) | ✅ |
| PART 1 binding preserved after append (no regression) | `list-keys -1 -T prefix g` unchanged after running the appended run file (§7) | ✅ |
| Append of verbatim PART 2 ⇒ run file is byte-identical to PRD §5.2 | `diff` of staged PART1+PART2 against PRD §5.2 = empty (§6) | ✅ |

## §1 — The exact `set-hook` quoting (item contract #4 — the CRUX)

The PRD §5.2 PART 2 line:
```bash
tmux set-hook -g session-created \
    "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'"
```
Stored hook (verbatim from `show-hooks -g session-created`):
```
session-created[0] run-shell -b "/tmp/tmp.eM4uDXP2i0/z-session.sh \"#{session_name}\""
```
This matches item contract #4 EXACTLY. The nested quoting mechanics:
- **Outer double quotes** around `"run-shell -b '...'"` → bash expands `${SESSION_SCRIPT}` at run time,
  baking the **absolute** script path into the stored command. The `\"` inside become literal `"`.
- **Inner single quotes** (`'${SESSION_SCRIPT} ...'`) → literal characters tmux stores; they wrap the
  whole `run-shell -b` argument so tmux sees ONE shell-argument: `"<abs>/z-session.sh \"#{session_name}\""`.
- **`\"#{session_name}\"`** → tmux stores literal `"` around the `#{...}` format. At hook-dispatch time,
  tmux expands `#{session_name}` and the surrounding `\"` deliver the (possibly spaced) name as a
  **single quoted `$1`** to z-session.sh. (This is the same idiom tmux-session-history uses — see the
  PRD §5.2 inline comment; confirmed working in §3.)

**Do not alter this quoting.** It is the only form that (a) bakes the absolute path, (b) keeps the
`run-shell -b` arg as one token, and (c) passes a spaced name as one `$1`.

## §2 — The reliable `show-hooks` assertion (NOT a name-count)

`tmux show-hooks -g` **always lists the `session-created` hook NAME**, even when no command is set:
- **Unset** (clean server, no `set-hook`): `show-hooks -g session-created` → `session-created` (bare
  name, no command). A bare `grep -c session-created` returns **1** even though nothing is wired.
- **Set**: `show-hooks -g session-created` → `session-created[0] run-shell -b "<abs>/z-session.sh \"#{session_name}\""`.

⇒ **The "absent" assertion must check for `run-shell` (and the script path) ABSENCE, not grep-count the
hook name.** The on/off assertion is:
- **on**: output contains `run-shell -b` AND the abs `<repo>/scripts/z-session.sh` path AND `#{session_name}`.
- **off**: output does NOT contain `run-shell` (the if-gate skipped set-hook).

## §3 — Hook fires end-to-end; spaced `$1` integrity (PRD §7 test 9)

Probe handler (`echo "FIRED arg1=[$1]" >> $LOG; exit 0`) installed as `z-session.sh`, hook set with the
exact PRD quoting, then sessions created:
- `new-session -d -s sellario` → log `FIRED arg1=[sellario]` (after a 0.5s settle for the `-b` async).
- `new-session -d -s "two words"` → log `FIRED arg1=[two words]` — **the spaced name arrived as ONE `$1`**.

`run-shell -b` is non-blocking; a ≥0.4s sleep after `new-session` is the validated floor for the probe
to flush. (Confirmed previously: findings ✅2.)

## §4 — `set-hook -g` OVERWRITES (reload-idempotent — NOTE C)

After `set-hook -g session-created "X"` then `set-hook -g session-created "Y"`:
`show-hooks -g | grep -c session-created` (command lines) = **1** (only Y). Re-running the run file
(PART 2) on a TPM reload therefore **overwrites** — no duplicate hooks accumulate across `prefix r` /
TPM re-source. This is the empirically-validated basis for keeping `-g` (NOT switching to `-ag`, which
would append a duplicate on every reload). Documented as NOTE C (DOCS only — handled in README by
P1.M4.T1/T3, NOT by changing the mechanism).

## §5 — The if-gate: auto-session=off ⇒ hook NOT set

Running the verbatim PART 2 block with `@zoxide-sessions-auto-session=off`:
`auto_session` reads back `off` → the `[ "$auto_session" != "off" ]` test is false → `set-hook` is
**skipped** → `show-hooks -g session-created` contains NO `run-shell`. With the option **unset**, the
default `"on"` applies → gate passes → hook set. (get_tmux_option returns the default for an unset
@-option — S1 contract.) Both branches verified.

## §6 — Append of verbatim PART 2 ⇒ byte-identical to PRD §5.2

Copied the real repo run file (PART 1) to a staging dir, appended the PRD §5.2 PART 2 block verbatim,
and `diff`'d against PRD §5.2's complete code fence → **empty**. Executing that staged run file (PART 1
+ PART 2) on a clean server produced the correct hook (§1) AND left the PART 1 binding intact (§7).
⇒ The implementation is a pure **append** (preserve PART 1 above); no rewrite.

## §7 — PART 1 binding preserved (regression)

After executing the appended run file, `tmux list-keys -1 -T prefix g` still returns:
`bind-key -T prefix g command-prompt -p "z to:" "run-shell '<abs>/scripts/z-window.sh %%'"`.
The append adds code BELOW PART 1; it does not touch the bind-key. `test_run_file.sh`'s C1–C8
(binding) assertions therefore still hold.

## §8 — Clean server requires `-f /dev/null` (the user-tmux.conf gotcha)

`tmux -L <sock> new-session` **sources the user's `~/.config/tmux/tmux.conf` by default**. On this
machine the isolated server inherited a `session-created` hook from the `tmux-session-history` plugin
(`run-shell ".../session_history.sh maintain"`), polluting the "absent" assertion (it showed count=1
even when MY gate skipped). 

**Fix:** boot the isolated server with `-f /dev/null` so NO user config is sourced:
`"$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s zs -c "$FIX"`. (`-f` must precede `-L`.)
Then `show-hooks -g session-created` is clean (bare name, no command) until MY run file sets it.

This is a DIFFERENT concern from `test_run_file.sh` (P1.M2.T2.S1), which tested bindings (`list-keys`)
and so was unaffected by session-created-hook noise. **Only the session-hook test needs `-f /dev/null`.**

## §9 — `test_run_file.sh` C0 must FLIP (PART 2 is now legitimately present)

`test_run_file.sh` (P1.M2.T2.S1) ships a C0 guard that FAILS if the run file contains
`set-hook|z-session\.sh|@zoxide-sessions-auto-session`:
```sh
if grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' "$RUN"; then
    echo "FAIL  C0: ... (must be PART 1 only)"; fail=$((fail+1))
```
That guard existed BECAUSE PART 2 was deferred to this subtask (P1.M3.T2.S1). Once PART 2 is appended,
the run file legitimately contains those tokens → C0 FAILS → `test_run_file.sh` reports fail=1.

**Resolution (scoped, minimal modification of a prior test — justified by the append):** flip C0 to
assert PART 2 IS present (the inverse), so `test_run_file.sh` remains a valid regression test for the
now-complete two-feature run file. C1–C8 (binding) are unchanged and still pass (PART 1 untouched;
running `"$RUN"` now also executes PART 2's `set-hook`, which is harmless to `list-keys`). The pass
count stays 9.

## §10 — Test strategy: real run file for registration; staging+probe for firing (parallel-safe)

P1.M3.T1.S1 (z-session.sh handler) runs **in parallel** with this subtask, so the real
`scripts/z-session.sh` may be absent when this test runs. Two decoupled strategies:

- **Registration / regression (C1–C5):** run the **REAL repo run file** on a clean isolated server.
  `set-hook` merely **stores the command string**; it does NOT require `z-session.sh` to exist at
  registration time (run-shell checks the file only at dispatch). So `show-hooks` assertions (on/off)
  + `list-keys` (binding) + the reload-idempotency check all work **without** z-session.sh present.
- **Firing / `$1` integrity (C6–C7):** use a **staging copy** of the run file (real PART 1 + PART 2
  content + real `resolve.sh`) with a **probe** `z-session.sh` (logs `$1`) dropped at
  `staging/scripts/z-session.sh`. The run file's `SESSION_SCRIPT="$CURRENT_DIR/scripts/z-session.sh"`
  then points at the probe. Create sessions, check the probe log. This tests the real wiring + dispatch
  + `$1` integrity, **decoupled from P1.M3.T1.S1**'s deliverable (mirrors how `test_run_file.sh`
  CASE 3 used a stand-in handler).

Socket: `zxstest_hook` (distinct from `zxstest_run` / `zxstest_session` so parallel runs don't collide).

## §11 — shellcheck posture

The appended PART 2 block is plain bash appended to an existing bash file. `shellcheck -x` on the
complete run file remains rc 0 (the only dynamic source is `$CURRENT_DIR/scripts/lib/resolve.sh`, which
`-x` follows; identical profile to the PART 1 run file, already verified by P1.M2.T2.S1). The added
lines introduce no new dynamic sources. No new SC codes.

## §12 — Non-modify invariants

The append touches ONLY `tmux-zoxide-sessions.tmux` (append bytes below PART 1) and, as a justified
minimal edit, `tests/test_run_file.sh`'s C0 guard + its comment (§9). NOT modified: `resolve.sh`,
`z-window.sh`, `z-session.sh` (P1.M3.T1.S1 owns it), `PRD.md`, `.gitignore`, the S1–S4 tests,
`test_z_window.sh`, `test_z_session.sh`. No new tmux options introduced (PART 2 reads the EXISTING
`@zoxide-sessions-auto-session` from PRD §4).

## §13 — REPO-STATE FINDING (the work may already be applied — make tasks IDEMPOTENT)

At research time the repo was ALREADY in the complete post-implementation state (all changes
UNCOMMITTED; the last commit `6f29638` was P1.M3.T1.S1's handler):

- `tmux-zoxide-sessions.tmux` — **already byte-identical to PRD §5.2** (PART 1 + PART 2 present; 31
  lines; `diff` against the §5.2 code fence is empty). `shellcheck -x` rc 0.
- `tests/test_run_file.sh` — C0 **already flipped** to "PART 2 present"; C1–C8 pass; `RESULTS: pass=9 fail=0`.
- `tests/test_session_hook.sh` — **already exists**, byte-identical to this PRP's verbatim test, and
  passes `RESULTS: pass=11 fail=0` on a clean (no-concurrent-servers) run.
- `scripts/z-session.sh` — already shipped by P1.M3.T1.S1 (`-rwxr-xr-x`, PRD §5.5 verbatim).

⇒ A prior pass already implemented P1.M3.T2.S1. The PRP therefore frames every task as
**IDEMPOTENT (verify-then-act)**, keyed on the authoritative end-state gate
(`diff <PRD §5.2 fence> tmux-zoxide-sessions.tmux` empty + tests pass):

- **Task 1 (run file):** if PART 2 is ABSENT (expected P1.M2.T2.S1 input = PART 1 only), APPEND it;
  if PART 2 is ALREADY present, VERIFY byte-identity and do NOT re-append (a blind append would
  DUPLICATE the block — though functionally harmless because `set-hook -g` overwrites, it would
  break the byte-identity `diff` gate and is not the spec).
- **Task 2 (test):** write the verbatim test (overwrites any prior version; it is byte-identical anyway).
- **Task 3 (C0 flip):** if C0 is the PART-1-only guard, FLIP it; if already flipped, VERIFY.

This makes the PRP correct whether the implementing agent starts from a clean PART-1-only checkout
or from the already-complete state.

## §14 — Test determinism (avoid concurrent tmux servers on the test socket)

`test_session_hook.sh` passed 11/11 on every clean (isolated) run. ONE transient failure (pass=2
fail=9) was observed immediately after a burst of concurrent diagnostic tmux servers (different
sockets, but heavy load) left the system contended; a fresh `kill-server` + re-run restored 11/11.
The cleanboot already does `kill-server` + `sleep 0.2` before `new-session`, which handles stale
servers in normal sequential execution. To rule out flakiness, run the test in isolation (no other
`tmux -L zxstest_*` servers active). The failures were all explained (C2/C4 = hook not registered →
run file didn't land set-hook under contention; C6/C7 = probe log empty → same root cause) and did
NOT recur on isolated runs.

## §15 — THE ISSUE (re-plan): `test_z_session.sh` fails C1a — ROOT CAUSE + VERIFIED FIX

### Symptom
After P1.M3.T2.S1 correctly wires PART 2, the PARALLEL sibling test `tests/test_z_session.sh`
(P1.M3.T1.S1's deliverable) reports `pass=8 fail=1`: **C1a** ("pre-relocate cwd = home") fails
because the pane is already at `$FIX/proj` by the time the assertion runs.

### Root cause (the FULL chain — empirically confirmed)
1. The user's `~/.config/tmux/tmux.conf` (line 102) lists `@plugin 'dabstractor/tmux-zoxide-sessions'`
   and runs TPM (line 137). It also loads `tmux-plugins/tmux-sensible` (line 92), which sets
   **`set -g exit-empty off`**.
2. `test_z_session.sh`'s `boot()` does NOT use `-f /dev/null`, so `new-session -s _seed` **sources
   the user's tmux.conf** → TPM loads THIS plugin → the run file (now with PART 2) sets the global
   `session-created` hook → when a case does `new-session -s proj`, the **real hook fires** and the
   real `z-session.sh` relocates `proj` to `$FIX/proj` *before* C1a reads the cwd → C1a fails.
3. `boot()` also does `kill-session -t _seed`. Because the plugin (via tmux-sensible) set
   `exit-empty off`, the server **stays alive** after `_seed` dies, so boot's `set -g` options
   (home-dir, backend) **persist** — which is why all OTHER cases pass (the handler + options work);
   only the pre-relocate C1a check is beaten by the hook.

### Why the naive `-f /dev/null`-only fix is WRONG
Adding `-f /dev/null` to boot's `new-session` ALONE makes `exit-empty` revert to its default **ON**
(no tmux.conf → no tmux-sensible). Then `kill-session -t _seed` (the only session) **EXITS the
server**. Boot's `set -g` options are LOST. Every case's `new-session` (which has NO `-f /dev/null`)
then RESTARTS the server, sourcing tmux.conf again (plugin reloads). Net: a half-isolated mess
where `home-dir` is `$HOME` (not `$FIX/home`) → the handler's `path==home` guard fails → no
relocation → C1b/C7/C9 fail (`pass=5 fail=4`). Measured directly: `kill-session` on the sole
session of a `-f /dev/null` server → `list-sessions` = "no server running"; the next `new-session`
restarts it WITH the plugin's hook + binding present.

### The VERIFIED fix (2 lines in `boot()` — measured 9/9 pass, exit 0)
```sh
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    # seed then clear so option defaults are clean per-case
    "$REAL_TMUX" -f /dev/null -L "$SOCK" new-session -d -s _seed -c "$FIX" 2>/dev/null || true   # (1) -f /dev/null
    sleep 0.1
    "$REAL_TMUX" -L "$SOCK" set -g exit-empty off 2>/dev/null                                          # (2) exit-empty off
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
    ...
    "$REAL_TMUX" -L "$SOCK" kill-session -t _seed 2>/dev/null || true
}
```
- **(1) `-f /dev/null`** isolates the server from the user's tmux.conf → the plugin does NOT load →
  no real hook fires → test sessions are created clean (C1a passes: proj stays at home).
- **(2) `set -g exit-empty off`** (set BEFORE `kill-session -t _seed`) keeps the server alive after
  `_seed` dies → boot's `set -g` options PERSIST on the clean server → the handler's guards work →
  C1b/C7/C9 pass.
Measured end-to-end: `pass=9 fail=0`, exit 0. After revert: back to `pass=8 fail=1`.

### Scope decision (why P1.M3.T2.S1 applies this fix)
The failing file is nominally P1.M3.T1.S1's, but: (a) the orchestrator assigned this issue to
P1.M3.T2.S1; (b) P1.M3.T2.S1's CORRECT PART 2 wiring is what exposes the sibling's latent isolation
flaw (it was always coupled to tmux-sensible's `exit-empty off` via the user's tmux.conf); (c)
P1.M3.T1.S1 is COMPLETE (committed `6f29638`); (d) the fix is a 2-line test-isolation hardening
that mirrors what `test_session_hook.sh` already does, NOT a handler change. The revised PRP
therefore adds a scoped Task 4 that applies exactly this verified fix to `test_z_session.sh`'s
`boot()` (and only `boot()`).
