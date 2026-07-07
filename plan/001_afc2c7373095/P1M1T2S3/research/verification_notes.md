# Verification Notes — P1.M1.T2.S3 (`_resolve_z`, CORRECTION A)

Empirically verified on this machine: rupa/z at `/home/dustin/.config/znap/rupa/z/z.sh`
(populated `~/.z`, 7430 B), `zsh 5.9.1` at `/usr/bin/zsh`, `shellcheck 0.11.0`,
`/bin/sh -> bash`. These ground the PRP's validation gates and resolve the two gaps
the architecture notes left open.

## 1. CORRECTION A validated: the bug is real, the fix works (sh AND zsh)

`findings_and_risks.md` §A reproduced the bug from knowledge + one probe. Re-confirmed
here across both shell paths (`sh` and `zsh`, since the function picks zsh when present
— and it is present on this machine):

| Query | PRD §5.3 buggy form (`pwd` after `_z`) | CORRECTION A (pwd-delta) |
| --- | --- | --- |
| `zzz_nomatch_xyz_999` (no-match) | `/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions` ❌ | *(empty)* ✓ |
| `tmux` (real match) | `/home/dustin/.config/tmux` ✓ | `/home/dustin/.config/tmux` ✓ |

Exit codes (CORRECTION A): no-match → **0**, match → **0**. (Buggy form also exits 0 —
status is not the signal; output is.) Identical results under `sh -c` and `zsh -c`.

**Root cause restated for the implementer:** rupa/z's `_z` does `cd` on a match and is a
silent **no-op on a miss**. The PRD form unconditionally runs `pwd` after `_z`, so a miss
prints the subshell's *starting* directory — a non-empty, wrong path. CORRECTION A captures
`pwd` before (`o`) and after (`n`) `_z` and emits `n` only when `o != n`. The trailing
`exit 0` honors the documented contract ("resolve always exits 0").

## 2. ⚠️ Shellcheck gap in findings_and_risks.md §A (found and resolved)

The §A code block was **not** run through shellcheck in the architecture notes. On
shellcheck 0.11.0 the §A-verbatim form emits two findings:

```
line: shell=sh; ...   ->  SC2209 (warning): Use var=$(command) ... (or quote to assign string).
line: "$shell" -c '...'  ->  SC2016 (info): Expressions don't expand in single quotes ...
```

- **SC2209** is a real, trivially-fixable style nit: `shell=sh` looks like assigning a
  command. **Fix:** quote it — `shell="sh"` / `shell="zsh"`. Behavior identical.
- **SC2016 is an intentional false positive.** The `"$shell" -c '. "$1"; _z "$2"; …'`
  form deliberately uses **single quotes** so the inner `$1`/`$2`/`$o`/`$n` expand
  *inside the subshell* (where `$1`=`$z_sh`, `$2`=the query are passed as positional
  args via `_ "$z_sh" "$1"`), NOT in the parent. Switching to double quotes would require
  escaping every `$` and is more error-prone. This is exactly the PRD §5.3 `_resolve_z`
  structure — CORRECTION A only changes the *body* of the subshell string, not the
  single-quote/positional-arg pattern. **Fix:** a scoped directive on the line.

**Verified shellcheck-clean variant (OPTION C)** — behaviorally identical to §A, exit 0 +
no output on shellcheck 0.11.0:
```sh
_resolve_z() {
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    [ -n "$z_sh" ] && [ -r "$z_sh" ] || return 0
    shell="sh"; command -v zsh >/dev/null 2>&1 && shell="zsh"
    # shellcheck disable=SC2016 # inner $1/$2/$o/$n expand inside the subshell, not the parent
    "$shell" -c '. "$1" 2>/dev/null || exit 0; o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ] && printf "%s\n" "$n"; exit 0' \
        _ "$z_sh" "$1" 2>/dev/null
}
```
The `disable=SC2016` is **scoped to one line** with a justifying comment — this is the
idiomatic way to silence an intentional shellcheck false positive. (S2's "no directives"
stance applied to its trivial 1-line `&&` chain, which is genuinely clean; S3's subshell
pattern is structurally different and legitimately needs the annotation.)

> If the implementer prefers the §A-verbatim form (`shell=sh`, no directive), the function
> still *behaves* identically and the unit test still passes 5/5 — but `shellcheck
> scripts/lib/resolve.sh` will emit SC2209+SC2016 and the Level-1 gate will not be "exit 0,
> no output." OPTION C is mandated by this PRP to keep the lint bar S1/S2 set.

## 3. Why the subshell is structurally required (no cleaner refactor)

`_z` has a side effect (`cd`). `resolve.sh` is *sourced* by the run file and both handler
scripts — `_resolve_z` MUST NOT leave the parent's cwd changed. So the lookup has to run in
an isolated process. A `(...)` subshell in the parent shell would drop the PRD's
"zsh-if-available" preference (z.sh has a zsh code path; the PRD prefers it). The
`"$shell" -c '…' _ "$z_sh" "$query"` form isolates the side effect AND honors the
shell preference. Keep it.

## 4. The TDD unit test passes 5/5 and is shellcheck-clean

A dependency-free POSIX-`sh` test, modelled on S1's fake-`tmux` + S2's fake-`zoxide`
harnesses. Instead of depending on the live `~/.z` (machine-specific), it ships a **minimal
`z.sh` fixture** whose `_z` reproduces only the two semantics CORRECTION A depends on:
`cd` on a known match (`proj`), no-op on a miss. Verified `RESULTS: pass=5 fail=0`, exit 0:

- **case 1** — BUGGY PRD §5.3 form (inline) on a no-match → **NON-empty** (characterizes
  the false positive; this is the TDD "red" motivation).
- **case 2** — shipped `_resolve_z` match → the fixture's canned path.
- **case 3** — shipped `_resolve_z` no-match → **empty** (the core fix).
- **case 4** — option unset (fake tmux answers "") → short-circuit, empty.
- **case 5** — `_resolve_z` exit code → **0** on a no-match (documented contract).

`shellcheck tests/test_resolve_z.sh` → exit 0, no output.

### Test-design gotcha (found and fixed): env-var propagation into the nested subshell

`_resolve_z` spawns a **nested** subshell (`sh -c` → `"$shell" -c` → sources `z.sh`). A
naive fake `z.sh` that references `$ZFIX` at runtime depends on that var propagating two
subshell levels deep — fragile, and per-command `VAR=x cmd` assignments also trip
shellcheck SC2097/SC2098. **Fix:** bake the absolute path into the fake `z.sh` at
*generation* time using an **unquoted heredoc** with `\$1` escaped, so the fixture holds a
literal path and `$1` stays the function's positional param:
```sh
cat > "$ZFIX/z.sh" <<ZSH
_z() {
    case "\$1" in
        proj) cd "$ZFIX/proj" 2>/dev/null || cd / ;;   # $ZFIX baked at gen time
        *) ;;                                          # \$1 stays literal
    esac
}
ZSH
```
No runtime env var needed; the fixture is fully self-contained. (The PRP's verbatim test
uses exactly this.)

## 5. Live rupa/z smoke (optional, not a gate)

Against the REAL `z.sh` + populated `~/.z` on this machine, CORRECTION A returns
`/home/dustin/.config/tmux` for `tmux` and empty for a guaranteed no-match (see §1). This is
a sanity check only — the Level-2 unit test (case 2/3) is the authoritative gate because it
is deterministic and machine-independent.

## 6. Scope boundary (anti-regression)

This subtask **appends** `_resolve_z` (CORRECTION A, OPTION C form) to the existing
`scripts/lib/resolve.sh`, which after S2 holds `get_tmux_option` + `_resolve_zoxide`. Do NOT:
- modify `get_tmux_option` or `_resolve_zoxide` (S1/S2 own them),
- pre-write `resolve` (S4, CORRECTION B) — `_resolve_z`'s intentional `exit 0`/`return 0`
  is what lets S4's `return 0` defense compose cleanly,
- chmod anything, or touch `.gitignore` / `PRD.md`.

Append-only: preserve the shebang, header comment, `get_tmux_option`, and `_resolve_zoxide`
byte-for-byte.
