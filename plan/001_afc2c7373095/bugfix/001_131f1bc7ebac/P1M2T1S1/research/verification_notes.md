# Verification Notes — P1.M2.T1.S1 (Issue 2: double-quote `%%` in the binding)

> Empirically validated in **isolated `/tmp/qf_clean/` mirror** of the repo (repo untouched).
> tmux 3.6b, bash 5, `/bin/sh`. The run file fix + the test_run_file.sh C3/C4 needle update
> were applied via the `edit`/`write` tools and run: **`test_run_file.sh` → pass=9 fail=0,
> 10/10 stable (0 flakes); full suite → pass=90 fail=0**.

## 0. HEADLINE — the contract's specified fix (Fix A) is BROKEN; ship Fix A-alt instead

The item contract (LOGIC #3) and `architecture/research_issue2_quoting.md` (Fix A) both specify
wrapping `%%` in **double quotes INSIDE the existing OUTER SINGLE quotes**:

```bash
"run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"
```

**This does NOT fix the reported apostrophe case** — it makes it *worse*. Empirically, an `o'brien`
query through this form makes **tmux return 2 (error)** and `z-window.sh` is **never reached**
(`<no log>`). Reason: the contract's trace (step 2: "tmux lex (outer `'…'`) → passes `\"o'brien\"`
through") is **incorrect**. tmux's command lexer follows POSIX single-quote semantics — a `'` inside
a single-quoted token **closes the token**, and there is **no escaping inside single quotes**. So
the `'` in `o'brien` terminates the outer `'…'` at the tmux layer, *before* the inner `"…"` (or the
shell layer) can protect it. The inner double quotes are inert for apostrophes.

### The correct minimal fix: OUTER DOUBLE quotes (Fix A-alt)

tmux's double quotes treat `'` as a **literal** character (POSIX). So the whole `run-shell` argument
must be wrapped in **tmux double quotes** (with the inner `%%` quotes escaped):

```bash
"run-shell \"$CURRENT_DIR/scripts/z-window.sh \\\"%%\\\"\""
```

`bash` evaluates this to the tmux template `run-shell "/abs/z-window.sh \"%%\""`. Verified.

## 1. Empirical proof (probe via `source-file` of the post-`%%`-substitution command — the faithful
       reproduction of tmux's lexer, used by both the research note and the PRD bug report)

`source-file` of the exact post-substitution line exercises the SAME tmux command lexer that
`command-prompt` uses after `%%` substitution (research_note §Gaps confirms `%%` is raw text, no
escaping; both go through `cmd_parse`). Probe script logged `argc`/`$1`/`$*`:

| Query | bare `o'brien` (current) | **Fix A** (contract) `\"o'brien\"` inside `'…'` | **Fix A-alt** `\"o'brien\"` inside `"…"` |
|---|---|---|---|
| `o'brien` | rc=0, `$1=obrien` (apostrophe **stripped** — broken) | **rc=2** (tmux error; z-window **not reached**) | rc=0, **`$1=o'brien`** ✅ FIXED |
| empty `""` | — | rc=0, `$1=` (empty) ✅ | rc=0, `$1=` (empty) ✅ |
| `my proj` | — | rc=0, `$1=my proj` ✅ | rc=0, `$1=my proj` ✅ |
| `a;b` | — | rc=0, `$1=a;b` ✅ (metachar protected) | rc=0, `$1=a;b` ✅ |
| `proj` | — | rc=0, `$1=proj` ✅ | rc=0, `$1=proj` ✅ |

**Conclusion:** Fix A-alt matches the research note's *intended* coverage table (apostrophe, spaces,
`;`/`&`/`|` protected; residual `$`/`` ` ``/`\` sh-expanded — vanishingly rare in dir names) **and
actually fixes apostrophes**, which Fix A does not. Fix A-alt is strictly better and is the minimal
correct fix.

## 2. Why Fix A-alt and not Fix B?

Fix B (`read </dev/tty` or `display-popup -E`, collecting input on the shell side) is the *fully*
robust option (arbitrary `$`/`"`/`` ` ``/`\`) but: raises the change size (new prompt script or
`-E` flow), and `display-popup` raises the minimum tmux to 3.2 (PRD §6.3 requires 3.0+). The reported
bug is the apostrophe + spaces, which Fix A-alt fully resolves with a **one-line** change preserving
the status-line `command-prompt` UX. Out of scope for a 1-point subtask.

## 3. The `list-keys` escaping + why C3/C4 use the abs-path needle

After Fix A-alt, `tmux list-keys -1 -T prefix g` returns (tmux display-escapes the inner/outer
quotes):

```
bind-key -T prefix g command-prompt -p "z to:" "run-shell \"/abs/z-window.sh \\\"%%\\\"\""
```

The escaping around `%%` is `\\\"%%\\\"` (heavily backslashed, version-dependent). An assertion keyed
on that exact byte sequence is **fragile across tmux versions**. The robust substring is the
**abs path** `$REPO_ROOT/scripts/z-window.sh`, which tmux emits **unescaped** (verified: grep -F
matches). So C3/C4 assert the abs path is in the binding (the stable structural signal). The
`%%`-wrapping / quoting correctness is verified **behaviourally** by **P1.M2.T1.S2** (the single-
quote query regression test) — the appropriate layer, since list-keys escaping is not a behaviour.

Needle candidates tested against the real haystack (`grep -F`):

| needle | matches? |
|---|---|
| `run-shell "$REPO_ROOT/scripts/z-window.sh \"%%\""` (no backslash — contract's style) | ❌ miss |
| `$REPO_ROOT/scripts/z-window.sh` (abs path, unescaped) | ✅ MATCH (robust) |
| `%%` (literal token) | ✅ MATCH |

## 4. BOTH C3 AND C4 must be updated (contract only said C3)

The contract names only C3, but **C4 uses the identical old needle**
(`run-shell '$REPO_ROOT/scripts/z-window.sh %%'`) and **also fails** after the fix. Both are updated
to the abs-path needle. Verified: with only C3 updated, C4 fails (pass=8 fail=1); with both, pass=9.

## 5. Exact edits (validated, minimal diff)

**`tmux-zoxide-sessions.tmux` line 18** (one line; bash `bash -n` clean):
```diff
-    "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
+    "run-shell \"$CURRENT_DIR/scripts/z-window.sh \\\"%%\\\"\""
```
(Evaluated template = `run-shell "/abs/z-window.sh \"%%\""` — outer double quotes, inner escaped.)

**`tests/test_run_file.sh`** — C3 (with explanatory comment) + C4 needles → the abs-path substring:
```diff
-contains "C3: abs path to z-window.sh + %% kept" "$b" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
+# C3 needle: the abs path is the STABLE, unescaped substring of list-keys output (tmux's
+# quote-escaping around %% is version-fragile). The %%-wrapping / quoting is verified
+# BEHAVIOURALLY by P1.M2.T1.S2 (single-quote query regression test).
+contains "C3: abs path to z-window.sh in binding" "$b" "$REPO_ROOT/scripts/z-window.sh"
...
-contains "C4: binding on custom key 'Z'" "$bz" "run-shell '$REPO_ROOT/scripts/z-window.sh %%'"
+contains "C4: binding on custom key 'Z' targets z-window.sh" "$bz" "$REPO_ROOT/scripts/z-window.sh"
```

## 6. Validated results (clean mirror `/tmp/qf_clean/`, repo untouched)

```
$ bash -n tmux-zoxide-sessions.tmux && echo OK     # OK
$ sh -n tests/test_run_file.sh && echo OK          # OK
$ sh tests/test_run_file.sh                        # 10/10 runs: RESULTS: pass=9 fail=0, exit 0
$ <full suite>                                     # TOTAL: pass=90 fail=0 (all 9 files)
```

Per-file (clean mirror): backend_matrix 12, resolve_dispatcher 14, resolve_get_tmux_option 6,
resolve_zoxide 3, resolve_z 5, **run_file 9**, session_hook 11, z_session 13, z_window 17.

## 7. Composition with the parallel task (P1.M1.T3.S2) + downstream

- P1.M1.T3.S2 (implementing in parallel) adds `-l`/multiline cases to `test_z_window.sh` /
  `test_z_session.sh` and does NOT touch `test_run_file.sh` or the run file → **no conflict**.
- P1.M2.T1.S2 (next) adds the single-quote query regression test — it now has a fix that actually
  works (Fix A-alt) to assert against; if the contract's Fix A had been shipped, S2 would fail.
- The fix only changes the **window binding** (line 18); the session hook (line 30,
  `run-shell -b '...z-session.sh "#{session_name}"'`) is **unchanged** — its `#{session_name}`
  quoting is a separate concern (research_note Fix C, out of scope).
