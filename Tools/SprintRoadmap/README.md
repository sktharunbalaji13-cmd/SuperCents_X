# SuperCents_X Mission Control — Neural Sprint Roadmap

A clean, read-only visualization of the SuperCents_X research & engineering history
(Sprint 1 → Sprint 25), styled as a neural-network architecture diagram.

> **This is a visualization only.** It does not modify research state, does not touch the
> production EA, does not run the Strategy Tester, and exposes **no trading or execution
> controls**. All facts are sourced from the repository documentation. No search, no filters.

## Quick start

Requires Node.js ≥ 18 (tested on Node v25.x).

```bash
npm install
npm run dev        # http://localhost:3000  (auto-opens)
npm run typecheck  # strict TypeScript check
npm run build      # production build -> dist/
npm run preview    # serve the production build
```

Visual Studio Code tasks: `Tasks: Run Task` → `SuperCents_X Roadmap: Dev` / `Build` / `Typecheck`.

## What is on the screen (top to bottom)

1. **Current Working** — Sprint 25 only. Status pills (SOURCE GREEN / COMPILE GREEN /
   RUNTIME BLOCKED / OVERALL NOT COMPLETE), the EN-01 runtime-GREEN blocker, pending tasks
   (EN-02 / EN-05 / EN-06), and the repo-evidence discrepancy note (Sprint 25A disproved the
   stale-binary hypothesis; confirmed gap is source→binary→run identity binding G1–G9).
2. **Architecture** — the sprint history drawn as a neural network:
   - **Input layer** = the undocumented Sprint 1–10 era (10 muted pre-doc neurons).
   - **Hidden layers** = Detection & Pipeline (11–13) → Calibration & Validation (14–15) →
     Evidence & Research (16–19) → Platform Engineering (20) → RL01 Research Track (21–23) →
     Engineering Audit (24).
   - **Output layer** = Current Working (Sprint 25), larger and pulsing.
   - Fully-connected mesh lines between adjacent layers; one cyan **skip connection**
     (Sprint 20 → Sprint 24, the engineering lineage).
   - Click any neuron for its detail card (summary, completed/blocked/pending, facts, docs).
   - Neuron ring color = category; legend at the bottom.
3. **History** — an expandable, chronological list (Sprint 1 → 25) with the pre-docs git-only
   milestones and per-sprint documentation paths (copy to clipboard).

### Design principles applied (from the Neural Network Design skill)

- **Architecture**: input → hidden → output with explicit layer roles.
- **Depth vs width**: wide input layer, narrow bottleneck (Sprint 20 / 24 / 25), balanced hidden layers.
- **Weighted connections**: mesh lines encode lineage strength — research track (violet) and
  engineering path (cyan) are weighted higher than the faint pre-doc / spine mesh.
- **Skip connections**: one explicit engineering-lineage shortcut (Sprint 20 → Sprint 24).
- **Bias node**: a frozen-baseline constant (`v3.0` / `B8`) feeds the research terminal, audit,
  and output — mirroring a network's bias term.
- **Forward pass**: two subtle pulses travel input → output along the primary path.
- **Regularization**: uniform neuron sizes, single restrained color per category, muted mesh.
- **Activation / emphasis**: only the output neuron animates; hover pops a summary card, and a
  status dot under each neuron encodes completed / current / rejected / blocked / unverified.

### Sprints 1–10

No sprint-planning or completion documentation exists for these numbers — they are rendered
as unverified (dashed gray neurons) with the git-only milestones (v0.8.0 / v0.9.0 / v1.0 /
Sprint 5.1.12 / Capability Releases 2.3–2.6 / v2.7–v2.8 confluence engine) listed in the
History panel.

### Repo-evidence annotations

Where a stated roadmap status differs from repository evidence, an amber note appears on the
affected node (Current Working or History detail). Example: Sprint 24 records EN-01/EN-02/EN-03
closures (commits `459bdb3` / `7809301` / `73e5886`), while EN-05/EN-06 remain pending.

## Layout & data

- Layer/neuron layout is data-driven: `src/data/sprints.ts` defines every node.
- Strong types in `src/types.ts`; theme colors in `src/theme.ts`; Sprint 25 status in
  `src/data/engineering.ts`; evidence chain / early history in `src/data/evidence.ts`.
- Desktop-first (1366×768 / 1920×1080 / 2560×1440), single-column on narrow screens.

## Tech

React 18 · Vite 4 · TypeScript 5 (strict) · zero runtime dependencies beyond React.
