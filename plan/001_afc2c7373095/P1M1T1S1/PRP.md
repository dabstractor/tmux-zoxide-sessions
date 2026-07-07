# PRP — P1.M1.T1.S1: Create file tree + LICENSE

## Goal

**Feature Goal**: Establish the repository directory skeleton (`scripts/`, `scripts/lib/`) and place the MIT `LICENSE` at the repo root, exactly as specified in PRD §5.1 and §5.7. This is the first subtask of a greenfield tmux plugin; it creates the empty structure that all subsequent subtasks fill in.

**Deliverable**: Two empty directories (`scripts/`, `scripts/lib/`) and one file (`LICENSE`) at the plugin root, with `LICENSE` containing the **verbatim** MIT text from PRD §5.7.

**Success Definition**:
- `scripts/` and `scripts/lib/` exist as directories.
- `LICENSE` exists at the repo root.
- `LICENSE` is byte-for-byte identical to PRD §5.7's LICENSE block (year `2026`, holder `Dustin Schultz`).
- No other files are created (no `.sh`, `.tmux`, `README.md`, `.gitkeep`, etc.).
- `.gitignore` and `PRD.md` are untouched.

## User Persona

**Target User**: The implementing AI agent (subtask executor) and, downstream, future subtasks `P1.M1.T2.S1` (writes `scripts/lib/resolve.sh`) onward.

**Use Case**: Repo scaffolding — the very first commit-able structure so that later subtasks have well-known target paths to write into.

**Pain Points Addressed**: Eliminates ambiguity about where `resolve.sh`, `z-window.sh`, etc. must live by creating the canonical directory layout first.

## Why

- This is subtask #1 of a greenfield repo (only `PRD.md` + empty `docs/` exist). Every later subtask assumes `scripts/lib/` exists.
- `LICENSE` is a legal/identification artifact required for the §9 acceptance criteria ("All 6 files exist at the paths in §5.1") and for public GitHub publication (`dabstractor/tmux-zoxide-sessions`).
- Establishing structure first keeps subsequent subtasks independent and parallelizable.

## What

User-visible behavior: none (no runtime behavior — this is pure scaffolding). The artifact is purely files-on-disk.

### Success Criteria

- [ ] `scripts/` directory exists.
- [ ] `scripts/lib/` directory exists.
- [ ] `LICENSE` exists at repo root.
- [ ] `diff <(sed -n '/^MIT License$/,/^SOFTWARE\.$/p' LICENSE) <(sed -n '/### 5.7.*LICENSE/,/^\*\*\*$/p' PRD.md | sed -n '/^MIT License$/,/^SOFTWARE\.$/p')` produces no diff (LICENSE matches PRD §5.7 verbatim).
- [ ] No `.sh`, `.tmux`, `README.md`, or `.gitkeep` files were created.
- [ ] `.gitignore` and `PRD.md` are unmodified (`git status` shows no changes to them).

## All Needed Context

### Context Completeness Check

If someone knew nothing about this codebase, would they have everything needed to implement this successfully? **Yes.** The LICENSE text is reproduced verbatim below; the directory paths are exact; the CWD is the plugin root; and the "do not create" list is explicit. No codebase knowledge beyond this PRP is required.

### Documentation & References

```yaml
# MUST READ
- file: PRD.md
  why: Source of truth for the exact LICENSE text (§5.7) and the target file tree (§5.1).
  section: "§5.1 File tree, §5.7 LICENSE"
  critical: "LICENSE must be byte-exact to §5.7. Do NOT paraphrase, reflow, or modernize the MIT text."

- file: plan/001_afc2c7373095/architecture/findings_and_risks.md
  why: Documents validated corrections to LATER subtasks (CORRECTION A/B for resolve.sh).
  critical: "Those corrections target P1.M1.T2.S3/S4, NOT this scaffolding subtask. This subtask writes NO code, so corrections are N/A here. Included only to prevent scope confusion."
  section: "CORRECTION A, CORRECTION B"

- file: .gitignore
  why: Confirms what is already ignored; MUST NOT be modified (forbidden by contract).
  critical: "Do not add scripts/, LICENSE, or anything else to .gitignore. It is orchestrator/human-owned."

- docfile: plan/001_afc2c7373095/P1M1T1S1/research/verification_notes.md
  why: Verification log: repo state, verbatim LICENSE capture, gotchas.
  section: "LICENSE text, Gotchas"
```

### Current Codebase tree

```bash
$ pwd
/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions   # CWD = plugin root

$ find . -not -path './.git/*' -not -path './.git' -not -path './.pi-subagents/*' | sort
.
./docs                       # empty
./.gitignore
./plan/001_afc2c7373095/...  # orchestrator artifacts (PRP, tasks.json, architecture/, prd_snapshot.md)
./PRD.md
# scripts/ — ABSENT   LICENSE — ABSENT
```

### Desired Codebase tree (this subtask's delta)

```bash
tmux-zoxide-sessions/        # repo root (CWD)
  scripts/                   # NEW — empty directory
    lib/                     # NEW — empty directory (resolve.sh arrives in P1.M1.T2.S1)
  LICENSE                    # NEW — verbatim MIT text from PRD §5.7
```

Everything else in PRD §5.1 (`resolve.sh`, `z-window.sh`, `z-session.sh`, `tmux-zoxide-sessions.tmux`, `README.md`) is owned by later subtasks — **do not create them here.**

### Known Gotchas of our codebase & Library Quirks

```sh
# CRITICAL: LICENSE must be byte-exact to PRD §5.7.
#   - Copyright line is: "Copyright (c) 2026 Dustin Schultz"  (year 2026, NOT current year)
#   - Do not reflow/paraphrase. Copy the block verbatim (below).

# GOTCHA: Git does not track empty directories.
#   scripts/ and scripts/lib/ will be empty after this subtask. Do NOT add a .gitkeep:
#   the PRD §5.1 tree shows none, and the contract forbids creating .sh/.tmux (and
#   creating unrelated placeholder files deviates from spec). This is safe because the
#   immediately-following subtask P1.M1.T2.S1 writes resolve.sh into scripts/lib/
#   before any commit, so the dir gains tracked content.

# GOTCHA: No chmod here. There are no executables yet. chmod +x is explicitly deferred
#   to P1.M4.T2.S1.

# FORBIDDEN: Do NOT modify .gitignore (human/orchestrator-owned).
# FORBIDDEN: Do NOT modify PRD.md (read-only).
# FORBIDDEN: Do NOT create any .sh, .tmux, README.md, or .gitkeep file in this subtask.
```

## Implementation Blueprint

### Data models and structure

N/A — no code, no schemas. The only structured artifact is the LICENSE text.

### Implementation Tasks (ordered by dependencies)

```yaml
Task 1: CREATE directory skeleton
  - COMMAND: mkdir -p scripts/lib
  - RESULT: scripts/ and scripts/lib/ exist (empty)
  - GOTCHA: do not create any files inside them; do not add .gitkeep
  - PLACEMENT: repo-relative, from the plugin root (CWD)

Task 2: CREATE LICENSE at repo root (verbatim MIT)
  - FILE: ./LICENSE
  - CONTENT: the EXACT block below (PRD §5.7, verbatim). Ends with a single trailing newline.
  - GOTCHA: copyright year is 2026; holder is "Dustin Schultz". Do not alter.
  - PLACEMENT: repo root (not inside scripts/)

Task 3: VERIFY (do not modify anything during verification)
  - RUN: test -d scripts && test -d scripts/lib && test -f LICENSE
  - RUN: head -2 LICENSE   # expect "MIT License\n\nCopyright (c) 2026 Dustin Schultz"
  - RUN: grep -c 'Copyright (c) 2026 Dustin Schultz' LICENSE   # expect 1
  - RUN: git status --short   # confirm only LICENSE + (untracked) scripts/ appear;
                              # PRD.md and .gitignore must NOT show as modified
```

### Verbatim LICENSE content (copy exactly into ./LICENSE)

```
MIT License

Copyright (c) 2026 Dustin Schultz

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

> Implementing agent: write the block above to `./LICENSE` exactly, including the blank lines and a single trailing newline after `SOFTWARE.`. Do not prepend or append anything.

### Implementation Patterns & Key Details

No code patterns apply. The only pattern is "verbatim copy from a spec" — the failure mode is paraphrasing or "fixing" the year/holder, which must NOT happen.

### Integration Points

```yaml
FILESYSTEM:
  - create: "scripts/        (directory, empty)"
  - create: "scripts/lib/    (directory, empty)"

NO DATABASE / CONFIG / ROUTES / BUILD CHANGES:
  - This subtask touches only the filesystem (two mkdir, one file write).
  - .gitignore: UNCHANGED (forbidden).
  - PRD.md: UNCHANGED (read-only).
  - No executable bits set (deferred to P1.M4.T2.S1).

DOWNSTREAM CONSUMER:
  - P1.M1.T2.S1 writes scripts/lib/resolve.sh into the scripts/lib/ created here.
```

## Validation Loop

This is a pure-scaffolding subtask with no runtime, no tests, no build. Validation is filesystem + content checks only.

### Level 1: Existence & Structure (Immediate)

```bash
# Run from the plugin root (CWD).
test -d scripts           && echo "scripts/ OK"      || echo "scripts/ MISSING"
test -d scripts/lib       && echo "scripts/lib/ OK"  || echo "scripts/lib/ MISSING"
test -f LICENSE           && echo "LICENSE OK"        || echo "LICENSE MISSING"
test ! -e scripts/lib/resolve.sh && echo "no stray .sh OK" || echo "ERROR: created forbidden file"
```
Expected: all four "OK", no errors.

### Level 2: LICENSE Content (Verbatim Check)

```bash
# Line count and key markers (sanity).
wc -l LICENSE                      # expect 21 lines (MIT standard) + trailing newline
head -1 LICENSE                    # expect: MIT License
sed -n '3p' LICENSE                # expect: Copyright (c) 2026 Dustin Schultz
tail -1 LICENSE                    # expect: SOFTWARE.

# Diff LICENSE against the authoritative source block inside PRD.md §5.7.
diff <(sed -n '/^MIT License$/,/^SOFTWARE\.$/p' LICENSE) \
     <(awk '/### 5.7 .*LICENSE/{f=1;next} /^\*\*\*$/{f=0} f' PRD.md \
        | sed -n '/^```$/,/^```$/p' | sed '1d;$d' \
        | sed -n '/^MIT License$/,/^SOFTWARE\.$/p') \
  && echo "LICENSE matches PRD §5.7 verbatim" \
  || echo "LICENSE MISMATCH — fix before proceeding"
```
Expected: "LICENSE matches PRD §5.7 verbatim", zero diff lines.
(If the awk pipeline is awkward on a given machine, the simpler authoritative check is: the LICENSE first line is `MIT License`, line 3 is `Copyright (c) 2026 Dustin Schultz`, and the SHA/byte count matches a fresh paste of the block in "Verbatim LICENSE content" above.)

### Level 3: Scope Boundary (Nothing Forbidden Created/Modified)

```bash
# Confirm no forbidden side effects.
git status --short
# Expect to see only:
#   ?? LICENSE
#   (scripts/ may not even appear as untracked if empty, because git ignores empty dirs — that is FINE)
# CRITICAL: PRD.md and .gitignore must NOT appear as modified.

git diff --name-only              # expect: empty (no tracked file modified)
test -z "$(git diff --name-only)" && echo "no tracked files modified OK" || echo "ERROR: tracked file modified"

# Confirm no stray plugin files were created.
find . -not -path './.git/*' -not -path './.pi-subagents/*' -not -path './plan/*' \
       \( -name '*.sh' -o -name '*.tmux' -o -name 'README.md' -o -name '.gitkeep' \) -print
# Expect: no output.
```
Expected: no tracked-file modifications; no stray `.sh`/`.tmux`/`README.md`/`.gitkeep`.

### Level 4: N/A

No runtime, integration, performance, or security validation applies to a scaffolding+LICENSE subtask. Skipped intentionally.

## Final Validation Checklist

### Technical Validation

- [ ] `test -d scripts && test -d scripts/lib` passes.
- [ ] `test -f LICENSE` passes.
- [ ] LICENSE matches PRD §5.7 verbatim (Level 2 diff is empty).
- [ ] LICENSE copyright line is exactly `Copyright (c) 2026 Dustin Schultz`.
- [ ] No `.sh`, `.tmux`, `README.md`, or `.gitkeep` created (Level 3 find is empty).
- [ ] `git diff --name-only` is empty — no tracked file (incl. `.gitignore`, `PRD.md`) modified.

### Feature Validation

- [ ] Both success criteria from "What" met.
- [ ] Directory skeleton matches the `scripts/` + `scripts/lib/` portion of PRD §5.1.
- [ ] LICENSE placed at repo root (not nested).
- [ ] Empty directories are acceptable as-is (no `.gitkeep` hack) because P1.M1.T2.S1 populates them next.

### Code Quality Validation

- [ ] No code written (N/A) — but no anti-patterns introduced (no placeholder files, no chmod, no .gitignore edits).
- [ ] File placement matches desired codebase tree exactly.

### Documentation & Deployment

- [ ] LICENSE is self-documenting (legal text). No README authored here (owned by P1.M4.T1).
- [ ] No new environment variables or config (N/A).

---

## Anti-Patterns to Avoid

- ❌ Don't "modernize" the MIT text or change the year to the current year — it must be `2026`.
- ❌ Don't add a `.gitkeep` to make empty dirs trackable — the spec shows none, and the dir is populated by the next subtask.
- ❌ Don't create placeholder/stub `.sh` or `.tmux` files "to be helpful" — later subtasks own their exact contents.
- ❌ Don't run `chmod +x` on anything — there are no executables yet; that is P1.M4.T2.S1's job.
- ❌ Don't modify `.gitignore` or `PRD.md`.
- ❌ Don't reflow the LICENSE to a different line width — copy it byte-exact.

---

## Scope Boundaries (explicit)

| Item | This subtask (S1) | Later subtasks |
| --- | --- | --- |
| `scripts/`, `scripts/lib/` dirs | ✅ CREATE (empty) | — |
| `LICENSE` | ✅ CREATE (verbatim MIT) | — |
| `scripts/lib/resolve.sh` | ❌ DO NOT | P1.M1.T2.S1–S4 |
| `scripts/z-window.sh` | ❌ DO NOT | P1.M2.T1.S1 |
| `scripts/z-session.sh` | ❌ DO NOT | P1.M3.T1.S1 |
| `tmux-zoxide-sessions.tmux` | ❌ DO NOT | P1.M2.T2.S1, P1.M3.T2.S1 |
| `README.md` | ❌ DO NOT | P1.M4.T1.S1 |
| `chmod +x` | ❌ DO NOT | P1.M4.T2.S1 |
| `.gitignore` / `PRD.md` | ❌ FORBIDDEN (read-only/human-owned) | — |

---

**Confidence Score: 10/10** — Trivial, fully-specified scaffolding task. The LICENSE text is reproduced verbatim in this PRP, paths are exact, CWD is confirmed, and the forbidden-action list is explicit. One-pass success is essentially guaranteed if the implementing agent copies the LICENSE block byte-exact and creates nothing else.
