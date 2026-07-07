# System Context — Bugfix 001 (zoxide flag absorption + single-quote query)

> Synthesized by the Lead Architect from three parallel research subagents
> (research_issue1_defense.md, research_issue2_quoting.md, research_test_baseline.md)
> plus direct codebase analysis at commit `720f1f3` (HEAD of `main`).

## 1. What changed (regression)

Commit `b93e776` "Remove zoxide -- end-of-options guard and fix tautological test"
removed the contract-required `--` end-of-options guard from `_resolve_zoxide()`
in `scripts/lib/resolve.sh`, reverting `zoxide query -- "$1"` to `zoxide query "$1"`.

The removal was justified by a **factually false** comment block (lines 12-17)
claiming zoxide "already rejects a query that begins with `-` safely" and that
`--` "breaks the rupa/z-backed zoxide shim." Both claims are disproven:

- `zoxide query "-l"` enters **list mode** and dumps the entire frecency
  database (146+ lines), NOT empty output.
- There is no "rupa/z-backed zoxide shim" in the PRD backend model. The thing
  that fails on `--` is the **test fixture's fake zoxide** (a blind `shift` +
  `case`), not a support target.

The same commit also stripped `--` handling from all 6 fake-zoxide test fixtures,
making them incapable of catching this regression.

## 2. Current codebase state (verified)

### File map (non-git, ship-relevant)

| File | Role | Shebang | Lines |
|------|------|---------|-------|
| `tmux-zoxide-sessions.tmux` | TPM run file: bind-key + session-created hook | `#!/usr/bin/env bash` | ~30 |
| `scripts/lib/resolve.sh` | Shared library: `get_tmux_option`, `_resolve_zoxide`, `_resolve_z`, `resolve` | `#!/bin/sh` | ~48 |
| `scripts/z-window.sh` | Window-jump handler (binding dispatch target) | `#!/bin/sh` | ~25 |
| `scripts/z-session.sh` | Session-relocate handler (hook dispatch target) | `#!/bin/sh` | ~55 |
| `tests/test_*.sh` (9 files) | Unit + integration tests | `#!/bin/sh` | various |
| `README.md` | Install, usage, options, backends, known limits | -- | ~130 |

### Key function signatures (contracts)

```sh
# scripts/lib/resolve.sh
get_tmux_option() <name> <default> -> option value or default
_resolve_zoxide() <query> -> single dir path or empty (currently BROKEN: no -- guard)
_resolve_z() <query> -> single dir path or empty (rupa/z via _z)
resolve() <query> -> single dir path or empty (dispatcher, always exits 0)

# scripts/z-window.sh
# Usage: z-window.sh [query ...]
# query="$*" -> resolve -> new-window -c "$dir" -n "$base"

# scripts/z-session.sh
# Usage: z-session.sh <session_name>
# name="$1" -> guard chain -> resolve -> respawn-pane -c "$resolved"
```

### Test baseline (before bugfix)

- **9 test files, 80 assertions, all passing (80/80, 9/9 exit 0)**
- No Makefile or test runner — each test is `sh tests/test_*.sh`
- Assertion format: `check <desc> <expected> <actual>` (exact equality) + `contains` (substring)
- Unit tests use fake zoxide/tmux on PATH in a `sh -c` subshell
- Integration tests use isolated `tmux -L zxstest_*` servers via fake tmux wrapper
- Only `test_backend_matrix.sh` subtest A exercises real zoxide (skip-if-absent)
- ShellCheck: clean except SC1091 info for sourced files (version 0.11.0)

## 3. Data flow (how the bug manifests)

```
prefix g -> command-prompt "z to:" -> user types "-l"
  -> %% substituted -> run-shell '.../z-window.sh -l'
    -> z-window.sh: query="-l", resolved=$(resolve "-l")
      -> resolve("-l") -> backend=auto (default)
        -> _resolve_zoxide("-l") -> zoxide query "-l"  [NO -- GUARD]
          -> REAL ZOXIDE ENTERS LIST MODE -> 146-line database dump
        -> _r = <146-line dump> (NON-empty) -> auto fallback SKIPPED
        -> resolve returns <146-line dump>
    -> dir = <146-line dump>  [NO VALIDATION]
    -> tmux new-window -c "<146-line dump>" -n "<random basename>"  [CORRUPTED WINDOW]
```

After fix:
```
_resolve_zoxide("-l") -> zoxide query -- "-l"  [-- GUARD RESTORED]
  -> zoxide treats "-l" as positional -> no match -> empty
-> _r = "" -> auto fallback -> _resolve_z("-l") -> empty
-> resolve returns ""
-> dir = $cur (fallback)  [PLUS defence-in-depth: -d check rejects any non-dir]
-> tmux new-window -c "$cur" -n "basename($cur)"  [CORRECT]
```

## 4. Architecture decisions for the bugfix

### Issue 1 — Three-layer fix

**Layer 1 (root): Restore `--` guard in `_resolve_zoxide`**
```sh
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
}
```
Delete the false comment block (lines 12-17), replace with accurate doc.

**Layer 2 (defence-in-depth): Caller-side guards in z-window.sh and z-session.sh**

POSIX-compliant newline-reject + directory-exists check. Use `case` with a literal
newline variable (NOT the bash-only `$'\n'`). The PRD's suggested one-liner uses
`$'\n'` and has inverted boolean logic — do NOT copy it.

```sh
NL='
'
# ...after resolved=$(resolve "$query")...
case "$resolved" in
    *"$NL"*) : ;;                    # multi-line -> reject, keep dir=$cur
    *)        [ -d "$resolved" ] && dir="$resolved" ;;
esac
```

Applied symmetrically to both z-window.sh (before `new-window`) and z-session.sh
(before `respawn-pane`).

**Layer 3 (verifiability): Harden test fixtures + add regression tests**

All 6 fake-zoxide fixtures must:
1. Strip `--` (like real zoxide) — so the restored guard doesn't break them
2. Model list-mode for `-l`/`--list` (multi-line dump) — so regression tests can observe the bug
3. The list-mode modeling must ONLY trigger when `--` is absent (before `--`), because
   after `--`, `-l` is a positional and returns empty. This models real zoxide precisely.

Hardened fake zoxide design:
```sh
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then
    shift    # -- consumed; everything after is positional (literal query)
else
    # No --: model flag parsing (list-mode for -l/--list)
    case "$1" in
        -l|--list) printf '%s\n' "/fake1" "/fake2"; exit 0 ;;
    esac
fi
# Positional query resolution
case "$1" in
    <known-token>) printf '%s\n' "<fixture-dir>" ;;
    *)             printf '' ;;
esac
```

**CRITICAL COUPLING:** Restoring the `--` guard changes the fake zoxide's argv from
`query <kw>` to `query -- <kw>`. The fixtures MUST be hardened to strip `--` BEFORE
(or simultaneously with) the guard restoration, or all existing `proj`-match tests
will silently break (the fake sees `--` as the keyword, returns empty).

### Issue 2 — Binding quoting fix

Change the binding in `tmux-zoxide-sessions.tmux` from:
```sh
"run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
```
to:
```sh
"run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"
```

This wraps `%%` in shell double quotes. tmux's outer single quotes pass the inner
`"..."` through untouched; `sh -c` then protects single quotes and spaces inside
the double quotes. Trace for `o'brien`:

1. Substitute: `run-shell '.../z-window.sh "o'brien"'`
2. tmux lex (outer `'...'`): shell-command = `.../z-window.sh "o'brien"`
3. `sh -c`: z-window.sh receives `$1 = o'brien` ✓

Residual edge cases (`$`, backtick, backslash` are vanishingly rare for zoxide
directory queries. Full robustness would require bypassing `%%` entirely
(`display-popup -E` or `read </dev/tty`), which is out of scope for this bugfix.

## 5. Files to change (complete scope)

| File | Change | Issue |
|------|--------|-------|
| `scripts/lib/resolve.sh` | Restore `zoxide query -- "$1"`; rewrite false comment (L12-17) | 1 |
| `scripts/z-window.sh` | Add newline-reject + `-d` guard before `new-window` | 1 |
| `scripts/z-session.sh` | Add symmetric guard before `respawn-pane` | 1 |
| `tests/test_resolve_zoxide.sh` | Harden fake: strip `--`, model list-mode; add `-l` case | 1 |
| `tests/test_resolve_dispatcher.sh` | Harden fake: strip `--`, model list-mode; add `-l` case | 1 |
| `tests/test_z_window.sh` | Harden fake; add `-l` regression (window falls back to cur) | 1 |
| `tests/test_z_session.sh` | Harden fake; add `-l` regression (no relocate) | 1 |
| `tests/test_run_file.sh` | Harden fake; update C3 assertion for `\"%%\"` quoting | 1+2 |
| `tests/test_backend_matrix.sh` | Harden fake (subtest B); update subtest A description | 1 |
| `tmux-zoxide-sessions.tmux` | Double-quote `%%` in binding | 2 |
| `README.md` | Review/update known limitations (Mode B final task) | both |

**Out of scope:** `tests/test_resolve_z.sh` and `tests/test_session_hook.sh` (no
fake-zoxide fixture); `PRD.md` (read-only); `.gitignore` (forbidden).
