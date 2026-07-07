# PRP — P1.M3.T1.S1: `scripts/z-session.sh` session-created handler (the guard chain)

## Goal

**Feature Goal**: Create `scripts/z-session.sh` — the **session auto-relocate handler** — per
**PRD §5.5 verbatim**. It implements the full 10-step **guard chain** (PRD §3.2): given a session
name as `$1`, it relocates the session's first pane from `$HOME` to the zoxide-resolved directory
matching the name — but **only** when the session (1) is under the master toggle, (2) has a
non-empty, non-whitelisted name, (3) whose first pane actually landed in `home-dir` (default
`$HOME`), and (4) zoxide resolves the name. Everything else (resurrect/continuum-restored,
sessionx/sesh-placed, project-dir-originated, no-match, whitelisted, master-off) is left
untouched. **Always exits 0.** Every `tmux` call is guarded `2>/dev/null || exit 0`.

**Deliverable**: Two artifacts —
1. `scripts/z-session.sh` — **NEW**, PRD §5.5 **verbatim** (shebang `#!/bin/sh`, the full PRD §5.5
   header comment, `SCRIPT_DIR` resolution, `. "$SCRIPT_DIR/lib/resolve.sh"`, the 10-step guard
   chain: master-toggle `off`→exit; `name="$1"` empty→exit; `for s in $skip_names` skip-list
   (default `home main`); `pane=$(display-message -t "$name" -p '#{pane_id}')`; `path=$(display-message
   -t "$pane" -p '#{pane_current_path}')`; `home_dir` option (default `$HOME`); `_norm()` via
   `readlink -f` + trailing-slash collapse → compare, `!= `→exit; `resolved=$(resolve "$name")`
   empty→exit; `respawn-pane -t "$pane" -c "$resolved" -k`; and the `window-name==session` branch
   renaming the first window). **`chmod +x`** (this subtask owns the executable bit for the script —
   TPM/hook exec it via `run-shell`; P1.M4.T2.S1 commits the bit).
2. `tests/test_z_session.sh` — a dependency-free POSIX-`sh` **integration** test on an **isolated**
   tmux server (`tmux -L zxstest_session`), driving the REAL `z-session.sh` + REAL `resolve.sh`
   unmodified via a fake `tmux` wrapper + fake `zoxide`. TDD-covers **PRD §7 cases 1–4, 6, 7, 9**:
   relocate-fires (resolvable @ home) / skip-list / no-match / not-`$HOME` / master-off /
   window-name / spaced name. Asserts pane cwd post-respawn via `display-message -p
   '#{pane_current_path}'` (item contract #5). Prints `RESULTS: pass=8 fail=0`, exit 0.

**Success Definition**:
- `scripts/z-session.sh` exists, is **PRD §5.5 verbatim**, is `chmod +x`, and `shellcheck` reports
  **only SC1091** (the dynamic `$SCRIPT_DIR/lib/resolve.sh` source — identical profile to the
  shipped `z-window.sh`; verified during research — see `research/verification_notes.md` §6).
- `sh tests/test_z_session.sh` prints `RESULTS: pass=8 fail=0` and exits 0 (C1 relocate / C2
  skip-list / C3 no-match / C4 not-`$HOME` / C6 master-off / C7 window-name / C8 spaced-name +
  the implicit pre-relocate home-cwd check = 8 asserts), validated empirically during research —
  see `research/verification_notes.md` §1.
- `resolve.sh`, `z-window.sh`, `tmux-zoxide-sessions.tmux`, the S1–S4 tests, `test_z_window.sh`,
  and `test_run_file.sh` are **unmodified**; `.gitignore`/`PRD.md` untouched; only
  `scripts/z-session.sh` is chmod'd by this subtask. **No** `set-hook` / run-file edit / hook
  wiring (that is **P1.M3.T2.S1** — this subtask only ships the handler + its direct-invocation test).

## User Persona

**Target User**: The implementing AI agent (subtask executor); ultimately the end user creating a
session "from `$HOME`" — e.g. `tmux new -s sellario` (from `$HOME`), `prefix :` `new-session`, or
`ssh host; tmux new -s bar` — whose first pane lands in `$HOME` and whom this feature silently
relocates to the zoxide-resolved directory matching the name.

**Use Case**: A new session is created by any path the plugin did **not** intercept (sessionx/sesh
only zoxide-resolve sessions they create). The `session-created` hook (wired in P1.M3.T2.S1)
invokes `z-session.sh "<name>"` in the background. The handler checks whether the session is a
"bare/default" creation (first pane in `$HOME`, resolvable name, not whitelisted, master on) and,
if so, `respawn-pane -c <resolved> -k` — moving the pane to the right directory with one brief
flicker. Sessions placed by resurrect/continuum/sessionx/sesh or from a project dir never land in
`$HOME`, so the `path == home` guard skips them.

**Pain Points Addressed**: The user wants every new session to open in the right project directory
without typing a path, regardless of how the session was created. The plugin is a safety net for
the sessions no other tool zoxide-enhances.

## Why

- This subtask is the **handler half of milestone P1.M3** (session auto-relocate). The companion
  P1.M3.T2.S1 ships the `set-hook` wiring that invokes this script. The split mirrors P1.M2 (T1 =
  `z-window.sh` handler, T2 = the binding that invokes it): ship the handler + its self-contained
  test now; wire the hook next. z-session.sh takes the name as a single `$1`, so it is fully
  testable by **direct invocation** (`$ZSESS "$name"`) before any hook exists.
- The handler body is **PRD §5.5 verbatim** — no design decisions remain. The only implementation
  risk is **testing it deterministically** without touching the user's live tmux and without the
  `#{pane_current_path}`-lags gotcha that bit `test_z_window.sh`. Both are solved and empirically
  validated (research/verification_notes.md §2): `respawn-pane -c <dir> -k` DOES reliably update
  `#{pane_current_path}` (after a 0.5 s settle sleep) — unlike a freshly `new-window`'d pane, a
  respawned pane's restarted shell initializes at the `-c` dir and tmux tracks it.
- The safety model (skip restored/sessionx/sesh/project sessions) rests entirely on the
  `path == home` guard, whose correctness is confirmed from primary source (external_deps.md §3:
  resurrect restores with `-c "$saved_dir"`, continuum reuses resurrect). The `_norm`/
  `readlink -f` comparison was exercised end-to-end during research (verification_notes §3).

## What

User-visible behavior (after this subtask; the hook is wired in P1.M3.T2.S1):

- Invoked as `z-session.sh "<name>"` (the hook passes `#{session_name}` as a single quoted `$1`),
  the script runs the guard chain (PRD §3.2): master off → exit; empty name → exit; name in
  skip-list → exit; find the session's first pane; if its cwd normalizes to `home-dir` (default
  `$HOME`), and `resolve "<name>"` returns a directory, `respawn-pane -c <resolved> -k` the pane
  and (optionally, if `@zoxide-sessions-window-name == session`) rename the first window to `<name>`.
- A session NOT at `home-dir`, OR whose name does not resolve, OR is whitelisted, OR when the
  master toggle is off, is left exactly as-is. The script always exits 0; no `tmux` error ever
  propagates (`2>/dev/null || exit 0` on every tmux call).

### Success Criteria

- [ ] `scripts/z-session.sh` exists, is executable (`test -x`), and is **PRD §5.5 verbatim**
      (eyeball against PRD §5.5; the 10-step chain in order; every tmux call guarded).
- [ ] It sources `$SCRIPT_DIR/lib/resolve.sh` and uses `get_tmux_option` (S1) + `resolve` (S4) —
      it does **not** reimplement option reading or the resolver.
- [ ] It **always exits 0** (`exit 0` terminus; every `tmux … 2>/dev/null || exit 0`).
- [ ] It contains **no** `set-hook`, no `bind-key`, no run-file logic, no `#{session_name}`/hook
      wiring — it is the pure handler (hook = P1.M3.T2.S1).
- [ ] `shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | sort -u` → only `SC1091`
      (matches the shipped `z-window.sh`).
- [ ] `sh tests/test_z_session.sh` → `RESULTS: pass=8 fail=0`, exit 0.
- [ ] `resolve.sh`/`z-window.sh`/run file unchanged; S1–S4 + `test_z_window.sh` + `test_run_file.sh`
      still pass (no regression).
- [ ] `.gitignore` / `PRD.md` unmodified; only `scripts/z-session.sh` is chmod'd (`+x`).

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this
successfully?_ **Yes.** The handler body is reproduced **verbatim** from PRD §5.5 and was exercised
end-to-end (8/8 cases pass) against the real `resolve.sh` on an isolated tmux server during
research. The 8-case integration test is specified end-to-end (isolated socket `zxstest_session` +
fake `tmux` wrapper + fake `zoxide`, PATH set before boot, `@zoxide-sessions-home-dir` pointed at a
fixture dir so the test never touches the real `$HOME`). The single non-obvious tmux gotcha — that
`respawn-pane -c <dir> -k` updates `#{pane_current_path}` only after a brief settle sleep (0.5 s),
which is the **opposite** of `test_z_window.sh`'s finding that `#{pane_current_path}` "lags" for a
freshly created window — is surfaced, justified, and empirically confirmed in
`research/verification_notes.md` §2. The shellcheck gate is stated accurately ("only SC1091",
matching `z-window.sh`) — **not** "`-x` → rc 0", which does not hold for dynamic-source scripts
(§6). `shellcheck` + `tmux` are the only tools (both confirmed installed). No codebase knowledge
beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source — the handler body is copied VERBATIM from here.
  section: "§5.5 scripts/z-session.sh (the ENTIRE code block, byte-for-byte). §3.2 the guard chain
            (the 10 numbered steps = a prose restatement of §5.5). §4 Options (@zoxide-sessions-
            auto-session default 'on', -skip-names default 'home main', -home-dir default '$HOME',
            -window-name default 'off' — the four this script reads). §7 test matrix cases 1-4,6,7,9
            (the TDD scope). §8 known limitations (flicker, skip-names whitespace, readlink -f GNU)."
  critical: "Copy §5.5 VERBATIM. Keep the header comment. Keep EVERY 'tmux ... 2>/dev/null || exit 0'
             guard and the final 'exit 0' — the contract is 'always exits 0'. The _norm function and
             the case/window-name branch are exactly as written. Do NOT add set -e, logging, a probe,
             or hook-wiring code (hook = P1.M3.T2.S1)."

- file: plan/001_afc2c7373095/P1M3T1S1/research/verification_notes.md
  why: Empirical proof grounding every gate — the 8/8 pass result, the respawn/pane_current_path
       finding (the decisive unknown), _norm correctness, the deterministic home-dir approach, the
       spaced-name $1-integrity proof (no file-mutating probe needed), and the accurate shellcheck
       profile.
  section: "§1 RESULT (8/8); §2 respawn updates #{pane_current_path} after 0.5s (NOT laggy like
            new-window); §3 _norm/readlink -f correct; §4 home-dir via fixture (deterministic, not
            real $HOME); §5 spaced $1 proven via the resolve->respawn chain (no probe); §6 shellcheck
            = SC1091-only (NOT -x rc 0); §7 harness idiom reused; §8 dependency/non-modify invariants"
  critical: "§2: assert post-respawn cwd via #{pane_current_path} WITH a >=0.4s sleep; do NOT swap to
             #{pane_start_path} (respawn doesn't guarantee updating it; contract says current_path).
             §6: the clean gate is 'only SC1091' (grep -Eo 'SC[0-9]+' | sort -u == SC1091), matching
             z-window.sh. shellcheck -x does NOT yield rc 0 here (dynamic $SCRIPT_DIR source) — do not
             gate on -x rc 0. §5: do NOT add an echo probe to the script; the spaced-name assertion
             already proves $1 integrity through the chain."

- file: scripts/lib/resolve.sh
  why: The DEPENDENCY the handler sources — its get_tmux_option() (S1) + resolve() (S4) contracts.
       NOT modified by this subtask.
  section: "get_tmux_option <name> <default> -> value-or-default (reads tmux show-option -gqv; empty
            for an unset @-option -> default). resolve <query> -> dir or empty; ALWAYS exits 0 (S4
            ends with 'return 0') — so 'resolved=$(resolve "$name") || exit 0' never trips on status;
            the '[ -n "$resolved" ] || exit 0' is what gates on no-match."
  critical: "z-session.sh calls get_tmux_option FOUR times (auto-session, skip-names, home-dir,
             window-name) and resolve() once. resolve() always exits 0 (S4 CORRECTION B) — callers
             check OUTPUT, not status. Do NOT modify resolve.sh; do NOT reimplement resolving."

- file: scripts/z-window.sh
  why: The shipped SIBLING handler (P1.M2.T1.S1, PRD §5.4 verbatim). z-session.sh mirrors its
       preamble (SCRIPT_DIR + . resolve.sh) and its shellcheck profile (SC1091-only). The test
       REUSES test_z_window.sh's harness idiom unchanged.
  section: "the SCRIPT_DIR idiom; the 'source resolve.sh then call tmux' structure; the proven
            isolated-server + fake-tmux-wrapper + fake-zoxide test idiom (test_z_window.sh)."
  critical: "z-session.sh is the SESSION analogue of z-window.sh (window: new-window -c resolved;
             session: respawn-pane -c resolved). Both are PRD-verbatim, both chmod +x, both
             SC1091-only. The test copies test_z_window.sh's skeleton verbatim and swaps the
             per-case setup/assertions."

- file: tests/test_z_window.sh
  why: The GOLD-STANDARD test to clone. Its harness (REAL_TMUX/SOCK/REPO_ROOT, FIX fixture with REAL
       resolved dirs, TBIN fake-tmux + fake-zoxide, PATH-before-boot, set -u + check() + trap cleanup
       + RESULTS:) is reused with a new socket and z-session-specific cases.
  section: "the whole file — harness skeleton, fake-tmux/fake-zoxide construction, the check() helper,
            the cleanup trap, the 'RESULTS: pass=N fail=M' footer + '[ $fail -eq 0 ]' exit."
  critical: "DIFFERENCES from test_z_window.sh: (1) new socket 'zxstest_session' (avoid collision with
             parallel window/run tests); (2) set @zoxide-sessions-home-dir to a FIXTURE dir so the test
             never respawns a real-$HOME session and is deterministic; (3) create the session FIRST
             (new-session -d -s <name> -c <start>), then invoke $ZSESS \"$name\" (the hook's dispatch),
             then sleep 0.5 and assert #{pane_current_path} (test_z_window used #{pane_start_path} for
             new-window — do NOT copy that, respawn uses current_path)."

- file: plan/001_afc2c7373095/architecture/external_deps.md
  why: The safety model + testing-strategy guidance.
  section: "§3 resurrect linchpin (restores with -c "$saved_dir" -> never $HOME -> the path==home
            guard's correctness basis); §4 sessionx/sesh coexistence (placed with -c -> skipped);
            §6 testing strategy (isolated tmux -L server, fake tmux/zoxide, assert via display-message)."
  critical: "The path==home guard is SOUND because restored/sessionx/sesh/project sessions are created
             with an explicit -c dir, so they never equal home_dir. §6 mandates the isolated-server +
             fake-binary mock (no bats/shunit2)."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: The validated findings the handler relies on.
  section: "✅1 session-created timing (fires after session+first pane exist -> display-message -t
            <name> -p '#{pane_id}' returns the new pane, #{pane_current_path} readable); ✅2 run-shell
            -b non-blocking; ✅3 respawn-pane -c -k sets cwd, -k kills old shell, preserves window name
            + geometry; ✅4 resurrect -c linchpin; ✅5 zoxide query empty+exit0 on no-match."
  critical: "✅1 + ✅3 are why the guard chain works: at hook fire the pane exists and is queryable,
             and respawn-pane -c relocates it. ✅5 (zoxide empty+exit0) is why 'resolved=$(resolve)'
             + '[ -n "$resolved" ]' gates no-match correctly."

- file: plan/001_afc2c7373095/P1M2.T2.S1/PRP.md
  why: The run-file PRP (currently being implemented in parallel). CONTRACT: the run file at repo
       root will be PRD §5.2 PART 1 only (window binding); it does NOT yet contain the session-hook
       block. This subtask does NOT touch it.
  section: "Deliverable + Scope Boundaries — P1.M2.T2.S1 owns the run file PART 1; P1.M3.T2.S1 will
            APPEND the '# --- 2. Session auto-relocate hook' block (set-hook -g session-created
            \"run-shell -b '<abs>/scripts/z-session.sh \\\"#{session_name}\\\"'\") to it."
  critical: "This subtask does NOT edit tmux-zoxide-sessions.tmux and does NOT add the set-hook.
             z-session.sh is invoked in the TEST by direct execution ($ZSESS \"$name\"), which is
             exactly what the hook's run-shell dispatch will do. The run file is P1.M2.T2.S1's
             deliverable; leave it alone."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State AFTER P1.M1 (resolver complete) + P1.M2.T1.S1 (z-window.sh) + P1.M2.T2.S1 (run file, in flight).
# z-session.sh does NOT yet exist.
$ ls -la scripts scripts/lib
scripts:
lib          z-window.sh     # z-window.sh: P1.M2.T1.S1 deliverable (PRD §5.4 verbatim, chmod +x) — SIBLING
scripts/lib:
resolve.sh   # COMPLETE: get_tmux_option + _resolve_zoxide + _resolve_z + resolve  (the dep z-session.sh sources)
$ ls -la
... tmux-zoxide-sessions.tmux   # P1.M2.T2.S1 deliverable (PRD §5.2 PART 1; PART 2 appended by P1.M3.T2.S1)
$ ls tests
test_resolve_get_tmux_option.sh   test_resolve_zoxide.sh   test_resolve_z.sh   test_resolve_dispatcher.sh
test_z_window.sh                  test_run_file.sh         # the harness idiom this test EXTENDS

# resolve.sh — the functions z-session.sh calls:
$ grep -nE '^get_tmux_option\(\)|^resolve\(\)' scripts/lib/resolve.sh
6:get_tmux_option()   # S1 — option reader (tmux show-option -gqv <name> || default)
36:resolve()          # S4 — dispatcher; ends 'return 0' (ALWAYS exits 0; CORRECTION B)

# z-window.sh preamble (the idiom z-session.sh mirrors):
$ head -3 scripts/z-window.sh
#!/bin/sh
# Open a new tmux window in the current session, ...
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"   # <- z-session.sh uses the SAME idiom

# Tooling on this machine:
$ command -v shellcheck tmux sh && shellcheck --version | head -2 | tail -1 && tmux -V
/usr/bin/shellcheck   # v0.11.0 — 'only SC1091' is the clean gate for dynamic-source scripts
/usr/bin/tmux         # tmux 3.6b — drives the ISOLATED test server (never the live one)
/usr/bin/sh           # POSIX sh for the test (dash/bash alike)

# Sibling shellcheck profile (z-session.sh will match this EXACTLY):
$ shellcheck scripts/z-window.sh 2>&1 | grep -Eo 'SC[0-9]+' | sort -u
SC1091
$ shellcheck scripts/lib/resolve.sh 2>&1 | grep -Eo 'SC[0-9]+' | sort -u
(empty)   # resolve.sh has NO dynamic source -> genuinely clean
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  tmux-zoxide-sessions.tmux  # (UNCHANGED — P1.M2.T2.S1; PART 2 hook appended by P1.M3.T2.S1, NOT here)
  scripts/
    lib/
      resolve.sh             # (UNCHANGED — COMPLETE; z-session.sh only SOURCES it)
    z-window.sh              # (UNCHANGED — P1.M2.T1.S1; the window sibling)
    z-session.sh             # NEW — PRD §5.5 verbatim; chmod +x (the session handler)
  tests/
    test_resolve_get_tmux_option.sh   # (S1, unchanged — re-run for regression)
    test_resolve_zoxide.sh            # (S2, unchanged)
    test_resolve_z.sh                 # (S3, unchanged)
    test_resolve_dispatcher.sh        # (S4, unchanged)
    test_z_window.sh                  # (P1.M2.T1.S1, unchanged — re-run for regression)
    test_run_file.sh                  # (P1.M2.T2.S1, unchanged — re-run for regression)
    test_z_session.sh                 # NEW — isolated-tmux-server integration test (8 asserts)
```

`scripts/z-session.sh` is the **first and only** file this subtask creates, and the **only** file it
chmod's (`+x`). `tests/test_z_session.sh` is the only test it adds.

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (VERBATIM): Copy PRD §5.5 byte-for-byte. Do NOT 'improve': keep the header comment, keep
#   the SCRIPT_DIR idiom, keep . "$SCRIPT_DIR/lib/resolve.sh", keep the 10-step chain in order, keep
#   EVERY 'tmux ... 2>/dev/null || exit 0' guard (8 of them: pane lookup, path lookup, respawn, window-
#   id lookup, rename — plus the [ -n ] short-circuits), keep _norm() exactly (readlink -f ||
#   printf '%s' fallback + trailing-slash 'printf %s/ | sed s#//*#/#g'), keep the case/window-name
#   branch, keep the final 'exit 0'. No set -e, no logging, no probe, no hook code.
# CRITICAL (ALWAYS EXIT 0): The contract (PRD §3.2 + item contract #4) is "always exits 0". Every tmux
#   call is '... 2>/dev/null || exit 0' and the script ends in 'exit 0'. resolve() ALSO always exits 0
#   (S4 CORRECTION B), so 'resolved=$(resolve "$name") || exit 0' never trips on status — the
#   '[ -n "$resolved" ] || exit 0' is the real no-match gate. Do NOT change '|| exit 0' to '|| true'.
# CRITICAL (TEST — respawn updates #{pane_current_path} AFTER a sleep): The decisive assertion is
#   post-respawn pane cwd via 'display-message -p "#{pane_current_path}"'. UNLIKE test_z_window.sh
#   (which used the SYNCHRONOUS #{pane_start_path} because current_path "lags" for a NEW window),
#   respawn-pane -c <dir> -k RESTARTS the pane's shell at <dir> and tmux tracks it as current_path —
#   reliably, after a >=0.4s settle sleep (empirically 0.5s). Do NOT use #{pane_start_path} here
#   (respawn does not guarantee updating it). Keep the sleep. (verification_notes §2)
# CRITICAL (TEST — deterministic home via the OPTION, not real $HOME): Set
#   @zoxide-sessions-home-dir to a FIXTURE dir ($FIX/home) and create sessions with -c "$FIX/home".
#   Do NOT use the real $HOME in the test (fragile + would respawn a real session). home-dir IS the
#   configured discriminator (PRD §4), so a fixture dir is the production-faithful equivalent. (§4)
# CRITICAL (shellcheck gate = 'only SC1091', NOT '-x rc 0'): 'shellcheck scripts/z-session.sh | grep
#   -Eo "SC[0-9]+" | sort -u' -> SC1091 (the dynamic $SCRIPT_DIR source shellcheck can't statically
#   follow). This is IDENTICAL to z-window.sh. 'shellcheck -x' does NOT yield rc 0 here (unlike
#   resolve.sh, which has no dynamic source). Gate on 'only SC1091'. (§6)
# GOTCHA: every bare 'tmux' call in z-session.sh (display-message, respawn-pane, rename-window) AND
#   in resolve.sh (get_tmux_option, resolve) is intercepted by the fake 'tmux' wrapper on PATH, which
#   forwards to the isolated socket. So set @zoxide-sessions-backend=zoxide AND
#   @zoxide-sessions-home-dir on the ISOLATED server before invoking $ZSESS. (same idiom as
#   test_z_window.sh / test_run_file.sh)
# GOTCHA: the fake resolved dirs ($FIX/proj, $FIX/twowords, $FIX/home, $FIX/else) MUST be REAL
#   (mkdir -p) — a non-existent -c target makes respawn/new-session fall back to $HOME. (P1.M2.T1.S1 §3)
# GOTCHA: POSIX sh for the SCRIPT and the TEST (#!/bin/sh). shellcheck analyzes z-session.sh as sh;
#   the unquoted '$skip_names' in 'for s in $skip_names' is intentional word-splitting (NOT flagged
#   SC2086). The test uses sh idioms only (no local/[[ ]]/arrays/==).
# GOTCHA: No test framework exists. Do NOT pull in bats/shunit2. The mandated approach is the
#   dependency-free isolated-server + fake-binary mock (item contract #5), extending S1–S4 /
#   test_z_window.sh / test_run_file.sh.
# GOTCHA: spaced-name $1 integrity is PROVEN by the chain (resolve "two words" -> fake zoxide matches
#   -> respawn fires -> cwd == resolved), NOT by a file-mutating echo probe. Do NOT add a probe to the
#   script. (verification_notes §5). The hook-quoting that DELIVERS a spaced $1 is P1.M3.T2.S1.
# FORBIDDEN: Do NOT modify resolve.sh, z-window.sh, tmux-zoxide-sessions.tmux, PRD.md, .gitignore, the
#   S1–S4 tests, test_z_window.sh, or test_run_file.sh.
# FORBIDDEN: Do NOT chmod anything except scripts/z-session.sh. Do NOT add the set-hook / run-file
#   PART 2 block (P1.M3.T2.S1). Do NOT create README.md (P1.M4.T1).
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The handler's I/O contract:
- **Args**: `"$1"` = the session name (a single positional; the hook quotes `"#{session_name}"`,
  P1.M3.T2.S1). The script captures it as `name="$1"` (quoted — no splitting).
- **Side effects**: sources `resolve.sh` (defines `get_tmux_option` + `resolve` in-process); reads 4
  tmux options via `get_tmux_option`; queries the live tmux server (`display-message`) for the
  session's first pane and its cwd; on a positive match, `respawn-pane -c <resolved> -k` (relocates
  the pane) and optionally `rename-window` (if `window-name == session`).
- **Output**: none on stdout. Exit status: **always 0** (the contract).

### Verbatim content for `scripts/z-session.sh`

Write **exactly** this (PRD §5.5 verbatim). It was exercised end-to-end (8/8 guard-chain cases pass)
against the real `resolve.sh` on an isolated tmux server during research.

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

> Implementing agent: this is **PRD §5.5 verbatim**. The PRP adds only:
> 1. **`chmod +x scripts/z-session.sh`** (item contract #3) — the hook's `run-shell` executes it; it
>    needs the x bit (this subtask owns it locally; P1.M4.T2.S1 commits the bit).
> 2. **Stop here** — do **NOT** add the `set-hook`/run-file PART 2 block (P1.M3.T2.S1), an `echo`
>    probe (verification_notes §5), `set -e`, logging, or a version check. The handler is intentionally
>    a pure guard chain that always exits 0.

### Verbatim content for `tests/test_z_session.sh`

Write **exactly** this. It is self-verifying (prints `PASS`/`FAIL`, exits non-zero on any failure)
and was validated during research against the verbatim z-session.sh + real `resolve.sh` + an isolated
tmux server → C1–C8 pass, exit 0. (Run in a `/tmp` staging copy with the real resolve.sh — the repo
was not modified during research.)

```sh
#!/bin/sh
# Integration test for scripts/z-session.sh (P1.M3.T1.S1) — the session-created handler.
#
# Strategy (item contract #5): drive an ISOLATED tmux server (tmux -L zxstest_session) so
# the user's live tmux is untouched; a fake `tmux` wrapper on PATH forwards every bare
# `tmux` call (from z-session.sh AND from resolve.sh's get_tmux_option/resolve) to that
# server; a fake `zoxide` makes resolve() deterministic; @zoxide-sessions-backend=zoxide
# and @zoxide-sessions-home-dir=<fixture> are SET on the isolated server. The REAL
# z-session.sh + REAL resolve.sh run unmodified against this sandbox.
#
# z-session.sh is invoked DIRECTLY as `$ZSESS "<name>"` — exactly what the session-created
# hook's `run-shell -b '<abs>/z-session.sh "#{session_name}"'` dispatch does (P1.M3.T2.S1).
# This subtask owns the handler + its direct-invocation test; it does NOT wire the hook.
#
# Assertion (item contract #5): pane cwd POST-RESPAWN via
# `display-message -p '#{pane_current_path}'`. respawn-pane -c <dir> -k RESTARTS the pane's
# shell at <dir> and tmux tracks it as current_path — reliably, after a >=0.4s settle sleep
# (research/verification_notes.md §2). NOTE: this is the OPPOSITE of test_z_window.sh, which
# used the synchronous #{pane_start_path} for a freshly new-window'd pane (current_path lags
# there). For respawn, current_path is the correct, reliable format.
#
# Cases (PRD §7 TDD scope 1-4,6,7,9): relocate-fires / skip-list / no-match / not-$HOME /
# master-off / window-name / spaced-name. (§7 cases 5 sessionx + 10 resurrect are external-
# plugin coexistence/restore-safety checks — manual-verify in P1.M4.T2.S1, not unit-testable.)

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_session"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZSESS="$REPO_ROOT/scripts/z-session.sh"

# fixture: a REAL home dir (the configured landing dir) + REAL resolved dirs.
FIX="$(mktemp -d)"
mkdir -p "$FIX/home" "$FIX/else" "$FIX/proj" "$FIX/twowords"
TBIN="$FIX/.tbin"; mkdir -p "$TBIN"

cleanup() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    rm -rf "$FIX"
}
trap cleanup EXIT INT TERM

# fake `tmux` wrapper: forward ALL bare `tmux` calls to the isolated server.
cat > "$TBIN/tmux" <<TMUX
#!/bin/sh
exec "$REAL_TMUX" -L "$SOCK" "\$@"
TMUX
chmod +x "$TBIN/tmux"

# fake `zoxide`: known names -> real fixture dirs; anything else -> empty (no match, exit 0).
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift; [ "${1:-}" = "--" ] && shift        # honor the end-of-options guard (NOTE D)
case "$1" in
    proj)        printf '%s\n' "$FIX/proj"; exit 0 ;;     # MATCH (real dir)
    "two words") printf '%s\n' "$FIX/twowords"; exit 0 ;; # MATCH (spaced name; real dir)
    *)           printf ''; exit 0 ;;                     # no-match: empty, exit 0
esac
ZOX
chmod +x "$TBIN/zoxide"

export PATH="$TBIN:$PATH"
export FIX

# boot a fresh isolated server + set the options the handler reads.
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    # seed then clear so option defaults are clean per-case
    "$REAL_TMUX" -L "$SOCK" new-session -d -s _seed -c "$FIX" 2>/dev/null || true
    sleep 0.1
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-home-dir' "$FIX/home" 2>/dev/null
    # reset the toggleable options each boot (prior cases may have set them)
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' on 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" set -gu '@zoxide-sessions-window-name' 2>/dev/null
    "$REAL_TMUX" -L "$SOCK" kill-session -t _seed 2>/dev/null || true
}

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}

# pane cwd (#{pane_current_path}) and window name of a session's first pane.
cwd_of()    { "$REAL_TMUX" -L "$SOCK" display-message -t "$1" -p '#{pane_current_path}'; }
winname_of() { "$REAL_TMUX" -L "$SOCK" display-message -t "$1" -p '#{window_name}'; }

echo "=== CASE 1: resolvable name landed at home -> relocate fires (§7 test 1) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/home"; sleep 0.3
check "C1a pre-relocate cwd = home"   "$FIX/home" "$(cwd_of proj)"
"$ZSESS" proj; sleep 0.5                                   # let respawn settle (§2)
check "C1b post-respawn cwd = resolved" "$FIX/proj" "$(cwd_of proj)"

echo "=== CASE 2: skip-list name (main) -> NO relocate (§7 test 2) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s main -c "$FIX/home"; sleep 0.3
"$ZSESS" main; sleep 0.3
check "C2 skip-list stays at home" "$FIX/home" "$(cwd_of main)"

echo "=== CASE 3: no-match name (zzznope) -> NO relocate (§7 test 3) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s zzznope -c "$FIX/home"; sleep 0.3
"$ZSESS" zzznope; sleep 0.3
check "C3 no-match stays at home" "$FIX/home" "$(cwd_of zzznope)"

echo "=== CASE 4: start dir != home -> NO relocate (§7 test 4) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/else"; sleep 0.3
"$ZSESS" proj; sleep 0.3
check "C4 not-home stays put" "$FIX/else" "$(cwd_of proj)"

echo "=== CASE 6: @zoxide-sessions-auto-session off -> NO relocate (§7 test 6) ==="
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-auto-session' off 2>/dev/null
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/home"; sleep 0.3
"$ZSESS" proj; sleep 0.3
check "C6 master-off stays at home" "$FIX/home" "$(cwd_of proj)"

echo "=== CASE 7: window-name=session -> first window renamed to name (§7 test 7) ==="
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-window-name' session 2>/dev/null
"$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$FIX/home"; sleep 0.3
"$ZSESS" proj; sleep 0.5
check "C7a post-respawn cwd = resolved" "$FIX/proj" "$(cwd_of proj)"
check "C7b first window renamed to name" "proj"        "$(winname_of proj)"

echo "=== CASE 9: spaced name \"two words\" resolvable -> relocates; \$1 intact (§7 test 9) ==="
boot
"$REAL_TMUX" -L "$SOCK" new-session -d -s "two words" -c "$FIX/home"; sleep 0.3
"$ZSESS" "two words"; sleep 0.5
# If $1 had been split, resolve would get "two" (no match -> empty) and the pane would NOT
# relocate. A relocated pane PROVES name="$1" preserved "two words" through resolve->respawn.
check "C9 spaced-name relocates to resolved" "$FIX/twowords" "$(cwd_of "two words")"

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

> The test is **self-contained** (no live user tmux). Each case boots a fresh isolated server, sets
> the options the handler reads (backend=zoxide, home-dir=$FIX/home, and the per-case toggle), creates
> the session at the chosen start dir, invokes `$ZSESS "<name>"` (the hook's dispatch), sleeps to let
> respawn settle, and asserts `#{pane_current_path}`. C9 proves spaced-`$1` integrity through the
> resolve→respawn chain (no file-mutating probe). Total 8 asserts. The socket `zxstest_session` is
> distinct from `zxstest_window`/`zxstest_run` so parallel runs don't collide.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE scripts/z-session.sh (PRD §5.5 verbatim) + chmod +x
  - FILE: scripts/z-session.sh  (NEW — under scripts/, the session analogue of z-window.sh)
  - CONTENT: the verbatim PRD §5.5 block above (shebang #!/bin/sh, full header comment, SCRIPT_DIR,
             . resolve.sh, the 10-step guard chain: master-toggle off->exit; name=$1 empty->exit;
             for-s-in-$skip_names skip-list (default 'home main'); pane via display-message -t name
             -p '#{pane_id}'; path via display-message -t pane -p '#{pane_current_path}'; home_dir
             option (default $HOME); _norm() readlink -f + trailing-slash collapse -> compare !=->exit;
             resolved=$(resolve name) empty->exit; respawn-pane -t pane -c resolved -k; case
             window-name==session -> rename-window. EVERY tmux call '2>/dev/null || exit 0'; final
             'exit 0').
  - EXEC BIT: chmod +x scripts/z-session.sh   (the hook's run-shell EXECUTES it; this subtask owns the
              local bit. P1.M4.T2.S1 commits it via git update-index --chmod=+x.)
  - VERBATIM: copy PRD §5.5 byte-for-byte. Do NOT add set -e / logging / a probe / hook-wiring /
              version check / set -u. Do NOT 'harden' the guards. Keep '|| exit 0' (not '|| true').
  - DEPENDENCY: sources $SCRIPT_DIR/lib/resolve.sh (exists, COMPLETE from S1-S4; NOT modified here).

Task 2: CREATE tests/test_z_session.sh
  - FILE: tests/test_z_session.sh  (NEW — dev integration test; additive, like test_z_window.sh)
  - CONTENT: the verbatim block above (isolated tmux server -L zxstest_session; fake tmux wrapper ->
             that server; fake zoxide -> real $FIX/proj|$FIX/twowords on match else empty; PATH set
             BEFORE boot; @zoxide-sessions-backend=zoxide + @zoxide-sessions-home-dir=$FIX/home on
             the server; C1 relocate / C2 skip-list / C3 no-match / C4 not-home / C6 master-off /
             C7 window-name / C9 spaced-name = 8 asserts; post-respawn cwd via #{pane_current_path}
             after a 0.5s sleep).
  - NAMING: test_z_session.sh (the session analogue of test_z_window.sh).
  - PLACEMENT: tests/ at repo root (dev-only; not in PRD §5.1 ship tree — additive, consistent with prior).
  - COVERAGE: PRD §7 cases 1,2,3,4,6,7,9 (the item-contract TDD scope). Cases 5 (sessionx) + 10
              (resurrect) are external-plugin coexistence/restore-safety -> manual-verify P1.M4.T2.S1.
  - CRITICAL: assert post-respawn cwd via #{pane_current_path} (NOT pane_start_path) WITH a >=0.4s
              sleep (verification_notes §2). Use a fixture home-dir (NOT real $HOME) (§4). Do NOT add a
              probe (§5). New socket zxstest_session (no collision with window/run tests).
  - SELF-VERIFY: prints PASS/FAIL per assertion; exits non-zero on any failure; kills the isolated
                 server + removes the fixture via trap. Copy verbatim.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: test -x scripts/z-session.sh && echo "executable OK"          # expect: executable OK
  - RUN: shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | sort -u   # expect: SC1091 (only)
  - RUN: shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | grep -v '^SC1091$' | sort -u; echo "rc=$?"
                                                                       # expect: rc=1 (no non-SC1091 findings)
  - RUN: diff <(sed -n '/^### 5.5/,/^### 5.6/p' PRD.md | sed -n '/^```sh$/,/^```$/p' | sed '1d;$d') scripts/z-session.sh
                                                                       # expect: empty (byte-identical to PRD §5.5)
  - RUN: shellcheck tests/test_z_session.sh                            # expect: exit 0, no output
  - RUN: sh tests/test_z_session.sh                                    # expect: "RESULTS: pass=8 fail=0", exit 0
  - RUN: sh tests/test_z_window.sh                                     # P1.M2.T1.S1 still passes (no regression)
  - RUN: sh tests/test_run_file.sh                                     # P1.M2.T2.S1 still passes (no regression)
  - RUN: sh tests/test_resolve_dispatcher.sh / test_resolve_z.sh / test_resolve_zoxide.sh / test_resolve_get_tmux_option.sh
                                                                       # S4/S3/S2/S1 pass
  - RUN: git status --short   # only scripts/z-session.sh (new, +x) + tests/test_z_session.sh (new);
                               # PRD.md/.gitignore/resolve.sh/z-window.sh/run file untouched
```

### Implementation Patterns & Key Details

```sh
# The guard chain is ONE pattern: a ladder of early-exits, each '... || exit 0', so a missing
# pane/option/match NEVER propagates an error and the script ALWAYS exits 0 (item contract #4).
#
#   name="$1"                                   # quoted -> preserves spaces (case 9)
#   pane=$(tmux display-message -t "$name" -p '#{pane_id}' 2>/dev/null) || exit 0
#   path=$(tmux display-message -t "$pane"  -p '#{pane_current_path}' 2>/dev/null) || exit 0
#   [ "$(_norm "$path")" = "$(_norm "$home_dir")" ] || exit 0      # the discriminator (PRD §1)
#   resolved=$(resolve "$name") || exit 0; [ -n "$resolved" ] || exit 0
#   tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
#
# Why 'name="$1"' (quoted): the hook passes "#{session_name}" as ONE positional (P1.M3.T2.S1). A
#   spaced session name ("two words") arrives intact; quoting $1 preserves it. resolve "two words"
#   is then called with the full string. (findings ✅6; verification_notes §5.)
#
# Why the path==home discriminator (PRD §1, §3.2 step 7): restored (resurrect/continuum) and
#   tool-placed (sessionx/sesh) sessions are created with an explicit '-c <dir>', so they NEVER
#   land in home_dir -> the guard skips them. Only bare/unresolved creations land at home_dir.
#   No startup-grace/timing logic is required. (external_deps.md §3/§4; findings ✅1,✅4.)
#
# Why _norm (readlink -f + trailing-slash collapse): canonicalizes symlinked $HOME (e.g. /home/me
#   vs /users/me) and tolerates a trailing slash, so '.../home' == '.../home/'. Fallback
#   '|| printf "%s" "$1"' keeps trailing-slash normalization working on non-GNU readlink (PRD §8).
#
# Why respawn-pane -c <resolved> -k (not new-window/new-session): the session+window+pane ALREADY
#   exist (the hook fires after creation, findings ✅1). respawn-pane -c sets the pane's cwd to
#   <resolved>, -k kills the just-started $HOME shell first, and PRESERVES the window name +
#   geometry (so an external rename-window hook is unaffected). The flicker is the unavoidable
#   restart (PRD §8; findings ✅3). After respawn, #{pane_current_path} == <resolved> (verification_notes §2).
#
# Why resolve() 'always exits 0' matters here: 'resolved=$(resolve "$name") || exit 0' would exit
#   on a non-zero status. S4 (CORRECTION B) ends resolve() with 'return 0', so the '|| exit 0'
#   never trips on status — the '[ -n "$resolved" ] || exit 0' is the real no-match gate (resolve
#   returns empty+exit0 on no match, findings ✅5). Defense in depth; do not change either.
#
# Why the window-name branch is AFTER respawn (and guarded): it only runs if respawn ran (i.e. a
#   real relocate). It reads #{window_id} from the pane and rename-window -t <win> <name>. Both
#   tmux calls are '2>/dev/null' so a missing window is silent. The branch is a case on the option
#   value ('session' -> rename; anything else -> skip).
```

### Integration Points

```yaml
FILESYSTEM:
  - create: "scripts/z-session.sh   (PRD §5.5 verbatim; chmod +x; the session handler)"
  - create: "tests/test_z_session.sh   (dev integration test; +x harmless but not required)"

DEPENDENCY (already satisfied — do NOT modify):
  - scripts/lib/resolve.sh: COMPLETE (S1-S4). z-session.sh sources it and calls get_tmux_option 4x
    + resolve 1x. get_tmux_option returns the default for an unset @-option; resolve returns empty
    + always exits 0 on no match.

DEPENDENCY (in flight / complete — treat as CONTRACT, do NOT modify):
  - scripts/z-window.sh: P1.M2.T1.S1, COMPLETE. The window sibling (PRD §5.4). Not touched here.
  - tmux-zoxide-sessions.tmux: P1.M2.T2.S1, COMPLETE (PRD §5.2 PART 1). NOT touched here. The
    session-hook block (PART 2) is APPENDED by P1.M3.T2.S1.

DOWNSTREAM CONSUMER (next subtask):
  - P1.M3.T2.S1 (session hook): APPENDS the '# --- 2. Session auto-relocate hook' block to the run
    file: `auto_session=$(get_tmux_option "@zoxide-sessions-auto-session" "on"); if [ "$auto_session"
    != "off" ]; then tmux set-hook -g session-created "run-shell -b
    '${SESSION_SCRIPT} \"#{session_name}\"'"; fi`. It invokes THIS script. It is reload-safe
    (set-hook -g overwrites — NOTE C). This subtask must ship z-session.sh before that append runs.
  - P1.M4.T1 (README): documents session auto-relocate + the 4 session options (Mode A) — ensure the
    defaults (auto-session 'on', home-dir '$HOME', skip-names 'home main', window-name 'off') match
    this script's defaults (item contract #6 — they do, verbatim from PRD §4/§5.5).
  - P1.M4.T2.S1: commits the executable bit (git update-index --chmod=+x) and runs the §7 matrix + §9.

NO DATABASE / BUILD / CONFIG CHANGES:
  - This subtask adds one executable script + one test. It reads 4 tmux options (the handler's
    defaults). .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only). resolve.sh /
    z-window.sh / run file: UNCHANGED.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — z-session.sh is POSIX sh. The dynamic '$SCRIPT_DIR/lib/resolve.sh' source cannot be
# statically followed, so SC1091 (info) is inherent and EXPECTED — identical to the shipped z-window.sh.
# The clean gate is "only SC1091", NOT "shellcheck -x rc 0" (which does NOT hold for dynamic-source
# scripts; resolve.sh is the only one that is genuinely -x-clean, having no dynamic source).
shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | sort -u
# Expected: a single line: SC1091

# Confirm NO non-SC1091 findings (the real "clean" check):
shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | grep -v '^SC1091$' | sort -u; echo "rc=$?"
# Expected: rc=1 (grep found nothing -> no non-SC1091 findings -> clean).

# Confirm the script is executable (this subtask's chmod).
test -x scripts/z-session.sh && echo "executable OK"
# Expected: executable OK

# Confirm byte-identity to PRD §5.5 (the handler is verbatim):
diff <(sed -n '/^### 5.5/,/^### 5.6/p' PRD.md | sed -n '/^```sh$/,/^```$/p' | sed '1d;$d') scripts/z-session.sh
# Expected: empty diff. (Extracts the §5.5 code fence from PRD.md and compares to the file.)

# No anti-patterns (no set -e / eval / probe / hook code / logging):
grep -nE '\bset -e\b|\beval\b|set-hook|bind-key|run-shell' scripts/z-session.sh
# Expected: nothing prints. (z-session.sh contains NONE of these — the hook is P1.M3.T2.S1.)

shellcheck tests/test_z_session.sh
# Expected: exit 0, no output. (Verified during research: clean POSIX sh.)
```

### Level 2: Integration Test (Component Validation — the authoritative gate)

```bash
# The isolated-server integration test (item contract #5). Does NOT touch the user's live tmux.
sh tests/test_z_session.sh
# Expected output ends with:  RESULTS: pass=8 fail=0   and exit code 0.
# (C1a pre-cwd=home, C1b post-cwd=resolved; C2 skip-list; C3 no-match; C4 not-home; C6 master-off;
#  C7a post-cwd=resolved, C7b window renamed; C9 spaced-name relocates.)
# If a post-respawn cwd read returns the OLD dir: bump the post-$ZSESS sleep to 0.6-0.8s (respawn is
#   near-instant but shell-start + tmux-cwd-update is not zero-latency; 0.5s is the validated floor).
#   Do NOT swap the assertion to #{pane_start_path} (respawn doesn't guarantee updating it).
# If C4 (not-home) relocates: your session was created at home, not $FIX/else — check the -c arg.

# Regression guards: prior tests must still pass (this subtask only ADDS files; nothing it depends on
# changed).
sh tests/test_z_window.sh                  # P1.M2.T1.S1: expect RESULTS: pass=11 fail=0, exit 0
sh tests/test_run_file.sh                  # P1.M2.T2.S1: expect RESULTS: pass=9 fail=0, exit 0
sh tests/test_resolve_dispatcher.sh        # S4: expect RESULTS: pass=14 fail=0, exit 0
sh tests/test_resolve_z.sh                 # S3: pass=5 fail=0
sh tests/test_resolve_zoxide.sh            # S2: pass=3 fail=0
sh tests/test_resolve_get_tmux_option.sh   # S1: pass=6 fail=0
```

### Level 3: Manual Smoke & Boundary (System Validation)

```bash
# 3a. The script's shebang + x bit make it directly runnable (the hook's run-shell executes it).
head -1 scripts/z-session.sh               # Expected: #!/bin/sh
ls -l scripts/z-session.sh                 # Expected: -rwxr-xr-x ... (the x bit is set)

# 3b. Smoke on an ISOLATED server (mirrors the test, ad hoc — NOT a gate). Confirms respawn relocates.
REAL_TMUX=/usr/bin/tmux; SOCK=zxssmoke_sess
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
B=$(mktemp -d); mkdir -p "$B/home" "$B/proj"
printf '#!/bin/sh\n[ "$1" = query ] || exit 0; shift; shift; [ "$1" = proj ] && printf "%%s\\n" "%s/proj"\n' "$B" > "$B/zoxide"; chmod +x "$B/zoxide"
printf '#!/bin/sh\nexec "%s" -L %s "$@"\n' "$REAL_TMUX" "$SOCK" > "$B/tmux"; chmod +x "$B/tmux"
PATH="$B:$PATH" "$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$B/home"; sleep 0.2
PATH="$B:$PATH" "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide
PATH="$B:$PATH" "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-home-dir' "$B/home"
PATH="$B:$PATH" "$REAL_TMUX" -L "$SOCK" new-session -d -s proj -c "$B/home"; sleep 0.3
PATH="$B:$PATH" "$PWD/scripts/z-session.sh" proj; sleep 0.5
"$REAL_TMUX" -L "$SOCK" display-message -t proj -p '#{pane_current_path}'   # Expected: <B>/proj
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; rm -rf "$B"

# 3c. Boundary: the script is the pure handler — grep confirms NO hook wiring leaked into it.
grep -nE 'set-hook|bind-key|run-shell|#{session_name}' scripts/z-session.sh
# Expected: nothing prints (the hook that reads #{session_name} is P1.M3.T2.S1, appended to the RUN FILE).

# 3d. The test never touches the user's LIVE tmux socket. Every call uses -L zxstest_session
#     (the fake wrapper hard-codes it). (No command — a guarantee by construction.)
```

### Level 4: N/A

No performance, security-scanning, or API-doc validation applies to a ~35-line guard-chain script
that relocates a pane. The feature (relocate ONLY home-landed, resolvable, non-whitelisted sessions
under the master toggle; always exit 0; optional window rename) is fully covered by Level 1's static
gates + Level 2's 8 assertions + the Level 3b smoke. Skipped intentionally. (The relocate flicker is
an inherent, documented limitation — PRD §8; not a defect to gate on.)

## Final Validation Checklist

### Technical Validation

- [ ] `test -x scripts/z-session.sh` → executable (the x bit is set; this subtask's chmod).
- [ ] `shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | sort -u` → only `SC1091`.
- [ ] `shellcheck scripts/z-session.sh 2>&1 | grep -Eo 'SC[0-9]+' | grep -v '^SC1091$'` → empty (rc 1).
- [ ] `diff <(sed -n '/^### 5.5/,/^### 5.6/p' PRD.md | sed -n '/^```sh$/,/^```$/p' | sed '1d;$d') scripts/z-session.sh` → empty (byte-identical to PRD §5.5).
- [ ] `grep -nE '\bset -e\b|\beval\b|set-hook|bind-key|run-shell' scripts/z-session.sh` → nothing (no anti-patterns, no hook code).
- [ ] `shellcheck tests/test_z_session.sh` → exit 0, no output.
- [ ] `sh tests/test_z_session.sh` → `RESULTS: pass=8 fail=0`, exit 0.
- [ ] `sh tests/test_z_window.sh` (P1.M2.T1.S1) still passes — no regression.
- [ ] `sh tests/test_run_file.sh` (P1.M2.T2.S1) still passes — no regression.
- [ ] `sh tests/test_resolve_*.sh` (S1–S4) still pass — no regression.
- [ ] The isolated test server (`-L zxstest_session`) leaves the user's live tmux untouched.

### Feature Validation

- [ ] All success criteria from "What" met.
- [ ] Resolvable name at home → pane relocates to resolved dir; window renamed iff `window-name==session` (CASE 1, 7).
- [ ] Skip-list name (`main`) → no relocate (CASE 2; PRD §7 test 2).
- [ ] No-match name (`zzznope`) → no relocate (CASE 3; PRD §7 test 3).
- [ ] Start dir != home → no relocate (CASE 4; PRD §7 test 4).
- [ ] `auto-session=off` → no relocate (CASE 6; PRD §7 test 6).
- [ ] Spaced name (`two words`) → relocates; `$1` intact through the chain (CASE 9; PRD §7 test 9).
- [ ] The script always exits 0; every `tmux` call is `2>/dev/null || exit 0`.

### Code Quality Validation

- [ ] Follows PRD §5.5 verbatim (the handler body) — no "improvements."
- [ ] POSIX-`sh` script is shellcheck-clean (only SC1091); the POSIX-`sh` test is shellcheck-clean.
- [ ] File placement matches the desired tree (`scripts/z-session.sh` new + executable; `tests/test_z_session.sh` new).
- [ ] Executable bit set on `scripts/z-session.sh` ONLY (resolve.sh stays non-executable — sourced; z-window.sh/run file untouched; tests not chmod'd).
- [ ] The test asserts post-respawn cwd via `#{pane_current_path}` (with a settle sleep), on an isolated `tmux -L zxstest_session` server.
- [ ] The test uses a fixture `@zoxide-sessions-home-dir` (never the real `$HOME`).

### Documentation & Deployment

- [ ] Inline header comment documents the handler's purpose + the §3.2 rationale (PRD §5.5 verbatim).
- [ ] No README/doc changes in this subtask (Mode A — README authored wholesale in P1.M4.T1; item contract #6). The 4 session-option defaults (`auto-session` `on`, `home-dir` `$HOME`, `skip-names` `home main`, `window-name` `off`) match this script's defaults.
- [ ] No new hooks (the `set-hook` is P1.M3.T2.S1) or environment variables introduced.

---

## Anti-Patterns to Avoid

- ❌ Don't deviate from PRD §5.5 — copy it **byte-for-byte**. The `_norm` function, the `for s in $skip_names` word-splitting, the `case … session)` branch, the `2>/dev/null || exit 0` guards, and the final `exit 0` are all exactly as specified. "Improving" any of them breaks the validated test or the always-exit-0 contract.
- ❌ Don't change `|| exit 0` to `|| true` or drop it — the contract (item contract #4) is **always exits 0**, and each guard must short-circuit on a missing pane/option/match, not continue.
- ❌ Don't assert post-respawn cwd via `#{pane_start_path}` — `respawn-pane -c <dir> -k` does **not** guarantee updating `pane_start_path`, and the item contract (#5) explicitly specifies `#{pane_current_path}`. Use `current_path` **with a ≥0.4 s settle sleep** (respawn restarts the shell at `-c` and tmux tracks it — verified reliable, verification_notes §2). This is the **opposite** of `test_z_window.sh`'s finding that `current_path` lags for a fresh `new-window`; don't copy that test's `pane_start_path` assertion.
- ❌ Don't use the real `$HOME` in the test — set `@zoxide-sessions-home-dir` to a **fixture dir** and create sessions with `-c "$FIX/home"`. The real `$HOME` is fragile (user-state-dependent) and would respawn a real session. `home-dir` IS the configured discriminator (PRD §4); a fixture dir is the production-faithful equivalent (verification_notes §4).
- ❌ Don't gate shellcheck on `shellcheck -x … rc 0` — for a dynamic-source script (`$SCRIPT_DIR/lib/resolve.sh`), `-x` still emits SC1091 (rc 1). The correct gate is **"only SC1091"** (`grep -Eo 'SC[0-9]+' | sort -u` == `SC1091`), matching the shipped `z-window.sh`. (verification_notes §6.)
- ❌ Don't add an `echo "name=[$1]" >> /tmp/zxs.log` probe to the script — the PRD §7 note suggests it for **manual** $1-integrity verification, but the automated test proves `$1` integrity **through the chain** (resolve `"two words"` → fake-zoxide match → respawn fires). A file-mutating probe is fragile and leaves the script dirty if a test aborts. (verification_notes §5.)
- ❌ Don't add the `set-hook` / run-file PART 2 block — that is **P1.M3.T2.S1** and is **APPENDED** to the run file, not this script. z-session.sh is the pure handler; the test invokes it directly (`$ZSESS "$name"`), exactly as the hook's `run-shell` will.
- ❌ Don't run the test against the user's **live** tmux — always drive an isolated server (`tmux -L zxstest_session`) via a fake `tmux` wrapper on PATH (item contract #5). Use a socket distinct from `zxstest_window`/`zxstest_run` so parallel runs don't collide.
- ❌ Don't "harden" the script with `set -e`, `set -u`, logging, a tmux-version check, or retry logic — PRD §5.5 is intentionally a pure guard chain that fails open (no-op, exit 0). A loud failure mode is worse than silent for a backgrounded hook handler.
- ❌ Don't `chmod +x resolve.sh` (sourced, never executed — S1–S4 invariant), `z-window.sh` (P1.M2.T1.S1 owns it), the run file (P1.M2.T2.S1 owns it), or the tests. The **only** chmod this subtask performs is `scripts/z-session.sh`.
- ❌ Don't modify `resolve.sh`, `z-window.sh`, `tmux-zoxide-sessions.tmux`, `PRD.md`, `.gitignore`, the S1–S4 tests, `test_z_window.sh`, or `test_run_file.sh`, or create `README.md`/the PART-2 hook (P1.M3.T2 / P1.M4 own those).
- ❌ Don't pull in bats/shunit2/sharness — dependency-free isolated-server + fake-binary mock is the mandated/established pattern (S1–S4, P1.M2.T1.S1, P1.M2.T2.S1).

---

## Scope Boundaries (explicit)

| Item | This subtask (S1 of M3.T1) | Other subtasks |
| --- | --- | --- |
| `scripts/z-session.sh` | ✅ CREATE (PRD §5.5 verbatim) + `chmod +x` | P1.M3.T2.S1 wires the hook that INVOKES it |
| `scripts/lib/resolve.sh` | ❌ DO NOT (CONSUME get_tmux_option + resolve) | S1–S4 own it (COMPLETE) |
| `scripts/z-window.sh` | ❌ DO NOT (the window sibling; consume pattern only) | P1.M2.T1.S1 owns it (COMPLETE) |
| `tmux-zoxide-sessions.tmux` | ❌ DO NOT (PART 1; the hook is APPENDED by P1.M3.T2.S1) | P1.M2.T2.S1 (PART 1) + P1.M3.T2.S1 (PART 2) |
| `tests/test_z_session.sh` | ✅ CREATE (additive dev artifact) | extends the test_z_window.sh / test_run_file.sh harness |
| the PART 2 session-hook block (`set-hook`/`run-shell … "#{session_name}"`) | ❌ DO NOT (would collide with P1.M3.T2.S1's append) | P1.M3.T2.S1 |
| `@zoxide-sessions-auto-session` / `-home-dir` / `-skip-names` / `-window-name` docs | (confirm defaults match PRD §4 — they do, verbatim) | README docs them (P1.M4.T1) |
| README.md, committed exec bit | ❌ DO NOT | P1.M4.T1 / P1.M4.T2.S1 |
| `chmod +x` on anything except `scripts/z-session.sh` | ❌ DO NOT | P1.M4.T2.S1 sets remaining ship bits |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

## Confidence Score

**9/10** — one-pass implementation success likelihood. The handler body is **PRD §5.5 verbatim** and
was exercised end-to-end (8/8 guard-chain cases pass) against the real `resolve.sh` on an isolated
tmux server during research. The single non-obvious risk (the post-respawn `#{pane_current_path}`
assertion) is resolved and empirically confirmed (verification_notes §2), and the shellcheck gate is
stated accurately (only SC1091, matching the shipped sibling). The −1 is the inherent fragility of
any tmux-internals integration test under future tmux/rc changes (mitigated by the configurable
settle sleep). No design decisions remain; the implementer copies two verbatim blocks and runs the
gates.
