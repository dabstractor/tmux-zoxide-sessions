# Dependency & Behavior Probe — P1.M1.T3.S1 (`-l`/`--list` unit regression)

> Empirical confirmation (run live 2026-07-07) of the exact behavior the new
> regression assertions encode, and of the **hard prerequisite** on the resolver
> `--` guard (P1.M1.T1.S2).

## 1. What this task adds (paste-ready assertions)

### `tests/test_resolve_zoxide.sh` (was 3 checks → 6; floor `>=5`)

Append, between the existing 3 checks and the `echo "RESULTS:"` line:

```sh
# --- leading-dash regression (Issue 1: zoxide flag absorption) --------------
# The hardened fake strips `--` (real zoxide honors end-of-options) and models
# list-mode for -l/--list. With the resolver `--` guard in place, `query -- -l`
# strips `--`, sees `-l` as a positional query (no match) -> empty.
check "leading-dash -l resolves to empty"    ""  "$(withfake -l)"
check "leading-dash --list resolves to empty" "" "$(withfake --list)"
# Document WHY the `--` guard is needed: WITHOUT it, the fake enters list-mode
# for `query -l` and returns a MULTI-LINE dump. (Direct fake invocation.)
check "fake models list-mode: query -l -> multi-line dump" \
    "$(printf '%s\n' "/home/user/projects/proj" "/home/user/projects/other1" "/home/user/projects/other2")" \
    "$("$TBIN/zoxide" query -l)"
```

### `tests/test_resolve_dispatcher.sh` (was 14 checks → 18; floor `>=17`)

Append, near the exit-0 contract block (after case 14):

```sh
# --- leading-dash regression (Issue 1): the auto/zoxide dispatchers must NOT
# short-circuit on a multi-line dump, because the `--` guard makes zoxide
# return empty for a `-l` positional query. -------------------------------
check "zoxide: -l resolves empty" "" "$(rout zoxide -l)"
check "exit 0: zoxide -l"         "0" "$(rexit zoxide -l)"
check "auto: -l resolves empty"   "" "$(rout auto -l)"
check "exit 0: auto -l"           "0" "$(rexit auto -l)"
```

## 2. HARD PREREQUISITE — the resolver `--` guard (P1.M1.T1.S2)

The `-l`/`--list` **empty-resolution** checks (`withfake -l`/`--list`,
`rout auto -l`/`zoxide -l`) pass **only** when `scripts/lib/resolve.sh`
`_resolve_zoxide` calls `zoxide query -- "$1"` (the `--` guard restored by
P1.M1.T1.S2). If it still reads `zoxide query "$1"` (no `--`), those checks
**fail by design** — that is the expected signal that the prerequisite isn't
met. Do NOT weaken the assertions to pass against the unguarded resolver; do
NOT modify resolve.sh (owned by P1.M1.T1.S2).

### Proof (live)

Hardened fake (identical to the one already committed in the two test files):

| call                          | lines | value                                          |
|-------------------------------|------:|------------------------------------------------|
| `$TBIN/zoxide query -l`       |     3 | `/home/user/projects/proj` + 2 more (dump)     |
| `$TBIN/zoxide query --list`   |     3 | same 3-line dump                               |
| `$TBIN/zoxide query -- -l`    |     0 | empty (R2 holds: `--` beats list-mode)         |
| `query -l` contains newline?  |  yes  | (multi-line — proves list-mode is modeled)     |

Resolver path (fake prepended to PATH inside the `sh -c` subshell):

| resolver state             | `withfake -l`            | `withfake --list`        | `withfake proj` (no regression) |
|----------------------------|--------------------------|--------------------------|---------------------------------|
| **CURRENT** (no `--` guard)| 3-line DUMP ❌ (would FAIL the empty check) | 3-line dump ❌ | `/home/user/projects/proj` ✓ |
| **GUARDED** (P1.M1.T1.S2)  | empty ✓                  | empty ✓                  | `/home/user/projects/proj` ✓    |

Dispatcher (`resolve -l`, backend auto): guarded → empty + exit 0;
unguarded → the 3-line dump short-circuits the `[ -z "$_r" ] && _r=$(_resolve_z …)`
auto fallback (the Issue-1 bug), exit still 0 (CORRECTION B `return 0`).

## 3. Assertion mechanics — why exact-equality proves "multi-line"

The list-mode check compares the fake's `query -l` output against the exact
3-line dump (built with the same `printf '%s\n' …` the fake uses). POSIX `[ a = b ]`
compares full strings including embedded newlines; `$(…)` strips only *trailing*
newlines, so both sides keep the 2 internal newlines and are equal. Passing the
check therefore proves the value is multi-line (contains a newline) AND non-empty.
Robust alternative (intent over content): `"3" = "$("$TBIN/zoxide" query -l | wc -l | tr -d ' ')"`.

## 4. Exit-0 checks vs empty-output checks (which needs the guard)

- `rexit <backend> -l` → always `0`, **regardless of the guard**. The fake's
  `-l` arm exits 0 (list-mode success); and `resolve()` ends with `return 0`
  (CORRECTION B). So the exit-0 checks document the contract, not the guard.
- `rout <backend> -l` → empty **only with the guard**. This is the real
  regression assertion (it would return the 3-line dump unguarded).

## 5. Scope / non-regression

- Only the two UNIT test files are modified. No source, no integration tests
  (those are P1.M1.T3.S2), no README, no resolve.sh.
- The existing `proj`/`zzz_nomatch`/missing-binary checks (zoxide.sh) and the
  14-case dispatcher suite must stay green — the new fake bodies are already
  in place (P1.M1.T1.S1 = Complete), so the existing checks are unaffected.
- The `withfake`/`rout`/`rexit` helpers already exist in the two files; the new
  checks reuse them verbatim — no helper changes.
