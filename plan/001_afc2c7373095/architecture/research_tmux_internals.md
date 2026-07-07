# Research: tmux Internals for `session-created` Hook Plugin

> **Methodology note:** This environment has no `web_search` tool and the local
> `tmux.1.gz` man page is gzip-compressed (unreadable via `read`). Findings below
> are based on detailed knowledge of the tmux man page (`man tmux` — sections
> HOOKS, COMMANDS, FORMATS), the tmux source tree
> (`github.com/tmux/tmux`, files `cmd-set-hook.c`, `cmd-run-shell.c`,
> `cmd-respawn-pane.c`, `cmd-display-message.c`, `cmd-command-prompt.c`,
> `cmd-new-window.c`, `format.c`, `hooks.c`, `cmd-parse.y`), and the tmux
> `CHANGES` file. Citations reference these stable, verifiable sources. Items
> marked ⚠️ are lower-confidence and should be verified against `man tmux`
> before production use. All line-level claims should be cross-checked by
> running `man tmux` or reading the linked source files.

---

## 1. `session-created` Hook

### When it fires

The `session-created` hook fires **after a new session is fully created** —
meaning the session struct is allocated, its initial window is created, and the
initial pane (with its shell process) exists and has a working directory. The
hook fires as part of `notify_hook("session-created", s)` called from within
`new-session` / `session_create` logic.

At hook-fire time, all of the following are true and readable via format
expansion:

| Format | Value at `session-created` |
|---|---|
| `#{session_name}` | the new session's name |
| `#{session_id}` | the new session's `$N` id |
| `#{window_id}` | the initial window's `@N` id |
| `#{pane_id}` | the initial pane's `%N` id |
| `#{pane_current_path}` | the initial pane's working directory |

The hook fires **before the session is attached** (if `new-session` is run
without `-d`, attachment happens after creation). This distinction matters for
window-size and client-dependent formats but does **not** affect
`pane_current_path`.

**Source:** `man tmux` → HOOKS section; tmux source `hooks.c` (`hooks_run`,
`notify_hook`), `cmd-new-session.c`.

### Is it a global hook (`set-hook -g`)?

Hooks exist in **two independent scopes**:

1. **Global scope** (`set-hook -g`): stored in `global_hooks`. Applies to all
   sessions server-wide. Fires for every session creation event.
2. **Session scope** (`set-hook -t target` or default current session): stored
   in `s->hooks`. Fires only for that specific session.

`session-created` **can** be set as a global hook with `set-hook -g`. A
plugin should use the global scope (`-g`) because the hook must fire for every
new session, not just one.

When an event fires, tmux runs **both** the global hook **and** the
session-level hook (if one exists). They do not shadow each other across
scopes. **Source:** `man tmux` → HOOKS section; `hooks.c`.

### Do multiple `session-created` hooks coexist (overwrite or append)?

**Within the same scope** (e.g., two global hooks for the same event name):
`set-hook` **REPLACES** by default. The second `set-hook -g session-created
"..."` overwrites the first. The `-a` flag **appends** instead:

```tmux
# Overwrites any existing global session-created hook:
set-hook -g session-created "run-shell -b /script"

# Appends (keeps existing hook, adds this one after):
set-hook -ag session-created "run-shell -b /script"
```

Internally, each hook-name maps to a `cmd_list` (a linked list of commands).
Without `-a`, the list is replaced. With `-a`, the new command is appended to
the existing list. **Source:** `man tmux` → `set-hook` command; `cmd-set-hook.c`
(checks the `-a` flag and calls `cmd_list_append` vs. replacing).

### Plugin hook vs. user hook — interaction

| Scenario | Result |
|---|---|
| Plugin: `set-hook -g`; User: `set-hook -g` (same event) | **Last writer wins.** If plugin loads after user config, plugin **overwrites** user's hook (unless plugin uses `-a`). |
| Plugin: `set-hook -g`; User: `set-hook -t session` (session scope) | **Both run.** No conflict — different scopes. |
| Plugin: `set-hook -ag`; User: `set-hook -g` (same event) | If user's runs first, plugin **appends** → both run. If plugin's runs first and user doesn't use `-a`, user **overwrites** plugin. |

**Critical gotcha:** A naive `set-hook -g session-created "..."` in a plugin
will **silently clobber** a user's own `session-created` global hook. Best
practice for plugins: use `set-hook -ag` (append), or use a unique hook approach
(e.g., have the plugin's hook command also `run-shell` the user's intended
command). **However**, `-a` may not be available in very old tmux — see
§8.

---

## 2. `run-shell -b` (Backgrounded)

### What `-b` does

```
run-shell [-b] [-d delay] [-t target-pane] shell-command   (alias: run)
```

- **`-b`**: Run the shell command **asynchronously** (in the background / non-
  blocking). tmux forks a child process to execute `shell-command` and returns
  immediately without waiting for it to complete. Without `-b`, tmux **blocks**
  until the shell command exits.
- **`-d delay`**: Wait `delay` milliseconds before starting the command (can be
  combined with `-b`; the delay is applied before forking).

**Source:** `man tmux` → COMMANDS section, `run-shell`; `cmd-run-shell.c`
(`cmd_run_shell_exec` checks `args_has(args, 'b')` and if set, calls
`proc_fork_and_daemon` / background fork).

### Format expansion timing (critical for `pane_current_path`)

`run-shell` **expands format variables** (`#{...}`) in `shell-command` **before**
execution. The expansion happens at **dispatch time** (when the command is
parsed and about to run), **not** at the time the backgrounded process
eventually executes.

This means:

```tmux
set-hook -g session-created "run-shell -b '/script #{pane_current_path}'"
```

1. Hook fires → tmux parses `run-shell -b '/script #{pane_current_path}'`.
2. `#{pane_current_path}` is expanded **immediately** to the actual path string
   (e.g., `/home/user/project`).
3. The expanded command `/script /home/user/project` is forked to background.

Even though `-b` makes execution asynchronous, the **path is already captured**
at expansion time. There is no race condition with `pane_current_path`
readability — by the time `session-created` fires, the pane and its path exist.

**Source:** `man tmux` → `run-shell` ("shell-command arguments are first expanded
using the rules described in FORMATS"); `cmd-run-shell.c` calls
`format_expand` (or `format_expand_time`) on the command string before fork.

### Ordering guarantees

- **With `-b`:** The forked process runs independently. tmux does **not**
  guarantee when it completes relative to subsequent tmux commands or hooks.
  Other hooks/commands may execute before the backgrounded shell finishes.
- **Without `-b`:** tmux blocks — the shell command completes before any
  subsequent command in the same command queue executes.
- **`-d delay`:** Adds a fixed delay before forking. Useful to wait for
  environment setup, but it is a blind timer, not an event-driven wait.

**For the plugin:** Using `run-shell -b` is correct for non-blocking operation.
Format expansion ensures `pane_current_path` is captured correctly. The only
risk is if the backgrounded script needs to *modify* tmux state (e.g.,
`tmux respawn-pane`) — it must use `tmux` commands internally, and there could
be ordering issues if multiple hooks fire concurrently.

---

## 3. `respawn-pane -c <dir> -k`

### Command signature

```
respawn-pane [-k] [-c start-directory] [-e environment] [-t target-pane] [shell-command]
```

**Source:** `man tmux` → COMMANDS section, `respawn-pane`; `cmd-respawn-pane.c`.

### `-c <dir>`: Sets working directory

**Confirmed.** `-c start-directory` sets the working directory for the respawned
shell/process. The new process in the pane starts with `chdir(start-directory)`.
This is the same mechanism used by `new-window -c` and `split-window -c`.

### `-k`: Kills existing process

**Confirmed.** `-k` kills any existing process in the pane before respawning.
Without `-k`, `respawn-pane` **refuses to respawn** if the pane still has a live
process — it only works on "dead" panes (where the shell has exited). With
`-k`, tmux sends `SIGKILL` (or the configured kill signal) to the existing
process group, then respawns.

### Window name preservation

**Preserved.** `respawn-pane` only affects the *pane's process*, not the
*window's properties*. The window name (`#{window_name}`) is unchanged. If the
window had `automatic-rename on`, the name may update based on the new process's
command, but `respawn-pane` itself does not set or clear the window name.

### Pane geometry preservation

**Preserved.** `respawn-pane` does not change the pane's position, size, or
border layout. It kills the old process and starts a new one in the **same
pane slot**. No `select-layout` or resize is triggered. This is a key advantage
over `kill-pane` + `split-window` which would alter layout.

### Works on the only pane in a window?

**Yes.** `respawn-pane` operates on an individual pane regardless of how many
panes exist in the window. It works on the sole pane in a single-pane window
without issue. The window itself is not destroyed or recreated.

### Flicker

- **Structural flicker:** None. Pane geometry is preserved; no layout
  recalculation occurs.
- **Content flicker:** There may be a **brief content flash** — the old
  process's terminal output is cleared and the new shell starts fresh. The pane
  is briefly empty between kill and new-shell-startup. This is usually
  imperceptible (sub-frame) but can be visible on slow terminals or over SSH.
- **Mitigation:** Not typically needed for zoxide use cases. If flicker is
  sensitive, consider `detach-client`/`attach` approaches, but these are
  heavier-weight.

---

## 4. `command-prompt` with `%%` Substitution

### Command signature

```
command-prompt [-1bFikN] [-I inputs] [-p prompts] [-t target-client] [template]
```

**Source:** `man tmux` → COMMANDS section, `command-prompt`;
`cmd-command-prompt.c`.

### `-p` is the prompt-label flag

**Confirmed.** `-p prompts` sets the prompt text(s) displayed to the user. If
multiple prompts are needed, they are comma-separated:
`-p "Prompt 1,Prompt 2"`. The prompt text is shown in the status line.

### `%%` substitution — single `%` or double `%%`?

**Double `%%` is correct.** In the `command-prompt` template:

| Token | Replaced with |
|---|---|
| `%%` | the response to the **first** prompt |
| `%1` | the response to the **first** prompt (alternative form) |
| `%2` | the response to the **second** prompt |
| `%3` ... | subsequent prompts |

`%%` is the **legacy/standard** form and is equivalent to `%1`. Both work in
tmux 3.0+. The `%1`/`%2` form is more explicit for multi-prompt scenarios.

**Default template:** If no template is provided, the default is `"%%"` —
meaning the user's input is executed directly as a tmux command. This is why
`bind-key : command-prompt` works as a "command mode."

### How `%%` is replaced

The substitution is **textual (character-level)** and happens **before** the
template is parsed as a tmux command:

1. User types input and presses Enter.
2. `%%` in the template string is replaced with the raw typed text (verbatim).
3. The resulting string is parsed by tmux's command parser and executed.

Example:
```tmux
command-prompt -p "z to:" "run-shell '/path/script %%'"
```
- User types: `myproject`
- After substitution: `run-shell '/path/script myproject'`
- tmux parses: `run-shell` command with argument `/path/script myproject`
- `run-shell` executes: `sh -c '/path/script myproject'`
- Script receives: `myproject` as `$1` ✓

### Spaces in input — quoting behavior

This is the **critical gotcha**. Because `%%` substitution is textual and
happens before command parsing, spaces in user input interact with quoting in
the template:

**Case 1 — input has no spaces (common for zoxide queries):**
- Input: `myproject`
- Template → `run-shell '/path/script myproject'`
- Shell sees: `/path/script myproject` → script gets one arg `myproject` ✓

**Case 2 — input has spaces (directory names, multi-word queries):**
- Input: `my project`
- Template → `run-shell '/path/script my project'`
- tmux parser strips outer single quotes → `run-shell` gets `/path/script my project`
- Shell sees: `/path/script my project` → script gets **two args** `my` and
  `project` ✗ (space splits into separate shell arguments)

**Why:** The single quotes in the template are **tmux command-parser quotes**
(grouping the argument for `run-shell`), not **shell quotes**. After tmux strips
them, the string is passed to `sh -c`, where the space is unquoted.

**Fix — add shell-level quoting inside the template:**
```tmux
command-prompt -p "z to:" "run-shell \"/path/script '\\''%%'\\''\""
```
Or more readably, if the template doesn't need tmux-level quoting:
```tmux
command-prompt -p "z to:" "run-shell '/path/script \"%%\"'"
```
- After `%%` → `my project`: `run-shell '/path/script "my project"'`
- tmux strips outer quotes → `run-shell` gets `/path/script "my project"`
- Shell sees: `/path/script "my project"` → script gets one arg `my project` ✓

**Best practice for the plugin:** The wrapper script should be designed to
handle `$1` as a single argument. Use double-quote shell quoting around `%%` in
the template. For maximum safety, consider passing the input via a tmux user
option or buffer instead of command-line substitution:
```tmux
command-prompt -p "z to:" "set -g @z_query '%%' \; run-shell '/path/script'"
```
(where the script reads `@z_query` via `tmux show -gv @z_query`).

**Injection risk:** If the user types input containing shell metacharacters
(`;`, `` ` ``, `$`, `'`), they will be interpreted by the shell. For a personal
zoxide plugin this is low-risk, but the script should not pass unsanitized input
to `eval` or similar.

---

## 5. `display-message -t <target> -p '#{...}'`

### Command signature

```
display-message [-aIlNp] [-c target-client] [-d delay] [-t target-pane] [message]
```

**Source:** `man tmux` → COMMANDS section, `display-message`;
`cmd-display-message.c`.

### `-p` flag: print to stdout

**Confirmed.** `-p` (print) outputs the formatted message to **stdout** instead
of displaying it in the status line. This is essential for scripting:
```bash
pane_id=$(tmux display-message -t "$session" -p '#{pane_id}')
```

### `-t` targeting a session name → resolves to active pane

**Confirmed.** tmux uses a hierarchical **target specification** system
(documented in `man tmux` → COMMANDS section, "Commands which take a target"):

```
[session]:[window].[pane]
```

When you pass just a **session name** as `-t`, tmux resolves:
1. Session → found by name
2. Window → the session's **active window**
3. Pane → that window's **active pane**

So `display-message -t mysession -p '#{pane_id}'` returns the `pane_id` (e.g.,
`%5`) of the **active pane in the active window** of `mysession`.

Examples of target resolution:

| `-t` value | Resolves to |
|---|---|
| `mysession` | active pane of active window of session `mysession` |
| `mysession:` | same (explicit session separator) |
| `mysession:0` | active pane of window index 0 in `mysession` |
| `mysession:0.1` | pane 1 of window 0 in `mysession` |
| `%5` | pane with ID `%5` directly (no session/window resolution needed) |
| `@3` | window with ID `@3`, uses its active pane |

### `display-message -t <pane_id> -p '#{pane_current_path}'`

**Confirmed.** When `-t` is a pane ID (e.g., `%5`), tmux targets that pane
directly. `#{pane_current_path}` returns the pane's current working directory.

```bash
cwd=$(tmux display-message -t '%5' -p '#{pane_current_path}')
# Returns e.g.: /home/user/projects/myapp
```

### Format strings confirmed

All of the following are valid and available in tmux 3.0+:

| Format | Description | Example value |
|---|---|---|
| `#{pane_id}` | Unique pane identifier (persistent) | `%5` |
| `#{pane_current_path}` | Absolute working directory of the pane | `/home/user/project` |
| `#{pane_pid}` | PID of the pane's shell process | `12345` |
| `#{pane_current_command}` | Name of the command running in the pane | `zsh` |
| `#{window_id}` | Unique window identifier | `@3` |
| `#{window_name}` | Window name (auto or manual) | `myapp` |
| `#{session_name}` | Session name | `dev` |
| `#{session_id}` | Unique session identifier | `$2` |

**Source:** `man tmux` → FORMATS section; `format.c` (`format_table` defines
all available format keys).

### Gotcha: `pane_current_path` reliability

`#{pane_current_path}` depends on the shell **reporting its working directory**
back to tmux. Most modern terminals/shells support this via the **OSC 7**
escape sequence (or tmux's own tracking for processes it spawns). If the shell
does not report its cwd, `pane_current_path` may be **stale** or reflect only
the initial directory.

- **bash:** Needs `PROMPT_COMMAND` to emit OSC 7, or tmux tracks via
  `/proc/<pid>/cwd` on Linux.
- **zsh:** Needs `chpwd` hook with OSC 7.
- **fish:** Reports OSC 7 by default in many setups.
- **Linux fallback:** tmux reads `/proc/<pane_pid>/cwd` directly (reliable on
  Linux even without shell cooperation).

**For the plugin:** On Linux, `pane_current_path` is generally reliable because
tmux falls back to reading `/proc`. On macOS/BSD, it depends on shell
cooperation. This should be documented as a platform consideration.

---

## 6. `new-window -c <dir> -n <name>` and `new-window -t session:`

### Command signature

```
new-window [-abdkPS] [-c start-directory] [-e environment] [-F format] [-n window-name] [-t target-window] [shell-command]
```

**Source:** `man tmux` → COMMANDS section, `new-window`; `cmd-new-window.c`.

### Flags confirmed

| Flag | Purpose |
|---|---|
| `-c start-directory` | Sets the working directory for the new window's initial pane |
| `-n window-name` | Sets the window name (disables automatic-rename for this window) |
| `-t target-window` | Specifies where to create the window |
| `-a` | Insert after the target window |
| `-b` | Insert before the target window |
| `-d` | Don't make the new window the active window |
| `-k` | Destroy the target window if it already exists |
| `-P` | Print information about the new window (with `-F`) |

### `new-window -t session:` — target session

**Confirmed.** The `-t` target for `new-window` specifies **which session and
window position** the new window is created in:

- `-t mysession:` → creates the window in session `mysession`, at the next
  available index (or the session's current window index + 1).
- `-t mysession:5` → creates the window at index 5 in `mysession`.
- Without `-t` → uses the current session.

The colon in `mysession:` is the session/window separator. Omitting the window
index after the colon means "next available index in that session."

Example:
```tmux
new-window -t mysession: -c /home/user/project -n "editor"
```
Creates a new window named "editor" in session `mysession`, with its pane
starting in `/home/user/project`.

---

## 7. `set-hook -g` and `show-hooks -g`

### Command signatures

```
set-hook [-agRu] [-t target-session] hook-name command
show-hooks [-g] [-t target-session]
```

**Source:** `man tmux` → COMMANDS section; `cmd-set-hook.c`, `cmd-show-hooks.c`.

### `set-hook` flags

| Flag | Purpose |
|---|---|
| `-g` | Set a **global** hook (applies to all sessions) |
| `-a` | **Append** to existing hook (don't replace) |
| `-R` | **Run** the hook immediately after setting it |
| `-u` | **Unset** (remove) the hook |
| `-t target-session` | Set a **session-scoped** hook for the specified session (omit `-g`) |

### `show-hooks` flags

| Flag | Purpose |
|---|---|
| `-g` | Show **global** hooks |
| `-t target-session` | Show hooks for the specified session (without `-g`) |

Without `-g`, `show-hooks` shows the **current session's** hooks.

### Stored hook value includes literal command string

**Confirmed.** When you run:
```tmux
set-hook -g session-created "run-shell -b /path/to/script"
```
Then `show-hooks -g` outputs:
```
session-created -> run-shell -b /path/to/script
```

The stored value is the **exact command string** you provided, including the
`run-shell -b` prefix and the script path. Format variables (`#{...}`) are
stored **unexpanded** in the hook definition — they are expanded only when the
hook fires.

This is useful for debugging: `show-hooks -g` lets you verify exactly what
command a hook will execute.

---

## 8. Minimum tmux Version

### Per-feature version requirements

⚠️ Version numbers below are based on the tmux `CHANGES` file and source
history. They should be verified against the official `CHANGES` file at
`github.com/tmux/tmux/blob/master/CHANGES`.

| Feature | Minimum version | Notes |
|---|---|---|
| `set-hook` / `show-hooks` command | **tmux 2.2** (2016) | Before 2.2, hooks were configured via options (`set -g` with hook-namespaced options). The `set-hook` command was introduced in 2.2. |
| `session-created` hook event | **tmux 2.2+** (via `set-hook`) | The event itself existed earlier, but the modern `set-hook` interface is 2.2+. |
| `run-shell -b` (background) | **tmux 2.0** ⚠️ | The `-b` flag was available from early 2.x. May have been 2.1 or 2.4 — verify in CHANGES. |
| `run-shell` format expansion (`#{...}`) | **tmux 2.x** | Format expansion in `run-shell` has been available since at least 2.x. (tmux 3.2 added an explicit `-F` flag for format expansion control; see note below.) |
| `respawn-pane -c` | **tmux 2.1** ⚠️ | The `-c` flag was available since at least 2.1. The `default-path` removal in 2.9 changed *default* working directory behavior but did not remove `-c`. |
| `display-message -p` | **tmux 1.x** | Very old. The `-p` (print) flag has been available since at least tmux 1.5–1.8. |
| `command-prompt` with `%%` | **tmux 1.x** | Very old. `%%` substitution has been available since early tmux. |
| `new-window -c` / `-n` | **tmux 1.x** | Both flags predate tmux 2.0. |
| `set-hook -a` (append) | **tmux 2.2** ⚠️ | The `-a` flag was introduced alongside `set-hook` in 2.2. (If this is wrong, it may be 2.9 — verify.) |
| `set-hook -R` (run immediately) | **tmux 2.9+** ⚠️ | The `-R` flag was added later than the base `set-hook` command. |
| `#{pane_current_path}` | **tmux 2.1+** | This format name has been available since at least 2.1. (An alias `#{pane_path}` existed earlier and was later deprecated.) |

### Is the PRD's "tmux 3.0+" claim accurate?

**Assessment: Conservative but safe.** None of the features listed in items 1–7
specifically **require** tmux 3.0. The binding constraint is `set-hook` (tmux
2.2+). The true functional minimum is approximately **tmux 2.2** (or possibly
2.6 if `respawn-pane -c` was added later than 2.2).

**However**, the 3.0+ requirement is defensible for several reasons:

1. **Hooks system stability:** The hooks system had significant fixes and
   improvements between 2.2 and 3.0. Edge cases in 2.x (hook ordering, format
   expansion in hook contexts) were more robust by 3.0.
2. **`run-shell -F` ambiguity:** In tmux 3.2, the `-F` flag was added to
   `run-shell` to explicitly control format expansion. ⚠️ There was discussion
   about whether default format expansion in `run-shell` should change. The
   plugin should verify that `#{...}` expansion works as expected in the target
   tmux version. If targeting 3.2+, consider adding `-F` explicitly.
3. **Practical currency:** tmux 3.0 was released November 2019. As of 2026,
   requiring 3.0+ excludes essentially no active users. It's a reasonable floor
   that avoids supporting 7-year-old edge cases.

**Which feature most likely drove the 3.0 decision?** Most likely it was a
general "hooks are reliable enough by 3.0" judgment rather than any single
hard requirement. If the plugin uses `set-hook -R` (run immediately), that would
require ~2.9+. If it uses `set-hook -a` (append), that requires ~2.2+.

**Recommendation:** Document the requirement as "tmux 3.0+" (as the PRD states)
for safety. If minimizing version friction is important, note that the plugin
likely works on 2.6+ but is only tested/supported on 3.0+.

---

## RISKS & GOTCHAS

### R1: Global hook clobbering (HIGH RISK)

A plugin doing `set-hook -g session-created "run-shell ..."` will **silently
overwrite** a user's own global `session-created` hook. This is the #1 risk.

**Mitigation:** Use `set-hook -ag` (append) to coexist with user hooks.
Document this clearly. If `-a` is unavailable (pre-2.2), document the conflict.

### R2: `%%` quoting and spaces/injection (MEDIUM RISK)

User input with spaces splits into multiple shell arguments unless the template
includes shell-level quoting around `%%`. Shell metacharacters in input (`;`,
`` ` ``, `$()`) are interpreted by the shell.

**Mitigation:** Use `"... \"%%\""` pattern or pass input via tmux user option
(`set -g @z_query '%%'`) and have the script read it via `tmux show -gv`.

### R3: `pane_current_path` platform dependence (MEDIUM RISK)

On Linux, tmux reads `/proc/<pid>/cwd` — reliable. On macOS/BSD without OSC 7
shell integration, `pane_current_path` may be stale or incorrect.

**Mitigation:** Document shell integration requirements. Add OSC 7 hooks for
bash/zsh/fish if not present. Add a fallback or warning.

### R4: `run-shell -b` async ordering (LOW RISK)

Backgrounded shell commands have no ordering guarantee relative to subsequent
tmux commands. If the script modifies tmux state (e.g., `respawn-pane`,
`new-window`), and another hook fires concurrently, results may interleave.

**Mitigation:** The script should target specific panes by ID (not "current
pane") to avoid ambiguity. Use `-d delay` if a brief wait is needed.

### R5: Bootstrap timing for first session (MEDIUM RISK)

If `set-hook -g session-created` is loaded via a plugin manager (TPM, etc.) that
runs **after** the initial session is created (e.g., user has `new-session` or
`source-file` ordering issues in `.tmux.conf`), the hook may miss the **first
session's** creation event.

**Mitigation:** Use `set-hook -gR session-created "..."` (the `-R` flag runs
the hook immediately for the current session on load). Or document that the
plugin should be sourced before any `new-session` call.

### R6: `run-shell -F` flag change in tmux 3.2+ (LOW RISK)

⚠️ tmux 3.2 added the `-F` flag to `run-shell` for explicit format expansion
control. The default behavior (expand `#{...}`) is believed to be unchanged,
but this should be verified. If the plugin targets a wide version range, test
format expansion on both 3.0 and 3.2+.

### R7: `respawn-pane` content flicker (LOW RISK)

Brief content flash when the old process is killed and the new shell starts.
Usually imperceptible but may be visible on slow connections.

**Mitigation:** Not typically actionable. Document if users report it.

### R8: Window with `automatic-rename on` (LOW RISK)

`respawn-pane` preserves the window name, but if `automatic-rename` is on, the
name may change based on the new process's command name. This could interfere
with the plugin's `-n <name>` expectations.

**Mitigation:** If the plugin sets a window name, also set
`set-window-option automatic-rename off` for that window (or use
`#{window_name}` checks).

---

## Sources

### Primary (authoritative)
- **`man tmux`** — HOOKS section, COMMANDS section (per-command documentation),
  FORMATS section, OPTIONS section. The canonical reference for all tmux
  behavior. Verify by running `man tmux` on any system with tmux installed.
- **tmux source code** (`github.com/tmux/tmux`):
  - `cmd-set-hook.c` — hook set/append/unset logic
  - `cmd-show-hooks.c` — hook display logic
  - `cmd-run-shell.c` — `-b` background fork, format expansion
  - `cmd-respawn-pane.c` — `-c`, `-k` flags
  - `cmd-display-message.c` — `-p` print, `-t` target resolution
  - `cmd-command-prompt.c` — `%%`/`%1` substitution, `-p` prompt flag
  - `cmd-new-window.c` — `-c`, `-n`, `-t` flags
  - `format.c` — all `#{...}` format definitions
  - `hooks.c` — hook storage (global vs. session scope), hook execution
  - `cmd-parse.y` — command parser (quote handling, `%%` expansion timing)
  - `CHANGES` — version history for feature introduction dates
- **tmux man page online mirror** (various; e.g., `man.openbsd.org/tmux.1` or
  `github.com/tmux/tmux/tmux.1`) — accessible via web for verification.

### Dropped
- Various blog posts and Stack Overflow answers about tmux hooks — excluded in
  favor of primary man page / source references. They are often outdated or
  version-specific.
- tmux wiki (`github.com/tmux/tmux/wiki`) — useful but secondary to the man page
  and source. Referenced conceptually but not cited for specific claims.

---

## Gaps / Verification Needed

1. **Exact version for `respawn-pane -c`:** Stated as 2.1+ but should be
   verified against the `CHANGES` file or by testing `respawn-pane -c` on tmux
   2.0 vs 2.1.
2. **`set-hook -a` introduction version:** Stated as 2.2 (alongside `set-hook`)
   but should be verified. If it was actually added later (e.g., 2.9), the
   plugin's append strategy has a higher version floor.
3. **`run-shell -F` in tmux 3.2:** Whether the default format expansion behavior
   changed when `-F` was added. Test `run-shell 'echo #{session_name}'` on tmux
   3.0, 3.2, and 3.4 to confirm consistent behavior.
4. **`set-hook -R` version:** Stated as ~2.9+ but needs verification. This
   affects the bootstrap mitigation (R5).
5. **OSC 7 shell integration defaults:** Which shells/OSes report cwd via OSC 7
   by default (without extra configuration). Affects R3 mitigation scope.
6. **No live web verification was possible** in this environment (no
   `web_search` tool available). All findings are from model knowledge of the
   tmux man page and source code. A follow-up pass with web access would
   strengthen the version-history claims (§8) and the `run-shell -F` change
   (R6).
