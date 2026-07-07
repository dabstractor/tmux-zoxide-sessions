# README ↔ Shipped-code drift audit — P1.M4.T3.S1

Method: read README.md in full, diff each work-item-required claim against the
shipped code (scripts/lib/resolve.sh, scripts/z-session.sh, scripts/z-window.sh,
tmux-zoxide-sessions.tmux) and PRD §4/§6/§8, with Corrections A/B and NOTE C from
plan/001_afc2c7373095/architecture/findings_and_risks.md.

## Verdict matrix

| # | Check (work-item requirement) | Verdict | Evidence |
|---|---|---|---|
| 1 | 8 options present, CORRECT defaults (g / 'z to:' / auto / unset / on / $HOME / 'home main' / off) | PASS | README "Options" table rows match PRD §4 verbatim; defaults match get_tmux_option 2nd args in resolve.sh + run file. |
| 2 | $HOME-guard model accurate | PASS | README "Usage → Session auto-relocate": relocates only when session lands in $HOME; matches z-session.sh `[ "$(_norm "$path")" = "$(_norm "$home_dir")" ]` guard. |
| 3 | Coexistence (resurrect/continuum via `-c "$saved_dir"`, sessionx/sesh via `-c`) skipped | PASS | README "Scope & compatibility" bullet 2: "restored via `-c`, skipped" / "placed via `-c`, skipped". |
| 4 | Known limitations COMPLETE: respawn flicker, whitespace skip-names, single home-dir, GNU readlink -f, degenerate restored-$HOME | **DRIFT** | README lists flicker + skip-names + home-dir. MISSING: (a) GNU `readlink -f` limitation (PRD §8 has it); (b) degenerate restored-$HOME case (findings_and_risks.md risk register: "document in README known-limitations"). |
| 5 | Backends description vs Correction A (rupa/z empty on no-match) | PASS | README "Backends" para: "(The `z` backend achieves this by comparing the working directory before and after calling rupa/z's `_z`...)". Matches _resolve_z before/after-pwd delta. |
| 6 | Scope & compatibility reflects NOTE C (reload-safe set-hook -g + how to combine with a user hook) | PASS | README: "reload-safe ... does not stack duplicate hooks. Because `set-hook -g` *replaces* any pre-existing global `session-created` hook ... To combine ... set your hook **after** the TPM init line ... or ... `set-hook -ag`". |
| 7 | "empty + exit 0 on no match" contract | PASS | README: "All three backends return an empty result (and exit 0) when a query has no match; callers check the output, never the exit status." Matches resolve.sh `return 0`. |

## Conclusion — the ONLY drift

The "Known limitations" section is incomplete. Two bullets must be ADDED (no
existing text removed — all three present bullets are accurate and faithful to
PRD §5.6; the PRD §8 limitations list is longer than README's, and the work item
explicitly requires README's list to be complete):

1. **GNU `readlink -f`** — PRD §8 bullet 4, verbatim: symlinked `$HOME` may not
   canonicalize on systems without GNU readlink; falls back to literal path
   comparison (trailing-slash still normalized). Source: scripts/z-session.sh
   `_norm()` uses `readlink -f ... || printf '%s' "$1"`.

2. **Degenerate restored-`$HOME` case** — findings_and_risks.md Risk register:
   "a restored session whose saved pane cwd *was* `$HOME` gets relocated (false
   positive). Arguably desirable; document in README known-limitations." This is
   the consequence of the $HOME-guard model: resurrect restores pane cwd, and if
   the saved cwd was literally `$HOME`, z-session.sh's path guard passes and it
   relocates. Mentioned in the work-item "Known limitations" completeness list.

Everything else in README is faithful to PRD §5.6 and consistent with shipped
v1.0. This is a minimal, surgical doc-only edit — two new bullets in the
"Known limitations" section. No other README section changes.
