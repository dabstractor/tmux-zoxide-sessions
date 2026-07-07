# PRP — P1.M1.T2.S4: `resolve()` dispatcher — APPLY CORRECTION B

## Goal

**Feature Goal**: Append the **fourth and final** function — `resolve()` — to the shared library `scripts/lib/resolve.sh` (built up by S1 `get_tmux_option` → S2 `_resolve_zoxide` → S3 `_resolve_z`). This is the **dispatcher** and the **single resolver entry point** every consumer calls: it reads `@zoxide-sessions-backend` (default `auto`) and routes to the right backend — `zoxide` → `_resolve_zoxide`, `z` → `_resolve_z`, `auto` → try zoxide then fall back to z — then, per **CORRECTION B** (`findings_and_risks.md` §B), ends with an **unconditional `return 0`** so the documented contract ("always exits 0 — callers check output, not status") is **enforced** rather than merely commented. The PRD §5.3 body's `zoxide`/`z` branches let the backend call's exit status propagate; `auto` is already safe (its last statement is `printf`), so the direct branches are the gap the `return 0` closes.

**Deliverable**: Two artifacts —
1. `scripts/lib/resolve.sh` — **append** `resolve()` after `_resolve_z()`. Nothing else changes (shebang, header comment, `get_tmux_option`, `_resolve_zoxide`, `_resolve_z` stay byte-for-byte; `resolve` is the **last** function — the file is now complete for P1.M1.T2).
2. `tests/test_resolve_dispatcher.sh` — a dependency-free POSIX-`sh` unit test, with a **single fake `tmux`** that answers both `@zoxide-sessions-backend` (runtime `$ZS_BACKEND`, default `auto`) and `@zoxide-sessions-z-sh` (baked path), a fake `zoxide` that **exits 1 on no-match** (simulating the version-dependent non-zero exit CORRECTION B defends against), and a minimal `z.sh` fixture. Follows the TDD discipline in the item contract: case 1 proves the buggy form (no `return 0`) leaks a non-zero status; cases 2–8 assert correct output across all three backends (incl. the `auto` fallback); cases 9–14 assert exit 0 for every backend × {match, no-match}.

**Success Definition**:
- `scripts/lib/resolve.sh` contains `get_tmux_option` + `_resolve_zoxide` + `_resolve_z` (unchanged) **and** `resolve` (new, CORRECTION B), is sourceable in plain `sh`, and `resolve` is the **last** function.
- `resolve <query>` echoes the best-match directory (one path line) or **empty** on no match, and **ALWAYS exits 0** regardless of backend or backend version.
- `shellcheck scripts/lib/resolve.sh` and `shellcheck tests/test_resolve_dispatcher.sh` each exit 0 with **no** output.
- `sh tests/test_resolve_dispatcher.sh` prints `RESULTS: pass=14 fail=0` and exits 0.
- `.gitignore` and `PRD.md` are untouched; no other functions are added or modified; nothing is chmod'd.

## User Persona

**Target User**: The implementing AI agent (subtask executor); the downstream handler scripts **P1.M2.T1.S1 (`z-window.sh`)** and **P1.M3.T1.S1 (`z-session.sh`)**, which call `resolve()` as their sole frecency entry point; ultimately the end user pressing `prefix g` or creating a named session.

**Use Case**: A single, backend-agnostic entry point that turns a short query (`tmux`, `proj`) into a concrete directory for `new-window -c` / `respawn-pane -c`, selected by the user's `@zoxide-sessions-backend` option (`auto` default, or `zoxide`/`z` to force one).

**Pain Points Addressed**: `z-window.sh`/`z-session.sh` must not care *which* backend is configured, nor *whether* a given zoxide version exits non-zero on a miss. `resolve()` hides both: it dispatches by option and guarantees exit 0, so callers can do `resolved=$(resolve "$q")` and branch on emptiness alone.

## Why

- This is the **fourth and final** function in `resolve.sh` (S1 → S2 → S3 → S4) and the **only one consumers call directly**. The backends (`_resolve_zoxide`/`_resolve_z`) are internal helpers; `resolve()` is the public API for P1.M2/P1.M3. Shipping it unblocks both feature modules.
- **CORRECTION B is the whole point of this subtask.** The PRD §5.3 comment claims `resolve()` "Always exits 0 — callers must check the output, not the exit status," but the **code does not enforce it** for the `zoxide`/`z` branches: the backend call is the last statement, so its status propagates. zoxide's no-match exit code **varies by version** (findings §B); on such a version, `resolve()` with `backend=zoxide` and a no-match would exit non-zero — silently breaking any future caller that (reasonably) trusts the documented contract. One trailing `return 0` fixes it with zero behavioral cost.
- The `auto` default's **fallback** (zoxide first, then rupa/z) is what keeps the plugin working on machines **without zoxide** (PRD §4). `resolve()` is where that fallback lives, so getting the `_r=$(_resolve_zoxide "$1")` → `[ -z ]` → `_r=$(_resolve_z "$1")` → `printf` sequence exactly right is load-bearing for the no-zoxide deployment story.
- It **composes** with S3 (CORRECTION A): `_resolve_z` already exits 0 / returns 0, so the `auto` fallback's command-substitution captures the correct (possibly empty) output. CORRECTION B's `return 0` is **defense in depth on top of both backends** — it makes no assumption about either's status, exactly §B's rationale.

## What

User-visible behavior: none directly (sourced library function). Observable contract when sourced into any `sh` script:

- `resolve "<query>"` reads `@zoxide-sessions-backend` (default `auto`) via `get_tmux_option` and dispatches:
  - `zoxide` → `_resolve_zoxide "<query>"` (zoxide only);
  - `z` → `_resolve_z "<query>"` (rupa/z only);
  - `auto` → `_r=$(_resolve_zoxide "<query>")`; if `_r` is empty, `_r=$(_resolve_z "<query>")`; then `printf '%s\n' "$_r"`.
- **Always exits 0** (trailing unconditional `return 0`), regardless of which backend ran or what that backend (or its version) returned.
- Output: one absolute-path line on a match, or an empty line (`printf '%s\n' ""`) on a no-match. Callers capture via `$(resolve …)` (trailing newline stripped) and branch on emptiness.
- An **unrecognized** backend value matches no `case` branch → the function runs no backend, reaches `return 0`, prints nothing. (Matches PRD §4: only `auto`/`zoxide`/`z` are documented; unknown → empty + exit 0 is the safe no-op.)

### Success Criteria

- [ ] `scripts/lib/resolve.sh` still starts with `#!/bin/sh`, the §5.3 header comment, `get_tmux_option`, `_resolve_zoxide`, **and** `_resolve_z` — **unchanged**.
- [ ] `resolve` is **appended** after `_resolve_z`, separated by a blank line + the 6-line doc comment, and is the **last** function in the file.
- [ ] `resolve` body is the CORRECTION-B form: `backend=$(get_tmux_option "@zoxide-sessions-backend" "auto")`; `case` over `zoxide`/`z`/`auto` (the `auto` branch uses `_r=$(_resolve_zoxide "$1")` → `[ -z "$_r" ] && _r=$(_resolve_z "$1")` → `printf '%s\n' "$_r"`); **trailing `return 0`** after the `esac` (with the inline rationale comment).
- [ ] The trailing `return 0` is present (the single CORRECTION-B delta from PRD §5.3 — verified by `grep -nF 'return 0   # honor the documented contract'`).
- [ ] No `local`, no `[[ ]]`, no arrays, no `==` in `[ ]`, no `echo -e` (POSIX-clean). No shellcheck directives needed in `resolve()` itself.
- [ ] `shellcheck scripts/lib/resolve.sh` → exit 0, no output. `shellcheck tests/test_resolve_dispatcher.sh` → exit 0, no output.
- [ ] `sh tests/test_resolve_dispatcher.sh` → `RESULTS: pass=14 fail=0`, exit 0.
- [ ] `get_tmux_option`, `_resolve_zoxide`, `_resolve_z` still work after the append (re-run S1/S2/S3 tests — no regression).
- [ ] `.gitignore` / `PRD.md` unmodified (`git status --short` shows only the expected new/modified files).

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** CORRECTION B is a single `return 0` with its rationale reproduced verbatim from `findings_and_risks.md` §B (incl. why `auto` is already safe and only the direct branches are the gap). The full `resolve()` body is reproduced verbatim and was `shellcheck`-verified clean. The 14-case unit test is specified verbatim and was run during research (14/14 PASS, shellcheck-clean on both files); the one non-obvious test-design decision — the fake `zoxide` must **exit 1 on no-match** to make the exit-0 gate meaningful (the real zoxide exits 0 on this machine, but CORRECTION B defends against version-dependent non-zero) — is surfaced and justified in `research/verification_notes.md` §2. The mocking strategy (single fake `tmux` answering both option names; backend switched via `$ZS_BACKEND` env var, which propagates reliably to the direct-child `tmux`) is fully specified. `shellcheck` is the only required tool (confirmed installed). No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source for the dispatcher body and the resolver contract.
  section: "§5.3 scripts/lib/resolve.sh (the resolve() block is the BASELINE; CORRECTION B below amends it), §4 Options reference (@zoxide-sessions-backend: auto|zoxide|z; 'callers check output, not status'), h2.1/h3.0 rationale"
  critical: "The PRD §5.3 resolve() body is MISSING the trailing `return 0` (CORRECTION B). Use the CORRECTION-B form reproduced below (verbatim PRD body + one `return 0`). The CONTRACT ('returns empty on no-match, always exits 0') is what the fix must satisfy."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: Primary-source, empirically-verified analysis of the exit-status gap + the validated fix.
  section: "🟡 CORRECTION B (REQUIRED) — the 'resolve() must enforce always-exit-0' analysis + the exact `return 0` fix"
  critical: "§B explains WHY: the zoxide/z direct branches let the backend status propagate; auto's last statement (printf) is already exit 0; zoxide's no-match exit varies by version. The fix is ONE trailing `return 0`. Callers (z-session.sh `|| exit 0`, z-window.sh output-only) are already robust, but matching the documented contract prevents future regressions."

- file: plan/001_afc2c7373095/P1M1T2S3/PRP.md
  why: The S3 PRP that APPENDED _resolve_z (the function this subtask appends AFTER). Defines the file state S4 starts from and the test-harness pattern S4 extends (fake-tmux + fake-z.sh fixture).
  section: "Verbatim content to APPEND (the _resolve_z CORRECTION-A block, OPTION C form), Verbatim test block (fake-tmux + unquoted-heredoc z.sh fixture), Known Gotchas (POSIX, append-only, sourced-not-exec, the SC2016 directive)"
  critical: "ASSUME resolve.sh already has shebang + header comment + get_tmux_option + _resolve_zoxide + _resolve_z (S1+S2+S3). APPEND resolve AFTER _resolve_z. S3's _resolve_z intentionally exits 0 / returns 0, so the `auto` fallback's `_r=$(_resolve_z "$1")` captures correct output; CORRECTION B's `return 0` is defense-in-depth on top."

- file: plan/001_afc2c7373095/P1M1T2S2/PRP.md
  why: The S2 PRP that APPENDED _resolve_zoxide. Establishes the fake-binary-on-PATH + PATH-narrowing-inside-subshell test idiom S4's harness builds on.
  section: "Verbatim test block (withfake/without helpers), Known Gotchas (the PATH-prefix false-pass bug)"
  critical: "_resolve_zoxide returns zoxide's status (exit 0 on this version for match AND miss). For S4's test, the FAKE zoxide must exit 1 on no-match to make CORRECTION B testable (see research/verification_notes.md §2). Reuse S2's `. "$0" >/dev/null; PATH="$bin:$PATH"; f` subshell idiom."

- docfile: plan/001_afc2c7373095/P1M1T2S4/research/verification_notes.md
  why: Empirical proof grounding every gate: CORRECTION B = one `return 0`; the fake-zoxide-exit-1 rationale; the $ZS_BACKEND env-var mocking approach; the 14-case matrix (14/14 PASS); the distinct-keyword discrimination.
  section: "§1 what CORRECTION B is, §2 why fake zoxide exits 1, §3 mocking strategy, §4 backend discrimination, §5 empirical results, §6 composition with S3 + downstream"
  critical: "§2 is the crux: a fake zoxide that exits 0 on no-match makes the exit-0 gate a SILENT FALSE PASS (the red case can never fail). It MUST exit 1 to simulate the version-dependent non-zero exit CORRECTION B defends against. §3: switch backends via $ZS_BACKEND env var (single fake tmux; tmux is a direct child so one export propagates — no SC2097/2098 trap)."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State AFTER S1 + S2 + S3 have run (treat as contract — S4 appends to this):
$ ls scripts/lib tests 2>/dev/null
scripts/lib:
resolve.sh          # S1: shebang+header+get_tmux_option ; S2: + _resolve_zoxide ; S3: + _resolve_z  (3 funcs, 24 lines)
tests:
test_resolve_get_tmux_option.sh   # S1's fake-tmux unit test (pattern S4 extends)
test_resolve_zoxide.sh            # S2's fake-zoxide unit test (pattern S4 extends)
test_resolve_z.sh                 # S3's fake-z.sh unit test (pattern S4 extends)

# resolve.sh currently ENDS with _resolve_z (the last function). resolve is NOT yet present.

# Tooling on this machine (the unit test is self-contained — these are for the optional smoke):
$ command -v shellcheck zsh sh tmux zoxide
/usr/bin/shellcheck            # ✅ required lint gate (v0.11.0)
/usr/bin/zsh                   # ✅ present -> _resolve_z takes the zsh code path at runtime
/bin/sh -> bash                # dev note: dash-strictness observed via shellcheck, not runtime
/usr/bin/tmux                  # ✅ (optional live smoke only)
/home/dustin/.local/bin/zoxide # ✅ (optional live smoke only; fakes shadow it in the test)
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  scripts/
    lib/
      resolve.sh             # MODIFIED — APPEND resolve() after _resolve_z()  (now 4 funcs)
  tests/
    test_resolve_get_tmux_option.sh   # (S1, unchanged — re-run to confirm no regression)
    test_resolve_zoxide.sh            # (S2, unchanged — re-run to confirm no regression)
    test_resolve_z.sh                 # (S3, unchanged — re-run to confirm no regression)
    test_resolve_dispatcher.sh        # NEW — fake-tmux + fake-zoxide(exit-1) + fake-z.sh unit test (14 cases)
```

`resolve.sh` now holds **four** functions: `get_tmux_option`, `_resolve_zoxide`, `_resolve_z`, `resolve`. The file is **complete** for P1.M1.T2; P1.M2/P1.M3 source it and call `resolve()` only.

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE FIX): PRD §5.3 resolve() is MISSING the trailing `return 0`. Its zoxide/z
#   branches' LAST statement is the backend call, whose status propagates as resolve's.
#   auto's last statement is printf (always exit 0) -> auto is ALREADY safe; the gap is the
#   two DIRECT branches. CORRECTION B = ONE unconditional `return 0` after the `esac`. DO NOT
#   ship the PRD form without it. Do NOT add any other defense (no `|| true`, no per-branch
#   `return 0`) — the single trailing `return 0` is the mandated, minimal, lint-clean fix.

# CRITICAL (TEST DESIGN — the fake zoxide MUST exit 1 on no-match): the REAL zoxide on this
#   machine exits 0 on a no-match (findings §5). If the fake zoxide also exited 0, then
#   resolve() WITHOUT `return 0` would already exit 0 -> the TDD red case could NEVER fail
#   -> CORRECTION B would be untestable (silent false pass). CORRECTION B exists BECAUSE
#   "zoxide exit code on no-match varies by version" (§B). So the fake zoxide DELIBERATELY
#   exits 1 on no-match to SIMULATE that version-dependent non-zero exit. Then: buggy form
#   (no return 0) leaks 1 (red); shipped form (return 0) overrides to 0 (green). Output
#   assertions are unaffected by exit code. Copy the fake zoxide verbatim.

# CRITICAL (MOCKING — backend via $ZS_BACKEND env var): ONE fake tmux answers BOTH option
#   names (@zoxide-sessions-backend -> ${ZS_BACKEND:-auto}; @zoxide-sessions-z-sh -> baked
#   $ZSH path). Switch backends per case by exporting ZS_BACKEND INSIDE the sh -c subshell.
#   tmux is a DIRECT CHILD of the shell running resolve, so one export propagates reliably —
#   NO SC2097/SC2098 trap (those only bite `VAR=x cmd` per-command assignments across NESTED
#   subshells, the S3 gotcha). This is cleaner than 3 separate fake-tmux binaries.

# CRITICAL (APPEND only): preserve S1+S2+S3 content byte-for-byte — shebang `#!/bin/sh`, the
#   2-line header comment WITH its U+2014 em dash, get_tmux_option, _resolve_zoxide, _resolve_z
#   (incl. its `# shellcheck disable=SC2016` directive). Insert resolve AFTER _resolve_z,
#   separated by a blank line + the 6-line doc comment. resolve is the LAST function.

# CRITICAL (DISCRIMINATE backends): the fake zoxide matches `proj` -> /home/user/projects/proj;
#   the fake z.sh _z matches `work` -> $ZFIX/work. DISTINCT keywords/paths let `auto + work`
#   prove the FALLBACK genuinely returns z's path (not zoxide's) — a real assertion, not a
#   tautology. Do NOT make both fakes match the same keyword.

# GOTCHA: Do NOT chmod +x resolve.sh — SOURCED, never executed (S1/S2/S3 invariant; carried).
# GOTCHA: POSIX sh — NO `local`. `resolve` uses `backend`/`_r` as scratch vars (global namespace
#   is acceptable in a sourced lib; matches get_tmux_option's `_v`, _resolve_z's `z_sh`/`shell`).
#   Avoid [[ ]], arrays, `==` in [ ], `echo -e`, ${var//}.
# GOTCHA: No test framework exists. Do NOT pull in bats/shunit2. The mandated approach is a
#   dependency-free fake-binary-on-PATH mock (item contract #5), extending the S1/S2/S3 pattern.
# GOTCHA: `_r` and `backend` are reused global scratch names; since resolve.sh is sourced into a
#   script that may ALSO define its own vars, prefer the underscore-prefixed `_r` (already used)
#   and accept `backend` as a short-lived dispatcher local-in-spirit (matches PRD §5.3 verbatim).
# GOTCHA: `/bin/sh` -> bash on THIS dev machine (dash-strictness via shellcheck, not runtime).

# FORBIDDEN: Do NOT modify .gitignore or PRD.md.
# FORBIDDEN: Do NOT chmod anything, and do NOT modify get_tmux_option, _resolve_zoxide, _resolve_z,
#   or the S1/S2/S3 tests.
# FORBIDDEN: Do NOT add a per-branch `return 0`, `|| true`, or extra shellcheck directives to
#   resolve(). The single trailing `return 0` (after esac) is the mandated form.
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The only "structure" is the function's positional-parameter contract:
`$1` = query keyword (e.g. `tmux`). Output via stdout only (one absolute-path line on a match,
or one empty line on a no-match). Exit status always 0.

### Verbatim content to APPEND to `scripts/lib/resolve.sh`

`scripts/lib/resolve.sh` already exists from S1+S2+S3 with this tail (do not rewrite it; `…` =
the S1/S2 functions above, unchanged):
```sh
… (shebang, header comment, get_tmux_option — S1 ; _resolve_zoxide — S2) …

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
**Append** exactly the following block (one blank line + 6-line doc comment + function) after `_resolve_z`.
This is the **verbatim PRD §5.3 `resolve()` body + the single CORRECTION-B `return 0`**:
```sh

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
    return 0   # honor the documented contract regardless of backend exit status
}
```
> Implementing agent: this is **PRD §5.3 verbatim + exactly one new line** (`    return 0   # …`).
> Do **not** add `local`, per-branch `return 0`, `|| true`, shellcheck directives, or other
> functions. Do **not** "improve" the `auto` branch (the `_r` capture → `[ -z ]` → fallback →
> `printf` is the documented fallback contract). The `return 0` MUST be the **last** statement
> in the function (after the `esac`), so it overrides any status that propagated from a backend.

#### Why each piece is exactly so (do not "improve" it)

```sh
# backend=$(get_tmux_option "@zoxide-sessions-backend" "auto")
#   Read the backend option via the S1 helper (default "auto" when unset/empty). PRD §4 verbatim.
# case "$backend" in
#   zoxide) _resolve_zoxide "$1" ;;        # zoxide-only branch. LAST stmt = backend call -> status
#   z)      _resolve_z "$1" ;;             # rupa/z-only branch.  LAST stmt = backend call -> status
#   auto)                                  # default: zoxide first, z fallback
#     _r=$(_resolve_zoxide "$1")           # capture zoxide output (status discarded by $())
#     [ -z "$_r" ] && _r=$(_resolve_z "$1")# fallback to rupa/z only if zoxide was empty
#     printf '%s\n' "$_r"                  # emit (path or empty line); LAST stmt = printf -> exit 0
#     ;;
# esac
# return 0   # CORRECTION B: override any status that propagated from a DIRECT backend branch
#            # (zoxide/z). auto is already exit 0 (printf), but the `return 0` covers it too.
#            # "callers check output, not status" (PRD §4) is now ENFORCED, not just commented.
```

### Verbatim content for `tests/test_resolve_dispatcher.sh`

Write **exactly** this. It is self-verifying (prints `PASS`/`FAIL`, exits non-zero on any
failure) and was run during research: `RESULTS: pass=14 fail=0`, exit 0; shellcheck-clean on
both files. (Validated in an isolated `/tmp` copy — the repo was not modified during research.)

```sh
#!/bin/sh
# Unit tests for resolve() dispatcher (P1.M1.T2.S4 — CORRECTION B).
# TDD discipline: case 1 demonstrates that WITHOUT the trailing `return 0`, a
# zoxide no-match (simulated non-zero exit) propagates as resolve's exit status
# (the bug); cases 2-8 prove correct output, and cases 9-14 prove exit 0 for
# every backend x {match, no-match} (the CORRECTION-B contract).
# Strategy: one fake `tmux` answers @zoxide-sessions-backend (from $ZS_BACKEND,
# default auto) and @zoxide-sessions-z-sh (baked path); a fake `zoxide` matches
# `proj` and exits 1 on no-match (simulates the version-dependent non-zero exit
# CORRECTION B defends against); a minimal `z.sh` fixture makes _z match `work`.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- minimal z.sh fixture: _z cds on `work`, no-op on a miss -----------------
ZFIX="$REPO_ROOT/tests/.zfix4"
ZSH="$ZFIX/z.sh"
mkdir -p "$ZFIX/work"
cat > "$ZSH" <<ZSH
_z() {
    case "\$1" in
        work) cd "$ZFIX/work" 2>/dev/null || cd / ;;
        *) ;;  # no-op on miss -> cwd unchanged
    esac
}
ZSH

# --- fake tmux: answers @zoxide-sessions-backend ($ZS_BACKEND, default auto)
#     and @zoxide-sessions-z-sh (baked $ZSH path) ----------------------------
TBIN="$REPO_ROOT/tests/.tbin4"
mkdir -p "$TBIN"
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
# Fake tmux implementing ONLY: tmux show-option -gqv <name>
if [ "\$1" = "show-option" ]; then
    shift
    name=""
    while [ \$# -gt 0 ]; do
        case "\$1" in -*) ;; *) name="\$1"; break ;; esac
        shift
    done
    case "\$name" in
        @zoxide-sessions-backend) printf '%s\n' "\${ZS_BACKEND:-auto}" ;;
        @zoxide-sessions-z-sh)    printf '%s\n' "$ZSH" ;;
        *)                        printf '' ;;
    esac
fi
exit 0
TMUX
chmod +x "$TBIN/tmux"

# --- fake zoxide: matches `proj` (exit 0); no-match -> empty + exit 1 --------
# (exit 1 on no-match simulates the version-dependent non-zero exit that
#  CORRECTION B's trailing `return 0` defends against — findings_and_risks.md §B)
cat > "$TBIN/zoxide" <<'ZOXIDE'
#!/bin/sh
# Fake zoxide implementing ONLY: zoxide query [--] <keyword>
[ "$1" = "query" ] || exit 0
shift
[ "${1:-}" = "--" ] && shift        # honor the end-of-options guard
kw="$1"
case "$kw" in
    proj) printf '%s\n' "/home/user/projects/proj"; exit 0 ;;   # MATCH
    *)    printf ''; exit 1 ;;                                   # no-match: empty + NON-zero
esac
ZOXIDE
chmod +x "$TBIN/zoxide"

cleanup() { rm -rf "$ZFIX" "$TBIN"; }
trap cleanup EXIT INT TERM

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# resolve stdout, with the backend selected via $ZS_BACKEND and fakes on PATH.
rout() {  # rout <backend> <query>
    sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3"' \
        "$RESOLVE" "$1" "$TBIN" "$2"
}
# resolve exit code (output discarded).
rexit() {  # rexit <backend> <query>
    sh -c '. "$0"; ZS_BACKEND="$1"; export ZS_BACKEND; PATH="$2:$PATH"; resolve "$3" >/dev/null 2>&1; echo $?' \
        "$RESOLVE" "$1" "$TBIN" "$2" | tail -1
}

# --- case 1: BUGGY form (no trailing return 0) -> zoxide no-match propagates -
# non-zero (the CORRECTION-B bug). Fake zoxide exits 1 on no-match, so a resolve
# WITHOUT `return 0` lets that status leak out of the zoxide branch.
buggy_rc=$(sh -c '
    . "$0"
    ZS_BACKEND="$1"; export ZS_BACKEND
    PATH="$2:$PATH"
    buggy_resolve() {
        backend=$(get_tmux_option "@zoxide-sessions-backend" "auto")
        case "$backend" in
            zoxide) _resolve_zoxide "$1" ;;
            z)      _resolve_z "$1" ;;
            auto)
                _r=$(_resolve_zoxide "$1")
                [ -z "$_r" ] && _r=$(_resolve_z "$1")
                printf "%s\n" "$_r"
                ;;
        esac
    }
    buggy_resolve "$3" >/dev/null 2>&1
    echo $?
' "$RESOLVE" zoxide "$TBIN" zzz)
check "buggy form (no return 0) leaks non-zero on zoxide no-match" "NONZERO" \
    "$( [ "$buggy_rc" != "0" ] && echo NONZERO || echo zero )"

# --- cases 2-3: zoxide backend -----------------------------------------------
check "zoxide match echoes the path"   "/home/user/projects/proj" "$(rout zoxide proj)"
check "zoxide no-match echoes empty"   ""                          "$(rout zoxide zzz)"

# --- cases 4-5: z backend ----------------------------------------------------
check "z match echoes the path"        "$ZFIX/work"                "$(rout z work)"
check "z no-match echoes empty"        ""                          "$(rout z zzz)"

# --- cases 6-8: auto backend (zoxide first, z fallback) ----------------------
check "auto match (zoxide) echoes path"    "/home/user/projects/proj" "$(rout auto proj)"
check "auto no-match echoes empty"          ""                          "$(rout auto zzz)"
check "auto fallback (zoxide miss->z) path" "$ZFIX/work"                "$(rout auto work)"

# --- exit-0 for every backend x {match, no-match} (CORRECTION B contract) ----
check "exit 0: zoxide match"      "0" "$(rexit zoxide proj)"
check "exit 0: zoxide no-match"   "0" "$(rexit zoxide zzz)"
check "exit 0: z match"           "0" "$(rexit z work)"
check "exit 0: z no-match"        "0" "$(rexit z zzz)"
check "exit 0: auto match"        "0" "$(rexit auto proj)"
check "exit 0: auto no-match"     "0" "$(rexit auto zzz)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

> The test is **self-contained** (no live tmux/zoxide/rupa-z): one fake `tmux` answers both
> option names; the fake `zoxide` **exits 1 on no-match** (the crux — see Known Gotchas +
> verification_notes §2 — without it the exit-0 gate is a silent false pass); the fake `z.sh`
> reproduces only the two `_z` semantics (cd on match, no-op on miss). **Case 1** runs a
> `buggy_resolve` (PRD §5.3 form WITHOUT `return 0`) inline and asserts it leaks non-zero on a
> zoxide no-match — the TDD "red". **Cases 2–8** run the shipped `resolve` and assert correct
> output (incl. the `auto` fallback returning z's distinct path). **Cases 9–14** assert exit 0
> for all three backends × {match, no-match} — the CORRECTION-B contract.

### Implementation Tasks (ordered by dependencies — TDD red→green)

```yaml
Task 1: MODIFY scripts/lib/resolve.sh  (APPEND resolve — CORRECTION B)
  - FILE: scripts/lib/resolve.sh (exists from S1+S2+S3 with get_tmux_option + _resolve_zoxide + _resolve_z; do NOT recreate the head)
  - ACTION: append the verbatim block above (blank line + 6-line doc comment + function) AFTER _resolve_z.
  - FORM: the verbatim PRD §5.3 resolve() body + the single CORRECTION-B line `    return 0   # honor the documented contract regardless of backend exit status`
          placed AFTER the `esac` as the function's last statement.
  - DISPATCH: backend via get_tmux_option "@zoxide-sessions-backend" "auto"; case over zoxide/z/auto; auto = _r=$(_resolve_zoxide "$1"); [ -z "$_r" ] && _r=$(_resolve_z "$1"); printf '%s\n' "$_r".
  - NAMING: function resolve (no underscore = the public entry point consumed by z-window.sh/z-session.sh).
  - PRESERVE: shebang, header comment (em dash), get_tmux_option, _resolve_zoxide, _resolve_z (incl. its SC2016 directive) — byte-for-byte.
  - STOP: do NOT add other functions. Do NOT chmod +x. Do NOT add per-branch return 0 / || true / directives.

Task 2: CREATE tests/test_resolve_dispatcher.sh
  - FILE: tests/test_resolve_dispatcher.sh
  - CONTENT: the verbatim block above (one fake tmux answering both option names; fake zoxide exit-1-on-no-match; minimal z.sh fixture; 14 cases incl. the TDD buggy-form characterization).
  - NAMING: test_resolve_dispatcher.sh (resolve is the dispatcher/entry point; extends the test_resolve_<function>.sh pattern).
  - PLACEMENT: tests/ at repo root (dev-only; not in PRD §5.1 ship tree — additive, like S1/S2/S3).
  - COVERAGE: (1) buggy form no-match -> NON-zero exit [TDD red]; (2-8) output for zoxide/z/auto × {match,no-match} + auto fallback; (9-14) exit 0 for all three backends × {match,no-match}.
  - CRITICAL: the fake zoxide MUST `exit 1` on no-match (else the exit-0 gate is a silent false pass — verification_notes §2). Switch backends via $ZS_BACKEND env var (exported inside the sh -c). Copy verbatim.
  - SELF-VERIFY: prints PASS/FAIL per case; exits non-zero on any failure; cleans up fixture/bin dirs via trap.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: shellcheck scripts/lib/resolve.sh                       # expect exit 0, NO output
  - RUN: shellcheck tests/test_resolve_dispatcher.sh             # expect exit 0, NO output
  - RUN: sh tests/test_resolve_dispatcher.sh                     # expect "RESULTS: pass=14 fail=0", exit 0
  - RUN: sh tests/test_resolve_z.sh                              # S3 test still passes (no regression)
  - RUN: sh tests/test_resolve_zoxide.sh                         # S2 test still passes (no regression)
  - RUN: sh tests/test_resolve_get_tmux_option.sh                # S1 test still passes (no regression)
  - RUN: sh -c '. scripts/lib/resolve.sh; type get_tmux_option; type _resolve_zoxide; type _resolve_z; type resolve'  # all 4 present
  - RUN: grep -nF 'return 0   # honor the documented contract' scripts/lib/resolve.sh     # expect exactly 1 match (CORRECTION B)
  - RUN: grep -nE '\blocal\b|\[\[|==|\becho -e\b' scripts/lib/resolve.sh     # expect NO matches
  - RUN: git status --short                          # only expected new/modified files; PRD.md/.gitignore untouched
```

#### TDD note (red → green)

The item contract asks: *"assert exit status is 0 for every backend on both match and no-match."*
The shipped test realizes the TDD discipline as a single self-verifying script: **case 1** runs a
`buggy_resolve` (PRD §5.3 WITHOUT the trailing `return 0`) inline and asserts it leaks a **non-zero**
exit on a zoxide no-match — proving the gap exists and is understood (the "red"). **Cases 9–14** run
the shipped `resolve` (WITH `return 0`) and assert exit 0 for all three backends × {match, no-match}
(the "green"). The fake `zoxide` deliberately exits 1 on no-match to make this *meaningful* (the real
zoxide exits 0 on this machine, but CORRECTION B defends against version-dependent non-zero — see
verification_notes §2). If you prefer the literal red-then-green sequence during development:
temporarily delete the trailing `return 0` from `resolve`, run the test → case 10 (`exit 0: zoxide
no-match`) fails (got=1); then re-add the `return 0` → 14/14 pass. (Not required — the shipped test
already characterizes both.)

### Implementation Patterns & Key Details

```sh
# The single pattern this subtask establishes — the backend-agnostic resolver entry point:
#   resolved=$(resolve "$query")
#   [ -n "$resolved" ] && cd "$resolved"   # (or new-window -c / respawn-pane -c)
#
# Why the trailing `return 0` (CORRECTION B, the ENTIRE point):
#   - The zoxide/z branches' LAST statement is the backend call; its status propagates.
#   - zoxide's no-match exit code VARIES BY VERSION (some exit 1). On such a version, a direct
#     `zoxide`-backend resolve on a no-match would exit non-zero, breaking any caller that
#     trusts the documented "always exits 0" contract. One `return 0` (after esac) overrides it.
#   - auto's last statement is printf (exit 0), so auto is already safe — but the `return 0`
#     covers it too (defense in depth; uniform contract across all branches).
#
# Why the `auto` fallback uses command substitution (`_r=$(...)`):
#   - `$()` DISCARDS the inner command's exit status, capturing only stdout. So a zoxide
#     no-match (empty output, possibly exit 1) becomes `_r=""` with no status leak. Then
#     `[ -z "$_r" ] && _r=$(_resolve_z "$1")` falls back to rupa/z. This is why auto is
#     exit-status-safe even WITHOUT CORRECTION B (the direct branches are the real gap).
#
# Why NO per-branch `return 0` / `|| true`:
#   - The single trailing `return 0` is minimal, uniform, and lint-clean. Per-branch defense
#     would deviate from the PRD §5.3 structure (which S2 deliberately left bare in
#     _resolve_zoxide) and is unnecessary. CORRECTION B owns ALL exit-status normalization,
#     at the dispatcher, exactly once.
#
# Why `printf '%s\n' "$_r"` (not `echo`):
#   - POSIX: `echo` behavior is unspecified for `-n`/`-e` args and backslashes; `printf '%s\n'`
#     is portable. Emitting a trailing newline (even for empty `_r`) is correct — callers use
#     `$(resolve …)` which strips it, so empty `_r` -> captured "". Matches get_tmux_option's
#     `echo` only because that helper's values are never flag-like; resolve's output is a path,
#     but `printf` is the safe choice for the dispatcher (precedent: _resolve_z uses printf).
```

### Integration Points

```yaml
FILESYSTEM:
  - modify: "scripts/lib/resolve.sh   (APPEND resolve; sourced lib — NOT executable; resolve is the LAST function)"
  - create: "tests/test_resolve_dispatcher.sh   (dev unit test; executable bit optional — chmod +x is harmless)"

NO DATABASE / CONFIG / ROUTES / BUILD CHANGES:
  - This subtask adds one sourced function + one test. It only READS @zoxide-sessions-backend
    (no new tmux options, no hooks, no keybindings). (Wiring belongs to P1.M2/P1.M3.)
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only).

DOWNSTREAM CONSUMERS (contract this subtask guarantees — the whole point of S4):
  - P1.M2.T1.S1 (z-window.sh): calls `resolved=$(resolve "$query")` and branches on
    `[ -n "$resolved" ]` (PRD §5.4). Guaranteed: one path line on match, empty on no-match,
    exit 0 always (so `$(resolve …)` never aborts a `set -e` caller).
  - P1.M3.T1.S1 (z-session.sh): calls `resolved=$(resolve "$name") || exit 0` (PRD §5.5).
    The `|| exit 0` is belt-and-suspenders WITH CORRECTION B (resolve already exits 0); without
    CORRECTION B it would be load-bearing on a non-zero-exiting zoxide version. Both consumers
    are decoupled from the backends — they call resolve() only.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — POSIX-sh posture. MUST exit 0 with NO output.
shellcheck scripts/lib/resolve.sh
shellcheck tests/test_resolve_dispatcher.sh
# (Verified during research: exit 0, zero findings on both.)

# Confirm POSIX-clean + CORRECTION-B shape by inspection. Expect NO matches for the anti-patterns:
grep -nE '\blocal\b|\[\[|==|\becho -e\b' scripts/lib/resolve.sh
# Expected: nothing prints.

# Confirm CORRECTION B is present (the single fix). Expect exactly ONE match:
grep -nF 'return 0   # honor the documented contract' scripts/lib/resolve.sh
# Expected: one line (inside resolve, after esac). (If this prints nothing, you shipped the buggy PRD form.)

# Confirm resolve() exists and is the LAST function. Expect the resolve() line number > the
# _resolve_z() line number:
grep -nE '^(resolve|_resolve_z)\(\)' scripts/lib/resolve.sh
# Expected: two lines, resolve() after _resolve_z().

# Expected: shellcheck exits 0 silently; the anti-pattern grep prints nothing; the fix grep prints 1 line.
```

### Level 2: Unit Tests (Component Validation)

```bash
# The mocking-based unit test (item contract #5). No live tmux/zoxide/rupa-z, no bats, no deps.
sh tests/test_resolve_dispatcher.sh
# Expected output ends with:  RESULTS: pass=14 fail=0   and exit code 0.
# (Verified during research: 14/14 PASS. Case 1 is the TDD no-return-0 characterization;
#  cases 2-8 are output (incl. the auto fallback); cases 9-14 are exit-0 for all backends x {match,no-match}.
#  If case 10 (exit 0: zoxide no-match) fails with got=[1], the trailing `return 0` is missing — re-add it.
#  If case 1 fails with got=[zero], the fake zoxide is exiting 0 on no-match — make it `exit 1` (verification_notes §2).)

# Regression guards: S1 + S2 + S3 tests must still pass (the append touched no prior function).
sh tests/test_resolve_get_tmux_option.sh   # S1: expect RESULTS: pass=6 fail=0, exit 0
sh tests/test_resolve_zoxide.sh            # S2: expect RESULTS: pass=3 fail=0, exit 0
sh tests/test_resolve_z.sh                 # S3: expect RESULTS: pass=5 fail=0, exit 0
```

### Level 3: Integration / Sourceability (System Validation)

```bash
# 3a. The lib sources cleanly in plain sh and ALL FOUR functions are defined after sourcing.
sh -c '. scripts/lib/resolve.sh; type get_tmux_option; type _resolve_zoxide; type _resolve_z; type resolve' | sed 's/is.*//'
# Expected: four lines — "get_tmux_option ", "_resolve_zoxide ", "_resolve_z ", "resolve ".

# 3b. Unknown-backend -> empty output, exit 0 (the safe no-op; PRD §4 documents only auto/zoxide/z).
sh -c '. scripts/lib/resolve.sh; r=$(resolve "tmux" 2>/dev/null); rc=$?; [ -z "$r" ] && [ "$rc" = 0 ] && echo "unknown-backend OK" || echo "unknown-backend FAIL (r=[$r] rc=$rc)"'
# NOTE: this bare shell has NO @zoxide-sessions-backend set -> get_tmux_option returns default "auto".
# To truly test the unknown-backend path, point at a tmux that returns e.g. "bogus" — the unit test's
# fake-tmux harness does this implicitly via $ZS_BACKEND. Here, expect "auto" default behavior.

# 3c. resolve always exits 0 even when a backend would exit non-zero (the CORRECTION-B contract,
#     demonstrated against a hostile backend). Uses the unit test's fake-zoxide-exit-1 idiom inline:
TBIN=$(mktemp -d)
cat > "$TBIN/zoxide" <<'Z'
#!/bin/sh
[ "$1" = "query" ] && shift && [ "${1:-}" = "--" ] && shift
printf ''; exit 1   # no-match -> empty + NON-zero (hostile version)
Z
chmod +x "$TBIN/zoxide"
cat > "$TBIN/tmux" <<'T'
#!/bin/sh
printf '%s\n' zoxide   # force the zoxide (direct) branch
T
chmod +x "$TBIN/tmux"
sh -c '. scripts/lib/resolve.sh; PATH="'"$TBIN"':$PATH"; resolve "nomatch" >/dev/null 2>&1; echo rc=$?'
# Expected: rc=0   (CORRECTION B overrides the fake zoxide's exit 1). Without `return 0` this prints rc=1.
rm -rf "$TBIN"

# 3d. OPTIONAL live smoke (only meaningful with a populated zoxide DB). Sanity check, NOT a gate.
if command -v zoxide >/dev/null 2>&1; then
    live=$(sh -c '. scripts/lib/resolve.sh; resolve "tmux"'); rc=$?
    [ -n "$live" ] && echo "live-resolve OK ($live, rc=$rc)" || echo "live-resolve: empty (DB cold — acceptable, rc=$rc)"
else
    echo "skipped live-resolve smoke (no zoxide) — Level 2 unit test is the authoritative gate"
fi
# Expected: sourceability OK (4 funcs); hostile-backend rc=0; live smoke OK-or-noted-empty.
```

### Level 4: N/A

No runtime feature, performance, or security validation applies to a single sourced dispatcher.
Skipped intentionally (no user-facing behavior to exercise beyond Levels 1–3; the dispatcher's
"feature" is exit-0 normalization, fully covered by Level 2 cases 9–14 + Level 3c).

## Final Validation Checklist

### Technical Validation

- [ ] `shellcheck scripts/lib/resolve.sh` exits 0 with no output.
- [ ] `shellcheck tests/test_resolve_dispatcher.sh` exits 0 with no output.
- [ ] `sh tests/test_resolve_dispatcher.sh` prints `RESULTS: pass=14 fail=0` and exits 0.
- [ ] `sh tests/test_resolve_z.sh` (S3) still passes — no regression.
- [ ] `sh tests/test_resolve_zoxide.sh` (S2) still passes — no regression.
- [ ] `sh tests/test_resolve_get_tmux_option.sh` (S1) still passes — no regression.
- [ ] Sourceability check (Level 3a) shows all four: `get_tmux_option`, `_resolve_zoxide`, `_resolve_z`, `resolve`.
- [ ] Hostile-backend check (Level 3c) prints `rc=0` (CORRECTION B overrides a non-zero backend).
- [ ] Anti-pattern grep (Level 1) prints nothing; the CORRECTION-B grep prints exactly 1 line.

### Feature Validation

- [ ] All success criteria from "What" met.
- [ ] `resolve` echoes a match path for `zoxide`/`z`/`auto` backends on a match (cases 2, 4, 6).
- [ ] `resolve` echoes **empty** on a no-match for all three backends (cases 3, 5, 7).
- [ ] `auto` falls back from zoxide to z and returns **z's distinct path** (case 8 — the fallback works).
- [ ] `resolve` **always exits 0** for all three backends × {match, no-match} (cases 9–14) — the core CORRECTION-B contract.
- [ ] The buggy form (no `return 0`) demonstrably leaks non-zero (case 1 — the TDD red).
- [ ] The trailing `return 0` is the function's last statement, after the `esac` (verified by the Level-1 grep).
- [ ] `resolve` is the **last** function in the file (after `_resolve_z`); `get_tmux_option`/`_resolve_zoxide`/`_resolve_z` precede it, unchanged.

### Code Quality Validation

- [ ] Follows CORRECTION B (findings_and_risks.md §B) — verbatim PRD §5.3 body + one trailing `return 0`.
- [ ] POSIX-`sh` clean (no `local`/`[[ ]]`/arrays/`==`/`echo -e`); no shellcheck directives added to `resolve()`.
- [ ] Append-only — the S1+S2+S3 head (shebang, header comment with em dash, `get_tmux_option`, `_resolve_zoxide`, `_resolve_z` incl. its SC2016 directive) is byte-preserved.
- [ ] File placement matches the desired tree (`scripts/lib/resolve.sh` modified; `tests/test_resolve_dispatcher.sh` new).
- [ ] No executable bit set on resolve.sh (sourced, not executed — S1/S2/S3 invariant carried).
- [ ] The fake `zoxide` exits 1 on no-match (making the exit-0 gate meaningful, not a silent false pass).
- [ ] The fake `tmux` answers both `@zoxide-sessions-backend` and `@zoxide-sessions-z-sh`; backends switched via `$ZS_BACKEND` env var.

### Documentation & Deployment

- [ ] Inline doc comment documents the contract (`# resolve <query> -> … Always exits 0 — callers must check the output, not the exit status.`).
- [ ] No user-facing/config surface (internal dispatcher — no README/doc changes, per item contract #6; the README 'Backends'/'Options' sections are authored in P1.M4.T1).
- [ ] No new tmux options, hooks, or environment variables introduced (only READS `@zoxide-sessions-backend`).

---

## Anti-Patterns to Avoid

- ❌ Don't copy the PRD §5.3 `resolve()` body **without** the trailing `return 0` — that is the CONFIRMED gap (CORRECTION B). Add exactly one `return 0` after the `esac`.
- ❌ Don't make the fake `zoxide` exit 0 on no-match "to match reality" — the real zoxide exits 0 on this machine (findings §5), but CORRECTION B defends against *version-dependent non-zero*. A fake that exits 0 makes the exit-0 gate a silent false pass (case 1 can never fail). The fake MUST `exit 1` on no-match (verification_notes §2).
- ❌ Don't add per-branch `return 0`, `|| true`, or shellcheck directives to `resolve()`. The single trailing `return 0` (after esac) is the mandated, minimal, lint-clean fix. S2 deliberately left `_resolve_zoxide` bare; CORRECTION B owns all exit-status normalization, once, at the dispatcher.
- ❌ Don't "improve" the `auto` branch — the `_r=$(_resolve_zoxide "$1")` → `[ -z "$_r" ] && _r=$(_resolve_z "$1")` → `printf '%s\n' "$_r"` sequence is the documented fallback contract. (The `$()` discards zoxide's status, which is exactly why `auto` is already exit-0-safe.)
- ❌ Don't make both fakes match the **same** keyword — `auto + work` must return **z's** distinct path (`$ZFIX/work`), not zoxide's, to prove the fallback genuinely fires. Use `proj` (zoxide) vs `work` (z).
- ❌ Don't use 3 separate fake-`tmux` binaries (one per backend) — one fake `tmux` answering both option names, with the backend switched via `$ZS_BACKEND` env var, is cleaner and reliable (`tmux` is a direct child; one export propagates — no SC2097/2098 trap).
- ❌ Don't write the backend-selection test as `ZS_BACKEND=x sh -c '…'` (per-command prefix) if it also needs to spawn nested subshells — export it INSIDE the `sh -c` instead (`ZS_BACKEND="$1"; export ZS_BACKEND`). (Not strictly necessary here since tmux is a direct child, but `export` inside is the robust idiom matching S3.)
- ❌ Don't **recreate** `resolve.sh` from scratch (you'd clobber S1+S2+S3). APPEND `resolve` after `_resolve_z`.
- ❌ Don't use `local` (non-POSIX), `[[ ]]`, `echo -e`, or `${var//}` — POSIX-`sh` only.
- ❌ Don't `chmod +x resolve.sh` — sourced, never executed (S1/S2/S3 invariant).
- ❌ Don't pull in bats/shunit2/sharness — dependency-free fake-binary mock is the mandated/established pattern.
- ❌ Don't modify `.gitignore` or `PRD.md`.

---

## Scope Boundaries (explicit)

| Item | This subtask (S4) | Other subtasks |
| --- | --- | --- |
| `scripts/lib/resolve.sh` (file) | ✅ MODIFY (append) | S1 created it; S2 appended `_resolve_zoxide`; S3 appended `_resolve_z` |
| shebang `#!/bin/sh` + header comment | (preserve, S1 owns) | — |
| `get_tmux_option()` | (preserve, S1 owns) | S2/S3/S4 consume it |
| `_resolve_zoxide()` (with `--` guard) | (preserve, S2 owns) | S4 consumes it |
| `_resolve_z()` (CORRECTION A, OPTION C form) | (preserve, S3 owns) | S4 consumes it |
| `resolve()` dispatcher (CORRECTION B) | ✅ CREATE (append — last function) | P1.M2.T1.S1 / P1.M3.T1.S1 consume it |
| `tests/test_resolve_dispatcher.sh` | ✅ CREATE (additive dev artifact) | extends S1/S2/S3's test pattern |
| `tmux-zoxide-sessions.tmux`, `z-window.sh`, `z-session.sh`, `README.md` | ❌ DO NOT | P1.M2 / P1.M3 / P1.M4 |
| `chmod +x` on anything | ❌ DO NOT | P1.M4.T2.S1 |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 9.5/10** — CORRECTION B is **empirically validated**: the verbatim `resolve()` body (PRD §5.3 + one `return 0`) and the full 14-case unit test were written into an **isolated `/tmp` copy** and run during research — `shellcheck` exit 0 / no output on **both** files, `sh tests/test_resolve_dispatcher.sh` → `RESULTS: pass=14 fail=0`, exit 0, all four functions source cleanly with `resolve` as the last function. The one non-obvious test-design decision — the fake `zoxide` **must exit 1 on no-match** to make the exit-0 gate meaningful (the real zoxide exits 0 on this machine, but CORRECTION B defends against version-dependent non-zero; a fake that exits 0 makes case 1 a silent false pass) — is surfaced, justified, and validated (case 1 correctly shows NONZERO for the buggy form; cases 9–14 correctly show 0 for the shipped form). The mocking strategy (single fake `tmux` answering both option names; backends switched via a reliably-propagating `$ZS_BACKEND` env var; distinct `proj`/`work` keywords to discriminate the `auto` fallback) is proven by the 14/14 run. Append-only / always-exit-0 / last-function / no-per-branch-defense boundaries are explicit. The residual half-point: `/bin/sh`→bash means strict-dash runtime behavior is observed via `shellcheck` rather than a real dash execution, and the optional live smoke depends on the local zoxide DB (the self-contained unit test is the authoritative, machine-independent gate that absorbs this). S4 completes `resolve.sh` for P1.M1.T2 and unblocks P1.M2/P1.M3.
