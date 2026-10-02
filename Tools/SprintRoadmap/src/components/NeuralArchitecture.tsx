import { useState } from 'react'
import type { Category, GraphNode } from '../types'
import { NODES } from '../data/sprints'
import { CATEGORY_META, STATUS_META } from '../theme'

interface NeuralArchitectureProps {
  selectedId: string | null
  onSelect: (id: string | null) => void
}

const nodeById = new Map(NODES.map((n) => [n.id, n]))

interface LayerDef {
  label: string
  kind: 'input' | 'hidden' | 'output'
  sub: string
  ids: string[]
}

const LAYERS: LayerDef[] = [
  {
    label: 'PRE-DOCS ERA',
    kind: 'input',
    sub: 'no repo docs · git milestones only',
    ids: ['sprint-1', 'sprint-2', 'sprint-3', 'sprint-4', 'sprint-5', 'sprint-6', 'sprint-7', 'sprint-8', 'sprint-9', 'sprint-10'],
  },
  { label: 'DETECTION & PIPELINE', kind: 'hidden', sub: 'FVG · Liquidity · Entry & Execution', ids: ['sprint-11', 'sprint-12', 'sprint-13'] },
  { label: 'CALIBRATION & VALIDATION', kind: 'hidden', sub: 'Calibration · Stability Audit · Providers', ids: ['sprint-14', 'sprint-15'] },
  { label: 'EVIDENCE & RESEARCH', kind: 'hidden', sub: 'Confidence · Schema v3 · Deep Research · AVP', ids: ['sprint-16', 'sprint-17', 'sprint-18', 'sprint-19'] },
  { label: 'PLATFORM ENGINEERING', kind: 'hidden', sub: 'TT01 · B8 baseline · ED01-A…E', ids: ['sprint-20'] },
  { label: 'RL01 RESEARCH TRACK', kind: 'hidden', sub: 'Literature · RL-HYP-01 REJECT · no experiment', ids: ['sprint-21', 'sprint-22', 'sprint-23'] },
  { label: 'ENGINEERING AUDIT', kind: 'hidden', sub: 'EN-01…08 backlog · no implementation', ids: ['sprint-24'] },
  { label: 'CURRENT WORKING', kind: 'output', sub: 'Sprint 25 · EN-01 runtime blocked', ids: ['sprint-25'] },
]

const VB = { w: 900, h: 640 }
const X0 = 60
const STEP = 110
const MID = 280

function isPreDoc(node: GraphNode): boolean {
  return node.category === 'UNVERIFIED'
}

function layerYs(count: number): number[] {
  if (count === 1) return [MID]
  if (count === 2) return [MID - 60, MID + 60]
  if (count === 3) return [MID - 72, MID, MID + 72]
  return [MID - 108, MID - 36, MID + 36, MID + 108]
}

function radius(node: GraphNode, kind: LayerDef['kind']): number {
  if (kind === 'output') return 22
  return isPreDoc(node) ? 12 : 15
}

function neuronPositions() {
  return LAYERS.map((layer, i) => {
    const x = X0 + i * STEP
    const ys = layer.kind === 'input' ? Array.from({ length: 10 }, (_, k) => 70 + k * 48) : layerYs(layer.ids.length)
    return layer.ids.map((id, k) => ({ id, x, y: ys[k] }))
  })
}

const POSITIONS = neuronPositions()

type WeightKind = 'weak' | 'spine' | 'research' | 'engineering'

const WEIGHT_MAP: Record<string, WeightKind> = {
  '0-1': 'weak',
  '1-2': 'spine',
  '2-3': 'spine',
  '3-4': 'spine',
  '4-5': 'research',
  '5-6': 'research',
  '6-7': 'engineering',
}

const WEIGHT_STYLE: Record<WeightKind, { stroke: string; width: number; opacity: number }> = {
  weak: { stroke: '#3a4258', width: 0.6, opacity: 0.1 },
  spine: { stroke: '#5a6480', width: 0.8, opacity: 0.16 },
  research: { stroke: '#8b7cff', width: 1.1, opacity: 0.3 },
  engineering: { stroke: '#22d3ee', width: 1.3, opacity: 0.34 },
}

function meshByKind() {
  const out: Record<WeightKind, string[]> = { weak: [], spine: [], research: [], engineering: [] }
  for (let i = 0; i < POSITIONS.length - 1; i++) {
    const kind = WEIGHT_MAP[`${i}-${i + 1}`] ?? 'spine'
    const parts = out[kind]
    for (const a of POSITIONS[i]) {
      for (const b of POSITIONS[i + 1]) {
        parts.push(`M ${a.x} ${a.y} L ${b.x} ${b.y}`)
      }
    }
  }
  return out
}

const MESH = meshByKind()

const SKIP = { from: { x: X0 + 4 * STEP, y: MID }, to: { x: X0 + 6 * STEP, y: MID } }

const BIAS = { x: 620, y: 565, r: 13 }
const BIAS_TARGETS = [
  { x: X0 + 5 * STEP, y: MID + 72 }, // s23 — research terminal
  { x: X0 + 6 * STEP, y: MID }, // s24 — audit
  { x: X0 + 7 * STEP, y: MID }, // s25 — output
]

/* forward-pass path: input → hidden bottleneck → research → audit → output */
const PULSE_PATH =
  'M 60 502 C 90 502, 140 352, 170 352 C 200 352, 250 340, 280 340 ' +
  'C 310 340, 360 388, 390 388 C 420 388, 470 280, 500 280 ' +
  'C 530 280, 580 352, 610 352 C 640 352, 690 280, 720 280 C 750 280, 800 280, 830 280'

const STATUS_LEGEND = [
  { label: 'completed', color: '#34d399' },
  { label: 'current', color: '#8b7cff' },
  { label: 'rejected', color: '#f5b544' },
  { label: 'blocked', color: '#f04d5a' },
  { label: 'unverified', color: '#737b94' },
]

function Legend() {
  const cats = Object.keys(CATEGORY_META) as Category[]
  return (
    <g pointerEvents="none">
      {cats.map((c, i) => {
        const x = 330 + i * 85
        return (
          <g key={c}>
            <circle cx={x} cy={600} r={4} fill={CATEGORY_META[c].color} />
            <text x={x + 8} y={603.5} fontSize="8.5" fill="#737b94" fontFamily="ui-monospace, monospace" letterSpacing="0.04em">
              {CATEGORY_META[c].label}
            </text>
          </g>
        )
      })}
      {STATUS_LEGEND.map((s, i) => {
        const x = 330 + i * 85
        return (
          <g key={s.label}>
            <circle cx={x} cy={622} r={4} fill={s.color} />
            <text x={x + 8} y={625.5} fontSize="8.5" fill="#737b94" fontFamily="ui-monospace, monospace" letterSpacing="0.04em">
              {s.label}
            </text>
          </g>
        )
      })}
    </g>
  )
}

export default function NeuralArchitecture({ selectedId, onSelect }: NeuralArchitectureProps) {
  const [hoverId, setHoverId] = useState<string | null>(null)
  const hoverNode = hoverId ? nodeById.get(hoverId) : null

  return (
    <div className="nn-wrap" onMouseLeave={() => setHoverId(null)}>
      <svg className="nn-svg" viewBox={`0 0 ${VB.w} ${VB.h}`}>
        <defs>
          <linearGradient id="g-out" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#8b7cff" />
            <stop offset="100%" stopColor="#22d3ee" />
          </linearGradient>
        </defs>

        {/* layer groupings */}
        {LAYERS.map((layer, i) => {
          const x = X0 + i * STEP
          const ys = layer.kind === 'input' ? [70, 502] : layerYs(layer.ids.length)
          const yTop = (layer.kind === 'input' ? 56 : Math.min(...ys)) - 36
          const yBot = (layer.kind === 'input' ? 514 : Math.max(...ys)) + 36
          return (
            <rect key={layer.label} x={x - 46} y={yTop} width={92} height={yBot - yTop} rx={14} fill="rgba(21,26,40,0.55)" stroke="rgba(140,152,190,0.1)" pointerEvents="none" />
          )
        })}

        {/* layer labels + metadata */}
        {LAYERS.map((layer, i) => {
          const x = X0 + i * STEP
          const isInput = layer.kind === 'input'
          const base = isInput ? 22 : 18
          return (
            <g key={layer.label} pointerEvents="none">
              <text x={x} y={base + 4} fontSize="9" fill="#aab2c8" textAnchor="middle" fontFamily="ui-monospace, monospace" letterSpacing="0.09em">
                {layer.label}
              </text>
              <text x={x} y={base + 14} fontSize="7" fill="#4c5468" textAnchor="middle" fontFamily="ui-monospace, monospace" letterSpacing="0.14em">
                {isInput ? 'INPUT LAYER' : layer.kind === 'output' ? 'OUTPUT LAYER' : 'HIDDEN LAYER'}
              </text>
              <text x={x} y={base + 24} fontSize="6.6" fill="#3d4459" textAnchor="middle" fontFamily="ui-monospace, monospace" letterSpacing="0.02em">
                {layer.sub}
              </text>
            </g>
          )
        })}

        {/* weighted mesh connections */}
        {(Object.keys(WEIGHT_STYLE) as WeightKind[]).map((kind) => (
          <path
            key={kind}
            d={MESH[kind].join(' ')}
            fill="none"
            stroke={WEIGHT_STYLE[kind].stroke}
            strokeWidth={WEIGHT_STYLE[kind].width}
            opacity={WEIGHT_STYLE[kind].opacity}
            pointerEvents="none"
          />
        ))}

        {/* skip connection: platform -> audit (engineering lineage) */}
        <g pointerEvents="none">
          <line x1={SKIP.from.x} y1={SKIP.from.y} x2={SKIP.to.x} y2={SKIP.to.y} stroke="#22d3ee" strokeWidth="1.6" strokeDasharray="5 4" opacity="0.8" />
          <text x={(SKIP.from.x + SKIP.to.x) / 2} y={SKIP.from.y - 10} fontSize="7.5" fill="#22d3ee" opacity="0.9" textAnchor="middle" fontFamily="ui-monospace, monospace" letterSpacing="0.08em">
            SKIP · ENGINEERING LINEAGE
          </text>
        </g>

        {/* bias node: frozen baselines */}
        <g pointerEvents="none">
          {BIAS_TARGETS.map((t, i) => (
            <line key={i} x1={BIAS.x} y1={BIAS.y} x2={t.x} y2={t.y} stroke="#2dd4bf" strokeWidth="0.9" strokeDasharray="3 3" opacity="0.4" />
          ))}
          <circle cx={BIAS.x} cy={BIAS.y} r={BIAS.r} fill="rgba(16,20,31,0.95)" stroke="#2dd4bf" strokeWidth="1.4" strokeDasharray="3 2.5" />
          <text x={BIAS.x} y={BIAS.y + 3} fontSize="8" fill="#2dd4bf" textAnchor="middle" fontFamily="ui-monospace, monospace" fontWeight="700">
            B8
          </text>
          <text x={BIAS.x} y={BIAS.y + BIAS.r + 11} fontSize="6.8" fill="#2a826f" textAnchor="middle" fontFamily="ui-monospace, monospace" letterSpacing="0.05em">
            BIAS · frozen baselines v3.0 / B8
          </text>
        </g>

        {/* forward-pass pulse */}
        <g pointerEvents="none">
          {[0, 1].map((i) => (
            <circle key={i} r="2.6" fill="#22d3ee" opacity="0.7">
              <animateMotion dur="6.5s" begin={`${i * 3.25}s`} repeatCount="indefinite" path={PULSE_PATH} />
            </circle>
          ))}
        </g>

        {/* neurons */}
        {POSITIONS.flat().map((pos) => {
          const node = nodeById.get(pos.id)
          if (!node) return null
          const layer = LAYERS.find((l) => l.ids.includes(pos.id))!
          const r = radius(node, layer.kind)
          const pre = isPreDoc(node)
          const isOutput = layer.kind === 'output'
          const isSelected = pos.id === selectedId
          const isHover = pos.id === hoverId
          const st = STATUS_META[node.status]
          const stroke = isOutput ? 'url(#g-out)' : pre ? '#4c5468' : CATEGORY_META[node.category].color
          const dotY = pos.y + r + 7
          return (
            <g
              key={pos.id}
              className={`nn-neuron ${isOutput ? 'nn-output' : ''}`}
              opacity={pre ? 0.72 : 1}
              onMouseEnter={() => setHoverId(pos.id)}
              onClick={(e) => {
                e.stopPropagation()
                onSelect(isSelected ? null : pos.id)
              }}
            >
              {isSelected && (
                <circle cx={pos.x} cy={pos.y} r={r + 5} fill="none" stroke="#ffffff" strokeOpacity="0.55" strokeWidth="1.4" style={{ animation: 'pulse 1.8s ease-in-out infinite' }} />
              )}
              {isHover && !isSelected && (
                <circle cx={pos.x} cy={pos.y} r={r + 4} fill="none" stroke={pre ? '#4c5468' : CATEGORY_META[node.category].color} strokeOpacity="0.4" strokeWidth="1" />
              )}
              <circle
                cx={pos.x}
                cy={pos.y}
                r={r}
                fill="rgba(16,20,31,0.92)"
                stroke={stroke}
                strokeWidth={isOutput ? 2.6 : pre ? 1 : 2}
                strokeDasharray={pre ? '3 2.5' : undefined}
                style={isOutput ? { animation: 'pulse 2s ease-in-out infinite' } : undefined}
              />
              <text x={pos.x} y={pos.y + 3.5} fontSize={isOutput ? 13 : pre ? 8 : 10} fill={pre ? '#4c5468' : '#e7eaf3'} textAnchor="middle" fontFamily="ui-monospace, monospace" fontWeight="700">
                {node.sprint ?? ''}
              </text>
              <circle cx={pos.x} cy={dotY} r={2.6} fill={st.color} opacity={pre ? 0.5 : 0.95} />
            </g>
          )
        })}

        <Legend />
      </svg>

      {hoverNode && <Popover node={hoverNode} />}
    </div>
  )
}

function Popover({ node }: { node: GraphNode }) {
  const pos = POSITIONS.flat().find((p) => p.id === node.id)
  if (!pos) return null
  const layer = LAYERS.find((l) => l.ids.includes(node.id))!
  const r = radius(node, layer.kind)
  const st = STATUS_META[node.status]
  return (
    <div
      className="nn-pop"
      style={{
        left: `${(pos.x / VB.w) * 100}%`,
        top: `${((pos.y - r - 12) / VB.h) * 100}%`,
      }}
    >
      <div className="nn-pop-head">
        <span style={{ color: CATEGORY_META[node.category].color }}>{node.sprint ? `Sprint ${node.sprint}` : node.id}</span>
        <span className="mono" style={{ color: st.color }}>
          {st.label}
        </span>
      </div>
      <div className="nn-pop-title">{node.title}</div>
      <div className="nn-pop-sub">{node.summary}</div>
    </div>
  )
}
