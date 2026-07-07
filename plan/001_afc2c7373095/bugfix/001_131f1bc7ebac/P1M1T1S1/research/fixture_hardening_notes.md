# Research Notes — P1.M1.T1.S1 (Harden 6 fake-zoxide fixtures)

## Baseline (verified live, commit 720f1f3)
`sh tests/test_*.sh` → **80 pass / 0 fail**, all 9 files exit 0:
| file | pass |
|---|---|
| test_backend_matrix.sh | 12 |
| test_resolve_dispatcher.sh | 14 |
| test_resolve_get_tmux_option.sh | 6 |
| test_resolve_zoxide.sh | 3 |
| test_resolve_z.sh | 5 |
| test_run_file.sh | 9 |
| test_session_hook.sh | 11 |
| test_z_session.sh | 9 |
| test_z_window.sh | 11 |
- No Makefile. Runner = `sh tests/test_*.sh`. ShellCheck 0.11.0 present; suite is ShellCheck-clean (only SC1091 info on sourced files).
- Current resolver call (the one these fakes must stay compatible with): `scripts/lib/resolve.sh:19` = `zoxide query "$1"` (NO `--`). The `--` guard is restored in the NEXT subtask S2, not here.

## Current state of all 6 fakes (confirmed verbatim in repo — matches arch §D1–D6)

| # | File | Heredoc | Match arm(s) | No-match arm | Comment to rewrite |
|---|------|---------|--------------|--------------|--------------------|
| D1 | test_resolve_zoxide.sh | `<<'ZOXIDE'` (quoted) | `proj) → /home/user/projects/proj` (no explicit exit; trailing `exit 0`) | `*) printf ''` (implicit exit 0) | header: `# Fake zoxide implementing ONLY: zoxide query [--] <keyword>` |
| D2 | test_resolve_dispatcher.sh | `<<'ZOXIDE'` (quoted) | `proj) → /home/user/projects/proj; exit 0` | `*) printf ''; exit 1` **EXIT 1** | same header comment |
| D3 | test_z_window.sh | `<<'ZOX'` (quoted) | `proj) → $FIX/proj; exit 0` | `*) printf ''; exit 0` | inline: `# no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)` |
| D4 | test_z_session.sh | `<<'ZOX'` (quoted) | `proj)→$FIX/proj; "two words")→$FIX/twowords; exit 0` | `*) printf ''; exit 0` | same inline false comment |
| D5 | test_run_file.sh | `<<'ZOX'` (quoted) | `proj) → $FIX/proj; exit 0` | `*) printf ''; exit 0` | same inline false comment |
| D6 | test_backend_matrix.sh (subtest B) | `<<ZOX` **UNQUOTED** (`\$1` escaped; `$TOKEN`,`$FIX/$TOKEN` build-time expand) | `$TOKEN) → $FIX/$TOKEN; exit 0` (TOKEN=zxmatrix) | `*) printf ''; exit 0` | header block above heredoc: `# No '--' handling: matches the real zoxide/zoxide-shim invocation form, which omits '--'.` |

Notes:
- D1/D2 use a `kw="$1"` var then `case "$kw"`; D3–D6 use `case "$1"` directly. Restructuring to `case "$1"` is fine; keep behavior identical.
- Quoted heredocs (`<<'ZOX'`/`<<'ZOXIDE'`) write `$FIX` LITERALLY into the fake; `$FIX` expands at RUNTIME because the test does `export FIX` (and PATH-fronts the fake bin). Must preserve literal `$FIX` in these.
- D6 unquoted heredoc expands `$FIX`/`$TOKEN` at BUILD time and keeps `\$1` escaped — preserve that style exactly.

## CRITICAL: R2 ordering — `--` must be checked BEFORE `-l`/`--list`

findings_and_risks.md §R2: if the fake enters list mode for `-l` even after `--` is stripped, the regression test `_resolve_zoxide "-l"` (post-S2) would get a multi-line dump instead of empty → test fails even WITH the fix.

**The task description's template uses an `if/else` that is R2-correct** (`--` present → consume + SKIP list-mode entirely; else → check list-mode).

⚠️ **The architecture §D "hardened fake skeleton" is BUGGY per R2**: it does `[ "$1" = "--" ] && shift` and then a SINGLE `case "$1" in -l|--list) ...; proj) ...; *) ...`. With input `query -- -l` that skeleton consumes `--`, then `$1=-l` re-enters the unified `case` → `-l|--list)` matches → prints a dump. That is wrong. **Do NOT copy the §D skeleton. Use the task's if/else form.** This is the single most likely implementation trap.

## Why the suite stays 80/80 after S1 (the no-op property)
The resolver still calls `zoxide query "$1"` (no `--`) until S2. So every existing `proj` query is argv `query proj` → `shift` → `$1=proj` → `[ "$1" = "--" ]`? no → else → `case -l|--list`? no → positional `case` → `proj` matches. No existing test queries `-l`/`--list`, so the new list-mode arm is dead code for current assertions. → strictly additive, 80/80 preserved.

## Per-file list-mode dump content (must be MULTI-LINE, ≥2 lines, non-empty)
Content is arbitrary (it models a corrupt dump the caller-side guards in T2 will reject); only requirement is multi-line. Suggested:
- D1/D2 (unit, literal paths): `printf '%s\n' "/home/user/projects/proj" "/home/user/projects/other1" "/home/user/projects/other2"`
- D3/D4/D5 (quoted heredoc, `$FIX` literal): `printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"`
- D6 (unquoted heredoc, build-time expand): `printf '%s\n' "$FIX/$TOKEN" "$FIX/extra1" "$FIX/extra2"` (keep `$FIX`/`$TOKEN` UNescaped; `\$1` escaped)

## Out of scope (do NOT touch)
- test_resolve_z.sh, test_session_hook.sh (no fake-zoxide fixture — confirmed).
- scripts/lib/resolve.sh, scripts/z-window.sh, scripts/z-session.sh (owned by S2 / T2).
- Any new regression test assertions (owned by T3 = P1.M1.T3.S1/S2). S1 only hardens fixtures.
- Issue 2 (single-quote query), README, .gitignore, PRD.md.
