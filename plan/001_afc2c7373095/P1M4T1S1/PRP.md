# PRP — P1.M4.T1.S1: Author `README.md` (documentation)

## Goal

**Feature Goal**: Create `README.md` at the **repo root** documenting the `tmux-zoxide-sessions`
plugin. The body is **PRD §5.6 verbatim** — the title, the two-feature intro, Why, Install (TPM +
manual), Usage (window jump + session auto-relocate), the full **8-row Options table**, the
Backends section, Scope & compatibility, Known limitations, and the MIT License pointer — with
**exactly two accuracy touchpoints** applied (this subtask's only deviations from §5.6 verbatim).

**Deliverable**: A single new file — `README.md` at the repo root (`/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions/README.md`). **No code changes.** This is a
documentation-only (Mode A authoring) subtask: no scripts, no tests, no run-file edits, no
`chmod`, no `.gitignore`/`PRD.md`/`tasks.json` changes.

**Success Definition**:
- `README.md` exists at the repo root and renders as well-formed GitHub-Flavored Markdown (no
  broken code fences, balanced headers, table parses).
- Content is **faithful to PRD §5.6** (every section present, same wording) **except** the two
  approved touchpoints below.
- The Options table lists **all 8** `@zoxide-sessions-*` options with correct defaults — this
  satisfies the **P1.M4.T2.S1** acceptance criterion *"README documents every option"*.
- The **`$HOME`-guard model** is described (resurrect/continuum/sessionx/sesh place with `-c`, so
  they never land in `$HOME` and are never touched) — satisfies *"and the `$HOME`-guard model"*.
- **Touchpoint (a) NOTE C** is applied to *Scope & compatibility* (reload-safe `set-hook -g` +
  how to combine with a user's own `session-created` logic).
- **Touchpoint (b) Correction A** is applied to *Backends* (resolver returns empty on no-match —
  now actually TRUE after the `_resolve_z` cwd-delta fix shipped in `resolve.sh`).

## User Persona

**Target User**: Two audiences — (1) the downstream verification subtasks (P1.M4.T2.S1 acceptance
check, P1.M4.T3.S1 final README↔behavior reconciliation) that machine-check the README's content;
(2) the end user reading the rendered README on GitHub to install/configure the plugin.

**Use Case**: A tmux user lands on the repo, reads the README, installs via TPM (or manual
`run-shell`), learns the window-jump key and the session auto-relocate behavior, scans the Options
table to configure the 8 options, understands the backends, and reads Scope & compatibility to
confirm the plugin is safe alongside their resurrect/continuum/sessionx/sesh setup.

**Pain Points Addressed**: The shipped code (M1/M2/M3) has no top-level documentation. The README
is the single source of user-facing truth for install, usage, options, backends, compatibility,
and limitations. Without it, the §9 acceptance criterion "README documents every option and the
`$HOME`-guard model" cannot pass.

## Why

- This **is** the documentation deliverable for the MVP. PRD §5.6 specifies the README content
  verbatim; this subtask authors it and folds in the two validated corrections from
  `findings_and_risks.md` that post-date the PRD prose.
- **Scope/cohesion**: All implementation subtasks (M1 resolver, M2 window-jump, M3 session hook)
  are complete. The README must match that shipped behavior exactly. Downstream P1.M4.T3.S1 will
  *reconcile* the README against shipped behavior — authoring it faithfully now (with the two
  known corrections pre-applied) makes that reconciliation a confirmation, not a rewrite.
- **NOTE C** matters because the run file (`tmux-zoxide-sessions.tmux`) uses `set-hook -g`, which
  empirically **overwrites** a pre-existing global `session-created` hook (it does *not*
  literally "compose"). The PRD §5.6 wording ("any user `session-created` hooks" compose fine)
  is therefore inaccurate and must be corrected in the README — **documentation only**, per
  `findings_and_risks.md` NOTE C ("Do NOT change the run-file mechanism").

## What

A single new Markdown file `README.md` at the repo root, containing the PRD §5.6 README body with
**two surgical edits** applied (detailed in *All Needed Context* → *The two touchpoints*). The
README's sections, in order:

1. `# tmux-zoxide-sessions` + two-feature intro + zoxide/rupa-z link line.
2. `## Why` (literal-path problem; session-manager gap).
3. `## Install` — `### With TPM` (`set -g @plugin ...`), `### Manual` (`git clone`, `run-shell`,
   `tmux source`), + backend/index prerequisite paragraph.
4. `## Usage` — `### Window jump` (`prefix + g`, `z to: tmux`, empty/no-match fallback),
   `### Session auto-relocate` (on by default, `tmux new -s sellario`, skip-list/no-match left at
   `$HOME`, **the `$HOME`-guard safety paragraph**).
5. `## Options` — the **8-row** table + an example `set -g` block.
6. `### Backends` (zoxide / z / auto) **+ Correction A note**.
7. `## Scope & compatibility` — tmux 3.0+; resurrect/continuum + sessionx/sesh composition
   **+ NOTE C reload-safe `set-hook -g` wording**; not a session picker.
8. `## Known limitations` (respawn flicker, whitespace skip-names, single home-dir, GNU
   `readlink -f`).
9. `## License` → `MIT`.

### Success Criteria

- [ ] `README.md` exists at repo root.
- [ ] All 8 options present in the Options table with correct defaults (see Validation).
- [ ] The `$HOME`-guard model is described (the "never land in `$HOME` and are never touched"
  sentence).
- [ ] Touchpoint (a) NOTE C applied: README mentions `set-hook -g`, reload-safe, that it
  *replaces* a pre-existing global hook, and how to combine (set after TPM init / `set-hook -ag`).
- [ ] Touchpoint (b) Correction A applied: README states the resolver returns empty (exit 0) on
  no-match.
- [ ] No source files, tests, run file, `PRD.md`, `tasks.json`, `.gitignore`, or `LICENSE`
  modified. **Only** `README.md` is created by this subtask.

## All Needed Context

### Context Completeness Check

If someone knew nothing about this codebase, would they have everything needed to implement this
successfully? **Yes** — the entire README body is supplied verbatim below (PRD §5.6), the two
touchpoints are specified as exact old→new text edits, and validation is a concrete grep
checklist. The only judgment call is faithful transcription; the verbatim block removes ambiguity.

### Documentation & References

```yaml
# MUST READ - primary sources for content + corrections
- docfile: PRD.md
  why: §5.6 is the VERBATIM README source. §4 (Options reference) is the authoritative
       options table; §6.2 (Coexistence) + §8 (Known limitations) cross-check the Scope &
       Known-limitations sections. §9 (Acceptance criteria) defines what the README must cover.
  section: "§5.6 README.md (verbatim body); §4 Options reference; §6.2 Coexistence; §8 Known
           limitations; §9 Acceptance criteria (last bullet: 'README documents every option and
           the $HOME-guard model')."

- docfile: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: "Defines the TWO approved README deviations. NOTE C (🟡) = the set-hook -g overwrites
        reality that mandates the Scope & compatibility rewrite. Correction A (🔴) = the rupa/z
        no-match false-positive that is now FIXED in resolve.sh, so the README's 'resolver
        returns empty on no-match' claim is now actually TRUE and should be stated."
  section: "🔴 CORRECTION A (rupa/z _z no-match) ; 🟡 NOTE C (set-hook -g overwrites, docs-only)."

- file: README.md
  why: "THE deliverable (new file at repo root)."
  pattern: "GitHub-Flavored Markdown; H1 title, H2 sections, one pipe table, several fenced
            code blocks."
  gotcha: "Fenced code blocks inside the Install/Usage/Options sections MUST be balanced (open
           and close with ``` at column 0). The PRD §5.6 raw block is clean (see exact text
           below); do not reintroduce the nested-fence escaping artifacts seen in the mdsel
           selection — write the clean version."

- file: scripts/lib/resolve.sh
  why: "Confirms Correction A is shipped: _resolve_z compares cwd before/after _z and returns
        empty (exit 0) on no-match. So the README's 'empty on no-match' claim is TRUE."
  pattern: "_resolve_z emits a path ONLY when _z changed cwd; resolve() ends with `return 0`."

- file: tmux-zoxide-sessions.tmux
  why: "Confirms NOTE C applies: the run file uses `tmux set-hook -g session-created ...` (NOT
        -ag). So a pre-existing global session-created hook IS overwritten. The README must say
        so."
  pattern: "`tmux set-hook -g session-created \"run-shell -b '...'\"`"

- file: scripts/z-session.sh
  why: "The shipped guard chain the README's Usage/Scope sections describe (master toggle,
        skip-names, $HOME path compare via _norm/readlink -f, respawn-pane -c -k, window-name
        branch). README wording must match this behavior."

- file: LICENSE
  why: "README's `## License` section points to it as 'MIT'. Do NOT recreate the full MIT text
        in the README — the LICENSE file already holds it (Copyright (c) 2026 Dustin Schultz).
        README License section is just the word `MIT`."
```

### Current Codebase tree (run `ls` in the repo root)

```bash
tmux-zoxide-sessions/
  .gitignore
  LICENSE                # MIT — already exists (M1.T1)
  PRD.md                 # READ-ONLY spec
  tmux-zoxide-sessions.tmux   # run file (M2.T2 + M3.T2 wiring)
  scripts/
    lib/resolve.sh       # shared resolver (M1.T2)
    z-window.sh          # window-jump handler (M2.T1)
    z-session.sh         # session-created handler (M3.T1)
  tests/                 # POSIX-sh integration tests (8 files)
  plan/001_afc2c7373095/ # plan + PRPs + architecture/findings_and_risks.md
  # NOTE: README.md does NOT yet exist — this subtask creates it.
```

### Desired Codebase tree with files to be added

```bash
tmux-zoxide-sessions/
  README.md   # NEW (this subtask). User-facing docs: install, usage, 8 options,
              # backends, scope & compatibility (NOTE C wording), known limitations.
```

### The README body (PRD §5.6 verbatim) — write this, then apply the two touchpoints

Below is the **exact** PRD §5.6 README content (clean; fetched from `PRD.md` so no nested-fence
escaping artifacts). Author the file with this content, then make the two edits in the next
subsection.

````markdown
# tmux-zoxide-sessions

Two zoxide-powered features for tmux:

1. **Window jump** — press `prefix g`, type a query, get a new window in the
   directory zoxide resolves for that query (named after the dir basename).
2. **Session auto-relocate** — any new session that lands in `$HOME` is
   automatically moved to the zoxide-resolved directory matching its name.

Built for tmux users who keep a frecency index with [zoxide](https://github.com/ajeetdsouza/zoxide)
or rupa/z.

## Why

`new-window -c` and `new-session -c` need literal paths. zoxide (and rupa/z)
already rank every directory you visit by frecency, so a short query such as
`tmux` or `proj` lands in the right place without typing or copying a path.

The session feature fills a gap: session managers like tmux-sessionx and sesh
only zoxide-resolve sessions created *through them*. Sessions created any other
way (`tmux new -s foo`, `prefix :` `new-session`, ssh-then-tmux) default to
`$HOME`. This plugin catches those.

## Install

### With TPM

Add this line before the [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) init:

```
set -g @plugin 'dabstractor/tmux-zoxide-sessions'
```

Reload tmux and press `prefix + I`.

### Manual

```
git clone https://github.com/dabstractor/tmux-zoxide-sessions \
  ~/.config/tmux/plugins/tmux-zoxide-sessions
```

```
run-shell ~/.config/tmux/plugins/tmux-zoxide-sessions/tmux-zoxide-sessions.tmux
```

```
tmux source ~/.tmux.conf
```

zoxide must be installed and its shell hook active for the `zoxide`/`auto`
backends; or set `@zoxide-sessions-z-sh` to a rupa/z `z.sh` for the `z` backend.
With no populated index, window queries fall back to the current directory and
session relocate is a no-op.

## Usage

### Window jump
Press `prefix + g` (default), type a query, press Enter:

```
z to: tmux
```

A window opens in the current session, in zoxide's best match for `tmux`, named
after the directory basename. An empty query or a no-match opens the window in
the current pane's directory (same as `new-window -c "#{pane_current_path}"`).

### Session auto-relocate
On by default. Create a session from `$HOME` with a name zoxide knows:

```
tmux new -s sellario
```

The session's first pane moves from `$HOME` to `zoxide query sellario`. Sessions
named in the skip-list (`home`, `main` by default), or whose name doesn't
resolve, are left at `$HOME`.

This is safe alongside resurrect/continuum, sessionx, and sesh: those place
sessions with an explicit directory, so they never land in `$HOME` and are never
touched.

## Options

Set with `set -g` before the TPM init (or `run-shell`) line.

| Option | Default | Purpose |
| --- | --- | --- |
| `@zoxide-sessions-key` | `g` | Window-jump key (after prefix). |
| `@zoxide-sessions-prompt` | `z to:` | `command-prompt` label. |
| `@zoxide-sessions-backend` | `auto` | Resolver: `auto`, `zoxide`, or `z`. |
| `@zoxide-sessions-z-sh` | unset | Path to rupa/z `z.sh`. |
| `@zoxide-sessions-auto-session` | `on` | Session hook master toggle. |
| `@zoxide-sessions-home-dir` | `$HOME` | Dir treated as the "bare/default" landing dir. |
| `@zoxide-sessions-skip-names` | `home main` | Names never relocated (whitespace-separated). |
| `@zoxide-sessions-window-name` | `off` | Rename first window after relocate: `off` or `session`. |

Example:

```
set -g @zoxide-sessions-key 'Z'
set -g @zoxide-sessions-window-name 'session'
```

### Backends
- `zoxide` runs `zoxide query <query>`. Needs the `zoxide` binary on `$PATH`.
- `z` sources a rupa/z `z.sh` (set via `@zoxide-sessions-z-sh`) and calls `_z`.
  Uses zsh when available, otherwise sh.
- `auto` (default) uses zoxide when present, then rupa/z when a `z.sh` path is
  set. Keeps working on machines without zoxide.

## Scope & compatibility
- Requires **tmux 3.0+** (`session-created` hook, `respawn-pane -c`).
- The session hook composes with resurrect/continuum (restored via `-c`, skipped),
  sessionx/sesh (placed via `-c`, skipped), and any user `session-created` hooks.
- This is not a session picker/switcher; use sessionx/sesh for browsing.

## Known limitations
- Relocation uses `respawn-pane -k`, so there is a brief flicker as the first
  pane restarts in the new directory (unavoidable — tmux permits no pre-creation
  interception).
- `skip-names` is whitespace-separated, so entries cannot contain spaces.
- `home-dir` is a single directory, not a list.

## License
MIT
````

### The two touchpoints (the ONLY deviations from the verbatim body)

**Touchpoint (a) — NOTE C (docs-only).** In the **`## Scope & compatibility`** section, replace
this single bullet (the middle one):

> **OLD** —
> ```
> - The session hook composes with resurrect/continuum (restored via `-c`, skipped),
>   sessionx/sesh (placed via `-c`, skipped), and any user `session-created` hooks.
> ```

with this **revised bullet** (keeps resurrect/continuum + sessionx/sesh, drops the inaccurate
"any user hooks compose" clause, and adds the reload-safe + how-to-combine story):

> **NEW** —
> ```
> - The session hook composes with resurrect/continuum (restored via `-c`, skipped)
>   and sessionx/sesh (placed via `-c`, skipped). It registers globally with
>   `set-hook -g`, which is **reload-safe** — re-running `prefix r` or a TPM
>   re-source does not stack duplicate hooks. Because `set-hook -g` *replaces*
>   any pre-existing global `session-created` hook, a hook set *before* the TPM
>   init line is overwritten. To combine the plugin with your own
>   `session-created` logic, set your hook **after** the TPM init line and have it
>   also invoke `scripts/z-session.sh "#{session_name}"`, or append instead of
>   replace with `set-hook -ag session-created "..."`.
> ```

Rationale (from `findings_and_risks.md` NOTE C): empirically, `set-hook -g session-created "Y"`
after an earlier `set-hook -g session-created "X"` leaves **only** Y. Reload-idempotency (no
duplicate hooks on TPM re-source) is the more important property for a plugin, so the PRD keeps
`set-hook -g` in the run file — but the README must not claim literal composition. Do **not**
change the run file (`tmux-zoxide-sessions.tmux`).

**Touchpoint (b) — Correction A.** In the **`### Backends`** section, **append** the following
note immediately after the `auto` bullet (i.e. after "...Keeps working on machines without
zoxide."):

> **ADD** —
> ```
> All three backends return an empty result (and exit 0) when a query has no
> match; callers check the output, never the exit status. (The `z` backend
> achieves this by comparing the working directory before and after calling
> rupa/z's `_z`, which changes directory only on a match.) An empty result means
> a window-jump query falls back to the current pane's directory and session
> relocate is a no-op.
> ```

Rationale (from `findings_and_risks.md` 🔴 CORRECTION A): the shipped `_resolve_z`
(`scripts/lib/resolve.sh`) compares `pwd` before/after `_z` and emits a path **only** on a real
match, so the documented contract — "the resolver returns empty on no-match and always exits 0"
(also stated in PRD §4) — is now actually TRUE for all three backends. The README should state
it. (Previously rupa/z returned a false-positive on no-match; that bug is fixed in code, so the
README need not hedge.)

> **Important**: Keep the README faithful to §5.6 everywhere else — same section order, same
> wording, same links. Do **not** add the GNU `readlink -f` bullet to *Known limitations* beyond
> what §5.6 already has (§5.6 lists only three limitations; §8 lists four including `readlink -f`.
> Per the work-item contract "Keep the README's content faithful to §5.6", ship the **three**
> §5.6 limitations verbatim and do **not** add the fourth `readlink -f` bullet. Downstream
> P1.M4.T3.S1 may reconcile if it decides to expand.)

### Known Gotchas of our codebase & Library Quirks

```markdown
# CRITICAL: This is a DOCUMENTATION subtask. Do NOT touch any .sh / .tmux file, tests, PRD.md,
# tasks.json, .gitignore, or LICENSE. The ONLY file you create is README.md.

# CRITICAL: The README's `### Backends` section must reflect Correction A (empty-on-no-match is
# TRUE now) and `## Scope & compatibility` must reflect NOTE C (set-hook -g overwrites; reload-
# safe). Every OTHER section stays PRD §5.6 verbatim.

# GOTCHA (markdown): fenced code blocks inside the body must open AND close with ``` at column 0.
# The PRD §5.6 raw block (quoted above) is already clean. Do NOT copy from the mdsel/selection
# rendering of §5.6 — it contained nested-fence escaping artifacts (backslashed \~). Use the
# clean block above.

# GOTCHA (license): the README `## License` section is just the word `MIT`. The full MIT text
# lives in the existing `LICENSE` file (Copyright (c) 2026 Dustin Schultz) — do not duplicate it.

# GOTCHA (options count): there are exactly EIGHT @zoxide-sessions-* options. The acceptance
# criterion is "documents every option". The Options table must contain all 8 rows (see table).

# GOTCHA (faithfulness): §5.6 Known limitations has THREE bullets; §8 has FOUR (the extra being
# `readlink -f`/GNU). Per the work-item contract, ship the §5.6 THREE verbatim. Do not silently
# add the fourth.
```

## Implementation Blueprint

### Data models and structure

N/A — pure Markdown, no data models, schemas, or code.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE README.md (repo root)
  - WRITE the PRD §5.6 verbatim body (the full markdown block quoted in
    "The README body" subsection above), then apply the TWO touchpoint edits:
      (a) NOTE C — replace the middle Scope & compatibility bullet with the revised bullet
          (reload-safe set-hook -g + how to combine).
      (b) Correction A — append the empty-on-no-match note after the `auto` Backends bullet.
  - KEEP verbatim everywhere else: title, Why, Install (TPM + manual + prereq para),
    Usage (window jump + session auto-relocate incl. the "$HOME-guard" safety paragraph),
    Options (8-row table + example), Backends (3 bullets + note), Scope & compatibility
    (3 bullets, middle one revised), Known limitations (3 bullets), License (MIT).
  - NAMING: file is `README.md` (exact, uppercase) at the repo root
    (/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions/README.md).
  - PLACEMENT: repo root (sibling of PRD.md, LICENSE, tmux-zoxide-sessions.tmux).
  - NO other files created or modified. No chmod (it is not an executable).

Task 2: SELF-VALIDATE (see Validation Loop) before declaring done
  - Run the grep checks for all 8 options, the $HOME-guard sentence, the NOTE C markers
    (reload-safe / set-hook -g / replaces), and the Correction A marker (empty / no match).
  - Confirm fenced code blocks are balanced (``` count is even).
  - Confirm no source files were touched: `git status --porcelain` shows ONLY `?? README.md`.
```

### Implementation Patterns & Key Details

```markdown
# The entire "implementation" is faithful transcription of PRD §5.6 + two surgical edits.
# There is no logic. The risk is purely editorial (typos, dropped sections, unbalanced fences,
# wrong options count). Mitigate with the grep validation loop below.

# Pattern for the Options table (must have exactly these 8 rows; defaults must match):
#   @zoxide-sessions-key           g
#   @zoxide-sessions-prompt        z to:
#   @zoxide-sessions-backend       auto
#   @zoxide-sessions-z-sh          unset
#   @zoxide-sessions-auto-session  on
#   @zoxide-sessions-home-dir      $HOME
#   @zoxide-sessions-skip-names    home main
#   @zoxide-sessions-window-name   off

# CRITICAL: The "$HOME-guard model" acceptance line is satisfied by THIS sentence in
# ### Session auto-relocate (keep it verbatim from §5.6):
#   "This is safe alongside resurrect/continuum, sessionx, and sesh: those place sessions with
#    an explicit directory, so they never land in `$HOME` and are never touched."
```

### Integration Points

```yaml
# None. README.md is a standalone doc. It is consumed/verified by:
#   - P1.M4.T2.S1 (acceptance: "README documents every option" + the $HOME-guard model).
#   - P1.M4.T3.S1 (final reconcile README <-> shipped behavior).
# It does NOT import, source, or get sourced by anything. No config/routes/db changes.
```

## Validation Loop

There is **no markdown linter installed** in this environment (`markdownlint`, `mdformat`,
`pandoc` are all absent; only `shellcheck` is present, which is irrelevant for a `.md`). So
validation is **grep-based content checks** plus a structural sanity pass. Run each; all must pass.

### Level 1: File existence & scope

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# 1a. README exists at repo root.
test -f README.md && echo "OK: README.md exists" || echo "FAIL: README.md missing"

# 1b. ONLY README.md is new/changed — no source/docs/config files were touched by this subtask.
# Expected output: exactly one line -> "?? README.md"
git status --porcelain
```

### Level 2: All 8 options documented (acceptance criterion)

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# 2a. Every @zoxide-sessions-* option name appears in README.
for opt in key prompt backend z-sh auto-session home-dir skip-names window-name; do
  grep -q "@zoxide-sessions-${opt}" README.md \
    && echo "OK: @zoxide-sessions-${opt}" \
    || echo "FAIL: @zoxide-sessions-${opt} MISSING"
done
# Expected: 8x OK, 0x FAIL.

# 2b. All 8 default values are present.
for d in '`g`' '`z to:`' '`auto`' 'unset' '`on`' '`$HOME`' '`home main`' '`off`'; do
  grep -q "$d" README.md && echo "OK default ${d}" || echo "FAIL default ${d} MISSING"
done
# Expected: 8x OK.
```

### Level 3: The two touchpoints

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# 3a. Touchpoint (a) NOTE C — Scope & compatibility must reflect reload-safe set-hook -g.
grep -qi 'reload-safe' README.md        && echo "OK NOTE-C: reload-safe"      || echo "FAIL NOTE-C: reload-safe MISSING"
grep -qi 'set-hook -g' README.md        && echo "OK NOTE-C: set-hook -g"      || echo "FAIL NOTE-C: set-hook -g MISSING"
grep -qi 'replaces' README.md           && echo "OK NOTE-C: replaces"         || echo "FAIL NOTE-C: replaces MISSING"
grep -qi 'set-hook -ag' README.md       && echo "OK NOTE-C: combine guidance" || echo "FAIL NOTE-C: set-hook -ag MISSING"
# Expected: 4x OK.

# 3b. Touchpoint (b) Correction A — Backends must state empty-on-no-match (now true).
awk '/### Backends/,/^## /' README.md | grep -qi 'no match' \
  && echo "OK CORR-A: no-match wording in Backends" \
  || echo "FAIL CORR-A: no-match wording MISSING from Backends"
awk '/### Backends/,/^## /' README.md | grep -qi 'exit 0' \
  && echo "OK CORR-A: exit-0 contract in Backends" \
  || echo "FAIL CORR-A: exit-0 contract MISSING from Backends"
# Expected: 2x OK.
```

### Level 4: The $HOME-guard model + structural sanity

```bash
cd /home/dustin/.config/tmux/plugins/tmux-zoxide-sessions

# 4a. $HOME-guard model documented (acceptance: "and the $HOME-guard model").
grep -qi 'never land in `$HOME`' README.md \
  && echo "OK: \$HOME-guard sentence present" \
  || echo "FAIL: \$HOME-guard sentence MISSING"

# 4b. Fenced code blocks balanced (even number of ``` at column 0 -> parses as GFM).
fences=$(grep -c '^```' README.md)
[ $((fences % 2)) -eq 0 ] && echo "OK: fences balanced ($fences)" || echo "FAIL: fences UNBALANCED ($fences)"

# 4c. Section headers present (PRD §5.6 faithfulness).
for h in '^# tmux-zoxide-sessions' '^## Why' '^## Install' '^## Usage' '^## Options' '^## Scope & compatibility' '^## Known limitations' '^## License'; do
  grep -qE "$h" README.md && echo "OK header ${h}" || echo "FAIL header ${h} MISSING"
done
# Expected: 8x OK.

# 4d. Manual sanity: render-check by eye — open README.md, confirm the table is a clean pipe
# table and the three Install sub-fences (git clone / run-shell / tmux source) each close.
# (No automated renderer available; a human/DIFF review is the final gate, consumed by
# P1.M4.T3.S1.)
```

## Final Validation Checklist

### Technical Validation

- [ ] Level 1–4 grep checks all print `OK` (no `FAIL` lines).
- [ ] `git status --porcelain` shows **only** `?? README.md` (nothing else touched).
- [ ] Fenced code blocks balanced (`grep -c '^```' README.md` is even).

### Feature Validation

- [ ] All 8 `@zoxide-sessions-*` options present with correct defaults (Level 2).
- [ ] The `$HOME`-guard model sentence is present (Level 4a) — acceptance criterion.
- [ ] Touchpoint (a) NOTE C applied to Scope & compatibility (Level 3a) — reload-safe
      `set-hook -g`, replaces pre-existing global hook, combine via set-after-init / `-ag`.
- [ ] Touchpoint (b) Correction A applied to Backends (Level 3b) — empty-on-no-match + exit 0.
- [ ] README body otherwise faithful to PRD §5.6 (same sections, order, wording, links).

### Code Quality / Scope Validation

- [ ] File is named exactly `README.md` at the repo root.
- [ ] **No** source/script/test/run-file/`PRD.md`/`tasks.json`/`.gitignore`/`LICENSE` changes.
- [ ] Anti-patterns avoided (see below): no source edits, no adding the 4th §8 limitation, no
      nested-fence escaping artifacts, no full MIT text duplicated.

### Documentation & Deployment

- [ ] README is self-contained and renders as GitHub-Flavored Markdown.
- [ ] Install instructions match the shipped run file (`run-shell .../tmux-zoxide-sessions.tmux`).
- [ ] Options table defaults match `scripts/lib/resolve.sh` (`backend` default `auto`), the run
      file (`key` `g`, `prompt` `z to:`, `auto-session` `on`), and `z-session.sh`
      (`home-dir` `$HOME`, `skip-names` `home main`, `window-name` `off`).

---

## Anti-Patterns to Avoid

- ❌ **Don't edit any source file** — this is documentation-only. The run file's `set-hook -g`
  is intentional (reload-safe); NOTE C is resolved in the README, NOT by changing the run file.
- ❌ **Don't add the 4th Known-limitations bullet** (`readlink -f`/GNU). §5.6 has 3; the
  work-item contract says stay faithful to §5.6. Leave §8's 4th bullet to P1.M4.T3.S1 if it
  chooses to reconcile.
- ❌ **Don't copy the README from the mdsel/selection rendering** — it had nested-fence
  escaping artifacts (`\~`, split fences). Use the clean PRD §5.6 block quoted in this PRP.
- ❌ **Don't duplicate the full MIT text** in the README — the `LICENSE` file already holds it;
  the README `## License` section is just `MIT`.
- ❌ **Don't drop or reorder sections**, and don't invent options beyond the 8, to "improve"
  the doc. Faithful to §5.6 is the spec.
- ❌ **Don't claim literal hook composition** ("any user hooks compose fine") — that is the
  inaccurate PRD §5.6/§6.2 wording NOTE C corrects. Use the revised Scope & compatibility bullet.
- ❌ **Don't hedge the `z` backend** ("may return a path on no-match") — Correction A's fix is
  shipped; state plainly that all backends return empty on no-match.

---

## Confidence Score

**9/10** — one-pass success is highly likely: the deliverable is a single Markdown file whose
body is supplied verbatim above, with the only two deviations specified as exact old→new text
blocks, and validation is a concrete grep checklist requiring no tooling beyond `grep`/`git`.
The residual 1/10 risk is purely editorial (typo, dropped section, unbalanced fence) — fully
caught by the Level 1–4 checks.
