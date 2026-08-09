# RH01 - Canonical Relocation Plan (SuperCents_X EA-Rooted)

- **Date:** 2026-08-09
- **Status:** PLAN ONLY - NOTHING EXECUTED, AWAITING APPROVAL
- **Basis:** verified workspace-rooted history (128 commits, `origin/main`=964c51e);
  relocation = single forward commit, no rewrite, no force-push, no filter-repo.

## 1. Migration Plan (exact)

Repo root/worktree/.git stays at `MQL5\Experts\SuperCents_X` (current state).

Tracked `Experts/SuperCents_X/` content (434 files, ALL verified present in the
working folder - 0 missing) relocates to repository root, staged from the
**working originals** (newer versions win over committed copies for `docs/`
[3 files], `Tests/` [13 files], `Tools/`, `.gitignore`; the rest are identical):

```
Relocate to root:  Core/ Structure/ Entry/ Trading/ Risk/ Monitoring/ Production/
  Validation/ Visualization/ Calibration/ Optimization/ Portfolio/ Presets/
  Research/ Knowledge/ Laboratory/ Confluence/ docs/ Tests/ Tools/ Utils/ Providers/
  benchmarks/ Telemetry/ Regression/ RegressionLogs/
  SuperCents_X.mq5  CalibrationRunner.mq5  CHANGELOG.md
Keep at root:      LICENSE  README.md (update)  .gitignore (merged, expanded)
Add:               Validation/Sprint17/  <- Evidence A-items (see section 3)
```

Mechanics:
1. `git rm -r --cached Evidence Files Scripts Tests Experts` - untrack
   workspace-rooted content; nothing deleted from disk.
2. Delete reset-materialized copies `SuperCents_X\Experts\SuperCents_X\` and
   `SuperCents_X\Experts\SmartMoneyEA_v4\` (exact git copies; SmartMoneyEA_v4
   original lives on disk at `MQL5\Experts\SmartMoneyEA_v4`).
3. `git add` each relocated top-level path (from working originals) + Evidence
   A-items + updated README/.gitignore.
4. Review `git status`, commit `relocate: canonical SuperCents_X EA-rooted tree (RH01)`.
5. `git push origin main` - fast-forward (new commit on top of 964c51e), no force.

## 2. Workspace Extras - EXCLUDED (untracked + .gitignore'd, kept on disk)

| Path | Files | Disposition |
|---|---|---|
| `Evidence/` | 68 tracked | untrack (see section 3) |
| `Files/` (baseline txts, Telemetry, Temp) | 2 tracked | untrack, ignore |
| `Scripts/` (RunSprint9.ps1, Scripts/SuperCents_X/) | 3 tracked | untrack, ignore |
| `Tests/CI/` | 1 tracked | untrack, ignore |
| `Experts/SmartMoneyEA_v4/` | 46 tracked | untrack, ignore (stays on disk) |
| compile_*.log / compile_*.txt / *.log at EA root | ~50 | untracked, ignore |
| `Temp/`, `CalibrationRunner.ex5`, `SuperCents_X.ex5`, Data dumps | - | untracked, ignore |

New `.gitignore` rules: `Evidence/`, `Files/`, `Scripts/`, `Tests/CI/`,
`Experts/`, `Temp/`, `/*.log`, `/compile_*.txt`, plus existing rules kept.

## 3. Evidence Classification (Evidence\Sprint17, ~54 MB)

| Item | Size | Class | Action |
|---|---|---|---|
| `manifest/` (sprint17_collection_v1.manifest, SuperCents_X.set) | 12.7 KB | **A** | relocate -> `Validation/Sprint17/manifest/` |
| `reports/` (extract_journal.py, sprint17_collect_stats.py, sprint17_stats.json) | 10 KB | **A** | relocate -> `Validation/Sprint17/reports/` |
| `README.md` | 4.5 KB | **A** | relocate -> `Validation/Sprint17/README.md` |
| `EURUSD_H1/` `EURUSD_M15/` `GBPJPY_H1/` (raw csv/json/txt) | 19.3 MB | **B** | zip -> archive outside repo (e.g. `MQL5\Archives\`), keep on disk |
| `logs/` (.log) | 16.4 MB | **C** | generated - ignore (regenerable) |
| `merged/` (derived csv) | 19 MB | **C** | generated - ignore (re-derivable from raw) |
| none | - | **D** | nothing proposed for deletion |

## 4. Expected Canonical Tree (after commit)

```
SuperCents_X (repo root = EA root)
  .git/  .gitignore  LICENSE  README.md
  CHANGELOG.md  SuperCents_X.mq5  CalibrationRunner.mq5
  Core/ Structure/ Entry/ Trading/ Risk/ Monitoring/ Production/
  Validation/  (+ Sprint17/manifest, Sprint17/reports, Sprint17/README.md)
  Visualization/ Calibration/ Optimization/ Portfolio/ Presets/
  Research/ Knowledge/ Laboratory/ Confluence/ docs/ Tests/ Tools/
  Utils/ Providers/ benchmarks/ Telemetry/ Regression/ RegressionLogs/
  [gitignored, on disk only:] Evidence/ Files/ Scripts/ Tests/CI/ Experts/ Temp/
```

## 5. Notes / Caveats

- Working `Tools/` (593 diffs vs tracked 27) contains untracked/generated
  material - only tracked source (.mqh/.mq5/.py/.md) is staged at root.
- Root `README.md`/`LICENSE` are the workspace copies (reset-overwrite
  possible); README is rewritten as canonical project README, LICENSE kept.
- History untouched: 128 commits preserved, relocation is a normal forward
  commit, push is fast-forward.
- Target after push: `docs/Sprint20_ED01D_Protocol.md` at root (moved by the
  commit, historical commit untouched).

**AWAITING APPROVAL - NOTHING EXECUTED.**
