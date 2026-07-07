# Research: tmux Plugin Ecosystem Conventions & `tmux-zoxide-sessions` Coexistence Claims

**Scope:** Validate the six ecosystem/coexistence claims that ground the implementation plan for a new plugin `tmux-zoxide-sessions`. Findings are drawn primarily from **locally installed reference plugins** under `~/.config/tmux/plugins/` (TPM, tmux-resurrect, tmux-continuum) whose actual source was inspected, plus knowledge-based analysis for tools not present on disk (tmux-sessionx, sesh). Confidence levels are marked per item.

**Date:** 2026-07-07

---

## Summary

All core conventions the PRD relies on are **confirmed against real plugin source code**: TPM executes each `<plugin-name>.tmux` run file once at init via a glob over `$plugin_path*.tmux`; the `get_tmux_option()` helper using `tmux show-option -gqv` is a universal, copy-pasted idiom found verbatim in TPM, resurrect, and continuum. The **linchpin coexistence claim holds**: tmux-resurrect restores every session with `new-session -d -s "$session_name" -c "$dir"` where `$dir` is the **saved** `#{pane_current_path}`, so restored sessions inherit their saved cwd and never land in `$HOME` (unless `$HOME` was literally the pane's cwd when saved). Continuum's auto-restore delegates to the *same* `restore.sh`, so the guarantee extends to server-startup restore.

---

## 1. TPM Loading & the Run-File Pattern

**CONFIRMED (primary source — TPM's own loader).**

### How TPM loads a plugin

TPM's `scripts/source_plugins.sh` resolves each `@plugin 'user/repo'` entry to a directory, then **runs every `*.tmux` file in that directory as an executable**:

```bash
silently_source_all_tmux_files() {
	local plugin_path="$1"
	local plugin_tmux_files="$plugin_path*.tmux"
	if plugin_dir_exists "$plugin_path"; then
		for tmux_file in $plugin_tmux_files; do
			# if the glob didn't find any files this will be the
			# unexpanded glob which obviously doesn't exist
			[ -f "$tmux_file" ] || continue
			# runs *.tmux file as an executable
			$tmux_file >/dev/null 2>&1
		done
	fi
}
```
— `~/.config/tmux/plugins/tpm/scripts/source_plugins.sh`

Key facts, all read from source:
- The glob is `$plugin_path*.tmux` — i.e. **any file matching `<plugin-name>.tmux` at the repo root** is executed. A plugin ships exactly one such file, conventionally named after the repo (`tmux-resurrect.tmux`, `tmux-continuum.tmux`, `tmux-zoxide-sessions.tmux`).
- The file is **executed, not sourced** (`$tmux_file >/dev/null 2>&1`), and **output is suppressed** (`>/dev/null 2>&1`). So the run file should do its work via `tmux set-option`/`tmux run-shell` and not rely on printing to stdout. It is run **once per TPM init / reload** (in `tpm`'s `main()` via `source_plugins`).
- A missing plugin dir / missing `.tmux` file produces **no error** (`plugin_dir_exists` guard + `[ -f ] || continue`).

### The `CURRENT_DIR` idiom

The run file establishes its own absolute directory with the standard one-liner. TPM's own run file demonstrates the **bash** variant:

```bash
#!/usr/bin/env bash
CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
```
— `~/.config/tmux/plugins/tpm/tpm`

`${BASH_SOURCE[0]}` is the bash idiom (robust when the file is sourced). The **POSIX `sh`** equivalent is the idiom the PRD uses for its helper scripts:

```sh
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"
```

Both are correct for their respective interpreters. The run file (executed, not sourced) is conventionally `#!/usr/bin/env bash`; because it is *executed*, `$0` is also valid there, but `bash` + `${BASH_SOURCE[0]}` is the safest, most-imitated choice.

### The `@plugin` convention

Confirmed in `source_plugins.sh` → `source_plugins()` → `tpm_plugins_list_helper` (from `helpers/plugin_functions.sh`): TPM enumerates plugins from the `@plugin` options. The documented contract is:

```tmux
set -g @plugin 'user/repo'
```

TPM expands `user/repo` to `$TMUX_PLUGIN_MANAGER_PATH/user/repo/` and runs that directory's `*.tmux` files.

**Verdict for PRD item 1:** Fully validated. Ship `tmux-zoxide-sessions.tmux` at repo root, `#!/usr/bin/env bash`, with the `CURRENT_DIR` one-liner, sourced-once semantics. Declare via `set -g @plugin '<owner>/tmux-zoxide-sessions'`.

---

## 2. The `get_tmux_option` Helper Pattern

**CONFIRMED (primary source — found verbatim in 4 separate plugin files).**

This helper is the de-facto universal convention of the tmux-plugins/* ecosystem. The **canonical form**, found *byte-identical* in TPM, tmux-resurrect (`scripts/helpers.sh`), resurrect's `scripts/check_tmux_version.sh`, and tmux-continuum (`scripts/helpers.sh`):

```bash
get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}
```
— `~/.config/tmux/plugins/tmux-resurrect/scripts/helpers.sh` (also `~/.config/tmux/plugins/tpm/tpm`, `tmux-continuum/scripts/helpers.sh`, `tmux-resurrect/scripts/check_tmux_version.sh`)

### Behavior of `tmux show-option -gqv <name>`

- `-g` = global, `-q` = quiet (no error if option is unset), `-v` = value only.
- For an **unset user option** (e.g. `@plugin-style` that the user never set), `show-option -gqv` prints **nothing and exits 0**. The `[ -z "$option_value" ]` branch therefore fires and the `default_value` is echoed. This is precisely why the helper takes a default argument and is the **correct** way to read `@plugin-style` user options.
- This is a pure external-command invocation + string test; it is **interpreter-agnostic**. `tmux show-option -gqv` behaves identically whether invoked from `bash` or POSIX `sh` — the `tmux` binary does the work, the shell just tests emptiness.

### POSIX `sh` rewrite — validity

The canonical form uses `local`, which is **non-POSIX** but **supported as an extension by dash** (Debian/Ubuntu's `/bin/sh`), busybox ash, and of course bash. A strictly-POSIX rewrite drops `local` (and changes `$(...)` stays the same — it's POSIX). Two safe options for the PRD:

```sh
# Option A — keep `local`; works on dash/ash/bash (the real-world /bin/sh shells)
get_tmux_option() {
    local option="$1" default_value="$2"
    local option_value; option_value=$(tmux show-option -gqv "$option")
    if [ -z "$option_value" ]; then echo "$default_value"; else echo "$option_value"; fi
}

# Option B — strictly POSIX (no `local`); maximally portable
get_tmux_option() {
    option_value=$(tmux show-option -gqv "$1")
    if [ -z "$option_value" ]; then echo "$2"; else echo "$option_value"; fi
}
```

> ⚠️ If `#!/bin/sh` is used, **do not** keep `local` *and* claim strict POSIX conformance — pick one posture. In practice `local` is safe on every Linux `/bin/sh`. See §5.

**Verdict for PRD item 2:** Validated. The helper is the correct mechanism; `show-option -gqv` returns empty + exit 0 for unset options; POSIX rewrites are valid because the substantive work is in the `tmux` binary. The PRD's choice to ship this as a sourced `resolve.sh` lib under `#!/bin/sh` is sound (see §5 for the `local` caveat).

---

## 3. tmux-resurrect `restore.sh` Coexistence  ⭐ LINCHPIN

**CONFIRMED (primary source — actual `restore.sh` + `save.sh` + continuum's auto-restore).** This is the claim the entire safety model rests on, and it holds.

### The exact `new-session ... -c` line

From `new_session()` in `~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh`:

```bash
new_session() {
	local session_name="$1"
	local window_number="$2"
	local dir="$3"
	local pane_index="$4"
	local pane_id="${session_name}:${window_number}.${pane_index}"
	if is_restoring_pane_contents && pane_contents_file_exists "$pane_id"; then
		local pane_creation_command="$(pane_creation_command "$session_name" "$window_number" "$pane_index")"
		TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -c "$dir" "$pane_creation_command"
	else
		TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -c "$dir"
	fi
	# change first window number if necessary
	local created_window_num="$(first_window_num)"
	if [ $created_window_num -ne $window_number ]; then
		tmux move-window -s "${session_name}:${created_window_num}" -t "${session_name}:${window_number}"
	fi
}
```

**The linchpin line (both branches):**
```
TMUX="" tmux -S "$(tmux_socket)" new-session -d -s "$session_name" -c "$dir"
```

This is `new-session -d -s <name> -c <saved-dir>` — matching the PRD's claim almost exactly (resurrect adds `TMUX=""` + `-S socket` plumbing; the `-c "$dir"` is present in **both** the pane-contents and plain branches).

### Where does `$dir` come from? → the SAVED cwd, not `$HOME`

`new_session()` receives `$dir` from `restore_pane()`, which parses each `pane` line of the resurrect save file:

```bash
restore_pane() {
	local pane="$1"
	while IFS=$d read line_type session_name window_number window_active window_flags pane_index pane_title dir pane_active pane_command pane_full_command; do
		dir="$(remove_first_char "$dir")"
		...
		else
			new_session "$session_name" "$window_number" "$dir" "$pane_index"
		fi
```

And `save.sh`'s `pane_format()` shows that the `dir` field written to the save file is the **pane's current working directory at save time**:

```bash
pane_format() {
	...
	format+=":#{pane_current_path}"   # <- the dir field, captured live
	...
}
```
— `~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh`

So the chain is: **`#{pane_current_path}` at save → resurrect file → `$dir` at restore → `new-session -c "$dir"`**. Restored sessions land in their **saved cwd**. The ONLY way a restored session lands in `$HOME` is if the pane's cwd was literally `$HOME` when it was saved.

> Note on `new_window()` / `new_pane()`: they *also* pass `-c "$dir"` (and `new_window` additionally does `dir="${dir/#\~/$HOME}"` to expand a leading `~`). The directory is always the saved path. Confirmed across all three creation paths in `restore.sh`.

### Continuum auto-restore uses the SAME restore path

Continuum's `continuum_restore.sh` does **not** re-implement restore; it **executes resurrect's `restore.sh`** by looking up the path tmux-resurrect registered in `@resurrect-restore-script-path`:

```bash
fetch_and_run_tmux_resurrect_restore_script() {
	# give tmux some time to start and source all the plugins
	sleep 1
	local resurrect_restore_script_path="$(get_tmux_option "$resurrect_restore_path_option" "")"
	if [ -n "$resurrect_restore_script_path" ]; then
		"$resurrect_script_path"
	fi
}

main() {
	# ... only if this is the only tmux server ...
	if auto_restore_enabled && ! another_tmux_server_running_on_startup; then
		fetch_and_run_tmux_resurrect_restore_script
	fi
}
```
— `~/.config/tmux/plugins/tmux-continuum/scripts/continuum_restore.sh`

with `resurrect_restore_path_option="@resurrect-restore-script-path"` (`tmux-continuum/scripts/variables.sh`). Because it runs the identical `restore.sh`, **continuum's server-startup auto-restore inherits the exact same `-c "$saved_dir"` guarantee.** The `@continuum-restore` option defaults to `"off"` (`auto_restore_default="off"`), so a user must opt in.

**Verdict for PRD item 3:** ✅ **Holds, with high confidence.** Both manual (`prefix + C-r`) restore and continuum auto-restore create sessions via `new-session -d -s <name> -c "$saved_cwd"`. Restored sessions do **not** land in `$HOME` (barring the degenerate case where the saved cwd *was* `$HOME`). The PRD's safety model — "zoxide only rewrites cwd for freshly-created/default `$HOME` sessions, never for restored ones" — is therefore sound, with the caveat that the plugin must correctly *detect* whether a session was restored vs. freshly created (see RISKS & GOTCHAS).

---

## 4. sessionx / sesh Coexistence

**PARTIALLY CONFIRMED (knowledge-based; tools not installed locally → cannot quote source).** Treat confidence as *medium*; this should be re-verified against live source before hardening.

### tmux-sessionx (`omerxx/tmux-sessionx`)
A fuzzy session manager (fzf/zoxide-backed). Its session-creation path resolves a directory — in **zoxide mode** it queries zoxide for the chosen entry's path — and creates the session with that directory:

- `tmux new-session -d -s "<name>" -c "<resolved_dir>"`
- When the user picks a zoxide result, the resolved dir is the **zoxide entry's directory**, not `$HOME` (unless the zoxide entry *is* `$HOME`).
- Sessionx also supports "attach if exists" semantics; it only creates when absent.

### sesh (`joshmedeski/sesh`)
A Go binary session manager. Session names are **directory-derived** (typically the basename of the path). With zoxide integration, `sesh connect <query>` resolves a real path and:

- `tmux new-session -d -s "<name>" -c "<path>"`
- The `-c` target is the resolved path, so new sessions start in their project directory, not `$HOME`.

### Implication for the PRD
Both tools pass `-c <resolved-dir>` on creation, so **sessions they create do not start in `$HOME`** — meaning the PRD's "leave non-`$HOME` sessions alone" rule will (correctly) skip them. The coexistence claim is consistent, but:

- **Cannot be quoted from source here.** Recommend confirming against the current `omerxx/tmux-sessionx` and `joshmedeski/sesh` repos (look for `new-session` / `new_session` and the `-c`/`start-directory` argument).
- Edge: a user can configure sessionx/sesh to create sessions **without** `-c` (custom hooks). The PRD should key its behavior off **observed cwd**, not off "was created by tool X" — which the design already does.

**Verdict for PRD item 4:** Plausible and consistent with the design's cwd-based detection, but **not source-verified** in this pass. Design correctly relies on checking `pane_current_path == $HOME` rather than on a specific tool's behavior, so even if a tool occasionally omits `-c`, the fallback still works.

---

## 5. POSIX `sh` vs `bash` in Plugin Scripts

**CONFIRMED via ecosystem convention + shell-semantics analysis.**

### What the ecosystem actually does
- The ecosystem's run files and most scripts use **`#!/usr/bin/env bash`** (TPM, resurrect's `restore.sh`/`save.sh`/`helpers.sh`, continuum). This lets them freely use `local`, `[[ ]]`, `=~` regex, arrays, `${BASH_SOURCE[0]}`, `< <(...)` process substitution, `read -ra` array splitting — **all of which are bash-only or bash-extended**.
- The PRD's deliberate split — **`#!/usr/bin/env bash` for the run file, `#!/bin/sh` for the helper scripts that `source` a shared `. resolve.sh` lib** — is a sound, more-portable pattern *provided the `sh` scripts avoid bash-isms*.

### The three classic portability traps under dash/POSIX `sh`
| Construct | POSIX? | dash `/bin/sh` | bash | PRD implication |
|---|---|---|---|---|
| `local` keyword | ❌ **not POSIX** | ✅ supported (extension) | ✅ | "Works on every real `/bin/sh`" but is *technically* non-conformant. Safe in practice; don't claim strict POSIX if used. |
| `[[ ... ]]` | ❌ | ❌ **unsupported** | ✅ | MUST use `[ ... ]` with single `=` for string compare. |
| Arrays `a=(...)`, `${a[@]}` | ❌ | ❌ **unsupported** | ✅ | MUST use positional params / `IFS`-split loops. |
| `[ "$x" = "$y" ]` | ✅ | ✅ | ✅ | Use `=` not `==`. |
| `case ... esac` | ✅ | ✅ | ✅ | Prefer over `[[ =~ ]]` for pattern matching. |
| `$( ... )` | ✅ | ✅ | ✅ | Avoid legacy backticks. |
| `< <(...)` process substitution | ❌ | ❌ | ✅ | Use pipes/temp files. |
| `read -ra` (array split) | ❌ | ❌ | ✅ | Use `IFS=... read` into scalars. |

### Verdict for PRD item 5
- **Sound pattern.** `#!/bin/sh` + sourcing a shared `. resolve.sh` lib is exactly how maximally-portable shell helpers are written. The substantive work is in `tmux` invocations and simple `[ ]` tests, all POSIX-clean.
- **The PRD reportedly avoids `local`, `[[ ]]`, and arrays** — if true, the `sh` scripts are genuinely POSIX-conformant and will run under dash, busybox ash, mksh, and bash alike. ✅
- **One nuance to verify in the actual PRD scripts:** confirm there are no `[[ ]]`, no `()=()` arrays, no `==` inside `[ ]`, no `read -ra`, no `${var//pattern/}` (non-POSIX parameter expansion), and no `echo -e` (POSIX `echo` has no `-e`; use `printf`). Use `printf` for any formatted/escape output — `echo` behavior is famously inconsistent across shells.
- **`dash` does support `local`**, so even if the PRD *does* keep `local`, it will run on the overwhelmingly common `/bin/sh` (dash on Debian/Ubuntu, ash on Alpine/busybox). The strict-POSIX purist move is to drop it; the pragmatic move is to keep it and document the dash assumption.

---

## 6. Conventional Repo Layout

**CONFIRMED (primary source — TPM, resurrect, continuum all follow it).**

The conventional layout for a tmux-plugins-style plugin:

```
tmux-zoxide-sessions/
├── tmux-zoxide-sessions.tmux      # run file, executable (chmod +x), #!/usr/bin/env bash
├── scripts/                       # helper scripts subdir
│   ├── resolve.sh                 # sourced lib (e.g. get_tmux_option / resolve dir)
│   └── *.sh                       # executable helpers (chmod +x)
├── README.md                      # root — install + usage + options
└── LICENSE                        # root — MIT (tmux-plugins ecosystem standard)
```

Evidence:
- **`scripts/` subdir is universal.** resurrect: `scripts/restore.sh`, `scripts/save.sh`, `scripts/helpers.sh`, `scripts/variables.sh`, `scripts/check_tmux_version.sh`. continuum: `scripts/continuum_restore.sh`, `scripts/helpers.sh`, `scripts/variables.sh`. TPM: `scripts/source_plugins.sh`, `scripts/variables.sh`. ✅
- **Run file at repo root.** TPM sources `$plugin_path*.tmux` from the *root* of the plugin dir, so the run file **must** sit at repo root, not under `scripts/`. ✅
- **Executable bit.** TPM runs the `.tmux` file as `$tmux_file >/dev/null 2>&1` — i.e. **executed**, so it **must be `chmod +x`** (and have a valid shebang). Scripts invoked via `tmux run-shell`/`$CURRENT_DIR/scripts/x.sh` likewise need `+x` (or be invoked via `sh path`). `git update-index --chmod=+x` is needed to preserve the bit across clone on platforms. ✅
- **LICENSE (MIT).** The tmux-plugins ecosystem standard. Place at repo root. (LICENSE file was not present in the staged reference snapshot here, but MIT-at-root is the documented convention for the org's plugins.)
- **README.md at root.** Standard; TPM README documents `set -g @plugin` install, and each plugin's README documents its `@plugin-*` options and keybindings.

> **Observation:** In this research sandbox the reference repos were staged *selectively* — the `scripts/` trees and TPM's `tpm` loader were present and quotable, but the root `*.tmux` run files and `LICENSE` files for resurrect/continuum/prefix-highlight were **not present on disk** (ENOENT at all expected paths including the `~/.tmux/plugins/` default location). The run-file-at-root + MIT-license conventions are therefore inferred from TPM's glob logic and ecosystem documentation rather than read directly. They are high-confidence inferences but not byte-verified here.

**Verdict for PRD item 6:** Validated (run file at root + `scripts/` subdir + `chmod +x`; LICENSE MIT + README at root). One caveat: ensure the executable bit is committed.

---

## RISKS & GOTCHAS

1. **Detection of "restored vs. fresh" is the real load-bearing logic, not the `-c` fact.** The resurrect `-c` claim is solid, but the PRD must correctly decide *when* to apply zoxide-rewrite. If it naively rewrites cwd for *every* session on creation — including ones resurrect is mid-creating — it would clobber restored paths. Mitigation: hook only the `session-created` / first-pane path where `pane_current_path == $HOME`, and ensure ordering doesn't race resurrect. (Resurrect creates sessions synchronously within `restore.sh`; a `session-created` hook firing during restore would see the `-c` dir already set, so testing `pane_current_path == $HOME` is the correct gate.)

2. **Ordering / race with resurrect on server start.** Continuum's auto-restore does `sleep 1` then runs `restore.sh`. If `tmux-zoxide-sessions` registers a `session-created`/`window-linked` hook that fires while resurrect is creating sessions, the hook *could* run between resurrect's `new-session -c $dir` and later steps. Because resurrect sets cwd at `new-session` time, by the time any hook observes the session its cwd is already the saved dir — so a `== $HOME` gate correctly skips it. Still: **validate the gate fires after cwd is set**, and prefer a `client-session-changed`/explicit-trigger model over a blanket `session-created` rewrite if ordering proves fragile.

3. **Degenerate `$HOME`-as-saved-cwd case.** If a user's saved session genuinely had a pane in `$HOME`, resurrect restores it there, and a `== $HOME` gate would (wrongly) treat it as "fresh, rewrite me." This is an acceptable false-positive in practice (rewriting a `$HOME` session to a zoxide dir is arguably desirable), but document it. Consider distinguishing via a marker option set during restore (e.g. resurrect could be detected via `@resurrect-restore` script activity) if precision matters.

4. **`local` under `#!/bin/sh`.** dash supports it; a pure-POSIX validator (e.g. `shellcheck` with `sh` shebang, or `posh`) will flag it. If the PRD claims strict POSIX conformance, drop `local`. If it claims "runs on dash/busybox/bash," `local` is fine — but say so explicitly.

5. **`echo` portability.** Under dash, `echo -e "..."` may print `-e` literally. Use `printf '%s\n'` / `printf` for any escape sequences. The canonical `get_tmux_option` uses plain `echo "$default_value"` (no escapes) — safe; the PRD should follow suit and avoid `echo -e`/`echo -n` reliance.

6. **Executable bit lost on clone.** `*.tmux` and `scripts/*.sh` must be committed executable. Use `git update-index --chmod=+x <file>` (or `chmod +x` before commit) — otherwise the run file won't execute and TPM silently no-ops it (output suppressed).

7. **Output suppression.** TPM runs the `.tmux` file with `>/dev/null 2>&1`. Any `echo`/diagnostic from the run file is invisible; use `tmux display-message` for user-facing notices (as resurrect's `display_message()` does).

8. **sessionx / sesh not source-verified (item 4).** Coexistence is plausible and the design's cwd-based detection makes it robust regardless, but the `-c` behavior of these two tools should be confirmed against live repos before the README claims "guaranteed coexistence."

---

## Gaps

- **sessionx & sesh session-creation source not verified** locally (not installed) and no web fetch available in this environment. Recommendation: open `omerxx/tmux-sessionx` and `joshmedeski/sesh` and grep `new-session` / `-c` / `start-directory` to confirm §4 before finalizing README claims.
- **Root `*.tmux` run files & `LICENSE` for the reference plugins were not present** in the staged sandbox (only `scripts/` + TPM loader were). Run-file-at-root and MIT-at-root are high-confidence inferences from TPM's glob + ecosystem docs, not direct reads. Low risk.
- **Resurrect hook integration** (`@resurrect-hook-pre-restore-all` / `post-restore-all`) could let the plugin *know* a restore is in progress and disable its rewrite for the duration — worth investigating as a more precise alternative to the `== $HOME` gate (addresses gotcha #3).

## Supervisor coordination
No blocking decision required; proceeding to write the brief and return summary. The linchpin (item 3) is confirmed from primary source, so the core design is grounded. The only soft spot (item 4) does not block the implementation plan because the design keys off observed cwd rather than tool identity.
