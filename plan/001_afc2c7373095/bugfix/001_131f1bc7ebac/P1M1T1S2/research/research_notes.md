# Research Notes — P1.M1.T1.S2 (Restore `--` guard in `_resolve_zoxide`)

## 1. Authoritative external documentation

### zoxide `query` subcommand — the root cause of the bug

**Source**: zoxide-query(1) man page (Arch Linux, upstream zoxide 0.10.0)
**URL**: https://man.archlinux.org/man/zoxide-query.1.en

```
NAME
    zoxide-query - search for a directory in the database

SYNOPSIS
    zoxide query [KEYWORDS] [OPTIONS]

DESCRIPTION
    Query the database for paths matching the keywords.

OPTIONS
    -l, --list
        List all results, rather than just the one with the highest frecency.
    -i, --interactive
        Use interactive selection.
    -s, --score
        Print the calculated score as well as the matched path.
    --all
        Show deleted directories.
    --exclude PATH
        Exclude a path from query results.
```

**Why this matters**: The `query` subcommand has a `-l`/`--list` FLAG. When the
plugin calls `zoxide query "$1"` and `$1` is the literal string `-l` or `--list`,
zoxide parses it as the `--list` option → "List all results" → multi-line dump of
the entire frecency database (empirically 146+ lines). The fix (`zoxide query -- "$1"`)
inserts the end-of-options delimiter so `-l`/`--list` becomes a KEYWORD (positional),
finds no match, and returns empty.

### POSIX Utility Syntax Guidelines — the `--` convention

**Source**: POSIX.1-2017, §12 "Utility Conventions", Utility Syntax Guidelines
**URL**: https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html

Verbatim (Guideline 10 — the `--` delimiter):

> "The first -- argument that is not an option-argument should be accepted as a
> delimiter indicating the end of options. Any following arguments should be
> treated as operands, even if they begin with the '-' character."

**Why this matters**: This is the standard guarantee that zoxide (a clap-based
Rust CLI) honors. Passing `--` before the user query is the idiomatic, portable
way to prevent a leading-dash query from being absorbed as a flag.

## 2. Empirical proof (from PRD §h2.2 / §h3.0 "Steps to Reproduce")

Captured on a real zoxide instance:
```
zoxide query  "-l"     | wc -l   # -> 146+ (list-mode DB dump)   [BUG]
zoxide query "--list"  | wc -l   # -> 146+ (list-mode DB dump)   [BUG]
zoxide query -- "-l"             # -> empty (correct)            [the fix]
zoxide query -- "--list"         # -> empty (correct)            [the fix]
```

## 3. Current state of `scripts/lib/resolve.sh` (verified at HEAD)

Line-numbered (confirmed live):
```
 11  # _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
 12  # Note: NO `--` end-of-options guard. PRD §5.3 calls `zoxide query "$1`".
 13  # The `--` guard breaks the rupa/z-backed zoxide shim (which does not parse
 14  # `--` and treats it as part of the query), making BOTH features silently
 15  # no-op against the plugin's primary support target. zoxide already rejects
 16  # a query that begins with `-` safely (empty output + exit 0), which is not a
 17  # realistic user query, so the guard buys nothing while breaking the shim.
 18  _resolve_zoxide() {
 19      command -v zoxide >/dev/null 2>&1 && zoxide query "$1" 2>/dev/null
 20  }
```

The edit is a single contiguous replacement of lines 11–20:
- Line 11 summary rewritten (`dir from` → `single directory from`).
- Lines 12–17 (false rationale) collapsed to ONE accurate comment line.
- Line 19: `zoxide query "$1"` → `zoxide query -- "$1"`.

Constraints (from contract + findings_and_risks.md §F4 / POSIX carry):
- Keep the EXACT `command -v ... && zoxide query -- "$1" 2>/dev/null` chain form.
- Do NOT add `|| true`, `; return 0`, or `local`. (The `return 0` at the end of
  `resolve()` — CORRECTION B — already neutralizes any residual non-zero exit.)
- No bashisms (no `[[ ]]`, `==`, `$'\n'`, arrays). The file is `#!/bin/sh`.

## 4. Dependency on P1.M1.T1.S1 (CRITICAL — R1 coupling)

findings_and_risks.md §R1: restoring the guard changes the fake zoxide's argv from
`query <kw>` to `query -- <kw>`. The OLD fakes do a blind `shift; kw="$1"` → `kw`
becomes `--` → every `proj`-match silently no-matches → suite breaks.

Therefore **S1 MUST be complete before S2 is applied/validated.** S1 hardens all 6
fake-zoxide fixtures to strip a leading `--` (via the `if [ "$1" = "--" ]; then shift`
idiom), so a `query -- proj` call resolves `proj` correctly and the suite stays green.

S1's hardened fake form (canonical, from P1.M1.T1.S1/PRP.md):
```sh
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then
    shift      # -- consumed; everything after is a POSITIONAL query
else
    case "$1" in -l|--list) printf '%s\n' <dump>; exit 0 ;; esac   # list-mode (no -- only)
fi
case "$1" in <token>) printf '%s\n' <dir> ;; *) printf '' ;; esac   # positional resolution
```

**Precondition check for the S2 implementer**: before applying the S2 edit, verify
S1 is present — `grep -rl 'if \[ "\$1" = "--" \]' tests/` should list the 6 files
(test_resolve_zoxide, test_resolve_dispatcher, test_z_window, test_z_session,
test_run_file, test_backend_matrix). If S1 is absent, STOP — applying S2 alone
will turn the suite red (proj matches no-op through the unstripped `--`).

## 5. Test baseline (verified live at HEAD, pre-S1)

```
test_backend_matrix.sh:          pass=12 fail=0
test_resolve_dispatcher.sh:      pass=14 fail=0
test_resolve_get_tmux_option.sh: pass=6  fail=0
test_resolve_zoxide.sh:          pass=3  fail=0
test_resolve_z.sh:               pass=5  fail=0
test_run_file.sh:                pass=9  fail=0
test_session_hook.sh:            pass=11 fail=0
test_z_session.sh:               pass=9  fail=0
test_z_window.sh:                pass=11 fail=0
TOTAL:                           pass=80 fail=0
```

After S1 + S2, this same TOTAL (80/0) must hold. No test counts change: S2 adds no
assertions (those are T3); S1 only restructures fixture parsing (a no-op for the
current `proj`/`zxmatrix`/`two words` match arms through the new code).

## 6. ShellCheck posture

`scripts/lib/resolve.sh` is `#!/bin/sh`. `shellcheck scripts/lib/resolve.sh` is
clean at HEAD. The edit adds two characters (`-- `) and rewrites a comment — it
cannot introduce SC findings. Verify post-edit.

## 7. README / docs impact (NONE)

The README "Backends" section says: "`zoxide` runs `zoxide query <query>`." This is
a high-level user-facing description. The `--` is an implementation detail of safe
argument passing (defense against leading-dash queries), not a user-facing surface
change. No README edit is in scope for S2 (docs sync is P1.M3.T1).
