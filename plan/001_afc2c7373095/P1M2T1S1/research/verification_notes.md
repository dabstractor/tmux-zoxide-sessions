# Verification Notes — P1.M2.T1.S1 (`z-window.sh`)

> Empirically validated in an **isolated `/tmp/zwin_validation/` tree** (repo untouched).
> Tooling on this machine: tmux 3.6b (`/usr/bin/tmux`), shellcheck 0.11.0, zsh 5.x.
> The full implementation (PRD §5.4 `z-window.sh` verbatim) + a 9-case integration test were
> written, run, and refined here. Final state: **`RESULTS: pass=9 fail=0`, exit 0, empty
> stderr, 5 consecutive runs (no flake), shellcheck-clean on both files**.

## 1. What the subtask ships

Two artifacts:
- `scripts/z-window.sh` — **PRD §5.4 verbatim** (no deviations), made executable (`chmod +x`).
  Sourced `lib/resolve.sh`; `query="$*"`; reads `cur`/`session` via `tmux display-message -p`;
  resolves on non-empty query; `new-window -t "$session:" -c "$dir" -n "$base"`.
- `tests/test_z_window.sh` — dependency-free POSIX-`sh` **integration** test against an
  isolated tmux server, with a fake `resolve` injected via a staged lib/resolve.sh.

## 2. The `%%` / `"$*"` recombination (findings_and_risks.md §✅6) — CONFIRMED

`command-prompt ... %%` substitution is **textual and splits on spaces**, so a typed query
`my proj` reaches `z-window.sh` as **two argv entries** (`$1=my`, `$2=proj`). The script uses
`query="$*"` which **recombines** them (`"$*"="my proj"`), so spaced queries resolve correctly.

Test case 4 exploits this as a **TDD discriminator**: the fake `resolve` matches the spaced
keyword `"my proj"`. With the correct `query="$*"` → resolve gets `"my proj"` → match.
With a buggy `query="$1"` → resolve gets only `"my"` → no match → fallback to current dir.
**Confirmed PASS** with `"$*"`. Do NOT change to `"$1"` (would break spaced queries).

## 3. tmux no-client behavior — the two sandbox quirks that shape the harness

z-window.sh is invoked via `run-shell` from a keybinding in **production** (the active client
sets the "current pane" context). The test invokes it **directly from a shell** (no client).
Two empirically-discovered behaviors govern the harness design:

### 3a. `display-message -p '#{pane_current_path}'` (no `-t`) resolves without a client
With no attached client, it targets the **most-recent session's active pane**. So `cur=$(...)`
and `session=$(...)` both work from the test shell (the isolated server's only session is the
"current" one). **Confirmed**: `#{session_name}` → `zs`, `#{pane_current_path}` → the `-c` dir.

### 3b. `#{pane_current_path}` has a small propagation race after pane creation
Immediately after `new-session -d -c "$DIR"` / `new-window -c "$DIR"`, `#{pane_current_path}`
may briefly report the **server's cwd** (where the server process was launched) instead of
`$DIR`, until the new pane's process establishes its cwd. `#{pane_start_path}` reflects `-c`
**immediately** (no race). **Fix**: a `sleep 0.3` after creating the session/window lets
`#{pane_current_path}` settle to the `-c` dir reliably. (The contract asks to assert via
`#{pane_current_path}`, so we sleep; `#{pane_start_path}` is noted as a no-race alternative.)

## 4. default-shell must be PINNED on the isolated server (sandbox quirk)

This sandbox's tmux starts with **`default-shell=[]` (empty)**. With an empty default-shell,
new panes spawn erratically (re-launching the `tmux` binary as the pane "shell"), and a second
`new-window` eventually **kills the isolated server** ("server exited unexpectedly").

**Fix (TEST-HARNESS ONLY — z-window.sh never sets default-shell)**: in the test's `newserver()`,
`start-server` → `set-option -g default-shell "$DSHELL"` (where `DSHELL="${SHELL:-/bin/sh}"`)
→ `new-session`. Order matters: pin default-shell **before** creating the session so its first
pane inherits the real shell. With a real login shell, panes stay alive and `#{pane_current_path}`
reliably reflects `-c` (mirrors production where the user's shell is configured). **Confirmed**:
after pinning, `pane_current_command=zsh`, panes `dead=0`, server stable across all cases.

## 5. kill-server → start-server socket race (the inter-case flake)

Each TDD case calls `newserver()`, which `kill-server`s the prior server then `start-server`s a
new one. If a **real** server was just killed, `start-server`/`new-session` can race the socket
cleanup → the new server dies mid-case. Case 1 (first run) never hit this (its `kill-server` is a
no-op on a nonexistent server); case 2+ did. **Fix**: `sleep 0.25` between `kill-server` and
`start-server` lets the killed server release its socket. **Confirmed**: 5 consecutive runs,
0 flakes.

## 6. Mocking strategy (item contract #5) — staging-dir fake resolve + fake tmux wrapper

z-window.sh does `. "$SCRIPT_DIR/lib/resolve.sh"` then `resolve "$query"`. To inject a
deterministic resolver **without** depending on the live zoxide DB (and without modifying the
real resolve.sh), the test builds a **staged plugin tree**:
- `$STAGE/scripts/z-window.sh` ← copy of the real handler (`SCRIPT_DIR` resolves to `$STAGE/scripts`).
- `$STAGE/scripts/lib/resolve.sh` ← a **FAKE** `resolve()` matching `proj`/`"my proj"` → `$PROJDIR`,
  else empty (always exit 0, honoring S4's contract).

The handler's bare `tmux` calls are routed to the isolated server via a **fake `tmux` wrapper**
on PATH: `exec "$REAL_TMUX" -L zxstest "$@"` (absolute `$REAL_TMUX` so the wrapper cannot recurse).
The test's own assertions use the real tmux directly (absolute path) against the same socket.

Assertions read the **newest window** by index and check `#{pane_current_path}` (cwd) and
`#{window_name}` (name) via `display-message -t "zs:$idx"`. **Case 5** additionally counts windows
before/after to prove **exactly one** window is created per invocation (item contract #4).

## 7. shellcheck: SC1091 is the one accepted info (dynamic source path)

`shellcheck scripts/z-window.sh` flags **SC1091 (info)** on `. "$SCRIPT_DIR/lib/resolve.sh"`
(can't follow a dynamically-computed source path). This is **unavoidable for any script that
sources a computed path** and is benign (the S-series resolve.sh avoided it only because it
sources inside `sh -c '...'` strings). To keep the handler **PRD-verbatim** (no shellcheck
directive added), the gate uses `shellcheck --exclude=SC1091 scripts/z-window.sh` → exit 0, no
output. The test file sources via `sh -c`/heredoc staging, so it needs no exclusion (clean).

## 8. Empirical results (final, validated)

```
$ shellcheck --exclude=SC1091 scripts/z-window.sh && echo OK     # exit 0, no output -> OK
$ shellcheck tests/test_z_window.sh && echo OK                   # exit 0, no output -> OK
$ sh tests/test_z_window.sh                                      # run 5x, identical:
RESULTS: pass=9 fail=0                                           # exit 0, EMPTY stderr
```

Case matrix:
| # | Input | Expected new-window cwd | Expected name | Result |
|---|-------|------------------------|---------------|--------|
| 1 | `""` (empty) | current pane dir | basename(cur) | PASS |
| 2 | `proj` (match) | resolved dir ($PROJDIR) | basename(resolved) | PASS |
| 3 | `zzz_nomatch_xyz` (no-match) | current pane dir (fallback) | basename(cur) | PASS |
| 4 | `my proj` (2 args → `"$*"`) | resolved dir (recombined match) | basename(resolved) | PASS |
| 5 | `proj` (count) | window delta == 1 | — | PASS |

(cases 1–4 each also assert the **name**; case 5 asserts the single-window count.)

## 9. Composition with S4 (parallel) + downstream

- z-window.sh **sources** `scripts/lib/resolve.sh` and calls `resolve "$query"`. `resolve()`
  (the public entry point) is owned by **P1.M1.T2.S4** (implementing in parallel). The production
  handler depends on S4's `resolve()` existing (guaranteed by S4's contract). The **test fakes**
  `resolve` (staging-dir), so it passes **independently** of S4's state — no coupling, no race
  with the parallel implementation.
- z-window.sh is **consumed by P1.M2.T2.S1** (the run file wires `prefix g` →
  `command-prompt -p "z to:"` → `run-shell '...z-window.sh %%'`). This subtask ships ONLY the
  handler + its test; the binding is P1.M2.T2.S1. No README/option changes here (item contract #6,
  Mode A: defaults `g`/`z to:` are owned by the run file, authored in P1.M4.T1).
