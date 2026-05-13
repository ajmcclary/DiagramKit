# DiagramKit — Active Roadmap

This file is the active index. Historical phase records live under
[docs/archive/](docs/archive/) — see [docs/archive/PHASES.md](docs/archive/PHASES.md)
for the full multi-format port story (Phases 0–10) and the individual
`docs/archive/PHASE-*.md` deep dives.

## Current state (post-Phase 10 + review remediation)

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
- 28 diagram families with full SVG/CG renderer parity and a 422-entry
  corpus exercised by the snapshot suite. Multi-format corpus entries
  (D2 / DOT / Structurizr / PlantUML) round-trip through their
  respective importers/exporters.

## Active work

- **Review remediation (PLAN.md)** — execute the 12 Critical and the
  Important backlog from [REVIEW.md](REVIEW.md). Phases 1–6 of
  [PLAN.md](PLAN.md) are complete; Phase 7 (docs + minor cleanup),
  Phase 8 (release verification) are the remaining slices.
- **PlantUML family slices** — extend the importer/exporter coverage
  beyond sequence (Phases 6B–6E in the archived roadmap). Current
  PlantUML import is sequence-only; the exporter supports sequence +
  C4 emission. Class, state/activity, mindmap+gantt, and C4 import
  are still open.
- **DOT exporter** — `DOTExporter` does not exist yet. Calling
  `DiagramExportLoader.export(to: .graphviz, …)` returns a
  `.unsupported` diagnostic. Implementation is a separate scoped phase.
- **ASCII renderer coverage** — 5 of 28 families ship an ASCII renderer
  (flowchart, sequence, class, ER, state). The remaining 23 throw
  `notYetImplemented`. Documented in
  [BASELINES.md](BASELINES.md).

## Index

| Doc | Purpose |
| --- | --- |
| [REVIEW.md](REVIEW.md) | Comprehensive code review (12 Critical + Important + Minor) |
| [PLAN.md](PLAN.md) | Remediation plan for REVIEW.md, organised into Phases 0–8 |
| [BASELINES.md](BASELINES.md) | Build / test / snapshot counts, gate caveats, deferred follow-ups |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Local + CI gate workflow, file-size & Sendable policy |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layer diagram, pipeline detail, drift hazards |
| [docs/archive/PHASES.md](docs/archive/PHASES.md) | Historical multi-format port roadmap (Phases 0–10) |
| [docs/archive/PHASE-0.md](docs/archive/PHASE-0.md) ... `PHASE-10.md` | Per-phase records |
