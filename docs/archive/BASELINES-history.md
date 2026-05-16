# BASELINES-history.md

Historical sections extracted from `BASELINES.md` so the live document
can stay focused on current build / test / snapshot / gate metrics.
For closing-commit context on the comprehensive code review and the
post-remediation feature work, see also
[RELEASE_NOTES-review-remediation.md](RELEASE_NOTES-review-remediation.md).

## Rebaseline events

| Date | Reason | Commits | Notes |
| --- | --- | --- | --- |
| 2026-05-14 | SVG color-mix resolver rebaseline | `5cf2186` (SVG) + *image commit* | Session 4 of the review-remediation cycle. Re-recorded 390 of 435 SVG and 57 of 435 image baselines against the post-resolver-fix output (`1c2f18f`, `6b35c80`, `d6bdec7`). Unmodified entries were 17 pre-failing IDs (`req-*`, `xychart-27-full-config`) plus byte-identical outputs. Visual canary set: `flow-1-simple`, `seq-1-basic`, `class-1-basic`, `er-1-basic`, `state-1-basic`, `xychart-1-bar`. |

### Re-recorded during the review-remediation cycle

- 7 Gantt SVG baselines (`gantt-1` … `gantt-7`) — Phase 1.3 pinned the
  today-marker via `DIAGRAMKIT_GANTT_TODAY=2024-06-15`.
- 2 Block SVG baselines (`block-5-edges`, `block-7-architecture`) —
  Phase 6D fixed the D2-probe mis-routing.
- 2 Block image baselines (`block-5-edges`, `block-7-architecture`) —
  Phase 8 caught the corresponding image drift that exceeded the
  precision threshold.

## Review-remediation map (Critical → closing commit)

| # | Critical finding | Phase | Commit |
| --- | --- | --- | --- |
| 1 | `DiagramPipeline.renderSVG` round-trips theme through `hexString` | 1 | `75d3244` |
| 2 | Block CG vs SVG `.round` shape mismatch | 1 | `75d3244` |
| 3 | `DiagramLayer.preparationTask` stale main-actor publish | 3 | `07aac8c` |
| 4 | `DiagramLayer.commonInit()` is `nonisolated` | 3 | `07aac8c` — documented constraint blocked on `@preconcurrency QuartzCore` |
| 5 | `DiagramView.bindPreparationUpdates` clobbers `onPrepareComplete` | 3 | `07aac8c` |
| 6 | `StructurizrExporter` alias sanitization | 2 | `81342f6` |
| 7 | `StructurizrExporter` emits tags/group the parser drops | 2 | `81342f6` |
| 8 | `PlantUMLSequenceExport.escape` newline normalization | 2 | `81342f6` |
| 9 | `DiagramKitExport → DiagramKitImport` dependency | 4 | `3b98dd6` |
| 10 | `MermaidExporter` inside the umbrella | 4 | `3b98dd6` |
| 11 | Gantt today-marker non-determinism | 1 | `75d3244` |
| 12 | `bootstrap-smoke-check.sh` + `linux-check.sh` policy | 5 | `cb1f082` |

The Important-and-Minor backlog closed across Phases 6A–6F + 7
(commits `7ae5c1c`, `c60574a`, `d35e849`, `d7d68dd`, `bcb7bae`,
`07cc87a`, `a20e94e`).

## Post-remediation feature work

The follow-on plan ([PLAN-followup.md](PLAN-followup.md)) closed the
three open work items from [PHASES.md](PHASES.md):

| # | Feature | Phase | Commit |
| --- | --- | --- | --- |
| 1 | DOT exporter (`DiagramKitGraphviz/DOTExporter`) | Phase 1 | `f468791` |
| 2 | PlantUML class slice (importer + exporter) | Phase 2 | `26314a8` |
| 3 | PlantUML state/activity slice | Phase 3 | `b4e6de9` |
| 4 | PlantUML mindmap slice | Phase 4 | `2255621` |
| 5 | PlantUML gantt slice | Phase 5 | `e911295` |
| 6 | PlantUML C4 slice | Phase 6 | `a4bdee1` |
| 7 | Pie chart ASCII renderer | Phase 7 | `d6773c1` |
| 8 | Tree-shaped ASCII (mindmap, treeView, ishikawa) | Phase 8 | `a25704b` |
| 9 | Time-based ASCII (gantt, gitGraph, timeline, journey) | Phase 9 | `64eed79` |
| 10 | Box-cluster ASCII (block, c4, architecture, eventModeling, wardley, kanban) | Phase 10 | `8cdd3c4` |
| 11 | Specialty ASCII (sankey, radar, treemap, venn, quadrant, packet, requirement, zenuml) | Phase 11 | `1b84e89` |

After Phase 11, `Sources/DiagramKit/src_ascii_index.swift` no longer
contains any `notYetImplemented` branches — every diagram family routes
to a real ASCII renderer. Corpus ASCII baselines have since been
recorded for every entry (the live `BASELINES.md` reflects the
post-recording counts).

## Closed historical deferrals

- **PlantUML family slices** — importer + exporter coverage for class,
  state/activity, mindmap+gantt, and C4 import is complete (see the
  Post-remediation feature work table above).
- **ASCII renderer coverage gap** — closed by Phases 7–11; every
  diagram family ships an ASCII renderer and every corpus entry has an
  ASCII baseline.

## Open deferrals (still active — also referenced from the live BASELINES.md)

- **EventModeling tests** — `EventModelingTests.swift` remains a single
  monolithic XCTest file. Splitting per-concern (parser / layout /
  renderer / corpus fixture) is a separate scoped phase. Documented at
  the suite level so it stays discoverable.
- **`DiagramLayer.commonInit()` → `@MainActor`** — blocked on dropping
  `@preconcurrency QuartzCore`; documented in source.
