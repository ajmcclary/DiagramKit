# Foreign-Format Coverage Expansion — Design

**Date:** 2026-05-19
**Status:** Approved (brainstorm)
**Source backlog:** [COVERAGE.md](../../../COVERAGE.md) §"Backlog summary" → items 1, 2, 3.

## Goal

Close the three remaining items on the [COVERAGE.md](../../../COVERAGE.md)
foreign-format backlog in a single spec driving three wave plans. After this
work, the import/export tables move to their theoretical ceiling under the
current DiagramKit family set:

| Format       | Import today → after | Export today → after |
|--------------|----------------------|----------------------|
| D2           | 1/28 → 4/28          | 1/28 → 4/28          |
| DOT          | 1/28 → 4/28          | 1/28 → 4/28          |
| Structurizr  | 1/28 (✓, gains multi-view depth) | 1/28 (⚠ → ✓ lift) |
| PlantUML     | 6/28 → 11/28         | 6/28 → 11/28         |

(Structurizr × c4 import is already ✓; multi-view enriches what one ✓ cell
carries without changing the cell glyph. Only the export side moves ⚠ → ✓.)

The two existing ⚠ cells — Structurizr × c4 (export) and PlantUML ×
sequenceDiagram (export) — are addressed where the work cleanly admits it
(Wave 3 lifts Structurizr × c4 to ✓; the PlantUML sequence informational
diagnostic stays as documented partial).

### Success bar: ⚠ or ✓

A cell counts as closed if it lands at **⚠ or ✓**, provided:

- every observed loss is paired to a typed `.lossyTransform` /
  `.featureDropped` / `.informational` diagnostic
  ([docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)),
  and
- `DiagramKitTestSupport.RoundTripHarness` round-trips the new fixture
  (`parse → export → parse → assert structurally equal`), with every
  `RoundTripLoss` paired to a diagnostic by `DiagnosticCategory` equality.

## In Scope

Three waves, one per [COVERAGE.md](../../../COVERAGE.md) backlog item:

- **Wave 1 — PlantUML expansion.** Five new PlantUML idioms (`activity`,
  `erDiagram`, `useCase`, `object`, `component`), import + export each. Each
  projects onto an existing DiagramKit family payload — no new `typedPayload`
  cases.
- **Wave 2 — D2 + DOT expansion.** Three families (`classDiagram`,
  `stateDiagram`, `erDiagram`) × two formats × two directions = 12 cells.
  Lossy on stereotype/visibility/state-action/cardinality decoration as
  COVERAGE.md predicted; closed at ⚠ with typed diagnostics.
- **Wave 3 — Structurizr enrichment.** No new family rows. Two enhancements:
  (a) comment-encoded recovery of dropped tag/boundary data lifts Structurizr ×
  c4 export from ⚠ to ✓; (b) multi-view import parses every view in a
  workspace, with the first view remaining the rendered output for back-compat.

## Out of Scope

- **No new DiagramKit family payloads.** Every new format cell lands on an
  existing `DiagramDocument.typedPayload` case.
- **No corpus growth.** `Sources/DiagramKitSample/Resources/test-diagrams.json`
  stays at 424 entries; SVG/image/ASCII snapshot baselines stay at 437/437/424.
  New tests live exclusively under
  `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`.
- **No new public surface.** No new modules, no new public types. Work fits
  inside existing `DiagramKitPlantUML`, `DiagramKitD2`, `DiagramKitGraphviz`,
  `DiagramKitStructurizr` slices.
- **No new Mermaid family rows.** Mermaid stays at 28/28 native; the spec
  follows the closed-iteration baseline from
  [2026-05-19-mermaid-exporter-completion-design.md](2026-05-19-mermaid-exporter-completion-design.md).
- **PlantUML salt/wireframe mockups, treeView/mindmap projections to D2/DOT,
  and other COVERAGE.md `—` cells without a defensible projection.** They stay
  documented `—` unless a concrete user need surfaces later.

## Invariants Preserved

- **No thread pool.** Parsers and exporters run synchronously on the same
  dispatch as today; the 8 MB-stack `Thread` worker model in
  `DiagramEngine._runOnWorker` is untouched. Narrow per-parser cache queues
  serializing a single regex/formatter are still allowed.
- **File-size policy** (500-line warn / 1000-line error per
  `Scripts/check-file-sizes.sh`). One file per family keeps each new file well
  under the warn line. Where a host file (e.g. `D2Exporter.swift`,
  `StructurizrImporter.swift`) would cross the warn line, the wave plan splits
  it (see Architecture).
- **Diagnostic discipline.** Only typed `DiagramDiagnostic` factories
  (`.lossyTransform` / `.featureDropped` / `.informational`); raw
  `DiagramDiagnostic(severity:message:)` remains deprecated and
  `Scripts/check-diagnostic-discipline.sh` enforces it.
- **Round-trip discipline.** Every new exporter wires into
  `DiagramKitTestSupport.RoundTripHarness`. `RoundTripLoss` admits no
  `case other(_)`; new loss kinds extend the enum and pair to a typed
  diagnostic category.
- **Public surface unchanged.** No new public types, no new module boundaries.
- **Linux portability.** `DiagramKitPlantUML`, `DiagramKitD2`,
  `DiagramKitGraphviz`, `DiagramKitStructurizr` are already Linux-portable.
  All new code stays Linux-portable — no `BMColor` / `BMFont` / CoreText reach.
- **Worker invariant scope.** Same as
  [CLAUDE.md](../../../CLAUDE.md#critical-invariants): the no-thread-pool rule
  applies to `Sources/DiagramKit*/` production code on the parse/layout/render
  path; test suites and the sample app remain out of scope.

## Architecture & File Layout

### Wave 1 — PlantUML (`Sources/DiagramKitPlantUML/`)

Follows the established slice convention: one **per-family subdirectory**
(matching `C4/`, `Class/`, `Sequence/`, `State/`, `Mindmap/`, `Gantt/`) each
holding AST + Parser + Mapper, and one shared `Exporter/` directory:

```
Activity/
  PlantUMLActivityAST.swift           — token/line struct types
  PlantUMLActivityParser.swift        — body → AST
  PlantUMLActivityMapper.swift        — AST → flowchart payload + diagnostics
ER/
  PlantUMLERAST.swift
  PlantUMLERParser.swift
  PlantUMLERMapper.swift              — AST → erDiagram payload + diagnostics
UseCase/
  PlantUMLUseCaseAST.swift
  PlantUMLUseCaseParser.swift
  PlantUMLUseCaseMapper.swift         — AST → flowchart payload + diagnostics
Object/
  PlantUMLObjectAST.swift
  PlantUMLObjectParser.swift
  PlantUMLObjectMapper.swift          — AST → classDiagram payload + diagnostics
Component/
  PlantUMLComponentAST.swift
  PlantUMLComponentParser.swift
  PlantUMLComponentMapper.swift       — AST → architecture payload + diagnostics
Exporter/
  PlantUMLActivityExporter.swift
  PlantUMLERExporter.swift
  PlantUMLUseCaseExporter.swift
  PlantUMLObjectExporter.swift
  PlantUMLComponentExporter.swift
```

`PlantUMLFamilyProbe.swift` and `PlantUMLImporter.swift:36-129` gain new
probes and dispatch branches for the five new families.

- `PlantUMLImporter.swift:36-129` cascade gains five new header-keyword
  branches; family disambiguation runs through `PlantUMLFamilyProbe.swift`
  on the body (e.g. `start`/`stop` keyword → activity; `entity` keyword →
  erDiagram; `(usecase)` token → useCase; `object` keyword → object;
  `[component]` token → component).
- `PlantUMLExporter.swift` dispatch grows five new cases against
  `DiagramDocument.typedPayload` — they coexist with the existing six
  exporter cases. The dispatch chooses among PlantUML idioms when more than
  one targets the same payload (e.g. flowchart payload → activity unless
  caller hints useCase via a future option; default to activity).

#### PlantUML component → architecture

PlantUML component diagrams (`[component]` + `interface`) map to the
`architecture` payload (services with typed interfaces and connection
lines). Lossy on stereotypes; emits `.featureDropped(.styling, …)` for
interface-vs-component visual distinction. Round-trips structurally via the
existing architecture payload + renderer.

### Wave 2 — D2 + DOT (`Sources/DiagramKitD2/`, `Sources/DiagramKitGraphviz/`)

```
DiagramKitD2/
  D2Mapper.swift            (extended: classDiagram, stateDiagram, erDiagram cases)
  D2Parser.swift            (extended: shape: class / sql_table recognition)
  D2ClassExporter.swift     (new — split out so D2Exporter.swift stays under warn line)
  D2StateExporter.swift
  D2ERExporter.swift
DiagramKitGraphviz/
  DOTMapper.swift           (extended)
  DOTParser.swift           (extended: record / HTML-label recognition)
  DOTClassExport.swift      (new, mirrors DOTFlowchartExport.swift pattern)
  DOTStateExport.swift
  DOTERExport.swift
```

- D2 idioms: `shape: class` for classDiagram, digraph + start/end pseudo-state
  for stateDiagram, `shape: sql_table` for erDiagram.
- DOT idioms: `record` shape / HTML labels for classDiagram and erDiagram,
  general digraph + start/end pseudo-state for stateDiagram.
- `DOTExporter.swift` currently surfaces `.unsupported` for non-flowchart
  payloads. Wave 2 replaces three of those fall-throughs with real cases.

### Wave 3 — Structurizr (`Sources/DiagramKitStructurizr/`)

- `StructurizrExporter.swift`:
  - lines 70–82 (nested-boundary flattening): replace `.lossyTransform(.structure, …)`
    emission with `# diagramkit:boundary-parent=<id>` comments adjacent to the
    flattened group lines.
  - line 170 (element tags): replace `.featureDropped(.styling, …)` emission
    with `# diagramkit:tag=<name>` comments adjacent to the element line.
  - lines 226–246 (alias rewriting): unchanged — already silent, semantically
    safe.
- `StructurizrImporter.swift:24-39`:
  - factor view parsing into a loop emitting metadata for every view in the
    workspace; the first view remains the document's rendered/exported view
    for back-compat with current callers.
  - add comment-recovery hooks that re-attach `# diagramkit:tag=…` and
    `# diagramkit:boundary-parent=…` metadata onto the corresponding
    element/group structures during import.
- No new files necessary; if the importer crosses the warn line during
  multi-view work, split a `StructurizrViewParser.swift`.

Net Structurizr × c4 export effect: the two existing ⚠ emission sites are
*removed* because the data round-trips. Cell moves ⚠ → ✓.

## Diagnostics & Round-Trip Pairing

**Typed factories only.** Decision tree, category table, silent-drop policy,
and throw boundary live in
[docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md).
`Scripts/check-diagnostic-discipline.sh` enforces this in the merge gate.

**Per-wave category mapping.** `DiagnosticCategory`
(`Sources/DiagramKitCommon/DiagnosticCategory.swift`) statically pins severity
per case; the factory `precondition`s on the match. Existing cases cover most
of the new loss kinds; the remaining few extend the enum in their wave plan
(`DiagnosticCategory` + `RoundTripLoss` + harness coverage all bump together,
per [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md)).

| Loss kind                                                                   | Factory + category                                  | Enum status |
|-----------------------------------------------------------------------------|-----------------------------------------------------|-------------|
| Swimlane / partition lost (PlantUML activity → flowchart)                   | `.lossyTransform(.subgraphFlatten, …)`              | existing    |
| Actor-vs-usecase styling lost (PlantUML useCase → flowchart)                | `.featureDropped(.styleDrop, …)` — `styleDrop` is `.warning`; emit via `lossyTransform` if not "feature-absent" | use `.lossyTransform(.styleDrop, …)` (style is dropped, but target has the underlying node shape — not a `featureDropped` case) |
| Object-vs-class distinction lost (PlantUML object → classDiagram)           | `.lossyTransform(.shapeDowngrade, …)`               | existing    |
| Interface-vs-component styling lost (PlantUML component → architecture)     | `.lossyTransform(.styleDrop, …)`                    | existing    |
| Stereotype lost (classDiagram → D2/DOT)                                     | `.lossyTransform(.classStereotypeDrop, …)`          | **new case** in Wave 2 plan |
| Visibility marker lost (classDiagram → D2/DOT)                              | `.lossyTransform(.styleDrop, …)`                    | existing    |
| State entry/exit actions lost (stateDiagram → D2/DOT)                       | `.lossyTransform(.stateActionDrop, …)`              | **new case** in Wave 2 plan |
| Cardinality decoration lost (erDiagram → D2/DOT)                            | `.lossyTransform(.cardinalityDrop, …)`              | **new case** in Wave 2 plan |
| Structurizr tag (Wave 3 export, pre-recovery-comment paths only)            | n/a — comment-encoded, no diagnostic emitted        | removed in Wave 3 |
| Structurizr nested boundary flatten (Wave 3 export, pre-recovery paths)     | n/a — comment-encoded, no diagnostic emitted        | removed in Wave 3 |

Wave plans introduce three new `DiagnosticCategory` cases:
`classStereotypeDrop`, `stateActionDrop`, `cardinalityDrop`. All three are
`.warning`-severity (lossy structural transforms). Each gets a paired
`RoundTripLoss` case in `Sources/DiagramKitTestSupport/RoundTripLoss.swift`
and a matching `RoundTripLossTag` mapping so per-cell allow-lists keep
working.

`RoundTripLoss` (in `Sources/DiagramKitTestSupport/`) admits no
`case other(_)`. Wave plans extend the enum when a new loss kind has no
matching case; each new case pairs to a `DiagnosticCategory` for harness
matching.

**Structurizr Wave 3 inverts the pattern.** The diagnostic decision tree
emits only for *actual* loss. Comment-encoded recovery means no loss, no
diagnostic, cell moves ⚠ → ✓. The exporter's existing `.featureDropped` /
`.lossyTransform` sites at lines 70–82 and 170 are deleted, not redirected.

**No new throw sites.** All format-conversion failures continue to surface
through `DiagramImportResult.diagnostics` or
`DiagramExportResult.diagnostics` per the decision tree.

## Testing Strategy

Round-trip fixtures only. Snapshot baselines (437 SVG + 437 image + 424 ASCII
= 1298) stay frozen across all three waves. Corpus
(`Sources/DiagramKitSample/Resources/test-diagrams.json`) stays at 424
entries.

### Same-format fixtures added (per wave)

| Wave | New same-format fixtures (under `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/`) |
|------|------------------------------------------------------------------------------------------|
| 1    | `plantuml-activity`, `plantuml-er`, `plantuml-usecase`, `plantuml-object`, `plantuml-component` |
| 2    | `d2-class`, `d2-state`, `d2-er`, `dot-class`, `dot-state`, `dot-er` |
| 3    | `structurizr-c4-multiview` (extends existing single-view coverage); a regression case for tag/boundary `# diagramkit:` recovery comments |

### Cross-format pairs added (per wave, bidirectional in harness)

| Wave | New cross-format pairs |
|------|------------------------|
| 1    | `classDiagram × {mermaid↔plantuml-object}`; `erDiagram × {mermaid↔plantuml}`; `flowchart × {mermaid↔plantuml-activity, mermaid↔plantuml-usecase}`; `architecture × {mermaid↔plantuml-component}` |
| 2    | `classDiagram × {mermaid↔d2, mermaid↔dot, d2↔dot}`; `stateDiagram × {mermaid↔d2, mermaid↔dot, d2↔dot}`; `erDiagram × {mermaid↔d2, mermaid↔dot, d2↔dot}` |
| 3    | `c4 × {mermaid↔structurizr, plantuml↔structurizr}` updated to expect new `# diagramkit:` recovery comments; multi-view round-trip cases for new Structurizr view types |

### Verification commands per wave

```bash
swift test --filter RoundTrip                    # gate for all waves
swift test --filter PlantUMLImporter             # Wave 1 dispatch
swift test --filter D2Importer                   # Wave 2 D2
swift test --filter GraphvizImporter             # Wave 2 DOT
swift test --filter StructurizrImporter          # Wave 3 multi-view + recovery
```

Filters are exact suite names per the project memory — substring filters
like `--filter TreeView` match corpus parameterized cases and hang.

### Discipline gates (unchanged)

The existing merge gate carries:

- `Scripts/check-diagnostic-discipline.sh`
- `Scripts/check-file-sizes.sh` (allowlist:
  `Scripts/check-file-sizes-allowlist.txt`)
- `Scripts/check-sendable-annotations.sh`
- `Scripts/strict-concurrency-check.sh`
- `Scripts/linux-check.sh` (skipped when Docker/Podman is unavailable
  locally)
- `Scripts/bootstrap-smoke-check.sh` (chains the above + `swift test` +
  multiplatform `xcodebuild` sweep)

No new gates added.

## Documentation Upkeep

Each wave closes with:

- `COVERAGE.md` table edits: cells move from `—`/`⚠` to their final glyph
  per the success bar; totals row updates.
- `BASELINES.md` line for the new round-trip fixture counts (currently 16
  same-format + 16 directed cross-format = 32). After all three waves:
  same-format ≈ 16 + 12 = 28, cross-format directed ≈ 16 + 20+ = 36+, exact
  counts pinned in each wave plan.
- No `CLAUDE.md` invariants change.
- [ARCHITECTURE.md](../../../ARCHITECTURE.md) "Drift hazards" gets a new
  bullet noting the Structurizr `# diagramkit:` comment convention so future
  contributors don't strip the recovery comments.

## Wave Sequencing & Independence

The three waves are independent and can be implemented sequentially or in
parallel:

- **Wave 1 (PlantUML)** touches only `Sources/DiagramKitPlantUML/`.
- **Wave 2 (D2 + DOT)** touches only `Sources/DiagramKitD2/` and
  `Sources/DiagramKitGraphviz/`. No PlantUML dependencies.
- **Wave 3 (Structurizr)** touches only `Sources/DiagramKitStructurizr/`.
  No D2/DOT/PlantUML dependencies.

Round-trip fixtures touch the same `roundtrip/` directory but never collide
(disjoint filenames). Wave plans assume sequential execution (Wave 1 → 2 →
3, matching COVERAGE.md impact ordering) but parallel execution is safe if
the user later chooses to dispatch them concurrently.

## Resolved Open Questions (from brainstorm)

| Question                                                                         | Decision                                                                 |
|----------------------------------------------------------------------------------|--------------------------------------------------------------------------|
| Scope of the single spec                                                         | All three [COVERAGE.md](../../../COVERAGE.md) backlog items.             |
| Cell-closed bar (⚠ vs ✓)                                                         | ⚠ or ✓ both count, gated on typed diagnostics + round-trip.              |
| Wave split shape                                                                 | One wave per backlog item (PlantUML / D2+DOT / Structurizr).             |
| PlantUML `component` target payload                                              | `architecture`.                                                          |
| Corpus / snapshot growth                                                         | None. Round-trip fixtures only.                                          |
| Structurizr ⚠ resolution path                                                    | Comment-encoded recovery on export + parsing hooks on import.            |

## Backlog Discipline

Anything outside this spec stays a deliberate `—` in
[COVERAGE.md](../../../COVERAGE.md):

- Wardley, Sankey, Packet, Treemap, Radar, Quadrant, Kanban, Mindmap (in
  non-native formats other than where already shipped), Block, Architecture
  (outside the PlantUML component → architecture mapping), Timeline,
  Ishikawa, EventModeling, TreeView, Venn, GitGraph, ZenUML, Journey, Pie,
  XYChart, Requirement, C4 (outside the existing PlantUML/Structurizr/Mermaid
  triangle) — none of these have a defensible projection to D2/DOT/PlantUML/
  Structurizr without a concrete user need.

When a new family + format pair gains a concrete user need, that becomes its
own spec — not a Wave-N extension of this one.
