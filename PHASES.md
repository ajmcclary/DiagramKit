# DiagramKit — Active Roadmap

This file is the active index. Historical phase records live under
[docs/archive/](docs/archive/) — see [docs/archive/PHASES.md](docs/archive/PHASES.md)
for the full multi-format port story (Phases 0–10) and the individual
`docs/archive/PHASE-*.md` deep dives. The completed review-remediation
plan is preserved at [docs/archive/PLAN.md](docs/archive/PLAN.md); the
closing-commit map for every Critical finding lives in
[BASELINES.md](BASELINES.md).

## Current state

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
- Review remediation (archived `PLAN.md`, Phases 0–8 plus 6A–6F) is
  complete. CI runs the governance gates on PRs; `BASELINES.md` tracks
  the closing commit for every Critical finding.

## Active work

- **PlantUML family slices** — extend importer/exporter coverage beyond
  sequence. Current PlantUML import is sequence-only; the exporter
  supports sequence + C4 emission. Class, state/activity, mindmap +
  gantt, and C4 import are still open. Tracked as Phases 6B–6E in the
  archived multi-format roadmap.
- **DOT exporter** — `DOTExporter` does not exist yet. Calling
  `DiagramExportLoader.export(to: .graphviz, …)` returns a
  `.unsupported` diagnostic. Implementation is a separate scoped phase.
- **ASCII renderer coverage** — 5 of 28 families ship an ASCII renderer
  (flowchart, sequence, class, ER, state). The remaining 23 throw
  `notYetImplemented` from `Sources/DiagramKit/src_ascii_index.swift`.
  Documented in [BASELINES.md](BASELINES.md).

## Index

| Doc | Purpose |
| --- | --- |
| [BASELINES.md](BASELINES.md) | Build / test / snapshot counts, gate caveats, REVIEW.md closing-commit map |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Local + CI gate workflow, file-size & Sendable policy |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layer diagram, pipeline detail, drift hazards |
| [docs/archive/PHASES.md](docs/archive/PHASES.md) | Historical multi-format port roadmap (Phases 0–10) |
| [docs/archive/PLAN.md](docs/archive/PLAN.md) | Completed review-remediation plan (Phases 0–8 + 6A–6F) |
| [docs/archive/PHASE-0.md](docs/archive/PHASE-0.md) ... `PHASE-10.md` | Per-phase records |
