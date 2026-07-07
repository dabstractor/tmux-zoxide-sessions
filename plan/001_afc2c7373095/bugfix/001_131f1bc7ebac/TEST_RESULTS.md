# Bug Fix Requirements

## Overview

Tested the shipped `tmux-zoxide-sessions` v1.0 end-to-end against the PRD scope,
acting as a creative/adversarial QA engineer. All testing was done on isolated
tmux 3.6b servers (`tmux -L <sock>`) with the user's live tmux untouched; both
real `zoxide` (0.9.x, on `$PATH`) and real rupa/z (`/home/dustin/.config/znap/rupa/z/z.sh`)
were exercised, plus the project's own 9-file test suite.

**Overall quality: solid core, one real Major regression.** The primary user
journeys work: the window jump resolves normal queries and opens the right
window; the session auto-relocate fires on `$HOME`-landed resolvable sessions
and correctly skips skip-list / no-match / not-`$HOME` / master-off cases; all
three backends resolve; the `set-hook -g` form registers exactly as PRD §9
requires. The shipped test suite passes (77/77 assertions across 9 files).

However, creative input testing surfaced **one Major bug** (zoxide flag
absorption that corrupts the window-jump output, affecting the *default*
backend) and **one Minor bug** (single-quote queries break resolution). The
Major bug was introduced by the most recent commit, which removed a
contract-required safety guard on a factually false rationale, and the test
suite could not catch it because the fake-zoxide test fixture does not model
real zoxide's flag parsing.

---

## Critical Issues (Must Fix)

None. Core functionality (window jump for normal queries, session relocate,
all three backends, the full guard chain) works as specified.

---

## Major Issues (Should Fix)

### Issue 1: zoxide flag absorption — `-l` / `--list` queries dump the entire frecency database into a corrupted window

**Severity**: Major

**PRD Reference**: §4 ("The resolver returns empty on no match and always
exits 0"), §3.1 (window jump: no-match must fall back to the current pane
path), §5.3 (`_resolve_zoxide`). Also contradicts the README "Backends"
contract and the implementation contract item **P1.M1.T2.S2 / NOTE D**, which
explicitly required an `--` end-of-options guard.

**Expected Behavior**: A window-jump query that is not a real directory match
must resolve to **empty**, and `z-window.sh` must fall back to opening the
window in the current pane's directory (PRD §3.1). The resolver must never
return a multi-line or non-path value.

**Actual Behavior**: `_resolve_zoxide` calls `zoxide query "$1"` with **no
`--` end-of-options guard** (`scripts/lib/resolve.sh:19`). For the queries
`-l` and `--list`, real zoxide enters **list mode** and prints the *entire*
frecency database (observed: 146–147 lines). That whole dump is returned as
the "resolved" directory. `z-window.sh` then runs:

```
tmux new-window -t "$session:" -c "$dir" -n "$base"
```

where `$dir` is the full multi-line database dump and `$base` is
`basename` of the dump (a random last-line entry, e.g. `jin-glm`). The result
is a window whose `pane_start_path` is the entire 146-line database crammed
into one field, named after an arbitrary directory — a visibly broken window.

This also violates the documented resolver contract (PRD §4: "returns empty
on no match") and breaks the `auto` backend's fallback design: because the
zoxide dump is non-empty, the `auto` dispatcher's `[ -z "$_r" ] && _r=$(_resolve_z ...)`
never invokes the rupa/z fallback, so the corrupted value is what ships.

**Scope of impact**: The **default** backend is affected. `auto` (default)
tries zoxide first; the dump short-circuits the rupa/z fallback. `zoxide`
backend is affected. Only systems whose sole backend is rupa/z (`z` backend
with no zoxide binary) are immune. Real zoxide is the primary support target
(PRD §6.3, §9), so this hits the common case.

**Steps to Reproduce** (real zoxide, isolated server):

```sh
cd <repo>
REAL_TMUX=/usr/bin/tmux; SOCK=bugrepro
TBIN=/tmp/bugbin; mkdir -p "$TBIN"
printf '#!/bin/sh\nexec "%s" -L "%s" "$@"\n' "$REAL_TMUX" "$SOCK" > "$TBIN/tmux"
chmod +x "$TBIN/tmux"
export PATH="$TBIN:$PATH"

"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
"$REAL_TMUX" -L "$SOCK" -f /dev/null new-session -d -s zs -c /tmp; sleep 0.3
# default 'auto' backend is in effect (option unset)

# Simulate: prefix g, then type "-l"
<repo>/scripts/z-window.sh -l

# Observe the newest window: name is a random basename, start_path is the
# ENTIRE zoxide database (100+ lines) instead of falling back to /tmp.
"$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index} name=[#{window_name}] start=[#{pane_start_path}]'
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null
```

Direct proof of the root cause:

```sh
zoxide query  "-l"     | wc -l   # -> 146+ (list-mode DB dump)  [BUG]
zoxide query "--list"  | wc -l   # -> 146+ (list-mode DB dump)  [BUG]
zoxide query -- "-l"             # -> empty (correct)           [the fix]
zoxide query -- "--list"         # -> empty (correct)           [the fix]
```

**Root cause / regression history**: The implementation contract (P1.M1.T2.S2,
NOTE D) required the `--` guard. Commit `eabce65`/`bb90152` added it
(`zoxide query -- "$1"`). Commit **`b93e776` "Remove zoxide -- end-of-options
guard and fix tautological test"** removed it, reverting to `zoxide query "$1"`.

The removal's stated rationale (`scripts/lib/resolve.sh:12-17`) is
**factually false**. The comment claims: *"zoxide already rejects a query that
begins with `-` safely (empty output + exit 0)"*. This is disproven above:
`-l`/`--list` return the full database, not empty. The comment also justifies
the removal by claiming `--` "breaks the rupa/z-backed zoxide shim (which does
not parse `--`)". There is no "rupa/z-backed zoxide shim" in the PRD — the
three backends are real `zoxide`, a user `zoxide` shim, and rupa/z via
`@zoxide-sessions-z-sh`. The "shim" that fails on `--` is the **test fixture**
in `tests/test_z_window.sh` / `tests/test_backend_matrix.sh`, whose fake
`zoxide` does a blind `shift` + `case "$1"`. That is a test artifact, not a
support target; a real or well-written shim honors `--` exactly as real
zoxide does (proven: `zoxide query -- foo` resolves correctly).

**Why the test suite missed it**: The fake-zoxide fixtures treat every
argument (including `-l`) as a plain query string and return empty, so they
never reproduce real zoxide's flag parsing. Subtest A of
`tests/test_backend_matrix.sh` *does* use real zoxide, but only ever queries a
probed normal token — never a leading-dash query — so the absorption path is
unexercised.

**Suggested Fix**:

1. Restore the guard in `scripts/lib/resolve.sh`:
   ```sh
   _resolve_zoxide() {
       command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
   }
   ```
   and delete/rewrite the false comment block at lines 12-17.
2. Harden `z-window.sh` against a non-directory / multi-line `resolved` so a
   future resolver regression cannot corrupt a window (defence in depth):
   after `resolved=$(resolve "$query")`, only accept it if it is a single line
   that is an existing directory, e.g.
   ```sh
   if [ -n "$query" ]; then
       resolved=$(resolve "$query")
       [ -n "$resolved" ] && [ -z "${resolved##*$'\n'*}" ] || { [ -d "$resolved" ] && dir="$resolved"; }
   fi
   ```
3. Fix the fake-`zoxide` test fixtures to (a) strip a leading `--` like real
   zoxide, and (b) model list-mode behavior for `-l`/`--list`, then add a
   regression case that queries `-l`/`--list` and asserts the resolver returns
   empty and the window falls back to the current pane path.

---

## Minor Issues (Nice to Fix)

### Issue 2: A single quote in a window-jump query breaks resolution

**Severity**: Minor

**PRD Reference**: §5.2 (the `bind-key` line, reproduced verbatim), §3.1
(window jump must resolve the typed query).

**Expected Behavior**: A query containing a single quote (e.g. a directory
like `o'brien` or `Mary's Project`) is delivered to `z-window.sh` as `$1` so
zoxide can resolve it.

**Actual Behavior**: The binding wraps the `%%` substitution in single quotes
(`tmux-zoxide-sessions.tmux:18`, verbatim from PRD §5.2):

```
"run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
```

When the user types a query containing `'`, the apostrophe terminates the
single-quoted argument prematurely. The query is **not delivered intact**.
Observed outcomes (depending on invocation path through tmux's parser):

- `tmux run-shell '.../z-window.sh o'brien'` → tmux reports
  `returned 2` and **no window is created**.
- via `tmux source-file` of the same expanded command → the query is
  **silently truncated to empty**, so a window opens in the *current*
  directory (named after the current dir) instead of the intended one.

In neither case does the user reach the zoxide-resolved directory.

**Steps to Reproduce**:

```sh
REAL_TMUX=/usr/bin/tmux; SOCK=apo; REPO=<repo>
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
"$REAL_TMUX" -L "$SOCK" -f /dev/null new-session -d -s zs -c /tmp; sleep 0.3
printf "run-shell '%s/scripts/z-window.sh o'\''brien'\n" "$REPO" > /tmp/apo.tmux
"$REAL_TMUX" -L "$SOCK" source-file /tmp/apo.tmux      # query lost; window opens at /tmp, not resolved
"$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index} name=[#{window_name}]'
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null
```

**Note**: This originates in PRD §5.2's literal quoting, so the shipped code
faithfully reproduces a spec-level limitation; the fix likely needs a
binding-level quoting change (e.g. have `z-window.sh` read the query through a
mechanism that does not embed raw user text inside single quotes, or escape
`'` → `'\''` in the substituted token).

**Suggested Fix**: Escape single quotes in the substituted prompt text before
it is placed inside the single-quoted `run-shell` argument, or restructure the
binding so the query is passed via an environment variable / tmux format that
preserves arbitrary characters.

---

## Testing Summary

- **Total tests performed**: ~45 distinct scenarios across happy-path,
  edge-case, adversarial, and integration categories (on top of the project's
  77-assertion automated suite, which was re-run and passes 77/77).
- **Passing**: All PRD §7 matrix cases (1-4, 6-10) verified working; both
  features with real zoxide, a zoxide shim, and rupa/z; the guard chain; the
  `set-hook -g` registration form; reload-idempotency; rupa/z no-match returns
  empty (Correction A holds); `resolve()` always exits 0 (Correction B holds).
- **Failing**: 2 issues found — 1 Major (Issue 1), 1 Minor (Issue 2).
- **Areas with good coverage**:
  - Session auto-relocate guard chain (skip-list, no-match, not-`$HOME`,
    master toggle, window-name, spaced names).
  - All three resolver backends; Correction A (rupa/z empty-on-no-match) and
    Correction B (resolve exits 0) verified intact.
  - Hook registration quoting (`\"#{session_name}\"`) and spaced-name delivery.
  - Coexistence model (resurrect/continuum via `-c` skip; `set-hook -g`
    reload-safe/overwrite behavior documented in README).
- **Areas needing more attention**:
  - **Resolver hardening against real-zoxide flag parsing** (Issue 1) — the
    primary gap. The `--` guard was removed and the test fixtures do not model
    real zoxide, so this class of input is untested.
  - **Arbitrary-character queries through the `command-prompt` `%%` path**
    (Issue 2) — only normal and space-containing queries are covered;
    quote/special-character inputs are not.
