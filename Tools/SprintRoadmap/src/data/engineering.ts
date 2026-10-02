import type { DocRef } from '../types'

export interface EnTask {
  id: string
  title: string
  klass: string
  disposition: string
  status: string
  source: DocRef[]
}

const D = (path: string): DocRef => ({ path })

export const engineeringBacklog: EnTask[] = [
  {
    id: 'EN-01',
    title: 'HistoryEpoch orientation',
    klass: 'B',
    disposition: 'FIX NOW',
    status: 'SOURCE FIX COMPLETE — RUNTIME GREEN BLOCKED',
    source: [D('docs/Sprint24_EngineeringAudit.md'), D('docs/Sprint24_EN01_Closure.md')],
  },
  {
    id: 'EN-02',
    title: 'Visualization reset-awareness',
    klass: 'B',
    disposition: 'FIX NOW',
    status: 'PENDING',
    source: [D('docs/Sprint24_EngineeringAudit.md'), D('docs/Sprint24_EN02_Closure.md')],
  },
  {
    id: 'EN-03',
    title: 'Trend-flip gate (RESEARCH FIRST)',
    klass: 'B→C',
    disposition: 'RESEARCH FIRST',
    status: 'CLOSURE RECORDED',
    source: [D('docs/Sprint24_EN03_Closure.md')],
  },
  {
    id: 'EN-04',
    title: 'Magic-number stability',
    klass: 'B',
    disposition: 'DEFER',
    status: 'DORMANT',
    source: [D('docs/Sprint24_EngineeringAudit.md')],
  },
  {
    id: 'EN-05',
    title: 'BOSRenderer lifecycle/freeze',
    klass: 'A',
    disposition: 'FIX NOW',
    status: 'PENDING',
    source: [D('docs/Sprint24_EngineeringAudit.md')],
  },
  {
    id: 'EN-06',
    title: 'TradeManager fill reporting',
    klass: 'A',
    disposition: 'FIX NOW',
    status: 'PENDING',
    source: [D('docs/Sprint24_EngineeringAudit.md')],
  },
  {
    id: 'EN-07',
    title: 'Performance & logging',
    klass: 'A',
    disposition: 'DEFER',
    status: 'DORMANT',
    source: [D('docs/Sprint24_EngineeringAudit.md')],
  },
  {
    id: 'EN-08',
    title: 'Dead-code quarantine',
    klass: 'D',
    disposition: 'DEFER (quarantine)',
    status: 'QUARANTINED',
    source: [D('docs/Sprint24_EngineeringAudit.md')],
  },
]

export interface Sprint25Task {
  id: string
  title: string
  status: string
  state: 'SOURCE' | 'COMPILE' | 'RUNTIME' | 'PENDING' | 'CLOSED'
}

export const sprint25Tasks: Sprint25Task[] = [
  {
    id: 'EN-01',
    title: 'HistoryEpoch orientation',
    status: 'SOURCE FIX COMPLETE — RUNTIME GREEN BLOCKED',
    state: 'RUNTIME',
  },
  {
    id: 'EN-02',
    title: 'Visualization reset-awareness',
    status: 'PENDING',
    state: 'PENDING',
  },
  {
    id: 'EN-05',
    title: 'BOSRenderer lifecycle / freeze',
    status: 'PENDING',
    state: 'PENDING',
  },
  {
    id: 'EN-06',
    title: 'TradeManager fill reporting',
    status: 'PENDING',
    state: 'PENDING',
  },
]

export interface Blocker {
  title: string
  detail: string
}

export const currentBlockers: Blocker[] = [
  {
    title: 'EN-01 runtime GREEN verification',
    detail:
      'Source correction exists and compiles, but runtime GREEN verification is blocked by suspected MQL5 .ex5 binary caching/loading behavior. Repo evidence (Sprint25A) disproved stale-binary caching and confirmed a structural source→binary→run identity gap (G1–G9), so the full post-fix TT01 under the identity gates is required before Sprint 25 can close.',
  },
]

export const statusMatrix = {
  source: 'GREEN',
  compile: 'GREEN',
  runtime: 'BLOCKED',
  overall: 'NOT COMPLETE',
} as const
