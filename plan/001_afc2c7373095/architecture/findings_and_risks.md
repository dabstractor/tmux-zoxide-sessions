# Findings, Risks & Implementation Corrections — tmux-zoxide-sessions

> The PRD is the complete spec (§5 is verbatim source). This file records the **validated
> discrepancies** between the PRD's prose/code and reality, with the exact correction each
> implementing subtask MUST apply. Every finding below was confirmed empirically on this
> machine (tmux 3.6b + zoxide + rupa/z) or from primary plugin source. Raw briefs:
> `research_*.md`.

## ✅ Confirmed-correct PRD assumptions (no action needed)

1. **`session-created` hook timing** — empirically: fires after the session, its first
   window, and its first pane all exist. `display-message -t <session> -p '#{pane_id}'`
   returns the new session's active pane; `#{pane_current_path}` is readable. The
   z-session.sh guard chain is sound. (Test A: `name=[probeA] pane=[%1] path=[...]`.)
2. **`run-shell -b`** — non-blocking; tmux expands `#{...}` formats at dispatch time
   (before the async fork). No race reading the pane path.
3. **`respawn-pane -c <dir> -k`** — `-c` sets cwd, `-k` kills the old shell first;
   preserves window name + pane geometry; works on the sole pane. The flicker is the
   unavoidable restart (PRD §8).
4. **resurrect `-c "$saved_dir"` linchpin** — confirmed from `restore.sh` source
   (`external_deps.md` §3). The `$HOME`-guard safety model holds.
5. **`zoxide query`** — empirical: returns the best match as one absolute path line on
   match; **empty stdout + exit 0** on no-match (no stderr noise). The contract
   "callers check output, not status" is satisfied; `2>/dev/null` is still good hygiene.
6. **Window feature + spaces** — `%%` substitution is textual and splits on spaces, BUT
   `z-window.sh` does `query="$*"` which recombines them. Spaced queries work. (Residual:
   shell-metachar injection in typed input — acceptable for a personal tool; never `eval`
   the query.)
7. **POSIX sh posture** — `resolve.sh` is genuinely POSIX (no `local`/`[[ ]]`/arrays).
8. **`get_tmux_option`** + TPM run-file/executable-bit conventions — confirmed.

---

## 🔴 CORRECTION A (REQUIRED): rupa/z `_z` returns a false positive on no-match

**Affected subtask:** `P1.M1.T2.S3` (`_resolve_z`).

### The bug
PRD §5.3 `_resolve_z`:
```sh
"$shell" -c '. "$1"; _z "$2" >/dev/null 2>&1; pwd' _ "$z_sh" "$1"
```
rupa/z's `_z` **silently `cd`s on a match** and **leaves cwd unchanged on no-match**.
So on a no-match, `pwd` prints the **subshell's starting directory** — a non-empty,
wrong path. Empirically (this machine):

| Query | PRD form output | Correct |
|---|---|---|
| `zzz_nomatch_xyz` | `/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions` ❌ | *(empty)* |
| `tmux` | `/home/dustin/.config/tmux` ✓ | `/home/dustin/.config/tmux` |

A false-positive means `resolve()` (in `z` and `auto`-fallback paths) returns a bogus
dir → `respawn-pane -c <bogus>` (session) or `new-window -c <bogus>` (window).

### The validated fix (before/after `pwd` delta + always exit 0)
Emit a path **only when `_z` actually changed cwd**; always exit 0 to honor the
documented contract ("resolve always exits 0"):
```sh
_resolve_z() {
    z_sh=$(tmux show-option -gqv "@zoxide-sessions-z-sh" 2>/dev/null || true)
    [ -n "$z_sh" ] && [ -r "$z_sh" ] || return 0
    shell=sh; command -v zsh >/dev/null 2>&1 && shell=zsh
    # rupa/z _z silently cd's on match and is a no-op on miss. Compare before/after
    # cwd so we emit a path ONLY on a real match; always exit 0 (callers check output).
    "$shell" -c '. "$1" 2>/dev/null || exit 0; o=$(pwd); _z "$2" 2>/dev/null; n=$(pwd); [ "$o" != "$n" ] && printf "%s\n" "$n"; exit 0' \
        _ "$z_sh" "$1" 2>/dev/null
}
```
Empirically validated: no-match → empty (exit 0); match → correct path (exit 0).

> Note: by default `@zoxide-sessions-z-sh` is **unset**, so `_resolve_z` short-circuits to
> `return 0` and this bug is dormant. It only activates when a user points at a real
> `z.sh`. Still: ship the fix — it is the documented contract and the `auto` fallback
> depends on it.

---

## 🟡 CORRECTION B (REQUIRED): `resolve()` must enforce "always exit 0"

**Affected subtask:** `P1.M1.T2.S4` (`resolve` dispatcher).

The PRD comment states `resolve()` "Always exits 0 — callers must check the output, not
the exit status," but the code does not enforce it for the `zoxide`/`z` branches (the last
executed statement is the backend call, whose status propagates). zoxide exit code on
no-match varies by version; the `_z` fix above intentionally exits 0, but for defense in
depth across backends/versions, end `resolve()` with an unconditional `return 0`:
```sh
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
Callers (`z-session.sh`: `resolved=$(resolve "$name") || exit 0`; `z-window.sh`: checks
output only) are already robust to a non-zero status, but matching the documented contract
prevents future regressions.

---

## 🟡 NOTE C (DOCS, not code): `set-hook -g` overwrites — does not literally "compose"

**Affected subtasks:** `P1.M3.T2.S1` (hook wiring) + `P1.M4.T1.S1`/`P1.M4.T3.S1` (README).

Empirically (isolated tmux server): `set-hook -g session-created "X"` then `set-hook -g
session-created "Y"` → `show-hooks` shows **only Y**. So the PRD's `set-hook -g`
**overwrites** any pre-existing global `session-created` hook. `set-hook -ag` appends
(both fire) but would **duplicate on every TPM reload**.

**Decision:** KEEP the PRD's `set-hook -g`. Reload-idempotency (no duplicate hooks across
`prefix r` / TPM re-source) is the more important property for a plugin. The cost is that a
global `session-created` hook set in `.tmux.conf` *before* the TPM init line is replaced by
the plugin's. This contradicts the literal wording of PRD §6.2 ("A user's own
session-created hooks — compose fine").

**Action (documentation only):** in README, clarify the composition story: the plugin's
hook is reload-safe; to combine with custom `session-created` logic, the user should set
their hook *after* TPM init and have it also invoke the plugin's `z-session.sh`, OR use
`set-hook -ag` manually. Reflect this in the "Scope & compatibility" section. Do NOT change
the run-file mechanism.

---

## ⚪ NOTE D (minor robustness): `zoxide query -- "$q"`

Optional hardening in `_resolve_zoxide`: `zoxide query -- "$1"` (the `--` guards a query
that looks like a flag). The PRD's `zoxide query "$1"` is fine for normal queries; add `--`
only if cheap. Not required for acceptance.

---

## Risk register (residual, documented in PRD §8)

- **Relocate flicker** — inherent to `respawn-pane -k`; unavoidable (PRD §8). Accept.
- **`skip-names` whitespace-separated** — entries can't contain spaces (PRD §8). Accept.
- **`home-dir` is a single dir, not a list** (PRD §8). Accept.
- **`readlink -f` is GNU** — on systems without it, symlinked `$HOME` may not canonicalize;
  the `_norm` fallback (`|| printf '%s' "$1"`) keeps trailing-slash normalization working
  (PRD §8). Accept.
- **Degenerate case:** a restored session whose saved pane cwd *was* `$HOME` gets relocated
  (false positive). Arguably desirable; document in README known-limitations.
