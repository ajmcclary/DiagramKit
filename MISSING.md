# Missing Image Snapshot Baselines

> **161 image snapshot baselines** currently exist across 15 diagram categories.
> **~235 are missing** — 131 from 13 entirely-uncovered types, 104 from 12 partially-covered types.
>
> The `CorpusSnapshotTests.imageSnapshot` test iterates over **all 396 diagrams** in
> `Examples/MermaidPlayground/Resources/test-diagrams.json`. Missing baselines mean
> `MermaidRenderer.renderImage(source:)` returned `nil` or threw for those diagrams —
> consistent with AGENTS.md: *"missing image cases are rendering bugs (layout
> producing 0×0 bounds)."*

---

## Diagram Types With Zero Image Snapshots (13 types, 131 entries)

These have working SVG and ASCII baselines but no PNG baselines at all.

| # | Diagram Type | Corpus Entries | Image Snapshots | Notes |
|---|-------------|---------------|-----------------|-------|
| 1 | architecture | 9 | 0 | `DiagramRenderer+Architecture.swift` exists |
| 2 | block | 12 | 0 | `DiagramRenderer+Block.swift` exists |
| 3 | c4 | 5 | 0 | `DiagramRenderer+C4.swift` exists |
| 4 | eventmodeling | 12 | 0 | `DiagramRenderer+EventModeling.swift` exists |
| 5 | kanban | 4 | 0 | `DiagramRenderer+Kanban.swift` exists |
| 6 | packet | 5 | 0 | `DiagramRenderer+Packet.swift` exists |
| 7 | radar | 10 | 0 | `DiagramRenderer+Radar.swift` exists |
| 8 | requirement | 16 | 0 | `DiagramRenderer+Requirement.swift` exists |
| 9 | sankey | 10 | 0 | `DiagramRenderer+Sankey.swift` exists |
| 10 | timeline | 13 | 0 | `DiagramRenderer+Timeline.swift` exists |
| 11 | venn | 8 | 0 | `DiagramRenderer+Venn.swift` exists |
| 12 | wardleyBeta | 12 | 0 | `DiagramRenderer+Wardley.swift` exists |
| 13 | zenuml | 15 | 0 | `DiagramRenderer+ZenUML.swift` exists |
| **Total** | | **131** | **0** | |

### Missing IDs by Type

**architecture** (9):
`architecture-basic`, `architecture-nested`, `architecture-junctions`,
`architecture-edge-labels`, `architecture-group-boundary`,
`architecture-title-accessibility`, `architecture-minimal`,
`architecture-external-icons`, `architecture-edge-labels-arrows`

**block** (12):
`block-1-simple`, `block-2-columns`, `block-3-nested`, `block-4-arrow`,
`block-5-edges`, `block-6-style`, `block-7-architecture`, `block-8-widths`,
`block-9-arrows-all`, `block-10-edges-all`, `block-11-style-default`,
`block-12-mixed-rows`

**c4** (5):
`c4-context`, `c4-container`, `c4-component`, `c4-dynamic`, `c4-deployment`

**eventmodeling** (12):
`eventmodeling-simple-state-change`, `eventmodeling-relaxed-notation`,
`eventmodeling-reset-frame`, `eventmodeling-multi-relation`,
`eventmodeling-data-blocks`, `eventmodeling-inline-data`,
`eventmodeling-namespaces`, `eventmodeling-gwt`,
`eventmodeling-title-accessibility`, `eventmodeling-frontmatter-config`,
`eventmodeling-all-entity-types`, `eventmodeling-state-view`

**kanban** (4):
`kanban-simple`, `kanban-metadata`, `kanban-decorations`, `kanban-full-board`

**packet** (5):
`packet-1-tcp`, `packet-2-udp`, `packet-3-nobits`, `packet-4-longsplit`,
`packet-5-empty`

**radar** (10):
`radar-empty`, `radar-simple`, `radar-labeled-axes`,
`radar-detailed-entries`, `radar-polygon-graticule`, `radar-options`,
`radar-multi-curve`, `radar-accessibility`, `radar-student-grades`,
`radar-frontmatter`

**requirement** (16):
`req-1-basic`, `req-2-all-requirement-types`, `req-3-all-risk-levels`,
`req-4-all-verify-methods`, `req-5-empty-bodies`, `req-6-all-relationships`,
`req-7-reverse-relationships`, `req-8-directions`, `req-9-accessibility`,
`req-10-styles`, `req-11-classDef-and-class`, `req-12-shorthand-classes`,
`req-13-full-sysml`, `req-15-neo-look`, `req-16-neo-theme`,
`req-17-markdown-labels`

**sankey** (10):
`sankey-1-minimal`, `sankey-2-beta-header`, `sankey-3-energy-flow`,
`sankey-4-label-outlined`, `sankey-5-link-color-source`,
`sankey-6-node-alignment-left`, `sankey-7-showvalues-prefix-suffix`,
`sankey-8-custom-node-colors`, `sankey-9-comments-and-spacing`,
`sankey-10-apple-financial-flow`

**timeline** (13):
`timeline-1-basic`, `timeline-2-sectioned-industrial`,
`timeline-3-br-tags`, `timeline-4-section-br`, `timeline-5-td-basic`,
`timeline-6-td-sectioned`, `timeline-7-disable-multicolor`,
`timeline-8-cscale-override`, `timeline-9-many-events`,
`timeline-10-continuation-events`, `timeline-11-accessibility`,
`timeline-12-neo-look`, `timeline-13-neo-redux`

**venn** (8):
`venn-simple-two-set`, `venn-three-set`, `venn-title-labels`,
`venn-custom-sizes`, `venn-quoted-identifiers`, `venn-text-nodes`,
`venn-styled`, `venn-frontmatter-theme`

**wardleyBeta** (12):
`wardley-1-tea-shop`, `wardley-2-coordinates`, `wardley-3-decorators`,
`wardley-4-link-types`, `wardley-5-evolution`, `wardley-6-pipeline`,
`wardley-7-custom-stages`, `wardley-8-annotations`,
`wardley-9-accelerators`, `wardley-10-hyphenated`,
`wardley-11-platform`, `wardley-12-minimal`

**zenuml** (15):
`zenuml-1-simple`, `zenuml-2-sync`, `zenuml-3-multi-async`,
`zenuml-4-creation`, `zenuml-5-return`, `zenuml-6-return-arrow`,
`zenuml-7-alt`, `zenuml-8-loop`, `zenuml-9-tcf`,
`zenuml-10-stereotypes`, `zenuml-11-emoji`, `zenuml-12-group`,
`zenuml-13-divider`, `zenuml-14-nested`, `zenuml-15-title`

---

## Diagram Types With Partial Image Coverage (12 types, 104 missing)

These have some PNG baselines but are missing many.

### class (36 of 61 — missing 25)

| Have | Missing |
|------|---------|
| 1, 3-11, 14, 15, 17, 18, 20, 22-24, 26, 27, 30, 32, 33, 36, 39, 40, 45-51, 55, 58, 60 | 2, 12, 13, 16, 19, 21, 25, 28, 29, 31, 34, 35, 37, 38, 41, 42, 43, 44, 52, 53, 54, 56, 57, 59, 61 |

### er (7 of 25 — missing 18)

| Have | Missing |
|------|---------|
| 3, 14, 15, 16, 18, 20, 23 | 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 19, 21, 22, 24, 25 |

### flowchart (19 of 27 — missing 8)

| Have | Missing |
|------|---------|
| 1, 3-6, 9-11, 14-18, 20, 22-26 | 2, 7, 8, 12, 13, 19, 21, 27 |

### gantt (3 of 7 — missing 4)

| Have | Missing |
|------|---------|
| 1, 3, 6 | 2, 4, 5, 7 |

### gitGraph (11 of 18 — missing 7)

| Have | Missing |
|------|---------|
| 1, 5, 6, 8, 10, 11, 14-18 | 2, 3, 4, 7, 9, 12, 13 |

### ishikawa (1 of 7 — missing 6)

| Have | Missing |
|------|---------|
| simple | root-only, unindented-root, deep-nesting, leading-comments, frontmatter-config, dark-theme |

### mindmap (2 of 9 — missing 7)

| Have | Missing |
|------|---------|
| 1, 7 | 2, 3, 4, 5, 6, 8, 9 |

### sequence (16 of 23 — missing 7)

| Have | Missing |
|------|---------|
| 1-7, 10-17, 20 | 8, 9, 18, 19, 21, 22, 23 |

### state (8 of 12 — missing 4)

| Have | Missing |
|------|---------|
| 1, 3-6, 8, 10, 12 | 2, 7, 9, 11 |

### treemap (1 of 10 — missing 9)

| Have | Missing |
|------|---------|
| basic | hierarchical, comma-separator, title-accessibility, themed-dark, value-format, multiline-accdescr, classdef, theme-forest, complex |

### treeView (2 of 10 — missing 8)

| Have | Missing |
|------|---------|
| annotations, icons | basic-tree, custom-config, icon-suppression, multiple-roots, accessibility, special-files, deep-nesting, empty |

### xychart (26 of 27 — missing 1)

| Have | Missing |
|------|---------|
| 1-26 | 27-full-config |

---

## Fully Covered Types (3 types, 29 entries)

| Diagram Type | Corpus | Image |
|-------------|--------|-------|
| journey | 3 | 3 |
| pie | 14 | 14 |
| quadrantChart | 12 | 12 |

---

## Summary

| Status | Types | Entries |
|--------|-------|---------|
| Fully covered | 3 | 29 |
| Partially covered | 12 | 104 missing |
| Not covered at all | 13 | 131 missing |
| **Current baselines** | — | **161** |
| **Total missing** | — | **~235** |
| **Total corpus** | **28** | **396** |

## Root Cause

The `CorpusSnapshotTests.imageSnapshot` test already runs `renderImage` for every
diagram in the corpus. The missing baselines mean the CG image rendering pipeline
is failing — most likely returning `nil` (caught by `#require`) due to layouts
producing 0×0 bounds or unhandled edge cases in the renderer dispatch.

From AGENTS.md: *"~161 image baselines — missing image cases are rendering bugs
(layout producing 0×0 bounds)."*

## How to Regenerate

Once the rendering bugs are fixed:

```bash
SNAPSHOT_TESTING_RECORD=true swift test --filter CorpusSnapshotTests
```

Then update `SNAPSHOTS.md` with the new entries.
