# Research: Resolver Backends (`zoxide`, `rupa/z`, `auto`)

> **Scope of this brief.** Validates the CLI/function interfaces the tmux plugin will shell out to:
> 1. `zoxide query <query>` (binary), 2. rupa/z `_z` (shell function), 3. `auto` fallback, 4. exit-status contract.
>
> **Confidence legend.** ✅ high-confidence (stable, version-independent behavior); ⚠️ version-sensitive / should be pinned-and-tested; ❓ could not be verified in this run (see *Gaps*).
>
> **Tooling caveat.** This run had **no `web_search` and no shell-execution tool** available, and the supervisor/intercom channels timed out. Findings are derived from the PRD-proposed patterns quoted in the task plus established knowledge of zoxide and rupa/z. Every claim that depends on a specific runtime/version is flagged ❓ or ⚠️ and lists an explicit empirical check. No commands were executed.

## Summary

`zoxide query -- "$q" 2>/dev/null` is the correct one-shot best-match resolver: it prints exactly one absolute path line on a match (exit 0) and prints nothing on stdout (exit 1, a `zoxide:` diagnostic on stderr) on a miss. rupa/z's `_z` is a **shell function** defined in `z.sh` (POSIX-`sh`-sourcable) that **silently `cd`s** to the best match on success and does not print the path — so the PRD's `…; _z "$q"; pwd` subshell pattern is directionally right, **but it has a no-match bug**: on a miss `_z` does not `cd`, so `pwd` echoes the *starting* directory rather than empty. The fix is a before/after `pwd` comparison (version-robust) or gating on `_z`'s exit status. The `auto` fallback (zoxide → rupa/z) is sound because the two use **completely separate databases** that can coexist. The "always exit 0; callers check output" contract is correct and sufficient **provided** each wrapper suppresses stderr, ignores backend exit codes via `|| true`, and guarantees empty output on a miss (which requires the rupa/z cwd-delta fix).

---

## 1. `zoxide query <query>`

### Binary & location
- **Binary name:** `zoxide` ✅. Single native binary written in Rust. Distributed via `brew`, `apt`/`dnf`, Arch `zoxide`, Nixpkgs, `cargo install zoxide`, and the official install script. Typical install locations: `/usr/bin/zoxide`, `/usr/local/bin/zoxide`, `~/.cargo/bin/zoxide`. Detect with `command -v zoxide >/dev/null 2>&1`. ✅
- **Database:** single shared binary DB at `$XDG_DATA_HOME/zoxide/db.zo` (default `~/.local/share/zoxide/db.zo`) ✅. Shared across all shells (not shell-specific).

### Correct one-shot subcommand
- `zoxide query [KEYWORDS]…` **without** `--list` is the correct "best match" resolver ✅. With keywords it prints the single best match; with **no** keywords it dumps the whole DB in frecency order (that is *not* what we want for one-shot resolution).
- `zoxide query --list` / `-l` → all matches (multi-line). Avoid for resolution. ✅
- `zoxide query --score <q>` → `"<score>\t<path>"`. Avoid (needs parsing).

### Output / exit code on MATCH
- Prints **exactly one line** to stdout: the full absolute path of the best-matching directory, newline-terminated. ✅
- Exit code **0**. ✅

### Output / exit code on NO match
- **Stdout:** nothing (empty). ✅
- **Exit code:** **1** ✅. This is a deliberate, documented contract — `zoxide query` returns 1 when no entry matches.
- **Stderr:** a diagnostic line, e.g. `zoxide: no match found` (exact text/wording is version- and locale-dependent; zoxide routes all diagnostics through its logger prefixed `zoxide:`) ⚠️. **Implication:** always redirect stderr (`2>/dev/null`) so the contract "empty stdout = miss" holds and no noise reaches the tmux UI.

### Relevant flags
- **`--exclude <PATH>`** ✅ — excludes a directory *and its children* from results. zoxide's own shell hooks call `zoxide query --exclude "$PWD" …` so `z <dir>` never resolves to the current directory. For the tmux resolver, whether to exclude the active session's cwd is a **product decision**; if wanted, pass `--exclude "$current_dir"`.
- **`--` separator** — strongly recommended: `zoxide query -- "$q"` so a query beginning with `-` (e.g. a dir literally named `-foo`) is not parsed as a flag. ✅ (zoxide uses clap, which honors `--`.)
- `-l/--list`, `--score` — see above; not for one-shot resolution.

### Empty-query behavior (`zoxide query ''`)
- ❓ **Version-sensitive — must be guarded.** With **zero** keywords, `zoxide query` is defined to list the whole DB (first line = global best match). With an **empty-string keyword** (`zoxide query ''`) behavior is not contractually guaranteed across versions: some builds ignore empty keywords (→ behaves like "no keywords" → returns global best match), others may treat it as a real (non-matching) keyword (→ exit 1). Either way the result is **not** a clean "miss". **Recommendation:** strip/validate the query *before* calling zoxide; treat empty/whitespace-only input as an explicit no-op (or "global best", but make it deliberate). Do **not** rely on `zoxide query ''` exit code.

### Recommended invocation form (zoxide)
```sh
out=$(zoxide query -- "$q" 2>/dev/null || true)
# out = one-line absolute path on match; empty on miss; exit always 0.
```

---

## 2. rupa/z `_z` function

### Structure
- rupa/z ships as **`z.sh`**, a POSIX-`sh`-compatible script that defines a **shell function** named `_z` — *not* a binary. ✅ It is activated by sourcing: `. /path/to/z.sh`. There is no `_z`/`z` on `$PATH` until the script is sourced.
- It self-installs a directory-recording hook on the shell's prompt/precmd/chpwd mechanism (`PROMPT_COMMAND` for bash, `precmd_functions` for zsh, the POSIX `cd` wrapper / `_z --add` for `sh`).
- **Database:** plain text at `$_Z_DATA` (default `~/.z`). Totally independent of zoxide's DB. ✅
- **Compatibility:** the docs explicitly support **sh, bash, zsh, and fish** ✅. The `_z` function body uses only POSIX tools (`awk`, `sort`, `sed`, `tail`, `grep`) plus `cd`, so `_z` itself works under plain `sh` (dash/ash/busybox).

### `_z` signature / behavior
- `_z [OPTIONS] [REGEX]` — by default it **`cd`s** to the best-matching directory (regex match against the stored paths). ✅
  - On a match: `cd "$best"` and prints **nothing** to stdout. ✅
  - On no match: does **not** change directory; emits a warning to stderr (e.g. `_z: no match found`); ⚠️ exit status of `_z` on no-match is **version-sensitive** (see GOTCHA below).
- Options relevant to resolution: `-l` list matches with scores (no `cd`); `-r` rank-only; `-t` recency-only; `-c` subdirs-of-cwd-only. ⚠️ Exact option letters are stable in the canonical rupa/z but forks (`z.sh` derivatives, `z.lua`, etc.) differ — only support the canonical rupa/z `z.sh`.

### Non-interactive resolution WITHOUT changing the caller's cwd
- The PRD's subshell pattern **correctly** isolates the `cd` to the subshell: `sh -c '. /path/z.sh; _z "$q"; pwd'` changes cwd only inside that `sh -c` process; the parent (tmux plugin) is unaffected. ✅
- **But the exact PRD form has a no-match bug** — see *GOTCHA A*.

### GOTCHA A — no-match prints the *starting* dir, not empty
- PRD-proposed: `sh -c '. /path/z.sh; _z "$query" >/dev/null 2>&1; pwd'`.
- On a **miss**, `_z` does **not** `cd`, so the subshell's cwd is unchanged and `pwd` echoes the **starting directory** (whatever the plugin's cwd was — typically the tmux server's cwd or `$HOME`). That is a **false positive**: non-empty output that is *not* a real match. ❌ This breaks the "empty output = miss" contract.
- **Does `_z` print the matched path to stdout?** No (default mode `cd`s silently). So capturing `_z`'s stdout directly yields empty on success — **wrong**; the `pwd`-after-`cd` idea is the correct *mechanism*, it just needs miss-handling.
- **Fix (preferred, version-robust): before/after `pwd` comparison.** Emit the path **only when `_z` actually changed the directory**:
  ```sh
  sh -c '
    . "$1" >/dev/null 2>&1 || exit 0
    before=$(pwd)
    _z "$2" >/dev/null 2>&1
    after=$(pwd)
    [ "$before" != "$after" ] && printf "%s\n" "$after"
  ' _ "$Z_SH_PATH" "$q" 2>/dev/null
  ```
  This is independent of `_z`'s exit code and of `_z -l`'s output format. ✅
- **Alternative fix:** gate on `_z`'s exit status — `if _z "$q" >/dev/null 2>&1; then pwd; fi`. ⚠️ Only valid if the pinned z.sh version returns non-zero on no-match (canonical rupa/z typically does, but forks/older copies vary). Prefer the cwd-delta form.

### GOTCHA B — sourcing `z.sh` emits shell-specific noise under `sh`
- Under plain `sh`, the hook auto-detection block may attempt bash/zsh-only builtins (`complete`, `compctl`, etc.) and print "command not found" warnings to **stderr**. ⚠️
- **Fix:** redirect stderr on the *source* step too: `. "$Z_SH_PATH" >/dev/null 2>&1`. The PRD form only redirected `_z`'s stderr, not the source's. ❌→✅

### GOTCHA C — don't rely on the shell's ambient `z`/`_z`
- Many users alias `z` to zoxide (`zoxide init` provides a `z` function) or have a stale/different `_z`. The plugin must **source the canonical rupa/z `z.sh` from an explicit configured path** (`$Z_SH_PATH`), never `command -v z`. ✅ (PRD already does this.)

### Empty-query behavior (`_z ''`)
- ❓ Not contractually defined. `_z` with no args prints usage/help to stderr; an empty-string argument likely matches everything (→ `_z ''` could `cd` to the global top-ranked dir) or produce a parse warning. **Guard** empty/whitespace input before calling.

### Recommended invocation form (rupa/z)
```sh
out=$(sh -c '
  . "$1" >/dev/null 2>&1 || exit 0
  before=$(pwd)
  _z "$2" >/dev/null 2>&1
  after=$(pwd)
  [ "$before" != "$after" ] && printf "%s\n" "$after"
' _ "$Z_SH_PATH" "$q" 2>/dev/null || true)
```
(`$Z_SH_PATH` is a plugin option/env var pointing at the user's `z.sh`; default discovery: `$HOME/z.sh`, `$HOME/.z.sh`, `$XDG_CONFIG_HOME/z/z.sh`, Homebrew `share/z.sh`.)

---

## 3. The `auto` fallback

### Separate databases can coexist ✅
- zoxide DB: `~/.local/share/zoxide/db.zo` (binary). rupa/z DB: `~/.z` (text, override via `$_Z_DATA`). No shared state, no schema overlap, no conflict. A machine can run both simultaneously; users migrating rupa/z → zoxide commonly have both populated for a while.

### "zoxide first, then rupa/z if empty" is sound ✅
- zoxide installed + has the match → use it (fast native binary, single process). ✅
- zoxide installed but DB empty / cold / lacks the entry → `zoxide query` exits 1, empty stdout → fall back to rupa/z. ✅ This is the **real, common** case the fallback exists for: dirs that were only ever recorded by rupa/z (e.g. the user runs rupa/z in shells without a zoxide hook, or zoxide DB was reset).
- zoxide **not** installed → skip directly to rupa/z. ✅
- Deterministic priority is fine: when both would match, **zoxide's ranking wins** and rupa/z is never consulted. Document this; the two frecency formulas can disagree on "best" for the same query, but priority makes it deterministic. ⚠️ (non-bug, just a stated contract)

### Latency
- zoxide miss is one fast process. rupa/z runs only on a miss, adding one `sh -c` + source + `awk/sort/sed/tail` pipeline. Acceptable for an interactive resolver invoked on demand. ✅

### Recommended `auto` logic
```sh
resolve() {
  q="$1"
  [ -z "$(printf '%s' "$q" | tr -d '[:space:]')" ] && { return 0; }  # empty -> no-op
  if command -v zoxide >/dev/null 2>&1; then
    out=$(zoxide query -- "$q" 2>/dev/null || true)
    [ -n "$out" ] && { printf '%s\n' "$out"; return 0; }
  fi
  if [ -r "$Z_SH_PATH" ]; then
    out=$(sh -c '. "$1" >/dev/null 2>&1 || exit 0
                 b=$(pwd); _z "$2" >/dev/null 2>&1; a=$(pwd)
                 [ "$b" != "$a" ] && printf "%s\n" "$a"' \
              _ "$Z_SH_PATH" "$q" 2>/dev/null || true)
    [ -n "$out" ] && printf '%s\n' "$out"
  fi
  return 0   # always 0; emptiness signals miss
}
```

---

## 4. Exit-status contract

### "always exit 0; callers check output" — correct and sufficient ✅ (with two preconditions)
- **Why correct:** tmux plugins call resolvers via `run-shell` / `display-popup -E` / captured `sh -c`; a non-zero exit can abort `set -e` chains, surface as tmux errors, or confuse `$(...)`-based consumers. A stable exit-0 with an *emptiness* signal is the robust contract. ✅
- **Precondition 1 — ignore backend exit codes explicitly.** zoxide returns **1** on miss and the shell returns 127 on a missing binary; rupa/z's `_z` may return non-zero on miss. The wrapper must convert all of these to exit 0. Use `|| true` on every capture and end every path with `return 0`/`exit 0`. ✅
- **Precondition 2 — guarantee empty output on miss.** This is **automatically true for zoxide** (empty stdout + `2>/dev/null`), but **NOT true for the naive rupa/z `pwd` pattern** (GOTCHA A) — which is why the cwd-delta form is mandatory. ⚠️ Without it, a miss returns the starting dir as a false match and breaks the contract.
- **Sufficiency:** once both preconditions hold, "output empty ⇔ no match" is a sound, complete signal and callers need not inspect `$?`. ✅

### Wrapper invariants to enforce
1. Suppress all stderr (`2>/dev/null`) at both source and backend call sites.
2. `|| true` (or equivalent) on every backend capture.
3. Exactly one line of output (the absolute path) on success; zero lines on miss.
4. Validate/strip the query *before* dispatch (empty/whitespace → no-op → exit 0).
5. End every code path with `return 0`.

---

## RISKS & GOTCHAS (consolidated)

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| A | rupa/z `_z` no-match echoes the **starting dir** via naive `…; pwd`, creating a false positive | **High** | Use before/after `pwd` comparison (emit path only if cwd changed). |
| B | Sourcing `z.sh` under `sh` prints shell-hook warnings to stderr | Medium | Redirect stderr on the **source** step too (`. "$Z_SH_PATH" >/dev/null 2>&1`). |
| C | Ambient `z`/`_z` may be aliased to zoxide or a fork | Medium | Source canonical rupa/z `z.sh` from an explicit configured path. |
| D | `zoxide query ''` / `_z ''` empty-query behavior undefined | Medium | Strip/validate query first; treat empty as explicit no-op. |
| E | zoxide miss writes `zoxide: no match found` to stderr | Low | `2>/dev/null` everywhere. |
| F | Missing binary (zoxide) → exit 127 | Medium | `command -v` gate + `|| true`. |
| G | zoxide vs rupa/z ranking disagreement | Low | Deterministic priority (zoxide wins); document it. |
| H | `_z` exit-code-on-miss is version-sensitive | Medium | Don't rely on it; use cwd-delta instead. |
| I | Forks (`z.lua`, `z.sh` variants) differ in `_z` options/output | Low | Support only canonical rupa/z; require its `z.sh` path. |

### Exact recommended invocation forms

**zoxide (one-shot best match, exit-0 contract):**
```sh
out=$(zoxide query -- "$q" 2>/dev/null || true)
```
→ `out` = one absolute path line on match; empty on miss; exit always 0.

**rupa/z (one-shot best match, exit-0 contract, miss-safe):**
```sh
out=$(sh -c '
  . "$1" >/dev/null 2>&1 || exit 0
  before=$(pwd); _z "$2" >/dev/null 2>&1; after=$(pwd)
  [ "$before" != "$after" ] && printf "%s\n" "$after"
' _ "$Z_SH_PATH" "$q" 2>/dev/null || true)
```
→ `out` = the matched absolute path on a real `cd`; empty on miss; exit always 0.

**`auto` (zoxide → rupa/z):** see §3 snippet.

---

## Gaps (could not be verified in this run — no web/shell tooling)
1. ❓ Exact wording of zoxide's stderr no-match diagnostic (version/locale-dependent). Mitigated by `2>/dev/null`; not needed for correctness.
2. ❓ `_z` exit status on no-match for the *specific* z.sh the user has. Mitigated by the cwd-delta form (do not depend on it).
3. ❓ Behavior of `zoxide query ''` and `_z ''` on the installed versions. Mitigated by pre-validating the query.
4. ❓ Whether `--exclude` on the installed zoxide excludes children (yes in current releases; verify if a pinned old version).
5. ❓ No PRD/architecture source file was found in the repo (paths `prd.md`, `architecture.md`, `plan.md`, `spec.md`, `design.md` under the plan dir did not exist) — only the task-quoted PRD snippets were available. Confirm against the canonical PRD if it exists elsewhere.

### Suggested next steps (empirical verification)
- On a target machine, capture:
  - `zoxide query foo; echo "rc=$?"; zoxide query __nomatch__; echo "rc=$?"` (with stdout/stderr separated).
  - `zoxide query '' ; echo "rc=$?"` and `zoxide query -- '' ; echo "rc=$?"`.
  - `sh -c '. ./z.sh 2>err; _z realdir 1>out 2>err; echo rc=$?; cat out err'` and the same for a non-matching dir.
  - `sh -c '. ./z.sh 2>/dev/null; _z __nomatch__; echo "rc=$?"'` to confirm exit-status contract.
- Pin the supported zoxide version and rupa/z `z.sh` revision in the plugin README, and assert the above in a small shell test.

## Sources
- Kept (knowledge base, no live fetch possible in this run):
  - **ajeetdsouza/zoxide** — `query` subcommand semantics: best-match by default, `--list`, `--score`, `--exclude <PATH>`, exit 1 on no match, diagnostics to stderr prefixed `zoxide:`; binary DB at `$XDG_DATA_HOME/zoxide/db.zo`. (https://github.com/ajeetdsouza/zoxide — `man`/`--help` text.)
  - **rupa/z** (`z.sh`) — defines the `_z` shell function (not a binary); POSIX-`sh`/bash/zsh/fish compatible; `_z <regex>` `cd`s to best match (silent on success), `_z -l` lists with scores; DB at `$_Z_DATA` (default `~/.z`); options `-c -r -t -l -h`. (https://github.com/rupa/z.)
- Dropped: none (no live sources were fetchable this run; nothing redundant was encountered).

## Supervisor coordination
- Attempted `contact_supervisor` (reason `need_decision`) and `intercom` `ask` to (a) locate the PRD and (b) confirm whether web access/shell could be provided given only `read`/`write`/`contact_supervisor`/`intercom` tools were present. **Both timed out with no reply.** Proceeded with research-only approach (PRD snippets quoted in-task + established backend knowledge), with all unverifiable claims explicitly flagged ❓/⚠️ and empirical checks listed.
