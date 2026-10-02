import { useState } from 'react'
import { NODES } from './data/sprints'
import CurrentWorking from './components/CurrentWorking'
import NeuralArchitecture from './components/NeuralArchitecture'
import NodeDetail from './components/NodeDetail'
import HistoryList from './components/HistoryList'
import Footer from './components/Footer'

const nodeById = new Map(NODES.map((n) => [n.id, n]))

export default function App() {
  const [selectedId, setSelectedId] = useState<string | null>(null)
  const selectedNode = selectedId ? nodeById.get(selectedId) ?? null : null

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-inner">
          <div className="brand">
            <div className="brand-mark">
              <svg viewBox="0 0 24 24" width="20" height="20">
                <circle cx="7" cy="8" r="2.2" fill="none" stroke="#8b7cff" strokeWidth="1.5" />
                <circle cx="17" cy="8" r="2.2" fill="none" stroke="#22d3ee" strokeWidth="1.5" />
                <circle cx="12" cy="17" r="2.6" fill="none" stroke="#34d399" strokeWidth="1.5" />
                <path d="M7 8 H17 M9 9.5 L11 15 M15 9.5 L13 15 M9 15 H15" stroke="#5a6480" strokeWidth="1" />
              </svg>
            </div>
            <div>
              <div className="brand-title">
                SuperCents_X <span>Mission Control</span>
              </div>
              <div className="brand-sub">SPRINT 1 → 25 · NEURAL ROADMAP ARCHITECTURE</div>
            </div>
          </div>
          <div className="header-current">
            <span>CURRENT:</span>
            <span className="chip" style={{ color: 'var(--violet)', borderColor: 'rgba(139,124,255,0.4)' }}>
              Sprint 25
            </span>
            <span className="chip" style={{ color: 'var(--red)', borderColor: 'rgba(240,77,90,0.4)' }}>
              RUNTIME BLOCKED
            </span>
          </div>
        </div>
      </header>

      <main className="simple-main">
        <div className="overview-card">
          <CurrentWorking />

          <section className="nn-section">
            <div className="section-head">
              <span className="dot" style={{ background: 'var(--cyan)' }} />
              <span className="section-title">Architecture</span>
              <span className="section-count">input → hidden → output · click a neuron</span>
            </div>
            <div className="nn-body">
              <NeuralArchitecture selectedId={selectedId} onSelect={setSelectedId} />
              {selectedNode && <NodeDetail node={selectedNode} onClose={() => setSelectedId(null)} />}
            </div>
          </section>

          <HistoryList />
        </div>
      </main>

      <Footer />
    </div>
  )
}
