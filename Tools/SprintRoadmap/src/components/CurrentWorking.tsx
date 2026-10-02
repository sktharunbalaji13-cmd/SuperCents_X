import { statusMatrix, currentBlockers, sprint25Tasks } from '../data/engineering'
import { findNode } from '../data/sprints'
import { CATEGORY_META } from '../theme'

export default function CurrentWorking() {
  const s25 = findNode('sprint-25')
  if (!s25) return null

  const pendingTasks = sprint25Tasks.filter((t) => t.state === 'PENDING' || t.state === 'RUNTIME')

  return (
    <section className="cw-section">
      <div className="section-head">
        <span className="dot" style={{ background: 'var(--violet)', boxShadow: '0 0 10px var(--violet)', animation: 'pulse 1.6s ease-in-out infinite' }} />
        <span className="section-title">Current Working</span>
      </div>
      <div className="cw-body">
        <div className="cw-title">
          Sprint 25 — {s25.title}
          <span className="cw-code">{s25.code}</span>
        </div>

        <div className="cw-pills">
          <span className="pill green">
            <span className="p-dot" />
            SOURCE GREEN
          </span>
          <span className="pill green">
            <span className="p-dot" />
            COMPILE GREEN
          </span>
          <span className="pill red pulse">
            <span className="p-dot" />
            RUNTIME BLOCKED
          </span>
          <span className="pill red">
            <span className="p-dot" />
            OVERALL NOT COMPLETE
          </span>
        </div>

        <div className="cw-grid">
          <div className="cw-card">
            <div className="cw-card-title">Blocker</div>
            {currentBlockers.map((b) => (
              <div key={b.title} className="cw-blocker">
                <span className="bl-id">{b.title}</span>
                <p>{b.detail}</p>
              </div>
            ))}
          </div>
          <div className="cw-card">
            <div className="cw-card-title">Pending</div>
            <ul className="cw-list">
              {pendingTasks.map((t) => (
                <li key={t.id}>
                  <span className="mono" style={{ color: 'var(--amber)', marginRight: 6 }}>
                    {t.id}
                  </span>
                  {t.title}
                </li>
              ))}
            </ul>
          </div>
        </div>

        <div className="note-box">
          <div className="note-box-title">Repo evidence · discrepancy note</div>
          <p>
            {s25.note}
            <br />
            <span style={{ color: 'var(--muted)', fontSize: 11 }}>(Sprint 25A assessment, G7 PASS / G8 RESOLVED — see History below)</span>
          </p>
        </div>

        <div style={{ marginTop: 12, fontSize: 11, color: 'var(--muted)' }}>
          Category: <span style={{ color: CATEGORY_META[s25.category].color }}>{CATEGORY_META[s25.category].label}</span>
          <span className="mono" style={{ color: statusMatrix.overall, marginLeft: 10 }}>
            {statusMatrix.source} / {statusMatrix.compile} / {statusMatrix.runtime} / {statusMatrix.overall}
          </span>
        </div>
      </div>
    </section>
  )
}
