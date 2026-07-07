# Verification Notes — P1.M2.T1.S2 (Issue 2: single-quote query regression test)

> Empirically validated in an **isolated `/tmp/prp_s2_stage/` mirror** of the repo
> (repo untouched). tmux 3.6b, `/bin/sh`, ShellCheck 0.11.0. The three edits to
> `tests/test_z_window.sh` (mkdir + fake arm + CASE 7 + CASE 8) were applied via
> `write`/python and run: **`test_z_window.sh` → pass=23 fail=0 (5/5 stable);
> full suite → pass=98 fail=0; `shellcheck tests/test_z_window.sh` exit 0**.

## 0. HEADLINE — Approach A works; the test is INDEPENDENT of the binding form

The item contract (#3) mandates **Approach A (direct invocation)** for reliability:
`$ZWIN "o'brien"` (with the optional dispatch variant `$REAL_TMUX run-shell
"$ZWIN \"o'brien\""`). Both forms are validated GREEN.

Crucially, **neither form reads the `%%` binding** — CASE 7 calls `z-window.sh`
directly, CASE 8 drives `run-shell` with a hand-constructed argument. So this
regression test passes **regardless of whether P1.M2.T1.S1 ships Fix A (the
contract's `\"%%\"`-inside-`'…'` form) or Fix A-alt (the outer-double-quote form
its own verification_notes §0 shows is the actually-working fix)**. The test
locks in the *capability* (an apostrophe query resolves end-to-end through the
handler + dispatch layer) and the *fake-zoxide contract* (`o'brien` → a real
dir), not any particular binding byte sequence. The binding-level structural
check (abs path in the binding) is owned by `test_run_file.sh` C3/C4.

## 1. The single CRITICAL quoting trap (this is the whole difficulty)

The apostrophe in the query must be written as a **BARE `'` inside double
quotes** — `run_case "o'brien"` — NEVER as `"o\'brien"`.

In POSIX sh, inside double quotes a backslash is an escape ONLY before `$`,
`` ` ``, `"`, `\`, and newline. Before any other character (including `'`) the
backslash is **literal**. So `"o\'brien"` evaluates to the 8-character string
`o\'brien` (with a real backslash), which does **not** match the fake's
`"o'brien"` pattern (7 chars, no backslash) → resolve returns empty → window
falls back to `cur` → C7b/C7c FAIL.

This was hit and fixed during validation:

| form in the test | `$1` delivered to z-window.sh | fake match? | result |
|---|---|---|---|
| `run_case "o'brien"` (bare `'`) | `o'brien` | ✅ | **PASS** (name=obrien) |
| `run_case "o\'brien"` (escaped) | `o\'brien` (literal `\`) | ❌ | FAIL (name=basename(cur)) |

(The same applies to the CASE 7 header `echo` string and to the CASE 8
`run-shell "$ZWIN \"o'brien\""` argument — the embedded `'` is bare; only the
`"` characters around `o'brien` are `\"`-escaped, because they ARE shell-special
inside the outer double-quoted argument.)

## 2. The fake-zoxide arm (quoted heredoc, double-quoted pattern)

The fake is written via `<<'ZOX'` (quoted heredoc → `$FIX` literal, expands at
runtime via `export FIX`). The new arm uses a **double-quoted case pattern** so
the apostrophe is a literal pattern character:

```sh
case "$1" in
    proj)      printf '%s\n' "$FIX/proj"; exit 0 ;;
    "o'brien") printf '%s\n' "$FIX/obrien"; exit 0 ;;   # MATCH apostrophe (Issue 2)
    multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;
    *)         printf ''; exit 0 ;;
esac
```

A bare `o'brien)` pattern is itself **invalid shell** (the `'` opens an
unterminated quote) — this is the same trap the P1.M2.T1.S1 repro warned about
(`verification_notes.md` §5). The double-quoted `"o'brien")` form is required.
Verified the generated fake matches `o'brien` → `$FIX/obrien` (rc=0).

`$FIX/obrien` MUST be a real directory (added to the `mkdir -p` line), or the
`z-window.sh` `[ -d "$resolved" ]` guard rejects it and the window falls back to
`cur` (corrupting the assertion — see P1.M2.T2.S1 finding §3, mirrored here).

## 3. The two committed cases (both Approach A, both validated)

**CASE 7 — direct invocation (the contract's primary).** Reuses `run_case` /
`new_name` / `new_start` verbatim. Asserts the resolved dir (like CASE 2), so
**no `CUR` re-capture** is needed (CUR matters only for fallback-to-cur cases).
`run_case "o'brien"` → `"$ZWIN" "o'brien"` → `$1=o'brien` → resolve → `$FIX/obrien`.

**CASE 8 — run-shell dispatch (the contract's Approach-A dispatch variant).**
Drives the REAL tmux `run-shell` with the post-`%%`-substitution argument the
FIXED binding produces: `"$REAL_TMUX" -L "$SOCK" run-shell "$ZWIN \"o'brien\""`.
Exercises tmux `run-shell` → `sh -c` → `z-window.sh` (the quoting layer the fix
protects). Independent of the binding form (the quoted arg is constructed in the
test). Negative control: the fixed (double-quoted) dispatch resolves `obrien`;
the old (unquoted) form would lose/truncate the query at the `sh -c` layer.

Both cases assert the same trio: (a) exactly 1 new window, (b) NAME=obrien,
(c) START_PATH=`$FIX/obrien`.

## 4. Why CASE 7 mirrors CASE 2 (no CUR re-capture)

`run_case` makes its new window the active one, so the active pane's cwd shifts
after each case. Cases that assert the **current** dir (1/3/4/5/6) must
re-capture `CUR=$(tmux display-message -p '#{pane_current_path}')` immediately
before `run_case`. CASE 7 asserts the **resolved** dir (`$FIX/obrien`), which is
independent of the active pane — exactly like CASE 2 (`proj`). So CASE 7 does
NOT re-capture CUR. CASE 8 likewise asserts the resolved dir.

## 5. Validated results (clean mirror `/tmp/prp_s2_stage/`, repo untouched)

```
$ sh -n tests/test_z_window.sh && echo OK        # OK
$ shellcheck tests/test_z_window.sh; echo $?     # 0  (clean — no SC1091, no notes)
$ sh tests/test_z_window.sh                      # RESULTS: pass=23 fail=0 (5/5 stable)
$ <full suite>                                   # TOTAL: pass=98 fail=0 (all 9 files)
```

Per-file (clean mirror): backend_matrix 12, resolve_dispatcher 14,
resolve_get_tmux_option 6, resolve_zoxide 3, resolve_z 5, run_file 11,
session_hook 11, z_session 13, **z_window 23** (was 17; +3 CASE 7, +3 CASE 8).

`test_z_window.sh` history: 11 (original) → 17 (P1.M1.T3.S2 CASE 5+6) → **23**
(this task, CASE 7+8). Clears the contract floor (one regression case, 3 checks)
with margin.

## 6. Composition with the parallel/sibling tasks

- **P1.M2.T1.S1** (implementing in parallel): fixes the binding `%%` quoting +
  updates `test_run_file.sh` C3/C4. This task does NOT touch the run file or
  `test_run_file.sh`. As shown in §0, this test is independent of which fix
  variant S1 ships, so there is **no conflict and no hard ordering dependency**
  — the implementer can run this task before or after S1 lands.
- **P1.M1.T3.S2** (Complete): added CASE 5 (`-l`) + CASE 6 (`multiline`) to
  `test_z_window.sh`. This task APPENDS CASE 7 + CASE 8 after CASE 6 (no overlap,
  no renumbering). The fake arm inserts cleanly between `proj)` and `multiline)`.
- **P1.M1.T2.S1** (Complete): the `z-window.sh` `[ -d "$resolved" ]` guard. CASE 7
  relies on it accepting `$FIX/obrien` (a real dir); the real dir is created in
  the `mkdir -p` line so the guard passes.

## 7. Independence from P1.M2.T1.S1's fix variant (robustness note)

P1.M2.T1.S1's PRP body specifies **Fix A** (`%%` → `\"%%\"` inside the existing
outer single quotes). P1.M2.T1.S1's own `research/verification_notes.md` §0–§1
shows **Fix A is empirically BROKEN** for apostrophes (tmux returns 2,
`z-window.sh` never reached) and that **Fix A-alt** (outer double quotes) is the
working form. Because this task's CASE 7 (direct `$ZWIN`) and CASE 8
(`run-shell` with a hand-built arg) **bypass the binding entirely**, both pass
under EITHER variant. This makes the regression robust to the S1 uncertainty and
removes any hard dependency. (If a future task wants a *binding-level* behavioural
test of the `%%` wrapping, it must use Approach B — `source-file` of the binding's
emitted post-substitution line — which is more brittle and binding-form-dependent;
out of scope here per the contract's "Use Approach A for reliability.")
