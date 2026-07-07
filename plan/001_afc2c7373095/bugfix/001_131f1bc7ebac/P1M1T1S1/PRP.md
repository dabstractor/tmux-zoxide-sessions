# PRP — P1.M1.T1.S1: Harden all 6 fake-zoxide test fixtures (strip `--` + model list-mode)

## Goal

**Feature Goal**: Restructure the argument parsing inside all 6 fake-`zoxide` test fixtures so they faithfully model real zoxide's two behaviors that today's fakes get wrong: (a) honoring `--` as end-of-options, and (b) entering **list mode** (multi-line database dump) for `-l`/`--list` when `--` is absent. This makes Issue 1 (zoxide flag absorption) **observable by tests** and is the prerequisite for the next subtask (S2), which restores the `--` guard in `scripts/lib/resolve.sh`.

**Deliverable**: Modified heredocs in exactly 6 test files — `tests/test_resolve_zoxide.sh`, `tests/test_resolve_dispatcher.sh`, `tests/test_z_window.sh`, `tests/test_z_session.sh`, `tests/test_run_file.sh`, and subtest B of `tests/test_backend_matrix.sh`. No source-code changes. No new assertions (regression tests are a later task, T3).

**Success Definition**:
- All 6 fakes strip a leading `--` (consume it; treat the rest as a positional query).
- All 6 fakes emit a **multi-line** dump + `exit 0` for `-l`/`--list` **only when `--` is absent**.
- After `--`, `-l`/`--list` is **never** treated as a flag (it becomes a positional query → no-match).
- The full suite still reports **80 pass / 0 fail** (verified baseline; see Validation).
- D2 (`test_resolve_dispatcher.sh`) still returns **exit 1** on positional no-match (CORRECTION B exercise).
- D6 (`test_backend_matrix.sh`) still uses its **unquoted** heredoc with `\$1` escaped and `$TOKEN`/`$FIX` build-time expansion.
- The false "would break the shim" / "implementing ONLY: zoxide query [--]" comments are replaced with accurate ones.

## User Persona

**Target User**: The implementing AI agent (this subtask) and, downstream, the regression-test author (T3) and the `--`-guard restorer (S2).

**Use Case**: Make the test sandbox capable of reproducing real zoxide's flag parsing so that the absent `--` guard (Issue 1) becomes a *detectable* defect rather than a silent no-op.

**Pain Points Addressed**: Today every fake does a blind `shift` + `case "$1"`, treating `-l` as an ordinary (empty) keyword. That is why Issue 1 shipped uncaught: no fake could ever return a multi-line dump, so no assertion could observe the absorption path.

## Why

- Issue 1 (Major) is that `_resolve_zoxide` calls `zoxide query "$1"` with no `--` guard (`scripts/lib/resolve.sh:19`), so a `-l`/`--list` query dumps the entire frecency database (146+ lines) into a corrupted window. The fix has three layers; **this subtask owns layer 3 (fixture verifiability)** and is sequenced **before** S2 (the root `--` guard) because of a hard coupling (see Gotchas).
- **Coupling (findings_and_risks.md §R1):** Restoring `zoxide query -- "$1"` in S2 changes the argv the fakes receive from `query <kw>` to `query -- <kw>`. If the fakes still do a blind `shift` + `case "$1"`, the `--` lands in `$1`, every existing `proj`-match silently flips to no-match, and the suite breaks. So fixtures must learn to strip `--` *first*. Both subtasks end green.
- This subtask is strictly **additive and a no-op for current behavior**: the resolver still omits `--` until S2, so no current assertion queries `-l`, and the `--`-stripping branch is never taken on a `query proj` call (proven in Validation).

## What

User-visible behavior: none (test fixtures are internal dev artifacts; no config/API/README surface changes).

### Success Criteria

- [ ] Each of the 6 fakes: `query -- <token>` resolves `<token>` the same as `query <token>` (i.e. `--` is transparently stripped).
- [ ] Each of the 6 fakes: `query -l` and `query --list` each print **≥2 lines** and `exit 0`.
- [ ] Each of the 6 fakes: `query -- -l` prints **empty** and the file's documented no-match exit code (R2 holds — `--` beats list-mode).
- [ ] D2's `*` arm still `exit 1` on positional no-match; its `-l|--list` arm `exit 0`.
- [ ] D6 keeps its **unquoted** `<<ZOX` heredoc; `\$1` stays escaped; `$TOKEN`/`$FIX` stay unescaped (build-time expansion); **no backticks anywhere** in the heredoc.
- [ ] `sh tests/test_*.sh` → **80 pass / 0 fail** across all 9 files (identical to baseline).
- [ ] `shellcheck tests/*.sh` → clean (only SC1091 info on sourced files; heredoc bodies are data, so internals are not analyzed).

## All Needed Context

### Context Completeness Check

If someone knew nothing about this codebase, could they implement this successfully? **Yes.** The exact current content of every fixture, the harness mechanism, the canonical replacement form, and a per-file diff table are all below. No broader codebase knowledge is required.

### Documentation & References

```yaml
# MUST READ
- file: scripts/lib/resolve.sh
  why: The call site the fakes model. Line 19 is `zoxide query "$1"` (NO `--`) today; S2 (next task) adds `--`.
  critical: "This subtask must NOT change resolve.sh. The fakes must remain correct for the CURRENT no-`--` call AND for the future `--` call."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/research_issue1_defense.md
  why: Authoritative brief. §D1–D6 = exact current state of each fake (matches repo); §D "Hardening plan" + skeleton.
  critical: "⚠️ The §D skeleton does `[ \"$1\" = \"--\" ] && shift` then ONE unified `case` that includes `-l|--list`. That is BUGGY (violates R2). Do NOT copy it. Use the if/else form in this PRP. See Known Gotchas."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/architecture/findings_and_risks.md
  why: §R1 (coupling/ordering), §R2 (`--` BEFORE list-mode), §F6 (80/0 baseline, runner), §R5 (D2 exit-1-on-no-match).
  section: "R1, R2, F6, R5"

- file: tests/test_z_window.sh
  why: Canonical harness example (fake `tmux` wrapper → isolated `-L zxstest_*` server, quoted heredoc with `$FIX` runtime-expand via `export FIX`, `pass/fail/check`, backend forced to `zoxide`).
  pattern: "How the fake-zoxide is installed/invoked; what an assertion looks like."
  gotcha: "Quoted heredocs (`<<'ZOX'`) write `$FIX` LITERALLY; `$FIX` resolves at RUNTIME because the test exports it. Preserve literal `$FIX` in D3/D4/D5."

- docfile: plan/001_afc2c7373095/bugfix/001_131f1bc7ebac/P1M1T1S1/research/fixture_hardening_notes.md
  why: Verified per-file current-state table + the R2 trap + baseline confirmation.
```

### Current Codebase tree (test files only)

```bash
tests/
  test_backend_matrix.sh        # subtest B has a fake-zoxide (UNQUOTED heredoc)
  test_resolve_dispatcher.sh    # fake-zoxide (quoted); no-match EXIT 1
  test_resolve_get_tmux_option.sh  # NO fake-zoxide — out of scope
  test_resolve_zoxide.sh        # fake-zoxide (quoted); no-match exit 0
  test_resolve_z.sh             # NO fake-zoxide (fakes tmux/z.sh only) — out of scope
  test_run_file.sh              # fake-zoxide (quoted)
  test_session_hook.sh          # NO fake-zoxide — out of scope
  test_z_session.sh             # fake-zoxide (quoted); two match tokens incl "two words"
  test_z_window.sh              # fake-zoxide (quoted); harness reference
```

### Desired Codebase tree with files to be modified

```bash
tests/   # only the fake-zoxide heredoc inside each file changes; file set unchanged
  test_resolve_zoxide.sh      # MODIFY heredoc  (D1)
  test_resolve_dispatcher.sh  # MODIFY heredoc  (D2) — keep exit 1 on `*`
  test_z_window.sh            # MODIFY heredoc  (D3)
  test_z_session.sh           # MODIFY heredoc  (D4) — keep "two words" token
  test_run_file.sh            # MODIFY heredoc  (D5)
  test_backend_matrix.sh      # MODIFY subtest-B heredoc + its header comment (D6) — keep unquoted style
```

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL (R2): `--` MUST be checked BEFORE `-l`/`--list`.
#   After consuming `query`, do: if [ "$1" = "--" ]; then shift;  else <list-mode case>; fi
#   then the positional `case`. NEVER put `-l|--list` in the same `case` that runs after `--`
#   is stripped — that re-enters list mode for `query -- -l` (wrong; real zoxide returns empty).
#   => The task template's if/else is correct. The arch §D skeleton (`&& shift` + unified case) is NOT.

# CRITICAL (R1): This subtask ships BEFORE the `--` guard is restored in resolve.sh.
#   The resolver still calls `zoxide query "$1"` (no `--`). So a `proj` query is argv `query proj`,
#   the `[ "$1" = "--" ]` test is false, and the positional `case` matches `proj` as before.
#   => The suite stays 80/80. Do NOT also restore the guard here (that is S2).

# CRITICAL (D2): test_resolve_dispatcher.sh's fake returns exit 1 on positional no-match
#   (`*) printf ''; exit 1`) to exercise CORRECTION B (resolve() always exit 0). KEEP that exit 1
#   on the `*` arm. Only the `-l|--list` arm is new and exits 0 (real zoxide exits 0 in list mode).

# CRITICAL (D6): test_backend_matrix.sh subtest B uses an UNQUOTED heredoc (`<<ZOX`).
#   - `$1` MUST stay written as `\$1` (escaped) so it survives to the fake.
#   - `$TOKEN` and `$FIX` MUST stay UNescaped (they expand at fixture-build time; TOKEN=zxmatrix).
#   - NO backticks anywhere inside the unquoted heredoc — they would trigger command substitution
#     at build time. Write comments in plain words (no `query [--] <kw>` with backticks).

# GOTCHA (heredoc quoting): D1/D2/D3/D4/D5 use QUOTED heredocs (`<<'ZOX'`/`<<'ZOXIDE'`).
#   `$FIX`/`$TOKEN` are written LITERALLY and resolve at RUNTIME because the test exports them.
#   Preserve the literal `$FIX` form in D3/D4/D5 dumps.

# GOTCHA: ShellCheck does NOT analyze heredoc bodies (they are string data), so adding code inside
#   the `<<...` blocks cannot introduce SC warnings. `shellcheck tests/*.sh` stays clean regardless.

# FORBIDDEN: Do NOT modify scripts/lib/resolve.sh, scripts/z-window.sh, scripts/z-session.sh
#   (owned by S2 / T2). Do NOT add regression assertions (owned by T3). Do NOT touch
#   test_resolve_z.sh, test_resolve_get_tmux_option.sh, test_session_hook.sh (no fake-zoxide).
#   Do NOT modify .gitignore or PRD.md. Do NOT change Issue 2 (single-quote) files.
```

## Implementation Blueprint

### Data models and structure

N/A — pure shell-argument parsing. The "model" is real zoxide's CLI surface for `query`:

| input argv (after the binary) | real zoxide behavior | modeled fake behavior |
|---|---|---|
| `query <token>` | resolve token → 1 dir or empty | unchanged (positional `case`) |
| `query -- <token>` | `--` ends options; token positional → resolve | strip `--`, then positional `case` |
| `query -l` / `query --list` | **list mode** → multi-line DB dump, exit 0 | multi-line `printf`, exit 0 |
| `query -- -l` | `--` ends options → `-l` is a literal query → empty | strip `--`, positional `case` → no-match (R2) |
| `query` with no token | empty positional → no-match | positional `case` `*` (unchanged) |

### Canonical hardened form (R2-correct — use this shape for ALL 6)

```sh
#!/bin/sh
# Fake zoxide: models query [--] <kw> AND list-mode for -l/--list, like real zoxide.
# Strip -- (real zoxide honors end-of-options); model list-mode for -l/--list.
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then
    shift      # -- consumed; everything after is a POSITIONAL query (NEVER list-mode after --)
else
    # No --: model real zoxide flag parsing. -l/--list -> list-mode DB dump (multi-line).
    case "$1" in
        -l|--list) printf '%s\n' "<dump1>" "<dump2>" "<dump3>"; exit 0 ;;
    esac
fi
# Positional query resolution (after -- or a non-flag token)
case "$1" in
    <token>) printf '%s\n' "<dir>" ;;   # MATCH
    *)       printf '' ;;               # no-match -> empty
esac
exit 0
```

> **Why `if/else` and not `[ "$1" = "--" ] && shift` + one `case`:** the single-`case` form puts `-l|--list` in the branch that runs *after* `--` is consumed, so `query -- -l` would wrongly print the dump. The `if/else` guarantees list-mode is reachable **only** through the `else` (no `--`) path. This is §R2 made concrete.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: STANDALONE LOGIC PROBE (do this FIRST to validate the canonical form in isolation)
  - CREATE a throwaway /tmp/zxprobe/z from the canonical form with FIX=/tmp/zxprobe/f, token=proj, dump=$FIX/proj $FIX/other1 $FIX/other2.
  - RUN and assert 4 behaviors (see Validation Level 2). Fix the canonical form if any fail BEFORE editing the 6 files.
  - WHY: isolates the if/else logic from test-harness noise; catches an R2 mistake in seconds.
  - DISCARD after (do not commit /tmp/zxprobe).

Task 2: MODIFY tests/test_resolve_zoxide.sh  (D1) — quoted heredoc <<'ZOXIDE'
  - REPLACE the heredoc body (currently lines ~12–24) with the canonical form.
  - TOKEN: proj -> /home/user/projects/proj  (literal; no $FIX in this file).
  - DUMP:  printf '%s\n' "/home/user/projects/proj" "/home/user/projects/other1" "/home/user/projects/other2"
  - NO-MATCH arm: *) printf ''  (exit 0 implicit; keep trailing `exit 0`).
  - DROP the now-redundant `kw="$1"` var; use `$1` directly (behavior identical).
  - REPLACE header comment "# Fake zoxide implementing ONLY: zoxide query [--] <keyword>" with the canonical 2-line comment.

Task 3: MODIFY tests/test_resolve_dispatcher.sh  (D2) — quoted heredoc <<'ZOXIDE'
  - SAME shape as D1 BUT:
  - NO-MATCH arm MUST stay: *) printf ''; exit 1   (CORRECTION B — do NOT change to exit 0).
  - -l|--list arm: exit 0 (list-mode is a successful list query in real zoxide).
  - TOKEN: proj -> /home/user/projects/proj  (literal).
  - REPLACE the header comment as in D1.

Task 4: MODIFY tests/test_z_window.sh  (D3) — quoted heredoc <<'ZOX'
  - CANONICAL form; TOKEN: proj -> $FIX/proj (LITERAL $FIX; resolves at runtime via export FIX).
  - DUMP: printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"
  - NO-MATCH arm: *) printf ''; exit 0
  - REPLACE inline comment "# no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)" with the canonical 2-line comment.

Task 5: MODIFY tests/test_z_session.sh  (D4) — quoted heredoc <<'ZOX'
  - CANONICAL form; TWO match tokens preserved EXACTLY:
      proj)        printf '%s\n' "$FIX/proj"; exit 0 ;;
      "two words") printf '%s\n' "$FIX/twowords"; exit 0 ;;
  - DUMP: printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"
  - NO-MATCH arm: *) printf ''; exit 0
  - REPLACE the same false inline comment as D3.

Task 6: MODIFY tests/test_run_file.sh  (D5) — quoted heredoc <<'ZOX'
  - IDENTICAL to D3 (token proj -> $FIX/proj; same dump; same comment swap).

Task 7: MODIFY tests/test_backend_matrix.sh  (subtest B only, ~lines 165–179)  (D6) — UNQUOTED heredoc <<ZOX
  - CANONICAL form, BUT preserve the unquoted-heredoc style:
      * every `$1` written as `\$1` (escaped)
      * `$TOKEN` and `$FIX/...` left UNescaped (build-time expand; TOKEN=zxmatrix)
      * NO backticks in the heredoc (comments in plain words — see Gotchas)
  - TOKEN: $TOKEN) printf '%s\n' "$FIX/$TOKEN"; exit 0   (unchanged match arm)
  - DUMP:  printf '%s\n' "$FIX/$TOKEN" "$FIX/extra1" "$FIX/extra2"
  - NO-MATCH arm: *) printf ''; exit 0
  - ALSO replace the header COMMENT BLOCK immediately above the heredoc
    ("# No '--' handling: matches the real zoxide/zoxide-shim invocation form, which omits '--'.")
    with an accurate note, e.g.:
      "# Install the fake zoxide into $TBIN (already front-of-PATH): models query [--] <kw>"
      "# and list-mode for -l/--list (like real zoxide); <TOKEN> -> the real fixture dir, else empty."
  - LEAVE the trailing `rm -f "$TBIN/zoxide"` (cleanup so it does not leak into subtests A/C) untouched.

Task 8: VERIFY (no edits) — see Validation Loop.
```

### Exact replacement bodies (paste-ready)

> These are the precise heredoc bodies to drop into each file (replacing the existing fake). For the quoted-heredoc files (D1–D5) the `$FIX`/literal-path rules apply as noted; for D6 the unquoted-heredoc escapes apply.

**D2 — `tests/test_resolve_dispatcher.sh` (note `exit 1` on `*`):**
```sh
cat > "$TBIN/zoxide" <<'ZOXIDE'
#!/bin/sh
# Fake zoxide: models query [--] <kw> AND list-mode for -l/--list, like real zoxide.
# Strip -- (real zoxide honors end-of-options); model list-mode for -l/--list.
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then
    shift      # -- consumed; everything after is a POSITIONAL query (NEVER list-mode after --)
else
    case "$1" in
        -l|--list) printf '%s\n' "/home/user/projects/proj" "/home/user/projects/other1" "/home/user/projects/other2"; exit 0 ;;
    esac
fi
case "$1" in
    proj) printf '%s\n' "/home/user/projects/proj"; exit 0 ;;   # MATCH
    *)    printf ''; exit 1 ;;                                   # no-match: empty + NON-zero (CORRECTION B)
esac
ZOXIDE
```

**D6 — `tests/test_backend_matrix.sh` subtest B (UNQUOTED heredoc; `\$1` escaped; no backticks):**
```sh
cat > "$TBIN/zoxide" <<ZOX
#!/bin/sh
# Fake zoxide: models query [--] <kw> AND list-mode for -l/--list, like real zoxide.
# Strip -- (real zoxide honors end-of-options); model list-mode for -l/--list.
[ "\$1" = "query" ] || exit 0
shift
if [ "\$1" = "--" ]; then
    shift      # -- consumed; everything after is a POSITIONAL query (NEVER list-mode after --)
else
    case "\$1" in
        -l|--list) printf '%s\n' "$FIX/$TOKEN" "$FIX/extra1" "$FIX/extra2"; exit 0 ;;
    esac
fi
case "\$1" in
    $TOKEN) printf '%s\n' "$FIX/$TOKEN"; exit 0 ;;   # MATCH (real dir)
    *)      printf ''; exit 0 ;;                       # no-match: empty, exit 0
esac
ZOX
chmod +x "$TBIN/zoxide"
```

(D1 = D2 with `exit 1`→(implicit exit 0) and the trailing `exit 0` kept; D3/D5 = the `$FIX/proj` quoted form; D4 = D3 plus the `"two words"` arm. All five quoted-heredoc files take the canonical body with their token/path/no-match-exit variants from the Task table.)

### Implementation Patterns & Key Details

```sh
# The single load-bearing idiom: `--` BEFORE list-mode (R2).
if [ "$1" = "--" ]; then
    shift                      # positional only from here; do NOT re-check flags
else
    case "$1" in
        -l|--list) printf '%s\n' <multi-line>; exit 0 ;;
    esac
fi
case "$1" in <token>) ... ;; *) printf '' ;; esac   # positional resolution, shared by both paths
```

```sh
# Multi-line guarantee: the dump MUST contain >=2 lines so T2's newline-reject guard and
# T3's regression tests can observe it. printf '%s\n' A B C prints 3 lines. Do NOT collapse to one.
```

### Integration Points

```yaml
TEST HARNESS (unchanged by this task):
  - each integration test (D3/D4/D5/D6) boots an isolated `tmux -L zxstest_*` server via a fake
    `tmux` wrapper on PATH, forces `@zoxide-sessions-backend zoxide`, and runs the REAL scripts.
  - the fake `zoxide` lives in `$TBIN` (front-of-PATH). Do not change install/cleanup/PATH plumbing.
  - `export FIX` makes `$FIX` visible to quoted-heredoc fakes at runtime — keep exporting it.

DOWNSTREAM CONSUMERS (this task enables, does not implement):
  - S2 (P1.M1.T1.S2): restores `zoxide query -- "$1"` in resolve.sh. Safe only AFTER this task.
  - T2 (P1.M1.T2): caller-side newline-reject + `-d` guards in z-window.sh / z-session.sh.
  - T3 (P1.M1.T3): regression cases that query `-l`/`--list` and assert empty-after-guard.
```

## Validation Loop

### Level 1: Logic Probe (do FIRST, in isolation)

```bash
# Validate the canonical if/else form independent of any test file.
mkdir -p /tmp/zxprobe/f; export FIX=/tmp/zxprobe/f
cat > /tmp/zxprobe/z <<'EOF'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then shift
else case "$1" in -l|--list) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;; esac
fi
case "$1" in proj) printf '%s\n' "$FIX/proj"; exit 0 ;; *) printf ''; exit 0 ;; esac
EOF
chmod +x /tmp/zxprobe/z

echo "query proj      (expect 1 line, match)  -> $(/tmp/zxprobe/z query proj      | wc -l | tr -d ' ')"
echo "query -- proj   (expect 1 line, match)  -> $(/tmp/zxprobe/z query -- proj   | wc -l | tr -d ' ')"
echo "query -l        (expect 3 lines, dump)  -> $(/tmp/zxprobe/z query -l        | wc -l | tr -d ' ')"
echo "query --list    (expect 3 lines, dump)  -> $(/tmp/zxprobe/z query --list    | wc -l | tr -d ' ')"
echo "query -- -l     (expect 0 lines, R2!)   -> $(/tmp/zxprobe/z query -- -l     | wc -l | tr -d ' ')"
rm -rf /tmp/zxprobe
```
Expected output: `1, 1, 3, 3, 0`. If `query -- -l` is NOT 0, the if/else is wrong (you copied the §D skeleton) — fix before touching any file.

### Level 2: No-Op Property (after editing each file)

For every modified file, confirm the `proj` match still resolves through the new code:
```bash
cd <repo>
sh tests/test_resolve_zoxide.sh   | tail -1   # RESULTS: pass=3 fail=0
sh tests/test_resolve_dispatcher.sh | tail -1  # RESULTS: pass=14 fail=0
sh tests/test_z_window.sh         | tail -1   # RESULTS: pass=11 fail=0
sh tests/test_z_session.sh        | tail -1   # RESULTS: pass=9 fail=0
sh tests/test_run_file.sh         | tail -1   # RESULTS: pass=9 fail=0
sh tests/test_backend_matrix.sh   | tail -1   # RESULTS: pass=12 fail=0
```
Expected: each prints its baseline `fail=0`. (These exercise the `proj`/`zxmatrix`/`two words` match arms through the new code, proving the `--`-stripping branch is a no-op for the current no-`--` resolver.)

### Level 3: Full Suite + ShellCheck (system validation)

```bash
cd <repo>
total_pass=0; total_fail=0
for t in tests/test_*.sh; do
  line=$(sh "$t" 2>&1 | grep -E '^RESULTS:')
  p=$(echo "$line" | sed -n 's/.*pass=\([0-9]*\).*/\1/p'); f=$(echo "$line" | sed -n 's/.*fail=\([0-9]*\).*/\1/p')
  [ -n "$p" ] && total_pass=$((total_pass+p)); [ -n "$f" ] && total_fail=$((total_fail+f))
  echo "$(basename $t): $line"
done
echo "TOTAL: pass=$total_pass fail=$total_fail"   # MUST be pass=80 fail=0

shellcheck tests/*.sh && echo "shellcheck clean (excluding SC1091 info expected on sourced files)" \
  || shellcheck -e SC1091 tests/*.sh
```
Expected: `TOTAL: pass=80 fail=0`; ShellCheck reports no errors/warnings for the test files (heredoc bodies are data, so they cannot introduce findings; pre-existing SC1091 info on sourced scripts is acceptable).

### Level 4: Targeted behavior re-check (optional but recommended)

After editing D6 specifically, manually confirm the unquoted-heredoc escapes survived (a common copy-paste failure is leaving `$1` unescaped, which would make the fake read the build-time `$1` = empty and break subtest B):
```bash
cd <repo>
# Grep the subtest-B fake region; $1 MUST appear as \$1, $TOKEN and $FIX must be bare.
sed -n '/SUBTEST B/,/chmod +x "\$TBIN\/zoxide"/p' tests/test_backend_matrix.sh | grep -nE '\$1|\$TOKEN|\$FIX'
# Expect to see:  "\$1" (escaped) and $TOKEN/$FIX (bare). If you see bare "$1", fix the escapes.
```

## Final Validation Checklist

### Technical Validation

- [ ] Level 1 logic probe returns `1, 1, 3, 3, 0` (R2 holds: `query -- -l` → 0 lines).
- [ ] All 9 test files green; `TOTAL: pass=80 fail=0`.
- [ ] `shellcheck -e SC1091 tests/*.sh` clean.
- [ ] D6 grep shows `\$1` escaped and `$TOKEN`/`$FIX` bare (unquoted heredoc intact).

### Feature Validation

- [ ] Each of the 6 fakes strips `--` (transparent for `query -- <token>`).
- [ ] Each models list mode (`-l`/`--list` → multi-line, exit 0) ONLY when `--` is absent.
- [ ] D2 keeps `exit 1` on positional `*`; its list-mode arm is `exit 0`.
- [ ] D4 keeps the `"two words"` match arm.
- [ ] D6 keeps `TOKEN=zxmatrix` match and the post-subtest `rm -f "$TBIN/zoxide"` cleanup.
- [ ] False comments ("would break the shim", "implementing ONLY") replaced everywhere they appeared (D1, D2, D3, D4, D5, D6).

### Code Quality Validation

- [ ] POSIX only: no `$'\n'`, `[[ ]]`, `==`, `local`, arrays, `echo -e` in any heredoc body.
- [ ] No backticks inside the D6 unquoted heredoc.
- [ ] No source files (`scripts/*`) modified. No new test assertions added. Out-of-scope files untouched.

### Documentation & Deployment

- [ ] Accurate comments on every fake (the 2-line canonical comment, adapted per file).
- [ ] No README/config changes (test fixtures are internal; docs sync is P1.M3.T1).

---

## Anti-Patterns to Avoid

- ❌ Don't use the architecture §D skeleton (`[ "$1" = "--" ] && shift` + a single unified `case` including `-l|--list`). It re-enters list mode after `--` and violates R2. Use the `if/else` form.
- ❌ Don't change D2's `exit 1` on the `*` no-match arm. It is the CORRECTION B exercise; only the `-l|--list` arm is new.
- ❌ Don't unquote the D6 heredoc's `$1` (must be `\$1`) and don't escape `$TOKEN`/`$FIX` (they must build-time-expand).
- ❌ Don't put backticks inside the D6 unquoted heredoc (command substitution at build time).
- ❌ Don't "helpfully" restore the `--` guard in `resolve.sh` here — that is S2's job and this task must ship while the resolver still omits `--` (so the change is provably a no-op).
- ❌ Don't add `-l` regression assertions in the test files — that is T3's job. S1 only hardens fixtures.
- ❌ Don't touch `test_resolve_z.sh`, `test_resolve_get_tmux_option.sh`, or `test_session_hook.sh` — they have no fake-zoxide.
- ❌ Don't collapse the list-mode dump to a single line — it must be multi-line (≥2) so T2/T3 can observe it.

---

## Scope Boundaries (explicit)

| Concern | This subtask (S1) | Other subtasks |
| --- | --- | --- |
| 6 fake-zoxide heredocs (D1–D6) | ✅ MODIFY | — |
| `scripts/lib/resolve.sh` `--` guard | ❌ DO NOT | S2 (P1.M1.T1.S2) |
| `z-window.sh` / `z-session.sh` caller guards | ❌ DO NOT | T2 (P1.M1.T2.S1/S2) |
| `-l`/`--list` regression assertions | ❌ DO NOT | T3 (P1.M1.T3.S1/S2) |
| `test_resolve_z.sh`, `test_resolve_get_tmux_option.sh`, `test_session_hook.sh` | ❌ OUT OF SCOPE (no fake-zoxide) | — |
| Issue 2 (single-quote binding), README, `.gitignore`, `PRD.md` | ❌ FORBIDDEN / other tasks | P1.M2, P1.M3 |

---

**Confidence Score: 9/10** — The current state of every fixture is captured verbatim, the canonical replacement is paste-ready with per-file variants spelled out, the 80/0 baseline is verified live, and the one real trap (R2: `--` before list-mode, and the §D skeleton that gets it wrong) is called out in three places. The residual 1/10 is the D6 unquoted-heredoc escape discipline (`\$1` vs bare `$TOKEN`), which Level 4 explicitly re-checks.
