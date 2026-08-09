# RH01 - Git State Investigation

- **Date:** 2026-08-09
- **Severity:** High (blocker for canonical repo restructure)
- **Status:** INVESTIGATION COMPLETE - AWAITING USER DECISION

## Brief

The repository at `MQL5` was investigated to explain an apparent contradiction:
the original audit observed an EA-rooted tree (36 top-level entries, 434 tracked
files, `docs/` at root) for `HEAD`/`origin/main`, while the user's direct
observation of GitHub and all subsequent verifications show a workspace-rooted
tree (`.gitignore`, `Evidence`, `Experts`, `Files`, `LICENSE`, `README.md`,
`Scripts`, `Tests`).

## Checks Run (all verified 2026-08-09)

1. `git rev-parse --git-dir` - one repository, previously `MQL5\.git`, moved to
   `SuperCents_X\.git` during the session (reversible).
2. Tree of every commit - verified immutable, content-addressed:
   - `dd7dba4` (bootstrap): `.gitignore Evidence Experts Files README.md Scripts Tests`
   - `9f7daeb` (merge): same 8-entry layout
   - `bb3a432` (protocol): same 8-entry layout (557 files)
   - `964c51e` (VF01): same 8-entry layout
   - `origin/main` = `964c51e` (verified via `git ls-remote`)
3. Object store integrity: 2725 loose objects (89 MB), physical count matches
   `count-objects`; `git fsck --full` clean (dangling blobs only); key objects
   timestamped at their commit times (13:52:50, 14:18:12) - no re-creation.
4. No second Git database: recursive search of `MQL5` found only this `.git`;
   no alternates, no worktrees, no replace refs, no grafts, no shallow file,
   no junctions/symlinks, no `GIT_*` environment redirection.
5. Reflog continuous 12:46 -> 14:20 with no gap covering the audit window.
6. Remote reachability: `git ls-remote origin` returns `964c51e` (cached
   credentials). GitHub API returns 404 because the repo is **private**, not
   because it is missing.

## Findings

1. **There is exactly one repository, and it has always been workspace-rooted.**
   The user's original direct observation of GitHub (Evidence/, Experts/, Files/
   at repo root) was correct.
2. **The audit's EA-rooted observations are not reproducible and are
   impossible in this object store.** Trees are content-addressed and immutable:
   tree `16d4b47c...` (bb3a432) provably contains the 8-entry workspace tree and
   was written at 13:52:50, before the audit ran. No mechanism in Git could make
   `ls-tree` report 36 EA entries for it, then later report 8.
3. The audit was internally inconsistent: its `git status` output showed
   workspace paths (`D Experts/SmartMoneyEA_v4/...`), while its `ls-tree`
   output showed EA paths. Both cannot describe the same index and object store.
4. Conclusion: the audit's tree-level observations (36 entries, 434 files,
   EA-rooted `origin/main`) were **erroneous** and are void per protocol
   (directly observed reality supersedes secondary sources). The protocol doc is
   confirmed committed at `Experts/SuperCents_X/docs/Sprint20_ED01D_Protocol.md`
   (bb3a432), and the VF01 files at `Experts/SuperCents_X/Visualization/` (964c51e).

## Current Verified State

- Repo root (worktree + .git): `MQL5\Experts\SuperCents_X`
- HEAD = `964c51e` (workspace-rooted, 557 files)
- `origin/main` = `964c51e` (already pushed; GitHub matches)
- Working tree: reset materialized the workspace tree inside `SuperCents_X`
  (Evidence/, Files/, Scripts/, Tests/, README.md, LICENSE, .gitignore,
  Experts\SuperCents_X\, Experts\SmartMoneyEA_v4 restored); original EA content
  (Core/, Structure/, docs/, Visualization/, Data/, Tests/) still present
  untracked. `git status` = 127 lines (untracked EA content + copies).
- MQL5-root originals (Evidence/, Files/, Scripts/, Tests/, README.md, LICENSE,
  .gitignore) untouched on disk.

## Next Steps (forward relocation - no history rewrite, no force push)

1. Restore clean state: delete the reset-materialized workspace copies inside
   `SuperCents_X` (originals exist at MQL5 root).
2. `git rm -r Experts/SuperCents_X Experts/SmartMoneyEA_v4` (index) and
   `git rm -r --cached` top-level workspace extras.
3. `git add` the EA-rooted content at `SuperCents_X` root (Core/, Structure/,
   docs/, Visualization/, Data/, Tests/, CHANGELOG.md, README.md).
4. Commit "relocate: EA-rooted canonical tree" - fast-forward onto `964c51e`.
5. `git push origin main` (fast-forward, no force needed).

**Decision needed from user:** keep or drop the workspace extras (Evidence/,
Files/, Scripts/, Tests/, SmartMoneyEA_v4, LICENSE) from the canonical repo?

**Nothing committed. Awaiting approval.**
