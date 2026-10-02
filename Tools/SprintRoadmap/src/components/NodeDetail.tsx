import { useState } from 'react'
import type { GraphNode } from '../types'
import { CATEGORY_META, STATUS_META } from '../theme'

interface NodeDetailProps {
  node: GraphNode
  onClose: () => void
}

export default function NodeDetail({ node, onClose }: NodeDetailProps) {
  const [copied, setCopied] = useState<string | null>(null)
  const cat = CATEGORY_META[node.category]
  const st = STATUS_META[node.status]

  const copyPath = async (path: string) => {
    try {
      await navigator.clipboard.writeText(path)
      setCopied(path)
      setTimeout(() => setCopied((c) => (c === path ? null : c)), 1400)
    } catch {
      setCopied(null)
    }
  }

  const list = (title: string, items: string[], tone?: 'good' | 'bad' | 'warn') => {
    if (!items.length) return null
    return (
      <div className="dc-col">
        <div className="dc-col-title">{title}</div>
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

  return (
    <div className="detail-card">
      <div className="dc-head">
        <span className="dot" style={{ width: 9, height: 9, borderRadius: '50%', background: cat.color, flex: 'none' }} />
        <div className="dc-title">
          {node.sprint ? `Sprint ${node.sprint}` : node.title}
          <span className="dc-code">
            {node.code ?? node.id} · {cat.label} · <span style={{ color: st.color }}>{st.label}</span>
          </span>
        </div>
        <button className="dc-close" onClick={onClose} aria-label="Close detail">
          ×
        </button>
      </div>
      <p className="dc-summary">{node.summary}</p>
      <div className="dc-cols">
        {list('Completed', node.completed, 'good')}
        {list('Blocked', node.blocked, 'bad')}
        {list('Pending', node.pending, 'warn')}
        {list('Objectives', node.objectives)}
      </div>
      {node.facts && node.facts.length > 0 && (
        <div>
          <div className="dc-col-title">Key facts</div>
          <div className="dc-facts">
            {node.facts.map((f) => (
              <div key={f.label} className="dc-fact">
                <span className="fl">{f.label}</span>
                <span className="fv">{f.value}</span>
              </div>
            ))}
          </div>
        </div>
      )}
      {node.note && <div className="dc-note">{node.note}</div>}
      {node.evidence.length > 0 && (
        <div className="dc-evidence">
          <div className="dc-col-title">Documentation (repo paths)</div>
          {node.evidence.map((d) => (
            <button key={d.path} className="dc-ev" onClick={() => copyPath(d.path)} title={copied === d.path ? 'Copied to clipboard' : 'Copy relative path'}>
              {copied === d.path ? '✓ ' : '⧉ '}
              {d.label ?? d.path}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
