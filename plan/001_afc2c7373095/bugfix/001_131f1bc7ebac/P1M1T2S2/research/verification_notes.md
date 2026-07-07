# Verification Notes — P1.M1.T2.S2 (symmetric defence-in-depth guard in `z-session.sh`)

Empirically verified on this machine: `tmux 3.6b`, `shellcheck` installed,
real `zoxide` on PATH, repo at the plugin root. The guard was applied to a
**temp copy** (real source untouched) and exercised with the full integration
harness. These ground the PRP's validation gates.

## 1. The mandated guard form passes `shellcheck` with ZERO new findings

Exact guard (insert between `[ -n "$resolved" ] || exit 0` and the relocate line):
```sh
# Defence in depth: accept `resolved` ONLY if it is a single existing
# directory; otherwise no-op (pane stays where it is).
case "$resolved" in
    *"$NL"*) exit 0 ;;                 # multi-line dump -> refuse to relocate
    *)       [ -d "$resolved" ] || exit 0 ;;
esac
```
with `NL='` + a real newline + `'` defined once after the `. resolve.sh` line.

`shellcheck` on the guarded file emits ONLY the **pre-existing** SC1091 (info)
on the `. "$SCRIPT_DIR/lib/resolve.sh"` line — **identical** to the unmodified
original. The edits add **zero** new findings (no SC2086, no SC2230, nothing).
This matches the S1 (z-window.sh) finding. The newline-`case` idiom and the
`-d` test are both POSIX-clean; no `$'\n'`, no `[[ ]]`, no `=~`.

> SC1091 cannot be silenced by passing resolve.sh as a second input NOR by `-x`
> here, because the source path is dynamic (`$SCRIPT_DIR/lib/resolve.sh`).
> `shellcheck -x` changes the message to "openBinaryFile: does not exist" but
> still emits SC1091. The correct validation stance: SC1091 is a pre-existing
> INFO finding present in the original; the gate is "no NEW findings vs baseline"
> (verified by diffing shellcheck output original-vs-guarded — identical).

## 2. The critical adaptation vs S1 (z-window.sh): failure action is `exit 0`

This is the single most important difference between the two caller guards:

| Caller | Failure action | Mechanism |
|---|---|---|
| z-window.sh (S1) | keep `dir=$cur` (continue to `new-window`) | `*) [ -d "$resolved" ] && dir="$resolved" ;;` |
| z-session.sh (S2) | **`exit 0`** (skip `respawn-pane` entirely) | `*) [ -d "$resolved" ] || exit 0 ;;` + `*"$NL"*) exit 0 ;;` |

Why the difference: z-window.sh's job is to ALWAYS open a window — if the
resolved dir is bad, fall back to the current pane path and still open. z-session.sh's
job is to RELOCATE an already-existing pane — if it can't relocate safely, the
correct action is to **do nothing** (`exit 0`), leaving the pane where it landed
($HOME or wherever). There is no "default dir" to fall back to, because respawn
is conditional. The handler already `exit 0`s on every other guard failure
(skip-list, no-match, not-$HOME, master-off); this guard is consistent with that
"nothing to do" contract.

## 3. The full integration harness passes 9/0 against the guarded handler

Applied the exact guard to a temp copy of `scripts/z-session.sh`, repointed the
temp `tests/test_z_session.sh` at the temp scripts dir, ran the full harness:
`RESULTS: pass=9 fail=0` — **all 7 cases (9 assertions) still pass**. No regression.

Why normal matches still relocate: the fake resolves `proj` → `$FIX/proj`, which
is a **real, single-line** directory. The newline `case` arm does not match
(single line); the `-d` arm is true → falls through to `respawn-pane`. The
spaced-name case (`"two words"` → `$FIX/twowords`) likewise passes both checks.

## 4. The guard logic itself: 4/4 (deterministic, no tmux)

Standalone proof of the `case`/`-d` decision (returns relocate vs no-op):

| `resolved` value | newline? | `-d`? | result |
|---|---|---|---|
| `$FIX/proj` (real dir) | no | yes | **relocate** |
| `` (empty / no-match) | no | no (empty fails `-d`) | no-op |
| `$FIX/does-not-exist` | no | no | no-op |
| 3-line DB dump (`-l`) | **yes** | — | no-op |

The dump case is the key: its first line (`$FIX/proj`) IS a real directory, yet
the newline arm rejects the whole multi-line value before `-d` is ever consulted.
This is exactly the Issue-1 symptom (`-l`/`--list` dumping the frecency DB), and
it is the reason the newline check must come FIRST (a `-d`-only guard would test
only the first line and wrongly accept a truncated/first-entry path).

## 5. The emptiness check is already present (guard is layered correctly)

The existing line `[ -n "$resolved" ] || exit 0` runs BEFORE the new guard. So the
empty/no-match case exits there and never reaches the `case`. The new guard's `-d`
arm would also catch empty (`[ -d "" ]` is false) — that redundancy is harmless
and documents defense-in-depth. Do NOT remove the pre-existing `[ -n "$resolved" ]`
line; the item contract says INSERT the guard BETWEEN it and `respawn-pane`.

## 6. The test fixture is ALREADY hardened — do not touch it

`tests/test_z_session.sh`'s fake `zoxide` (P1.M1.T1.S1 = Complete) already:
- strips a leading `--` (real zoxide honours end-of-options), AND
- models list-mode for `-l`/`--list` (prints `$FIX/proj`, `$FIX/other1`,
  `$FIX/other2` — a 3-line dump where only line 1 is a real dir).

So a `-l` session-name would already produce the multi-line dump this guard
catches. BUT the committed test does NOT currently query `-l` as a session name
in any of its 7 cases — that committed regression assertion is owned by
**P1.M1.T3.S2** (integration leading-dash regression). This task must NOT add a
committed `-l` case; provide only a throwaway Level-4 proof.

## 7. Insert points (exact, verified live)

`scripts/z-session.sh` structure (line numbers as read):
- Line 11: `. "$SCRIPT_DIR/lib/resolve.sh"` — **NL literal goes right after this**
  (blank line, comment, `NL='<newline>'`, blank line), before `# Master toggle.`.
- The resolve/relocate sequence (with blank lines between):
  ```
  resolved=$(resolve "$name") || exit 0
  [ -n "$resolved" ] || exit 0
                                          <-- GUARD INSERTED HERE
  # Relocate: restart the pane's shell in the resolved directory.
  tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
  ```
  Anchor on `[ -n "$resolved" ] || exit 0` followed by the `# Relocate:` comment.

## 8. Scope boundary (anti-regression)

This subtask edits ONLY `scripts/z-session.sh` (NL literal + guard). Do NOT:
- modify `scripts/z-window.sh` (S1, parallel), `scripts/lib/resolve.sh`
  (P1.M1.T1.S2, resolver `--` guard), the run file (P1.M2, Issue 2), README
  (P1.M3.T1), or any test file (P1.M1.T1.S1 done; P1.M1.T3 owns regressions),
- add a committed `-l` regression assertion,
- chmod anything, or touch `.gitignore` / `PRD.md` / `tasks.json`.
