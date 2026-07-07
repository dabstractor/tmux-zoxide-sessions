# Implementation Issue Feedback (Attempt 1/3)

The previous implementation attempt encountered an issue that requires re-planning.

## Issue Details

P1.M3.T2.S1 implementation is COMPLETE and CORRECT — all three deliverables (run-file PART 2 append, test_session_hook.sh new, test_run_file.sh C0 flip) pass every PRP gate: byte-identical to PRD §5.2 (diff empty), shellcheck -x rc=0, exec bit preserved, test_session_hook.sh pass=11/11, test_run_file.sh pass=9/9, test_z_window.sh 11/11, all four test_resolve_*.sh pass, and the Level-3b TPM smoke prints the exact item-contract-#4 show-hooks string with PART 1 preserved. ONE issue was surfaced that is OUTSIDE this subtask's scope: tests/test_z_session.sh (owned by the PARALLEL sibling P1.M3.T1.S1, explicitly FORBIDDEN for P1.M3.T2.S1 to modify) now fails C1a (pass=8 fail=1). Root cause: that test boots its isolated server WITHOUT -f /dev/null (line 71), so it sources the user's ~/.config/tmux/tmux.conf, which loads this plugin via TPM; now that PART 2 correctly wires the session-created hook, the real hook fires on the test's 'proj' session and relocates it before C1a reads the pre-relocate cwd. This is the exact trap PRP research/verification_notes.md §8 documents and fixes in test_session_hook.sh with -f /dev/null — the parallel sibling has the same latent clean-boot bug, which PART 2 correctly exposes. The fix (add -f /dev/null to test_z_session.sh boot()) belongs to P1.M3.T1.S1, not this subtask. My delta is exactly the three intended files; no forbidden file was modified.

## Full Agent Output

**Confirmed beyond doubt.** The diagnosis:

- `test_z_session.sh` line 71 boots its isolated server **without `-f /dev/null`** → the user's `~/.config/tmux/tmux.conf` is sourced → TPM loads the real plugin → PART 2 (now wired) registers the global `session-created` hook pointing at the real `scripts/z-session.sh`.
- C1a (line 93-95) creates `new-session -s proj -c "$FIX/home"`, then immediately checks the cwd is still `$FIX/home`. But the now-active real hook **fires on `proj`** (a resolvable name) and relocates it to `$FIX/proj` *before* the assertion → C1a fails.

This is the **exact** trap the PRP documents in verified_notes §8 and fixes in `test_session_hook.sh` with `-f /dev/null`. The parallel sibling `test_z_session.sh` has the same latent bug but predates PART 2, so it never manifested until this subtask correctly wired the hook. The PRP explicitly forbids me from modifying it (it's P1.M3.T1.S1's deliverable).

My implementation is complete and correct. Let me produce the final report.

---

## Summary

### Implementation — all three tasks complete

| Task | File | Change | Status |
|---|---|---|---|
| 1 | `tmux-zoxide-sessions.tmux` | APPEND PRD §5.2 PART 2 verbatim below PART 1 | ✅ byte-identical to PRD §5.2 (diff empty) |
| 2 | `tests/test_session_hook.sh` | NEW (verbatim from PRP) | ✅ `pass=11 fail=0`, exit 0 |
| 3 | `tests/test_run_file.sh` | FLIP C0 only (PART-1-only → PART-2-present) | ✅ `pass=9 fail=0`, exit 0 |

### Validation gates — all pass

- **Level 1 (Syntax/Style):** exec bit preserved; `shellcheck -x` rc=0; only SC1091 without `-x`; no anti-patterns (`set -e`/`eval`/`-ag`); exactly 1 `set-hook`; PART 1 bind-key intact; both tests shellcheck-clean.
- **Level 2 (Integration):** `test_session_hook.sh` 11/11; `test_run_file.sh` 9/9 (C0 flipped); `test_z_window.sh` 11/11; all four `test_resolve_*.sh` pass.
- **Level 3 (Smoke):** TPM-load on clean `-f /dev/null` server prints exactly `session-created[0] run-shell -b "<abs>/scripts/z-session.sh \"#{session_name}\""` (item contract #4); PART 1 binding preserved.
- **git delta:** exactly the three intended files (the `tasks.json`/`P1M3T2S1/` entries are orchestrator/research artifacts, not my edits).

### One issue surfaced — outside my scope (reported, not fixed)

`tests/test_z_session.sh` (owned by the **parallel** sibling P1.M3.T1.S1, explicitly FORBIDDEN for me to modify) now reports `pass=8 fail=1` (C1a). **Root cause:** that test boots its isolated tmux server **without `-f /dev/null`** (line 71), so it sources the user's `~/.config/tmux/tmux.conf`, which loads this very plugin via TPM. Now that PART 2 is correctly wired, the real `session-created` hook fires on the test's `proj` session and relocates it *before* C1a reads the pre-relocate cwd. This is the precise trap the PRP documents in `research/verification_notes.md §8` and fixes in `test_session_hook.sh` with `-f /dev/null` — the parallel sibling has the same latent clean-boot bug, which PART 2 (correctly) exposes. The PRP's 9/10 confidence note explicitly reserved this kind of parallel-coupling risk.

This is **not a defect in my deliverable** (the run file is byte-identical to PRD §5.2 and behaves exactly as specified) and the fix belongs to P1.M3.T1.S1 (apply `-f /dev/null` to `test_z_session.sh`'s `boot()`, mirroring `test_session_hook.sh`). Per the PRP's FORBIDDEN list and scope boundaries, I did not modify that file.

```json
{
   "result": "issue",
   "message": "P1.M3.T2.S1 implementation is COMPLETE and CORRECT — all three deliverables (run-file PART 2 append, test_session_hook.sh new, test_run_file.sh C0 flip) pass every PRP gate: byte-identical to PRD §5.2 (diff empty), shellcheck -x rc=0, exec bit preserved, test_session_hook.sh pass=11/11, test_run_file.sh pass=9/9, test_z_window.sh 11/11, all four test_resolve_*.sh pass, and the Level-3b TPM smoke prints the exact item-contract-#4 show-hooks string with PART 1 preserved. ONE issue was surfaced that is OUTSIDE this subtask's scope: tests/test_z_session.sh (owned by the PARALLEL sibling P1.M3.T1.S1, explicitly FORBIDDEN for P1.M3.T2.S1 to modify) now fails C1a (pass=8 fail=1). Root cause: that test boots its isolated server WITHOUT -f /dev/null (line 71), so it sources the user's ~/.config/tmux/tmux.conf, which loads this plugin via TPM; now that PART 2 correctly wires the session-created hook, the real hook fires on the test's 'proj' session and relocates it before C1a reads the pre-relocate cwd. This is the exact trap PRP research/verification_notes.md §8 documents and fixes in test_session_hook.sh with -f /dev/null — the parallel sibling has the same latent clean-boot bug, which PART 2 correctly exposes. The fix (add -f /dev/null to test_z_session.sh boot()) belongs to P1.M3.T1.S1, not this subtask. My delta is exactly the three intended files; no forbidden file was modified."
}
```

## Instructions

Review this feedback and create a revised PRP that addresses the issue.
If the issue is fundamentally impossible to resolve, output `"result": "fail"` with an explanation.
