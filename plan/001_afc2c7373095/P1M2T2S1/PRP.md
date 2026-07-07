# PRP — P1.M2.T2.S1: `tmux-zoxide-sessions.tmux` run file (PART 1 — window binding)

## Goal

**Feature Goal**: Create `tmux-zoxide-sessions.tmux` at repo root — the TPM **run file** — containing **PRD §5.2 PART 1 only**: the bash preamble, the `. resolve.sh` source, the two option reads (`@zoxide-sessions-key` → `g`, `@zoxide-sessions-prompt` → `z to:`), and the one `tmux bind-key` that wires the window-jump binding to `run-shell '<abs>/scripts/z-window.sh %%'`. Make it `chmod +x` and TPM-loadable. **Do NOT add the session-hook block (PART 2) — that is P1.M3.T2.S1, which APPENDS to this file.**

**Deliverable**: Two artifacts —
1. `tmux-zoxide-sessions.tmux` — **NEW** at repo root, PRD §5.2 **PART 1 verbatim** (shebang `#!/usr/bin/env bash`, the full PRD §5.2 header comment, `CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`, `. "$CURRENT_DIR/scripts/lib/resolve.sh"`, the `# --- 1. Window-jump binding ---` block reading the two options via `get_tmux_option` and issuing the `tmux bind-key "$key" command-prompt -p "$prompt" "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"`). **`chmod +x`** (this subtask owns the executable bit for the run file — TPM *executes* it). The file terminates cleanly after the `bind-key` command so P1.M3.T2.S1 can **append** PART 2 without rewriting.
2. `tests/test_run_file.sh` — a dependency-free POSIX-`sh` **integration** test on an **isolated** tmux server (`tmux -L zxstest_run`), driving the run file as TPM does (direct execution, output suppressed) via a fake `tmux` wrapper. Asserts (CASES 1–2) the binding is registered on the right key with the right prompt + the correct **absolute** path to `scripts/z-window.sh` + `%%`; (CASE 3) triggering the prompt path (`run-shell '<path>/z-window.sh <query>'`, the production dispatch after `%%` substitution) opens exactly one window in the zoxide-resolved dir (PRD §7 test #8).

**Success Definition**:
- `tmux-zoxide-sessions.tmux` exists at repo root, is **PART 1 only** (no `set-hook`/`z-session.sh`/`@zoxide-sessions-auto-session` code), is `chmod +x`, and `shellcheck -x` reports **zero findings** (rc 0).
- `sh tests/test_run_file.sh` prints `RESULTS: pass=9 fail=0` and exits 0 (C0 PART-1-only guard + C1–C5 binding registration + C6–C8 window-open), validated empirically during research — see `research/verification_notes.md`.
- `resolve.sh`, `z-window.sh`, the S1–S4 tests, and `test_z_window.sh` are **unmodified**; `.gitignore`/`PRD.md` untouched; only `tmux-zoxide-sessions.tmux` is chmod'd by this subtask.

## User Persona

**Target User**: The implementing AI agent (subtask executor); TPM's loader (`source_plugins.sh` → `silently_source_all_tmux_files()`), which globs `<plugin>/*.tmux` and **executes** each with output suppressed (`$tmux_file >/dev/null 2>&1`), once per init/reload; ultimately the end user pressing `prefix g` (default) and typing a zoxide query to open a window in the resolved dir.

**Use Case**: The run file is the plugin's single entry point. TPM (or a manual `run-shell` line) executes it; it reads two user-tunable options and registers the `prefix g` → `command-prompt` → `z-window.sh` binding. Without this file, the window-jump feature has no key binding and the plugin is inert.

**Pain Points Addressed**: The user wants `prefix g` to jump to a frecency-resolved dir without typing/copying a path. The run file is the wiring layer between "user option" and "live tmux binding."

## Why

- This subtask is the **second half of milestone P1.M2** (the window-jump feature). P1.M2.T1.S1 ships the handler (`z-window.sh`); this subtask ships the **binding that invokes it**. Together they deliver the first complete user-facing feature. Both are scheduled so that `z-window.sh` exists when this subtask's test runs.
- The run file body is **PRD §5.2 PART 1 verbatim** — no design decisions remain. The only implementation risk is (a) correctly scoping to PART 1 (no PART 2 leak, clean termination for the P1.M3.T2.S1 append) and (b) **testing it deterministically** without touching the user's live tmux and without the tmux-internals traps that bit the first prototype (the `list-keys`/`-1` gotcha and the `run-shell`/server-PATH gotcha). Both are fully solved and empirically validated (research/verification_notes.md §1, §4).
- TPM executes the run file **once per init/reload with output suppressed** (architecture/research_plugin_ecosystem.md §1, external_deps.md §2). So the file must `chmod +x`, have a valid shebang, and do its work via `tmux` commands (not stdout). The `#!/usr/bin/env bash` + `${BASH_SOURCE[0]}` preamble is the TPM convention, confirmed verbatim in TPM's own loader.

## What

User-visible behavior (after this subtask + P1.M2.T1.S1; before P1.M3 adds the session hook):

- TPM (or `run-shell ~/.config/tmux/plugins/tmux-zoxide-sessions/tmux-zoxide-sessions.tmux`) executes the file once at init/reload.
- The file resolves its own absolute dir (`CURRENT_DIR`), sources `scripts/lib/resolve.sh` (defining `get_tmux_option`), reads `@zoxide-sessions-key` (default `g`) and `@zoxide-sessions-prompt` (default `z to:`), and registers `bind-key <key> command-prompt -p "<prompt>" "run-shell '<CURRENT_DIR>/scripts/z-window.sh %%'"` in the **prefix** table.
- `prefix <key>` opens the prompt; the user types a query; `%%` is substituted and `z-window.sh` opens a new window in the zoxide-resolved dir.

### Success Criteria

- [ ] `tmux-zoxide-sessions.tmux` exists at repo root, is executable (`test -x`), and is **PRD §5.2 PART 1 verbatim** (eyeball against PRD §5.2; the `# --- 1.` block; no `# --- 2.` block).
- [ ] It sources `$CURRENT_DIR/scripts/lib/resolve.sh` and reads both options via `get_tmux_option` (the S1 public helper) — it does **not** reimplement option reading.
- [ ] It registers exactly ONE `bind-key` (the window-jump binding); it contains **no** `set-hook`, no `z-session.sh` reference, no `@zoxide-sessions-auto-session` read (PART 2 = P1.M3.T2.S1).
- [ ] It terminates cleanly after the `bind-key` command (trailing newline; ready for P1.M3.T2.S1 append).
- [ ] `shellcheck -x tmux-zoxide-sessions.tmux` → rc 0, no output. (Equivalently: `shellcheck … | grep -Eo 'SC[0-9]+' | sort -u` == `SC1091`.)
- [ ] `sh tests/test_run_file.sh` → `RESULTS: pass=9 fail=0`, exit 0.
- [ ] `resolve.sh`/`z-window.sh` unchanged; S1–S4 + `test_z_window.sh` still pass (no regression).
- [ ] `.gitignore` / `PRD.md` unmodified; only `tmux-zoxide-sessions.tmux` is chmod'd (`+x`).

## All Needed Context

### Context Completeness Check

_If someone knew nothing about this codebase, would they have everything needed to implement this successfully?_ **Yes.** The run-file body is reproduced **verbatim** from PRD §5.2 PART 1 and was `shellcheck -x`-verified clean (rc 0). The 9-case integration test is specified end-to-end (isolated server + fake `tmux` wrapper + fake `zoxide`, PATH set before boot) and its critical assertions were exercised empirically during research: default binding on `g` with prompt `z to:` + abs path + `%%`; custom key `Z` / prompt `jump to`; and `run-shell`-dispatched window-open (name `proj`, start_path `$FIX/proj`, count delta 1). The two non-obvious tmux-internals traps — (1) `list-keys` needs **`-1`** to query a single key (a bare key arg yields `unknown key: g`), and (2) `tmux run-shell` spawns with the **server's** PATH so the fake wrapper/zoxide must be on PATH **before** the server boots — are surfaced, justified, and fixed in `research/verification_notes.md` §1 and §4. `shellcheck` + `tmux` are the only required tools (both confirmed installed). No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Authoritative source — the run file body is copied VERBATIM (PART 1) from here.
  section: "§5.2 tmux-zoxide-sessions.tmux (PART 1 ONLY: shebang + header comment + CURRENT_DIR + . resolve.sh + the '# --- 1. Window-jump binding' block through the bind-key line). §4 Options (@zoxide-sessions-key default 'g', @zoxide-sessions-prompt default 'z to:' — the two this file reads). §7 test #8 (prefix g -> window opens — automated in CASE 3). §5.1 file tree (run file sits at repo ROOT, not under scripts/)."
  critical: "PART 1 ONLY. Do NOT copy the '# --- 2. Session auto-relocate hook' block — it is P1.M3.T2.S1 and is APPENDED later (item contract #4). Keep the header comment verbatim (it describes the FINAL file; only PART 1's CODE ships now). The run file is executed, not sourced -> needs #!/usr/bin/env bash AND chmod +x."

- file: plan/001_afc2c7373095/P1M2T2S1/research/verification_notes.md
  why: Empirical proof grounding every gate — the list-keys/-1 gotcha, the shellcheck -x gate (and why grep -v SC1091 is the WRONG gate), the run-shell/server-PATH gotcha, custom-option override, PART-1-only regression guard.
  section: "§1 list-keys needs -1; §3 shellcheck -x is clean (grep -v SC1091 is NOT empty); §4 run-shell inherits SERVER PATH -> set fakes BEFORE boot; §5 custom options; §6 PART-1-only grep guard; §7 mocking harness; §8 z-window.sh dependency"
  critical: "§1: assert via `tmux list-keys -1 -T prefix <key>` (NOT `list-keys -T prefix <key>` -> 'unknown key'). §4: prepend fake-tmux wrapper + fake zoxide to PATH BEFORE `tmux -L <sock> new-session` boots the server, or run-shell'd z-window.sh escapes isolation and hits the LIVE tmux. §3: use `shellcheck -x` (rc 0) as the gate, NOT `grep -v SC1091`."

- file: plan/001_afc2c7373095/architecture/research_plugin_ecosystem.md
  why: TPM loading contract — HOW the run file is discovered and executed.
  section: "§1 TPM Loading & the Run-File Pattern (silently_source_all_tmux_files: glob $plugin_path*.tmux, execute each as $tmux_file >/dev/null 2>&1, once per init/reload); the CURRENT_DIR idiom (bash: ${BASH_SOURCE[0]}); §6 conventional repo layout (run file at ROOT, chmod +x, commit the bit)"
  critical: "TPM EXECUTES the .tmux file (not source), output suppressed, once per init/reload. So: valid shebang + chmod +x + do work via tmux commands (no stdout reliance). The run file MUST sit at repo root (the glob is rooted at the plugin dir). The executable bit must be COMMITTED (git update-index --chmod=+x) — P1.M4.T2.S1 owns the committed bit; this subtask does local chmod +x."

- file: plan/001_afc2c7373095/architecture/external_deps.md
  why: The TPM contract restated + the testing-strategy guidance (isolated server).
  section: "§2 TPM loading contract (must be chmod +x, committed; runs once; reload re-runs -> why later hooks use set-hook -g idempotent overwrite, NOT -ag); §6 testing strategy (isolated tmux -L server, fake tmux/zoxide, assert via display-message)"
  critical: "Reload re-runs the run file -> the binding's bind-key is naturally idempotent (re-binding the same key overwrites). PART 2's hook (P1.M3.T2.S1) uses set-hook -g (overwrite) precisely for this reload-safety (NOTE C). This subtask's bind-key is reload-safe by construction."

- file: scripts/lib/resolve.sh
  why: The DEPENDENCY the run file sources — its get_tmux_option() contract (reads tmux show-option -gqv <name>, returns default if unset/empty). NOT modified by this subtask.
  section: "get_tmux_option() (the first function; S1) — the public option reader the run file calls twice. resolve()/_resolve_* are used only by z-window.sh at dispatch time, NOT by the run file."
  critical: "The run file calls get_tmux_option '@zoxide-sessions-key' 'g' and get_tmux_option '@zoxide-sessions-prompt' 'z to:'. For an unset @-option, show-option -gqv prints nothing + exit 0, so get_tmux_option returns the default. Do NOT modify resolve.sh; do NOT reimplement option reading in the run file."

- file: plan/001_afc2c7373095/P1M2T1S1/PRP.md
  why: The PRP for z-window.sh — the script this binding invokes. Treat as a CONTRACT: z-window.sh WILL exist at scripts/z-window.sh (PRD §5.4 verbatim), chmod +x, accepting [query ...], opening one window in the resolved dir (or cur on empty/no-match).
  section: "Verbatim z-window.sh body; the isolated-server + fake-tmux-wrapper + fake-zoxide test idiom this test REUSES (same harness, set @zoxide-sessions-backend=zoxide on the isolated server); the query=\"$*\" recombination finding (findings §6)"
  critical: "z-window.sh is the binding's TARGET. The binding stores run-shell '<abs>/scripts/z-window.sh %%'. This subtask's CASE 3 dispatches run-shell '<abs>/scripts/z-window.sh proj' (the exact post-%%-substitution command). z-window.sh reads NEITHER @zoxide-sessions-key NOR @zoxide-sessions-prompt (those are the binding's defaults, owned here) — item contract #6. README docs them in P1.M4.T1 (Mode A) — no doc work here."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: The validated findings that bear on the run file (reload idempotency, the %% textual substitution, the resolve-always-exits-0 contract the binding relies on).
  section: "✅6 (%% substitution is textual, splits on spaces; z-window.sh recombines via query=\"$*\"); ✅8 (get_tmux_option + TPM run-file/executable-bit conventions confirmed); NOTE C (set-hook -g overwrites — for context on why PART 2 is separate, not this subtask's concern)"
  critical: "The binding's run-shell '... %%' makes tmux substitute the typed text TEXTUALLY and word-split it; z-window.sh recombines with query=\"$*\". This is CORRECT and already validated by P1.M2.T1.S1's CASE 4 — do not change the binding's quoting (single quotes around the path so $CURRENT_DIR expands at bind time; %% literal)."
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

# State AFTER P1.M1 (foundation complete) + P1.M2.T1.S1 (z-window.sh, in flight).
# The run file does NOT yet exist at repo root.
$ ls -la
LICENSE  PRD.md  .gitignore  scripts/  tests/  plan/   # NO tmux-zoxide-sessions.tmux yet
$ ls scripts scripts/lib
scripts:
lib          z-window.sh     # z-window.sh: P1.M2.T1.S1 deliverable (PRD §5.4 verbatim, chmod +x) — CONTRACT
scripts/lib:
resolve.sh   # COMPLETE: get_tmux_option + _resolve_zoxide + _resolve_z + resolve  (the dep the run file sources)
$ ls tests
test_resolve_get_tmux_option.sh   test_resolve_zoxide.sh   test_resolve_z.sh   test_resolve_dispatcher.sh
test_z_window.sh                  # P1.M2.T1.S1's integration test (pattern this test extends)

# resolve.sh head (the function the run file calls):
$ grep -nE '^get_tmux_option\(\)' scripts/lib/resolve.sh
6:get_tmux_option()    # S1 — the public option reader: tmux show-option -gqv <name> || default

# Tooling on this machine:
$ command -v shellcheck tmux bash && shellcheck --version | head -1 && tmux -V
/usr/bin/shellcheck   # v0.11.0 — `shellcheck -x <file>` is the clean gate (rc 0)
/usr/bin/tmux         # tmux 3.6b — drives the ISOLATED test server (never the live one)
/usr/bin/bash         # the run file's interpreter (#!/usr/bin/env bash)
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  tmux-zoxide-sessions.tmux  # NEW — PRD §5.2 PART 1 verbatim; chmod +x (EXECUTED by TPM, not sourced)
  scripts/
    lib/
      resolve.sh             # (UNCHANGED — COMPLETE; the run file only SOURCES it)
    z-window.sh              # (P1.M2.T1.S1 — present by the time this test runs; CONTRACT)
  tests/
    test_resolve_get_tmux_option.sh   # (S1, unchanged — re-run for regression)
    test_resolve_zoxide.sh            # (S2, unchanged)
    test_resolve_z.sh                 # (S3, unchanged)
    test_resolve_dispatcher.sh        # (S4, unchanged)
    test_z_window.sh                  # (P1.M2.T1.S1, unchanged — re-run for regression)
    test_run_file.sh                  # NEW — isolated-tmux-server integration test (C0 + C1–C8 = 9 asserts)
```

`tmux-zoxide-sessions.tmux` is the **first and only** file this subtask creates, and the **only** file it chmod's (`+x`). It sits at repo **root** (per TPM's `<plugin>/*.tmux` glob — NOT under `scripts/`).

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (VERBATIM): Copy PRD §5.2 PART 1 byte-for-byte. Do NOT 'improve': keep the
#   full header comment verbatim (it describes the FINAL file; P1.M3.T2.S1 appends PART 2),
#   keep CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" (the bash TPM idiom),
#   keep . "$CURRENT_DIR/scripts/lib/resolve.sh", keep the SINGLE bind-key with the exact
#   quoting: "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'" (DOUBLE quotes outside so
#   $CURRENT_DIR EXPANDS at bind time baking the abs path in; SINGLE quotes inside are literal
#   characters tmux stores; %% is literal and substituted by command-prompt at prompt-accept).
# CRITICAL (PART 1 ONLY): Do NOT add the '# --- 2. Session auto-relocate hook' block. No set-hook,
#   no z-session.sh, no @zoxide-sessions-auto-session read. The file ends after the bind-key line
#   (+ trailing newline). P1.M3.T2.S1 APPENDS PART 2 — termination must be clean (no dangling heredoc,
#   no trailing backslash continuing onto nothing).
# CRITICAL (EXECUTED, not sourced): TPM runs the .tmux file as `$tmux_file >/dev/null 2>&1`. It NEEDS
#   #!/usr/bin/env bash AND chmod +x. This subtask OWNS the executable bit for the run file. Do NOT
#   chmod resolve.sh (sourced) or the tests. P1.M4.T2.S1 commits the bit via git update-index --chmod=+x.
# CRITICAL (TEST — list-keys needs -1): `tmux list-keys -T prefix g` -> "unknown key: g" (it does NOT
#   take a key arg). Use `tmux list-keys -1 -T prefix g` to query ONE key (compact single-space form),
#   or `tmux list-keys -T prefix | grep z-window` for the full table. Asserting on the wrong form is the
#   #1 way this test silently fails. (research/verification_notes.md §1)
# CRITICAL (TEST — run-shell inherits the SERVER PATH): CASE 3 dispatches
#   `tmux -L <sock> run-shell "<abs>/z-window.sh proj"`. The spawned process gets the tmux SERVER's
#   environment, which captures PATH at STARTUP. So: prepend the fake-`tmux` wrapper + fake-`zoxide` dir
#   to PATH BEFORE `tmux -L <sock> new-session` boots the server. If you set PATH after boot, the
#   run-shell'd z-window.sh calls bare `tmux` -> the user's LIVE socket (bad) and `resolve`->real/absent
#   zoxide. Set PATH first. (research/verification_notes.md §4)
# CRITICAL (shellcheck gate — use -x): `shellcheck -x tmux-zoxide-sessions.tmux` -> rc 0, no output
#   (-x follows the sourced resolve.sh; SC1091 disappears). WITHOUT -x the only code is SC1091 (info),
#   verifiable via `shellcheck <f> 2>&1 | grep -Eo 'SC[0-9]+' | sort -u` == SC1091. Do NOT use
#   `shellcheck <f> | grep -v SC1091` as the "empty" gate — on this shellcheck build SC1091's message is
#   multi-line and grep -v SC1091 leaves the "In … line N:" / "For more information:" lines (NOT empty).
# GOTCHA: bind-key (no -T, no -n) registers in the PREFIX table -> triggered by `prefix <key>`. Confirmed.
#   No need for -T prefix explicitly (PRD §5.2 omits it; the default table for bind-key is prefix).
# GOTCHA: reload re-runs the run file. bind-key on the same key OVERWRITES (idempotent) — reload-safe by
#   construction. (PART 2's set-hook -g is similarly idempotent — NOTE C — but that's P1.M3.T2.S1.)
# GOTCHA: the binding bakes $CURRENT_DIR (abs path) at bind time. So the registered command shows the
#   repo's absolute scripts/z-window.sh path, e.g. run-shell '/home/.../tmux-zoxide-sessions/scripts/z-window.sh %%'.
#   The test asserts this equals "$REPO_ROOT/scripts/z-window.sh" — compute REPO_ROOT the same way the
#   test does (cd "$(dirname "$0")/.." && pwd) and they'll match.
# GOTCHA: POSIX sh for the TEST (#!/bin/sh). The RUN FILE is bash (#!/usr/bin/env bash) — that's fine,
#   shellcheck analyzes it as bash and ${BASH_SOURCE[0]} / the nested quoting are clean (verified -x rc 0).
#   The test itself uses sh idioms only (no local/[[ ]]/arrays/==); it must run under dash/bash alike.
# GOTCHA: No test framework exists. Do NOT pull in bats/shunit2. The mandated approach is the
#   dependency-free isolated-server + fake-binary mock (item contract #5), extending S1–S4 / P1.M2.T1.S1.
# GOTCHA: the fake resolved dir ($FIX/proj) MUST be REAL (mkdir -p) — a non-existent -c target makes the
#   pane fall back to $HOME (P1.M2.T1.S1 finding §3). CASE 3 mkdirs it.
# FORBIDDEN: Do NOT modify resolve.sh, z-window.sh, PRD.md, .gitignore, the S1–S4 tests, or test_z_window.sh.
# FORBIDDEN: Do NOT chmod anything except tmux-zoxide-sessions.tmux. Do NOT create z-session.sh / README (P1.M3/P1.M4).
# FORBIDDEN: Do NOT add the PART 2 session-hook block (P1.M3.T2.S1 owns it and APPENDS it).
```

## Implementation Blueprint

### Data models and structure

N/A — no data models. The run file's I/O contract:
- **Args**: none (TPM invokes it bare).
- **Side effects**: sources `resolve.sh` (defines `get_tmux_option` in-process); reads 2 tmux options via `get_tmux_option` → `tmux show-option -gqv`; issues exactly ONE `tmux bind-key` (registers the window-jump binding in the prefix table).
- **Output**: none on stdout (TPM suppresses it anyway: `>/dev/null 2>&1`). Exit status: that of the final `bind-key` (not asserted by TPM; a failure is silent).

### Verbatim content for `tmux-zoxide-sessions.tmux`

Write **exactly** this (PRD §5.2 PART 1 verbatim). It was `shellcheck -x`-verified clean (rc 0) and its binding registration + window-open dispatch were exercised end-to-end during research.

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
```

> Implementing agent: this is **PRD §5.2 PART 1 verbatim**. The PRP adds two things the
> prose doesn't:
> 1. **`chmod +x tmux-zoxide-sessions.tmux`** (item contract #3) — TPM *executes* it, so it
>    needs the x bit (this subtask owns it locally; P1.M4.T2.S1 commits the bit).
> 2. **Stop here** — do **NOT** add the `# --- 2. Session auto-relocate hook` block. The
>    header comment is kept verbatim (it documents the *final* file that P1.M3.T2.S1
>    completes by appending PART 2). Terminating cleanly after the `bind-key` line is a hard
>    requirement: P1.M3.T2.S1 APPENDS, it does not rewrite.
> Do **not** add error handling, `set -e`, logging, an extra binding, a version check, or a
> `display-message`. The run file is intentionally minimal — one source, two option reads,
> one bind-key.

### Verbatim content for `tests/test_run_file.sh`

Write **exactly** this. It is self-verifying (prints `PASS`/`FAIL`, exits non-zero on any
failure) and was validated during research against the verbatim PART 1 run file + real
`resolve.sh` + an isolated tmux server → C0–C8 pass, exit 0. (Run in a `/tmp` staging copy
with a stand-in z-window.sh — the repo was not modified during research.)

```sh
#!/bin/sh
# Integration test for tmux-zoxide-sessions.tmux (P1.M2.T2.S1) — PART 1 only.
#
# Strategy (item contract #5): drive an ISOLATED tmux server (tmux -L zxstest_run) so the
# user's live tmux is untouched. A fake `tmux` wrapper on PATH forwards every bare `tmux`
# call (the run file's bind-key, resolve.sh's get_tmux_option, z-window.sh's
# display-message/new-window) to that server. A fake `zoxide` makes resolve() deterministic.
# PATH with fakes is set BEFORE the server boots so `run-shell` (the binding's production
# dispatch path) inherits it (research/verification_notes.md §4).
#
# The run file is EXECUTED directly (`"$RUN"`), exactly as TPM does ($tmux_file >/dev/null 2>&1).
#
# Assertions: C0 PART-1-only (no session-hook code); C1–C3 default binding registered on 'g'
# with prompt 'z to:' + the correct ABSOLUTE path to scripts/z-window.sh + %% (via
# `list-keys -1 -T prefix g` — the -1 is mandatory, §1); C4–C5 custom
# @zoxide-sessions-key/@zoxide-sessions-prompt override; C6–C8 triggering the prompt path
# (run-shell '<path>/z-window.sh proj', the production dispatch after %% substitution) opens
# exactly one window in the zoxide-resolved dir (PRD §7 test #8).

set -u
REAL_TMUX="${REAL_TMUX:-/usr/bin/tmux}"
SOCK="zxstest_run"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUN="$REPO_ROOT/tmux-zoxide-sessions.tmux"
ZWIN="$REPO_ROOT/scripts/z-window.sh"

# fixture: a REAL resolved dir (must exist or the active pane falls back to $HOME —
# P1.M2.T1.S1 finding §3).
FIX="$(mktemp -d)"
mkdir -p "$FIX/proj"                 # fake zoxide resolves `proj` -> here (REAL dir)
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

# fake `zoxide`: `proj` -> the real fixture dir; anything else -> empty (no match).
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift; [ "${1:-}" = "--" ] && shift        # honor the end-of-options guard
case "$1" in
    proj) printf '%s\n' "$FIX/proj"; exit 0 ;;   # MATCH (real dir)
    *)    printf ''; exit 0 ;;                    # no-match: empty, exit 0
esac
ZOX
chmod +x "$TBIN/zoxide"

# CRITICAL: set PATH with fakes BEFORE booting the server, so `run-shell` inherits it.
export PATH="$TBIN:$PATH"
export FIX

# boot a fresh isolated server; set backend=zoxide so resolve() takes the zoxide branch.
boot() {
    "$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null || true
    sleep 0.2
    "$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$FIX" || { echo "FATAL: new-session"; exit 2; }
    sleep 0.2
    "$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-backend' zoxide 2>/dev/null
}

pass=0; fail=0
check() {  # check <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then echo "PASS  $1 (got=[$3])"; pass=$((pass+1));
    else echo "FAIL  $1 (expected=[$2] got=[$3])"; fail=$((fail+1)); fi
}
contains() {  # contains <desc> <haystack> <needle>  (fixed-string substring match)
    if printf '%s' "$2" | grep -Fq -- "$3"; then echo "PASS  $1"; pass=$((pass+1));
    else echo "FAIL  $1 (expected haystack to contain [$3]; got=[$2])"; fail=$((fail+1)); fi
}

echo "=== C0: PART 1 only — no session-hook code (PART 2 = P1.M3.T2.S1) ==="
if grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' "$RUN"; then
    echo "FAIL  C0: run file contains session-hook code (must be PART 1 only)"; fail=$((fail+1))
else
    echo "PASS  C0: no session-hook code (PART 1 only)"; pass=$((pass+1))
fi

echo "=== CASE 1: default options -> binding on 'g', prompt 'z to:', abs path + %% ==="
boot
"$RUN" >/dev/null 2>&1
b=$("$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix g 2>&1)
contains "C1: bind-key on 'g' registered"        "$b" "bind-key -T prefix g"
contains "C2: default prompt 'z to:'"            "$b" 'command-prompt -p "z to:"'
contains "C3: abs path to z-window.sh + %% kept" "$b" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"

echo "=== CASE 2: custom @zoxide-sessions-key / @zoxide-sessions-prompt ==="
boot
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-key' Z
"$REAL_TMUX" -L "$SOCK" set -g '@zoxide-sessions-prompt' "jump to"
"$RUN" >/dev/null 2>&1
bz=$("$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix Z 2>&1)
contains "C4: binding on custom key 'Z'" "$bz" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
contains "C5: custom prompt 'jump to'"   "$bz" 'command-prompt -p "jump to"'

echo "=== CASE 3: trigger the prompt path (run-shell ... z-window.sh <query>) -> window opens ==="
if [ -x "$ZWIN" ]; then
    boot
    before=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    # Simulate: user types `proj` at the prompt -> tmux substitutes %% and runs
    # `run-shell '<abs>/scripts/z-window.sh proj'` (the binding's production dispatch).
    "$REAL_TMUX" -L "$SOCK" run-shell "$REPO_ROOT/scripts/z-window.sh proj"
    sleep 0.4                               # let the new pane's cwd settle
    after=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | wc -l | tr -d ' ')
    idx=$("$REAL_TMUX" -L "$SOCK" list-windows -t zs: -F '#{window_index}' | sort -n | tail -1)
    check "C6: exactly 1 new window"                 "1"         "$((after - before))"
    check "C7: window named basename(resolved)=proj" "proj"      \
        "$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{window_name}')"
    check "C8: window start_path = resolved dir"     "$FIX/proj" \
        "$("$REAL_TMUX" -L "$SOCK" display-message -t "zs:$idx" -p '#{pane_start_path}')"
else
    echo "FAIL  C6/C7/C8: z-window.sh missing ($ZWIN) — run P1.M2.T1.S1 first"; fail=$((fail+3))
fi

echo ""
echo "RESULTS: pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
```

> The test is **self-contained** (no live user tmux). C0 is a static PART-1-only guard. CASES
> 1–2 boot a fresh isolated server, execute the run file (via the fake wrapper so `bind-key` +
> `get_tmux_option` land on the isolated server), and assert via `list-keys -1 -T prefix <key>`
> (the `-1` is mandatory — a bare key arg yields `unknown key`). CASE 3 sets PATH **before**
> boot (so `run-shell` inherits the fake wrapper + fake zoxide), dispatches the exact
> post-`%%`-substitution command, and asserts one window opens named `proj` in `$FIX/proj`.
> CASES 1–2 do NOT need z-window.sh; only CASE 3 does (it requires `-x scripts/z-window.sh`,
> P1.M2.T1.S1's deliverable, and fails clearly with a pointer if absent). Total 9 asserts.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE tmux-zoxide-sessions.tmux  (PRD §5.2 PART 1 verbatim) + chmod +x
  - FILE: tmux-zoxide-sessions.tmux  (NEW — at REPO ROOT, per TPM's <plugin>/*.tmux glob; NOT under scripts/)
  - CONTENT: the verbatim PART 1 block above (shebang #!/usr/bin/env bash, full PRD §5.2 header comment,
             CURRENT_DIR via ${BASH_SOURCE[0]}, . resolve.sh, the '# --- 1. Window-jump binding' block:
             key/prompt via get_tmux_option, ONE tmux bind-key with the exact run-shell '... %%' quoting).
  - EXEC BIT: chmod +x tmux-zoxide-sessions.tmux   (TPM EXECUTES it; this subtask owns the local bit.
              P1.M4.T2.S1 commits it via git update-index --chmod=+x.)
  - VERBATIM / PART 1 ONLY: do NOT add the '# --- 2. Session auto-relocate hook' block (set-hook/z-session.sh/
             auto-session). Do NOT add set -e / error handling / logging / version check / extra bindings.
             Keep the header comment verbatim (documents the final file). Terminate cleanly after bind-key.
  - DEPENDENCY: sources $CURRENT_DIR/scripts/lib/resolve.sh (exists, COMPLETE from S1–S4; NOT modified here).

Task 2: CREATE tests/test_run_file.sh
  - FILE: tests/test_run_file.sh  (NEW — dev integration test; additive, like the S1–S4 / test_z_window tests)
  - CONTENT: the verbatim block above (isolated tmux server -L zxstest_run; fake tmux wrapper -> that server;
             fake zoxide -> real $FIX/proj on match else empty; PATH set BEFORE boot so run-shell inherits it;
             @zoxide-sessions-backend=zoxide set on the server; C0 PART-1-only grep guard; C1–C5 binding
             registration via list-keys -1; C6–C8 run-shell-dispatched window-open).
  - NAMING: test_run_file.sh (extends the test_<unit>.sh pattern; the integration counterpart for the run file).
  - PLACEMENT: tests/ at repo root (dev-only; not in PRD §5.1 ship tree — additive, consistent with prior).
  - COVERAGE: C0 PART-1-only; C1 key=g registered; C2 prompt='z to:'; C3 abs path + %% kept;
              C4 custom key=Z registered; C5 prompt='jump to'; C6 exactly 1 window; C7 name=proj; C8 start_path=$FIX/proj.
  - CRITICAL: assert via `list-keys -1 -T prefix <key>` (the -1 is mandatory). Set PATH with fakes BEFORE
              `tmux -L <sock> new-session` boots the server (run-shell inherits the server PATH). CASE 3 requires
              `test -x scripts/z-window.sh` (P1.M2.T1.S1) and fails clearly otherwise.
  - SELF-VERIFY: prints PASS/FAIL per assertion; exits non-zero on any failure; kills the isolated server +
                 removes the fixture via trap. Copy verbatim.

Task 3: VERIFY (do not modify anything during verification)
  - RUN: test -x tmux-zoxide-sessions.tmux && echo "executable OK"        # expect: executable OK
  - RUN: shellcheck -x tmux-zoxide-sessions.tmux; echo "rc=$?"            # expect: rc=0, no output
  - RUN: shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -Eo 'SC[0-9]+' | sort -u   # expect: SC1091 (only)
  - RUN: grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' tmux-zoxide-sessions.tmux; echo "rc=$?"   # expect: rc=1 (no match = PART 1 only)
  - RUN: shellcheck tests/test_run_file.sh                                # expect: exit 0, no output
  - RUN: sh tests/test_run_file.sh                                        # expect: "RESULTS: pass=9 fail=0", exit 0
  - RUN: sh tests/test_z_window.sh                                        # P1.M2.T1.S1 still passes (no regression)
  - RUN: sh tests/test_resolve_dispatcher.sh                              # S4 still passes
  - RUN: sh tests/test_resolve_z.sh / test_resolve_zoxide.sh / test_resolve_get_tmux_option.sh   # S3/S2/S1 pass
  - RUN: git status --short   # only tmux-zoxide-sessions.tmux (new, +x) + tests/test_run_file.sh (new);
                               # PRD.md/.gitignore/resolve.sh/z-window.sh untouched
```

### Implementation Patterns & Key Details

```bash
# The single pattern this subtask ships — the window-jump binding registration. One source,
# two option reads, one bind-key:
#
#   . "$CURRENT_DIR/scripts/lib/resolve.sh"        # defines get_tmux_option
#   key=$(get_tmux_option "@zoxide-sessions-key" "g")          # default 'g'
#   prompt=$(get_tmux_option "@zoxide-sessions-prompt" "z to:") # default 'z to:'
#   tmux bind-key "$key" command-prompt -p "$prompt" \
#       "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
#
# Why #!/usr/bin/env bash + ${BASH_SOURCE[0]} (not #!/bin/sh + $0):
#   TPM convention (research_plugin_ecosystem.md §1, verbatim in TPM's own loader). The run
#   file is EXECUTED (not sourced), so $0 would also work, but bash + ${BASH_SOURCE[0]} is the
#   safest, most-imitated choice and matches PRD §5.2 verbatim.
#
# Why the nested quoting "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'":
#   OUTER double quotes -> $CURRENT_DIR EXPANDS at bind time, baking the ABSOLUTE path into the
#   stored command (so the binding works regardless of the server's later cwd). INNER single
#   quotes are LITERAL characters tmux stores and passes to /bin/sh -c at dispatch. %% is the
#   command-prompt substitution token: when the user types text and presses Enter, tmux replaces
#   %% with that text (textually, then word-splits — z-window.sh recombines via query="$*",
#   P1.M2.T1.S1 finding §6). Do NOT change this quoting.
#
# Why bind-key with no -T registers in the prefix table:
#   The default table for `bind-key` (no -n, no -T) is the prefix table (verified empirically).
#   So `prefix <key>` triggers it. PRD §5.2 omits -T; keep it verbatim.
#
# Why the run file is reload-safe:
#   TPM re-runs the .tmux file on every init/reload (external_deps.md §2). Re-running `bind-key
#   <same-key>` OVERWRITES the prior binding (idempotent) — no duplicates. (PART 2's set-hook -g
#   is similarly idempotent — NOTE C — but that's P1.M3.T2.S1's concern, not here.)
#
# Why TPM-loadable requires chmod +x AND a valid shebang AND repo-root placement:
#   TPM's silently_source_all_tmux_files() globs $plugin_path*.tmux (REPO ROOT) and runs each as
#   `$tmux_file >/dev/null 2>&1` (EXECUTED, output suppressed). A non-executable file or one
#   without a shebang is silently no-op'd. The committed bit must be set (git update-index
#   --chmod=+x) or it's lost on clone — P1.M4.T2.S1 owns that; this subtask does local chmod +x.
```

### Integration Points

```yaml
FILESYSTEM:
  - create: "tmux-zoxide-sessions.tmux   (PRD §5.2 PART 1 verbatim; chmod +x; at REPO ROOT; EXECUTED by TPM)"
  - create: "tests/test_run_file.sh   (dev integration test; +x harmless but not required)"

DEPENDENCY (already satisfied — do NOT modify):
  - scripts/lib/resolve.sh: COMPLETE (S1–S4). The run file sources it and calls get_tmux_option twice.
    get_tmux_option returns the default for an unset @-option (show-option -gqv prints nothing + exit 0).

DEPENDENCY (in flight — P1.M2.T1.S1, treat as CONTRACT):
  - scripts/z-window.sh: PRD §5.4 verbatim, chmod +x, accepts [query ...], opens ONE window in the
    resolved dir (or cur on empty/no-match). The binding stores run-shell '<abs>/scripts/z-window.sh %%'.
    CASE 3 of the test requires it (-x); CASES 1–2 do not.

DOWNSTREAM CONSUMER (next milestone):
  - P1.M3.T2.S1 (session hook): APPENDS the '# --- 2. Session auto-relocate hook' block to THIS file
    (set-hook -g session-created "run-shell -b '<abs>/scripts/z-session.sh \"#{session_name}\"'").
    It does NOT rewrite — so PART 1 must terminate cleanly (no dangling heredoc/continuation).
  - P1.M4.T1 (README): documents window-jump usage + @zoxide-sessions-key/@zoxide-sessions-prompt (Mode A).
  - P1.M4.T2.S1: commits the executable bit (git update-index --chmod=+x) and runs the §7 matrix + §9.

NO DATABASE / BUILD / CONFIG CHANGES:
  - This subtask adds one executable run file + one test. It reads 2 tmux options (the binding's defaults).
  - .gitignore: UNCHANGED (forbidden). PRD.md: UNCHANGED (read-only). resolve.sh / z-window.sh: UNCHANGED.
```

## Validation Loop

### Level 1: Syntax & Style (Immediate Feedback)

```bash
# Static lint — the run file is bash. `shellcheck -x` follows the sourced resolve.sh, so SC1091
# disappears and the gate is a clean rc 0. (Do NOT use `grep -v SC1091` — it is NOT empty on this
# shellcheck build: SC1091's message is multi-line. See research/verification_notes.md §3.)
shellcheck -x tmux-zoxide-sessions.tmux
# Expected: rc=0, no output.

# Confirm "only SC1091 without -x" (informational parity with P1.M2.T1.S1's sourcing script):
shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -Eo 'SC[0-9]+' | sort -u
# Expected: a single line: SC1091

# PART-1-only guard: NO session-hook code leaked (PART 2 = P1.M3.T2.S1).
grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' tmux-zoxide-sessions.tmux; echo "rc=$?"
# Expected: rc=1 (grep found NO match -> PART 1 only). The verbatim header comment mentions
# "session-created hook" in prose, which is fine — this guard targets code tokens, not prose.

# Confirm the run file is executable (this subtask's chmod).
test -x tmux-zoxide-sessions.tmux && echo "executable OK"
# Expected: executable OK

# Confirm bash-clean by inspection. Expect NO matches (no set -e / eval / echo -e / extra logic):
grep -nE '\bset -e\b|\beval\b|\becho -e\b' tmux-zoxide-sessions.tmux
# Expected: nothing prints.

shellcheck tests/test_run_file.sh
# Expected: exit 0, no output. (Verified during research: clean POSIX sh.)
```

### Level 2: Integration Test (Component Validation — the authoritative gate)

```bash
# The isolated-server integration test (item contract #5). Does NOT touch the user's live tmux.
sh tests/test_run_file.sh
# Expected output ends with:  RESULTS: pass=9 fail=0   and exit code 0.
# (C0 PART-1-only; C1 g registered; C2 prompt 'z to:'; C3 abs path + %% kept; C4 Z registered;
#  C5 prompt 'jump to'; C6 exactly 1 window; C7 name=proj; C8 start_path=$FIX/proj.)
# If C1/C4 FAIL with "unknown key": you queried `list-keys -T prefix <key>` WITHOUT -1 — use -1.
# If C6/C7/C8 FAIL with the window in $HOME: you set PATH AFTER booting the server — set it BEFORE
#   `tmux -L <sock> new-session` (run-shell inherits the server PATH). See verification_notes §4.
# If C6/C7/C8 report "z-window.sh missing": run P1.M2.T1.S1 first (the binding's target must exist).

# Regression guards: prior tests must still pass (this subtask only ADDS files; nothing it depends on changed).
sh tests/test_z_window.sh                  # P1.M2.T1.S1: expect RESULTS: pass=11 fail=0, exit 0
sh tests/test_resolve_dispatcher.sh        # S4: expect RESULTS: pass=14 fail=0, exit 0
sh tests/test_resolve_z.sh                 # S3: pass=5 fail=0
sh tests/test_resolve_zoxide.sh            # S2: pass=3 fail=0
sh tests/test_resolve_get_tmux_option.sh   # S1: pass=6 fail=0
```

### Level 3: TPM-Load Simulation & Manual Smoke (System Validation)

```bash
# 3a. The run file's shebang + x bit make it directly runnable (TPM executes it, not sources it).
head -1 tmux-zoxide-sessions.tmux          # Expected: #!/usr/bin/env bash
ls -l tmux-zoxide-sessions.tmux            # Expected: -rwxr-xr-x ... (the x bit is set)

# 3b. Simulate TPM loading it onto an ISOLATED server (mirrors the test, ad hoc — NOT a gate).
REAL_TMUX=/usr/bin/tmux; SOCK=zxssmoke_run
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; sleep 0.2
B=$(mktemp -d)                                         # fake-bin dir (set BEFORE boot)
printf '#!/bin/sh\nexec "%s" -L %s "$@"\n' "$REAL_TMUX" "$SOCK" > "$B/tmux"; chmod +x "$B/tmux"
PATH="$B:$PATH" "$REAL_TMUX" -L "$SOCK" new-session -d -s zs -c "$HOME"; sleep 0.2
PATH="$B:$PATH" "$PWD/tmux-zoxide-sessions.tmux" >/dev/null 2>&1          # TPM-style execution
"$REAL_TMUX" -L "$SOCK" list-keys -1 -T prefix g
# Expected: bind-key -T prefix g command-prompt -p "z to:" "run-shell '<PWD>/scripts/z-window.sh %%'"
"$REAL_TMUX" -L "$SOCK" kill-server 2>/dev/null; rm -rf "$B"

# 3c. Sanity: the test never touches the user's LIVE tmux socket (default). Every call uses -L zxstest_run.
#     (No command — this is a guarantee by construction: the fake wrapper hard-codes -L zxstest_run.)
```

### Level 4: N/A

No performance, security-scanning, or API-doc validation applies to a ~15-line run file that
registers one key binding. The feature (register the binding on the configured key with the
configured prompt, pointing at the repo's z-window.sh with `%%`, reload-safe, TPM-loadable) is
fully covered by Level 1's static gates + Level 2's 9 assertions + the Level 3b TPM-load smoke.
Skipped intentionally. (The shell-metachar injection residual in typed prompt input is
documented and accepted — findings §6; the run file never `eval`s anything and z-window.sh only
passes the query to `resolve()` / `new-window`.)

## Final Validation Checklist

### Technical Validation

- [ ] `test -x tmux-zoxide-sessions.tmux` → executable (the x bit is set; this subtask's chmod).
- [ ] `shellcheck -x tmux-zoxide-sessions.tmux` → rc 0, no output.
- [ ] `shellcheck tmux-zoxide-sessions.tmux 2>&1 | grep -Eo 'SC[0-9]+' | sort -u` → only `SC1091`.
- [ ] `grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' tmux-zoxide-sessions.tmux` → rc 1 (PART 1 only).
- [ ] `shellcheck tests/test_run_file.sh` → exit 0, no output.
- [ ] `sh tests/test_run_file.sh` → `RESULTS: pass=9 fail=0`, exit 0.
- [ ] `sh tests/test_z_window.sh` (P1.M2.T1.S1) still passes — no regression.
- [ ] `sh tests/test_resolve_*.sh` (S1–S4) still pass — no regression.
- [ ] Anti-pattern grep (Level 1) prints nothing (no `set -e`/`eval`/`echo -e`).
- [ ] The isolated test server (`-L zxstest_run`) leaves the user's live tmux untouched.

### Feature Validation

- [ ] All success criteria from "What" met.
- [ ] Default options → binding on `g` with prompt `z to:` and `run-shell '<abs>/scripts/z-window.sh %%'` (CASE 1).
- [ ] Custom `@zoxide-sessions-key Z` / `@zoxide-sessions-prompt "jump to"` → binding on `Z` with that prompt (CASE 2).
- [ ] Triggering the prompt path (`run-shell '<abs>/z-window.sh proj'`) → exactly one window named `proj` in the resolved dir (CASE 3; PRD §7 test #8).
- [ ] The run file sources `$CURRENT_DIR/scripts/lib/resolve.sh` and reads both options via `get_tmux_option` (does not reimplement option reading).
- [ ] The run file is PRD §5.2 **PART 1 verbatim** (eyeball against PRD §5.2; the `# --- 1.` block present; the `# --- 2.` block ABSENT).

### Code Quality Validation

- [ ] Follows PRD §5.2 PART 1 verbatim (the run-file body) — no "improvements."
- [ ] bash run file is `shellcheck -x`-clean; the POSIX-`sh` test is `shellcheck`-clean.
- [ ] File placement matches the desired tree (`tmux-zoxide-sessions.tmux` new + executable at repo ROOT; `tests/test_run_file.sh` new).
- [ ] Executable bit set on `tmux-zoxide-sessions.tmux` ONLY (resolve.sh/z-window.sh stay as their owners left them; tests not chmod'd).
- [ ] The test asserts via `list-keys -1 -T prefix <key>` (the mandatory `-1`), with PATH set before boot for `run-shell` isolation.
- [ ] The test drives an isolated `tmux -L zxstest_run` server (user's live tmux untouched).

### Documentation & Deployment

- [ ] Inline header comment documents the file's purpose (PRD §5.2 verbatim — describes the final two-feature file; PART 1 ships the window binding now).
- [ ] No README/doc changes in this subtask (Mode A — README authored wholesale in P1.M4.T1; item contract #6).
- [ ] No new tmux options, hooks (PART 1), or environment variables introduced beyond the two the binding reads.

---

## Anti-Patterns to Avoid

- ❌ Don't add the `# --- 2. Session auto-relocate hook` block — it is P1.M3.T2.S1 and is **APPENDED** later. Shipping PART 2 here would create a merge/append conflict and violate item contract #4. The file ends after the single `bind-key`.
- ❌ Don't drop or alter the header comment to "only describe PART 1" — keep it **verbatim** from PRD §5.2 so the final file (after P1.M3.T2.S1 appends PART 2) is byte-for-byte PRD §5.2. The header describes the *final* file; only PART 1's *code* ships now.
- ❌ Don't change the binding's quoting — `"run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"`. The **outer double quotes** make `$CURRENT_DIR` expand at bind time (baking the absolute path); the **inner single quotes** are literal characters tmux stores; `%%` is the command-prompt token. Any other quoting breaks the absolute path or the substitution.
- ❌ Don't assert the binding via `tmux list-keys -T prefix g` (no `-1`) — it returns `unknown key: g`. Use `list-keys -1 -T prefix g` (query one key) or `list-keys -T prefix | grep z-window` (full table). This is the #1 silent test failure (verification_notes §1).
- ❌ Don't set the fake `tmux`/`zoxide` PATH **after** booting the isolated server — `tmux run-shell` spawns children with the **server's** PATH (captured at startup), so CASE 3's z-window.sh would escape isolation and hit the user's **live** tmux. Set PATH **before** `tmux -L <sock> new-session` (verification_notes §4).
- ❌ Don't run the test against the user's **live** tmux — always drive an isolated server (`tmux -L zxstest_run`) via a fake `tmux` wrapper on PATH (item contract #5).
- ❌ Don't use `shellcheck <file> | grep -v SC1091` as the "empty" gate — on this shellcheck build SC1091's message is multi-line and `grep -v SC1091` leaves the `In … line N:` / `For more information:` lines (NOT empty). Use `shellcheck -x` (rc 0) or `grep -Eo 'SC[0-9]+' | sort -u` == SC1091 (verification_notes §3).
- ❌ Don't "harden" the run file with `set -e`, error handling, logging, a tmux-version check, or extra bindings — PRD §5.2 PART 1 is intentionally minimal (one source, two option reads, one bind-key). TPM suppresses output anyway; a loud failure mode is worse than silent (the binding just won't register, same as any misconfigured tmux.conf).
- ❌ Don't `chmod +x resolve.sh` (sourced, never executed — S1–S4 invariant), `z-window.sh` (P1.M2.T1.S1 owns it), or the tests. The **only** chmod this subtask performs is `tmux-zoxide-sessions.tmux`.
- ❌ Don't modify `resolve.sh`, `z-window.sh`, `PRD.md`, `.gitignore`, the S1–S4 tests, or `test_z_window.sh`, or create `z-session.sh`/`README.md`/the PART-2 hook (P1.M3 / P1.M4 / P1.M3.T2 own those).
- ❌ Don't pull in bats/shunit2/sharness — dependency-free isolated-server + fake-binary mock is the mandated/established pattern (S1–S4, P1.M2.T1.S1).

---

## Scope Boundaries (explicit)

| Item | This subtask (S1 of M2.T2) | Other subtasks |
| --- | --- | --- |
| `tmux-zoxide-sessions.tmux` (PART 1) | ✅ CREATE (PRD §5.2 PART 1 verbatim) + `chmod +x` | P1.M3.T2.S1 APPENDS PART 2 (session hook) |
| `scripts/lib/resolve.sh` | ❌ DO NOT (CONSUME get_tmux_option only) | S1–S4 own it (COMPLETE) |
| `scripts/z-window.sh` | ❌ DO NOT (CONSUME — the binding's target) | P1.M2.T1.S1 owns it (CONTRACT) |
| `tests/test_run_file.sh` | ✅ CREATE (additive dev artifact) | extends the S1–S4 / test_z_window pattern |
| the PART 2 session-hook block (`set-hook`/`z-session.sh`) | ❌ DO NOT (would break the P1.M3.T2.S1 append) | P1.M3.T2.S1 |
| `@zoxide-sessions-key` / `@zoxide-sessions-prompt` docs | (confirm defaults 'g','z to:' match PRD §4 — they do) | README docs them (P1.M4.T1) |
| `z-session.sh`, README.md, committed exec bit | ❌ DO NOT | P1.M3 / P1.M4 / P1.M4.T2.S1 |
| `chmod +x` on anything except `tmux-zoxide-sessions.tmux` | ❌ DO NOT | P1.M4.T2.S1 sets remaining ship bits |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 9.5/10** — The run file is **PRD §5.2 PART 1 verbatim** (trivial; no design risk) and was `shellcheck -x`-verified clean (rc 0). The binding registration and the `run-shell`-dispatched window-open were both **exercised end-to-end** during research on an isolated tmux server (`tmux -L zxstest*`) with a fake `tmux` wrapper + fake `zoxide`: default binding on `g` with prompt `z to:` + abs path + `%%`; custom key `Z` / prompt `jump to`; and `run-shell '<path>/z-window.sh proj'` opening one window named `proj` in `$FIX/proj` (count delta 1). The two non-obvious tmux-internals traps that would silently break the test — (1) `list-keys` needs **`-1`** to query one key (a bare key yields `unknown key: g`), and (2) `tmux run-shell` inherits the **server's** PATH so the fakes must be on PATH **before** the server boots — are surfaced, justified, and fixed in `research/verification_notes.md` §1/§4. The shellcheck gate is corrected (`-x` rc 0, not the non-empty `grep -v SC1091`). The PART-1-only scoping (no `set-hook`/`z-session.sh`/`auto-session` code; clean termination for the P1.M3.T2.S1 append; verbatim header describing the final file) is explicit and guarded by C0. Executed-not-sourced / `chmod +x` / repo-root placement / single-bind-key / verbatim-quoting / no-live-tmux / no-doc-update boundaries are explicit. The residual half-point: CASE 3 depends on `z-window.sh` existing (P1.M2.T1.S1, parallel — treated as a contract and required via `test -x`); CASES 1–2 (the run file's core job) validate independently of it, so the binding-registration confidence is 10/10 and only the integrated window-open carries the cross-subtask dependency. `/bin/sh`→bash means the POSIX test's dash-strictness is observed via `shellcheck` rather than a real dash run, but the self-contained integration test is the authoritative, machine-independent gate. This subtask completes the window-jump feature (with P1.M2.T1.S1) and unblocks P1.M3 (the session hook appends here).
