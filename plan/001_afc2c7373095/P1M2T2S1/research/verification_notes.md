# Verification Notes — P1.M2.T2.S1 (`tmux-zoxide-sessions.tmux`, PART 1 only)

> Empirically validated in throwaway `/tmp/zxs_run_smoke*` sandboxes (repo untouched).
> Machine: tmux 3.6b, shellcheck 0.11.0, bash. Real `scripts/lib/resolve.sh` was copied
> into each sandbox so sourcing worked; `z-window.sh` was a stand-in copy of PRD §5.4
> (P1.M2.T1.S1's verbatim deliverable) for the window-open probe.

## 0. The shipped file = PRD §5.2 PART 1, verbatim

PART 1 = the shebang + the full PRD §5.2 header comment + `CURRENT_DIR` + `. resolve.sh`
+ the `# --- 1. Window-jump binding ---` block (through the `tmux bind-key … %%` line).
The `# --- 2. Session auto-relocate hook ---` block is **NOT** shipped here — it belongs
to P1.M3.T2.S1, which **APPENDS** it (item contract #4). PART 1 terminates cleanly after
the `bind-key` command + trailing newline, so the append produces the byte-for-byte PRD §5.2
file. The header comment is kept verbatim (it describes the *final* file); only PART 1's
*code* ships now.

## 1. ⚠️ GOTCHA: `list-keys` needs `-1` to query ONE key

- `tmux list-keys -T prefix g` → **`unknown key: g`** (it does NOT take a key arg; the
  bare `g` is rejected).
- `tmux list-keys -1 -T prefix g` → prints exactly the one binding for `g`
  (compact single-space form), e.g.
  `bind-key -T prefix g command-prompt -p "z to:" "run-shell '<abs>/scripts/z-window.sh %%'"`.
  (`-1` = "list one key".) If the key is unbound it still prints `unknown key: <key>`.
- Reliable full-table fallback: `tmux list-keys -T prefix | grep z-window`.

**Assertion strategy:** query `list-keys -1 -T prefix "$key"` and `grep -F` for the
expected substrings (`bind-key -T prefix <key>`, `command-prompt -p "<prompt>"`,
`run-shell '<REPO>/scripts/z-window.sh %%'`). This proves registration + key + prompt +
absolute path + `%%` in one shot.

## 2. `bind-key` (no `-T`) registers in the **prefix** table

Confirmed: after the run file ran `tmux bind-key "$key" …` (no `-T`), `list-keys -T prefix`
showed it. No `-n` (root) and no `-T` ⇒ prefix table ⇒ triggered by `prefix <key>`. Correct.

## 3. shellcheck gate — `shellcheck -x` is clean

- `shellcheck -x tmux-zoxide-sessions.tmux` → **rc=0, no output** (`-x` follows the sourced
  `resolve.sh`; SC1091 disappears because resolve.sh is present & readable).
- Without `-x`, the ONLY code emitted is **SC1091** (info, for the `. resolve.sh` line):
  `shellcheck <file> 2>&1 | grep -Eo 'SC[0-9]+' | sort -u` → `SC1091`.
- ⚠️ The P1.M2.T1.S1-style gate `shellcheck <file> 2>&1 | grep -v SC1091` is **NOT empty**
  on this shellcheck build: SC1091's message is multi-line ("In … line 10:", the source
  line, "For more information:"), and `grep -v SC1091` only strips the lines that literally
  contain `SC1091`, leaving the header/continuation lines. **Do not use `grep -v SC1091` as
  the "empty" gate.** Use `shellcheck -x` (rc 0) OR `grep -Eo 'SC[0-9]+' | sort -u` == SC1091.

## 4. ⚠️ GOTCHA: `tmux run-shell` inherits the SERVER's PATH — set fakes BEFORE boot

- CASE 3 "trigger the prompt path" runs `tmux -L <sock> run-shell "<abs>/z-window.sh proj"`
  (exactly what the binding dispatches after `%%`→`proj` substitution). z-window.sh then calls
  bare `tmux` and `resolve`→`zoxide`.
- **`run-shell` spawns with the tmux SERVER's environment, not the calling shell's.** The
  server captures PATH at **startup**. So: prepend the fake-`tmux` wrapper + fake-`zoxide`
  dir to PATH **before** `tmux -L <sock> new-session …` boots the server. Then `run-shell`'d
  children inherit the fakes and stay isolated. Verified: window opened named `proj` in
  `$FIX/proj` with the server PATH pre-set this way.
- If you set PATH *after* boot, `run-shell`'s children get the server's original PATH → bare
  `tmux` hits the user's **live** socket (bad) and `zoxide` is the real/absent one. Avoid.

## 5. Custom options override (verified)

Set on the isolated server, then execute the run file (via the fake wrapper):
```
tmux -L <sock> set -g @zoxide-sessions-key Z
tmux -L <sock> set -g @zoxide-sessions-prompt "jump to"
```
→ `list-keys -1 -T prefix Z` =
`bind-key -T prefix Z command-prompt -p "jump to" "run-shell '<abs>/scripts/z-window.sh %%'"`.
The defaults are honored when the options are unset (`get_tmux_option` → `show-option -gqv`
returns empty → default `'g'` / `'z to:'`).

## 6. PART 1-only regression guard

Grep the run file for PART-2 *code* tokens — they must be ABSENT (PART 1 ships no hook code):
`grep -Eq 'set-hook|z-session\.sh|@zoxide-sessions-auto-session' tmux-zoxide-sessions.tmux`
→ must print nothing. (The verbatim header comment mentions "session-created hook" in prose,
which is fine — the guard targets code tokens, not prose.)

## 7. Mocking harness summary (the established S1–S4 / P1.M2.T1.S1 idiom, extended)

- Isolated server: `tmux -L zxstest_run` (never the live socket).
- Fake `tmux` wrapper on PATH: `exec "$REAL_TMUX" -L zxstest_run "$@"` → every bare `tmux`
  call (run file's `bind-key`, resolve's `get_tmux_option`, z-window's `display-message`/
  `new-window`) lands on the isolated server.
- Fake `zoxide` on PATH: `proj` → a **real** `$FIX/proj` dir (mkdir it; a non-existent `-c`
  target makes the pane fall back to `$HOME` — P1.M2.T1.S1 finding §3); else empty + exit 0.
- `@zoxide-sessions-backend=zoxide` set ON the isolated server.
- The run file is **executed directly** (`"$RUN"`), exactly as TPM does
  (`$tmux_file >/dev/null 2>&1`) — not sourced.

## 8. Dependency on P1.M2.T1.S1

The binding stores `run-shell '<abs>/scripts/z-window.sh %%'`. `scripts/z-window.sh` is
P1.M2.T1.S1's deliverable (PRD §5.4 verbatim, `chmod +x`). It will exist by the time this
subtask's test runs (status: T1.S1 Implementing, T2.S1 Researching→Implementing). The test
**requires** `-x scripts/z-window.sh` for CASE 3 and fails clearly if absent (points to
P1.M2.T1.S1). CASES 1–2 (binding registration) do NOT need z-window.sh — they're pure
run-file/option assertions and validate even in isolation.
