# PRD + Technical Spec — tmux-zoxide-sessions (greenfield)

**Status:** Ready for implementation. This document is the **complete** specification.
A developer agent must be able to rebuild the entire plugin from this file alone —
no other source, no prior files, no external references. Every file's full content is
given verbatim in §5.

---

## 0. How to use this document

1. Create the files listed in §5.1 at the exact paths shown, with the exact contents in §5.2–§5.7.
2. Make `tmux-zoxide-sessions.tmux` and the two scripts in `scripts/` executable (`chmod +x`).
3. Load via TPM (see §6.1) or `run-shell`.
4. Verify against the test matrix in §7.

The plugin has **two features**, both delivered by this spec:
- **Window jump** (manual): `prefix g` opens a new window in a zoxide-resolved directory.
- **Session auto-relocate** (automatic, default on): a `session-created` hook moves any
  new session that "landed in `$HOME`" to the zoxide-resolved directory matching its name.

---

## 1. Overview & rationale

### The window feature
`new-window -c` needs a literal path. zoxide ranks every directory you visit by frecency,
so a short query (`tmux`, `proj`) lands in the right place without typing or copying a path.

### The session feature — and why a hook is reliable here
Session managers (sessionx, sesh) only zoxide-resolve sessions created *through them*.
Sessions created by any other path — `tmux new -s foo`, `prefix :` `new-session`,
`ssh host; tmux new -s bar` — default to `$HOME` and are never zoxide-enhanced. This
plugin is a **safety net** for those.

The `$HOME` guard is a clean discriminator **because resurrect/continuum create restored
sessions with `-c "$saved_dir"`** (verified in `tmux-resurrect/scripts/restore.sh`):

```sh
new-session -d -s "$session_name" -c "$dir"
```

So restored sessions land at their *saved* dir, **never `$HOME`**, and are skipped. The
only sessions that land at `$HOME` are bare/unresolved creations — exactly the target.
**No startup-grace or timing logic is required.** The signal "session landed in `$HOME`,
with a name that isn't whitelisted, that zoxide can resolve" is precise and safe.

---

## 2. Goals & non-goals

### In scope
- Window-jump key binding (zoxide-resolved `new-window`).
- `session-created` hook that zoxide-resolves the session name and relocates the first pane.
- Shared frecency resolver library (zoxide / rupa-z / auto), used by both features.
- Full configurability via tmux options.

### Non-goals (explicitly out of scope)
- A window-level auto-hook (windows lack a natural name/query).
- A session picker / fzf UI (that is sessionx/sesh's job).
- Switching clients on creation.
- Replacing sessionx; this **complements** it.
- Intercepting/rewriting `new-session -c` (impossible — tmux hooks are post-hoc).

---

## 3. Behavior

### 3.1 Window jump (manual)
On `prefix <key>` (default `g`), tmux opens a `command-prompt` labeled with `@zoxide-sessions-prompt`
(default `z to:`). The entered text is passed to `z-window.sh`:
- With a query → resolve via the shared backend → `new-window -c <resolved> -n <basename>`.
- No query / no match → `new-window -c <current pane path> -n <basename>` (matches plain `new-window -c "#{pane_current_path}"`).

### 3.2 Session auto-relocate (automatic) — the guard chain
On `session-created` (backgrounded), `z-session.sh` receives the session name as `$1` and runs:

1. If `@zoxide-sessions-auto-session` is `off` → exit.
2. `name = $1`. If empty → exit.
3. If `name` is in `@zoxide-sessions-skip-names` (default `home main`) → exit.
4. `pane = display-message -t "$name" -p '#{pane_id}'`. If empty → exit. *(At creation the session has one pane; its active pane is it.)*
5. `path = display-message -t "$pane" -p '#{pane_current_path}'`.
6. `home = @zoxide-sessions-home-dir` (default `$HOME`).
7. **Normalize** `path` and `home` (symlinks via `readlink -f`, collapse trailing `/`) and compare. If `path != home` → **exit**. *(Excludes all restored / sessionx / sesh / project-dir-originated sessions.)*
8. `resolved = resolve "$name"` (shared backend). If empty → exit.
9. `respawn-pane -t "$pane" -c "$resolved" -k`.
10. If `@zoxide-sessions-window-name == session`: rename the first window to `name`.
11. Exit 0.

Every tmux call is guarded `2>/dev/null || exit 0` so a missing pane/option never propagates an error.

**Relocate mechanism:** `respawn-pane -c <resolved> -k` restarts the first pane's shell in the
resolved dir; `-k` kills the just-started `$HOME` shell. There is an inherent, unavoidable
flicker (the pane must exist before it can be respawned) — see §8.

---

## 4. Options reference

Set with `set -g` before the TPM init / `run-shell` line.

| Option | Default | Purpose |
| --- | --- | --- |
| `@zoxide-sessions-key` | `g` | Window-jump binding key (after prefix). |
| `@zoxide-sessions-prompt` | `z to:` | Label shown by `command-prompt`. |
| `@zoxide-sessions-backend` | `auto` | Resolver: `auto` \| `zoxide` \| `z`. |
| `@zoxide-sessions-z-sh` | unset | Path to rupa/z `z.sh` (for `z` and `auto` backends). |
| `@zoxide-sessions-auto-session` | `on` | Master toggle for the session hook. `on` \| `off`. |
| `@zoxide-sessions-home-dir` | `$HOME` | Dir treated as "bare/default"; sessions here are relocate candidates. |
| `@zoxide-sessions-skip-names` | `home main` | Whitespace-separated names never relocated. |
| `@zoxide-sessions-window-name` | `off` | After relocate, rename first window: `off` \| `session`. |

**Backends** (shared by both features):
- `zoxide` → `zoxide query <query>` (needs the `zoxide` binary on `$PATH`).
- `z` → rupa/z `_z` via `@zoxide-sessions-z-sh` (zsh if available, else sh).
- `auto` (default) → zoxide if present, then rupa/z as fallback. Works on machines without zoxide.

> The resolver returns empty on no match and always exits 0; callers check output, not status.

---

## 5. Complete implementation

### 5.1 File tree
```
tmux-zoxide-sessions/
  tmux-zoxide-sessions.tmux     # run file: window binding + session hook
  scripts/
    lib/
      resolve.sh                # shared frecency resolver + get_tmux_option
    z-window.sh                 # window-jump handler
    z-session.sh                # session-created handler
  README.md
  LICENSE
```

### 5.2 `tmux-zoxide-sessions.tmux`
```bash
#!/usr/bin/env bash
# tmux-zoxide-sessions: run file (loaded by TPM or a plain run-shell line).
#
# Wires two features:
#   1. A key binding that opens a new window in a zoxide-resolved directory.
#   2. (default on) A session-created hook that relocates a new session from
#      $HOME to the zoxide-resolved directory matching its name. See PRD.md §3.2.

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$CURRENT_DIR/scripts/lib/resolve.sh"

# --- 1. Window-jump binding ---------------------------------------------------
key=$(get_tmux_option "@zoxide-sessions-key" "g")
prompt=$(get_tmux_option "@zoxide-sessions-prompt" "z to:")

tmux bind-key "$key" \
    command-prompt -p "$prompt" \
    "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"

# --- 2. Session auto-relocate hook -------------------------------------------
# Relocates a newly-created session's first pane from $HOME to the
# zoxide-resolved directory matching its name.
auto_session=$(get_tmux_option "@zoxide-sessions-auto-session" "on")
if [ "$auto_session" != "off" ]; then
    SESSION_SCRIPT="$CURRENT_DIR/scripts/z-session.sh"
    # Quoting mirrors tmux-session-history's proven hooks: the stored command
    # is `run-shell -b "/abs/path/z-session.sh \"#{session_name}\""`, passing
    # the (possibly spaced) session name through as a single $1.
    tmux set-hook -g session-created \
        "run-shell -b '${SESSION_SCRIPT} \"#{session_name}\"'"
fi
```

### 5.3 `scripts/lib/resolve.sh`
```sh
#!/bin/sh
# lib/resolve.sh — shared helpers for tmux-zoxide-sessions.
# Sourced by the run file, scripts/z-window.sh, and scripts/z-session.sh.

# get_tmux_option <name> <default> -> option value, or default if unset/empty.
get_tmux_option() {
    _v=$(tmux show-option -gqv "$1" 2>/dev/null)
    [ -n "$_v" ] && echo "$_v" || echo "$2"
}

# _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query "$1" 2>/dev/null
}

# _resolve_z <query> -> dir from rupa/z (_z), or empty.
_resolve_z() {
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    [ -n "$z_sh" ] && [ -r "$z_sh" ] || return 0
    # rupa/z is a shell function: source z.sh and call _z.
    shell=sh; command -v zsh >/dev/null 2>&1 && shell=zsh
    "$shell" -c '. "$1"; _z "$2" >/dev/null 2>&1; pwd' _ "$z_sh" "$1" 2>/dev/null
}

# resolve <query> -> best frecency-match directory (empty if no match).
# Always exits 0 — callers must check the output, not the exit status.
# Backend selected by @zoxide-sessions-backend (default "auto"):
#   zoxide -> zoxide only
#   z      -> rupa/z only
#   auto   -> zoxide if present, then rupa/z as fallback
resolve() {
    backend=$(get_tmux_option "@zoxide-sessions-backend" "auto")
    case "$backend" in
        zoxide) _resolve_zoxide "$1" ;;
        z)      _resolve_z "$1" ;;
        auto)
            _r=$(_resolve_zoxide "$1")
            [ -z "$_r" ] && _r=$(_resolve_z "$1")
            printf '%s\n' "$_r"
            ;;
    esac
}
```

### 5.4 `scripts/z-window.sh`
```sh
#!/bin/sh
# Open a new tmux window in the current session, in a zoxide-frecency-matched
# directory.
#
# Usage: z-window.sh [query ...]
#
# With a query, resolve it to its best frecency match and open the window
# there, named after the directory basename. The query is a zoxide query, not
# a literal window name.
#
# With no query, or when no match is found, open the window in the current
# pane's directory and name it after that. This matches a plain
# `new-window -c "#{pane_current_path}"`.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/resolve.sh"

query="$*"

# Pull the current pane's directory and session from the live tmux server.
cur=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
[ -z "$cur" ] && cur="$HOME"
session=$(tmux display-message -p '#{session_name}' 2>/dev/null)

dir="$cur"

if [ -n "$query" ]; then
    resolved=$(resolve "$query")
    [ -n "$resolved" ] && dir="$resolved"
fi

base=$(basename "$dir")
tmux new-window -t "$session:" -c "$dir" -n "$base"
```

### 5.5 `scripts/z-session.sh`
```sh
#!/bin/sh
# z-session.sh — session-created handler for tmux-zoxide-sessions.
#
# Relocates the first pane of a newly-created session from $HOME to the
# zoxide-resolved directory matching the session name. Acts ONLY when the
# session landed in $HOME with a resolvable, non-whitelisted name — so
# sessions placed by resurrect/continuum, sessionx/sesh, or created from a
# project directory are left untouched. See PRD.md §3.2 for the rationale.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/resolve.sh"

# Master toggle.
[ "$(get_tmux_option "@zoxide-sessions-auto-session" "on")" = "off" ] && exit 0

name="$1"
[ -n "$name" ] || exit 0

# Whitelist of names that legitimately live in $HOME.
skip_names="$(get_tmux_option "@zoxide-sessions-skip-names" "home main")"
for s in $skip_names; do
    [ "$s" = "$name" ] && exit 0
done

# Locate the session's first pane (the only pane at creation time).
pane=$(tmux display-message -t "$name" -p '#{pane_id}' 2>/dev/null) || exit 0
[ -n "$pane" ] || exit 0

path=$(tmux display-message -t "$pane" -p '#{pane_current_path}' 2>/dev/null) || exit 0
[ -n "$path" ] || exit 0

# The "home" directory where bare/unresolved sessions land.
home_dir="$(get_tmux_option "@zoxide-sessions-home-dir" "$HOME")"
[ -n "$home_dir" ] || home_dir="$HOME"

# Normalize both for comparison (resolve symlinks, collapse trailing slashes).
_norm() {
    _p=$(readlink -f "$1" 2>/dev/null || printf '%s' "$1")
    printf '%s/' "$_p" | sed 's#//*#/#g'
}
[ "$(_norm "$path")" = "$(_norm "$home_dir")" ] || exit 0

# Resolve the name via the shared backend. Empty = no match -> nothing to do.
resolved=$(resolve "$name") || exit 0
[ -n "$resolved" ] || exit 0

# Relocate: restart the pane's shell in the resolved directory.
tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0

# Optional: rename the first window to the session name.
case "$(get_tmux_option "@zoxide-sessions-window-name" "off")" in
    session)
        win=$(tmux display-message -t "$pane" -p '#{window_id}' 2>/dev/null)
        [ -n "$win" ] && tmux rename-window -t "$win" "$name" 2>/dev/null
        ;;
esac

exit 0
```

### 5.6 `README.md`
```markdown
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

## Scope & compatibility
- Requires **tmux 3.0+** (`session-created` hook, `respawn-pane -c`).
- The session hook composes with resurrect/continuum (restored via `-c`, skipped),
  sessionx/sesh (placed via `-c`, skipped), and any user `session-created` hooks.
- This is not a session picker/switcher; use sessionx/sesh for browsing.

## Known limitations
- Relocation uses `respawn-pane -k`, so there is a brief flicker as the first
  pane restarts in the new directory (unavoidable — tmux permits no pre-creation
  interception).
- `skip-names` is whitespace-separated, so entries cannot contain spaces.
- `home-dir` is a single directory, not a list.

## License
MIT
```

### 5.7 `LICENSE`
```
MIT License

Copyright (c) 2026 Dustin Schultz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 6. Compatibility & loading

### 6.1 Loading (TPM)
```
set -g @plugin 'dabstractor/tmux-zoxide-sessions'
```
TPM runs `tmux-zoxide-sessions.tmux`, which registers the window binding and
(unless `@zoxide-sessions-auto-session` is `off`) the `session-created` hook.

### 6.2 Coexistence
- **resurrect / continuum** — create with `-c "$saved_dir"` → never at `$HOME` → skipped.
- **sessionx / sesh** — place via `-c` with a resolved dir → skipped (when zoxide is healthy).
- **A user's own `session-created` hooks** — compose fine; `respawn-pane` preserves window names, so an external `rename-window` hook is unaffected.

### 6.3 Requirements
- tmux 3.0+ (3.6b verified).
- One resolver backend available: real `zoxide`, a `zoxide` shim, or rupa/z via `@zoxide-sessions-z-sh`.

---

## 7. Test / verification matrix

Run each from a shell at `$HOME` unless noted; record the outcome. `ZQ` = `zoxide query <name>`.

| # | Setup | Expected | Checks |
|---|---|---|---|
| 1 | `tmux new -d -s <resolvable>` | first pane cwd == `$ZQ` | relocate fires |
| 2 | `tmux new -d -s main` | stays at `$HOME` | skip-list |
| 3 | `tmux new -d -s zzznope` | stays at `$HOME` | no zoxide match |
| 4 | `cd /some/project; tmux new -d -s foo` | stays at `/some/project` | not-`$HOME` skip |
| 5 | sessionx create (zoxide mode on) | lands in resolved dir; hook does **not** relocate | sessionx coexistence |
| 6 | `@zoxide-sessions-auto-session off`, then #1 | no relocate | master toggle |
| 7 | `@zoxide-sessions-window-name session`, then #1 | first window named `<name>` | window-name option |
| 8 | `prefix g` → type a query | opens zoxide-resolved window | window feature |
| 9 | `tmux new -d -s "two words"` (if resolvable) | relocates; `$1` received intact | spaced names |
| 10 | resurrect restore (continuum restart) | restored sessions keep saved dirs | restore safety |

**Read a pane's cwd:**
```sh
tmux display-message -t "<session>:1.0" -p '#{pane_current_path}'   # adjust for base-index
```
For test 9, confirm `$1` arrives intact by temporarily prefixing `z-session.sh` with
`echo "$(date) name=[$1]" >> /tmp/zxs.log`, then removing the probe.
For test 10, log `path`/`resolved` to confirm restored sessions hit the `path != home` exit
and never call `respawn-pane`.

**Post-registration verification (do once):**
- `tmux show-hooks -g session-created` prints `run-shell -b "/<abs>/z-session.sh \"#{session_name}\""`.

---

## 8. Known limitations
- **Relocate flicker** — `respawn-pane -k` restarts the first pane; a brief flash of the `$HOME` shell is unavoidable without pre-creation interception (which tmux does not permit).
- **`skip-names`** is whitespace-separated → entries cannot contain spaces.
- **`home-dir`** is a single directory, not a list.
- **`readlink -f`** is GNU; on systems without it, symlinked `$HOME` may not canonicalize (falls back to literal path comparison — trailing-slash still normalized).

---

## 9. Acceptance criteria
- [ ] All 6 files exist at the paths in §5.1 with the contents in §5.2–§5.7; scripts and run file are executable.
- [ ] All 10 test-matrix cases pass.
- [ ] `tmux show-hooks -g session-created` shows the correct absolute path + `\"#{session_name}\"` form (only when `auto-session != off`).
- [ ] `z-window.sh` and `z-session.sh` share `lib/resolve.sh`; no duplicated resolver logic.
- [ ] Both features work with real `zoxide`, a `zoxide` shim, and rupa/z (`z` backend).
- [ ] README documents every option and the `$HOME`-guard model.
