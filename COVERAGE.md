# COVERAGE.md

Audit of importer and exporter coverage across the five source formats DiagramKit
ships: Mermaid, D2, Graphviz DOT, Structurizr, PlantUML. The corpus carries 28
diagram families. Mermaid is the canonical model surface — every other format
imports/exports a subset by projecting into a Mermaid-equivalent payload.

Last audited: 2026-05-21 (Wave G). Cross-reference [CLAUDE.md](CLAUDE.md)
"What Lives Where" for slice paths and [BASELINES.md](BASELINES.md) for
corpus counts.

## Legend

- `★` — native: this family's parser/layout lives here (Mermaid only)
- `✓` — full: importer/exporter produces a complete result with no lossy diagnostics
- `⚠` — partial: importer/exporter completes but emits `.lossyTransform` /
  `.featureDropped` / informational diagnostics
- `—` — not implemented: dispatch falls through to `.unsupportedDiagram` (export)
  or family never appears in payload union (import)
- The import and export tables both reach zero `⚠` for every covered
  (family × format) intersection after the 2026-05-20-residuals spec.
  Foreign-native features that have no Mermaid landing slot (D2 `vars`,
  `layers`, `style` blocks, DOT `splines`/`rank`/layout engine attrs,
  etc.) continue to emit `slotUnsupported` and stay documented `—` in
  the matrix below; they are out of scope for the canonical
  Mermaid-equivalent payload model.

## Import coverage

| Family            | Mermaid | D2 | DOT | Structurizr | PlantUML |
|-------------------|:-------:|:--:|:---:|:-----------:|:--------:|
| flowchart         |   ★    | ✓ | ✓  |     —      |    ✓    |
| stateDiagram      |   ★    | ✓ | ✓  |     —      |    ✓    |
| sequenceDiagram   |   ★    | ✓ | —  |     —      |    ✓    |
| classDiagram      |   ★    | ✓ | ✓  |     —      |    ✓    |
| erDiagram         |   ★    | ✓ | ✓  |     —      |    ✓    |
| xyChart           |   ★    | — | —  |     —      |    —    |
| pie               |   ★    | — | —  |     —      |    —    |
| journey           |   ★    | — | —  |     —      |    —    |
| gantt             |   ★    | — | —  |     —      |    ✓    |
| quadrantChart     |   ★    | — | —  |     —      |    —    |
| requirement       |   ★    | — | —  |     —      |    —    |
| gitGraph          |   ★    | — | —  |     —      |    —    |
| mindmap           |   ★    | ✓ | ✓  |     —      |    ✓    |
| timeline          |   ★    | — | —  |     —      |    —    |
| sankey            |   ★    | — | —  |     —      |    —    |
| block             |   ★    | — | —  |     —      |    —    |
| packet            |   ★    | — | —  |     —      |    —    |
| kanban            |   ★    | — | —  |     —      |    —    |
| architecture      |   ★    | ✓ | ✓  |     —      |    ✓    |
| radar             |   ★    | — | —  |     —      |    —    |
| treemap           |   ★    | — | —  |     —      |    —    |
| venn              |   ★    | — | —  |     —      |    —    |
| ishikawa          |   ★    | — | —  |     —      |    —    |
| treeView          |   ★    | ✓ | ✓  |     —      |    —    |
| eventModeling     |   ★    | — | —  |     —      |    —    |
| wardleyBeta       |   ★    | — | —  |     —      |    —    |
| c4                |   ★    | ✓ | ✓  |     ✓      |    ✓    |
| zenuml            |   ★    | — | —  |     —      |    —    |
| **Totals**        | 28/28  | 9/28 | 8/28 | 1/28      | 9/28    |

## Export coverage

| Family            | Mermaid | D2 | DOT | Structurizr | PlantUML |
|-------------------|:-------:|:--:|:---:|:-----------:|:--------:|
| flowchart         |   ✓    | ✓ | ✓  |     —      |    ✓    |
| stateDiagram      |   ✓    | ✓ | ✓  |     —      |    ✓    |
| sequenceDiagram   |   ✓    | ✓ | —  |     —      |    ✓    |
| classDiagram      |   ✓    | ✓ | ✓  |     —      |    ✓    |
| erDiagram         |   ✓    | ✓ | ✓  |     —      |    ✓    |
| xyChart           |   ✓    | — | —  |     —      |    —    |
| pie               |   ✓    | — | —  |     —      |    —    |
| journey           |   ✓    | — | —  |     —      |    —    |
| gantt             |   ✓    | — | —  |     —      |    ✓    |
| quadrantChart     |   ✓    | — | —  |     —      |    —    |
| requirement       |   ✓    | — | —  |     —      |    —    |
| gitGraph          |   ✓    | — | —  |     —      |    —    |
| mindmap           |   ✓    | ✓ | ✓  |     —      |    ✓    |
| timeline          |   ✓    | — | —  |     —      |    —    |
| sankey            |   ✓    | — | —  |     —      |    —    |
| block             |   ✓    | — | —  |     —      |    —    |
| packet            |   ✓    | — | —  |     —      |    —    |
| kanban            |   ✓    | — | —  |     —      |    —    |
| architecture      |   ✓    | ✓ | ✓  |     —      |    ✓    |
| radar             |   ✓    | — | —  |     —      |    —    |
| treemap           |   ✓    | — | —  |     —      |    —    |
| venn              |   ✓    | — | —  |     —      |    —    |
| ishikawa          |   ✓    | — | —  |     —      |    —    |
| treeView          |   ✓    | ✓ | ✓  |     —      |    —    |
| eventModeling     |   ✓    | — | —  |     —      |    —    |
| wardleyBeta       |   ✓    | — | —  |     —      |    —    |
| c4                |   ✓    | ✓ | ✓  |     ✓      |    ✓    |
| zenuml            |   ✓    | — | —  |     —      |    —    |
| **Totals**        | 28/28  | 9/28 | 8/28 | 1/28      | 9/28    |

## Round-trip discipline

`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` currently holds **40
same-format fixtures** (2 new D2 + DOT c4 fixtures since Wave F) and
**76 cross-format directed pairs** (38 unordered; +14 directed / +7
unordered c4 pairs added in Wave G).

| Layer | Coverage |
|-------|----------|
| Same-format | mermaid {flowchart, sequence, class, er, gantt, state, c4}, d2 {flowchart, class, state, er, architecture, mindmap, treeView, sequence, c4}, dot {flowchart, class, state, er, architecture, mindmap, treeView, c4}, plantuml {sequence, class, state, gantt, mindmap, c4, activity, er, useCase, object, component}, structurizr {c4} |
| Cross-format pairs | flowchart × {mermaid↔d2, mermaid↔dot, d2↔dot, mermaid↔plantuml}; sequence × {mermaid↔plantuml, mermaid↔d2, plantuml↔d2}; class × {mermaid↔plantuml, mermaid↔d2, mermaid↔dot, d2↔dot}; state × {mermaid↔d2, mermaid↔dot, d2↔dot}; er × {mermaid↔plantuml, mermaid↔d2, mermaid↔dot, d2↔dot}; architecture × {mermaid↔d2, mermaid↔dot, d2↔dot}; mindmap × {mermaid↔d2, mermaid↔dot, d2↔dot}; treeView × {mermaid↔d2, mermaid↔dot, d2↔dot}; c4 × {mermaid↔plantuml, mermaid↔structurizr, plantuml↔structurizr, mermaid↔d2, mermaid↔dot, plantuml↔d2, plantuml↔dot, structurizr↔d2, structurizr↔dot, d2↔dot} |

Every supported import × export intersection that produces a non-empty result
has a round-trip fixture. There are no missing pairs given today's supported
families — the gaps in the matrix above are the gaps to close.

## Partial-support detail

**Both the import and export tables now have zero `⚠` cells** for every
covered (family × format) intersection. Closure landed across four waves
of two specs (plus PlantUML deployment dialect and Wave E):

- **Waves A/B/C** of
  [docs/superpowers/specs/2026-05-20-coverage-marker-recovery-design.md](docs/superpowers/specs/2026-05-20-coverage-marker-recovery-design.md)
  closed every export-side `⚠` via the comment-encoded recovery-marker
  pattern (Structurizr-style pre-lexer scan + positional correlation).
- **Wave D** of
  [docs/superpowers/specs/2026-05-20-import-coverage-residuals-design.md](docs/superpowers/specs/2026-05-20-import-coverage-residuals-design.md)
  closed every import-side `⚠`:
  - Class-family residuals (3 cells): D2/DOT class `link`/`tooltip`/`style`
    routed into `ClassNode.link`/`.tooltip`/`.styles`; PlantUML
    `<<stereotype>>` lifted into `ClassNode.annotations`, `package` blocks
    surfaced as `ClassNamespace` with `ClassNode.parent` populated.
  - State + ER family residuals (4 cells): D2/DOT composite-state
    containers lifted into `MermaidSubgraph`; D2 `{lo..hi}` and DOT
    crow's-foot arrow tokens (`tee`/`crow`/`odot`/`crowodot`) mapped to
    `ErCardinality`.
  - PlantUML flowchart + architecture residuals (2 cells): activity
    `partition "Name" { … }` blocks lifted into `MermaidSubgraph`;
    component dialect `[component]` / `interface ()` mapped to a new
    `ArchitectureService.kind: ArchitectureServiceKind` field. The
    activity exporter emits matching `partition` blocks around subgraph
    members on round-trip.
- **PlantUML deployment dialect (no matrix cell change).** PlantUML's
  deployment syntax (`node`, `artifact`, `cloud`, `database`, `queue`,
  `storage`, etc. — 14 shape kinds) now imports and exports through the
  `architecture` payload as a peer to the Wave-3 component dialect.
  Decorations (stereotypes, color tags, notes, legend, group kind,
  edge style) round-trip losslessly via comment-encoded recovery
  markers (`' diagramkit:deployment-*`). Cross-format export to
  Mermaid architecture emits `.lossyTransform(.shapeDowngrade, …)`
  per non-`.service` kind. No new `DiagnosticCategory` cases; reuses
  `.shapeDowngrade` / `.slotUnsupported`. Closes
  [`docs/superpowers/specs/2026-05-20-plantuml-deployment-design.md`](docs/superpowers/specs/2026-05-20-plantuml-deployment-design.md).
- **Wave E — D2 + DOT architecture / mindmap / treeView.** D2 and
  DOT each gain three families (no matrix `⚠` involved; all three
  were `—`). Detection: structural probe for architecture (≥2
  distinctive arch shapes — `cylinder`, `cloud`, `queue`, `page` for
  D2; `cylinder`, `component`, `note`, `folder`, `box3d` for DOT —
  `circle`/`hexagon`/`oval` excluded to avoid misclassifying common
  flowchart downgrades), marker-only for mindmap/treeView. Six new
  recovery-marker kinds (`family`, `arch-icon`, `arch-group`,
  `tree-root`, `mindmap-icon`; no `tree-collapsed` — `TreeViewNode`
  has no collapsed slot) preserve shape kinds across same-format
  round-trip. Cross-format `mermaid ↔ d2/dot` paths bridge Mermaid's
  icon-based shape encoding (`service.icon: String`) with D2/DOT's
  kind-based encoding via reciprocal `iconForKind`/`kindForIcon`
  helpers on both mappers. No new `DiagnosticCategory` cases; reuses
  `.shapeDowngrade` / `.slotUnsupported` / `.idSanitization`. Closes
  [`docs/superpowers/specs/2026-05-20-d2-dot-coverage-wave-e-design.md`](docs/superpowers/specs/2026-05-20-d2-dot-coverage-wave-e-design.md).
- **Wave G — D2 + DOT c4.** D2 and DOT each gain one family (no matrix
  `⚠` involved; all four cells were `—`). Detection: marker-forced
  (`# diagramkit:family=c4`) or presence-of-any-c4-marker structural
  fallback. Eleven new shared recovery-marker kinds (`c4DiagramKind`,
  `c4ShapeKind`, `c4External`, `c4Technology`, `c4Description`,
  `c4Sprite`, `c4Tag`, `c4Link`, `c4BoundaryKind`, `c4RelKind`,
  `c4Color`) preserve all 22 `C4ShapeType` variants, all 5
  `C4DiagramKind` values, all 7 `C4RelationshipKind` flavors, boundary
  nesting + kind, technology / description / sprite / tag / link
  metadata, and packed shape / relationship colors. D2/DOT exporters
  skip the implicit `global` boundary; D2/DOT importers synthesize
  it on parse, matching Mermaid's c4 importer behaviour so
  cross-format round-trips stay clean. Cross-format paths
  `mermaid ↔ d2/dot`, `plantuml ↔ d2/dot`, `structurizr ↔ d2/dot`,
  `d2 ↔ dot` (7 unordered, 14 directed) bridge through the canonical
  `C4Diagram` payload — no format-specific shortcut paths. No new
  `DiagnosticCategory` cases; reuses `.shapeDowngrade` /
  `.styleDrop` / `.slotUnsupported` / `.idSanitization`. No new
  `RoundTripLoss` cases. Closes
  [`docs/superpowers/specs/2026-05-21-d2-dot-c4-design.md`](docs/superpowers/specs/2026-05-21-d2-dot-c4-design.md).
- **Wave F — D2 sequenceDiagram.** D2 gains one family (no matrix `⚠`
  involved; the cell was `—`). Detection: structural probe for a
  top-level `shape: sequence_diagram` declaration plus marker-forced
  family override (`# diagramkit:family=sequence`). Eleven new
  recovery-marker kinds (`seq-actor-kind`, `seq-arrow-type`,
  `seq-message-attr`, `seq-block-type`, `seq-block-divider`,
  `seq-note`, `seq-box`, `seq-autonumber`, `seq-title`,
  `seq-acc-title`, `seq-acc-descr`) preserve participant types,
  arrow types (all 26 `SequenceArrowType` values), block types,
  block dividers, notes, boxes, autonumber, and accessibility
  metadata across same-format round-trip. D2 only supports `->`,
  `<->`, and `--` natively; the exporter always emits `->` for
  non-bidirectional flavors and the paired `seq-arrow-type` marker
  carries the exact arrow type. Cross-format `mermaid ↔ d2` and
  `plantuml ↔ d2` paths bridge via the natural shared subset
  (participants, three arrow flavors, alt/opt/loop blocks, notes,
  autonumber, title). No new `DiagnosticCategory` cases; reuses
  `.shapeDowngrade` / `.styleDrop` / `.idSanitization` /
  `.slotUnsupported`. No new `RoundTripLoss` cases. Closes
  [`docs/superpowers/specs/2026-05-21-d2-sequence-design.md`](docs/superpowers/specs/2026-05-21-d2-sequence-design.md).

The only new public surface across Wave D is the
`ArchitectureServiceKind` enum (`service` / `component` / `interface`)
plus a defaulted `kind` field on `ArchitectureService`/
`PositionedArchitectureService`. A public memberwise `init` was added to
`ClassNamespace` so foreign importers can construct one.

## Gaps and the work to close them

The gap table reduces to four kinds of work, ordered by ratio of payoff to
effort. "Payoff" here means "users hit this combo on real input." Most of the
unimplemented cells are syntactically out-of-scope for the foreign format
(e.g. a Sankey in PlantUML, a Gantt in DOT) — those are documented below so the
backlog stays honest about which gaps are real candidates.

### 1. PlantUML expansion (natural-fit families only)

PlantUML upstream supports diagram dialects beyond the six DiagramKit covers.
The natural additions are:

| Family | PlantUML idiom | Effort |
|--------|----------------|--------|
| activity (maps to flowchart) | `@startuml` + `start`/`:label;`/`stop` activity blocks | Medium — needs an activity → flowchart payload mapper distinct from the existing state parser, plus a flowchart-from-PlantUML exporter |
| erDiagram | PlantUML "Information Engineering" / `entity` syntax | Medium — well-specified in PlantUML; an import/export pair would pin the corpus side via existing Mermaid ER fixtures |
| useCase (maps to flowchart) | `(usecase)`, `:actor:`, `-->` | Low-medium — small parser, projects to flowchart payload |
| object (maps to classDiagram) | `object` blocks | Low — variant of class importer |
| component (maps to architecture or c4) | `[component]` + `interface` | Medium — needs target-payload decision before parsing |
| salt / wireframe | mockup DSL | Out of scope — no DiagramKit target payload |

Files to add live under `Sources/DiagramKitPlantUML/` (parser + mapper) and
`Sources/DiagramKitPlantUML/Exporter/`. The router in
`Sources/DiagramKitPlantUML/PlantUMLImporter.swift:36-129` already cascades by
header keyword and is the dispatch site to extend.

### 2. D2 and DOT expansion (mostly mismatch, narrow opportunities)

D2 and DOT are general directed-graph formats. The vast majority of DiagramKit
families don't translate: pie charts, gantt timelines, sankey flows, radar
plots, etc. are not expressible as labelled-edge graphs without lossy projection
that defeats the purpose of round-tripping.

Realistic candidates:

| Family | D2 | DOT | Notes |
|--------|:--:|:---:|-------|
| classDiagram | possible | possible | DOT has `record` shapes; D2 has `shape: class`. Lossy on stereotypes/visibility but recoverable with diagnostics. |
| stateDiagram | possible | possible | Maps to general digraph with start/end pseudo-states. DOT idiom is well-established. |
| erDiagram | possible | possible | DOT `record`/HTML labels are the classic representation. |
| architecture | possible | weak | D2 has containers; DOT has clusters. |
| treeView / mindmap | possible | possible | Both reduce to directed trees. Output would be readable but not idiomatic. |

The remaining 18+ families have no defensible D2/DOT projection and should stay
`—`. Anything added here must come with `.lossyTransform` diagnostics per
[docs/diagnostic-severity-discipline.md](docs/diagnostic-severity-discipline.md)
and round-trip fixtures.

### 3. Structurizr scope

Structurizr is purpose-built for C4. Wave 3 of the coverage-expansion spec
(closed 2026-05-19) landed comment-encoded recovery for tags and nested
boundaries plus a multi-view import loop. The `⚠` cell moved to `✓`; the
`first-view-only` diagnostic is gone. No further work is currently scoped
for the Structurizr slice; new family rows require a concrete user need
(per the spec's Out of Scope).

## Backlog summary

Ordered by impact:

1. ~~**PlantUML: activity, erDiagram, useCase, object, component (5 families,
   import + export each).**~~ Closed by Wave 1 of the coverage-expansion spec.
2. ~~**D2 + DOT: classDiagram, stateDiagram, erDiagram (3 families each, both
   directions, with documented lossy diagnostics).**~~ Closed by Wave 2 of the
   coverage-expansion spec (closing commit on the Wave 2 closer).
3. ~~**Structurizr: tag/boundary lossy export + multi-view import.**~~ Closed
   by Wave 3 of the coverage-expansion spec (closed 2026-05-19).
4. ~~**Recovery-marker generalization to D2/DOT/PlantUML for export-side `⚠`
   closure.**~~ Closed by the 2026-05-20 coverage-marker-recovery spec.
5. ~~**Import-side residual `⚠` cells (9 cells) via Mermaid payload wiring.**~~
   Closed by the 2026-05-20 import-coverage-residuals spec.
6. ~~**D2 + DOT expansion: architecture, mindmap, treeView (3 families × 2
   formats × both directions, marker-recovered round-trip).**~~ Closed by
   Wave E (2026-05-20-d2-dot-coverage-wave-e spec).
7. ~~**D2 expansion: sequenceDiagram (one family × both directions,
   marker-recovered round-trip).**~~ Closed by Wave F
   (2026-05-21-d2-sequence spec).
8. ~~**D2 + DOT expansion: c4 (one family × two formats × both
   directions, marker-recovered round-trip + 7 new cross-format
   pairs).**~~ Closed by Wave G
   (2026-05-21-d2-dot-c4 spec).

Anything outside this list (Wardley, Sankey, Packet, Treemap, etc. in non-native
formats) is a deliberate `—` and should not be added without a concrete user
need.

## Source paths

| Slice | Importer | Exporter |
|-------|----------|----------|
| Mermaid | `Sources/DiagramKit/MermaidImporter.swift` (fallback; 28-family) | `Sources/DiagramKitMermaid/Exporter/MermaidExporter.swift` + `MermaidExport/` |
| D2 | `Sources/DiagramKitD2/D2Importer.swift` (+ `D2Parser.swift`, `D2Mapper.swift`) | `Sources/DiagramKitD2/D2Exporter.swift` |
| DOT | `Sources/DiagramKitGraphviz/GraphvizImporter.swift` (+ `DOTParser.swift`, `DOTMapper.swift`) | `Sources/DiagramKitGraphviz/DOTExporter.swift` + `DOTFlowchartExport.swift` |
| Structurizr | `Sources/DiagramKitStructurizr/StructurizrImporter.swift` (+ parser/mapper) | `Sources/DiagramKitStructurizr/StructurizrExporter.swift` |
| PlantUML | `Sources/DiagramKitPlantUML/PlantUMLImporter.swift` (+ per-family parsers, `PlantUMLFamilyProbe.swift`) | `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift` + per-family exporters |
| Round-trip fixtures | — | `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` |
| Corpus | — | `Sources/DiagramKitSample/Resources/test-diagrams.json` (424 entries: 397 Mermaid + 27 multi-format) |
