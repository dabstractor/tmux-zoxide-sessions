# Verification Notes — P1.M1.T2.S1 (`get_tmux_option`)

Empirically verified facts on this machine (tmux present, `/bin/sh` → bash, `shellcheck`
installed, no bats/shunit2). These ground the PRP's validation gates.

## 1. The mandated function form passes `shellcheck` clean (no exclusions)

Exact PRD §5.3 form:
```sh
get_tmux_option() {
    _v=$(tmux show-option -gqv "$1" 2>/dev/null)
    [ -n "$_v" ] && echo "$_v" || echo "$2"
}
```
`shellcheck <file>` → **exit 0, no output**. No SC2015, no SC2086, no warnings. (SC2015 — the
"A && B || C is not a ternary" advisory — does *not* fire here, empirically.) So the gate
"shellcheck passes" needs no `-e` exclusions and no `# shellcheck disable=` directives.
**Do not rewrite the `&& ||` form into `if/else`** — the item contract mandates this exact form.

## 2. The fake-`tmux`-on-PATH mocking approach works (6/6 cases pass)

A sourced-lib unit test with a fake `tmux` earlier on `PATH` correctly exercises every branch:

| Case | Setup (fake `tmux` returns) | Expected | Result |
|---|---|---|---|
| option SET non-empty | prints `thevalue` for `@set-nonempty` | `thevalue` | PASS |
| option UNSET | empty + exit 0 | the default | PASS |
| option set to EMPTY | empty + exit 0 | the default | PASS |
| value contains spaces | prints `with space` | `with space` | PASS |
| empty default, unset | empty + exit 0 | empty | PASS |
| no 2nd arg at all | empty + exit 0 | empty | PASS |

This confirms: (a) `get_tmux_option` is correct; (b) the mocking strategy in the item
contract (point 5) is viable and deterministic **without** a live tmux server.

### ⚠️ Critical fake-tmux gotcha (re-usable by S2/S3/S4)
`tmux show-option -gqv <name>` has the option name as the **first non-flag argument after
`show-option`**, NOT a fixed positional like `$4` or `$5`. The flag set is `-g -q -v`
(three separate flags), so `name` is `$5` in the standard case — but a robust fake must
**scan past all `-`-prefixed flags** and take the first bare token, because future callers
(S2 `_resolve_zoxide`, S3 `_resolve_z`) will pass other `tmux` subcommands with different
arg orders. A hardcoded `$4`-style positional silently always returns the default (the bug
that initially hid behind my first fake). The reference fake in the PRP scans flags:
```sh
shift          # drop 'show-option'
name=""
while [ $# -gt 0 ]; do
    case "$1" in -*) ;; *) name="$1"; break ;; esac
    shift
done
```

## 3. `show-option -gqv` semantics (re-confirmed from architecture/research_plugin_ecosystem.md §2)

- `-g` global, `-q` quiet (no error if unset), `-v` value-only.
- For an **unset** user `@option`: prints nothing, exits 0. → `[ -z "$_v" ]` true → default.
- This is why the default-arg pattern exists and is correct. Interpreter-agnostic: the
  `tmux` binary does the work; the shell only tests emptiness.

## 4. POSIX-sh posture (re-confirmed from findings_and_risks.md)

- The `_v` form (not `local`) is the mandated POSIX rewrite. `local` is non-POSIX; we avoid it.
- Tradeoff: `_v` leaks into the caller scope (not localized). Accepted — all scratch vars
  in resolve.sh are `_`-prefixed (`_v`, `_r`, `z_sh`) and reassigned on every call. The run
  file always calls via `$(get_tmux_option ...)` (a subshell), so the leak is confined.
- `/bin/sh` on THIS machine is bash (not dash), so dev-time dash-strictness can't be observed
  locally; `shellcheck` (shell=sh) is the portability proxy and passes.

## 5. Header-comment byte-exactness

PRD §5.3 header comment line 1 contains a **U+2014 em dash** (`—`):
`# lib/resolve.sh — shared helpers for tmux-zoxide-sessions.`
Copy byte-exact; do NOT replace with `--` or `-`. (The `write-tech-docs` "no em dash" rule
applies to prose we author; it does NOT override a verbatim spec.)

## 6. Scope boundary (anti-regression)

This subtask writes ONLY the shebang + header comment + `get_tmux_option()` into
`scripts/lib/resolve.sh`. `_resolve_zoxide` (S2), `_resolve_z` (S3, CORRECTION A), and
`resolve` (S4, CORRECTION B) are **appended later**. Do not pre-write them — S3/S4 carry
required corrections the PRD §5.3 text does not yet encode.
