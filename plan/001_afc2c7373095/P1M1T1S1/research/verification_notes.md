# Research Notes — P1.M1.T1.S1 (Create file tree + LICENSE)

## Repo state (verified `find .` + `ls -la` at plugin root)
Greenfield. Only these exist:
- `PRD.md` (READ-ONLY — never touch)
- `docs/` (empty dir)
- `.gitignore` (FORBIDDEN to modify)
- `plan/`, `.pi-subagents/` (orchestrator/tooling artifacts)

Confirmed ABSENT: `scripts/`, `scripts/lib/`, `LICENSE`, `*.tmux`, `*.sh`, `README.md`.

## LICENSE text (verified verbatim against PRD.md §5.7 source via `sed`)
- First line: `MIT License`
- Copyright line: `Copyright (c) 2026 Dustin Schultz` (year 2026, name Dustin Schultz)
- Ends with the standard MIT `THE SOFTWARE IS PROVIDED "AS IS"...` block.
- Must be byte-exact. A single trailing newline is conventional/standard.

## File tree (verified against PRD.md §5.1)
This subtask creates ONLY the directory skeleton + LICENSE:
```
scripts/
  lib/           # empty for now — resolve.sh arrives in P1.M1.T2.S1
LICENSE          # at repo root
```
Everything else in §5.1 (resolve.sh, z-window.sh, z-session.sh, *.tmux, README.md) is owned by later subtasks — DO NOT create them here.

## Gotchas
1. **Empty dirs + git:** `scripts/` and `scripts/lib/` will be empty after this subtask. Git does not track empty dirs. Do NOT add a `.gitkeep` (the PRD §5.1 tree shows none, and the contract forbids creating `.sh`/`.tmux` files here — adding unrelated files deviates from the spec). This is safe because the immediately-following subtask `P1.M1.T2.S1` writes `resolve.sh` into `scripts/lib/` before any commit, so the dir gains content.
2. **No chmod here:** there are no executables yet. `chmod +x` is explicitly deferred to `P1.M4.T2.S1`.
3. **CWD:** plugin root = `/home/dustin/.config/tmux/plugins/tmux-zoxide-sessions`. All paths are repo-relative.
4. **Architecture corrections (findings_and_risks.md):** CORRECTION A/B target `P1.M1.T2.S3`/`S4` (resolver code), NOT this scaffolding subtask. No code is written here, so corrections are N/A. Noted only to keep the implementing agent from confusing scope.

## Scope boundaries (do/don't)
- DO: `mkdir -p scripts/lib`; write `LICENSE` verbatim.
- DON'T: create any `.sh`, `.tmux`, `README.md`, `.gitkeep`, or any other file. DON'T touch `.gitignore`, `PRD.md`, `docs/`.
