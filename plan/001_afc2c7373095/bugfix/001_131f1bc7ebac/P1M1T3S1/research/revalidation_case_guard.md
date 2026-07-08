# Re-validation against the `case`-guard resolver (Attempt 2 prep)

> Live re-validation run 2026-07-08. Supersedes the mechanism-specific claims in
> `dependency_probe.md` (which assumed the `--` guard) after the Attempt-1 halt.

## 1. Why the previous attempt halted

Attempt 1 (see `issue_feedback.md`) halted at its Level-0a gate because the PRP
defined a **mechanism-specific hard prerequisite** — "`scripts/lib/resolve.sh`
must call `zoxide query -- "$1"`" — and the code deliberately does NOT. That
prerequisite was inherited from `research_issue1_defense.md` §A, which predates
the resolution of the P1.M1.T1.S2 environment conflict (T1.S2's own
`issue_feedback.md` documents that this machine's on-PATH `zoxide` IS the
rupa/z shim, which breaks on `--`).

## 2. What the resolver ACTUALLY does now (verified live at HEAD)

`scripts/lib/resolve.sh`, `_resolve_zoxide`:

```sh
_resolve_zoxide() {
    [ -n "$1" ] || return 0
    case "$1" in -*) return 0 ;; esac          # <-- leading-dash REJECTION guard
    command -v zoxide >/dev/null 2>&1 && zoxide query "$1" 2>/dev/null
}
```

- A query beginning with `-` is **rejected before zoxide is ever invoked** →
  returns empty, exits 0. This is a DIFFERENT mechanism from the `--` guard but
  achieves the SAME contract outcome for `-l`/`--list`: empty resolution.
- The comment block (resolve.sh lines 12-23) documents this as a deliberate
  choice: rejecting leading-dash queries fixes the dump symptom for BOTH real
  zoxide AND the rupa/z shim, without breaking the shim (which `--` would).
- `P1.M1.T1.S2` is marked **Complete** in the task tree; this `case` guard IS
  the landed form of that task.

## 3. Corrected prerequisite framing (behavioral, not mechanism-specific)

The assertions in this task test **behavior** (`-l`/`--list` → empty), which is
satisfied by EITHER the `--` guard OR the `case`-rejection guard. The PRP must
therefore gate on the BEHAVIOR, not on a grep for `--`.

**Behavioral prerequisite probe (run live, PASSES):**

```sh
TBIN=$(mktemp -d)
cat > "$TBIN/zoxide" <<'Z'
#!/bin/sh
[ "$1" = "query" ] || exit 0
shift
if [ "$1" = "--" ]; then shift
else case "$1" in -l|--list) printf '%s\n' a b c; exit 0;; esac; fi
case "$1" in proj) printf '%s\n' /home/user/projects/proj;; *) printf '';; esac
Z
chmod +x "$TBIN/zoxide"
for q in -l --list proj; do
  out=$(sh -c '. "$0"; PATH="$1:$PATH"; _resolve_zoxide "$2"' scripts/lib/resolve.sh "$TBIN" "$q")
  printf '%-8s -> [%s]\n' "$q" "$out"
done
rm -rf "$TBIN"
# EXPECTED:  -l     -> []
#            --list -> []
#            proj   -> [/home/user/projects/proj]
```

Result (live): `-l` → empty, `--list` → empty, `proj` → path. **Prerequisite HOLDS.**

## 4. Assertion validation (the exact blocks the PRP specifies)

Each new `check` was appended to a temporary in-repo copy of the real test file
(hidden name `tests/.validate_*.sh`, deleted after) and run against the
unmodified production `resolve.sh`. **All pass:**

### `tests/test_resolve_zoxide.sh` — 3 checks → 6 (floor ≥5)

| check | expected | actual | result |
|-------|----------|--------|--------|
| `leading-dash -l resolves to empty`     | `""` | `[]`                  | PASS |
| `leading-dash --list resolves to empty` | `""` | `[]`                  | PASS |
| `fake models list-mode: query -l -> multi-line dump` | 3-line dump | 3-line dump | PASS |

`RESULTS: pass=6 fail=0`. (The case guard rejects `-l`/`--list` before zoxide is
called, so `withfake -l`/`--list` → empty. The fake's direct `query -l` still
dumps multi-line, proving list-mode is modeled — the justification for the guard.)

### `tests/test_resolve_dispatcher.sh` — 14 checks → 18 (floor ≥17)

| check | expected | actual | result |
|-------|----------|--------|--------|
| `zoxide: -l resolves empty` | `""` | `[]` | PASS |
| `exit 0: zoxide -l`         | `0`  | `0`  | PASS |
| `auto: -l resolves empty`   | `""` | `[]` | PASS |
| `exit 0: auto -l`           | `0`  | `0`  | PASS |

`RESULTS: pass=18 fail=0`. (`auto` correctly does NOT short-circuit: the case
guard makes `_resolve_zoxide -l` empty, so the `[ -z "$_r" ] && _r=$(_resolve_z …)`
fallback runs; `_resolve_z -l` is also a no-match in the `z.sh` fixture → empty.)

## 5. Full-suite baseline (non-regression target)

9/9 files green, **98 pass / 0 fail** at HEAD:

```
test_backend_matrix.sh          pass=12
test_resolve_dispatcher.sh      pass=14   -> 18 after this task
test_resolve_get_tmux_option.sh pass=6
test_resolve_zoxide.sh          pass=3    -> 6  after this task
test_resolve_z.sh               pass=5
test_run_file.sh                pass=11
test_session_hook.sh            pass=11
test_z_session.sh               pass=13
test_z_window.sh                pass=23
```

After this task: zoxide 6/0, dispatcher 18/0, **full suite 105 pass / 0 fail**.
(The counts are higher than the original 80-assertion baseline because prior
completed tasks — defence-in-depth, apostrophe, integration leading-dash —
already added their regression assertions.)

## 6. Conclusion for the PRP

- The prerequisite is **behavioral** and **holds** (resolver rejects leading-dash).
- All 7 new assertions are **empirically validated** to pass against current HEAD.
- The `withfake` / `rout` / `rexit` helpers and the hardened fakes are already in
  place (P1.M1.T1.S1 = Complete); no helper or fixture changes are needed.
- This task is **test-only**: append `check` lines to the two unit test files.
  No edits to `resolve.sh` (owned by T1.S2, already Complete) or integration
  tests (T3.S2, already Complete).
