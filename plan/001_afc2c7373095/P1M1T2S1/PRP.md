# PRP — P1.M1.T2.S1: `get_tmux_option()` helper

## Goal

**Feature Goal**: Create the shared library file `scripts/lib/resolve.sh` with its POSIX-`sh` shebang, header comment, and **its first function** `get_tmux_option()` — the universal tmux-plugins idiom for reading a `@`-prefixed user option with a fallback default. This is the foundational helper that every later subtask (S2–S4) appends to and that the run file (P1.M2.T2.S1) and the two handler scripts consume.

**Deliverable**: Two files —
1. `scripts/lib/resolve.sh` — contains **only**: `#!/bin/sh` shebang, the §5.3 header comment block, and the `get_tmux_option()` function. **Nothing else** (no `_resolve_zoxide`, no `_resolve_z`, no `resolve` — those are later subtasks).
2. `tests/test_resolve_get_tmux_option.sh` — a dependency-free POSIX-`sh` unit test that mocks `tmux` via a fake binary earlier on `PATH` and asserts every branch of `get_tmux_option`.

**Success Definition**:
- `scripts/lib/resolve.sh` exists, is `sh`-sourceable, and is byte-faithful to the PRD §5.3 fragment for the shebang + header + `get_tmux_option`.
- `get_tmux_option <name> <default>` echoes the option's value when set non-empty, and the default when the option is unset or set-to-empty.
- `shellcheck scripts/lib/resolve.sh` exits 0 with **no** output (no exclusions, no directives).
- `sh tests/test_resolve_get_tmux_option.sh` prints all-PASS and exits 0.
- No other functions are added to `resolve.sh`; `.gitignore` and `PRD.md` are untouched.

## User Persona

**Target User**: The implementing AI agent (subtask executor); downstream subtasks S2–S4 (append to this same file) and P1.M2.T2.S1 / P1.M3.T2.S1 (source this file from the run file).

**Use Case**: Provide a single, sourced, POSIX-portable accessor for tmux user options so the run file and both handler scripts read configuration identically (`key=$(get_tmux_option "@zoxide-sessions-key" "g")`, etc.).

**Pain Points Addressed**: Removes per-script duplication of `tmux show-option` plumbing; centralizes the "unset → default" semantics that the option table (PRD §4) depends on.

## Why

- This is the **first content** written into the `scripts/lib/` directory created by P1.M1.T1.S1. It is the root dependency of the entire resolver library and both features.
- `get_tmux_option` is the validated universal idiom of the tmux-plugins ecosystem — found **byte-identical** in TPM, tmux-resurrect, and tmux-continuum (see `architecture/research_plugin_ecosystem.md` §2). Shipping the canonical, sourced form maximizes portability and reviewer familiarity.
- The PRD deliberately specifies a **strictly-POSIX** rewrite (no `local`) because `resolve.sh` carries `#!/bin/sh` and is sourced by `#!/bin/sh` handler scripts. Getting this function right — and proving it with a mocked unit test — de-risks S2–S4, which all reuse this exact `tmux show-option -gqv` call shape.

## What

User-visible behavior: none directly (sourced library function). Observable contract when sourced into any `sh` script:

- `get_tmux_option "<opt>" "<default>"` → writes to stdout the value of global tmux option `<opt>` if it is set to a non-empty string; otherwise writes `<default>`. Always exits 0.
- Reading an unset `@`-option (the common case for optional config) returns the default, not an error — because `tmux show-option -gqv` prints nothing and exits 0 for unset options.

### Success Criteria

- [ ] `scripts/lib/resolve.sh` exists and starts with `#!/bin/sh`.
- [ ] It contains the §5.3 header comment (2 lines) and **only** `get_tmux_option()`.
- [ ] `get_tmux_option` body is exactly: `_v=$(tmux show-option -gqv "$1" 2>/dev/null)` then `[ -n "$_v" ] && echo "$_v" || echo "$2"` (PRD §5.3, verbatim — multi-line form).
- [ ] No `local`, no `[[ ]]`, no arrays, no `==` inside `[ ]`, no `echo -e` (POSIX-clean).
- [ ] `shellcheck scripts/lib/resolve.sh` → exit 0, no output.
- [ ] `sh tests/test_resolve_get_tmux_option.sh` → all-PASS, exit 0.
- [ ] `scripts/lib/resolve.sh` is sourceable: `sh -c '. scripts/lib/resolve.sh; get_tmux_option x d'` prints `d` (no tmux → default).
- [ ] `.gitignore` and `PRD.md` are unmodified (`git diff --name-only` shows no tracked-file changes other than new untracked files).

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The exact file content is reproduced verbatim below; the mocking test is fully specified and was empirically verified to pass (6/6); the shebang/POSIX constraints are explicit; the "do not pre-write S2–S4" boundary is explicit; and `shellcheck` is the only required tool (confirmed installed). No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source for the EXACT function text and header comment.
  section: "§5.3 scripts/lib/resolve.sh (FIRST function only), §4 Options reference (the @options this reads)"
  critical: "Copy the get_tmux_option block byte-faithful. Header comment line 1 contains a U+2014 em dash (—) — preserve it, do NOT substitute '--' or '-'."

- file: plan/001_afc2c7373095/architecture/research_plugin_ecosystem.md
  why: Primary-source proof that this idiom is universal & that show-option -gqv returns empty+exit0 for unset @-options.
  section: "§2 The get_tmux_option Helper Pattern (CONFIRMED), §5 POSIX sh vs bash"
  critical: "The canonical ecosystem form uses `local`; the PRD's POSIX rewrite drops it (uses _v). We ship the POSIX rewrite. `local` is non-POSIX even though dash supports it."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: Records POSIX-correctness confirmation (#7) and the corrections that apply to LATER subtasks.
  section: "Confirmed-correct #7 (POSIX sh posture), CORRECTION A (S3), CORRECTION B (S4)"
  critical: "Corrections A & B target S3/S4 — NOT this subtask. Do NOT pre-write those functions; ship ONLY get_tmux_option or S3/S4 cannot apply their required fixes cleanly."

- file: plan/001_afc2c7373095/P1M1T1S1/PRP.md
  why: The scaffolding PRP that (concurrently) creates scripts/ and scripts/lib/ (empty) + LICENSE.
  section: "Goal, Scope Boundaries"
  critical: "This subtask ASSUMES scripts/lib/ exists from P1.M1.T1.S1. If it doesn't yet, the `write` tool auto-creates parent dirs — so S1 is robust to ordering either way."

- docfile: plan/001_afc2c7373095/P1M1T2S1/research/verification_notes.md
  why: Empirical proof: shellcheck passes clean on the exact form; the fake-tmux mocking harness passes 6/6; the arg-parsing gotcha for the fake tmux.
  section: "§1 shellcheck, §2 fake-tmux mocking + arg-parsing gotcha, §5 header em-dash, §6 scope boundary"
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# After P1.M1.T1.S1 has run (assume its contract):
$ ls -R scripts LICENSE 2>/dev/null
scripts:
lib
LICENSE        # (absent until P1.M1.T1.S1 writes it — not our concern)

# resolve.sh — ABSENT (this subtask creates it)
# tests/     — ABSENT (this subtask creates it)
```

Tooling on this machine: `shellcheck` at `/usr/bin/shellcheck` (✅ installed); **no** bats / shunit2 / sharness (greenfield). `/bin/sh` → `bash` here (so dev-time dash-strictness is observed via `shellcheck`, not at runtime).

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  scripts/
    lib/
      resolve.sh             # NEW — shebang + header comment + get_tmux_option() ONLY
  tests/                     # NEW — dev-only unit-test dir (NOT in PRD §5.1 ship tree; additive, see Gotchas)
    test_resolve_get_tmux_option.sh   # NEW — fake-tmux mocking unit test
```

`resolve.sh` deliberately contains **only** the first function now. S2/S3/S4 append `_resolve_zoxide`, `_resolve_z` (CORRECTION A), and `resolve` (CORRECTION B) into this same file. **Do not pre-write them.**

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL: Write ONLY get_tmux_option. The PRD §5.3 listing shows the FULL resolve.sh
#   (4 functions) for context — but this subtask owns ONLY the first. S3 ships CORRECTION A
#   (_resolve_z) and S4 ships CORRECTION B (resolve); pre-writing the PRD text for those
#   would override the required corrections and cause rework. STOP after get_tmux_option.

# CRITICAL: Header comment line 1 has a U+2014 EM DASH: "lib/resolve.sh — shared helpers".
#   Copy byte-exact. Do not ASCII-ify to "--" or "-".

# CRITICAL: POSIX sh — NO `local`. Use the _v scratch-variable form (mandated by item contract).
#   Also avoid [[ ]], arrays, `==` in [ ], `echo -e`, `${var//a/b}`. Use printf for any
#   formatted output (not needed in this function, but keep the discipline for S2-S4).

# GOTCHA: _v is NOT localized — it leaks into the caller's scope after each call.
#   Accepted tradeoff (matches PRD §5.3 intent; all scratch vars are _-prefixed and reassigned
#   per-call). The run file always calls via $(get_tmux_option ...) (a subshell), confining it.

# GOTCHA: No test framework exists. Do NOT pull in bats/shunit2. The mandated approach is a
#   dependency-free POSIX-sh script that injects a fake `tmux` earlier on PATH (item contract #5).
#   This is the repo's FIRST unit test — it establishes the pattern S2-S4 will extend.

# GOTCHA (test harness): `tmux show-option -gqv <name>` has the name as the FIRST NON-FLAG arg
#   after `show-option`, NOT a fixed positional. Flags -g -q -v are separate, so name is $5 in
#   the standard case. The fake tmux MUST scan past all leading `-` flags and take the first bare
#   token — a hardcoded $4/$5 silently always returns the default and hides real bugs.

# GOTCHA: `/bin/sh` -> bash on THIS dev machine, so dash-strictness is NOT exercised at runtime
#   here. `shellcheck` (which detects `#!/bin/sh` and lints as sh) is the portability gate.

# FORBIDDEN: Do NOT modify .gitignore or PRD.md.
# FORBIDDEN: Do NOT chmod +x resolve.sh — it is SOURCED, never executed. (Handler scripts and
#   the run file are chmod'd later in P1.M4.T2.S1.) A sourced lib needs no executable bit.
# FORBIDDEN: Do NOT create the run file, z-window.sh, z-session.sh, or README.md.
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The only "structure" is the function's positional-parameter contract:
`$1` = option name (e.g. `@zoxide-sessions-key`), `$2` = default value. Output via stdout only.

### Verbatim content for `scripts/lib/resolve.sh`

Write **exactly** this (and nothing else) to `scripts/lib/resolve.sh`. Note the em dash on line 2.

```sh
#!/bin/sh
# lib/resolve.sh — shared helpers for tmux-zoxide-sessions.
# Sourced by the run file, scripts/z-window.sh, and scripts/z-session.sh.

# get_tmux_option <name> <default> -> option value, or default if unset/empty.
get_tmux_option() {
    _v=$(tmux show-option -gqv "$1" 2>/dev/null)
    [ -n "$_v" ] && echo "$_v" || echo "$2"
}
```

> Implementing agent: the body of `get_tmux_option` is the **verbatim** PRD §5.3 form. The
> item contract also shows a semicolon-joined one-liner of the same logic; the multi-line
> form above is canonical ("exactly as in PRD §5.3"). Do **not** add `local`, `if/else`,
> shellcheck directives, or extra functions.

### Verbatim content for `tests/test_resolve_get_tmux_option.sh`

Write **exactly** this to `tests/test_resolve_get_tmux_option.sh`. It is self-verifying:
prints `PASS`/`FAIL` per case and exits non-zero on any failure. It was run during research
and passed 6/6.

```sh
#!/bin/sh
# Unit tests for get_tmux_option (P1.M1.T2.S1).
# Strategy: inject a fake `tmux` earlier on PATH that answers `show-option -gqv <name>`
# with canned output, source resolve.sh, and assert each branch. No live tmux required.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESOLVE="$REPO_ROOT/scripts/lib/resolve.sh"

# --- fake tmux ---------------------------------------------------------------
TBIN="$REPO_ROOT/tests/.tmux-bin"
mkdir -p "$TBIN"
cat > "$TBIN/tmux" <<'TMUX'
#!/bin/sh
# Fake tmux implementing ONLY: tmux show-option -gqv <name>
if [ "$1" = "show-option" ]; then
    shift                       # drop 'show-option'
    name=""
    while [ $# -gt 0 ]; do      # name = first non-flag arg (skip -g -q -v ...)
        case "$1" in -*) ;; *) name="$1"; break ;; esac
        shift
    done
    case "$name" in
        @set-nonempty) printf '%s\n' "thevalue" ;;
        @set-empty)    printf '' ;;           # set, but value is empty
        @set-space)    printf '%s\n' "with space" ;;
        *)             printf '' ;;           # unset -> empty stdout, exit 0
    esac
fi
exit 0
TMUX
chmod +x "$TBIN/tmux"

cleanup() { rm -rf "$TBIN"; }
trap cleanup EXIT INT TERM
PATH="$TBIN:$PATH"
export PATH

# --- harness -----------------------------------------------------------------
pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}
run() { sh -c '. "$0"; get_tmux_option "$1" "$2"' "$RESOLVE" "$1" "$2"; }
# variant with no default arg:
run1() { sh -c '. "$0"; get_tmux_option "$1"' "$RESOLVE" "$1"; }

# --- cases -------------------------------------------------------------------
check "set non-empty option echoes the value" "thevalue"    "$(run @set-nonempty DEFAULT)"
check "unset option echoes default"           "DEFAULT"     "$(run @unset-opt DEFAULT)"
check "set-to-empty option echoes default"    "DEFAULT"     "$(run @set-empty DEFAULT)"
check "value with spaces preserved"           "with space"  "$(run @set-space DEFAULT)"
check "empty default + unset -> empty"        ""            "$(run @unset-opt '')"
check "default omitted + unset -> empty"      ""            "$(run1 @unset-opt)"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE scripts/lib/resolve.sh
  - FILE: scripts/lib/resolve.sh
  - CONTENT: the verbatim block above (shebang + 2-line header comment + get_tmux_option ONLY).
  - SHEBANG: #!/bin/sh   (POSIX sh — NOT bash; resolves.sh is sourced by #!/bin/sh scripts)
  - NAMING: function name get_tmux_option (lowercase_with_underscores — ecosystem convention).
  - FORM: the exact PRD §5.3 multi-line body; _v scratch var (no `local`).
  - PLACEMENT: scripts/lib/ (created by P1.M1.T1.S1; `write` auto-makes parents if absent).
  - GOTCHA: preserve the U+2014 em dash in the header comment.
  - GOTCHA: do NOT chmod +x — this file is SOURCED, never executed.
  - STOP: do not add _resolve_zoxide / _resolve_z / resolve (S2/S3/S4 own those).

Task 2: CREATE tests/test_resolve_get_tmux_option.sh
  - FILE: tests/test_resolve_get_tmux_option.sh
  - CONTENT: the verbatim block above (fake-tmux mocking harness, 6 cases).
  - NAMING: test_<lib>_<function>.sh — establishes the repo's unit-test naming pattern.
  - PLACEMENT: tests/ at repo root (additive dev dir; NOT part of the PRD §5.1 ship tree).
  - COVERAGE: set-non-empty, unset, set-to-empty, spaces-in-value, empty-default, no-default-arg.
  - SELF-VERIFY: prints PASS/FAIL per case; exit non-zero on any failure; cleans up its fake bin.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: shellcheck scripts/lib/resolve.sh          # expect exit 0, no output
  - RUN: sh tests/test_resolve_get_tmux_option.sh   # expect "RESULTS: pass=6 fail=0", exit 0
  - RUN: sh -c '. scripts/lib/resolve.sh; r=$(get_tmux_option x d); [ "$r" = d ]' && echo sourceable-OK
  - RUN: git status --short                          # only NEW untracked files; PRD.md/.gitignore untouched
```

### Implementation Patterns & Key Details

```sh
# The single pattern this subtask establishes — read a @-option with a default:
#   val=$(get_tmux_option "@zoxide-sessions-key" "g")
#
# Why it works: `tmux show-option -gqv <name>` returns EMPTY + exit 0 for an unset @-option
# (architecture/research_plugin_ecosystem.md §2, confirmed against TPM/resurrect/continuum
# source). So `[ -n "$_v" ]` is the correct "is it actually set to something?" test, and the
# `&& echo "$_v" || echo "$2"` selects value-vs-default. `2>/dev/null` suppresses any stderr
# noise (defensive; real `tmux show-option -gqv` is quiet on unset by the -q flag anyway).
#
# Why no `local`: resolve.sh is `#!/bin/sh` and sourced by other `#!/bin/sh` scripts. `local`
# is non-POSIX (dash/ash support it as an extension, but a strict POSIX lint would flag it).
# The PRD's POSIX rewrite uses a plain `_v` scratch var. Tradeoff: `_v` leaks into the caller
# scope — acceptable because callers always wrap the call in `$(...)` (a subshell).
```

### Integration Points

```yaml
FILESYSTEM:
  - create: "scripts/lib/resolve.sh   (sourced lib — NOT executable)"
  - create: "tests/test_resolve_get_tmux_option.sh   (dev unit test, executable bit optional)"

NO DATABASE / CONFIG / ROUTES / BUILD CHANGES:
  - This subtask adds one sourced lib function + one test. No tmux options are registered,
    no hooks, no keybindings. (Those belong to P1.M2/P1.M3.)
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only).

DOWNSTREAM CONSUMERS (contract this subtask guarantees):
  - S2 (_resolve_zoxide): APPENDS to scripts/lib/resolve.sh, reuses the `tmux show-option -gqv`
    call shape; calls get_tmux_option for the backend option.
  - S3 (_resolve_z, CORRECTION A): APPENDS; reads @zoxide-sessions-z-sh via get_tmux_option.
  - S4 (resolve dispatcher, CORRECTION B): APPENDS; reads @zoxide-sessions-backend via get_tmux_option.
  - P1.M2.T2.S1 (run file): `. "$CURRENT_DIR/scripts/lib/resolve.sh"` then
    `key=$(get_tmux_option "@zoxide-sessions-key" "g")` etc. — so get_tmux_option MUST be
    defined (and only this function need be present) for the run file to source cleanly.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — POSIX-sh posture. MUST exit 0 with NO output.
shellcheck scripts/lib/resolve.sh
# (Verified during research: exit 0, zero findings. No -e exclusions, no disable directives.)

# Also lint the test for good measure.
shellcheck tests/test_resolve_get_tmux_option.sh

# Confirm POSIX-clean by inspection: no `local`, `[[ ]]`, arrays, `==` in [ ], `echo -e`.
grep -nE '\blocal\b|\[\[|==|\becho -e\b|\$\{[a-zA-Z_]+//[^}]+/\}' scripts/lib/resolve.sh
# Expected: NO output (nothing matched). If anything prints, remove the bash-ism.

# Expected: shellcheck exits 0 silently; grep prints nothing.
```

### Level 2: Unit Tests (Component Validation)

```bash
# The mocking-based unit test (item contract #5). No live tmux, no bats, no deps.
sh tests/test_resolve_get_tmux_option.sh
# Expected output ends with:  RESULTS: pass=6 fail=0   and exit code 0.
# (Verified during research: 6/6 PASS.)
```

### Level 3: Integration / Sourceability (System Validation)

```bash
# 3a. The lib must be sourceable in plain sh and the function must exist after sourcing.
sh -c '. scripts/lib/resolve.sh; type get_tmux_option' | head -1
# Expected: "get_tmux_option is a function" (or "shell function").

# 3b. With NO tmux on PATH at all, an unset option must fall back to the default
#     (proves the 2>/dev/null + emptiness-test path is robust to a missing/errored tmux).
sh -c '. scripts/lib/resolve.sh; r=$(get_tmux_option "@nope-xyz" FALLBACK); [ "$r" = FALLBACK ]' \
  && echo "no-tmux-default OK" || echo "no-tmux-default FAIL"

# 3c. OPTIONAL live-tmux smoke (only if a tmux server is reachable; skip in CI/headless).
#     Requires an active tmux session ($TMUX set) or a detached server.
if tmux info >/dev/null 2>&1; then
    tmux set -g @zoxide-sessions-key 'Z'
    got=$(sh -c '. scripts/lib/resolve.sh; get_tmux_option "@zoxide-sessions-key" "g"')
    [ "$got" = "Z" ] && echo "live-set OK ($got)" || echo "live-set FAIL ($got)"
    # And the unset path (use a name nothing sets):
    got2=$(sh -c '. scripts/lib/resolve.sh; get_tmux_option "@zoxide-sessions-unset-smoke" "def"')
    [ "$got2" = "def" ] && echo "live-unset OK ($got2)" || echo "live-unset FAIL ($got2)"
else
    echo "skipped live-tmux smoke (no server) — Level 2 unit test is the authoritative gate"
fi
# Expected: sourceability OK; no-tmux-default OK; live smoke OK or explicitly skipped.
```

### Level 4: N/A

No runtime feature, performance, or security validation applies to a single sourced accessor.
Skipped intentionally (there is no user-facing behavior to exercise beyond Levels 1–3).

## Final Validation Checklist

### Technical Validation

- [ ] `shellcheck scripts/lib/resolve.sh` exits 0 with no output.
- [ ] `sh tests/test_resolve_get_tmux_option.sh` prints `RESULTS: pass=6 fail=0` and exits 0.
- [ ] Sourceability check (Level 3a) shows `get_tmux_option is a function`.
- [ ] No-tmux-default check (Level 3b) returns the default (proves the `2>/dev/null` path).
- [ ] POSIX-clean grep (Level 1) prints nothing.

### Feature Validation

- [ ] All success criteria from "What" met.
- [ ] `get_tmux_option` echoes the value when the option is set non-empty (case 1).
- [ ] `get_tmux_option` echoes the default when the option is unset (case 2) or empty (case 3).
- [ ] Values containing spaces survive intact (case 4) — important for `@zoxide-sessions-skip-names`.
- [ ] The function is the **only** function in `resolve.sh` (S2–S4 append theirs later).

### Code Quality Validation

- [ ] Follows the ecosystem's universal `get_tmux_option` idiom (research_plugin_ecosystem.md §2).
- [ ] POSIX-`sh` clean (no `local`/`[[ ]]`/arrays/`==`/`echo -e`).
- [ ] Byte-faithful to PRD §5.3 (including the U+2014 em dash in the header comment).
- [ ] File placement matches the desired tree (`scripts/lib/resolve.sh`, `tests/...`).
- [ ] No executable bit set on the sourced lib (it is sourced, not executed).

### Documentation & Deployment

- [ ] Header comment documents the function contract inline (`# get_tmux_option <name> <default> -> ...`).
- [ ] No user-facing/config surface (internal helper — no README/doc changes, per item contract #6).
- [ ] No new tmux options, hooks, or environment variables introduced.

---

## Anti-Patterns to Avoid

- ❌ Don't write the **full** PRD §5.3 file (all 4 functions). Ship ONLY `get_tmux_option` — S2/S3/S4 append the rest and S3/S4 carry *required* corrections the PRD text doesn't encode.
- ❌ Don't use `local` — it's non-POSIX; the item contract mandates the `_v` scratch-var form.
- ❌ Don't rewrite `[ -n "$_v" ] && echo "$_v" || echo "$2"` into `if/else` to "fix" shellcheck — shellcheck already passes clean (verified); the form is mandated.
- ❌ Don't ASCII-ify the em dash (`—`) in the header comment — copy it byte-exact.
- ❌ Don't `chmod +x resolve.sh` — it's sourced, never executed; the bit is meaningless here and executable bits are handled centrally in P1.M4.T2.S1.
- ❌ Don't pull in bats/shunit2/sharness — no test framework exists and the contract prescribes a dependency-free fake-tmux mock; adding a framework deviates and adds a dependency.
- ❌ Don't parse the option name as a fixed positional (`$4`/`$5`) in the fake tmux — scan past `-` flags (the `show-option -gqv <name>` arg order has 3 separate flags before the name).
- ❌ Don't modify `.gitignore` or `PRD.md`.

---

## Scope Boundaries (explicit)

| Item | This subtask (S1) | Later subtasks |
| --- | --- | --- |
| `scripts/lib/resolve.sh` (file) | ✅ CREATE | S2/S3/S4 APPEND to it |
| shebang `#!/bin/sh` + header comment | ✅ CREATE | — |
| `get_tmux_option()` | ✅ CREATE (verbatim PRD §5.3) | consumes it |
| `_resolve_zoxide()` | ❌ DO NOT | P1.M1.T2.S2 |
| `_resolve_z()` (CORRECTION A) | ❌ DO NOT | P1.M1.T2.S3 |
| `resolve()` dispatcher (CORRECTION B) | ❌ DO NOT | P1.M1.T2.S4 |
| `tests/` dir + first unit test | ✅ CREATE (additive dev artifact) | S2–S4 extend the pattern |
| `tmux-zoxide-sessions.tmux`, `z-window.sh`, `z-session.sh`, `README.md` | ❌ DO NOT | P1.M2 / P1.M3 / P1.M4 |
| `chmod +x` on anything | ❌ DO NOT | P1.M4.T2.S1 |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 9.5/10** — The function text is reproduced verbatim and `shellcheck`-verified clean; the unit test is fully specified and was run during research (6/6 PASS); the sourceability and no-tmux-default paths are proven; the shebang/POSIX and "first function only" boundaries are explicit. The only residual half-point is that `/bin/sh`→bash on this dev box means strict-dash runtime behavior is observed via `shellcheck` rather than a real dash execution — mitigated by the function using only the most conservative POSIX subset (command substitution, `[ -n ]`, `echo`).
