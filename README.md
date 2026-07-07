# tmux-zoxide-sessions

Two zoxide-powered features for tmux:

1. **Window jump** — press `prefix g`, type a query, get a new window in the
   directory zoxide resolves for that query (named after the dir basename).
2. **Session auto-relocate** — any new session that lands in `$HOME` is
   automatically moved to the zoxide-resolved directory matching its name.

Built for tmux users who keep a frecency index with [zoxide](https://github.com/ajeetdsouza/zoxide)
or rupa/z.

## Why

`new-window -c` and `new-session -c` need literal paths. zoxide (and rupa/z)
already rank every directory you visit by frecency, so a short query such as
`tmux` or `proj` lands in the right place without typing or copying a path.

The session feature fills a gap: session managers like tmux-sessionx and sesh
only zoxide-resolve sessions created *through them*. Sessions created any other
way (`tmux new -s foo`, `prefix :` `new-session`, ssh-then-tmux) default to
`$HOME`. This plugin catches those.

## Install

### With TPM

Add this line before the [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) init:

```
set -g @plugin 'dabstractor/tmux-zoxide-sessions'
```

Reload tmux and press `prefix + I`.

### Manual

```
git clone https://github.com/dabstractor/tmux-zoxide-sessions \
  ~/.config/tmux/plugins/tmux-zoxide-sessions
```

```
run-shell ~/.config/tmux/plugins/tmux-zoxide-sessions/tmux-zoxide-sessions.tmux
```

```
tmux source ~/.tmux.conf
```

zoxide must be installed and its shell hook active for the `zoxide`/`auto`
backends; or set `@zoxide-sessions-z-sh` to a rupa/z `z.sh` for the `z` backend.
With no populated index, window queries fall back to the current directory and
session relocate is a no-op.

## Usage

### Window jump
Press `prefix + g` (default), type a query, press Enter:

```
z to: tmux
```

A window opens in the current session, in zoxide's best match for `tmux`, named
after the directory basename. An empty query or a no-match opens the window in
the current pane's directory (same as `new-window -c "#{pane_current_path}"`).

### Session auto-relocate
On by default. Create a session from `$HOME` with a name zoxide knows:

```
tmux new -s sellario
```

The session's first pane moves from `$HOME` to `zoxide query sellario`. Sessions
named in the skip-list (`home`, `main` by default), or whose name doesn't
resolve, are left at `$HOME`.

This is safe alongside resurrect/continuum, sessionx, and sesh: those place
sessions with an explicit directory, so they never land in `$HOME` and are never
touched.

## Options

Set with `set -g` before the TPM init (or `run-shell`) line.

| Option | Default | Purpose |
| --- | --- | --- |
| `@zoxide-sessions-key` | `g` | Window-jump key (after prefix). |
| `@zoxide-sessions-prompt` | `z to:` | `command-prompt` label. |
| `@zoxide-sessions-backend` | `auto` | Resolver: `auto`, `zoxide`, or `z`. |
| `@zoxide-sessions-z-sh` | unset | Path to rupa/z `z.sh`. |
| `@zoxide-sessions-auto-session` | `on` | Session hook master toggle. |
| `@zoxide-sessions-home-dir` | `$HOME` | Dir treated as the "bare/default" landing dir. |
| `@zoxide-sessions-skip-names` | `home main` | Names never relocated (whitespace-separated). |
| `@zoxide-sessions-window-name` | `off` | Rename first window after relocate: `off` or `session`. |

Example:

```
set -g @zoxide-sessions-key 'Z'
set -g @zoxide-sessions-window-name 'session'
```

### Backends
- `zoxide` runs `zoxide query <query>`. Needs the `zoxide` binary on `$PATH`.
- `z` sources a rupa/z `z.sh` (set via `@zoxide-sessions-z-sh`) and calls `_z`.
  Uses zsh when available, otherwise sh.
- `auto` (default) uses zoxide when present, then rupa/z when a `z.sh` path is
  set. Keeps working on machines without zoxide.

All three backends return an empty result (and exit 0) when a query has
no match; callers check the output, never the exit status. (The `z` backend
achieves this by comparing the working directory before and after calling
rupa/z's `_z`, which changes directory only on a match.) An empty result
means a window-jump query falls back to the current pane's directory and
session relocate is a no-op.

## Scope & compatibility
- Requires **tmux 3.0+** (`session-created` hook, `respawn-pane -c`).
- The session hook composes with resurrect/continuum (restored via `-c`, skipped)
  and sessionx/sesh (placed via `-c`, skipped). It registers globally with
  `set-hook -g`, which is **reload-safe** — re-running `prefix r` or a TPM
  re-source does not stack duplicate hooks. Because `set-hook -g` *replaces*
  any pre-existing global `session-created` hook, a hook set *before* the TPM
  init line is overwritten. To combine the plugin with your own
  `session-created` logic, set your hook **after** the TPM init line and have it
  also invoke `scripts/z-session.sh "#{session_name}"`, or append instead of
  replace with `set-hook -ag session-created "..."`.
- This is not a session picker/switcher; use sessionx/sesh for browsing.

## Known limitations
- Relocation uses `respawn-pane -k`, so there is a brief flicker as the first
  pane restarts in the new directory (unavoidable — tmux permits no pre-creation
  interception).
- `skip-names` is whitespace-separated, so entries cannot contain spaces.
- `home-dir` is a single directory, not a list.

## License
MIT
