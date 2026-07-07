# Verification Notes — P1.M1.T2.S4: `resolve()` dispatcher (CORRECTION B)

> These notes ground every gate in the PRP. All validation ran in an **isolated
> `/tmp/zsprp_validate/`** copy (the real repo was NOT modified — this is a research
> agent). The copy reproduced the post-S3 `resolve.sh` (3 functions) and appended the
> CORRECTION-B `resolve()`, plus the full `tests/test_resolve_dispatcher.sh`.

## §1 What CORRECTION B actually is

`findings_and_risks.md` §B: the PRD §5.3 `resolve()` body's **last executed statement in
the `zoxide`/`z` branches is the backend call**, whose exit status propagates as the
function's. The `auto` branch's last statement is `printf` (always exit 0), so `auto` is
already safe — the gap is the two **direct** branches. The fix is a single unconditional
`return 0` after the `case`:

```sh
    esac
    return 0   # honor the documented contract regardless of backend exit status
```

That `return 0` is the **entire** delta from PRD §5.3. Everything else (the `case` over
`zoxide`/`z`/`auto`, the `auto` capture-into-`_r`-then-`printf` fallback) is verbatim PRD.

## §2 Why the fake `zoxide` MUST exit 1 on no-match (the key test-design decision)

The **real** `zoxide` on this machine exits **0** on a no-match (findings_and_risks.md #5,
empirically confirmed). If the test's fake `zoxide` also exited 0 on no-match, then:
- `resolve()` WITHOUT `return 0` would already exit 0 (status propagated = 0) → the TDD
  "red" case could **never fail** → CORRECTION B would be untestable (a silent false-pass,
  exactly the class of bug S2's `without()` helper guards against).

CORRECTION B exists precisely because **"zoxide exit code on no-match varies by version"**
(§B). So the fake `zoxide` **deliberately** exits **1** on no-match to **simulate that
version-dependent non-zero exit**. Then:
- **Red** (resolve WITHOUT `return 0`, `zoxide` branch, no-match): status 1 leaks out →
  `buggy_rc != 0` → asserts `NONZERO` (proves the bug is real on such a version).
- **Green** (shipped resolve WITH `return 0`): `return 0` overrides the leaked 1 → asserts `0`.

This is the only way to make the exit-0 gate *meaningful* rather than vacuous. The
output assertions (match→path, no-match→empty) are unaffected by exit code, so the
`exit 1` does not perturb any other case.

## §3 Mocking strategy: one fake `tmux` + backend via `$ZS_BACKEND` env var

`resolve()` reads `@zoxide-sessions-backend` via `get_tmux_option` → `tmux show-option`;
`_resolve_z` reads `@zoxide-sessions-z-sh` via `tmux show-option`. A **single fake `tmux`**
answers **both** option names:
- `@zoxide-sessions-backend` → `printf '%s\n' "${ZS_BACKEND:-auto}"` (runtime env var,
  default `auto` so the sourceability smoke works with nothing set);
- `@zoxide-sessions-z-sh` → the baked `$ZSH` fixture path (literal, via an **unquoted**
  heredoc — same technique as S3's fake `z.sh`, avoids nested-subshell env propagation).

The backend is switched per test case by exporting `ZS_BACKEND` **inside** the test's
`sh -c` subshell, then prepending the fake bin dir to `PATH`:
```sh
rout() { sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3"' \
    "$RESOLVE" "$1" "$TBIN" "$2"; }
```
Why an env var (not 3 separate fake-tmux binaries)? `tmux` is a **direct child** of the
shell running `resolve` (no nesting), so a single `export` propagates reliably — no
SC2097/SC2098 trap (those only bite `VAR=x cmd` per-command assignments across nested
subshells, the S3 gotcha). Cleaner than 3× the heredoc. Note: the fake `tmux` heredoc
body is **not** linted by shellcheck (heredoc bodies are data) — same as S2's fake
`zoxide` (which also starts with `#!/bin/sh`) and S3's fake `z.sh`.

## §4 Discriminating the backends (distinct match keywords)

To prove *which* backend answered, the fakes use **different** match keywords/paths:
- fake `zoxide` matches `proj` → `/home/user/projects/proj`;
- fake `z.sh` `_z` matches `work` → `$ZFIX/work`.
So `auto + work` exercises the **fallback** (zoxide miss → z hit) and returns `$ZFIX/work`
(not the zoxide path) — a genuine, observable fallback assertion rather than a tautology.

## §5 Empirical results (run during research — `/tmp` copy)

| Gate | Command | Result |
|---|---|---|
| Lint (lib) | `shellcheck scripts/lib/resolve.sh` | exit 0, **no output** |
| Lint (test) | `shellcheck tests/test_resolve_dispatcher.sh` | exit 0, **no output** |
| Unit test | `sh tests/test_resolve_dispatcher.sh` | `RESULTS: pass=14 fail=0`, exit 0 |
| CORRECTION-B present | `grep -nF 'return 0   # honor the documented contract'` | 1 match (line 43) |
| Sourceability | `. resolve.sh; type resolve` | defined (last of 4 functions) |
| No regression | S1/S2/S3 functions still defined after append | all 4 present (byte-preserved head) |

The 14 cases: 1 TDD-red (buggy form leaks non-zero) + 7 output (3 backends × {match,no-match}
+ the `auto` fallback) + 6 exit-0 (3 backends × {match,no-match}). Full case-by-case PASS
lines reproduced in the run log (every `got=[…]` matched its expected).

## §6 Composes with S3 (CORRECTION A) and the downstream consumers

- `_resolve_z` (S3, CORRECTION A) intentionally ends `exit 0` (subshell) / `return 0`
  (short-circuit), and `_resolve_zoxide` (S2) returns zoxide's status. CORRECTION B's
  `return 0` is **defense in depth on top of both** — it does not assume either backend's
  status, which is exactly §B's rationale ("defense in depth across backends/versions").
- Downstream `z-session.sh` (PRD §5.5) writes `resolved=$(resolve "$name") || exit 0` —
  already robust to non-zero, but CORRECTION B makes the `|| exit 0` belt-and-suspenders
  rather than load-bearing. `z-window.sh` checks output only. Both are decoupled from the
  dispatcher's internals; they call `resolve()` only.

## §7 Residual / scope notes

- `/bin/sh` → bash on this dev machine; POSIX-strictness is observed via `shellcheck`, not
  a real dash execution (same residual as S1/S2/S3; the function uses only the most
  conservative POSIX subset). The unit test is the authoritative, machine-independent gate.
- No live tmux / zoxide / rupa/z is required by the test — all three are faked. An optional
  live smoke is in PRP Level 3 but is **not** a gate.
- `resolve()` is the **last** function appended to `resolve.sh` (S1→S2→S3→S4); the file
  now holds all 4 and is complete for P1.M1.T2.
