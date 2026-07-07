# External Dependencies & Compatibility — tmux-zoxide-sessions

> Derived from `research_plugin_ecosystem.md` (primary-source quotes) +
> `research_resolver_backends.md` + on-machine verification.

## 1. Hard runtime dependencies

| Dependency | Why | How detected |
|---|---|---|
| **tmux ≥ 3.0** (3.6b verified) | `session-created` hook, `respawn-pane -c`, `display-message -p`, `set-hook -g/-ag`, `command-prompt %%`. True functional floor ~2.2; 3.0 is a conservative margin. | `tmux -V` |
| **A resolver backend** (one of:) | frecency → directory resolution | — |
| ↳ `zoxide` binary on `$PATH` | `zoxide query <q>` | `command -v zoxide` |
| ↳ rupa/z `z.sh` (path set via `@zoxide-sessions-z-sh`) | `_z` shell function | `[ -r "$z_sh" ]` |
| ↳ a `zoxide` shim | for test harnesses | `command -v zoxide` |

> With no backend / empty index: window queries fall back to the current pane dir;
> session relocate is a no-op (resolve returns empty). The plugin degrades safely.

## 2. TPM loading contract (PRD §6.1) — confirmed from TPM source

TPM's `scripts/source_plugins.sh` → `silently_source_all_tmux_files()` globs
`$plugin_path*.tmux` and **executes** each match with output suppressed
(`$tmux_file >/dev/null 2>&1`). Implications:
- The run file **must** sit at repo root, be `chmod +x`, and have a valid shebang.
  (The executable bit must be **committed** — `git update-index --chmod=+x` — or it is
  lost on clone and TPM silently no-ops it.)
- The run file must not rely on stdout (it is discarded); user notices go via
  `tmux display-message`.
- It runs **once per TPM init / reload**. Reload re-runs it → why the hook must be
  set with `set-hook -g` (idempotent overwrite), NOT `set-hook -ag` (would duplicate
  on every reload). See `findings_and_risks.md` §B.

`get_tmux_option()` (the `tmux show-option -gqv` helper) is the universal tmux-plugins
idiom — found byte-identical in TPM, tmux-resurrect, tmux-continuum. `show-option -gqv`
returns empty + exit 0 for an unset `@`-option, so the default-arg pattern is correct.
It is interpreter-agnostic; the POSIX `sh` rewrite (no `local`) is valid.

## 3. The linchpin: coexistence with resurrect / continuum (PRD §1, §6.2) — CONFIRMED

The **entire** safety model rests on: restored sessions land at their SAVED cwd, never
`$HOME`. Verified from primary source.

`tmux-resurrect/scripts/restore.sh` → `new_session()`:
```bash
TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -c "$dir"
```
(both the pane-contents and plain branches). `$dir` is parsed from the save file's
`pane` line, whose `dir` field is the pane's live `#{pane_current_path}` at save time
(`save.sh` `pane_format()` → `format+=":#{pane_current_path}"`).

→ Restored sessions inherit their saved cwd. The only way one lands at `$HOME` is if the
saved pane's cwd *was* `$HOME` (acceptable false-positive; document it).

**tmux-continuum** auto-restore does NOT re-implement restore — `continuum_restore.sh`
looks up `@resurrect-restore-script-path` and runs resurrect's `restore.sh` (after a
`sleep 1`). So the same `-c "$saved_dir"` guarantee extends to server-startup restore.
`@continuum-restore` defaults to `off`.

## 4. Coexistence with sessionx / sesh (PRD §6.2) — plausible, design-robust

tmux-sessionx (`omerxx/tmux-sessionx`) and sesh (`joshmedeski/sesh`) both resolve a
directory (zoxide-backed) and create sessions via `tmux new-session -d -s <name> -c <resolved>`.
→ Sessions they create do not start at `$HOME`, so the `path == $HOME` guard skips them.
Not byte-verified from source in this pass, but **irrelevant to correctness**: the design
keys off observed `pane_current_path`, not tool identity. If a tool ever omits `-c`, the
fallback still works (and arguably relocating is desirable).

## 5. POSIX sh portability posture

The PRD's helper scripts use `#!/bin/sh` and the `resolve.sh` lib avoids `local`, `[[ ]]`,
arrays, `==` inside `[ ]`, `read -ra`, `${var//x/y}`, and `echo -e` → genuinely POSIX,
runs under dash/ash/mksh/bash. The run file uses `#!/usr/bin/env bash` (matches TPM
convention; uses `${BASH_SOURCE[0]}`).

## 6. Testing strategy guidance (for implementing agents)

- **Resolver unit tests (pure):** inject a fake `tmux` (PATH shim returning canned
  `show-option -gqv` output) + a fake `zoxide`/`z.sh` fixture; assert `resolve()` output
  and that it **always exits 0**.
- **z-window / z-session integration tests:** drive an **isolated** tmux server
  (`tmux -L zxs-test ...`) so the user's live tmux is never touched; use a `zoxide` shim
  or the real index; assert via `display-message -p '#{pane_current_path}'`.
- **Acceptance:** automate as much of PRD §7 (10-case matrix) as feasible; the rest is
  manual-verify with the exact read-pane-cwd snippet in §7.
