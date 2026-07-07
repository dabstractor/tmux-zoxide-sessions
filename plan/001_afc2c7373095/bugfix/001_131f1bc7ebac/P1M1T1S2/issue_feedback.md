# Implementation Issue Feedback (Attempt 1/3)

The previous implementation attempt encountered an issue that requires re-planning.

## Issue Details

Fundamental conflict between PRP premise and execution environment. The S2 edit is correctly applied exactly as specified in the PRP (Levels 0, 1, 2 all pass; shellcheck clean; grep checks return expected 1/0/0/0/exact-line). However, Level 3 (full suite) goes 80/0 -> 78/2 because this environment has NO real zoxide installed: the only zoxide on PATH (/home/dustin/.local/bin/zoxide) is itself the rupa/z-backed shim, which does NOT parse '--' (verified via sh -x: it sets target='-- tmux' -> no match -> empty). The PRP's entire remediation rests on the premise that real/native zoxide is in use and labels the old code comment about the shim as 'factually false' -- but in this environment that comment describes true, verified behavior. SUBTEST A of test_backend_matrix.sh exercises the real on-PATH zoxide (the shim), so 'zoxide query -- tmux' returns empty (fail) vs 'zoxide query tmux' returning the path (baseline pass). Every possible fix crosses an ownership boundary the PRP forbids: modifying the test is S1/S3 scope (DO NOT TOUCH), modifying the shim is the user's environment (~/.local/bin/zoxide, outside the repo), and adding a workaround in _resolve_zoxide is an explicit anti-pattern. Resolution requires an orchestrator decision: (a) install real zoxide so the PRP premise holds, (b) patch the shim to strip '--', or (c) make SUBTEST A skip when on-PATH zoxide is detected as the shim. The S2 source edit stands correct as written; it cannot reach pass=80/fail=0 in this environment without one of those out-of-scope changes.

## Full Agent Output

The S2 edit is correctly applied exactly as the PRP specifies. The issue is not with my implementation — it's a fundamental conflict between the PRP's core premise and this execution environment.

Per the PRP's halt protocol ("If a fundamental issue with the plan is found, halt and produce a thorough explanation of the problem at a 10th grade level"), I'm halting.

---

## Halt: Fundamental Issue with the Plan

**Summary:** I applied the S2 edit exactly as the PRP specifies, and Levels 0, 1, and 2 all pass. But Level 3 (the full test suite) goes from 80/0 to **78/2**, because the PRP's core premise is **false in this environment**.

### What the PRP assumes

The entire remediation (this task S2, plus the architecture docs §F1, §F2, and `research_notes.md §2`) rests on one empirically-stated premise:

> "Real zoxide enters list mode for `-l`/`--list` without `--` ... `zoxide query "-l"` → 146+ lines."

And it labels as **"factually false"** the old code comment that said:

> "The `--` guard breaks the rupa/z-backed zoxide shim (which does not parse `--` and treats it as part of the query)."

The PRP calls that comment a lie and instructs me to delete it and replace it with a comment claiming `--` is the correct, harmless fix.

### What is actually true in this environment

There is **no real zoxide** installed on this machine. The only `zoxide` on PATH is `/home/dustin/.local/bin/zoxide`, which is itself the **rupa/z-backed shim**. I proved this three ways:

1. `which -a zoxide` → only the shim exists; no `/usr/bin/zoxide`, `/usr/local/bin/zoxide`, or `/opt/homebrew/bin/zoxide`.
2. `file` → it is a "POSIX shell script," not a compiled Rust binary.
3. `sh -x zoxide query -- tmux` → the shim sets `target='-- tmux'`, passes it to rupa/z's `_z`, gets no match, and returns empty.

So the comment the PRP called "factually false" is **describing real, verifiable behavior** in this environment. The shim genuinely does not parse `--`, and `--` genuinely breaks resolution of normal tokens.

### Why the test breaks

`tests/test_backend_matrix.sh` SUBTEST A probes whatever `zoxide` is actually on PATH (the real one, not a fake). With my S2 edit applied:

- `zoxide query tmux` (old form, baseline) → `/home/dustin/.config/tmux` ✅ (pass=12/12)
- `zoxide query -- tmux` (new S2 form) → empty ❌ (pass=10/12, fail=2)

The 2 failures are the WINDOW and SESSION assertions for the `tmux` token. This is exactly the "silent no-op against the plugin's primary support target" that the old (deleted) comment warned about.

### Why I cannot fix this within scope

The PRP's scope and anti-patterns forbid every available escape hatch:

- ❌ Modifying `tests/test_backend_matrix.sh` → owned by S1/S3, "DO NOT TOUCH."
- ❌ Modifying the rupa/z shim → it is the user's environment file (`~/.local/bin/zoxide`), not project code.
- ❌ Adding `|| true` / a fallback in `_resolve_zoxide` → explicitly an anti-pattern.
- ❌ Reverting the edit → that fails the PRP's own Success Criteria (the `--` must be present).

### The contradiction in one sentence

The PRP says: "real zoxide is the default backend's primary support target, and the rupa/z shim is a non-issue because real zoxide is what's in use" — but **this environment uses the shim as its zoxide**, so the fix that protects against real zoxide's list-mode bug actively breaks the shim that is actually running.

### What needs to happen (outside my scope)

This requires a human/orchestrator decision, since every resolution crosses an ownership boundary the PRP forbids me from touching. Options the orchestrator should consider:

1. **Install a real zoxide** in this environment (e.g., `cargo install zoxide` or the official install script), so the PRP's premise holds and SUBTEST A exercises a real binary. Then my S2 edit passes 80/0 as designed.
2. **Accept the shim's reality** and revisit the architecture: the rupa/z shim needs to learn to strip `--` (a one-line change in `~/.local/bin/zoxide`: `if [ "$1" = "--" ]; then shift; fi` before `target="$*"`). But that file is outside this repo.
3. **Adjust SUBTEST A** to skip when the on-PATH zoxide is detected as the shim (not native), since the shim can't model list-mode anyway. That's an S1/S3-scope test change.

The S2 edit itself is **correctly applied** per the PRP's literal instructions (Levels 1 and 2 fully pass), but Level 3 cannot reach 80/0 in this environment without one of the above out-of-scope changes.

```json
{
   "result": "issue",
   "message": "Fundamental conflict between PRP premise and execution environment. The S2 edit is correctly applied exactly as specified in the PRP (Levels 0, 1, 2 all pass; shellcheck clean; grep checks return expected 1/0/0/0/exact-line). However, Level 3 (full suite) goes 80/0 -> 78/2 because this environment has NO real zoxide installed: the only zoxide on PATH (/home/dustin/.local/bin/zoxide) is itself the rupa/z-backed shim, which does NOT parse '--' (verified via sh -x: it sets target='-- tmux' -> no match -> empty). The PRP's entire remediation rests on the premise that real/native zoxide is in use and labels the old code comment about the shim as 'factually false' -- but in this environment that comment describes true, verified behavior. SUBTEST A of test_backend_matrix.sh exercises the real on-PATH zoxide (the shim), so 'zoxide query -- tmux' returns empty (fail) vs 'zoxide query tmux' returning the path (baseline pass). Every possible fix crosses an ownership boundary the PRP forbids: modifying the test is S1/S3 scope (DO NOT TOUCH), modifying the shim is the user's environment (~/.local/bin/zoxide, outside the repo), and adding a workaround in _resolve_zoxide is an explicit anti-pattern. Resolution requires an orchestrator decision: (a) install real zoxide so the PRP premise holds, (b) patch the shim to strip '--', or (c) make SUBTEST A skip when on-PATH zoxide is detected as the shim. The S2 source edit stands correct as written; it cannot reach pass=80/fail=0 in this environment without one of those out-of-scope changes."
}
```

## Instructions

Review this feedback and create a revised PRP that addresses the issue.
If the issue is fundamentally impossible to resolve, output `"result": "fail"` with an explanation.
