import type { Category, NodeStatus } from './types'

export const CATEGORY_META: Record<Category, { color: string; label: string }> = {
  RESEARCH: { color: '#8b7cff', label: 'Research' },
  EXPERIMENT: { color: '#5b9dff', label: 'Experiment' },
  ENGINEERING: { color: '#22d3ee', label: 'Engineering' },
  VALIDATION: { color: '#2dd4bf', label: 'Validation' },
  DECISION: { color: '#f5b544', label: 'Decision' },
  GOVERNANCE: { color: '#f04d5a', label: 'Governance' },
  UNVERIFIED: { color: '#737b94', label: 'Unverified' },
}

export const STATUS_META: Record<NodeStatus, { color: string; label: string }> = {
  UNVERIFIED: { color: '#737b94', label: 'UNVERIFIED' },
  COMPLETED: { color: '#34d399', label: 'COMPLETED' },
  CURRENT: { color: '#8b7cff', label: 'CURRENT' },
  BLOCKED: { color: '#f04d5a', label: 'BLOCKED' },
  REJECTED: { color: '#f5b544', label: 'REJECTED' },
  PARKED: { color: '#5b9dff', label: 'PARKED' },
  DORMANT: { color: '#737b94', label: 'DORMANT' },
  'NOT STARTED': { color: '#aab2c8', label: 'NOT STARTED' },
}

export const EDGE_COLORS: Record<string, string> = {
  spine: 'rgba(120, 132, 168, 0.45)',
  research: 'rgba(139, 124, 255, 0.6)',
  engineering: 'rgba(34, 211, 238, 0.5)',
  branch: 'rgba(120, 132, 168, 0.3)',
  active: '#8b7cff',
}
