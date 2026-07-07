# Implementation Issue Feedback (Attempt 1/3)

The previous implementation attempt encountered an issue that requires re-planning.

## Issue Details

HALTED at Level 0a (prerequisite gate): the resolver `--` guard required by this PRP is ABSENT. scripts/lib/resolve.sh:19 reads `zoxide query \

## Full Agent Output

This confirms the situation completely and actually changes the picture. The resolver comments (lines 12-17) document a deliberate, reasoned decision **not** to add the `--` guard — and the rationale directly contradicts a core premise of this PRP:

> "zoxide already rejects a query that begins with `-` safely (empty output + exit 0)... so the guard buys nothing while breaking the shim."

The PRP's Level-4 proof and `dependency_probe.md` claim a **hardened fake** proves the unguarded resolver returns a 3-line dump for `-l`. But the resolver is unguarded right now, and the baseline shows the existing tests pass. The discrepancy means either (a) P1.M1.T1.S2 was rejected/reversed and the resolver was intentionally left unguarded, or (b) the hardened fakes aren't actually in place as the PRP assumes. Either way, this is a **fundamental conflict between the PRP's hard prerequisite and the actual state of the codebase** — not something I can resolve by appending test assertions.

Per the PRP's own Failure Protocol and the Hard Prerequisite rule, I must halt.

```json
{
   "result": "issue",
   "message": "HALTED at Level 0a (prerequisite gate): the resolver `--` guard required by this PRP is ABSENT. scripts/lib/resolve.sh:19 reads `zoxide query \"$1\"` (no `--`), and lines 12-17 document a DELIBERATE decision NOT to add the guard, arguing it 'buys nothing while breaking the [rupa/z] shim' and that 'zoxide already rejects a query that begins with `-` safely.' This directly conflicts with the PRP's core premise (that an unguarded resolver returns a 3-line dump for `-l`, per dependency_probe.md §2).\n\nThe PRP defines this guard as a HARD PREREQUISITE owned by task P1.M1.T1.S2, and explicitly FORBIDS me from (a) editing resolve.sh, and (b) weakening the empty-resolution assertions to pass without the guard. The PRP states these assertions 'fail BY DESIGN' against an unguarded resolver and that the correct action is to 'coordinate with the P1.M1.T1.S2 owner' — not to proceed.\n\nBaseline (Level 0b) is clean: test_resolve_zoxide.sh = pass=3 fail=0, test_resolve_dispatcher.sh = pass=14 fail=0. So the starting point is healthy; only the prerequisite is missing.\n\nIn plain terms: this task's job is to add 7 test assertions that prove a fix (the `--` guard) is working. But that fix isn't installed in the code — in fact the code has comments explaining why that fix was intentionally NOT installed. I can't add tests that assert behavior the code doesn't have, I'm not allowed to add that behavior myself (different task owns it), and I'm not allowed to dumb the tests down to pass anyway. The right next step is for a human/orchestrator to reconcile P1.M1.T1.S2's status: either land the `--` guard (then re-run this PRP) or, if the guard was intentionally rejected, update this PRP's expected values and rationale before execution."
}
```

## Instructions

Review this feedback and create a revised PRP that addresses the issue.
If the issue is fundamentally impossible to resolve, output `"result": "fail"` with an explanation.
