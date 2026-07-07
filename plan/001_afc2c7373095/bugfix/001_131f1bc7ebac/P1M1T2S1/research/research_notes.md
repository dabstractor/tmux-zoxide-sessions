# Research Notes — P1.M1.T2.S1: newline-reject + directory-exists guard in `z-window.sh`

Defence-in-depth hardening for Issue 1 (zoxide `-l`/`--list` flag absorption). All facts
below verified live on this machine (tmux 3.x, `shellcheck` installed, `/bin/sh`→bash).

## 1. Exact current target file — `scripts/z-window.sh` (verified live)

```sh
17  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
18  . "$SCRIPT_DIR/lib/resolve.sh"
19
20  query="$*"
...
27  dir="$cur"
28
29  if [ -n "$query" ]; then
30      resolved=$(resolve "$query")
31      [ -n "$resolved" ] && dir="$resolved"      # <-- THE UNGUARDED LINE (no validation)
32  fi
33
34  base=$(basename "$dir")
35  tmux new-window -t "$session:" -c "$dir" -n "$base"
```

Two edits:
1. Insert the `NL` literal between line 18 (`. resolve.sh`) and line 20 (`query="$*"`).
2. Replace lines 29–32 (the `if…fi` block) with the `case`-guarded version.

`dir="$cur"` is ALREADY set on line 27, so "fall back to $cur" = "do nothing" (don't touch `dir`).
`base`/`new-window` (lines 34–35) are unchanged.

## 2. The guard is POSIX-clean and passes ShellCheck with NO new findings

Proposed final file run through `shellcheck`: the **only** message is
`SC1091 (info): Not following: ./lib/resolve.sh` on the PRE-EXISTING `. resolve.sh` source
line — identical to the original file (the original sources the same file). **My edits (the
`NL` literal + the `case`/`-d` guard) add zero findings.** A fully-clean run is obtained by
either:
- `shellcheck scripts/z-window.sh scripts/lib/resolve.sh`  (give it both files so it can follow the source), or
- `shellcheck -x scripts/z-window.sh`                       (in-repo, where `scripts/lib/resolve.sh` exists).

There is **no** SC1009/parse warning on the multiline `NL='<newline>'` literal — a real newline
between single quotes is valid POSIX and ShellCheck accepts it.

## 3. Guard logic proven 4/4 (tmux-free, deterministic)

Driving the exact `case … in *"$NL"*` + `[ -d ]` logic against simulated `resolve()` outputs:

| `resolved` value | newline? | `-d`? | result `dir` | ✓ |
|---|---|---|---|---|
| `/…/proj` (single line, real dir) | no | yes | `resolved` | PASS |
| `""` (empty / no match) | no | no (`-d ""` is false) | `$cur` | PASS |
| `/nonexistent` (single line, not a dir) | no | no | `$cur` | PASS |
| 3-line DB dump (`-l`) | **yes** | — | `$cur` | PASS |

**Critical insight:** the dump-rejection works even when **every** dumped line is itself a real
directory — the newline check (`case "$resolved" in *"$NL"*`) fires first and rejects the whole
multi-line value before the `-d` test ever runs. So a 146-line dump of real paths (the exact
Issue-1 symptom) is rejected solely by the newline arm. This is why the `case`-first ordering
matters: put `-d` first and a dump of real dirs would slip through.

## 4. NO hard dependency on P1.M1.T1.S2 (the parallel resolver `--` fix)

This is the key design point. Unlike T1.S2 (which hard-depends on T1.S1's fixture hardening),
**this task is true defence-in-depth and is order-independent**: the guard validates
`resolve()`'s *output*, so it catches a multi-line dump whether or not the resolver's `--`
guard is present.

Verified against BOTH resolver states, using the current (already-hardened, P1.M1.T1.S1 =
Complete) `tests/test_z_window.sh` fake:

- **resolve.sh WITHOUT `--` guard** (current repo state, T1.S2 parallel): `resolve("-l")` →
  `_resolve_zoxide "-l"` → `zoxide query -l` → fake (no `--`, hits list-mode arm) → **3-line
  dump** → guard's newline arm rejects → `dir=$cur`. ✓
- **resolve.sh WITH `--` guard** (after T1.S2): `resolve("-l")` → `_resolve_zoxide "-l"` →
  `zoxide query -- -l` → fake (strips `--`, keyword `-l` is positional, no list-mode) →
  **empty** → guard's `*)` arm runs `[ -d "" ]` = false → `dir=$cur`. ✓

Both states → correct fallback. And CASE 2 (`proj` match) passes in both states too (resolved
= single real dir → accepted). So `test_z_window.sh` stays pass=11 regardless of T1.S2.

## 5. Baseline confirmed: `sh tests/test_z_window.sh` → pass=11 fail=0 (run live)

Ran the real existing test (it spins up its own isolated `tmux -L zxstest_window` server +
hardened fake zoxide). All 4 cases green: empty→cur, proj→resolved, zzz→cur, spaced→1 window.
After the guard edit, these 4 cases are behavior-preserving (the guard only changes behavior
for multi-line/non-directory `resolved`, which none of the 4 cases produce).

## 6. P1.M1.T1.S1 fixture hardening is ALREADY APPLIED in the repo

The current `tests/test_z_window.sh` fake already:
- strips a leading `--` (`if [ "$1" = "--" ]; then shift`), and
- models list-mode for `-l`/`--list` (`-l|--list) printf … "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0`).

So a `-l` query through the existing test machinery already yields the 3-line dump that
exercises this guard. **The committed regression *assertion* for `-l` is owned by P1.M1.T3
(T3.S1 unit / T3.S2 integration) — do NOT add it here.** This task provides only a throwaway
Level-4 proof (see PRP) to demonstrate the guard fires, without committing a new test case.

## 7. The `NL` literal is load-bearing — don't collapse it

```sh
NL='
'
```
must contain a REAL newline (a genuine line break) between the single quotes. It is NOT
`NL='\n'` (that is a 2-character backslash-n literal, which would make `case "$resolved" in
*"$NL"*` match a literal `\n` sequence — never a real newline — and the guard would never
fire). The implementing tool must preserve the literal newline byte. Flagged as a gotcha.

## 8. Why NOT the PRD's suggested one-liner (§F4 / research_issue1_defense.md §B)

```sh
[ -n "$resolved" ] && [ -z "${resolved##*$'\n'*}" ] || { [ -d "$resolved" ] && dir="$resolved"; }
```
Two disqualifying faults: (1) `$'\n'` is a **bash/ksh-only** ANSI-C quote — not POSIX, breaks
under dash/ash; (2) its boolean logic is **inverted/confusing**. The `case "$resolved" in
*"$NL"*` idiom is the portable, readable equivalent and is what the item contract mandates.
