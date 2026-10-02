import { useState } from 'react'
import type { GraphNode } from '../types'
import { NODES, spineIds } from '../data/sprints'
import { earlyHistory } from '../data/evidence'
import { CATEGORY_META, STATUS_META } from '../theme'

const nodeById = new Map(NODES.map((n) => [n.id, n]))

function section(title: string, items: string[], tone?: 'good' | 'bad' | 'warn') {
  if (!items.length) return null
  return (
    <div>
      <div className="hd-col-title">{title}</div>
      <ul>
        {items.map((it, i) => (
          <li key={i} className={tone}>
            {it}
          </li>
        ))}
      </ul>
    </div>
  )
}

function FactGrid({ node }: { node: GraphNode }) {
  if (!node.facts || !node.facts.length) return null
  return (
    <div className="hd-facts">
      {node.facts.map((f) => (
        <div key={f.label} className="hd-fact">
          <div className="fl">{f.label}</div>
          <div className="fv">{f.value}</div>
        </div>
      ))}
    </div>
  )
}

export default function HistoryList() {
  const [open, setOpen] = useState<string | null>('sprint-25')
  const [copied, setCopied] = useState<string | null>(null)

  const toggle = (id: string) => setOpen((cur) => (cur === id ? null : id))

  const copyPath = async (path: string) => {
    try {
      await navigator.clipboard.writeText(path)
      setCopied(path)
      setTimeout(() => setCopied((c) => (c === path ? null : c)), 1400)
    } catch {
      setCopied(null)
    }
  }

  const rows: GraphNode[] = spineIds.map((id) => nodeById.get(id)!).filter(Boolean)

  return (
    <section>
      <div className="section-head">
        <span className="dot" style={{ background: 'var(--teal)' }} />
        <span className="section-title">History</span>
        <span className="section-count">Sprint 1 → 25</span>
      </div>

      <ul className="h-list">
        <li className={`h-row ${open === 'early-era' ? 'open' : ''}`}>
          <button className="h-row-main" onClick={() => toggle('early-era')}>
            <span className="h-num">1–10</span>
            <span className="h-title dnf">Early history — no planning docs in repo</span>
            <span className="h-cat">Unverified</span>
            <span className="h-status" style={{ color: STATUS_META.UNVERIFIED.color }}>
              UNVERIFIED
            </span>
            <span className="h-chev">›</span>
          </button>
          {open === 'early-era' && (
            <div className="h-detail">
              <p className="hd-summary">
                No sprint-planning or completion documentation exists in the repository for Sprints 1–10. The only
                recoverable record is the git history:
              </p>
              <div className="hd-cols" style={{ gridTemplateColumns: '1fr' }}>
                <div>
                  <div className="hd-col-title">Git-level milestones</div>
                  <ul>
                    {earlyHistory.map((m) => (
                      <li key={m.ref}>
                        <span style={{ color: 'var(--cyan)' }} className="mono">
                          {m.ref}
                        </span>{' '}
                        — {m.label} · {m.note}
                      </li>
                    ))}
                  </ul>
                </div>
              </div>
            </div>
          )}
        </li>

        {rows.map((node) => {
          const isDnf = node.category === 'UNVERIFIED'
          const cat = CATEGORY_META[node.category]
          const st = STATUS_META[node.status]
          const isOpen = open === node.id
          return (
            <li key={node.id} className={`h-row ${isOpen ? 'open' : ''}`}>
              <button className="h-row-main" onClick={() => toggle(node.id)}>
                <span className="h-num">{node.sprint ? `Sprint ${node.sprint}` : node.code}</span>
                <span className={`h-title ${isDnf ? 'dnf' : ''}`}>{node.title}</span>
                <span className="h-cat" style={{ color: cat.color }}>
                  {cat.label}
                </span>
                <span className="h-status" style={{ color: st.color }}>
                  {st.label}
                </span>
                <span className="h-chev">›</span>
              </button>
              {isOpen && (
                <div className="h-detail">
                  <p className="hd-summary">{node.summary}</p>
                  <div className="hd-cols">
                    {section('Completed', node.completed, 'good')}
                    {section('Blocked', node.blocked, 'bad')}
                    {section('Pending', node.pending, 'warn')}
                    {section('Objectives', node.objectives)}
                  </div>
                  <FactGrid node={node} />
                  {node.note && <div className="hd-note">{node.note}</div>}
                  {node.evidence.length > 0 && (
                    <div className="hd-evidence">
                      {node.evidence.map((d) => (
                        <button key={d.path} className="ev-path" onClick={() => copyPath(d.path)} title={copied === d.path ? 'Copied' : 'Copy path'}>
                          {copied === d.path ? '✓ ' : '⧉ '}
                          {d.label ?? d.path}
                        </button>
                      ))}
                    </div>
                  )}
                </div>
              )}
            </li>
          )
        })}
      </ul>
    </section>
  )
}
