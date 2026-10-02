import type { DocRef } from '../types'

export interface EvidenceItem {
  id: string
  title: string
  role: string
  status: string
  outcome: string
  relationship: string
  doc: DocRef
  tags: string[]
}

const D = (path: string, label?: string): DocRef => ({ path, label })

export const evidenceChain: EvidenceItem[] = [
  {
    id: 'ED01-A',
    title: 'Admission-Floor Sensitivity Screening',
    role: 'First ED01 research letter — admission floors',
    status: 'CLOSED — KEEP B8 floors',
    outcome:
      '63/63 runs; all 12 gated grid points KEEP. Key architectural finding: confidence is discrete, so floors act as switches, not filters.',
    relationship: 'Retained B8 floors become the baseline for every later ED01 comparison.',
    doc: D('docs/Sprint20_ED01_Decision.md'),
    tags: ['ED01-A', 'admission floor', 'B8'],
  },
  {
    id: 'ED01-B',
    title: 'Liquidity vs Non-Liquidity Conditional Expectancy',
    role: 'Family-conditioned expectancy test',
    status: 'REJECT — NO DISTINCT LIQUIDITY EDGE',
    outcome:
      'Primary EURUSD_H1 Δ −0.1164 clears the 0.10R materiality bar but the 95% CI [−0.2006, +0.0950] includes 0 → pre-registered CI gate fails → REJECT.',
    relationship: 'Feeds the ED01-C design constraint: no further liquidity-floor tuning.',
    doc: D('docs/Sprint20_ED01B_Decision.md'),
    tags: ['ED01-B', 'liquidity', 'reject'],
  },
  {
    id: 'ED01-C',
    title: 'Within-Family Discrete Confidence-Level Expectancy',
    role: 'Confidence-granularity test (FVG HIGH vs LOW)',
    status: 'DEFER',
    outcome:
      'Primary EURUSD_H1 Δ +0.0262 but closed-row paired days 7 < 10 → CI unavailable → DEFER per ladder. Point estimate far below 0.10R materiality.',
    relationship: 'Hypothesis stays open only under protocol §13 reopen conditions; ED01-D re-scoped to TP logic.',
    doc: D('docs/Sprint20_ED01C_Decision.md'),
    tags: ['ED01-C', 'confidence', 'defer'],
  },
  {
    id: 'ED01-D',
    title: 'TP Resolution — Opposing-Liquidity vs Fixed-RR',
    role: 'Exit-target logic test',
    status: 'EVIDENCE FOR DISTINCT TP EXPECTANCY (FIXED-RR BETTER)',
    outcome:
      'Requires the outcome simulator to distinguish TARGET_OPPOSING_LIQUIDITY from the legacy fixed-RR path (prerequisite engineering gate).',
    relationship: 'Confirms fixed-RR TP as the exit methodology carried into ED01-E.',
    doc: D('docs/Sprint20_ED01D_Decision.md'),
    tags: ['ED01-D', 'take profit', 'opposing liquidity'],
  },
  {
    id: 'ED01-E',
    title: 'Fixed-RR TP Tier Sweep',
    role: 'Exit-distance benchmark',
    status: 'REJECT / 2.0R REMAINS BEST',
    outcome:
      '15/15 runs; max |Δ Mean R| = 0.0309R (2.5R) — below the 0.10R materiality bar; all CIs include 0. 2.0R established as the empirical fixed-RR benchmark.',
    relationship: 'Establishes the 2.0R benchmark that Sprint 22 RL-HYP-01 measures against.',
    doc: D('docs/Sprint20_ED01E_Decision.md'),
    tags: ['ED01-E', '2.0R', 'benchmark', 'reject'],
  },
  {
    id: 'S21',
    title: 'Sprint 21 — Literature Review (RL01)',
    role: 'Hypothesis selection',
    status: 'COMPLETED',
    outcome:
      'Evidence ledger (64 claim rows), Phase 3 synthesis, Phase 4 shortlist: exactly one candidate seed RL-HYP-01 (NOT-SELECTED).',
    relationship: 'Seeds the first RL01 hypothesis execution in Sprint 22.',
    doc: D('docs/Sprint21_Experiment_Shortlist.md'),
    tags: ['Sprint 21', 'RL01', 'shortlist', 'RL-HYP-01'],
  },
  {
    id: 'S22',
    title: 'Sprint 22 — RL-HYP-01 Experiment',
    role: 'First RL01 hypothesis execution',
    status: 'REJECT / NOT SUPPORTED',
    outcome:
      'Swing-significance admission gate: max |Δ| 0.0261R (K2P0) below 0.10R materiality; every CI includes 0. Clean null, admissible 12/12 run set.',
    relationship: 'Clean null closes the seeded hypothesis; feeds the Sprint 23 venue assessment.',
    doc: D('docs/Sprint22_RL_HYP_01_Decision.md'),
    tags: ['Sprint 22', 'RL-HYP-01', 'reject', 'null'],
  },
  {
    id: 'S23',
    title: 'Sprint 23 — Research Venue Assessment',
    role: 'Decision gate on the next experiment',
    status: 'CLOSED — NO EXPERIMENT JUSTIFIED',
    outcome:
      'RL-CONFLICT-01 NO EXPERIMENT; RL-OBS-01 NOT PROMOTED; RL-HYP-01 PARKED. Research chain at a terminal boundary.',
    relationship: 'Terminal state of the evidence chain; engineering audit (Sprint 24) opens next.',
    doc: D('docs/Sprint23_Closure.md'),
    tags: ['Sprint 23', 'no experiment', 'parked'],
  },
]

export interface EarlyMilestone {
  label: string
  ref: string
  note: string
}

export const earlyHistory: EarlyMilestone[] = [
  { label: 'Initial commit', ref: '59b06a9', note: 'Repository bootstrap.' },
  { label: 'Market Structure Engine v1.0', ref: '4b23b3a', note: 'Commit message labels "Sprint 5.1.12"; no sprint-planning docs exist.' },
  { label: 'v0.8.0 execution pipeline', ref: '566741b', note: 'Market BUY/SELL execution pipeline.' },
  { label: 'v0.9.0 FVG freeze', ref: '60bc326', note: 'Fair Value Gap detector frozen.' },
  { label: 'v1.0 structural engine freeze', ref: 'ead8765', note: 'Swing, BOS, CHOCH, OB, FVG, Liquidity frozen.' },
  { label: 'v1.0.1 release', ref: 'a89dba3', note: 'Capability baseline.' },
  { label: 'Capability Releases 2.3–2.6', ref: 'a701c9c..9e7618e', note: 'Trading / Research / Production / Knowledge enhancements.' },
  { label: 'v2.7 / v2.8 confluence engine', ref: 'v2.8-confluence-engine', note: 'Modular evaluator architecture.' },
]
