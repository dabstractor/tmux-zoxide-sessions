# Research Notes — P1.M1.T3.S2 (`-l` + multi-line INTEGRATION regression)

> Empirical findings (all run live, 2026-07-07, against the CURRENT repo state).
> Repo at this snapshot: resolver has **NO `--` guard** (P1.M1.T1.S2 still
> "Researching"); z-window.sh / z-session.sh **HAVE** the defence-in-depth
> guards (P1.M1.T2.S1/S2 = Complete); the 6 fake-zoxide fixtures ARE hardened
> (P1.M1.T1.S1 = Complete: strip `--`, model list-mode for `-l`/`--list`).

## 0. The headline: this task is NOT blocked by the absent resolver `--` guard

The sibling UNIT task (P1.M1.T3.S1) **HALTED** at its Level-0 prerequisite
gate (see its `issue_feedback.md`): it asserts `resolve("-l") == ""`, which is
only true when `scripts/lib/resolve.sh` calls `zoxide query -- "$1"`. The guard
is absent, so those unit assertions fail by design, and S1 was (correctly)
forbidden from editing resolve.sh.

**Integration tests are different.** They assert the *user-visible outcome* —
"a window/pane is NOT corrupted" — which is guaranteed by the **defence-in-depth
caller guards** (P1.M1.T2.S1 for windows, P1.M1.T2.S2 for sessions), both
**Complete and in place**. Those guards reject any multi-line / non-directory
`resolved` *regardless* of whether the resolver emits empty (with `--`) or a
multi-line dump (without `--`). Proven empirically below — every new case
passes in the CURRENT (guard-absent) state.

| query        | resolver state     | `resolve()` returns | caller guard action   | window/pane lands at | new case passes? |
|--------------|--------------------|---------------------|-----------------------|----------------------|------------------|
| `-l` (win)   | WITH `--` guard    | `""` (empty)        | empty → keep `$cur`   | `$cur`               | ✅               |
| `-l` (win)   | **WITHOUT** guard  | 3-line list dump    | newline arm → `$cur`  | `$cur`               | ✅ (verified)    |
| `multiline`  | WITH `--` guard    | 3-line dump         | newline arm → `$cur`  | `$cur`               | ✅               |
| `multiline`  | **WITHOUT** guard  | 3-line dump         | newline arm → `$cur`  | `$cur`               | ✅ (verified)    |
| `-l` (sess)  | WITH `--` guard    | `""`                | `[ -n ]` → exit 0     | `$FIX/home`          | ✅               |
| `-l` (sess)  | **WITHOUT** guard  | 3-line list dump    | newline arm → exit 0  | `$FIX/home`          | ✅ (verified)    |

So the PRP does **not** carry a hard prerequisite on P1.M1.T1.S2. It carries a
SOFT note: CASE 5/CASE `-l` documents the *intended* flow (resolver returns
empty) which only holds once S2 lands; until then the same assertions pass via
the defence-in-depth path. Either way the committed regression is correct and
green.

## 1. Window cases — verified live (probe `/tmp/probe_window.sh`)

Hardened fake (identical to the one committed in `tests/test_z_window.sh`) plus
an added `multiline)` arm. `resolve.sh` UNguarded (current).

```
[CASE5 -l]      delta=1 NAME=[<basename cur>] START=[<cur>]   # falls back to cur ✓
[CASE6 multiline] delta=1 NAME=[<basename cur>] START=[<cur>]  # falls back to cur ✓
```

- CASE 5 (`-l`): `query="$*"` captures `-l`; with no `--` guard the fake enters
  list-mode and returns a 3-line dump; z-window.sh's `case "$resolved" in *"$NL"*`
  rejects it → `dir` stays `$cur`. Window created in `$cur`, named `basename($cur)`.
- CASE 6 (`multiline`): a *normal positional* token whose fake arm prints 3 lines.
  Reaches the resolver independent of the `--` guard (the fake strips `--` either
  way, then matches the positional). The caller guard rejects the multi-line
  value → `$cur`. **This is the independent test of P1.M1.T2.S1** (it cannot be
  “rescued” by the `--` fix, because the dump comes from a non-leading-dash query).

## 2. tmux leading-dash SESSION — the two gotchas (verified)

### Gotcha A: you CANNOT `new-session -s -l`
`tmux new-session -d -s -- -l -c "$DIR"` → `command new-session: unknown flag -l`.
tmux parses a leading-dash token as a flag in every flag position tried:

| form | result |
|------|--------|
| `new-session -s -- -l`            | ❌ `unknown flag -l` |
| `new-session -s=-l`               | ❌ creates session named `=-l` (the `=` leaks) |
| `new-session --session-name=-l`   | ❌ `invalid flag --` |
| **`new-session -s tmpl` + `rename-session -t tmpl -- -l`** | ✅ **session literally named `-l`** |

The **rename trick** is the only reliable way: create under a placeholder name,
then `rename-session -t <placeholder> -- -l` — the `--` ends option parsing so
`-l` is taken as the positional new-name argument.

### Gotcha B: you CAN target a `-l` session with `-t -l` (form 1)
Once a session is named `-l`, tmux’s getopt **consumes** `-l` as the argument to
`-t` (it does not treat it as a flag once `-t` expects a value):

| form | result |
|------|--------|
| **`display-message -t -l -p '#{pane_id}'`** | ✅ `%1` (form 1 — THIS is what z-session.sh does) |
| `display-message -t -- -l`          | ❌ target becomes `--` → returns literal format (NOT found) |
| `display-message -t=-l`             | ❌ empty |
| `display-message -t '-l:0'`         | ✅ `%1` (session:window form) |

**Form 1 is exactly `z-session.sh`’s call**: `tmux display-message -t "$name"`
where `name=-l` → argv `display-message -t -l`. So the handler **does** reach
`resolved=$(resolve "$name")` for a `-l` session — the test exercises the real
resolve→guard path, it does not bail at pane lookup. (Confirmed: `$ZSESS -l`
runs, pane stays at `$FIX/home`, exit 0.)

The test’s `cwd_of()` helper (`display-message -t "$1" …`) called as `cwd_of -l`
produces the identical `display-message -t -l` argv → correct targeting.

### Gotcha C (minor): the anchor session MUST survive
`tests/test_z_session.sh` already boots an anchor session `zs` with `-f /dev/null`
and reuses it across cases via `boot()`. Killing the last session destroys the
server and drops every `set -g`. A `-l` session is a *second* session on that
server; the anchor `zs` stays alive. (Already how the file works — no change.)

## 3. Session cases — verified live (probe `/tmp/probe_final.sh`)

Hardened fake + added `multiline)` arm. `resolve.sh` UNguarded (current).

```
=== session '-l' case ===
pre  =[$FIX/home]   post =[$FIX/home]   ✅ (no relocate)
=== session 'multiline' case ===
pre  =[$FIX/home]   post =[$FIX/home]   ✅ (guard rejects multi-line)
```

- `-l` session: handler reaches resolve → (no `--` guard) 3-line dump →
  z-session.sh `*"$NL"*) exit 0` → no relocate. With the guard it would hit
  `[ -n "$resolved" ] || exit 0` first. Either way: pane stays at `$FIX/home`.
- `multiline` session: positional query → 3-line dump → guard `exit 0` → no
  relocate. Independent test of P1.M1.T2.S2.

## 4. Assertion counts (current baseline verified live)

| file | now | +new | after | contract floor | OK? |
|------|----:|-----:|------:|---------------:|-----|
| `tests/test_z_window.sh`  | 11 | +6 (C5×3, C6×3) | **17** | `>=15` | ✅ |
| `tests/test_z_session.sh` |  9 | +4 (C11×2, C12×2) | **13** | `>=12` | ✅ |

Window: C5 = delta(1)+NAME+START_PATH = 3; C6 = delta(1)+NAME+START_PATH = 3.
Session: each new case = pre(home)+post(home) = 2, matching CASE-1/CASE-7 style.

## 5. Fake edit mechanics (both files)

Both fakes are **quoted heredocs** (`<<'ZOX'`), so `$FIX` is written LITERALLY
and expands at RUNTIME via `export FIX` + PATH-fronting the fake bin. The new
`multiline)` arm must use the SAME literal-`$FIX` style:

```sh
    multiline) printf '%s\n' "$FIX/proj" "$FIX/other1" "$FIX/other2"; exit 0 ;;
```

- Window fake: add the arm in the positional `case "$1"` block, before `*)`.
  `$FIX/other1`/`$FIX/other2` need NOT exist (window test only `mkdir`s
  `$FIX/proj`) — the newline arm rejects the value before `-d` runs.
- Session fake: same. Session fixture only `mkdir`s `$FIX/home $FIX/else
  $FIX/proj $FIX/twowords`; `other1/2` need not exist.
- The list-mode arm already present for `-l`/`--list` is REUSED as the dump
  content for `multiline` — identical 3-line shape. (Deliberate: the dump’s
  exact content is irrelevant; only its multi-line-ness matters.)

## 6. Why the suite stays green / non-regressing

- The two new window cases (`-l`, `multiline`) only ADD assertions after CASE 4;
  they touch no existing case. `run_case`/`new_name`/`new_start` are reused
  verbatim. CUR is re-captured before each new case (as CASE 1/3/4 do).
- The two new session cases only ADD cases after CASE 9; they reuse `boot`,
  `cwd_of`, `$ZSESS` verbatim.
- No source file is modified. No fake behavior for existing tokens (`proj`,
  `"two words"`, `zzz`/`zzznope`) changes — the new `multiline)` arm is strictly
  additive.
- The full-suite total rises from 80 → 90 (window 11→17, session 9→13; +10).

## 7. Scope / forbidden

- MODIFY: `tests/test_z_window.sh`, `tests/test_z_session.sh` (test-only).
- DO NOT touch: `scripts/*` (resolve.sh / z-window.sh / z-session.sh owned by
  T1.S2 / T2.S1 / T2.S2 — all already done), `tmux-zoxide-sessions.tmux`
  (P1.M2), README (P1.M3), `.gitignore`, `PRD.md`, `tasks.json`, snapshots.
- The unit-test regression (P1.M1.T3.S1) is a SEPARATE item; do not add its
  assertions here.
