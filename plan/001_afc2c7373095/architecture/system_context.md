# System Context — tmux-zoxide-sessions

> Synthesized by the Lead Architect from research + on-machine empirical verification
> (tmux 3.6b, zoxide present, rupa/z present). Full raw briefs live alongside this file:
> `research_tmux_internals.md`, `research_resolver_backends.md`, `research_plugin_ecosystem.md`.

## 1. What the system is

A **greenfield tmux plugin** (one TPM release, v1.0) that adds two zoxide-powered
features. The repo is currently empty (only `PRD.md`, empty `docs/`, and this
`plan/` dir exist). The PRD ships the **complete verbatim implementation** in §5 —
the build is a faithful transcription + the validated corrections in
`findings_and_risks.md`.

### Feature A — Window jump (manual)
`prefix <key>` (default `g`) → `command-prompt` → typed query → resolve via shared
backend → `new-window -c <resolved> -n <basename>`. Empty/no-match → open in the
current pane's path (matches plain `new-window -c "#{pane_current_path}"`).

### Feature B — Session auto-relocate (automatic, default ON)
A global `session-created` hook (backgrounded via `run-shell -b`) relocates the
**first pane** of any new session that "landed in `$HOME`" to the zoxide-resolved
dir matching its name, using `respawn-pane -c <resolved> -k`.

The discriminator is precise and safe: resurrect/continuum restore sessions with
`-c "$saved_dir"` (NEVER `$HOME`), sessionx/sesh place via `-c <resolved>`, so the
only sessions at `$HOME` are bare/unresolved creations — exactly the target.

## 2. File responsibilities (PRD §5.1)

| File | Role | Shebang | Exec |
|---|---|---|---|
| `tmux-zoxide-sessions.tmux` | **Run file** (TPM executes it once at init). Wires the key binding + the session hook. Sources `resolve.sh` for `get_tmux_option`. | `#!/usr/bin/env bash` | yes |
| `scripts/lib/resolve.sh` | **Shared library** (sourced, not exec). `get_tmux_option` + 3 resolver backends + `resolve()` dispatcher. | `#!/bin/sh` | n/a (sourced) |
| `scripts/z-window.sh` | Window-jump handler (`run-shell` target of the key binding). | `#!/bin/sh` | yes |
| `scripts/z-session.sh` | `session-created` handler (the guard chain). | `#!/bin/sh` | yes |
| `README.md` | Install, usage, full options table, backends, scope/compat, known limits. | — | — |
| `LICENSE` | MIT, "Copyright (c) 2026 Dustin Schultz". | — | — |

## 3. Data flow

```
                       ┌──────────────── scripts/lib/resolve.sh ────────────────┐
                       │  get_tmux_option()  _resolve_zoxide()  _resolve_z()      │
                       │                    resolve()  (dispatcher, always exit 0) │
                       └───────────────▲───────────────────▲───────────────────────┘
                                       │ source             │ source
   prefix g ─► command-prompt ─► z-window.sh ──► resolve() ─► new-window -c -n
   (tmux-zoxide-sessions.tmux bind-key)        │
                                                └─ empty/no-match ─► new-window -c <cur path>

   tmux new -s X ─► [session-created hook] ─► z-session.sh "$X" (run-shell -b)
        │                                        │ guard chain (toggle/name/skip/pane/path/home)
        └─ if pane cwd == $HOME & resolvable ───► resolve() ─► respawn-pane -c <resolved> -k
                                                    └─ optional rename-window (if @...-window-name=session)
```

## 4. The 8 user options (PRD §4) — contract for README + tests

| Option | Default | Consumed by |
|---|---|---|
| `@zoxide-sessions-key` | `g` | run file (bind) |
| `@zoxide-sessions-prompt` | `z to:` | run file (command-prompt) |
| `@zoxide-sessions-backend` | `auto` | resolve() dispatcher |
| `@zoxide-sessions-z-sh` | unset | _resolve_z() |
| `@zoxide-sessions-auto-session` | `on` | run file (hook gate) + z-session.sh (master toggle) |
| `@zoxide-sessions-home-dir` | `$HOME` | z-session.sh (normalize+compare) |
| `@zoxide-sessions-skip-names` | `home main` | z-session.sh (whitelist loop) |
| `@zoxide-sessions-window-name` | `off` | z-session.sh (rename branch) |

## 5. Environment facts (verified on this machine)

- tmux **3.6b** — satisfies PRD's "3.0+" floor (the true functional minimum is
  ~2.2 for `set-hook`; 3.0 is a conservative margin — see `research_tmux_internals.md` §8).
- `zoxide` at `/home/dustin/.local/bin/zoxide`; index is populated (`zoxide query --list` non-empty).
- rupa/z present: `~/.z` data file + `/home/dustin/.config/znap/rupa/z/z.sh`.
- GNU `readlink -f` works (path canonicalization in `_norm` is safe here).
- `/bin/sh` is dash-compatible; PRD scripts avoid `local`/`[[ ]]`/arrays/`echo -e` → genuinely POSIX.

## 6. Key empirical confirmations (see findings_and_risks.md for details + the 2 corrections)

- ✅ `session-created` fires AFTER session+window+pane exist; `#{session_name}`,
  `#{pane_id}`, `#{pane_current_path}` all resolve to the NEW session at dispatch time.
- ✅ `run-shell -b` expands formats at dispatch (before the async fork) → no race reading pane path.
- ✅ `respawn-pane -c <dir> -k` sets cwd, kills old shell, **preserves window name + geometry**.
- ✅ resurrect `restore.sh` uses `new-session -d -s "$name" -c "$saved_dir"` (linchpin confirmed from source).
- ✅ `zoxide query` returns exit **0** + empty stdout on no-match (empirical; the contract "callers
  check output, not status" holds regardless).
- ✅ `%%` substitution is textual; the window feature still handles spaced queries because
  `z-window.sh` does `query="$*"` (recombines split args).
- 🔴 **BUG (rupa/z):** the PRD `_z` pattern returns the starting cwd on no-match (false positive). FIX validated.
- 🟡 `set-hook -g` (PRD's choice) OVERWRITES a pre-existing global hook — reload-idempotent but
  does not literally "compose" (§6.2 wording nuance). Keep `-g` for reload-safety; document the tradeoff.
