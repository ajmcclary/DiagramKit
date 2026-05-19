# COVERAGE.md

Audit of importer and exporter coverage across the five source formats DiagramKit
ships: Mermaid, D2, Graphviz DOT, Structurizr, PlantUML. The corpus carries 28
diagram families. Mermaid is the canonical model surface — every other format
imports/exports a subset by projecting into a Mermaid-equivalent payload.

Last audited: 2026-05-19. Cross-reference [CLAUDE.md](CLAUDE.md) "What Lives
Where" for slice paths and [BASELINES.md](BASELINES.md) for corpus counts.

## Legend

- `★` — native: this family's parser/layout lives here (Mermaid only)
- `✓` — full: importer/exporter produces a complete result with no lossy diagnostics
- `⚠` — partial: importer/exporter completes but emits `.lossyTransform` /
  `.featureDropped` / informational diagnostics
- `—` — not implemented: dispatch falls through to `.unsupportedDiagram` (export)
  or family never appears in payload union (import)

## Import coverage

| Family            | Mermaid | D2 | DOT | Structurizr | PlantUML |
|-------------------|:-------:|:--:|:---:|:-----------:|:--------:|
| flowchart         |   ★    | ✓ | ✓  |     —      |    ⚠    |
| stateDiagram      |   ★    | ⚠ | ⚠  |     —      |    ✓    |
| sequenceDiagram   |   ★    | — | —  |     —      |    ✓    |
| classDiagram      |   ★    | ⚠ | ⚠  |     —      |    ⚠    |
| erDiagram         |   ★    | ⚠ | ⚠  |     —      |    ✓    |
| xyChart           |   ★    | — | —  |     —      |    —    |
| pie               |   ★    | — | —  |     —      |    —    |
| journey           |   ★    | — | —  |     —      |    —    |
| gantt             |   ★    | — | —  |     —      |    ✓    |
| quadrantChart     |   ★    | — | —  |     —      |    —    |
| requirement       |   ★    | — | —  |     —      |    —    |
| gitGraph          |   ★    | — | —  |     —      |    —    |
| mindmap           |   ★    | — | —  |     —      |    ✓    |
| timeline          |   ★    | — | —  |     —      |    —    |
| sankey            |   ★    | — | —  |     —      |    —    |
| block             |   ★    | — | —  |     —      |    —    |
| packet            |   ★    | — | —  |     —      |    —    |
| kanban            |   ★    | — | —  |     —      |    —    |
| architecture      |   ★    | — | —  |     —      |    ⚠    |
| radar             |   ★    | — | —  |     —      |    —    |
| treemap           |   ★    | — | —  |     —      |    —    |
| venn              |   ★    | — | —  |     —      |    —    |
| ishikawa          |   ★    | — | —  |     —      |    —    |
| treeView          |   ★    | — | —  |     —      |    —    |
| eventModeling     |   ★    | — | —  |     —      |    —    |
| wardleyBeta       |   ★    | — | —  |     —      |    —    |
| c4                |   ★    | — | —  |     ✓      |    ✓    |
| zenuml            |   ★    | — | —  |     —      |    —    |
| **Totals**        | 28/28  | 4/28 | 4/28 | 1/28      | 9/28    |

## Export coverage

| Family            | Mermaid | D2 | DOT | Structurizr | PlantUML |
|-------------------|:-------:|:--:|:---:|:-----------:|:--------:|
| flowchart         |   ✓    | ✓ | ✓  |     —      |    ⚠    |
| stateDiagram      |   ✓    | ⚠ | ⚠  |     —      |    ✓    |
| sequenceDiagram   |   ✓    | — | —  |     —      |    ⚠    |
| classDiagram      |   ✓    | ⚠ | ⚠  |     —      |    ⚠    |
| erDiagram         |   ✓    | ⚠ | ⚠  |     —      |    ✓    |
| xyChart           |   ✓    | — | —  |     —      |    —    |
| pie               |   ✓    | — | —  |     —      |    —    |
| journey           |   ✓    | — | —  |     —      |    —    |
| gantt             |   ✓    | — | —  |     —      |    ✓    |
| quadrantChart     |   ✓    | — | —  |     —      |    —    |
| requirement       |   ✓    | — | —  |     —      |    —    |
| gitGraph          |   ✓    | — | —  |     —      |    —    |
| mindmap           |   ✓    | — | —  |     —      |    ✓    |
| timeline          |   ✓    | — | —  |     —      |    —    |
| sankey            |   ✓    | — | —  |     —      |    —    |
| block             |   ✓    | — | —  |     —      |    —    |
| packet            |   ✓    | — | —  |     —      |    —    |
| kanban            |   ✓    | — | —  |     —      |    —    |
| architecture      |   ✓    | — | —  |     —      |    ⚠    |
| radar             |   ✓    | — | —  |     —      |    —    |
| treemap           |   ✓    | — | —  |     —      |    —    |
| venn              |   ✓    | — | —  |     —      |    —    |
| ishikawa          |   ✓    | — | —  |     —      |    —    |
| treeView          |   ✓    | — | —  |     —      |    —    |
| eventModeling     |   ✓    | — | —  |     —      |    —    |
| wardleyBeta       |   ✓    | — | —  |     —      |    —    |
| c4                |   ✓    | — | —  |     ✓      |    ✓    |
| zenuml            |   ✓    | — | —  |     —      |    —    |
| **Totals**        | 28/28  | 4/28 | 4/28 | 1/28      | 9/28    |

## Round-trip discipline

`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` currently holds **30
same-format fixtures** and **40 cross-format directed pairs** (20 unordered).

| Layer | Coverage |
|-------|----------|
| Same-format | mermaid {flowchart, sequence, class, er, gantt, state, c4}, d2 {flowchart, class, state, er}, dot {flowchart, class, state, er}, plantuml {sequence, class, state, gantt, mindmap, c4, activity, er, useCase, object, component}, structurizr {c4} |
| Cross-format pairs | flowchart × {mermaid↔d2, mermaid↔dot, d2↔dot, mermaid↔plantuml}; sequence × {mermaid↔plantuml}; class × {mermaid↔plantuml, mermaid↔d2, mermaid↔dot, d2↔dot}; state × {mermaid↔d2, mermaid↔dot, d2↔dot}; er × {mermaid↔plantuml, mermaid↔d2, mermaid↔dot, d2↔dot}; c4 × {mermaid↔plantuml, mermaid↔structurizr, plantuml↔structurizr} |

Every supported import × export intersection that produces a non-empty result
has a round-trip fixture. There are no missing pairs given today's supported
families — the gaps in the matrix above are the gaps to close.

## Partial-support detail

The remaining `⚠` cell is real:

- **PlantUML × sequenceDiagram (export)** — `PlantUMLSequenceExporter` emits
  an informational diagnostic for dropped link/properties/detail features
  (`Sources/DiagramKitPlantUML/Exporter/PlantUMLSequenceExporter.swift:126`).

All other PlantUML exporters (class, state, mindmap, gantt, c4) produce
diagnostic-free output. The orange-triangle indicators in some external UI
visualisations for PlantUML × {class, gantt, mindmap, c4} do **not** match the
code: those exports are `✓`, not `⚠`.

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
| c4 | maps via flowchart | maps via flowchart | Both formats can express containment graphs but lose the C4 view-type metadata; would need `.lossyTransform` diagnostics. |
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
