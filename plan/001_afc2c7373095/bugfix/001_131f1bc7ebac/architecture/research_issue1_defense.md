# Issue 1 — Defence-in-Depth Brief: zoxide Flag Absorption (`-l` / `--list`)

Scout brief for the bugfix that restores the `--` end-of-options guard in
`_resolve_zoxide` and hardens the two callers (`z-window.sh`, `z-session.sh`)
plus the six fake-zoxide test fixtures. Scope is **Issue 1 only**; Issue 2
(single-quote in query) is out of scope and tracked separately.

This document is research/architecture only. It does **not** modify source.
Line numbers are pinned to commit `720f1f3` (HEAD of `main`).

---

## A. Exact current state of `_resolve_zoxide` — the missing `--` guard

File: `scripts/lib/resolve.sh`, lines **11–20**.

```sh
11  # _resolve_zoxide <query> -> dir from `zoxide query`, or empty.
12  # Note: NO `--` end-of-options guard. PRD §5.3 calls `zoxide query "$1`".
13  # The `--` guard breaks the rupa/z-backed zoxide shim (which does not parse
14  # `--` and treats it as part of the query), making BOTH features silently
15  # no-op against the plugin's primary support target. zoxide already rejects
16  # a query that begins with `-` safely (empty output + exit 0), which is not a
17  # realistic user query, so the guard buys nothing while breaking the shim.
18  _resolve_zoxide() {
19      command -v zoxide >/dev/null 2>&1 && zoxide query "$1" 2>/dev/null
20  }
```

### What is wrong

1. **Missing `--` guard (line 19).** The call is `zoxide query "$1"` with no
   end-of-options terminator. For `$1 == -l` / `$1 == --list`, real zoxide
   enters **list mode** and prints the **entire frecency database** (observed
   146–147 lines). That dump becomes the "resolved" directory.
   - Direct proof (real zoxide 0.9.x):
     ```sh
     zoxide query  "-l"     | wc -l   # -> 146+  (list-mode DB dump)  [BUG]
     zoxide query "--list"  | wc -l   # -> 146+  (list-mode DB dump)  [BUG]
     zoxide query -- "-l"             # -> empty                    [the fix]
     zoxide query -- "--list"         # -> empty                    [the fix]
     ```

2. **The comment block (lines 11–17) is factually false** on every load-bearing
   claim and must be deleted/rewritten, not kept:
   - Line 16 claim: *"zoxide already rejects a query that begins with `-`
     safely (empty output + exit 0)"* — **disproven** by the `-l`/`--list`
     dump above (non-empty, many lines).
   - Lines 13–14 claim: *"`--` breaks the rupa/z-backed zoxide shim (which
     does not parse `--`)"* — there is **no rupa/z-backed zoxide shim** in the
     PRD's backend model. The three documented backends are: (a) real
     `zoxide`, (b) a user-installed `zoxide` *shim*, (c) rupa/z via
     `@zoxide-sessions-z-sh`. The thing that "fails on `--`" is the **test
     fixture** in `tests/test_z_window.sh` / `tests/test_backend_matrix.sh`,
     whose fake `zoxide` does a blind `shift` + `case "$1"` (see §D) — a test
     artifact, not a support target.
   - Lines 14–15 claim: *"`--` … making BOTH features silently no-op against
     the plugin's primary support target"* — backwards: real zoxide (the
     primary target) **honors** `--` exactly (proven above); only the
     hand-written fake does not.

### Regression history

- Contract **P1.M1.T2.S2 / NOTE D** required the `--` guard.
- Commit `eabce65`/`bb90152` **added** it (`zoxide query -- "$1"`).
- Commit **`b93e776` "Remove zoxide -- end-of-options guard and fix
  tautological test"** **removed** it, reverting to `zoxide query "$1"` and
  installing the false comment block above.

### Scope of impact (default backend)

- `auto` (the **default** backend) tries zoxide first; the non-empty dump
  short-circuits the rupa/z fallback in the `auto` dispatcher
  (`resolve.sh:44` — `[ -z "$_r" ] && _r=$(_resolve_z "$1")`), so the corrupt
  value ships to the caller. → **default backend affected**.
- `zoxide` backend affected.
- Only `z` backend (with no zoxide on PATH) is immune.

### The two-line fix (primary)

```sh
# _resolve_zoxide <query> -> single directory from `zoxide query`, or empty.
# `--` terminates zoxide options so a leading-dash query (e.g. `-l`, `--list`)
# is treated as a literal search term (real zoxide returns empty for those)
# rather than entering list-mode and dumping the entire frecency database.
_resolve_zoxide() {
    command -v zoxide >/dev/null 2>&1 && zoxide query -- "$1" 2>/dev/null
}
```

The caller-side guards in §B/§C are **defence in depth** and do not replace
this fix; the `--` guard is the contract-required root fix.

---

## B. `z-window.sh` — defence-in-depth guard design

File: `scripts/z-window.sh`. Current resolve/dir assignment logic (lines
**27–31**):

```sh
27  query="$*"
28
29  # Pull the current pane's directory and session from the live tmux server.
30  cur=$(tmux display-message -p '#{pane_current_path}' 2>/dev/null)
31  [ -z "$cur" ] && cur="$HOME"
32  session=$(tmux display-message -p '#{session_name}' 2>/dev/null)
33
34  dir="$cur"
35
36  if [ -n "$query" ]; then
37      resolved=$(resolve "$query")
38      [ -n "$resolved" ] && dir="$resolved"      # <-- NO validation
39  fi
40
41  base=$(basename "$dir")
42  tmux new-window -t "$session:" -c "$dir" -n "$base"
```

(Exact line offsets shift slightly between the source read and this excerpt;
anchor on `resolved=$(resolve "$query")` followed by `[ -n "$resolved" ] &&
dir="$resolved"`.)

### The defect

Line 38 accepts **any** non-empty `resolved` verbatim. If a future resolver
regression (or any backend) ever returns a multi-line value or a non-directory
string, `tmux new-window -c "$dir"` gets a corrupt path (Issue 1's exact
symptom: `pane_start_path` = the whole 146-line dump, window named after a
random last-line basename).

### Design — POSIX-compliant guard

Requirements (from task): (1) reject if `resolved` contains a newline
(multi-line dump), (2) accept only if `resolved` is an existing directory
(`-d`), (3) fall back to `$cur` if either check fails.

Constraints: the script is `#!/bin/sh` (dash/POSIX), so no bashisms. In
particular **avoid** `$'\n'` (bash/ksh) and `[[ ]]`. The PRD snapshot's
suggested one-liner —
`[ -n "$resolved" ] && [ -z "${resolved##*$'\n'*}" ] || { [ -d "$resolved" ] && dir="$resolved"; }`
— is **not acceptable**: it uses the `$'\n'` bashism *and* its boolean logic
is inverted/confusing. Do not copy it.

Recommended replacement for lines 36–39:

```sh
if [ -n "$query" ]; then
    resolved=$(resolve "$query")
    # Defence in depth: accept `resolved` ONLY if it is a single line that is
    # an existing directory. A multi-line value (e.g. a zoxide list-mode
    # database dump on `-l`/`--list`) or any non-directory falls back to the
    # current pane path ($cur). Pair with the `--` guard in resolve.sh.
    case "$resolved" in
        *"$NL"*) : ;;                  # multi-line -> reject, keep dir=$cur
        *)        [ -d "$resolved" ] && dir="$resolved" ;;
    esac
fi
```

with `NL` defined once near the top of the script (canonical POSIX newline
literal — a real newline between the quotes):

```sh
# Single newline, POSIX-portable (avoids the bash/ksh-only $'\n' form).
NL='
'
```

#### Why this idiom

- **`case "$resolved" in *"$NL"*`** is the standard POSIX idiom for
  "contains a newline". `"$NL"` holds a literal `\n` (a real newline between
  the two quote marks), so the glob `*<newline>*` matches any multi-line
  value. Fully portable to dash, busybox sh, ash, ksh, bash, zsh.
- **`[ -d "$resolved" ]`** is POSIX test for "exists and is a directory".
  Empty `resolved` correctly fails `-d` (and is also caught by the fallthrough
  `*)` arm only being meaningful when non-empty), so the empty/no-match case
  also keeps `dir=$cur`.
- **`&& dir="$resolved"`** is a one-line conditional assignment; if `-d`
  fails, `dir` is untouched and remains `$cur`. No `else`, no nested braces.
- The structure keeps the **3 checks explicit and ordered**: newline-reject
  → directory-test → fallback-to-`$cur` (which is the default already set on
  line 34, so "fallback" is "do nothing").

#### Net behavior

| `resolved` value             | newline? | `-d`? | result `dir` |
|------------------------------|----------|-------|--------------|
| `/home/user/projects/proj`   | no       | yes   | `resolved`   |
| (empty, no match)            | no       | no    | `$cur`       |
| multi-line DB dump (`-l`)    | **yes**  | —     | `$cur`       |
| `/nonexistent/path`          | no       | no    | `$cur`       |

`base=$(basename "$dir")` and `tmux new-window … -c "$dir" -n "$base"`
(lines 41–42) are unchanged and now always receive a single, existing path.

---

## C. `z-session.sh` — does it need the same guard?

**Yes.** Apply the same defence-in-depth, though the realistic attack surface
is smaller.

File: `scripts/z-session.sh`. The vulnerable sequence (lines **~49–55**):

```sh
# Resolve the name via the shared backend. Empty = no match -> nothing to do.
resolved=$(resolve "$name") || exit 0
[ -n "$resolved" ] || exit 0

# Relocate: restart the pane's shell in the resolved directory.
tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
```

`$name` is `#{session_name}` delivered by the `session-created` hook. A
leading-dash session name is uncommon (tmux permits `-l` as a session name),
so the *primary* trigger is weaker than for the window-jump path. **But** the
guard still belongs, for defence-in-depth and consistency:

1. `resolve()` is shared and backend-pluggable; any future backend/fixture
   regression could return a non-directory or multi-line value here too.
2. `tmux respawn-pane -c "$resolved"` with a 146-line dump is the same class
   of corruption as the window case (pane respawns in a bogus path, or tmux
   rejects it and the handler silently exits 0 — either way, wrong).
3. The contract is symmetric: the README/PRD promise "the resolver returns a
   single directory" should hold at both callers, not just one.

### Recommended guard (mirrors §B)

```sh
# Resolve the name via the shared backend. Empty = no match -> nothing to do.
resolved=$(resolve "$name") || exit 0
[ -n "$resolved" ] || exit 0

# Defence in depth: accept `resolved` ONLY if it is a single existing
# directory; otherwise no-op (pane stays where it is). See z-window.sh /
# resolve.sh `--` guard for the root fix.
case "$resolved" in
    *"$NL"*) exit 0 ;;                 # multi-line dump -> refuse to relocate
    *)       [ -d "$resolved" ] || exit 0 ;;
esac

# Relocate: restart the pane's shell in the resolved directory.
tmux respawn-pane -t "$pane" -c "$resolved" -k 2>/dev/null || exit 0
```

(`NL` literal defined once at the top of `z-session.sh`, same as §B. On
failure the handler `exit 0`s — consistent with its existing "nothing to do"
contract — rather than corrupting the pane.)

---

## D. ALL fake-zoxide test fixtures — current behaviour

Every fake-`zoxide` in the suite shares the **same two flaws**: (1) a blind
`shift` that ignores `--` (so if the resolver ever passes `--`, the fake
hands the wrong token to its `case`), and (2) `case "$1"` treating every
argument — including `-l`/`--list` — as a plain query string, so real
zoxide's list-mode flag parsing is **never modeled**. None model list-mode.

Confirmed there are **exactly 6** test files with a fake-zoxide binary
fixture (`cat > "$TBIN/zoxide"`):
`test_resolve_zoxide.sh`, `test_resolve_dispatcher.sh`, `test_z_window.sh`,
`test_run_file.sh`, `test_z_session.sh`, `test_backend_matrix.sh`.

(The other two tests that mention "zoxide" — `test_resolve_z.sh` and
`test_session_hook.sh` — have **no** fake-zoxide binary; they only fake
`tmux` / `z.sh`, so they are out of scope for this fix.)

### D1. `tests/test_resolve_zoxide.sh` — lines 12–24

```sh
cat > "$TBIN/zoxide" <<'ZOXIDE'
#!/bin/sh
# Fake zoxide implementing ONLY: zoxide query [--] <keyword>
[ "$1" = "query" ] || exit 0
shift
kw="$1"
case "$kw" in
    proj) printf '%s\n' "/home/user/projects/proj" ;;   # MATCH
    *)    printf '' ;;                                   # no-match -> empty stdout, exit 0
esac
exit 0
ZOXIDE
```
- Comment claims to implement `zoxide query [--] <keyword>` but the body does
  **one blind `shift`** after `query` and reads the next arg as `kw`. There is
  no `--` handling: if the caller passes `query -- proj`, `kw` becomes `--`
  and `case` falls through to `*` (empty). So a resolver that adds `--`
  **would break this fake** today (exactly the false "shim breaks" rationale
  in resolve.sh).
- No list-mode modeling: `query -l` → `kw=-l` → `*` → empty (not a DB dump).
- Tests 3 cases: match (`proj`), no-match (`zzz_nomatch`), missing-binary.

### D2. `tests/test_resolve_dispatcher.sh` — lines 54–66

```sh
cat > "$TBIN/zoxide" <<'ZOXIDE'
#!/bin/sh
# Fake zoxide implementing ONLY: zoxide query [--] <keyword>
[ "$1" = "query" ] || exit 0
shift
kw="$1"
case "$kw" in
    proj) printf '%s\n' "/home/user/projects/proj"; exit 0 ;;   # MATCH
    *)    printf ''; exit 1 ;;                                   # no-match: empty + NON-zero
esac
ZOXIDE
```
- Same blind-single-`shift` + `case` shape; no `--` handling.
- **No-match returns exit 1** (deliberately, to exercise CORRECTION B's
  trailing `return 0` in `resolve()`). This is the only fake with a non-zero
  no-match exit — the others exit 0.
- No list-mode modeling: `-l` → empty + exit 1.
- 14 cases: backend matrix `{zoxide,z,auto}` × {match,no-match} for both
  stdout and exit-0 contract, plus a "buggy form (no return 0) leaks
  non-zero" regression demonstration.

### D3. `tests/test_z_window.sh` — lines 43–54

```sh
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift        # no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)
case "$1" in
    proj) printf '%s\n' "$FIX/proj"; exit 0 ;;   # MATCH (real dir)
    *)    printf ''; exit 0 ;;                    # no-match: empty, exit 0
esac
ZOX
```
- Comment **explicitly** encodes the false rationale: *"no `--` guard: real
  zoxide/zoxide-shim do not strip it (would break the shim)"*. This is the
  fixture-level echo of the false `resolve.sh` comment (the comment that
  justified the `b93e776` regression). It must be rewritten when the fixture
  is hardened.
- Blind `shift` (drops `query`), no `--` stripping. `query -- proj` → `case`
  sees `--` → `*` → empty.
- No list-mode modeling: `-l` → empty.
- Integration test on isolated `tmux -L zxstest_window` server; 4 cases:
  empty query → cur; match `proj`; no-match `zzz`; spaced query recombine.

### D4. `tests/test_z_session.sh` — lines 49–61

```sh
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift        # no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)
case "$1" in
    proj)        printf '%s\n' "$FIX/proj"; exit 0 ;;     # MATCH (real dir)
    "two words") printf '%s\n' "$FIX/twowords"; exit 0 ;; # MATCH (spaced name; real dir)
    *)           printf ''; exit 0 ;;                     # no-match: empty, exit 0
esac
ZOX
```
- Identical blind-shift + case shape; same false "would break the shim"
  comment as D3.
- Adds a spaced-name match (`"two words"` → `$FIX/twowords`) to prove `$1`
  survives the hook's `run-shell '… "#{session_name}"'` dispatch intact.
- No `--` handling, no list-mode modeling.
- Integration test on isolated `tmux -L zxstest_session` server; 7 cases
  (relocate-fires, skip-list, no-match, not-`$HOME`, master-off,
  window-name=session, spaced name).

### D5. `tests/test_run_file.sh` — lines 45–56

```sh
cat > "$TBIN/zoxide" <<'ZOX'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift        # no '--' guard: real zoxide/zoxide-shim do not strip it (would break the shim)
case "$1" in
    proj) printf '%s\n' "$FIX/proj"; exit 0 ;;   # MATCH (real dir)
    *)    printf ''; exit 0 ;;                    # no-match: empty, exit 0
esac
ZOX
```
- Identical to D3 (same comment, same blind shift, same `proj`-only match).
- No `--` handling, no list-mode modeling.
- Tests the run-file binding registration (`g`/`z to:`/`%%`) on isolated
  `tmux -L zxstest_run` server, plus a trigger-path case that opens exactly
  one window at `$FIX/proj`.

### D6. `tests/test_backend_matrix.sh` (subtest B only) — lines 165–179

```sh
cat > "$TBIN/zoxide" <<ZOX
#!/bin/sh
[ "\$1" = "query" ] || exit 0
shift
case "\$1" in
    $TOKEN) printf '%s\n' "$FIX/$TOKEN"; exit 0 ;;
    *)      printf ''; exit 0 ;;
esac
ZOX
chmod +x "$TBIN/zoxide"
```
- Same blind-shift + case shape. `TOKEN=zxmatrix`, so `query zxmatrix` →
  `$FIX/zxmatrix` (real dir).
- Note: this heredoc is **unquoted** (`<<ZOX`, not `<<'ZOX'`), so `$TOKEN`
  and `$FIX/$TOKEN` expand at fixture-build time; `\$1` is escaped. The
  other 5 fakes use quoted heredocs. Behaviour is equivalent at runtime.
- No `--` handling, no list-mode modeling. Installed only for subtest B
  (fake zoxide), then `rm -f "$TBIN/zoxide"` so it does not leak into
  subtest A (real on-PATH zoxide) or C (rupa/z).
- **Subtest A uses the REAL zoxide** but only ever queries a probed
  *normal* token (`tmux config nvim …`); it never probes a leading-dash
  query, so the absorption path is unexercised even with real zoxide.

### Hardening plan for the fixtures (cross-cutting)

All six fakes need the same two changes so they model real zoxide and would
have caught Issue 1:

1. **Strip a leading `--`** (real zoxide honours `--` as end-of-options):
   after `shift` (consuming `query`), check for and consume a `--` token
   before reading the keyword. This makes the fakes compatible with the
   restored `zoxide query -- "$1"` call.
2. **Model list-mode** for `-l`/`--list`: when the (post-`--`) keyword is
   `-l` or `--list`, emit a **multi-line dump** (a handful of fixture lines
   with a trailing newline each) and exit 0 — mirroring real zoxide. This
   lets the caller-side guards in §B/§C be exercised end-to-end.

A hardened fake skeleton (shared shape — wire into each `cat > "$TBIN/zoxide"`):

```sh
#!/bin/sh
# Fake zoxide: models `query [--] <kw>` AND list-mode (-l/--list), like real zoxide.
[ "$1" = "query" ] || exit 0
shift
# Honour end-of-options like real zoxide (consume a leading `--`).
[ "$1" = "--" ] && shift
case "$1" in
    -l|--list)      # list-mode: dump the (fake) frecency database, multi-line
        printf '%s\n' "$FIX/proj" "$FIX/else" "$FIX/twowords" "$FIX/$TOKEN"
        exit 0 ;;
    proj)           printf '%s\n' "$FIX/proj"; exit 0 ;;
    *)              printf ''; exit 0 ;;   # no-match: empty, exit 0
esac
```

Then add a **regression case** to (at minimum) `test_z_window.sh` and
`test_z_session.sh`: query `-l` (or `--list`) and assert (a) the resolver /
`resolved` value is rejected (window/pane lands at `$cur` / `$HOME`, not a
corrupt path) and (b) the window name is `basename($cur)`, not a random DB
entry. The same assertion in `test_resolve_zoxide.sh` / unit-level should
confirm the `--` guard makes `_resolve_zoxide -l` return empty.

---

## Files to change (issue-1 scope, for the implementer)

| File | Change |
|------|--------|
| `scripts/lib/resolve.sh` | Restore `zoxide query -- "$1"` (line 19); delete/rewrite false comment block (lines 11–17). |
| `scripts/z-window.sh` | Add newline-reject + `-d` guard around `dir="$resolved"` (§B). |
| `scripts/z-session.sh` | Add the symmetric guard before `respawn-pane` (§C). |
| `tests/test_resolve_zoxide.sh` | Harden fake: strip `--`, model `-l`/`--list`; add `-l`→empty case. |
| `tests/test_resolve_dispatcher.sh` | Same hardening; add `-l`→empty case (per backend). |
| `tests/test_z_window.sh` | Same hardening; add `-l` regression (window falls back to cur). |
| `tests/test_run_file.sh` | Same hardening. |
| `tests/test_z_session.sh` | Same hardening; add `-l` regression (no relocate). |
| `tests/test_backend_matrix.sh` (subtest B) | Same hardening (token stays `zxmatrix`). |

Out of scope: Issue 2 (single-quote in query, binding-level quoting in
`tmux-zoxide-sessions.tmux`); `test_resolve_z.sh` and `test_session_hook.sh`
(no fake-zoxide fixture).

---

## Architecture / data flow (how the pieces connect)

```
tmux bind-key 'g'  ──command-prompt "z to:"──>  %% substituted
   │
   └─> run-shell '<repo>/scripts/z-window.sh <user-query>'   (production dispatch)

session-created hook ─> run-shell -b '<repo>/scripts/z-session.sh "#{session_name}"'

scripts/z-window.sh  ─┐
                      ├──> . scripts/lib/resolve.sh  ──>  resolve()  ──┐
scripts/z-session.sh ─┘                                                │
                                                                       ▼
                              backend = @zoxide-sessions-backend (default auto)
                              ┌──────────────────────────────────────────┐
                              │ zoxide  -> _resolve_zoxide()  ◄── THE GUARD GOES HERE (zoxide query -- "$1")
                              │ z       -> _resolve_z()                   │
                              │ auto    -> _resolve_zoxide(); empty? _resolve_z()  (dump short-circuits this)
                              └──────────────────────────────────────────┘
                                       │ single dir or empty
                                       ▼
                  caller-side guard (newline-reject + -d)  ◄── DEFENCE IN DEPTH (z-window.sh, z-session.sh)
                                       │
                                       ▼
                  tmux new-window -c "$dir"  /  tmux respawn-pane -c "$resolved"
```

- The `--` guard in `_resolve_zoxide` is the **root fix** (closes the
  contract violation and unblocks the `auto` fallback).
- The caller-side guards are **belt-and-braces** so a single point of
  regression can never again corrupt a window/pane.
- The fixture hardening is what makes both fixes **verifiable**: today the
  fakes treat `-l` as a no-op empty string, so no test can observe the
  absorption path or prove the guards fire.

---

## Start here

Open **`scripts/lib/resolve.sh`** first (lines 11–20). It is the smallest,
highest-leverage change — restore the `--` guard and rewrite the false
comment — and it is what every other file (callers + fixtures) keys off.
Then `scripts/z-window.sh` (§B) and `scripts/z-session.sh` (§C) for the
defence-in-depth guards, then the six fixtures in §D for verifiability.

---

## Constraints, risks, open questions

- **POSIX only.** Both caller scripts are `#!/bin/sh`. Do **not** use
  `$'\n'`, `[[ ]]`, or `=~`. The `case … in *"$NL"*` idiom (§B) is the
  portable newline test. Avoid the PRD snapshot's one-liner (bashism +
  inverted logic).
- **`--` and the fakes are coupled.** Restoring `zoxide query -- "$1"`
  changes the argv the fakes receive (`query -- <kw>`). Every fake must be
  hardened to strip `--` *in the same change*, or the existing `proj`
  matches in D3/D5/D6 will silently flip to no-match and break the suite.
  This is the most likely place for a rushed fix to regress.
- **Don't change the no-match exit contract.** `test_resolve_dispatcher.sh`
  (D2) deliberately returns exit 1 on no-match to exercise CORRECTION B's
  trailing `return 0` in `resolve()`. Keep that exit-1-on-no-match behaviour
  for the `*` arm; only the `-l`/`--list` and `--`-stripping arms are new.
- **`auto` fallback subtlety.** With the `--` guard, `_resolve_zoxide -l`
  returns empty, so the `auto` dispatcher's `[ -z "$_r" ] && _r=$(_resolve_z …)`
  (`resolve.sh:44`) will now correctly fall through to rupa/z for a `-l`
  query. That is the intended, correct behaviour — flag it in test notes.
- **`z-session.sh` attack surface is lower** (session names are rarely
  `-l`), but the guard still belongs for symmetry and future-proofing; do
  not skip it to "reduce scope" — it is the same 4-line idiom and is part
  of the defence-in-depth contract.
- **Subtest A of `test_backend_matrix.sh`** uses the real on-PATH zoxide
  but never probes a leading-dash token. Consider adding a leading-dash
  probe there (skip if the real index has nothing) — optional, lower
  priority than the six fixture hardenings.
- **No live zoxide/tmux needed for the unit fakes**; the integration tests
  (D3/D4/D5/D6) spin up isolated `tmux -L zxstest_*` servers and are
  self-contained.
