# Findings & Risks — Bugfix 001

> Derived from three parallel research subagents + direct codebase analysis.

## Findings (verified facts)

### F1. The `--` guard removal is a regression, not a design choice
- Commit `eabce65`/`bb90152` originally added `zoxide query -- "$1"` per contract P1.M1.T2.S2/NOTE D.
- Commit `b93e776` removed it on a **factually false** rationale (see system_context.md §1).
- The original PRP (P1M1T2S2/PRP.md) explicitly mandates the `--` guard and lists dropping it
  as an anti-pattern: "Don't drop the `--` guard — `zoxide query "$1"` is the PRD's unhardened form."

### F2. Real zoxide enters list mode for `-l`/`--list` without `--`
- `zoxide query "-l"` → 146+ lines (entire frecency database dump)
- `zoxide query "--list"` → same dump
- `zoxide query -- "-l"` → empty (correct: `-l` treated as positional, no match)
- `zoxide query -- "--list"` → empty (correct)
- This affects the **default** (`auto`) backend because the non-empty dump short-circuits
  the rupa/z fallback in `resolve()`'s auto dispatcher.

### F3. The test fixtures cannot catch this regression
- All 6 fake-zoxide fixtures do a blind `shift` + `case "$1"`. They treat every argument
  (including `-l`) as a plain keyword, returning empty. They never model list mode.
- Subtest A of `test_backend_matrix.sh` uses real zoxide but only queries normal tokens
  (`tmux`, `config`, `nvim`, etc.) — never a leading-dash query.
- The fixtures also lost their `--` stripping in the same commit, making them incompatible
  with a restored `--` guard.

### F4. The PRD's suggested defence-in-depth one-liner is non-POSIX
```sh
[ -n "$resolved" ] && [ -z "${resolved##*$'\n'*}" ] || { [ -d "$resolved" ] && dir="$resolved"; }
```
Problems: (1) `$'\n'` is a bash/ksh bashism, not POSIX; (2) the boolean logic is inverted
and confusing. Use `case "$resolved" in *"$NL"*)` with a literal newline variable instead.

### F5. tmux `%%` substitution is raw text with no escaping
- The user's typed text replaces `%%` verbatim, then tmux's lexer parses the result.
- Wrapping `%%` in double quotes (`\"%%\"`) makes single quotes and spaces survive both
  tmux's lexer and `sh -c`. This is the minimal fix for Issue 2.
- Full robustness would require bypassing `%%` entirely (out of scope).

### F6. Test suite baseline: 80 pass / 0 fail across 9 files
- No Makefile. Each test: `sh tests/test_*.sh`.
- ShellCheck clean (only SC1091 info for sourced files).

## Risks & mitigations

### R1. CRITICAL: `--` guard and fixture hardening are coupled
- **Risk:** Restoring `zoxide query -- "$1"` changes the fake zoxide's argv from
  `query <kw>` to `query -- <kw>`. Every fake must strip `--` or existing `proj`-match
  tests silently break (fake sees `--` as keyword, returns empty).
- **Mitigation:** Harden fixtures FIRST (S1), then restore the guard (S2). Both subtasks
  end with a green suite.

### R2. Fake zoxide list-mode modeling must distinguish pre/post `--`
- **Risk:** If the fake enters list mode for `-l` even after `--` stripping, the regression
  test `_resolve_zoxide "-l"` would get a multi-line dump instead of empty, making the test
  fail even WITH the fix.
- **Mitigation:** The fake must check `--` BEFORE checking for `-l`/`--list`. If `--` is
  present, consume it and treat everything after as positional (no flag parsing).

### R3. z-session.sh defence-in-depth is lower priority but required for symmetry
- **Risk:** Session names rarely contain leading dashes, so the guard seems unnecessary.
- **Mitigation:** Include it anyway — the resolver is shared and backend-pluggable. A future
  backend regression could return non-directory values. The guard is a 4-line idiom.

### R4. test_run_file.sh C3 assertion must change for Issue 2
- **Risk:** The binding changes from `...z-window.sh %%'` to `...z-window.sh \"%%\"'`.
  The `contains` assertion checking for `%%` substring would still match, but the exact
  form check may fail.
- **Mitigation:** Update the assertion to check for the new quoting form.

### R5. test_resolve_dispatcher.sh fake exits 1 on no-match (CORRECTION B)
- **Risk:** The hardened fake must preserve this exit-1-on-no-match behavior for the `*`
  arm (it exercises the `return 0` in resolve()). Only the `--` stripping and `-l` list-mode
  arms are new.
- **Mitigation:** Keep exit 1 for `*` no-match; use exit 0 for list-mode (`-l`/`--list`
  is a successful list query in real zoxide, just one we don't want).

## POSIX constraints (carry from v1 build)

- All scripts are `#!/bin/sh` — no bashisms: no `local`, `[[ ]]`, `$'\n'`, arrays, `==` in `[ ]`, `echo -e`.
- ShellCheck must pass clean (excluding SC1091 info).
- No test framework (bats/shunit2) — dependency-free fake-binary-on-PATH mocks.
- `.gitignore` and `PRD.md` are read-only/forbidden.
