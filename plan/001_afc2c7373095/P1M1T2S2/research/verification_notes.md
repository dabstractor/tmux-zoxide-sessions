# Verification Notes — P1.M1.T2.S2 (`_resolve_zoxide`)

Empirically verified on this machine: `zoxide` at `/home/dustin/.local/bin/zoxide`,
`/bin/sh → bash`, `shellcheck` installed. These ground the PRP's validation gates and
resolve the one open discrepancy in the architecture research.

## 1. The mandated function form passes `shellcheck` clean (no exclusions)

Exact form (PRD §5.3 + the NOTE D `--` guard):
```sh
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
}
```
Sourced alongside the S1 `get_tmux_option` (the file as it will exist after S2),
`shellcheck` → **exit 0, no output**. No SC2015, no SC2086 (`"$1"` is quoted), no SC2181.
No `# shellcheck disable=` directives needed. **Do not** rewrite the `&&` form or add
`|| true` / `; return 0` — the item contract mandates this exact shape, and it lints clean.

## 2. zoxide no-match exit status: empirically exit 0 (resolves the research discrepancy)

`research_resolver_backends.md` §1 (written with **no shell tool available**, knowledge-only)
claimed `zoxide query` returns **exit 1** on no-match. `findings_and_risks.md` #5 (empirically
verified on this machine) says **exit 0, empty stdout, no stderr**. The two conflict.

**Resolved by direct test on this machine:**
```sh
$ out=$(zoxide query -- "zzz_definitely_nomatch_xyz_999" 2>/dev/null); echo "stdout=[$out] rc=$?"
stdout=[] rc=0
```
→ **findings_and_risks.md #5 is authoritative.** No-match = exit 0 + empty stdout + no stderr
noise. The PRD §5.3 contract ("callers check output, not status"; `_resolve_zoxide` returns
empty on miss with exit 0) holds exactly as written. The function needs **no** `|| true`.

> The version here happens to exit 0 on a miss; other zoxide versions may exit 1. This is
> harmless for S2 because `_resolve_zoxide` is **never called directly** by handler scripts —
> it is only consumed by `resolve()` (S4), and (a) the `auto` path captures output in a
> subshell `$(...)` discarding status, and (b) CORRECTION B (S4) ends `resolve()` with an
> unconditional `return 0`. So a future exit-1 zoxide still can't leak. Do NOT add defense
> to `_resolve_zoxide` itself — keep the mandated form.

## 3. Empty-keyword behavior: `zoxide query -- ""` → empty, exit 0

`research_resolver_backends.md` flagged empty/whitespace queries as version-sensitive
(possible "global best match" false positive). Tested here:
```sh
$ out=$(zoxide query -- "" 2>/dev/null); echo "stdout=[$out] rc=$?"
stdout=[] rc=0
```
→ empty keyword behaves as a clean miss on this version (no false-positive global-best).
S2 therefore does **not** need a query pre-validation guard; S4's `resolve()` may add one
if desired, but it is out of scope for S2 (the item contract is the exact 2-line function).

## 4. The TDD test harness passes 3/3 (match / no-match / missing-binary)

A dependency-free POSIX-`sh` test, modelled on the S1 fake-`tmux` harness, with a fake
`zoxide` shim earlier on PATH. Verified `RESULTS: pass=3 fail=0`, exit 0:
- **match** → echoes the canned path
- **no-match** → echoes empty
- **missing-binary** → echoes empty, never errors

See the PRP for the verbatim test script.

## 5. ⚠️ Critical test-harness false-pass bug (found and fixed)

**The bug.** A naive missing-binary test written as
```sh
PATH="$EMPTY_BIN" sh -c '. resolve.sh; _resolve_zoxide proj'
```
produces `sh: command not found` on stderr. Reason: a command-prefix assignment
(`PATH=x cmd`) narrows PATH **before** the shell resolves the command word `sh`, so `sh`
itself is not found (confirmed: `/bin/sh → bash` here, and dash behaves the same). The
command substitution then captures **empty stdout** — which happens to equal the expected
`""` — so the assertion **passes for the wrong reason** (the function never ran). This is a
silent false pass: it would not detect a real regression in `_resolve_zoxide`.

**The fix.** Resolve `sh` via the outer PATH, then narrow PATH **inside** the subshell
before calling the function:
```sh
without() {
    sh -c '. "$0"; PATH="$1"; _resolve_zoxide "$2"' "$RESOLVE" "$EMPTY_BIN" "$1"
}
```
Now `sh` runs, `resolve.sh` is sourced (only defines functions — needs no PATH), then PATH
is narrowed so `command -v zoxide` (a builtin searching PATH) finds nothing and the `&&`
short-circuits. The function is genuinely exercised.

**Proof that the fixed test is real** (not a silent no-op): drop a fake `zoxide` into the
"empty" bin and the function returns its output (`/PROOF/command-v-is-consulted`); empty the
bin and it returns nothing. So `command -v` is actually consulted by the missing-binary case.

## 6. Fake-zoxide arg parsing: must honor the `--` guard

The function calls `zoxide query -- "$1"`, so the fake receives args `query -- <keyword>`.
The fake parses: drop `query`, drop a leading `--` (the NOTE D end-of-options guard), take
the next token as the keyword. This mirrors how the real zoxide (clap) treats `--` and keeps
the test honest about the S2 contract (the `--` is part of what we ship).

## 7. Scope boundary (anti-regression)

This subtask **appends** `_resolve_zoxide` to the existing `scripts/lib/resolve.sh` (which
S1 created with `get_tmux_option` only). Do NOT:
- modify `get_tmux_option`,
- pre-write `_resolve_z` (S3, CORRECTION A) or `resolve` (S4, CORRECTION B),
- chmod anything, or touch `.gitignore` / `PRD.md`.

Append-only: preserve the shebang, header comment, and `get_tmux_option` byte-for-byte.
