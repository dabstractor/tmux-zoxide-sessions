# Test Suite Baseline — `tmux-zoxide-sessions`

> Generated 2026-07-07 by running the exact commands from the task brief.
> Purpose: establish the green baseline (pass/fail counts, invocation pattern,
> fake-vs-real backend classification, assertion format) before any bugfix work.

## 1. Test invocation pattern

- **No `Makefile`, no test runner.** There is no `Makefile`, `*.mk`, `bats`,
  `shellspec`, or `prove` harness. Each test is a standalone POSIX `sh` script run
  directly:

  ```sh
  sh tests/test_<name>.sh
  ```

- 9 test files live under `tests/`:

  | file | category |
  |------|----------|
  | `test_resolve_get_tmux_option.sh` | unit (resolve.sh) |
  | `test_resolve_zoxide.sh`          | unit (resolve.sh) |
  | `test_resolve_z.sh`               | unit (resolve.sh) |
  | `test_resolve_dispatcher.sh`      | unit (resolve.sh, top-level `resolve`) |
  | `test_z_window.sh`                | integration (z-window.sh + resolve.sh + real tmux) |
  | `test_z_session.sh`               | integration (z-session.sh + resolve.sh + real tmux) |
  | `test_run_file.sh`                | integration (`tmux-zoxide-sessions.tmux` run file + real tmux) |
  | `test_session_hook.sh`            | integration (session-created hook wiring + real tmux) |
  | `test_backend_matrix.sh`          | integration matrix (auto/zoxide/z backends + real tmux) |

- **Canonical run-all loop** (from the task):

  ```sh
  for t in tests/test_*.sh; do echo "=== $t ==="; sh "$t" 2>&1 | tail -5; echo; done
  ```

## 2. Full-suite results — ALL GREEN

Every test exits `0`. Aggregate assertion count: **80 PASS / 0 FAIL**.

| test | assertions pass | fail | exit |
|------|----:|----:|----:|
| `test_resolve_get_tmux_option.sh` | 6  | 0 | 0 |
| `test_resolve_zoxide.sh`          | 3  | 0 | 0 |
| `test_resolve_z.sh`               | 5  | 0 | 0 |
| `test_resolve_dispatcher.sh`      | 14 | 0 | 0 |
| `test_z_window.sh`                | 11 | 0 | 0 |
| `test_z_session.sh`               | 9  | 0 | 0 |
| `test_run_file.sh`                | 9  | 0 | 0 |
| `test_session_hook.sh`            | 11 | 0 | 0 |
| `test_backend_matrix.sh`          | 12 | 0 | 0 |
| **TOTAL**                         | **80** | **0** | — |

Tail output per test (matches the loop above) for reference:

```
=== tests/test_backend_matrix.sh ===
... RESULTS: pass=12 fail=0
=== tests/test_resolve_dispatcher.sh ===
... RESULTS: pass=14 fail=0
=== tests/test_resolve_get_tmux_option.sh ===
... RESULTS: pass=6 fail=0
=== tests/test_resolve_zoxide.sh ===
... RESULTS: pass=3 fail=0
=== tests/test_resolve_z.sh ===
... RESULTS: pass=5 fail=0
=== tests/test_run_file.sh ===
... RESULTS: pass=9 fail=0
=== tests/test_session_hook.sh ===
... RESULTS: pass=11 fail=0
=== tests/test_z_session.sh ===
... RESULTS: pass=9 fail=0
=== tests/test_z_window.sh ===
... RESULTS: pass=11 fail=0
```

## 3. Assertion format

All tests use the **same** in-file helper (no shared library). Body (verbatim from
`test_backend_matrix.sh`, identical everywhere):

```sh
pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}
```

- Equality is exact string (`[ "$2" = "$3 ]`).
- Output format: `PASS  <desc> (got=[<actual>])` / `FAIL  <desc> (expected=[<exp>] got=[<act>])`.
- Two tests add a **substring** helper for fixture-file / config-text checks:
  ```sh
  contains() {  # contains <desc> <haystack> <needle>
      if printf '%s' "$2" | grep -Fq -- "$3"; then echo "PASS  $1"; pass=$((pass+1));
      else echo "FAIL  $1 (expected haystack to contain [$3]; got=[$2])"; fail=$((fail+1)); fi
  }
  ```
  Used by `test_run_file.sh` and `test_session_hook.sh` (e.g. "run file contains
  `@zoxide-sessions-auto-session`"). `test_backend_matrix.sh` also defines driver
  helpers `window_jump`/`session_relocate` that ultimately call `check`.
- Each script ends with `echo "RESULTS: pass=$pass fail=$fail"` and a final
  `[ "$fail" -eq 0 ]`, so **exit code 0 ⇔ zero failures** (confirmed per file above).
- Fakes are written under `tests/.<name>-bin/` temp dirs and removed via a
  `trap cleanup EXIT INT TERM`; the `.gitignore` does not list them but they are
  created/removed at runtime (no committed binaries).

## 4. Fake zoxide vs real zoxide (and tmux)

Environment at run time: real `zoxide` on PATH (`/home/dustin/.local/bin/zoxide`),
real `tmux` (`/usr/bin/tmux`). Tests deliberately sandbox so they neither depend on
nor pollute the user's live state.

### Unit tests — fake everything, no live zoxide/tmux
Source `scripts/lib/resolve.sh` inside a `sh -c` subshell with a stubbed PATH; assert
pure function behavior.

| test | `zoxide` | `tmux` | other |
|------|----------|--------|-------|
| `test_resolve_zoxide.sh`        | **fake** (match / no-match); plus an *empty dir* to prove the missing-binary path | none (not on PATH) | — |
| `test_resolve_z.sh`             | none — uses **fake rupa/z `z.sh`** fixture | **fake** #1 (`@zoxide-sessions-z-sh` SET) + **fake** #2 (UNSET → short-circuit) | seeds `_Z_DATA` |
| `test_resolve_get_tmux_option.sh` | none (no zoxide path) | **fake** (`show-option -gqv`) | — |
| `test_resolve_dispatcher.sh`    | **fake** (match→exit 0, no-match→empty+**exit 1**, simulating the version-dependent non-zero exit CORRECTION-B defends against) | **fake** (answers `@zoxide-sessions-backend` via `$ZS_BACKEND`, default `auto`; answers `@zoxide-sessions-z-sh`) | fake `z.sh` for the `z` backend |

### Integration tests — real tmux (isolated), fake zoxide (deterministic)
Pattern: boot a **real but isolated** tmux server `"$REAL_TMUX" -f /dev/null -L zxstest*`
(`-f /dev/null` ⇒ user's `tmux.conf` is NOT sourced), put a **fake `tmux` wrapper**
first on PATH that forwards every bare `tmux` call to that socket, and set
`PATH="$TBIN:$PATH"` **before** booting so `run-shell`/`new-window` inherit it. A
**fake `zoxide`** maps known tokens (`proj`, `projhook`, `twowords`, `zxmatrix`) to
real fixture dirs. The production scripts (`z-window.sh`, `z-session.sh`, the run
file, `resolve.sh`) run **unmodified**.

| test | zoxide | tmux |
|------|--------|------|
| `test_z_window.sh`   | **fake** (`proj`→`$FIX/proj`) | real isolated (`zxstest`) via fake wrapper |
| `test_z_session.sh`  | **fake** (known names→fixture; `@...-home-dir` set) | real isolated (`zxstest_session`) via fake wrapper |
| `test_run_file.sh`   | **fake** (`proj`→fixture) | real isolated (`zxstest_run`) via fake wrapper; runs the **run file directly** |
| `test_session_hook.sh` | none (no zoxide; tests hook wiring only) | real isolated (`zxstest_hook`) via fake wrapper |

### `test_backend_matrix.sh` — the ONLY test touching REAL zoxide
Three subtests on one isolated real server (token `zxmatrix`):

- **SUBTEST A — REAL zoxide.** Guards `ZOXIDE_ON_PATH="$(command -v zoxide ...)"`;
  if absent, the case is **SKIP**ped (never passes vacuously). When present it seeds
  zoxide's frecency index and asserts the window-jump / session-relocate land at the
  real resolved path. This is the only place the real `zoxide` binary is exercised.
- **SUBTEST B — fake zoxide shim** installed into `$TBIN` (returns the canned fixture
  dir for the token), asserted, then `rm -f "$TBIN/zoxide"` so it cannot leak into A/C.
- **SUBTEST C — rupa/z (`z` backend)** via seeded `_Z_DATA` + `@zoxide-sessions-z-sh`.

`REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"` is the configurable real-tmux anchor used by
all integration tests; the fake `tmux` wrapper always delegates to it.

**Summary classification:**
- Real `zoxide`: only `test_backend_matrix.sh` SUBTEST A (skip-if-absent).
- Fake `zoxide`: `resolve_zoxide`, `resolve_dispatcher`, `z_window`, `z_session`,
  `run_file`, and `backend_matrix` SUBTEST B.
- No `zoxide` at all: `resolve_z`, `resolve_get_tmux_option`, `session_hook`,
  `backend_matrix` SUBTEST C.
- Real `tmux` (isolated `-f /dev/null -L zxstest*`, via fake wrapper): all 5
  integration tests. No live `tmux` in the 4 unit tests.

## 5. ShellCheck

Command (verbatim):

```sh
shellcheck scripts/lib/resolve.sh scripts/z-window.sh scripts/z-session.sh tmux-zoxide-sessions.tmux
```

Result: **only SC1091 (info level)** — "Not following: … was not specified as input."
Exit code is `1` **only because** ShellCheck exits non-zero on any finding incl. info.
There are **no warnings, no errors, no style notes**.

For the exact combined command above, SC1091 fires for:
- `scripts/z-window.sh:16` — `. "$SCRIPT_DIR/lib/resolve.sh"`
- `scripts/z-session.sh:11` — `. "$SCRIPT_DIR/lib/resolve.sh"`

The `.tmux` file is **clean in the combined run** (its source target
`./scripts/lib/resolve.sh` matches an input file, so ShellCheck can follow it).
Per-file (run individually) every consumer emits one SC1091 and `resolve.sh` is clean:

| file | findings (info only) | combined-run |
|------|----|----|
| `scripts/lib/resolve.sh`         | 0 | clean |
| `scripts/z-window.sh`            | 1 (SC1091, line 16) | reported |
| `scripts/z-session.sh`           | 1 (SC1091, line 11) | reported |
| `tmux-zoxide-sessions.tmux`      | 1 (SC1091, line 10) | clean (resolvable) |

All SC1091 notes are an inherent artifact of the multi-file sourced architecture and
are noise, not defects — resolvable with `shellcheck -x` or a `.shellcheckrc`
`external-sources=true`. ShellCheck version: **0.11.0**.

## 6. Baseline / takeaway

- Suite is **fully green: 80 pass / 0 fail, 9/9 exit 0**.
- **No `Makefile`/runner** — invocation is `sh tests/test_*.sh`; CI/repeat is the
  `for` loop.
- Assertion contract: exact-equality `check <desc> <expected> <actual>` (PASS/FAIL +
  `RESULTS:` line + final `[ fail -eq 0 ]`), with `contains` substring helper in two tests.
- Isolation: unit tests stub `tmux`/`zoxide`/`z.sh` in a `sh -c` subshell (no live
  binaries); integration tests drive a real but **isolated** `tmux -f /dev/null -L
  zxstest*` server via a fake `tmux` wrapper, with a fake `zoxide` for determinism.
  Only `test_backend_matrix.sh` SUBTEST A exercises the **real** `zoxide` (skip-if-absent).
- ShellCheck: clean modulo expected SC1091 source-follow infos.

This is the regression target: any bugfix must keep all 9 tests green and not regress
the (informational) ShellCheck output.
