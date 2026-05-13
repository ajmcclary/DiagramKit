# DiagramKit — Active Roadmap

This file is the active index. Historical phase records live under
[docs/archive/](docs/archive/) — see [docs/archive/PHASES.md](docs/archive/PHASES.md)
for the full multi-format port story (Phases 0–10) and the individual
`docs/archive/PHASE-*.md` deep dives. The completed review-remediation
plan is preserved at [docs/archive/PLAN.md](docs/archive/PLAN.md); the
follow-on feature plan that closed DOT export, PlantUML family
slices, and ASCII coverage is at
[docs/archive/PLAN-followup.md](docs/archive/PLAN-followup.md). The
closing-commit map for every Critical finding lives in
[BASELINES.md](BASELINES.md).

## Current state (feature-complete)

- All 13 SwiftPM library products ship: `DiagramKit` (umbrella),
  `DiagramKitCommon`, `DiagramKitModel`, `DiagramKitImport`,
  `DiagramKitExport`, `DiagramKitMermaid`, `DiagramKitD2`,
  `DiagramKitGraphviz`, `DiagramKitStructurizr`, `DiagramKitPlantUML`,
  `DiagramKitRenderingCG`, `DiagramKitViews`, `DiagramKitInteractive`,
  plus the `DiagramKitTestSupport` test helper target.
- Public format-neutral API: `DiagramEngine`, `DiagramPipeline`,
  `DiagramImageRenderer`, `DiagramDocument`, `DiagramError`,
  `DiagramStructuralError`, `DiagramView`, `DiagramNativeView`,
  `DiagramLayer`, `DiagramViewModel`. Mermaid-prefixed aliases carry
  `@available(*, deprecated, renamed:)` annotations.
- 28 diagram families with full SVG/CG renderer parity, complete
  ASCII renderer parity (every dispatch arm in
  `Sources/DiagramKit/src_ascii_index.swift` routes to a real
  renderer), and a 422-entry corpus exercised by the snapshot suite.
- Multi-format coverage: Mermaid, D2, Graphviz DOT, Structurizr, and
  PlantUML (sequence + class + state/activity + mindmap + gantt +
  C4) on both the importer and exporter side.
- Review remediation (archived `PLAN.md`, Phases 0–8 plus 6A–6F) is
  complete. CI runs the governance gates on PRs; `BASELINES.md`
  tracks the closing commit for every Critical finding plus the
  follow-on feature work (DOT exporter, PlantUML family slices,
  ASCII coverage).

## Active work

_Empty._ The remaining backlog items from the post-remediation
PHASES.md ("DOT exporter", "PlantUML family slices", "ASCII
renderer coverage") landed across the Phase 1–11 commits in
`docs/archive/PLAN-followup.md`. See `BASELINES.md` for the
closing-commit map.

## Index

| Doc | Purpose |
| --- | --- |
| [BASELINES.md](BASELINES.md) | Build / test / snapshot counts, gate caveats, closing-commit map |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Local + CI gate workflow, file-size & Sendable policy |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layer diagram, pipeline detail, drift hazards |
| [docs/archive/PHASES.md](docs/archive/PHASES.md) | Historical multi-format port roadmap (Phases 0–10) |
| [docs/archive/PLAN.md](docs/archive/PLAN.md) | Completed review-remediation plan (Phases 0–8 + 6A–6F) |
| [docs/archive/PLAN-followup.md](docs/archive/PLAN-followup.md) | Completed follow-on plan (DOT export + PlantUML + ASCII) |
| [docs/archive/PHASE-0.md](docs/archive/PHASE-0.md) ... `PHASE-10.md` | Per-phase records |
