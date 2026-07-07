# PRP — P1.M2.T1.S1: `scripts/z-window.sh` (window-jump handler)

## Goal

**Feature Goal**: Create `scripts/z-window.sh` — the **window-jump handler** for the
`prefix g` binding (PRD §5.4). It is the manual half of the plugin: given an optional query,
open **exactly one** new window in the **current session**, in the zoxide-frecency-resolved
directory (named after the dir basename), or — with no query / no match — in the **current
pane's** directory. It sources `scripts/lib/resolve.sh` (built by P1.M1.T2) and calls its public
`resolve()` entry point (S4, implementing in parallel) as its **sole** frecency dependency.

**Deliverable**: Two artifacts —
1. `scripts/z-window.sh` — **PRD §5.4 verbatim** (no deviations), made executable (`chmod +x`).
   `#!/bin/sh`; `SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)`; `. "$SCRIPT_DIR/lib/resolve.sh"`;
   `query="$*"` (NOT `"$1"` — see findings §6 / gotchas); reads `cur=$(tmux display-message -p
   '#{pane_current_path}')` (fallback `$HOME`) and `session=$(... '#{session_name}')`; `dir="$cur"`;
   if query non-empty, `resolved=$(resolve "$query")` and `[ -n "$resolved" ] && dir="$resolved"`;
   `base=$(basename "$dir")`; `tmux new-window -t "$session:" -c "$dir" -n "$base"`.
2. `tests/test_z_window.sh` — a dependency-free POSIX-`sh` **integration** test (item contract #5)
   against an **isolated tmux server** (`tmux -L zxstest`), with a **fake `tmux` wrapper** on PATH
   and a **staged fake `lib/resolve.sh`** for deterministic results. Asserts the new window's cwd
   via `#{pane_current_path}` (with a propagation settle) and name via `#{window_name}`. 9 cases:
   empty/match/no-match + the `"$*"` recombination discriminator + a single-window-per-invocation count.

**Success Definition**:
- `scripts/z-window.sh` exists, is byte-for-byte PRD §5.4, is **executable** (`ls -l` shows `x`).
- `shellcheck --exclude=SC1091 scripts/z-window.sh` → exit 0, no output (SC1091 is the one
  accepted info — see gotchas; `--exclude=SC1091` keeps the handler verbatim, no directive added).
- `shellcheck tests/test_z_window.sh` → exit 0, no output.
- `sh tests/test_z_window.sh` → `RESULTS: pass=9 fail=0`, exit 0 (validated: 5 consecutive runs,
  no flake, empty stderr).
- `scripts/lib/resolve.sh` and the S1–S4 tests are **unmodified** (no regression). The real
  `resolve()` is never exercised by this test (a fake is staged), so this passes independently of
  P1.M1.T2.S4's completion.
- `.gitignore` / `PRD.md` untouched (`git status --short` shows only the two new files).

## User Persona

**Target User**: An end user pressing `prefix g` (default), typing a short frecency query
(`tmux`, `proj`), and getting a new window in the matched directory — and the **implementing AI
agent** (subtask executor), plus the downstream **P1.M2.T2.S1** run file that wires the binding
invoking this handler.

**Use Case**: `prefix g` → `z to: proj` Enter → a window opens in `zoxide query proj` (or the
rupa/z fallback), named after the dir basename. Empty query / no-match → a window in the current
pane's dir (same as `new-window -c "#{pane_current_path}"`).

**User Journey**: User presses the bound key → tmux's `command-prompt` collects the query → tmux
textually substitutes it into `run-shell '.../z-window.sh %%'` (splitting on spaces) → z-window.sh
recombines the argv via `"$*"`, resolves, and creates exactly one new window in the right dir.

**Pain Points Addressed**: `new-window -c` needs a **literal path**; the user has a **frecency
index** (zoxide/rupa-z) that already knows the right dir for a short query. The handler bridges
the two: short query → resolved dir → new window, with a safe current-dir fallback.

## Why

- This is the **first feature module** of P1.M2 (Window-jump). It consumes the resolver library
  built in P1.M1.T2 (S1→S4) and is itself consumed by P1.M2.T2.S1 (the run file's binding). It
  unblocks the user-visible window-jump feature.
- **The `"$*"` recombination is load-bearing** (findings §6): `command-prompt ... %%` substitutes
  **textually and splits on spaces**, so a spaced query arrives as multiple argv entries. Using
  `query="$*"` recombines them; using `"$1"` would silently break spaced queries. The test's case 4
  makes this a hard, discriminating assertion.
- **Determinism matters for testing**: the real `resolve()` shells out to `zoxide query` /
  rupa/z, whose output depends on the live frecency DB. The test injects a **fake** `resolve`
  (staging-dir) so the handler's branching logic is verified deterministically — independent of the
  DB and of P1.M1.T2.S4's completion.
- **Always exactly one window** (item contract #4): the binding fires once per keypress; the handler
  must create exactly one window. Test case 5 counts windows before/after to assert delta == 1.

## What

User-visible behavior: pressing `prefix g`, typing a query (or nothing), and pressing Enter opens
**one** new window in the current session:
- **query resolves** → window in the resolved dir, named after its basename;
- **empty query** or **no match** → window in the current pane's dir, named after its basename
  (equivalent to `new-window -c "#{pane_current_path}"`).

Observable contract when invoked as `z-window.sh [query ...]`:
- `query="$*"` (all args, space-recombined). Empty if no args.
- `cur` = current pane's path (`#{pane_current_path}`, fallback `$HOME`); `session` = current
  session (`#{session_name}`). With no query or no resolve match, `dir="$cur"`.
- `tmux new-window -t "$session:" -c "$dir" -n "$(basename "$dir")"` — exactly one window.
- The handler reads **no tmux options** itself (`@zoxide-sessions-key` / `@zoxide-sessions-prompt`
  are run-file concerns, P1.M2.T2.S1). It is fully option-agnostic.

### Success Criteria

- [ ] `scripts/z-window.sh` exists and is byte-for-byte PRD §5.4 (the verbatim block below).
- [ ] `scripts/z-window.sh` is executable (`test -x`).
- [ ] `query="$*"` (NOT `"$1"`) — spaced queries recombine (findings §6).
- [ ] Empty query → window in current pane dir, named basename (test case 1).
- [ ] Match → window in resolved dir, named basename (test case 2).
- [ ] No-match → window in current pane dir, fallback (test case 3).
- [ ] Spaced query (`my proj` as 2 args) → recombines to `"my proj"` and still matches (case 4).
- [ ] Exactly one window created per invocation (case 5, delta == 1).
- [ ] `shellcheck --exclude=SC1091 scripts/z-window.sh` exit 0, no output.
- [ ] `shellcheck tests/test_z_window.sh` exit 0, no output.
- [ ] `sh tests/test_z_window.sh` → `RESULTS: pass=9 fail=0`, exit 0.
- [ ] S1–S4 resolve tests still pass (no regression); `.gitignore`/`PRD.md` untouched.

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this
successfully?_ **Yes.** The handler is PRD §5.4 verbatim (reproduced below). The test was written,
run, and refined in an isolated `/tmp` tree during research and validated 5× consecutive
(`pass=9 fail=0`, exit 0, empty stderr, shellcheck-clean on both files). Every non-obvious testing
hurdle — the `#{pane_current_path}` propagation race (sleep 0.3), the empty-`default-shell` sandbox
quirk (pin via `set-option -g`), the `kill-server`→`start-server` socket race (sleep 0.25), the
fake-`tmux` wrapper recursion avoidance (absolute `$REAL_TMUX`), the staging-dir fake-resolve
injection, and the SC1091 dynamic-source info (`--exclude=SC1091`) — is surfaced, justified, and
empirically proven in `research/verification_notes.md`. The only tool required beyond a POSIX shell
is `tmux` 3.0+ (confirmed present). No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source for the handler (verbatim) and the feature's user-visible contract.
  section: "§5.4 scripts/z-window.sh (the BASELINE — ship it verbatim), §4 Options reference
            (the handler reads NONE; @zoxide-sessions-key/prompt are run-file concerns),
            h2.3/h3.4 3.1 Window jump (behavior)"
  critical: "Ship §5.4 byte-for-byte. The handler is option-agnostic: it does NOT read
            @zoxide-sessions-key or @zoxide-sessions-prompt — those belong to the run file
            (P1.M2.T2.S1). Do NOT add option reads. query=\"$*\" (NOT \"$1\")."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: Primary-source, empirically-verified analysis. §✅6 is the crux for this subtask.
  section: "§✅6 Window feature + spaces (%% splits on spaces BUT query=\"$*\" recombines; spaced
            queries work; never change to \"$1\"; never eval the query), §✅5 zoxide query contract
            (empty+exit0 on no-match), §✅7 POSIX posture"
  critical: "§6 is WHY query=\"$*\": command-prompt %% substitution is textual and splits on
            spaces; the script recombines argv via \"$*\". The test's case 4 turns this into a
            discriminating assertion. Residual (shell-metachar injection in typed input) is
            acceptable for a personal tool — the handler never evals the query."

- file: plan/001_afc2c7373095/P1M1T2S4/PRP.md
  why: Defines the resolve() public API this handler consumes (S4, implementing in PARALLEL).
  section: "Goal/Deliverable (resolve() dispatcher; always exits 0; output=path-or-empty),
            Integration Points DOWNSTREAM CONSUMERS (z-window.sh calls resolved=\$(resolve \"\$query\")
            and branches on [ -n \"\$resolved\" ])"
  critical: "TREAT S4 AS A CONTRACT: resolve() will exist (PRD §5.3 + CORRECTION B), returns one
            path line on match / empty on no-match, ALWAYS exits 0. z-window.sh's
            resolved=\$(resolve \"\$query\"); [ -n \"\$resolved\" ] && dir=\"\$resolved\" is the
            documented consume pattern. The test FAKES resolve (staging-dir) so it passes
            independently of S4 — no coupling, no race with the parallel implementation."

- docfile: plan/001_afc2c7373095/P1M2T1S1/research/verification_notes.md
  why: Empirical proof grounding every gate and every non-obvious test-design decision.
  section: "§2 $* recombination, §3 tmux no-client + propagation race, §4 default-shell pin,
            §5 kill/start socket race, §6 mocking strategy, §7 SC1091, §8 results, §9 composition"
  critical: "§3–§5 are the three sandbox quirks that, left unhandled, make the integration test
            flake or fail: (3) #{pane_current_path} needs ~0.3s after pane creation to settle to
            the -c dir; (4) an empty default-shell makes panes misbehave and crash the server — pin
            it; (5) kill-server→start-server needs ~0.25s to release the socket. Copy the test
            verbatim — these are baked in and validated."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State at subtask start (treat as contract). Note resolve.sh has 3 functions now;
# S4 (parallel) will append resolve() as the 4th. z-window.sh does not exist yet.
$ ls scripts tests 2>/dev/null
scripts/lib:
resolve.sh          # S1+S2+S3 done (get_tmux_option, _resolve_zoxide, _resolve_z);
                     # S4 (parallel) appends resolve() — the public API z-window.sh calls.
tests:
test_resolve_get_tmux_option.sh   # S1 unit test
test_resolve_zoxide.sh            # S2 unit test
test_resolve_z.sh                 # S3 unit test

# NOT yet present: tmux-zoxide-sessions.tmux (P1.M2.T2), z-session.sh (P1.M3.T1),
#                  README.md (P1.M4.T1). This subtask adds ONLY z-window.sh + its test.

# Tooling (the integration test requires tmux 3.0+):
$ command -v tmux shellcheck sh
/usr/bin/tmux          # ✅ 3.6b — REQUIRED by test_z_window.sh (isolated server)
/usr/bin/shellcheck    # ✅ lint gate (v0.11.0)
/bin/sh -> bash        # /bin/sh is bash on this box; POSIX posture enforced via shellcheck
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  scripts/
    lib/
      resolve.sh             # (UNCHANGED — S4 owns the resolve() append; this subtask never edits it)
    z-window.sh              # NEW — PRD §5.4 verbatim, EXECUTABLE (+x)
  tests/
    test_resolve_get_tmux_option.sh   # (S1, unchanged — re-run to confirm no regression)
    test_resolve_zoxide.sh            # (S2, unchanged)
    test_resolve_z.sh                 # (S3, unchanged)
    test_z_window.sh                  # NEW — isolated-tmux integration test (9 cases)
```

`z-window.sh` is the **window-jump handler**. The run file (`tmux-zoxide-sessions.tmux`,
P1.M2.T2.S1) will later wire `prefix g` → `command-prompt -p "z to:"` →
`run-shell '.../z-window.sh %%'`. This subtask ships the handler + test only.

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (THE $* RECOMBINATION — findings §6): command-prompt ... %% substitution is TEXTUAL
#   and SPLITS ON SPACES, so a typed query `my proj` reaches z-window.sh as TWO argv entries
#   ($1=my, $2=proj). The script uses `query="$*"` which RECOMBINES them ("my proj"), so spaced
#   queries resolve correctly. DO NOT change to query="$1" (breaks spaced queries). The test's
#   case 4 makes this a discriminating assertion (fake resolve matches the spaced "my proj").
#   Residual: shell-metachar injection in typed input — acceptable for a personal tool; the
#   handler NEVER evals the query (it is passed to resolve()/new-window as data, never executed).

# CRITICAL (CHMOD +x): z-window.sh is EXECUTED (via run-shell), unlike resolve.sh (SOURCED, no +x).
#   The handler MUST be executable: chmod +x scripts/z-window.sh. (P1.M4.T2.S1 commits the bit;
#   this subtask sets it per item contract #3.)

# CRITICAL (TEST — propagation race): immediately after new-session/new-window with -c "$DIR",
#   #{pane_current_path} may briefly report the SERVER's cwd (where tmux was launched) instead of
#   $DIR, until the new pane's process establishes its cwd. The test sleeps ~0.3s after each
#   session/window creation so #{pane_current_path} settles to the -c dir. #{pane_start_path}
#   reflects -c immediately (a no-race alternative); the contract asks for #{pane_current_path}.

# CRITICAL (TEST — pin default-shell): this sandbox's tmux starts with default-shell=[] (empty).
#   With an empty default-shell, new panes spawn erratically (re-launching the tmux binary) and a
#   second new-window eventually CRASHES the isolated server ("server exited unexpectedly"). The
#   test's newserver() pins default-shell to a real login shell (set-option -g default-shell
#   "$DSHELL", DSHELL="${SHELL:-/bin/sh}") BEFORE creating the session. THIS IS A TEST-HARNESS
#   CONCERN ONLY — z-window.sh itself NEVER sets default-shell (it inherits the user's shell, as
#   in production). Do NOT add default-shell handling to the handler.

# CRITICAL (TEST — kill/start socket race): each TDD case's newserver() kill-servers the prior
#   isolated server then start-servers a fresh one. If a REAL server was just killed, the immediate
#   start can race the socket cleanup -> the new server dies mid-case. The test sleeps ~0.25s
#   between kill-server and start-server. (Case 1 never hit this — its kill is a no-op on a
#   nonexistent server; case 2+ did.) Copy the test verbatim — the sleep is baked in & validated.

# CRITICAL (TEST — fake-tmux wrapper recursion): the wrapper at $TBIN/tmux must `exec
#   "$REAL_TMUX" -L zxstest "$@"` using the ABSOLUTE real-tmux path — if it called bare `tmux`,
#   it would recurse onto itself (PATH finds the wrapper again). The test resolves REAL_TMUX via
#   `command -v tmux` at setup and bakes it into the wrapper.

# CRITICAL (MOCKING — staging-dir fake resolve, NOT the real resolve.sh): z-window.sh does
#   `. "$SCRIPT_DIR/lib/resolve.sh"` then `resolve "$query"`. To inject a DETERMINISTIC resolver
#   (no live zoxide DB dependency) WITHOUT touching the real resolve.sh, the test builds a staged
#   plugin tree: $STAGE/scripts/z-window.sh (copy) + $STAGE/scripts/lib/resolve.sh (FAKE resolve).
#   SCRIPT_DIR resolves to $STAGE/scripts, so the handler sources the FAKE. The real resolve.sh is
#   untouched. Do NOT modify scripts/lib/resolve.sh in this subtask.

# GOTCHA (SC1091): shellcheck flags SC1091 (info) on `. "$SCRIPT_DIR/lib/resolve.sh"` — it cannot
#   follow a dynamically-computed source path. This is UNAVOIDABLE for any script sourcing a
#   computed path and is BENIGN (the S-series avoided it only by sourcing inside `sh -c` strings).
#   To keep the handler PRD-verbatim (no shellcheck directive added), the gate uses
#   `shellcheck --exclude=SC1091`. Do NOT add `# shellcheck disable=SC1091` to the handler
#   (that would deviate from PRD §5.4 verbatim).

# GOTCHA (POSIX sh): NO `local`, no `[[ ]]`, no arrays, no `==` in `[ ]`, no `echo -e`, no
#   ${var//}. The PRD §5.4 handler is already POSIX-clean; ship it as-is. (shellcheck-clean.)

# GOTCHA (the handler reads NO options): z-window.sh does NOT read @zoxide-sessions-key or
#   @zoxide-sessions-prompt — those are run-file concerns (P1.M2.T2.S1). Do NOT add option reads
#   to the handler. Item contract #6 (Mode A): no README/option changes in this subtask; the
#   defaults 'g'/'z to:' are authored wholesale in P1.M4.T1 by the run file.

# FORBIDDEN: Do NOT modify scripts/lib/resolve.sh (S1–S4 own it), .gitignore, or PRD.md.
# FORBIDDEN: Do NOT create the run file, z-session.sh, or README.md (later subtasks).
# FORBIDDEN: Do NOT change query="$*" to query="$1" (breaks spaced queries — findings §6).
# FORBIDDEN: Do NOT pull in bats/shunit2 — dependency-free POSIX-sh test (item contract #5).
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The handler's contract is positional/argv: `z-window.sh [query ...]` →
exactly one `tmux new-window -c <dir> -n <basename>`. Side-effect only (mutates tmux server
state); no stdout expected (tmux's `new-window` may print nothing or a target).

### Verbatim content for `scripts/z-window.sh` — PRD §5.4 (ship BYTE-FOR-BYTE, then `chmod +x`)

Write **exactly** this (it is PRD §5.4 verbatim — no deviations, no shellcheck directives, no
"improvements"). Then `chmod +x scripts/z-window.sh`.

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

#### Why each piece is exactly so (do not "improve" it)

```sh
# SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
#   Resolve the handler's own dir ABSOLUTELY, so `. "$SCRIPT_DIR/lib/resolve.sh"` works whether
#   the handler is invoked by absolute path (run-shell) or relative. Matches resolve.sh sourcing
#   in PRD §5.2/§5.5. (This dynamic path is what triggers SC1091 in shellcheck — see gotchas.)
# . "$SCRIPT_DIR/lib/resolve.sh"
#   Source the shared lib (S1-S4) to get get_tmux_option + resolve(). The handler uses resolve()
#   ONLY (the public API). (The test swaps this file for a FAKE via the staging dir.)
# query="$*"
#   RECOMBINE all argv into one space-joined string. CRITICAL (findings §6): command-prompt %%
#   substitution splits on spaces, so `my proj` arrives as $1=my $2=proj; "$*" recombines to
#   "my proj". NEVER use "$1". Empty if no args -> the if-block is skipped -> window in cur.
# cur=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
#   The current pane's cwd. In production (run-shell from a keybinding) the active client sets the
#   "current pane"; the test pins it via an isolated session. 2>/dev/null suppresses tmux noise.
# [ -z "$cur" ] && cur="$HOME"
#   Fallback if display-message returned nothing (no tmux / no pane). Defensive; matches PRD §5.4.
# session=$(tmux display-message -p '#{session_name}' 2>/dev/null)
#   The current session name, for the new-window target "$session:". Empty if no tmux -> new-window
#   -t "" may fail, but in production this always resolves.
# dir="$cur" ; if [ -n "$query" ]; then resolved=$(resolve "$query"); [ -n "$resolved" ] && dir="$resolved"; fi
#   Default to the current dir; ONLY override with the resolved dir when there's a query AND it
#   resolves non-empty (resolve returns empty on no-match, always exit 0 — S4 contract). This is
#   the consume pattern documented in P1M1T2S4/PRP.md DOWNSTREAM CONSUMERS.
# base=$(basename "$dir") ; tmux new-window -t "$session:" -c "$dir" -n "$base"
#   Name the window after the dir basename and open it in $dir. Exactly ONE window. -t "$session:"
#   targets the current session (trailing colon = the session, not a specific window).
```

### Verbatim content for `tests/test_z_window.sh`

Write **exactly** this. It is self-verifying (prints `PASS`/`FAIL`, exits non-zero on any failure),
was written + refined + run during research: **`RESULTS: pass=9 fail=0`, exit 0, empty stderr,
5 consecutive runs (no flake), shellcheck-clean**. (Validated in an isolated `/tmp` tree — the
repo was not modified during research.)

```sh
#!/bin/sh
# Integration tests for scripts/z-window.sh (P1.M2.T1.S1).
# TDD cases (item contract #3):
#   1. empty query  -> window opens in the CURRENT pane dir, named after basename
#   2. match        -> window opens in the RESOLVED dir, named after basename
#   3. no-match     -> window opens in the CURRENT pane dir (fallback)
#   4. spaced query -> "$*" recombines args (findings_and_risks.md §6); a spaced
#                      keyword still matches (distinguishes correct "$*" from "$1")
# Strategy (item contract #5): ISOLATED tmux server (tmux -L zxstest) so the user's
# live tmux is untouched; a fake tmux wrapper on PATH forwards to it; a FAKE
# lib/resolve.sh is staged so z-window.sh sources a deterministic resolver. We then
# assert the NEW window's cwd via '#{pane_current_path}' and name via '#{window_name}'.
# Requires: tmux 3.0+ on PATH. No live zoxide/rupa-z needed (fake resolve).

set -u

REAL_TMUX="$(command -v tmux)"
[ -n "$REAL_TMUX" ] || { echo "FATAL: tmux not found — cannot run integration test"; exit 1; }
SOCK=zxstest

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZWIN="$REPO_ROOT/scripts/z-window.sh"
[ -f "$ZWIN" ] || { echo "FATAL: $ZWIN not found"; exit 1; }

# --- staging: a fake plugin tree so z-window.sh sources OUR fake resolve ----------
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/scripts/lib"
cp "$ZWIN" "$STAGE/scripts/z-window.sh"
chmod +x "$STAGE/scripts/z-window.sh"

PROJDIR="$(mktemp -d)"   # the "resolved" dir for the match / spaced cases
cat > "$STAGE/scripts/lib/resolve.sh" <<RESOLVE
#!/bin/sh
# FAKE resolve for deterministic z-window.sh testing.
get_tmux_option() { :; }
resolve() {
    case "\$1" in
        proj|"my proj") printf '%s\n' "$PROJDIR" ;;   # match: single + spaced keyword
        *)             printf '\n' ;;                 # no-match: empty
    esac
    return 0
}
RESOLVE

# --- fake tmux wrapper: forward every call to the ISOLATED server (no recursion) ---
TBIN="$(mktemp -d)"
cat > "$TBIN/tmux" <<WRAPPER
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
WRAPPER
chmod +x "$TBIN/tmux"

cleanup() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    rm -rf "$STAGE" "$TBIN" "$PROJDIR"
}
trap cleanup EXIT INT TERM

# Pin default-shell on the ISOLATED server. Some sandboxes start tmux with an empty
# default-shell, causing new panes to spawn erratically (re-launching tmux) and
# eventually killing the server. A real login shell keeps panes alive and makes
# #{pane_current_path} reliably reflect the -c dir (mirrors production).  This is
# a TEST-HARNESS concern only; z-window.sh itself never sets default-shell.
DSHELL="${SHELL:-/bin/sh}"

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# fresh isolated server: one detached session 'zs', active pane in <curdir>.
# Order matters: start the server, set default-shell (no session yet), THEN create
# the session so its first pane inherits the pinned shell.
newserver() {
    "$REAL_TMUX" -L "$SOCK" kill-server >/dev/null 2>&1 || true
    sleep 0.25   # let the killed server release its socket before we restart
    "$REAL_TMUX" -L "$SOCK" start-server >/dev/null 2>&1 || true
    "$REAL_TMUX" -L "$SOCK" set-option -g default-shell "$DSHELL" >/dev/null 2>&1 || true
    "$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$1" >/dev/null 2>&1 || true
    sleep 0.3   # let #{pane_current_path} propagate to the -c dir
}
# run z-window.sh under test (fake resolve + isolated tmux on PATH).
run_zwin() { PATH="$TBIN:$PATH" "$STAGE/scripts/z-window.sh" "$@"; }
# window introspection
newest_win() { "$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1; }
win_cwd()    { "$REAL_TMUX" -L "$SOCK" display-message -t "zs:$1" -p '#{pane_current_path}'; }
win_name()   { "$REAL_TMUX" -L "$SOCK" display-message -t "zs:$1" -p '#{window_name}'; }

CURDIR="$(mktemp -d)"   # the "current pane" dir for empty/no-match cases

# --- case 1: empty query -> window in CURRENT pane dir ---------------------------
newserver "$CURDIR"
cur_seen=$("$REAL_TMUX" -L "$SOCK" display-message -p '#{pane_current_path}')
run_zwin ""            # empty query
sleep 0.3
w=$(newest_win)
check "empty query: window cwd == current pane dir"      "$cur_seen"           "$(win_cwd "$w")"
check "empty query: window name == basename(current dir)" "$(basename "$cur_seen")" "$(win_name "$w")"

# --- case 2: match -> window in RESOLVED dir ------------------------------------
newserver "$CURDIR"
run_zwin proj          # match -> resolve returns $PROJDIR
sleep 0.3
w=$(newest_win)
check "match: window cwd == resolved dir"            "$PROJDIR"              "$(win_cwd "$w")"
check "match: window name == basename(resolved dir)"  "$(basename "$PROJDIR")" "$(win_name "$w")"

# --- case 3: no-match -> window in CURRENT pane dir (fallback) -------------------
newserver "$CURDIR"
cur_seen=$("$REAL_TMUX" -L "$SOCK" display-message -p '#{pane_current_path}')
run_zwin zzz_nomatch_xyz   # no match -> resolve empty -> fallback to cur
sleep 0.3
w=$(newest_win)
check "no-match: window cwd == current pane dir"      "$cur_seen"           "$(win_cwd "$w")"
check "no-match: window name == basename(current dir)" "$(basename "$cur_seen")" "$(win_name "$w")"

# --- case 4: spaced query recombines via "$*" and STILL matches (findings §6) ----
# 'my proj' is passed as TWO args; z-window.sh's query="$*" recombines to 'my proj'.
# A buggy query="$1" would pass only 'my' -> no match -> fallback to cur. This case
# discriminates the correct form.
newserver "$CURDIR"
run_zwin my proj       # two args -> "$*" = "my proj" -> fake resolve matches
sleep 0.3
w=$(newest_win)
check "spaced query: window cwd == resolved dir (\"\$*\" recombination)" "$PROJDIR" "$(win_cwd "$w")"
check "spaced query: window name == basename(resolved dir)" "$(basename "$PROJDIR")" "$(win_name "$w")"

# --- case 5: exactly ONE new window is created per invocation --------------------
newserver "$CURDIR"
before=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
run_zwin proj
sleep 0.3
after=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
check "exactly one window created per invocation (delta==1)" "1" "$((after - before))"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

> The test is **self-contained** (no live tmux server touched, no live zoxide/rupa-z): one isolated
> `tmux -L zxstest` server; a fake `tmux` wrapper forwards the handler's bare `tmux` calls to it
> (absolute `$REAL_TMUX` prevents recursion); a staged fake `lib/resolve.sh` makes `resolve`
> deterministic (matches `proj`/`"my proj"` → `$PROJDIR`, else empty). The 0.25s/0.3s sleeps absorb
> the two socket/propagation races (gotchas). Assertions read the **newest window** (highest index)
> and check `#{pane_current_path}` + `#{window_name}` via `display-message -t "zs:$idx"`. **Case 4**
> is the TDD discriminator for `"$*"` vs `"$1"`. **Case 5** asserts exactly one window per invocation.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE scripts/z-window.sh  (PRD §5.4 verbatim, +x)
  - FILE: scripts/z-window.sh (NEW — does not exist yet)
  - CONTENT: the verbatim block above (PRD §5.4, byte-for-byte — no shellcheck directives, no option
    reads, no "improvements").
  - KEY FORMS: query="$*" (NOT "$1"); cur/session via `tmux display-message -p '#{...}'`;
    `resolved=$(resolve "$query")` then `[ -n "$resolved" ] && dir="$resolved"`; trailing
    `tmux new-window -t "$session:" -c "$dir" -n "$(basename "$dir")"`.
  - EXECUTABLE: chmod +x scripts/z-window.sh  (it is EXECUTED via run-shell, unlike sourced resolve.sh).
  - PRESERVE-OTHERS: do NOT touch scripts/lib/resolve.sh (S1-S4 own it), .gitignore, PRD.md.
  - STOP: do NOT create the run file / z-session.sh / README.md (later subtasks). Do NOT add option
    reads (key/prompt are run-file concerns).

Task 2: CREATE tests/test_z_window.sh  (isolated-tmux integration test, 9 cases)
  - FILE: tests/test_z_window.sh (NEW)
  - CONTENT: the verbatim block above (staging-dir fake resolve + fake-tmux wrapper + isolated
    server; the 0.25s kill/start sleep + 0.3s propagation sleep + default-shell pin are BAKED IN —
    do not remove them or the test flakes).
  - NAMING: test_z_window.sh (extends the test_resolve_*.sh / test_<unit>.sh pattern; this is the
    first FEATURE test, named after the handler).
  - PLACEMENT: tests/ at repo root (dev-only; not in PRD §5.1 ship tree — additive, like S1-S4).
  - COVERAGE: (1) empty → cur dir; (2) match → resolved dir; (3) no-match → cur dir; (4) spaced
    query "$*" recombination; (5) exactly one window per invocation. Cases 1-4 also assert the NAME.
  - CRITICAL: the test FAKES resolve (staging-dir) so it is INDEPENDENT of P1.M1.T2.S4's completion
    and of the live zoxide DB. Do NOT point it at the real resolve.sh. Copy verbatim.
  - SELF-VERIFY: prints PASS/FAIL per case; exits non-zero on any failure; cleans up (server kill +
    rm staging/tmp dirs) via trap.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: shellcheck --exclude=SC1091 scripts/z-window.sh        # expect exit 0, NO output
  - RUN: shellcheck tests/test_z_window.sh                       # expect exit 0, NO output
  - RUN: sh tests/test_z_window.sh                               # expect "RESULTS: pass=9 fail=0", exit 0
  - RUN: test -x scripts/z-window.sh && echo "executable OK"     # expect executable OK
  - RUN: sh tests/test_resolve_get_tmux_option.sh                # S1 still passes (no regression)
  - RUN: sh tests/test_resolve_zoxide.sh                         # S2 still passes
  - RUN: sh tests/test_resolve_z.sh                              # S3 still passes
  # (S4's test, if present by now, is also unaffected — this subtask never edits resolve.sh.)
  - RUN: grep -n 'query="\$' scripts/z-window.sh                 # expect `query="$*"` (NOT "$1")
  - RUN: git status --short                                       # only the two new files; PRD.md/.gitignore untouched
```

### Implementation Patterns & Key Details

```sh
# The handler's only non-trivial pattern — the resolve consume + fallback:
#   dir="$cur"                                           # default: current pane dir
#   if [ -n "$query" ]; then                             # only resolve when there's a query
#       resolved=$(resolve "$query")                     # S4 contract: path-or-empty, always exit 0
#       [ -n "$resolved" ] && dir="$resolved"            # override ONLY on a non-empty match
#   fi
#   tmux new-window -t "$session:" -c "$dir" -n "$(basename "$dir")"
#
# Why `resolved=$(resolve ...)` is safe even before CORRECTION-B fully lands: command substitution
#   `$(...)` DISCARDS the inner exit status, capturing only stdout. So even if a backend exited
#   non-zero, `resolved` gets the (possibly empty) output and the handler branches on emptiness —
#   the documented consume pattern. CORRECTION-B (S4) makes resolve() exit 0 too (belt+suspenders).
#
# Why `query="$*"` and not `"$1"` (findings §6): command-prompt `%%` is textual + splits on spaces,
#   so `my proj` -> argv [my, proj]. `"$*"` recombines to "my proj". `"$1"` would pass only "my" and
#   silently break spaced queries. The handler treats the query as DATA (never eval'd) — passed to
#   resolve()/new-window as a string argument, so shell-metachar injection is inert.
#
# Why `-t "$session:"` (trailing colon): targets the session (its active window / next free index),
#   not a specific window. Creates the new window in that session. Exactly one window per call.
#
# Testing pattern (item contract #5) — why a REAL isolated tmux server + fake resolve, not pure
#   unit fakes like S1-S4: z-window.sh's core behavior is a `tmux new-window -c <dir>` SIDE EFFECT.
#   Asserting "the new window's cwd == resolved dir" requires observing real tmux state. So we drive
#   a real (isolated, `tmux -L zxstest`) server, but inject a FAKE resolve for deterministic input.
#   The two are reconciled by a fake `tmux` wrapper on PATH that forwards to the isolated server.
```

### Integration Points

```yaml
FILESYSTEM:
  - create: "scripts/z-window.sh   (PRD §5.4 verbatim; EXECUTABLE — run-shell invokes it)"
  - create: "tests/test_z_window.sh   (dev integration test; +x optional — harmless)"

NO OPTIONS / CONFIG / HOOKS:
  - z-window.sh reads NO tmux options (key/prompt are run-file concerns). This subtask adds no
    options, no hooks, no keybindings. (Wiring belongs to P1.M2.T2.S1.)
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only). scripts/lib/resolve.sh:
    UNCHANGED (S1-S4 own it).

UPSTREAM DEPENDENCY (treat as contract):
  - scripts/lib/resolve.sh `resolve()` (P1.M1.T2.S4, parallel): z-window.sh calls
    `resolved=$(resolve "$query")`. Contract: one path line on match / empty on no-match / always
    exit 0. (The handler is robust even without CORRECTION-B via command-substitution status
    discarding; CORRECTION-B adds belt+suspenders.)

DOWNSTREAM CONSUMER (this subtask unblocks):
  - P1.M2.T2.S1 (run file): wires `tmux bind-key "$key" command-prompt -p "$prompt"
    "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"` (PRD §5.2). The `%%` is tmux's textual
    query substitution (splits on spaces; z-window.sh recombines via "$*").
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — POSIX-sh posture. SC1091 (info, dynamic source path) is the one ACCEPTED info:
# it is unavoidable for a script sourcing a computed path and is benign. Exclude it to keep the
# handler PRD-verbatim (no in-file directive). MUST exit 0 with NO output.
shellcheck --exclude=SC1091 scripts/z-window.sh
shellcheck tests/test_z_window.sh
# (Verified during research: exit 0, zero findings on both.)

# Confirm the $* recombination (NOT $1). Expect exactly `query="$*"`:
grep -n 'query="\$' scripts/z-window.sh
# Expected: one line — `query="$*"`.

# Confirm POSIX-clean + no option reads. Expect NO matches:
grep -nE '\blocal\b|\[\[|==|\becho -e\b|get_tmux_option|@zoxide-sessions-' scripts/z-window.sh
# Expected: nothing prints (the handler sources resolve.sh which DEFINES get_tmux_option, but the
# handler itself never calls it / reads options).

# Expected: shellcheck exits 0 silently; the $* grep shows `query="$*"`; the anti-pattern grep is empty.
```

### Level 2: Integration Tests (Component Validation) — the authoritative gate

```bash
# The isolated-tmux integration test (item contract #5). Requires tmux 3.0+ (confirmed present).
# Drives tmux -L zxstest (the user's LIVE tmux is untouched), injects a FAKE resolve for determinism.
sh tests/test_z_window.sh
# Expected output ends with:  RESULTS: pass=9 fail=0   and exit code 0, EMPTY stderr.
# (Verified during research: 5 consecutive runs, 0 flakes.
#  Case 1 empty -> cur dir; 2 match -> resolved dir; 3 no-match -> cur dir (fallback);
#  4 spaced query "$*" recombination; 5 exactly one window per invocation. Cases 1-4 also assert
#  the window NAME. If case 4 fails, the handler uses "$1" not "$*" — fix to "$*".
#  If you see "server exited unexpectedly", the default-shell pin or the kill/start sleep was
#  removed from newserver() — restore them verbatim from the PRP.)

# Regression guards: the S-series resolve tests must still pass (this subtask never edits resolve.sh).
sh tests/test_resolve_get_tmux_option.sh   # S1: expect RESULTS: pass=6 fail=0, exit 0
sh tests/test_resolve_zoxide.sh            # S2: expect RESULTS: pass=3 fail=0, exit 0
sh tests/test_resolve_z.sh                 # S3: expect RESULTS: pass=5 fail=0, exit 0
# (S4's test_resolve_dispatcher.sh, if present by now, is likewise unaffected.)
```

### Level 3: Executable-bit + Sourceability (System Validation)

```bash
# 3a. The handler is executable (run-shell invokes it directly).
test -x scripts/z-window.sh && echo "z-window.sh executable OK" || echo "NOT executable — run chmod +x"

# 3b. The handler sources resolve.sh cleanly (the resolve() it calls is provided by S4). NOTE: this
#     check requires S4's resolve() to be present; if S4 is not yet merged, this line will error on
#     `resolve` being undefined ONLY IF you actually invoke resolve — sourcing alone is fine.
sh -c '. scripts/lib/resolve.sh; type get_tmux_option >/dev/null && echo "resolve.sh sources OK"'
# Expected: resolve.sh sources OK (and, once S4 lands, `type resolve` also resolves).

# 3c. The handler's own structure (sanity): it must end with the new-window call.
tail -1 scripts/z-window.sh
# Expected: `tmux new-window -t "$session:" -c "$dir" -n "$base"`
```

### Level 4: Live smoke (OPTIONAL — not a gate; the Level 2 test is authoritative)

```bash
# A live end-to-end smoke against the user's REAL tmux + REAL zoxide. ONLY if you want to confirm
# the production path against a populated frecency DB. Requires an attached tmux session + zoxide.
# This is a manual sanity check, NOT automated (the deterministic Level 2 test is the gate).
if command -v tmux >/dev/null 2>&1 && [ -n "$TMUX" ]; then
    echo "live smoke: run in tmux:  scripts/z-window.sh <known-query>"
    scripts/z-window.sh tmux   # opens a window in zoxide's match for "tmux" (or current dir if no match)
    # verify: a new window opened, named after the matched dir's basename
else
    echo "skipped live smoke (not inside tmux) — Level 2 isolated test is the authoritative gate"
fi
```

## Final Validation Checklist

### Technical Validation

- [ ] `shellcheck --exclude=SC1091 scripts/z-window.sh` exits 0 with no output.
- [ ] `shellcheck tests/test_z_window.sh` exits 0 with no output.
- [ ] `sh tests/test_z_window.sh` prints `RESULTS: pass=9 fail=0` and exits 0 (empty stderr).
- [ ] `test -x scripts/z-window.sh` → executable OK.
- [ ] S1/S2/S3 resolve tests still pass (no regression); S4 unaffected.
- [ ] `query="$*"` present (grep); no `local`/`[[ ]]`/`==`/`echo -e`/option-reads in the handler.
- [ ] Handler ends with the `tmux new-window ...` call.

### Feature Validation

- [ ] Empty query → new window in current pane dir, named basename (case 1).
- [ ] Match → new window in resolved dir, named basename (case 2).
- [ ] No-match → new window in current pane dir, fallback (case 3).
- [ ] Spaced query (`my proj`) → recombines via `"$*"` and matches (case 4 — discriminates `"$1"`).
- [ ] Exactly one window created per invocation (case 5, delta == 1).
- [ ] Handler is option-agnostic (reads neither `@zoxide-sessions-key` nor `@zoxide-sessions-prompt`).

### Code Quality Validation

- [ ] Handler is **PRD §5.4 byte-for-byte** (no shellcheck directives, no option reads, no deviations).
- [ ] POSIX-`sh` clean (no `local`/`[[ ]]`/arrays/`==`/`echo -e`).
- [ ] File placement matches the desired tree (`scripts/z-window.sh` new + executable; `tests/test_z_window.sh` new).
- [ ] The test FAKES resolve (staging-dir) — independent of P1.M1.T2.S4 and the live zoxide DB.
- [ ] The test's default-shell pin + 0.25s/0.3s sleeps are present (verbatim) — the two races are absorbed.
- [ ] `scripts/lib/resolve.sh`, `.gitignore`, `PRD.md` unmodified.

### Documentation & Deployment

- [ ] Inline header comment documents usage + the match/no-match behavior (PRD §5.4 verbatim).
- [ ] No README/option changes (item contract #6, Mode A): the `@zoxide-sessions-key`/`-prompt`
      defaults (`g`/`z to:`) are owned by the run file, authored wholesale in P1.M4.T1. This subtask
      touches neither the run file nor the README.
- [ ] No new tmux options, hooks, or environment variables introduced by the handler.

---

## Anti-Patterns to Avoid

- ❌ Don't change `query="$*"` to `query="$1"` — that **breaks spaced queries** (findings §6:
  `command-prompt %%` splits on spaces; `"$*"` recombines). Case 4 is the discriminator.
- ❌ Don't deviate from PRD §5.4 — the handler is **verbatim**. No shellcheck directives (use
  `--exclude=SC1091` in the gate instead), no option reads, no "improvements," no extra error handling.
- ❌ Don't point the test at the REAL `scripts/lib/resolve.sh` — it would call real `zoxide query`
  and become non-deterministic (depends on the live DB). The test STAGES a FAKE resolve. (The real
  resolve.sh is never modified and never exercised by this test.)
- ❌ Don't drop the default-shell pin or the 0.25s/0.3s sleeps from `newserver()` — without them the
  test flakes/crashes in this sandbox (empty default-shell panes misbehave; kill/start races the
  socket; `#{pane_current_path}` needs a moment to settle). Copy the test **verbatim**.
- ❌ Don't make the fake `tmux` wrapper call bare `tmux` — it would recurse (PATH finds the wrapper
  again). It MUST `exec "$REAL_TMUX" -L zxstest "$@"` with the **absolute** real-tmux path.
- ❌ Don't `chmod +x` `scripts/lib/resolve.sh` — it's SOURCED (S1-S4 invariant). Only `z-window.sh`
  is executed (+x).
- ❌ Don't modify `scripts/lib/resolve.sh` (S1-S4 own it), `.gitignore`, or `PRD.md`.
- ❌ Don't create the run file / `z-session.sh` / `README.md` (P1.M2.T2 / P1.M3 / P1.M4 own them).
- ❌ Don't add option reads to the handler (`@zoxide-sessions-key`/`-prompt` are run-file concerns).
- ❌ Don't pull in bats/shunit2/sharness — dependency-free POSIX-sh test (item contract #5).
- ❌ Don't `eval` or otherwise execute the query — it's DATA, passed to `resolve()`/`new-window`.

---

## Scope Boundaries (explicit)

| Item | This subtask (P1.M2.T1.S1) | Other subtasks |
| --- | --- | --- |
| `scripts/z-window.sh` | ✅ CREATE (PRD §5.4 verbatim, +x) | P1.M2.T2.S1 consumes it (binding) |
| `tests/test_z_window.sh` | ✅ CREATE (isolated-tmux integration test) | extends the test_<unit>.sh pattern |
| `scripts/lib/resolve.sh` (`resolve()`) | ❌ DO NOT (treat as contract) | S1-S4 own it (S4 parallel) |
| `tmux-zoxide-sessions.tmux` (run file / binding) | ❌ DO NOT | P1.M2.T2.S1 |
| `@zoxide-sessions-key` / `-prompt` options | ❌ DO NOT (handler reads neither) | run file (P1.M2.T2) / README (P1.M4.T1) |
| `z-session.sh`, session hook | ❌ DO NOT | P1.M3 |
| `README.md`, LICENSE | ❌ DO NOT | P1.M1.T1 (LICENSE done) / P1.M4.T1 (README) |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 9.5/10** — the implementation is PRD §5.4 verbatim (the spec's own complete
listing), and the 9-case integration test was **written, run, and refined in an isolated `/tmp`
tree** during research: **`RESULTS: pass=9 fail=0`, exit 0, empty stderr, 5 consecutive runs with
zero flakes**, and `shellcheck` exit 0 / no output on both files (with `--exclude=SC1091` for the
handler's unavoidable dynamic-source info). Every non-obvious testing hurdle was hit, diagnosed, and
fixed empirically — the `#{pane_current_path}` propagation race (sleep 0.3), the empty-`default-shell`
sandbox quirk (pin via `set-option -g`), the `kill-server`→`start-server` socket race (sleep 0.25),
and the fake-`tmux` wrapper recursion (absolute `$REAL_TMUX`) — and is documented in
`research/verification_notes.md` with the empirical evidence. The staging-dir fake-resolve injection
makes the test **independent** of P1.M1.T2.S4 (parallel) and of the live zoxide DB, so it passes
whether or not S4 has landed. The `"$*"` recombination is turned into a discriminating assertion
(case 4) per findings §6. The residual half-point: `/bin/sh`→bash on this box (POSIX posture enforced
via shellcheck, not a real dash run), and the optional live smoke depends on a populated zoxide DB
(the self-contained Level 2 test is the authoritative, machine-independent gate that absorbs this).
This subtask unblocks P1.M2.T2.S1 (the run-file binding).
