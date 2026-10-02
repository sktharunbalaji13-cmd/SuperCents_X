export type Category =
  | 'UNVERIFIED'
  | 'RESEARCH'
  | 'EXPERIMENT'
  | 'ENGINEERING'
  | 'VALIDATION'
  | 'DECISION'
  | 'GOVERNANCE'

export type NodeStatus =
  | 'UNVERIFIED'
  | 'COMPLETED'
  | 'CURRENT'
  | 'BLOCKED'
  | 'REJECTED'
  | 'PARKED'
  | 'DORMANT'
  | 'NOT STARTED'

export type Shape = 'rect' | 'rounded' | 'circle' | 'diamond' | 'hexagon' | 'shield'

export interface DocRef {
  path: string
  label?: string
}

export interface LayoutRect {
  x: number
  y: number
  w: number
  h: number
}

export interface GraphNode {
  id: string
  sprint?: string
  code?: string
  title: string
  category: Category
  status: NodeStatus
  shape: Shape
  major?: boolean
  current?: boolean
  summary: string
  objectives: string[]
  completed: string[]
  blocked: string[]
  pending: string[]
  facts?: { label: string; value: string }[]
  timeline?: string[]
  evidence: DocRef[]
  dependencies: string[]
  tags: string[]
  layout: LayoutRect
  lineage?: 'research' | 'engineering' | 'validation' | 'pre-docs'
  note?: string
}

export type EdgeKind = 'spine' | 'research' | 'engineering' | 'branch' | 'active'

export interface Edge {
  from: string
  to: string
  kind: EdgeKind
}

export const VIEWBOX = { w: 1600, h: 960 }
