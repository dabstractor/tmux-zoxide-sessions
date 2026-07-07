# Verification Findings — P1.M4.T2.S1

Raw material gathered while authoring the PRP. Not user-facing; consumed by the
implementing agent for the acceptance report.

## 1. Committed executable-bit state (measured at PRP time)

`git ls-files -s` on the committed tree:

| File | Committed mode | Worktree `stat -c %a` | Required | Status |
| --- | --- | --- | --- | --- |
| `tmux-zoxide-sessions.tmux` | `100755` | `755` | executable (TPM runs it) | ✅ already correct |
| `scripts/z-window.sh`      | `100755` | `755` | executable (run-shell dispatch) | ✅ already correct |
| `scripts/z-session.sh`     | `100755` | `755` | executable (run-shell dispatch) | ✅ already correct |
| `scripts/lib/resolve.sh`   | `100644` | `644` | NOT executable (it is `. ` sourced) | ✅ already correct |

**Implication:** the "chmod +x and commit bits" deliverable is, at PRP time, a
**verify-and-confirm**. The implementing agent must still RUN the `git ls-files -s`
check (it is the §9 gate "scripts and run file are executable" + the external_deps §2
linchpin "the bit must be COMMITTED or it is lost on clone and TPM silently no-ops").
If any of the three executables shows `100644`, fix with
`git update-index --chmod=+x <file>` (then commit). Leave `resolve.sh` at `100644`.

> Trap to avoid: `git status` shows ` M tmux-zoxide-sessions.tmux` (the P1.M3.T2.S1
> append is uncommitted in the worktree). A plain `git add tmux-zoxide-sessions.tmux`
> PRESERVES the existing `100755` index mode — do not let any tool strip the bit. Re-run
> `git ls-files -s` after staging to confirm `100755` survived.

## 2. PRD §7 matrix ↔ existing automated coverage map

The MVP ships 8 integration tests in `tests/`. Their stated TDD scope already exercises
7 of the 10 §7 cases against the REAL scripts on an isolated tmux server:

| §7 # | Case | Automated by | How asserted |
| --- | --- | --- | --- |
| 1 | relocate fires (resolvable) | `tests/test_z_session.sh` | pane cwd post-respawn == shim-resolved dir |
| 2 | skip-list (`main`) | `tests/test_z_session.sh` | stays at fixture "home" |
| 3 | no zoxide match | `tests/test_z_session.sh` | stays at fixture "home" |
| 4 | not-`$HOME` skip | `tests/test_z_session.sh` | created at `$FIX/else`, no respawn |
| 5 | sessionx coexistence | **MANUAL** (not unit-testable; external plugin) | design argument + optional live probe |
| 6 | master toggle `off` | `tests/test_z_session.sh` + `tests/test_session_hook.sh` C3 | handler exits early; hook not registered |
| 7 | `window-name session` | `tests/test_z_session.sh` | first window renamed to `<name>` |
| 8 | window jump `prefix g` | `tests/test_run_file.sh` C6–C8 | `new-window` opens in resolved dir, named basename |
| 9 | spaced session name | `tests/test_z_session.sh` + `tests/test_session_hook.sh` C7 | `$1` arrives intact as one arg |
| 10 | resurrect restore safety | **MANUAL** (external plugin) | resurrect uses `-c "$saved_dir"` (external_deps §3) |

**Implication:** P1.M4.T2.S1 must (a) RUN all existing tests and record pass/fail, and
(b) add ONE new automated test — the **backend matrix** — because §9 requires
"Both features work with real `zoxide`, a `zoxide` shim, and rupa/z (`z` backend)" and
NO existing test exercises the real `zoxide` binary or the real rupa/z `z.sh`.

## 3. Backend matrix — what exists on this machine (for the new test)

- Real `zoxide`: `/home/dustin/.local/bin/zoxide` (`zoxide --version` ok). Index resolves
  `sellario` → `/home/dustin/projects/sellario-ui-forms-rebase-vite-typescript` and
  `tmux` → `/home/dustin/.config/tmux`. **Use `tmux` as the deterministic real-zoxide
  fixture** (short, stable, resolves to a dir the agent can also seed into a rupa/z
  `z.sh` index).
- Real rupa/z `z.sh`: `/home/dustin/.config/znap/rupa/z/z.sh` (readable; item contract #5
  names this exact path). Set `@zoxide-sessions-z-sh` to it and `@zoxide-sessions-backend z`
  (or `auto` with the `zoxide` binary removed from PATH) to drive the `z` branch.
- zoxide shim: a fake `zoxide` on a throwaway `PATH` (existing tests' pattern) returning a
  canned real dir for a known query, empty for others.

The new `tests/test_backend_matrix.sh` should, for each of the three backends, run BOTH
the window feature (assert a `new-window` lands in the resolved dir) and the session
feature (assert a `respawn-pane` relocates the pane), on an isolated server, so the single
§9 "all three backends work" criterion is mechanically proven — not asserted by hand.

## 4. Isolated-tmux conventions to reuse (proven by M2/M3 tests)

- `REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"` (never call bare `tmux` — it may hit the shim).
- Distinct socket per test to stay parallel-safe: existing sockets are `zxstest_run`,
  `zxstest_hook`, `zxstest_session`. The backend-matrix test should use `zxstest_backend`.
- `cleanboot` with `tmux -f /dev/null -L <sock> ...` so the USER's `tmux.conf` is NOT
  sourced (a stray `session-created` hook would pollute assertions).
- Fake `tmux` wrapper on a throwaway `PATH` forwarding every bare `tmux` to the isolated
  server; set that `PATH` BEFORE booting so `run-shell` inherits it.
- Real fixture dirs must `mkdir -p` (an active pane whose `-c` dir does not exist falls
  back to `$HOME`).
- Reading cwd: prefer `display-message -t "<session>" -p '#{pane_current_path}'`
  (session → active pane; no base-index dependency). The PRD §7 literal `<session>:1.0`
  assumes `base-index=1`; the isolated server defaults to `0`, so target the session, not
  a hardcoded `:1.0`.
- `respawn-pane` needs a ≥0.4s settle before `pane_current_path` reflects the new dir.
- Key-binding presence: `list-keys -1 -T prefix g` (the `-1` is mandatory).
- Hook presence: `show-hooks -g session-created | grep 'run-shell -b'` — NOT a bare count
  of the `session-created` token, which always lists even when unset.

## 5. Manual cases — recorded reasoning (for the acceptance report)

- **Case 5 (sessionx coexistence):** sessionx/sesh create sessions via
  `tmux new-session -d -s <name> -c <resolved>` (external_deps §4), so the first pane's
  `pane_current_path` is the resolved dir, NOT `$HOME`. z-session.sh's `path == $HOME`
  guard exits before any respawn. The design keys off OBSERVED cwd, not tool identity, so
  even a non-zoxide sessionx placement is skipped. Optional live confirmation: create a
  session with `-c /tmp/x` on the isolated server and assert the handler no-ops.
- **Case 10 (resurrect/continuum restore):** `tmux-resurrect`'s `restore.sh` calls
  `new-session -d -s <name> -c "$saved_dir"` (external_deps §3, primary-source quote),
  and continuum delegates to resurrect's restore. Restored sessions therefore land at
  their saved cwd; only a session whose saved cwd *was* `$HOME` would relocate (a
  documented, arguably-desirable false positive). Optional live confirmation: seed a
  resurrect save file, run restore on the isolated server, assert no relocate.

## 6. README dependency (parallel task P1.M4.T1.S1)

§9's last bullet ("README documents every option and the `$HOME`-guard model") is OWNED by
P1.M4.T1.S1, which is running in parallel. At PRP time `README.md` does not exist yet.
The acceptance report must mark that bullet **DEFERRED-to-parallel** if README.md is
absent at run time, and only run the content gate (grep for all 8 options + the
`$HOME`-guard sentence) if README.md is present. It must NOT be recorded as a failure of
P1.M4.T2.S1.
