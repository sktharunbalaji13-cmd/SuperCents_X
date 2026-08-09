# RH01 — Repository Structure Audit

Status: AUDIT ONLY — no files modified, no commits, no pushes.
Date: 2026-08-09
Audited repository: https://github.com/sktharunbalaji13-cmd/SuperCents_X (origin/main = `bb3a432`)

---

## 1. Executive summary

The premise of a "nested `Experts/SuperCents_X/` on GitHub" does **not** describe the
current `origin/main`. The repository was already re-rooted today during the
"bootstrap" step (`9f7daeb`, merge of the local EA-rooted lineage with the
new GitHub initial commit), and every commit in the current history is
**EA-rooted** — zero commits ever touch `Experts/` or `Evidence/` paths
(`git log --all --oneline -- Experts` = 0 results).

What the audit actually found:

| Fact | Evidence |
|---|---|
| `origin/main` tree = SuperCents_X project **at repository root** | `git ls-tree origin/main` — 36 top-level entries: `Core/ Structure/ Confluence/ ... SuperCents_X.mq5 docs/`; no `Experts/`, no `Evidence/`, no `Scripts/`, no `Files/` |
| `origin/main` is exactly local HEAD | `git rev-parse HEAD origin/main` → both `bb3a43254b4f0371569d73687aa3ee7d428a2cd6`; `git ls-remote origin` → same |
| History fully preserved | 127 commits; all Sprint-20 commits present (ED01-A/B/C/D, GR, VF01/02, TT01, B8, M2) |
| 76 MB `StrategyTester.log` is **NOT** tracked in HEAD and **NOT** on GitHub's tree | tracked tree total = 4.4 MB; largest tracked blob = 6.9 MB CSV; the 76 MB blob exists only in history (added `117e465`, removed `a999ea2`) and on disk |
| The "nested" structure the comparison showed = the **MQL5 terminal workspace folder**, not the repository | workspace root on disk contains `Evidence/`, `Scripts/`, `Tests/CI/`, `Files/`, `Experts/SmartMoneyEA_v4/`, `Experts/SuperCents_X/` — verified via directory listing |

**Bottom line:** the GitHub repo already matches the desired canonical root.
The real remaining problems are local hygiene: `.git` physically sitting in the
MQL5 workspace root, a stale index (48 phantom deletions, 3 genuine uncommitted
edits), 136 untracked files, tracked generated artifacts, a bloated 89.3 MB
object store, and missing `LICENSE`/`README.md`.

---

## 2. How the audit was performed

Read-only commands only. No `git add/rm/reset/rebase/filter-repo/push`, no
working-tree changes.

- `git rev-parse --show-toplevel / --git-dir / --absolute-git-dir`
- `git ls-tree HEAD|origin/main|8954332|9f7daeb|4f95c21|59b06a9 --name-only`
- `git log --all --graph --oneline`, `git reflog -8`, `git rev-list --count`
- `git cat-file -p` on roots/merge commits
- `git ls-files` + `git ls-tree -r -l HEAD` (sizes), `git status --porcelain`
- `git fsck --dangling`, `git ls-remote origin`, `git branch -a`, `git remote -v`
- Disk inventory of the MQL5 workspace root and the project folder

---

## 3. Current Git root and working-directory relationship

| Item | Value |
|---|---|
| `.git` location | `C:\Users\k.tharun balaji\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\.git` (the MetaTrader terminal data folder) |
| Git root as reported by `--show-toplevel` | same MQL5 path |
| Actual project root on disk | `...\MQL5\Experts\SuperCents_X` |
| Tracked tree root | **the project itself** (`Core/`, `Structure/`, … at index root — 434 tracked files) |
| `core.worktree` / `core.bare` | unset / false |

The repository is a terminal-workspace-rooted repo whose **history was rewritten
today to project-root paths**, but the `.git` directory was never moved out of the
workspace and the stale staging index was never refreshed. Consequences:

- `git status` compares the stale index (old workspace paths like
  `Experts/SmartMoneyEA_v4/...`) against the working tree → 48 "deleted" entries
  for files already removed from disk, 3 modified project files (genuine edits),
  136 untracked files (workspace leftovers + project raw artifacts).
- From the terminal's point of view the whole MQL5 folder is a git worktree,
  which is why workspace folders (`Scripts/`, `Include/`, `Evidence/`, …) show up
  in status instead of being invisible.

---

## 4. Why the project is (was) nested under `Experts/SuperCents_X`

Reconstructed timeline (evidence: commit graph, reflog, stale index, dangling objects):

1. **Original repository (pre-2026-08-09):** initialized with the entire MQL5
   terminal workspace as its root (`59b06a9` empty GitHub initial commit →
   workspace-rooted commits). The whole terminal tree was tracked, including
   `Experts/SuperCents_X/`, `Experts/SmartMoneyEA_v4/`, `Scripts/`,
   `Include/`, `Evidence/`, `Files/`, `Tests/CI/`, `Images/`, `Presets/`,
   `Profiles/`. **This is the structure the comparison was based on** — it is
   also exactly the MQL5 workspace folder layout still present on disk.
2. **2026-08-09 "bootstrap SuperCents_X GitHub canonical remote"** (`9f7daeb`):
   - the GitHub repository was deleted and re-created (new empty GitHub initial
     commit `4f95c21`, committer `GitHub <noreply@github.com>`, empty tree);
   - the local history was re-rooted: all paths rewritten from
     `Experts/SuperCents_X/*` → `/*`, everything else pruned, commit chain
     preserved (127 commits, new root `59b06a9` empty initial + GitHub's
     `4f95c21`, merged at `9f7daeb` via `merge origin/main`);
   - pushed → `origin/main` = EA-at-root.
3. **The stale staging index kept the old workspace paths** — this is the only
   place the "nested" structure still exists inside git, plus the local
   `develop` branch / remote-tracking refs (server-side `develop` was deleted
   with the old repo).

Note: `git log --all --oneline -- Evidence` and `-- Experts` both return **0**
results — no commit in the current history contains the nested layout.

---

## 5. Local vs origin/main — classification

`origin/main` == local HEAD (`bb3a432`) — **zero version drift between local
committed state and GitHub**. Everything below is HEAD-tree vs local disk vs
stale index.

### A. Current canonical SuperCents_X files (tracked, 434 files, 4.4 MB)
All project source, tests, docs, tools: `Core/ Structure/ Confluence/ Entry/
Portfolio/ Telemetry/ Visualization/ Trading/ Risk/ Providers/ Production/
Monitoring/ Optimization/ Validation/ Research/ Laboratory/ Knowledge/
Calibration/ benchmarks/ Presets/ Regression/ Tests/ Tools/ docs/`
plus `SuperCents_X.mq5`, `CalibrationRunner.mq5`, `.gitignore`, `CHANGELOG.md`.
Present on GitHub and locally, identical.

### B. Legacy SmartMoneyEA_v4 files
- **GitHub/history:** none — 0 commits touch `Experts/` paths (rewritten out).
- **Local disk:** `MQL5\Experts\SmartMoneyEA_v4` already deleted (Test-Path False).
- **Stale index:** 48 ` D` entries for `Experts/SmartMoneyEA_v4/SmartMoneyEA_X/*`
  (deletions that should simply be finalized by refreshing the index).

### C. Historical evidence to preserve
- The 127-commit chain itself (frozen protocol commits, ED01-A/B/C/D, GR01/02,
  VF01/02, TT01, B8, M2) — verified present in `git log`.
- `RegressionLogs/Sprint12.4/*` (5 small tracked files: Validation.json, Metrics.csv,
  Summary.md, .set, .ini) — historical evidence, keep.
- `Tools/TT01/baseline/telemetry_v4_20260130.csv` (6.9 MB, largest tracked blob)
  — TT01 baseline evidence, keep.
- `Tools/ED01/*` (11 tracked files: analyzers, run batch, probes, results JSONs) — keep.
- The 76 MB `StrategyTester.log` blob remains in history (commits `117e465`,
  `a999ea2`) — preserved whether or not we act; see §7.

### D. Generated / runtime artifacts that should NOT be tracked
- `compile_17_7a_*.log` ×4 — **tracked at project root** → remove from index
  (`git rm --cached`) + ignore `*.log`.
- `Tools/ED01/artifacts/` + `artifacts_6mo_2026-01-05_07-05/` on disk
  (232.1 MB / 225 files) — untracked already; must stay ignored.
- `Tools/ED01/__pycache__/`, `Temp/` (untracked `.py` scratch files, logs),
  `SuperCents_X.log`, `Sprint9_FVGTest.log`, `Sprint10_VisualRegression.log`,
  `CalibrationRunner.log`, `Presets/*.ini` audit/pilot files — untracked.
- Workspace junk at MQL5 root: `compile_log*.txt` ×8, `baseline_v2.8.txt`,
  `Experts/SuperCents_X.zip`, `Experts/Advisors/`, `Experts/Examples/`,
  `Experts/Free Robots/`, `Experts/SmartMoneyEA_X/`, `Scripts/*`, `Include/`,
  `Indicators/`, `Images/`, `Files/`, `Presets/`, `Profiles/`, `Tests/UnitTests/`,
  `Tests/CI/`, `.opencode/` — untracked leftovers of the workspace-rooted era.
- No `.ex5`, `.pyc`, or tester artifacts are tracked (verified: 0 / 0).

### E. Files that exist locally but are missing from GitHub
None — `origin/main` == local HEAD. (Local disk has more files than git, all
untracked, see D.)

### F. Files in GitHub that no longer exist locally
- Nothing tracked is missing from disk except the 48 SmartMoneyEA_v4 files
  (deleted from disk deliberately — "legacy/unrelated", handled via RH01; they
  exist only in the stale index, not in HEAD/GitHub).
- `develop` branch + `remotes/origin/develop` — server-side branch deleted when
  the repo was re-created; local refs are stale (3 commits, empty-tree tip
  `a89dba3` "Release: Market Structure Engine v1.0.1", all merged into main).

### G. Files with possible version drift
- HEAD vs origin/main: **none** (identical SHA `bb3a432`).
- Stale index vs HEAD: 3 project files carry **genuine uncommitted edits**
  (`git diff --stat` vs index): `Tests/unit/TestLiquidityRenderer.mqh` (+25),
  `Visualization/LiquidityRenderer.mqh` (+4),
  `Visualization/VisualizationManager.mqh` (+5). These edits are real worktree
  content not present in any commit — review before any index refresh.

---

## 6. Sprint-20 coverage verification

All Sprint-20 deliverables are in `origin/main` history and at the same revision
as local HEAD. Spot-verified commits: `bb3a432` (ED01-D protocol FROZEN),
`dd7dba4` (prerequisite gate PASSED), `b7441f1` (ED01-C DEFER), `afd5546`
(ED01-B REJECT), `e8aaaef` (ED01-A + B8 floors), `dcc7f69` (VF02 palette parity),
`0bb8664` (TT01 overall pass), plus GR01/GR02 and M2 commits deeper in the chain.
No Sprint-20 file exists on GitHub that is missing locally.

---

## 7. Large-file findings

| Item | Size | Status | Recommendation |
|---|---|---|---|
| `RegressionLogs/Sprint13.5a/StrategyTester.log` (disk) | 79,908,388 B (≈76 MB), 26-07-2026 | **Untracked**, already ignored via `.gitignore` `RegressionLogs/`; **not in HEAD, not on GitHub tree** | Archive on disk (or delete); no git action needed |
| Same blob in history (commits `117e465`, `a999ea2`) | 76 MB | Reachable from `main` → present in GitHub's repo, ~89 MB clone | Purge only with explicit user approval (filter-repo + force-push); **not part of this audit** |
| `Tools/TT01/baseline/telemetry_v4_20260130.csv` | 6,93,386 B | Tracked in HEAD | Keep (TT01 baseline evidence) |
| `.git` object store on disk | 89.3 MB / 2,774 files | — | Will shrink only if history purge is approved |
| `Tools/ED01/artifacts_6mo_2026-01-05_07-05/` + `artifacts/` (disk) | 232.1 MB / 225 files | Untracked | Ignore (`Tools/ED01/artifacts*/`), never commit |

---

## 8. Answers to the audit questions

1. **What is the current Git root?** The MQL5 terminal data folder
   (`...\D0E8209F...\MQL5\.git`), one level above the project.
2. **Why is the project nested under `Experts/SuperCents_X`?** It never is, in
   the current history. The original (pre-bootstrap, 2026-08-09) repository
   tracked the whole terminal workspace, which produced the nested layout the
   comparison saw; the "bootstrap" merge re-rooted all 127 commits to
   project-root paths and pruned the workspace. Only the stale local index and
   the disk workspace still show the old shape.
3. **What should the final repository root be?** The SuperCents_X project root —
   **already the case on `origin/main`**. Residual gap vs desired layout:
   `LICENSE` and `README.md` are missing (`.gitignore` present).
4. **Exact files/directories to move:** only `.git` (directory) from
   `MQL5\.git` → `MQL5\Experts\SuperCents_X\.git`. No file moves are needed —
   the tracked tree is already project-rooted; the project folder itself is the
   canonical root.
5. **Exact files/directories to delete (from the index, not disk):**
   `compile_17_7a_CalibrationRunner.log`, `compile_17_7a_SuperCents_X.log`,
   `compile_17_7a_TestRunner.log`, `compile_17_7a_TestRunnerEA.log`
   (`git rm --cached` + `.gitignore`). Stale refs: local `develop`,
   `remotes/origin/develop`.
6. **Exact items to preserve as historical evidence:** the full 127-commit
   chain, `RegressionLogs/Sprint12.4/*`, `Tools/TT01/baseline/*`, `Tools/ED01/*`,
   `docs/*`, all research/decision docs. Do NOT delete from disk anything
   currently ignored unless separately approved.
7. **Exact generated artifacts to ignore (`.gitignore` additions):**
   `*.log`, `Tools/ED01/artifacts*/`, `Tools/ED01/__pycache__/`, `Temp/`,
   `.opencode/`, `*.ex5`, `Presets/*.ini` (keep `.set`), `*compile_log*.txt`.
   Once `.git` moves into the project, the entire MQL5 workspace
   (`Scripts/ Include/ Indicators/ Evidence/ Files/ Images/ Presets/ Profiles/
   Tests/ …`) becomes outside the repo automatically and needs no rules.
8. **Large-file findings:** see §7. The 76 MB log is disk-only + history-only;
   it is not on GitHub's current tree. Purge decision deferred.
9. **Version drift:** none between `origin/main` and local HEAD. Three files
   have genuine uncommitted edits (review before reset).
10. **Safe migration strategy:** (1) review the 3 modified files, commit or
    discard; (2) move `.git` into the project folder; (3) refresh the index
    (`git read-tree HEAD` / `git reset` equivalent) — this makes the 48 phantom
    deletions and 136 untracked workspace files vanish from status;
    (4) `git rm --cached` the 4 compile logs + expand `.gitignore`;
    (5) add `LICENSE` + `README.md`; (6) delete stale `develop` refs;
    (7) TT01/compile verification; (8) forward-only commit + push. No history
    rewrite is required for the structure.
11. **Is a subtree migration required?** No. The tree is already project-rooted.
12. **Can Git history remain intact?** Yes — it already is (127 commits,
    byte-preserved lineage, re-rooted at the bootstrap merge). No rewrite,
    no force-push needed for the normalization.
13. **Verification plan after normalization:** `git status` clean; `git fsck`
    healthy; fresh clone of `origin/main` shows exactly the 36-entry root with
    `LICENSE` + `README.md`; TT01 compile gate; `git ls-remote` shows only
    `main`.

---

## 9. Open decisions for the user (nothing executed)

1. Review the 3 uncommitted file edits (LiquidityRenderer /
   VisualizationManager / TestLiquidityRenderer) — commit, or discard?
2. `LICENSE` type (MIT recommended) and whether to add `README.md` now.
3. 76 MB log: keep on disk archived vs delete; purge from history requires an
   explicit, separate approval (filter-repo + force-push) — out of scope here.
4. Delete local `develop` + stale `origin/develop` refs (server-side already gone).
5. `Tools/ED01/artifacts_6mo_2026-01-05_07-05` (232 MB): keep on disk as the
   pre-registered 6-month evidence archive; ensure it stays ignored.

## 10. Deliberately not done (audit integrity)

No commits, no pushes, no index changes, no file moves, no `git reset`, no
rewrite, no branch deletion. This document itself is uncommitted.
