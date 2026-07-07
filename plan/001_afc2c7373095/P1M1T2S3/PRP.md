# PRP — P1.M1.T2.S3: `_resolve_z()` backend (rupa/z) — APPLY CORRECTION A

## Goal

**Feature Goal**: Append the **third** function — `_resolve_z()` — to the shared library `scripts/lib/resolve.sh`. This function is the rupa/z backend resolver: given a query, it sources a rupa/z `z.sh` (set via `@zoxide-sessions-z-sh`), invokes rupa/z's `_z` frecency function in an **isolated subshell**, and emits the matched directory **only when `_z` actually changed cwd** — empty otherwise. It fixes a CONFIRMED false-positive bug in the PRD §5.3 form (CORRECTION A, `findings_and_risks.md` §A): rupa/z's `_z` silently `cd`s on a match but is a no-op on a miss, so the PRD's unconditional `pwd` printed the subshell's *starting* dir on a no-match. Consumed by the `resolve()` dispatcher (P1.M1.T2.S4) for the `z` branch and the `auto`-fallback's second leg.

**Deliverable**: Two artifacts —
1. `scripts/lib/resolve.sh` — **append** `_resolve_z()` after the existing `_resolve_zoxide()` (which S2 appended after `get_tmux_option`). Nothing else changes (shebang, header comment, `get_tmux_option`, `_resolve_zoxide` stay byte-for-byte; `resolve` is NOT written — S4 owns it).
2. `tests/test_resolve_z.sh` — a dependency-free POSIX-`sh` unit test, with a **minimal `z.sh` fixture** that reproduces rupa/z's `_z` semantics (`cd` on match, no-op on miss) and a fake `tmux` answering `@zoxide-sessions-z-sh`. Follows the TDD discipline in the item contract: case 1 demonstrates the false positive (no-match → NON-empty via the buggy `pwd` form); cases 2–5 prove the fix.

**Success Definition**:
- `scripts/lib/resolve.sh` contains `get_tmux_option` + `_resolve_zoxide` (unchanged) **and** `_resolve_z` (new, CORRECTION A), and is sourceable in plain `sh`.
- `_resolve_z <query>` emits a real `_z` match path, **empty** on a no-match or when `@zoxide-sessions-z-sh` is unset/unreadable, and **always exits 0** (callers check output, not status — PRD §4).
- `shellcheck scripts/lib/resolve.sh` and `shellcheck tests/test_resolve_z.sh` each exit 0 with **no** output (see Known Gotchas for the one mandated, scoped `disable=SC2016` directive).
- `sh tests/test_resolve_z.sh` prints `RESULTS: pass=5 fail=0` and exits 0.
- `.gitignore` and `PRD.md` are untouched; no other functions are added; nothing is chmod'd.

## User Persona

**Target User**: The implementing AI agent (subtask executor); the downstream `resolve()` dispatcher (P1.M1.T2.S4) which calls `_resolve_z` directly; ultimately the run file + both handler scripts (P1.M2/P1.M3) which call `resolve()`.

**Use Case**: Translate a short human query (`tmux`, `proj`) into a concrete directory using the rupa/z frecency index, as a fallback for machines without `zoxide` (the `auto` backend's second leg) or when the user explicitly selects the `z` backend.

**Pain Points Addressed**: tmux's `new-window -c` / `new-session -c` need a literal path; rupa/z already knows the user's most-used dirs. `_resolve_z` is the safe, side-effect-isolated, no-false-positive lookup that never crashes the plugin when `z.sh` isn't configured and never returns a bogus dir on a miss.

## Why

- This is the **third** of four functions built into the same file (S1 → S2 → S3 → S4). It is the **fallback** backend: `auto` (the default) tries `_resolve_zoxide` first and falls back to `_resolve_z` only on an empty result; `z` uses it directly (PRD §4). On machines without zoxide, `_resolve_z` is the only resolver — so its correctness is load-bearing for the whole plugin there.
- **The bug CORRECTION A fixes is dormant by default** (`@zoxide-sessions-z-sh` is unset, so `_resolve_z` short-circuits `return 0`), but activates the moment a user points at a real `z.sh`. The PRD §5.3 form returns the plugin's *own* directory on every no-match — which would feed `respawn-pane -c <bogus>` (session) or `new-window -c <bogus>` (window). Shipping the fix makes the README's "resolver returns empty on no-match" statement (authored in P1.M4.T1) actually true.
- **The validated fix is non-obvious.** A naive reading of `_z` (it "resolves a dir") suggests `pwd` after calling it; the actual semantics (`cd` on match, silent no-op on miss) require a before/after `pwd` delta to distinguish a real match from a no-op. This is exactly the kind of library quirk a PRP exists to capture.
- S4's CORRECTION B (`resolve()` ends with `return 0`) **composes** with this fix: `_resolve_z` intentionally exits 0 / returns 0, so the `auto` fallback's `_r=$(_resolve_z "$1")` captures the correct (possibly empty) output regardless of status. Getting S3 right is what makes S4's dispatcher defense-in-depth sound.

## What

User-visible behavior: none directly (sourced library function). Observable contract when sourced into any `sh` script:

- `_resolve_z "<query>"`:
  - If `@zoxide-sessions-z-sh` is **unset or empty or points to an unreadable file** → short-circuit `return 0`, no output.
  - Otherwise sources that `z.sh` under `zsh` (if available) else `sh`, calls `_z "<query>"` in an **isolated subshell** (so the `cd` side effect cannot leak to the parent — `resolve.sh` is sourced by the run file and handlers), and emits the new cwd **only if it differs from the starting cwd** (a real match); emits nothing on a no-match. Always exits 0.
- The parent process's cwd is **never changed** (the lookup runs in a forked `"$shell" -c` subshell).
- stderr from `_z`/z.sh is suppressed (`2>/dev/null`); a failure to source `z.sh` is caught by `|| exit 0` inside the subshell.

### Success Criteria

- [ ] `scripts/lib/resolve.sh` still starts with `#!/bin/sh`, the §5.3 header comment, `get_tmux_option`, **and** `_resolve_zoxide` — **unchanged**.
- [ ] `_resolve_z` is **appended** after `_resolve_zoxide`, separated by a blank line + a one-line doc comment.
- [ ] `_resolve_z` body is the CORRECTION-A pwd-delta form (OPTION C — see Known Gotchas): reads `@zoxide-sessions-z-sh` via `tmux show-option`; `[ -n ] && [ -r ] || return 0` short-circuit; `shell="sh"`/`shell="zsh"` selection; the `"$shell" -c '… o=$(pwd); _z "$2"; n=$(pwd); [ "$o" != "$n" ] && printf …; exit 0'` subshell with **before/after `pwd` delta**; trailing `2>/dev/null`.
- [ ] The function **always exits 0** (the subshell ends `exit 0`; the short-circuit is `return 0`).
- [ ] No `local`, no `[[ ]]`, no arrays, no `==` in `[ ]`, no `echo -e` (POSIX-clean). The only shellcheck annotation is the one mandated scoped `# shellcheck disable=SC2016` line.
- [ ] `shellcheck scripts/lib/resolve.sh` → exit 0, no output. `shellcheck tests/test_resolve_z.sh` → exit 0, no output.
- [ ] `sh tests/test_resolve_z.sh` → `RESULTS: pass=5 fail=0`, exit 0.
- [ ] `get_tmux_option` and `_resolve_zoxide` still work after the append (re-run S1/S2 tests or source-check — no regression).
- [ ] `.gitignore` / `PRD.md` unmodified (`git status --short` shows only the expected new/modified files).

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The bug and its fix are reproduced verbatim (with the empirically-validated before/after table); the one shellcheck gap in the architecture notes (§A wasn't linted) is surfaced and resolved with a verified-clean variant (OPTION C); the full 5-case unit test is specified verbatim and was run during research (5/5 PASS, shellcheck-clean on both files); the POSIX/append-only/isolation constraints are explicit; `shellcheck` is the only required tool (confirmed installed). The live rupa/z path + `~/.z` exist on this machine for an optional smoke check, but the unit test is self-contained (a minimal `z.sh` fixture) and is the authoritative gate. No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source for the resolver contract and the file's overall shape.
  section: "§5.3 scripts/lib/resolve.sh (the _resolve_z block is the BASELINE; CORRECTION A below amends it), §4 Options reference (@zoxide-sessions-z-sh, the z/auto backends, 'callers check output, not status')"
  critical: "The PRD §5.3 _resolve_z body has a CONFIRMED BUG (CORRECTION A). Do NOT copy it verbatim. Use the CORRECTION-A pwd-delta form reproduced below. The CONTRACT ('returns empty on no-match, always exits 0') is what the fix must satisfy."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: Primary-source, empirically-verified analysis of the false-positive bug + the validated fix.
  section: "🔴 CORRECTION A (REQUIRED) — the bug table + the before/after pwd-delta fix"
  critical: "§A gives the corrected algorithm. NOTE: §A was NOT run through shellcheck — on shellcheck 0.11.0 its verbatim form emits SC2209 (warning) + SC2016 (info). This PRP mandates OPTION C (quote the shell var + one scoped disable=SC2016 directive), which is behaviorally identical and lint-clean. See Known Gotchas + verification_notes.md §2."

- file: plan/001_afc2c7373095/architecture/research_resolver_backends.md
  why: Documents rupa/z _z semantics (cd on match, no-op on miss) and why the lookup must isolate the side effect.
  section: "§2 rupa/z (_z as a shell function that cds; sourced z.sh; zsh-vs-sh code paths)"
  critical: "Confirms _z is a side-effectful function (not a CLI), so the lookup MUST run in an isolated subshell and MUST compare cwd before/after. This is the root cause CORRECTION A addresses."

- file: plan/001_afc2c7373095/P1M1T2S2/PRP.md
  why: The S2 PRP that APPENDED _resolve_zoxide (the function this subtask appends AFTER). Defines the file state S3 starts from and the test-harness pattern S3 extends.
  section: "Verbatim content to APPEND (the _resolve_zoxide block), Verbatim test block (fake-zoxide-on-PATH pattern), Known Gotchas (POSIX, append-only, sourced-not-exec, PATH-narrowing-inside-subshell)"
  critical: "ASSUME resolve.sh already has shebang + header comment + get_tmux_option + _resolve_zoxide (S1+S2). APPEND _resolve_z AFTER _resolve_zoxide. Reuse S2's fake-binary-on-PATH test idiom; S3 adds a fake z.sh fixture + a second fake-tmux bin for the unset case."

- docfile: plan/001_afc2c7373095/P1M1T2S3/research/verification_notes.md
  why: Empirical proof grounding every gate: CORRECTION A validated (sh+zsh), the shellcheck gap found+resolved (OPTION C), the 5-case test run (5/5), and the env-var-propagation test gotcha found+fixed.
  section: "§1 CORRECTION A validated, §2 shellcheck gap + OPTION C, §3 why the subshell is required, §4 the 5/5 test + the heredoc-path-baking fix"
  critical: "§2: the §A-verbatim form FAILS the 'shellcheck exit 0 no output' gate; OPTION C is mandated. §4: bake the fake z.sh path via an UNQUOTED heredoc with \$1 escaped (not a runtime env var) — per-command VAR=x cmd assignments both trip SC2097/2098 and mis-propagate across the nested subshell."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State AFTER P1.M1.T2.S1 + P1.M1.T2.S2 have run (treat as contract — S3 appends to this):
$ ls scripts/lib tests 2>/dev/null
scripts/lib:
resolve.sh          # S1: shebang+header+get_tmux_option ; S2: + _resolve_zoxide (2 funcs now)
tests:
test_resolve_get_tmux_option.sh   # S1's fake-tmux unit test (pattern S3 extends)
test_resolve_zoxide.sh            # S2's fake-zoxide unit test (pattern S3 extends)

# resolve.sh currently ends with _resolve_zoxide (the last function). _resolve_z is NOT yet present.

# Tooling + live fixtures on this machine (for the optional smoke check):
$ command -v shellcheck zsh sh
/usr/bin/shellcheck            # ✅ required lint gate (v0.11.0)
/usr/bin/zsh                   # ✅ present -> _resolve_z selects the zsh code path
/bin/sh -> bash                # dev note: dash-strictness observed via shellcheck, not runtime
$ ls -la /home/dustin/.config/znap/rupa/z/z.sh ~/.z
... rupa/z/z.sh   # ✅ real z.sh (for OPTIONAL live smoke only — the unit test is self-contained)
... ~/.z          # ✅ populated frecency db (7430 B; e.g. /home/dustin/.config/tmux|...)
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  scripts/
    lib/
      resolve.sh             # MODIFIED — APPEND _resolve_z() after _resolve_zoxide()
  tests/
    test_resolve_get_tmux_option.sh   # (S1, unchanged — may re-run to confirm no regression)
    test_resolve_zoxide.sh            # (S2, unchanged — may re-run to confirm no regression)
    test_resolve_z.sh                 # NEW — fake-z.sh + fake-tmux mocking unit test (5 cases)
```

`resolve.sh` now holds **three** functions: `get_tmux_option`, `_resolve_zoxide`, `_resolve_z`.
`resolve` (the dispatcher, CORRECTION B) is still NOT written — S4 appends it. Do not pre-write it.

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE BUG): rupa/z _z silently `cd`s on a match and is a NO-OP on a miss. The PRD
#   §5.3 form runs `pwd` unconditionally after `_z`, so a no-match prints the subshell's
#   STARTING directory — a false-positive non-empty path. Empirically reproduced on this
#   machine: no-match -> /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions (the plugin's
#   own dir). CORRECTION A fixes it with a before/after pwd delta. DO NOT ship the PRD form.

# CRITICAL (SHELLCHECK GAP IN §A): findings_and_risks.md §A was NOT linted. Its verbatim form
#   emits SC2209 (`shell=sh`) + SC2016 (single-quote subshell). This PRP MANDATES OPTION C:
#     - Quote the var: `shell="sh"; ... && shell="zsh"`          (kills SC2209)
#     - One scoped directive ABOVE the "$shell" -c line:
#         # shellcheck disable=SC2016 # inner $1/$2/$o/$n expand inside the subshell, not the parent
#   Verified: shellcheck 0.11.0 -> exit 0, NO output; behavior identical to §A. SC2016 is an
#   INTENTIONAL false positive: the single quotes are correct (the inner $1/$2/$o/$n must NOT
#   expand in the parent — they are the subshell's positional params, passed via `_ "$z_sh" "$1"`).
#   This is exactly the PRD §5.3 _resolve_z structure; CORRECTION A only changes the subshell BODY.

# CRITICAL (ISOLATION): _z has a side effect (cd). resolve.sh is SOURCED by the run file +
#   both handlers — _resolve_z MUST NOT change the parent's cwd. Hence the lookup runs in a
#   forked `"$shell" -c '...'` subshell. Do NOT replace it with an in-process `(...)` group:
#   that drops the PRD's "zsh-if-available" preference (z.sh has a zsh code path). Keep the
#   `"$shell" -c` form.

# CRITICAL (APPEND only): preserve S1+S2 content byte-for-byte — shebang `#!/bin/sh`, the
#   2-line header comment WITH its U+2014 em dash, get_tmux_option, AND _resolve_zoxide.
#   Insert _resolve_z AFTER _resolve_zoxide, separated by a blank line + a one-line doc comment.

# CRITICAL (TEST HEREDOC): the fake z.sh fixture MUST bake its match path as a LITERAL (via an
#   UNQUOTED heredoc with `\$1` escaped), NOT reference a runtime env var. _resolve_z spawns a
#   NESTED subshell (sh -c -> "$shell" -c -> sources z.sh); a runtime $ZFIX depends on propagation
#   two levels deep (fragile) and per-command `VAR=x cmd` assignments trip SC2097/SC2098. Baking
#   the path at generation time is robust and shellcheck-clean. Copy the verbatim test block.

# GOTCHA: Do NOT chmod +x resolve.sh — SOURCED, never executed (S1 invariant; carried by S2).
# GOTCHA: POSIX sh — NO `local`. `_resolve_z` uses `z_sh`/`shell` as scratch vars (global namespace
#   is acceptable in a sourced lib; matches get_tmux_option's `_v` precedent). Avoid [[ ]], arrays,
#   `==` in [ ], `echo -e`, ${var//}.
# GOTCHA: No test framework exists. Do NOT pull in bats/shunit2. The mandated approach is a
#   dependency-free fake-binary-on-PATH mock + a minimal z.sh fixture (item contract #5), extending
#   the S1/S2 pattern.
# GOTCHA: `command -v zsh` SUCCEEDS on this machine, so `_resolve_z` takes the zsh path at runtime.
#   The fake z.sh fixture must therefore be zsh-safe (POSIX `case`/`cd` — it is). The unit test is
#   deterministic either way (a CI without zsh falls back to sh; the fixture is sh-safe too).
# GOTCHA: `/bin/sh` -> bash on THIS dev machine (dash-strictness via shellcheck, not runtime).

# FORBIDDEN: Do NOT modify .gitignore or PRD.md.
# FORBIDDEN: Do NOT chmod anything, and do NOT modify get_tmux_option, _resolve_zoxide, or S1/S2 tests.
# FORBIDDEN: Do NOT pre-write resolve (S4, CORRECTION B) or copy the PRD §5.3 _resolve_z verbatim.
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The only "structure" is the function's positional-parameter contract:
`$1` = query keyword (e.g. `tmux`). Output via stdout only (one absolute path line on a real
match, or nothing). Exit status always 0.

### Verbatim content to APPEND to `scripts/lib/resolve.sh`

`scripts/lib/resolve.sh` already exists from S1+S2 with this tail (do not rewrite it; `…` = the
S1 `get_tmux_option` block above, unchanged):
```sh
… (shebang, header comment, get_tmux_option — S1) …

# _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
}
```
**Append** exactly the following block (one blank line + doc comment + function) after `_resolve_zoxide`.
This is CORRECTION A in the shellcheck-clean OPTION C form (see Known Gotchas + verification_notes §2):
```sh

# _resolve_z <query> -> dir from rupa/z (_z), or empty. Always exits 0.
_resolve_z() {
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    [ -n "$z_sh" ] && [ -r "$z_sh" ] || return 0
    shell="sh"; command -v zsh >/dev/null 2>&1 && shell="zsh"
    # shellcheck disable=SC2016 # inner $1/$2/$o/$n expand inside the subshell, not the parent
    "$shell" -c '. "$1" 2>/dev/null || exit 0; o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ] && printf "%s\n" "$n"; exit 0' \
        _ "$z_sh" "$1" 2>/dev/null
}
```
> Implementing agent: this is `findings_and_risks.md` §A with two shellcheck-cleanliness tweaks
> (quote `shell="sh"`/`shell="zsh"`; one scoped `disable=SC2016` directive). The **algorithm** is
> byte-faithful to §A: short-circuit on unset/unreadable `z_sh`; else spawn an isolated subshell
> that sources `z.sh`, captures `pwd` before (`o`) and after (`n`) `_z`, and emits `n` **only** when
> `_z` actually changed cwd. The trailing `exit 0` (subshell) and `return 0` (short-circuit) honor
> "always exits 0." Do **not** add `local`, `if/else`, extra `|| true`, other directives, or other
> functions. Do **not** copy the PRD §5.3 body (the buggy `; pwd` form).

#### Why each piece is exactly so (do not "improve" it)

```sh
# z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
#   Read the option directly (NOT via get_tmux_option) so an UNSET option yields "" (not a default).
#   `|| true` guards a non-zero tmux exit (no server) so the line never aborts `set -e` callers.
# [ -n "$z_sh" ] && [ -r "$z_sh" ] || return 0
#   Dormant by default: unset/empty/unreadable -> short-circuit, no output, exit 0. This is why the
#   bug is dormant unless a user points at a real z.sh (findings_and_risks.md §A note).
# shell="sh"; command -v zsh >/dev/null 2>&1 && shell="zsh"
#   PRD §5.3 preference: z.sh has a zsh code path; use it when available. QUOTED (kills SC2209).
# "$shell" -c '. "$1" ...; exit 0' _ "$z_sh" "$1" 2>/dev/null
#   ISOLATION: _z cds; the subshell absorbs the cd so the parent cwd is untouched. The inner $1/$2
#   are the subshell's positional params ($1=z_sh, $2=query), passed via `_ "$z_sh" "$1"` — hence
#   SINGLE quotes (SC2016 is an intentional false positive; the directive silences it, scoped).
# o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ] && printf "%s\n" "$n"
#   THE FIX: emit a path ONLY when _z changed cwd. No-match -> _z no-op -> o==n -> empty output.
# exit 0   (subshell)   +   return 0   (short-circuit)
#   Honor "always exits 0" so S4's `resolve()` and the `auto` fallback compose cleanly.
```

### Verbatim content for `tests/test_resolve_z.sh`

Write **exactly** this. It is self-verifying (prints `PASS`/`FAIL`, exits non-zero on any
failure) and was run during research: `RESULTS: pass=5 fail=0`, exit 0; shellcheck-clean.

```sh
#!/bin/sh
# Unit tests for _resolve_z (P1.M1.T2.S3 — CORRECTION A).
# TDD discipline: case 1 demonstrates the PRD §5.3 false positive (no-match -> NON-empty
# via the buggy `pwd` form); cases 2-5 prove the shipped CORRECTION-A fix (match -> path,
# no-match -> empty, short-circuit on unset, always exit 0).
# Strategy: a minimal `z.sh` fixture reproduces rupa/z's _z semantics (cd on match, no-op on
# miss), and a fake `tmux` answers @zoxide-sessions-z-sh. No live rupa/z or ~/.z required.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- minimal z.sh fixture: _z cds on a known match, no-op on a miss ------------
# (unquoted heredoc bakes $ZFIX/proj as a literal path; \$1 stays the function's param)
ZFIX="$REPO_ROOT/tests/.zfix"
mkdir -p "$ZFIX/proj"
cat > "$ZFIX/z.sh" <<ZSH
_z() {
    case "\$1" in
        proj) cd "$ZFIX/proj" 2>/dev/null || cd / ;;
        *) ;;  # no-op on miss -> cwd unchanged (the false-positive root cause)
    esac
}
ZSH

# --- fake tmux #1 (option SET): answers @zoxide-sessions-z-sh with the z.sh path
TBIN_SET="$REPO_ROOT/tests/.tmux-set"
mkdir -p "$TBIN_SET"
cat > "$TBIN_SET/tmux" <<TMUX
#!/bin/sh
[ "\$1" = "show-option" ] && printf '%s\n' "$ZFIX/z.sh"
exit 0
TMUX
chmod +x "$TBIN_SET/tmux"

# --- fake tmux #2 (option UNSET): answers nothing -----------------------------
TBIN_UNSET="$REPO_ROOT/tests/.tmux-unset"
mkdir -p "$TBIN_UNSET"
cat > "$TBIN_UNSET/tmux" <<'TMUX'
#!/bin/sh
exit 0
TMUX
chmod +x "$TBIN_UNSET/tmux"

cleanup() { rm -rf "$ZFIX" "$TBIN_SET" "$TBIN_UNSET"; }
trap cleanup EXIT INT TERM

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# _resolve_z stdout, with the SET fake tmux on PATH.
zout() {  # zout <query>
    sh -c 'PATH="'"$TBIN_SET"':$PATH" . "$0" >/dev/null; _resolve_z "$1"' "$RESOLVE" "$1"
}
# _resolve_z exit code (last stdout line).
zexit() {
    sh -c 'PATH="'"$TBIN_SET"':$PATH" . "$0" >/dev/null; _resolve_z "$1"; echo $?' "$RESOLVE" "$1" \
        | tail -1
}
# _resolve_z with the UNSET fake tmux on PATH (option unset -> short-circuit).
zout_unset() {
    sh -c 'PATH="'"$TBIN_UNSET"':$PATH" . "$0" >/dev/null; _resolve_z "$1"' "$RESOLVE" "$1"
}

# --- case 1: BUGGY PRD §5.3 form -> no-match is NON-empty (the false positive) -
buggy=$(sh -c 'PATH="'"$TBIN_SET"':$PATH" . "$0" >/dev/null
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    shell="sh"; command -v zsh >/dev/null 2>&1 && shell="zsh"
    "$shell" -c '"'"'. "$1"; _z "$2" >/dev/null 2>&1; pwd'"'"' _ "$z_sh" "zzz_nomatch" 2>/dev/null
' "$RESOLVE")
check "buggy form false-positive on no-match (NON-empty)" "NONEMPTY" \
    "$( [ -n "$buggy" ] && echo NONEMPTY || echo empty )"

# --- cases 2-5: the shipped CORRECTION-A fix ----------------------------------
check "_resolve_z match returns the path"       "$ZFIX/proj" "$(zout proj)"
check "_resolve_z no-match echoes empty"        ""          "$(zout zzz_nomatch_xyz_999)"
check "_resolve_z short-circuits empty (unset)" ""          "$(zout_unset proj)"
check "_resolve_z always exits 0"               "0"         "$(zexit zzz_nomatch_xyz_999)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

> The test is **self-contained** (no live rupa/z / `~/.z` dependency): the fake `z.sh`'s `_z`
> reproduces only the two semantics CORRECTION A hinges on — `cd` on a known match (`proj`),
> no-op on a miss. Case 1 runs the PRD's *buggy* `; pwd` form inline (against the same fixture)
> and asserts it is NON-empty on a no-match — this is the TDD "red" that demonstrates the false
> positive exists and is understood. Cases 2–5 run the shipped `_resolve_z` and assert the fix.

### Implementation Tasks (ordered by dependencies — TDD red→green)

```yaml
Task 1: MODIFY scripts/lib/resolve.sh  (APPEND _resolve_z — CORRECTION A, OPTION C form)
  - FILE: scripts/lib/resolve.sh (exists from S1+S2 with get_tmux_option + _resolve_zoxide; do NOT recreate the head)
  - ACTION: append the verbatim block above (blank line + doc comment + function) AFTER _resolve_zoxide.
  - FORM: the CORRECTION-A pwd-delta body in OPTION C form (quote `shell="sh"`/`shell="zsh"`;
          one scoped `# shellcheck disable=SC2016` directive above the `"$shell" -c` line).
  - ALGORITHM (byte-faithful to findings_and_risks.md §A): short-circuit `return 0` on
          unset/empty/unreadable z_sh; else isolated `"$shell" -c` subshell that sources z.sh,
          compares pwd before/after `_z`, emits the new cwd ONLY on a real match; always exit 0.
  - NAMING: function _resolve_z (underscore-prefixed = internal backend helper; mirrors _resolve_zoxide).
  - PRESERVE: shebang, header comment (em dash), get_tmux_option, _resolve_zoxide — byte-for-byte.
  - STOP: do NOT add resolve (S4). Do NOT chmod +x. Do NOT copy the PRD §5.3 buggy body.

Task 2: CREATE tests/test_resolve_z.sh
  - FILE: tests/test_resolve_z.sh
  - CONTENT: the verbatim block above (minimal z.sh fixture via unquoted heredoc + `\$1` escape;
          two fake-tmux bins, set/unset; 5 cases incl. the TDD buggy-form characterization).
  - NAMING: test_resolve_<backend>.sh — extends S1/S2's test_resolve_<function>.sh pattern.
  - PLACEMENT: tests/ at repo root (dev-only; not in PRD §5.1 ship tree — additive, like S1/S2).
  - COVERAGE: (1) buggy form no-match -> NON-empty [TDD red]; (2) match -> path; (3) no-match -> empty;
          (4) option unset -> short-circuit empty; (5) always exit 0.
  - CRITICAL: bake the fake z.sh match path via an UNQUOTED heredoc with `\$1` escaped (NOT a runtime
          env var — see Known Gotchas: nested-subshell propagation + SC2097/2098). Copy verbatim.
  - SELF-VERIFY: prints PASS/FAIL per case; exits non-zero on any failure; cleans up fixture/bin dirs via trap.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: shellcheck scripts/lib/resolve.sh                       # expect exit 0, NO output
  - RUN: shellcheck tests/test_resolve_z.sh                      # expect exit 0, NO output
  - RUN: sh tests/test_resolve_z.sh                              # expect "RESULTS: pass=5 fail=0", exit 0
  - RUN: sh tests/test_resolve_zoxide.sh                         # S2 test still passes (no regression)
  - RUN: sh tests/test_resolve_get_tmux_option.sh                # S1 test still passes (no regression)
  - RUN: sh -c '. scripts/lib/resolve.sh; type get_tmux_option; type _resolve_zoxide; type _resolve_z'  # all 3 present
  - RUN: grep -nE '\blocal\b|\[\[|==|\becho -e\b' scripts/lib/resolve.sh     # expect NO matches
  - RUN: git status --short                          # only expected new/modified files; PRD.md/.gitignore untouched
```

#### TDD note (red → green)

The item contract asks: *"FIRST write a failing test that demonstrates the false positive
(no-match -> non-empty), THEN implement the fix so no-match -> empty."* The shipped test realizes
this as a single self-verifying script: **case 1** runs the PRD §5.3 *buggy* `; pwd` form inline
(against the same fixture) and asserts it is NON-empty on a no-match — proving the false positive
exists and is understood (the "red"). **Cases 2–5** run the shipped CORRECTION-A `_resolve_z` and
assert match→path, no-match→empty, unset→empty, exit→0 (the "green"). If you prefer the literal
red-then-green sequence during development: temporarily paste the PRD §5.3 buggy body into
`_resolve_z`, run the test → case 3 fails (no-match non-empty); then replace with the CORRECTION-A
OPTION C body → 5/5 pass. (Not required — the shipped test already characterizes both.)

### Integration Points

```yaml
FILESYSTEM:
  - modify: "scripts/lib/resolve.sh   (APPEND _resolve_z; sourced lib — NOT executable)"
  - create: "tests/test_resolve_z.sh   (dev unit test; executable bit optional — it has no shebang requirement but chmod +x is harmless)"

NO DATABASE / CONFIG / ROUTES / BUILD CHANGES:
  - This subtask adds one sourced function + one test. No tmux options registered (it only READS
    @zoxide-sessions-z-sh), no hooks, no keybindings. (Those belong to P1.M2/P1.M3.)
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only).

DOWNSTREAM CONSUMERS (contract this subtask guarantees):
  - S4 (resolve dispatcher, CORRECTION B): calls `_resolve_z "$1"` in the `z` branch and as the
    second leg of `auto` (`_r=$(_resolve_zoxide "$1")`; if empty, `_r=$(_resolve_z "$1")`). So
    _resolve_z MUST be defined, output a single path or empty, never crash on unset/unreadable
    z.sh, and always exit 0 — all guaranteed by this contract. Its intentional exit-0/return-0 is
    what lets S4's trailing `return 0` (CORRECTION B) compose cleanly.
  - P1.M2/P1.M3 handler scripts: call `resolve()` only (never _resolve_z directly), so they are
    decoupled from this backend's internals.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — POSIX-sh posture. MUST exit 0 with NO output.
shellcheck scripts/lib/resolve.sh
shellcheck tests/test_resolve_z.sh
# (Verified during research: exit 0, zero findings on both — OPTION C form + the unquoted-heredoc test.)

# Confirm POSIX-clean + CORRECTION-A shape by inspection. Expect NO matches for the anti-patterns:
grep -nE '\blocal\b|\[\[|==|\becho -e\b' scripts/lib/resolve.sh
# Expected: nothing prints.

# Confirm the fix is the pwd-delta form (NOT the buggy `; pwd` form). Expect exactly ONE match:
grep -nF 'o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ]' scripts/lib/resolve.sh
# Expected: the _resolve_z subshell line. (If this prints nothing, you shipped the buggy PRD form.)

# Confirm the buggy form is NOT present. Expect NO matches:
grep -nF '_z "$2" >/dev/null 2>&1; pwd' scripts/lib/resolve.sh
# Expected: nothing prints (that is the PRD §5.3 bug — it must not be in _resolve_z).

# Expected: shellcheck exits 0 silently; the anti-pattern grep prints nothing; the fix grep prints 1 line.
```

### Level 2: Unit Tests (Component Validation)

```bash
# The mocking-based unit test (item contract #5). No live rupa/z, no bats, no deps.
sh tests/test_resolve_z.sh
# Expected output ends with:  RESULTS: pass=5 fail=0   and exit code 0.
# (Verified during research: 5/5 PASS. Case 1 is the TDD false-positive characterization;
#  cases 2-5 are the fix. If case 2 fails with empty, the fake z.sh path wasn't baked — use the
#  unquoted heredoc with \$1 escaped, NOT a runtime env var (verification_notes.md §4).)

# Regression guards: S1 + S2 tests must still pass (the append touched neither prior function).
sh tests/test_resolve_get_tmux_option.sh   # S1: expect RESULTS: pass=6 fail=0, exit 0
sh tests/test_resolve_zoxide.sh            # S2: expect RESULTS: pass=3 fail=0, exit 0
```

### Level 3: Integration / Sourceability (System Validation)

```bash
# 3a. The lib sources cleanly in plain sh and ALL THREE functions are defined after sourcing.
sh -c '. scripts/lib/resolve.sh; type get_tmux_option; type _resolve_zoxide; type _resolve_z' | sed 's/is.*//'
# Expected: three lines — "get_tmux_option ", "_resolve_zoxide ", "_resolve_z ".

# 3b. Unset-option short-circuit -> empty output, no error (the dormant-by-default contract).
sh -c '. scripts/lib/resolve.sh; r=$(_resolve_z "tmux"); [ -z "$r" ] && echo "unset OK" || echo "unset FAIL"'
# Expected: unset OK  (no @zoxide-sessions-z-sh set in this bare shell -> short-circuit return 0).

# 3c. OPTIONAL live-rupa/z smoke (only meaningful if @zoxide-sessions-z-sh points at a real z.sh
#     with a populated ~/.z). Sanity check, NOT a gate (Level 2 is authoritative and machine-independent).
Z_SH=/home/dustin/.config/znap/rupa/z/z.sh
if [ -r "$Z_SH" ]; then
    live=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null)   # is the option set in YOUR tmux?
    # If unset, point _resolve_z at the real z.sh directly for the smoke:
    smoke=$(tmux set-option -gq "@zoxide-sessions-z-sh" "$Z_SH" 2>/dev/null; \
            sh -c '. scripts/lib/resolve.sh; _resolve_z "tmux"')
    [ -n "$smoke" ] && echo "live-rupa/z OK ($smoke)" || echo "live-rupa/z: empty (~/.z cold or option unreadable — acceptable)"
else
    echo "skipped live-rupa/z smoke (no z.sh at $Z_SH) — Level 2 unit test is the authoritative gate"
fi
# Expected: sourceability OK (3 funcs); unset OK; live smoke OK-or-noted-empty.
```

### Level 4: N/A

No runtime feature, performance, or security validation applies to a single sourced lookup.
Skipped intentionally (no user-facing behavior to exercise beyond Levels 1–3).

## Final Validation Checklist

### Technical Validation

- [ ] `shellcheck scripts/lib/resolve.sh` exits 0 with no output.
- [ ] `shellcheck tests/test_resolve_z.sh` exits 0 with no output.
- [ ] `sh tests/test_resolve_z.sh` prints `RESULTS: pass=5 fail=0` and exits 0.
- [ ] `sh tests/test_resolve_zoxide.sh` (S2) still passes — no regression.
- [ ] `sh tests/test_resolve_get_tmux_option.sh` (S1) still passes — no regression.
- [ ] Sourceability check (Level 3a) shows all three: `get_tmux_option`, `_resolve_zoxide`, `_resolve_z`.
- [ ] Unset-option check (Level 3b) returns empty with no error.
- [ ] Anti-pattern grep (Level 1) prints nothing; the fix-form grep prints exactly 1 line.

### Feature Validation

- [ ] All success criteria from "What" met.
- [ ] `_resolve_z` emits a real `_z` match path (case 2).
- [ ] `_resolve_z` emits **empty** on a no-match (case 3) — the core CORRECTION-A fix.
- [ ] `_resolve_z` short-circuits to empty when `@zoxide-sessions-z-sh` is unset (case 4).
- [ ] `_resolve_z` always exits 0 (case 5).
- [ ] The body uses the before/after `pwd` delta (verified by the Level-1 fix-form grep) — NOT the PRD `; pwd` form.
- [ ] The parent cwd is never changed (the lookup runs in a forked subshell).
- [ ] `get_tmux_option` and `_resolve_zoxide` are unchanged and precede `_resolve_z` in the file.

### Code Quality Validation

- [ ] Follows CORRECTION A (findings_and_risks.md §A) in the shellcheck-clean OPTION C form.
- [ ] POSIX-`sh` clean (no `local`/`[[ ]]`/arrays/`==`/`echo -e`); the only shellcheck annotation is the one mandated scoped `disable=SC2016` directive.
- [ ] Append-only — the S1+S2 head (shebang, header comment with em dash, `get_tmux_option`, `_resolve_zoxide`) is byte-preserved.
- [ ] File placement matches the desired tree (`scripts/lib/resolve.sh` modified; `tests/test_resolve_z.sh` new).
- [ ] No executable bit set on resolve.sh (sourced, not executed — S1/S2 invariant carried).
- [ ] The fake-z.sh fixture bakes its path via an unquoted heredoc (no runtime env-var propagation; SC2097/2098 avoided).

### Documentation & Deployment

- [ ] Inline doc comment documents the contract (`# _resolve_z <query> -> dir from rupa/z (_z), or empty. Always exits 0.`).
- [ ] No user-facing/config surface (internal backend helper — no README/doc changes, per item contract #6; the README 'Backends' section is authored in P1.M4.T1 and this fix makes its statement true).
- [ ] No new tmux options, hooks, or environment variables introduced (only READS `@zoxide-sessions-z-sh`).

---

## Anti-Patterns to Avoid

- ❌ Don't copy the PRD §5.3 `_resolve_z` body verbatim — it has the CONFIRMED false-positive bug (`pwd` after `_z`). Use the CORRECTION-A pwd-delta form (OPTION C).
- ❌ Don't ship the §A-verbatim form unlinted — it emits SC2209+SC2016 on shellcheck 0.11.0. Use OPTION C (quote `shell="sh"`/`shell="zsh"` + one scoped `disable=SC2016` directive). Behavior identical, lint-clean.
- ❌ Don't drop the `# shellcheck disable=SC2016` directive "to keep it clean" — without it shellcheck emits the SC2016 info and the Level-1 gate ("exit 0, no output") fails. The single quotes are intentional (inner `$1`/`$2`/`$o`/`$n` are the subshell's positional params); the directive is the idiomatic, scoped way to silence an intentional false positive.
- ❌ Don't replace the `"$shell" -c '…'` subshell with an in-process `(...)` group — that drops the PRD's zsh preference AND would still need the side-effect isolation. Keep the `"$shell" -c` form.
- ❌ Don't reference a runtime env var (`$ZFIX`) in the fake `z.sh` fixture — it must propagate across a *nested* subshell (fragile) and per-command `VAR=x cmd` assignments trip SC2097/SC2098. Bake the path via an unquoted heredoc with `\$1` escaped.
- ❌ Don't **recreate** `resolve.sh` from scratch (you'd clobber S1+S2). APPEND `_resolve_z` after `_resolve_zoxide`.
- ❌ Don't use `local` (non-POSIX), `[[ ]]`, `echo -e`, or `${var//}` — POSIX-`sh` only.
- ❌ Don't `chmod +x resolve.sh` — sourced, never executed (S1/S2 invariant).
- ❌ Don't pull in bats/shunit2/sharness — dependency-free fake-binary + fake-z.sh-fixture mock is the mandated/established pattern.
- ❌ Don't modify `.gitignore` or `PRD.md`.
- ❌ Don't pre-write `resolve` (S4, CORRECTION B) — its dispatcher defense composes on top of `_resolve_z`'s intentional exit-0/return-0.

---

## Scope Boundaries (explicit)

| Item | This subtask (S3) | Other subtasks |
| --- | --- | --- |
| `scripts/lib/resolve.sh` (file) | ✅ MODIFY (append) | S1 created it; S2 appended `_resolve_zoxide`; S4 appends `resolve` |
| shebang `#!/bin/sh` + header comment | (preserve, S1 owns) | — |
| `get_tmux_option()` | (preserve, S1 owns) | S2/S3/S4 consume it |
| `_resolve_zoxide()` (with `--` guard) | (preserve, S2 owns) | S4 consumes it |
| `_resolve_z()` (CORRECTION A, OPTION C form) | ✅ CREATE (append) | S4 consumes it |
| `resolve()` dispatcher (CORRECTION B) | ❌ DO NOT | P1.M1.T2.S4 |
| `tests/test_resolve_z.sh` | ✅ CREATE (additive dev artifact) | extends S1/S2's test pattern |
| `tmux-zoxide-sessions.tmux`, `z-window.sh`, `z-session.sh`, `README.md` | ❌ DO NOT | P1.M2 / P1.M3 / P1.M4 |
| `chmod +x` on anything | ❌ DO NOT | P1.M4.T2.S1 |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 9.5/10** — CORRECTION A is **empirically validated** on this machine (bug reproduced: no-match → plugin's own dir; fix verified: no-match → empty, match → correct path, both exit 0, under both `sh` and `zsh`). The one open gap the architecture notes left — §A was never run through shellcheck — is **surfaced and resolved**: OPTION C (quote the shell var + one scoped `disable=SC2016` directive) is verified lint-clean on shellcheck 0.11.0 and behaviorally identical to §A. The 5-case unit test is fully specified verbatim and was run during research (5/5 PASS, shellcheck-clean on both files); a subtle test-harness gotcha (env-var propagation across the nested subshell / SC2097-2098) was found and fixed by baking the fake-z.sh path via an unquoted heredoc with `\$1` escaped. Append-only / isolation / always-exit-0 / dormant-by-default boundaries are explicit. The residual half-point: `/bin/sh`→bash means strict-dash runtime behavior is observed via `shellcheck` rather than a real dash execution, and the optional live-rupa/z smoke depends on the local `~/.z` (the self-contained unit test is the authoritative, machine-independent gate that absorbs this).
