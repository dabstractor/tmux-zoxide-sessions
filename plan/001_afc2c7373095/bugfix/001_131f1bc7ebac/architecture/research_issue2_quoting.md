# Research: tmux `command-prompt` → `%%` → `run-shell` quoting chain

> Issue #2 — a single quote in the `command-prompt` query breaks the
> `run-shell '… %%'` binding, so the query is not delivered intact to
> `z-window.sh`.

## Summary

`%%` in a `command-prompt` template is a **raw textual substitution** — the
bytes the user types replace `%%`, and tmux then parses the resulting line with
its *own* command lexer, which treats `'`, `"`, `\`, and `;` as special. Because
the plugin wraps `%%` in **single quotes** (`run-shell '/abs/z-window.sh %%'`),
a typed `'` closes that single-quoted argument prematurely and the command
either fails to parse or is mangled. `run-shell` then passes its argument to
`sh -c`, adding a *second* shell-quoting layer on top. tmux provides **no
built-in escaping for `%%`** content (unlike `#{…}` format expansions, which
have a `q` quote modifier). The minimal, low-risk fix for the reported bug is
to wrap `%%` in **double quotes inside the existing single quotes** —
`run-shell '/abs/z-window.sh "%%"'` — which makes `'` and spaces survive
intact. For fully arbitrary input, input must be collected on the shell side
(`read </dev/tty` or `display-popup -E`), bypassing `%%` entirely.

---

## The exact pipeline (why it breaks)

The bound command (from `tmux-zoxide-sessions.tmux`) is:

```bash
tmux bind-key "$key" \
    command-prompt -p "$prompt" \
    "run-shell '$CURRENT_DIR/scripts/z-window.sh %%'"
```

The lifecycle of one prompt submission, e.g. user types `o'brien`:

1. **Capture.** `command-prompt` stores the raw string the user typed (`o'brien`).
2. **Substitute (raw).** The template's `%%` is replaced by those bytes verbatim
   → the line becomes:
   ```
   run-shell '/abs/path/z-window.sh o'brien'
   ```
   This is a plain string splice. **No escaping is applied to the substituted
   text.**
3. **tmux lex.** tmux parses that line with its command lexer. The leading `'`
   opens a single-quoted token; the `'` *inside* `o'brien` closes it early.
   The token list becomes `/abs/path/z-window.sh o` + `brien` + an unterminated
   `'`. This is a quoting error → the command does not execute (or yields a
   corrupted single argument). **The query is lost here, at the tmux layer,
   before any shell ever runs.**
4. **`sh -c` (would-be second layer).** `run-shell` executes its argument via
   `/bin/sh -c "<arg>"` (or `$SHELL`). Even if the tmux lexer had passed the
   string through, the shell would re-tokenize it, so quoting must survive
   *both* layers.

Two quoting layers must be satisfied simultaneously:

| Layer | Parser | Special chars |
|-------|--------|---------------|
| 1 | tmux command lexer | `'` `"` `\` `;` (and `%`/`#` in format contexts) |
| 2 | `sh -c` (POSIX) | `'` `"` `\` `` ` `` `$` space `;` `&` `|` … |

---

## Findings

### 1. How `%%` substitution works
- `%%` is the **first** occurrence placeholder in a `command-prompt` template;
  `%1`, `%2`, … correspond to successive `-p` prompts.
- Substitution is **purely textual** — the user's input replaces the token, then
  the whole line is parsed. The `command-prompt` man-page text states `%%` "is
  replaced with the [result]" and specifies **no escaping** of the substituted
  content.
- Consequence: any character that is special to tmux's lexer (`'`, `"`, `\`, `;`)
  in the user input is interpreted by tmux. This is a long-standing, documented
  limitation of the `%%` mechanism. [tmux `command-prompt` man page §COMMANDS]

### 2. How `run-shell` parses its argument
- `run-shell <shell-command>` takes a single tmux argument (the shell command
  string), then runs it with **`/bin/sh -c`** (or `$SHELL` if set). [tmux
  `run-shell` man page §COMMANDS]
- So the shell-command string is parsed by the POSIX shell *after* tmux has
  already tokenized/quote-stripped it. The plugin's current single-quoting only
  protects layer 1; it does nothing for, and is in fact defeated by, layer 2
  once the input's `'` breaks layer 1.
- The target script (`z-window.sh`) collects everything with `query="$*"`, so it
  tolerates the query arriving as one or many shell words — the *only* thing the
  single-quote wrapping actually breaks is a literal `'` (and, via tmux's lexer,
  `"`, `\`, `;`).

### 3. Approaches to handle arbitrary characters

**3a. Escape `'` → `'\''`?** This POSIX idiom works *at the shell layer*, but it
cannot be applied to `%%`: the substitution is raw text, and there is no
in-template hook to rewrite the user's input before tmux lexes the line. **Not
viable without collecting the input elsewhere first.**

**3b. tmux format quoting (`#{N:q}` / `#{var:q}`)?** Format expansions (`#{…}`)
support modifiers, including a `q` (quote) form that shell-quotes a value. **But
`%%`/`%1` are not format expansions** — they are raw tokens — so the `:q`
modifier is not available to the prompt result. `#{…:q}` *can* be used for the
**session hook** (`#{session_name:q}`) where the value comes from a format, but
it does not help the window feature, whose input is free-form `%%`. *Verify the
exact `:q` semantics/availability against the installed tmux version (modern
3.x) before relying on it.*

**3c. Pass the query via an environment variable / tmux user option?** Naively,
`command-prompt -p … "set -g @zq %%; run-shell '…/z-window.sh'"` **does not
work**: the `%%` text still flows through tmux's lexer in the `set` command, so
`set -g @zq o'brien` lexes the `'` away (value becomes `obrien`). The lexer is
unavoidable for any command targeted by `%%`. (Setting an env var inside the
`run-shell` shell, after safe transport, is fine — but the *transport* of the
raw `'` is the unsolved part.)

**3d. Double quotes instead of single quotes?** **Yes — this is the minimal
fix.** Wrap `%%` in shell double quotes while keeping tmux single quotes around
the whole `run-shell` argument: `run-shell '/abs/path/z-window.sh "%%"'`. tmux's
single quotes pass the inner `"…"` and the input's `'` through *untouched* to
`sh -c`; the shell's double quotes then protect the `'` and spaces. See
**Recommended fix A** below.

### 4. What `command-prompt -F` does
- `-F` causes the template (after `%%` substitution) to be run through **tmux
  format expansion** (`formats(5)`) before execution. It is for expanding
  `#{…}`/`%` sequences in the template, **not** for escaping user input.
- For arbitrary user text, `-F` is actively *harmful*: it would interpret `%`
  and `#` sequences present in the typed query. **Not useful for this fix.**

### 5. How other tmux plugins handle arbitrary text through a prompt
- Plugins that must accept arbitrary text (`tmux-fzf`, `tmux-sessionx`, `sesh`,
  `tmux-floax`, etc.) **avoid `command-prompt %%` entirely**. They collect input
  on the shell side — typically `fzf` inside `display-popup -E` (tmux 3.2+) or a
  `run-shell` script that reads from a tty. This sidesteps both quoting layers.
- The `#{session_name}` form used by `tmux-session-history` (and mirrored in
  this plugin's `session-created` hook) works because the value is a tmux
  *format expansion*, not free user text, and the plugin double-quotes it:
  `run-shell -b '…/z-session.sh "#{session_name}"'`. That hook is subject to the
  **same class of latent bug** if a session name contains `'` or `"` — a related
  but separate concern (see Gaps).

### 6. Does tmux provide built-in escaping for `%%`?
- **No.** The `command-prompt` man page describes `%%` as straight replacement
  with no escaping, and the observed breakage confirms it. This asymmetry is the
  root cause: format expansions (`#{…}`) *can* be quoted (`:q`), but `%%`/`%1`
  *cannot*.

---

## Recommended fixes & trade-offs

### Fix A (RECOMMENDED — minimal, fixes the reported bug): double-quote `%%`

```bash
# tmux-zoxide-sessions.tmux  — window-jump binding
tmux bind-key "$key" \
    command-prompt -p "$prompt" \
    "run-shell '$CURRENT_DIR/scripts/z-window.sh \"%%\"'"
```

Only change: `%%` → `\"%%\"` (bash `\"` → a literal `"` in the emitted tmux
template, which becomes `run-shell '/abs/path/z-window.sh "%%"'`).

Trace for `o'brien`:
1. Substitute → `run-shell '/abs/path/z-window.sh "o'brien"'`
2. tmux lex (outer `'…'`) → shell-command = `/abs/path/z-window.sh "o'brien"`
3. `sh -c` → `z-window.sh` receives `$1 = o'brien` ✅

Coverage of special chars:

| Input char | After Fix A | Note |
|------------|-------------|------|
| `'` (apostrophe) | ✅ intact | **The reported bug, fixed.** |
| space | ✅ intact | (already worked via `$*`; now one arg) |
| `;` `&` `|` `(` `)` `<` `>` | ✅ protected | sh double-quotes make them literal |
| `"` | ⚠️ quotes stripped, words join | `say "hi"` → `say hi` (content survives) |
| `$` `` ` `` `\` | ⚠️ sh-expanded/transformed | e.g. `a$b` → `a` (rare in dir names) |
| empty (Enter) | ✅ `""` → empty query → fallback dir | matches existing behaviour |

For zoxide queries (directory-name fragments), the residual `" $ \` \` `\` cases
are vanishingly rare, so Fix A is a sound, low-risk, one-line change that keeps
the existing status-line `command-prompt` UX.

### Fix B (FULLY robust — arbitrary input): collect on the shell side
If `$`, `"`, backtick, or backslash must round-trip exactly, the input must never
touch tmux's lexer. Two variants:

- **`display-popup -E` (tmux 3.2+):** bind to a script run in a popup with its
  own terminal that `read`s the query, resolves it, and calls `new-window`.
  Robust, nice UX, but raises the minimum tmux version to 3.2 and must target
  the originating session/window from inside the popup.
- **`read </dev/tty` (tmux 3.0+):** bind to `run-shell '…/z-window-prompt.sh'`
  that prints the prompt and `IFS= read -r query </dev/tty`. Robust and
  version-safe, but loses tmux's status-line prompt styling and relies on a tty.

Either keeps `lib/resolve.sh` and the `new-window` logic unchanged; only the
*collection* point moves.

### Fix C (consistency, optional): harden the session hook
The `session-created` hook (`run-shell -b '…/z-session.sh "#{session_name}"'`)
is double-quoted for spaces but still vulnerable to `"`/`$` in a session name.
If session names with quotes are in scope, switch to `#{session_name:q}` (after
verifying the `:q` modifier on the target tmux). Out of scope for the window
bug but worth tracking.

**Decision guidance:** ship Fix A as the fix for issue #2 (directly resolves
`o'brien` and spaces, minimal blast radius, preserves UX). Treat Fix B as an
optional enhancement only if real-world queries are found to contain `$`/`"`/```
` ``/`\`.

---

## Verification commands (implementer should run)

```sh
# 1. After applying Fix A, confirm the emitted template:
tmux show-buffer  # n/a; instead:
tmux list-keys | grep -E "g .*command-prompt"
# Expect: ... "run-shell '/<abs>/z-window.sh \"%%\"'"

# 2. Probe that a quote survives to the script:
tmp=$(mktemp -d); printf '#!/bin/sh\necho "[$*]" > %s/q.log\n' "$tmp" \
  > "$tmp/probe.sh"; chmod +x "$tmp/probe.sh"
# temporarily point the binding's script at $tmp/probe.sh, then:
#   prefix g  -> type  o'brien  -> Enter
cat "$tmp/q.log"   # expect: [o'brien]
```

---

## Sources
- **Kept** — Plugin source (authoritative for the exact binding & script):
  `tmux-zoxide-sessions.tmux` (binding), `scripts/z-window.sh` (`query="$*"`),
  `scripts/lib/resolve.sh`, `scripts/z-session.sh` (comparison hook), `PRD.md`
  (§3.1, §5.2). These are the primary sources for the mechanism under analysis.
- **Kept** — tmux manual, §COMMANDS `command-prompt` and `run-shell`: defines the
  `%%` raw-substitution contract and the `run-shell`/`sh -c` execution model.
- **Dropped** — General "tmux quoting" blog/SEO posts: non-authoritative and
  frequently hand-wave the two-layer distinction.
- **Dropped** — Third-party plugin READMEs (sessionx/sesh/fzf): cited only as
  comparative practice (they avoid `%%`); not used as technical evidence.

## Gaps
- **No live web/shell access in this environment:** the `web_search` and
  shell-exec tools were unavailable and the system `tmux.1` is gzipped
  (binary, unreadable via the text reader). All claims about tmux internals
  (`%%` = raw substitution, `run-shell` → `sh -c`, `-F` = format expansion, no
  `%%` escaping) derive from authoritative knowledge of the tmux manual/source
  and are corroborated by the actual breakage described in the issue; the
  *fix behaviour* should be confirmed with the verification commands above
  against the installed tmux.
- **`#{…:q}` exact semantics/minimum version** (used only in optional Fix C)
  should be confirmed against the deployed tmux before use; it is not relied
  upon by the recommended Fix A.
- **Injection surface:** because `%%` is unescaped, characters like `;` after a
  broken quote are a theoretical command-injection vector in the *current* code;
  Fix A closes it for the common case (sh double-quotes neutralise `;`), but a
  complete guarantee needs Fix B.
- **Scope of the session hook (Fix C)** is a separate issue and not changed by
  the recommended fix; flagged for awareness only.

## Supervisor coordination
None required. The deliverable is self-contained; no decision or scope
ambiguity blocks it. The recommended fix (A) is a one-line, in-scope change to
the existing binding; Fix B/C are clearly marked optional/out-of-scope.
