# 2026-05-21 — D2 + DOT block coverage (Wave J)

## Summary

Add `block` import + export to the `DiagramKitD2` and `DiagramKitGraphviz`
slices, taking D2 coverage from 9/28 → **10/28** and DOT coverage from
8/28 → **9/28** in each direction. The `block` family is the next
defensible borderline-natural extension after Wave G closed `c4`: block
diagrams are a tree of typed shape containers with a grid layout, which
maps cleanly onto D2's native containers + `grid-columns` and onto DOT's
clusters + `rank=same` row grouping. The 23 `BlockNodeType` shape kinds,
`blockArrow` direction sets, `widthInColumns` spans, `classDef`/`class`
apply tables, and `BlockEdge` style/arrow attributes all round-trip
losslessly on same-format via comment-encoded recovery markers; cross-
format paths to/from Mermaid carry only the typed shape-downgrade and
style-drop losses already in the loss enum.

No new public surface, no new `DiagnosticCategory` cases, no new
`RoundTripLoss` cases.

This builds on:

- [`2026-05-19-coverage-expansion-design.md`](2026-05-19-coverage-expansion-design.md)
  (Wave 2 — D2/DOT class/state/er): per-family mapper + exporter
  layering this spec reuses.
- [`2026-05-20-coverage-marker-recovery-design.md`](2026-05-20-coverage-marker-recovery-design.md):
  the comment-encoded recovery-marker pattern and the existing
  `D2RecoveryMarker.scanner` / `DOTRecoveryMarker.scanner` infrastructure.
- [`2026-05-20-d2-dot-coverage-wave-e-design.md`](2026-05-20-d2-dot-coverage-wave-e-design.md)
  (Wave E): the structural-probe-plus-marker-recovery dispatch
  pattern in `D2Importer.parse` and `GraphvizImporter.parse`, and the
  container-tree mapper shape that Wave J's block mapper inherits from.
- [`2026-05-21-d2-dot-c4-design.md`](2026-05-21-d2-dot-c4-design.md)
  (Wave G): the most recent precedent for slotting a new family into
  both D2 and DOT in a single wave with shared marker kinds.

## Matrix delta

| Family | D2 (was → now) | DOT (was → now) |
|--------|:--------------:|:---------------:|
| block  | — → ✓          | — → ✓           |

Totals after Wave J:

- D2 import: 9/28 → **10/28**
- D2 export: 9/28 → **10/28**
- DOT import: 8/28 → **9/28**
- DOT export: 8/28 → **9/28**

## Scope

### In scope

- New D2 block mapper, exporter, and structural probe:
  `D2BlockMapper.swift`, `D2BlockExporter.swift`, `D2BlockProbe.swift`.
- New DOT block mapper, exporter, and structural probe:
  `DOTBlockMapper.swift`, `DOTBlockExport.swift`, `DOTBlockProbe.swift`.
- Routing-chain extension in `D2Importer.parse` and
  `GraphvizImporter.parse`: insert block probe after the architecture
  probe and before the flowchart fallback. The marker-forced override
  (`# diagramkit:family=block`) is honored upstream by the existing
  `family` marker mechanism — no probe-internal escape hatch.
- Exporter dispatch extension in `D2Exporter` and `DOTExporter` for the
  `.block(let diagram)` payload case.
- Eleven new shared `Kind` cases on both `D2RecoveryMarker.Kind` (currently
  30, post-Wave-G) and `DOTRecoveryMarker.Kind` (currently 18, post-Wave-G):
  `blockCols`, `blockWidth`, `blockShapeFallback`, `blockArrowDir`,
  `blockSpace`, `blockEdgeAttrs`, `blockClassDef`, `blockClassApply`,
  `blockStyle`, `blockAccTitle`, `blockAccDescr`. The existing `family`
  case is reused for the `family=block` marker.
- Two new same-format round-trip fixtures:
  - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-block/`
  - `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-block/`
- Two new cross-format unordered pairs (four directed fixtures) added to
  the existing `CrossFormatRoundTripTests` parameterized suite:
  - `mermaid↔d2` (block)
  - `mermaid↔dot` (block)
- Six new test suites under `Tests/DiagramKitTests/`:
  `D2/D2BlockMapperTests`, `D2/D2BlockExporterTests`,
  `D2/D2BlockProbeTests`, `Graphviz/DOTBlockMapperTests`,
  `Graphviz/DOTBlockExportTests`, `Graphviz/DOTBlockProbeTests`. Plus
  two same-format suites under `Tests/DiagramKitTests/RoundTrip/`:
  `D2BlockRoundTripTests`, `DOTBlockRoundTripTests`.
- Two new corpus entries in
  `Sources/DiagramKitSample/Resources/test-diagrams.json` (one d2 block,
  one dot block), bringing corpus to 426 entries.

  Note: the **current corpus count is 424** (per `CLAUDE.md` "Target
  Layout" section); Wave J's two new entries land at 426. The
  baseline numbers in this spec assume that current state. The
  CLAUDE.md corpus-count line currently reads `424 entries: 397
  Mermaid + 27 multi-format` and after Wave J should read
  `426 entries: 397 Mermaid + 29 multi-format`.
- [`COVERAGE.md`](../../../COVERAGE.md) updates: import + export
  totals, round-trip discipline counts, partial-support detail Wave J
  subsection, backlog summary closer, removal of `block` from the §2
  D2/DOT candidate table.
- [`BASELINES.md`](../../../BASELINES.md) updates: snapshot counts
  (437 → 439 SVG, 437 → 439 image, 424 → 426 ASCII; 1298 → 1304 total)
  and corpus entry count.
- [`CLAUDE.md`](../../../CLAUDE.md) updates: corpus count
  (`424 entries` → `426 entries`).

### Out of scope

- **D2 ↔ DOT cross-format block pair.** Both formats use the same
  `block-*` marker set, so the `d2 ↔ dot` direction would shuffle
  markers without exercising a distinct conversion path. Wave E set
  this precedent for architecture/mindmap/treeView (no `d2 ↔ dot`
  pair when conversion adds no new logic). Can be added in a follow-up
  if a user need surfaces.
- **D2 `vars` / `style` blocks on block input.** No `BlockDiagram`
  payload landing slot. Surfaces `featureDropped(.slotUnsupported, …)`
  on parse. Same policy as the existing D2 architecture mapper.
- **DOT `splines` / `rank` / layout-engine attrs on block input.**
  Same — no landing slot, `featureDropped(.slotUnsupported, …)`.
  Exception: `rank=same` subgraphs the DOT block exporter itself emits
  to approximate grid rows are not re-surfaced as `slotUnsupported`;
  they are consumed by `DOTBlockMapper` as part of the block-row
  reconstruction.
- **Block `csstext` arbitrary CSS string.** `BlockNode.csstext` round-
  trips via Mermaid syntax but is silently dropped on D2/DOT emission.
  No `block-css` marker is allocated; it falls under the existing
  `.styleDrop` silent policy. Could be added in a follow-up if real
  fixtures require it.
- **`BlockNodeType.applyStyles`/`applyClass`/`classDef` outside the
  classDef + class-apply marker pair.** These three meta-types exist
  on `BlockNodeType` to let the JS-port parser carry directive lines
  through the node tree; they never reach a positioned block on the
  layout side. They are filtered out before emission. No marker
  allocated.
- **New public surface.** None. `BlockDiagram` and its substructures
  already exist in `Sources/DiagramKitModel/src_block_types.swift`.
  New files stay internal to their slices.
- **New `DiagnosticCategory` cases.** All emissions reuse
  `.shapeDowngrade` / `.styleDrop` / `.slotUnsupported` /
  `.idSanitization`.
- **New `RoundTripLoss` cases.** All observed losses map to the
  existing enum (`.shapeDowngrade`, `.idSanitization`, `.styleDrop`).
- **Corpus snapshot baselines beyond the two new corpus entries.** The
  Mermaid block family already has 10 corpus entries with SVG/image/ASCII
  baselines; D2/DOT importer/exporter output isn't snapshotted by the
  corpus pipeline (it's gated by `RoundTripHarness` only).

## File layout

### D2 slice (`Sources/DiagramKitD2/`)

```
D2BlockMapper.swift           # D2 AST → BlockDiagram
D2BlockExporter.swift         # BlockDiagram → D2 source
D2BlockProbe.swift            # structural probe (marker-forced override is upstream)
D2RecoveryMarker.swift        # extend Kind enum with 9 new block cases
```

### DOT slice (`Sources/DiagramKitGraphviz/`)

```
DOTBlockMapper.swift          # DOT AST → BlockDiagram
DOTBlockExport.swift          # BlockDiagram → DOT source
DOTBlockProbe.swift           # structural probe
DOTRecoveryMarker.swift       # extend Kind enum with 9 new block cases
```

### Dispatch insertion points

| Site | Change |
|------|--------|
| `D2Importer.parse` | Insert `D2BlockProbe.detect(...)` call after the architecture probe, before the flowchart fallback. Route to `D2BlockMapper.map(...)`. |
| `D2Exporter.export` | Add `case .block(let diagram):` to the payload switch, dispatch to `D2BlockExporter.export(diagram, options:)`. |
| `GraphvizImporter.parse` | Insert `DOTBlockProbe.detect(...)` in the probe cascade, same position as D2. Route to `DOTBlockMapper.map(...)`. |
| `DOTExporter.export` | Add `case .block(let diagram):` to the payload switch, dispatch to `DOTBlockExport.export(diagram, options:)`. |

No changes to umbrella `DiagramKit`, no changes to `DiagramKitModel`,
no changes to `DiagramKitImport` / `DiagramKitExport` protocol surface.

## Detection

The probe runs after `family` marker dispatch. A marker-forced
`# diagramkit:family=block` always wins via the upstream `family`
override; the probe is only consulted on marker-less input.

### D2 structural probe (`D2BlockProbe`)

Returns `true` when **either** condition holds:

1. A top-level or nested node has a `grid-rows`, `grid-columns`, or
   `grid-gap` attribute. These attributes are block-specific in
   DiagramKit's emission — architecture, mindmap, treeView, c4, and
   sequence mappers never emit them.
2. ≥2 nodes carry shapes from the **block-distinctive set**:

   ```
   { stadium, package, hexagon-with-double-border, lean_right, lean_left,
     trapezoid, inv_trapezoid }
   ```

   These shape kinds do not appear in the architecture probe
   (`{cylinder, cloud, queue, page}`) or in any other family probe.

Negative bias: a marker-less D2 file with only `rectangle` / `oval` /
`circle` / `diamond` shapes is **not** classified as block — it falls
through to flowchart, matching the documented "biased toward false
negatives" policy of Wave E.

### DOT structural probe (`DOTBlockProbe`)

Returns `true` when **either** condition holds:

1. The graph body contains ≥2 `subgraph cluster_*` blocks **and** at
   least one `rank=same` subgraph with ≥2 nodes (the row-grouping
   signature DOT block emission uses).
2. ≥2 nodes carry shapes from the block-distinctive DOT set:

   ```
   { box3d, parallelogram, invhouse, house, trapezium, invtrapezium,
     octagon }
   ```

   These do not appear in the architecture probe
   (`{cylinder, component, note, folder, box3d}` — note `box3d` is in
   both sets and is decided by combination with other distinctive
   shapes) or in any other DOT family probe.

The marker-less ambiguity between `box3d` (block subroutine) and
`box3d` (architecture compute node) is resolved by **majority over the
distinctive-set match**: if more box3d nodes are paired with other
block-distinctive shapes than with arch-distinctive shapes, the probe
returns block.

## Encoding rules

### Shape kind mapping (23 `BlockNodeType` cases)

| BlockNodeType | D2 native shape | DOT native shape | Marker on emission? |
|---|---|---|---|
| `square` | `rectangle` (default) | `box` (default) | none |
| `round` | `oval` | `ellipse` | none |
| `circle` | `circle` | `circle` | none |
| `doublecircle` | `circle` + marker | `doublecircle` | D2 only — `blockShapeFallback=<id>,doublecircle` |
| `diamond` | `diamond` | `diamond` | none |
| `hexagon` | `hexagon` | `hexagon` | none |
| `stadium` | `stadium` | `box` + marker | DOT only — `blockShapeFallback=<id>,stadium` |
| `subroutine` | `package` | `box3d` | both — `blockShapeFallback=<id>,subroutine` (D2 + DOT) |
| `cylinder` | `cylinder` | `cylinder` | none |
| `leanRight` | `parallelogram` + marker | `parallelogram` + marker | both — `blockShapeFallback=<id>,lean_right` |
| `leanLeft` | `parallelogram` + marker | `parallelogram` + marker | both — `blockShapeFallback=<id>,lean_left` |
| `trapezoid` | `rectangle` + marker | `trapezium` + marker | both — `blockShapeFallback=<id>,trapezoid` |
| `invTrapezoid` | `rectangle` + marker | `invtrapezium` + marker | both — `blockShapeFallback=<id>,inv_trapezoid` |
| `rectLeftInvArrow` | `rectangle` + marker | `box` + marker | both — `blockShapeFallback=<id>,rect_left_inv_arrow` |
| `blockArrow` | `rectangle` + 2 markers | `box` + 2 markers | both — `blockShapeFallback=<id>,block_arrow` + `blockArrowDir=<id>,<dirs-csv>` |
| `space` | omitted from emission | omitted from emission | both — `blockSpace=,<columnIndex>` |
| `composite` | container, no shape attr | `subgraph cluster_<id>` | none (structural) |
| `na`, `columnSetting`, `edge`, `classDef`, `applyClass`, `applyStyles` | filtered out before emission | filtered out before emission | none — these are parser-internal scaffolding, never reach the exporter |

The `blockShapeFallback` marker disambiguates a Mermaid `BlockNodeType`
that lost identity to a closest-fit D2 or DOT shape. On import, the
marker takes precedence over the natural shape decode.

### Grid: `columns` + `widthInColumns`

**D2**: when a composite container has `columns ≥ 1`, emit
`grid-columns: N` inside the container body. `widthInColumns > 1` on a
child has no clean native D2 expression — emit `blockWidth=<childId>,<span>`
marker; D2 still lays the child out as a single grid cell, accepting
the visual difference.

**DOT**: no native grid. Emit children in row order grouped by
`rank=same` subgraphs (every `columns` children share a rank), and
include the marker `blockCols=<containerId>,<N>` and (per spanning
child) `blockWidth=<childId>,<span>` for round-trip reconstruction.

A composite with `columns == -1` (the default for the synthetic root)
emits no `grid-columns` and no `blockCols` marker.

### Edges (`BlockEdge`)

**D2**: `src -> dst: "label"` with native arrow expression. Map:

- `thickness == "thick"` → D2 `style: { stroke-width: 3 }`
- `pattern == "dashed"` → D2 `style: { stroke-dash: 3 }`
- `pattern == "dotted"` → D2 `style: { stroke-dash: 1 }`
- `arrowTypeStart` / `arrowTypeEnd` → D2 `source-arrowhead`/`target-arrowhead`

**DOT**: `src -> dst [label="…", style=dashed, arrowhead=…, dir=…]`.
Map:

- `thickness == "thick"` → `penwidth=2`
- `pattern == "dashed"` / `"dotted"` → `style=dashed` / `style=dotted`
- `arrowTypeStart` / `arrowTypeEnd` → `arrowtail` / `arrowhead` plus
  `dir=both`/`dir=back`/`dir=forward`/`dir=none` as needed

Variants outside the natural D2/DOT expression set (e.g. Mermaid's
`arrow_open` vs `arrow_cross` distinction) are preserved by
`blockEdgeAttrs=<edgeIndex>,<thickness>,<pattern>,<arrowStart>,<arrowEnd>`.
The marker is always emitted on round-trip — even when the natural
attributes also encode the value — because the exporter cannot know
whether the importer will see comment-stripping middleware.

### Block arrow (`blockArrow`)

A `BlockNode` with `type == .blockArrow` carries a `directions: [BlockDirection]`
list (1–6 of `up`/`down`/`left`/`right`/`x`/`y`). D2/DOT have no native
equivalent. Emit as a `rectangle` (D2) or `box` (DOT) with the label
unchanged, plus two markers:

```
# diagramkit:block-shape-fallback=arrowId1,block_arrow
# diagramkit:block-arrow-dir=arrowId1,right,up
```

On import, the `blockShapeFallback` marker restores the type; the
`blockArrowDir` marker restores the direction list (comma-separated;
empty when no directions). Both markers must be present for the
restoration to succeed; if only one is present, the importer reports
`featureDropped(.slotUnsupported, …)` and emits a plain block of type
`square`.

### Space

A `BlockNode` with `type == .space` produces no native D2/DOT emission
(no node line, no shape). To preserve its position within the parent
container's column ordering, emit one marker per space cell:

```
# diagramkit:block-space=parent-id,4
```

The first field is the parent container's ID (empty when at root), the
second is the cell index within the container. The importer
reconstructs `space` nodes in column order by inserting synthetic
`BlockNode` entries with auto-generated IDs (`space-<n>`) at the marked
positions.

### Classes / classDef / inline styles

**`classDef`**: one marker per definition.

```
# diagramkit:block-classdef=blue,fill:#6cf;stroke:#333
```

The styles CSV uses semicolons as the inner separator so the outer
comma grammar stays intact. `textStyles` are folded into the same
semicolon-separated list with a `text:` prefix (e.g. `text:color:white`).

**`class` apply**: per applied class, one marker per (node, className)
pair.

```
# diagramkit:block-class-apply=A,blue
```

When `classDef` styles can also be expressed in D2's `style:` block or
DOT's `style="..."` attribute set, the exporter folds them into the
node declaration **in addition** to emitting the markers. This keeps
the rendered output visually correct in tools that strip DiagramKit
comments.

**Inline `styles`**: marker `block-style=<nodeId>,<stylesCsv>` carries
the per-node inline styles list verbatim. Same semicolon-inner
convention.

### Title and accessibility

**D2**: emit `title: "<diagramTitle>"` as the first non-comment
statement when set. PlantUML's accessibility analog is not adopted here;
DiagramKit's `accTitle`/`accDescr` round-trip via existing seq-style
markers, mirrored as:

```
# diagramkit:block-acc-title=Some accessibility title
# diagramkit:block-acc-descr=Long-form accessibility description
```

**DOT**: emit graph-level `label="<diagramTitle>"` when set. Same
`block-acc-title`/`block-acc-descr` marker pair for accessibility.

These two extra markers bring the total Wave J marker-kind additions to
**eleven**. The acc-title/acc-descr pair is needed for round-trip
parity with the existing Mermaid block exporter (`MermaidBlockExport.swift`).

## Recovery-marker kinds (final list)

Eleven new cases added to each of `D2RecoveryMarker.Kind` and
`DOTRecoveryMarker.Kind`. Wire format follows the existing convention
exactly:

```swift
case blockCols(containerID: String, columns: Int)
case blockWidth(nodeID: String, widthInColumns: Int)
case blockShapeFallback(nodeID: String, rawValue: String)
case blockArrowDir(nodeID: String, directionsCsv: String)
case blockSpace(parentID: String, columnIndex: Int)
case blockEdgeAttrs(edgeIndex: Int, thickness: String, pattern: String, arrowStart: String, arrowEnd: String)
case blockClassDef(className: String, stylesCsv: String)
case blockClassApply(nodeID: String, className: String)
case blockStyle(nodeID: String, stylesCsv: String)
case blockAccTitle(text: String)
case blockAccDescr(text: String)
```

Emit format:

```
# diagramkit:block-cols=group,3
# diagramkit:block-width=a,2
# diagramkit:block-shape-fallback=leanLeft1,lean_left
# diagramkit:block-arrow-dir=arrow1,right,up
# diagramkit:block-space=root,4
# diagramkit:block-edge-attrs=0,thick,dashed,arrow_open,arrow
# diagramkit:block-classdef=blue,fill:#6cf;stroke:#333
# diagramkit:block-class-apply=A,blue
# diagramkit:block-style=A,fill:#f00
# diagramkit:block-acc-title=Accessibility title
# diagramkit:block-acc-descr=Long accessibility description
```

Sanitization uses the existing `sanitize(_:)` helper (newline / quote /
CR → space) on every comma-separated arg. Styles CSVs use semicolon as
the inner separator.

**Parse `maxSplits` per kind** (to keep the scanner unambiguous when an
inner field would otherwise eat a comma):

| Marker kind | `maxSplits` | Rationale |
|---|---|---|
| `block-cols` | 1 | 2 fields |
| `block-width` | 1 | 2 fields |
| `block-shape-fallback` | 1 | 2 fields |
| `block-arrow-dir` | 1 | 2 fields; the second field is a comma-joined direction list parsed by the consumer (matches Wave G `c4Color` packed-string convention) |
| `block-space` | 1 | 2 fields |
| `block-edge-attrs` | 4 | 5 fields |
| `block-classdef` | 1 | 2 fields; second is a semicolon-separated styles CSV |
| `block-class-apply` | 1 | 2 fields |
| `block-style` | 1 | 2 fields; same semicolon-CSV convention |
| `block-acc-title` / `block-acc-descr` | n/a (rest-of-line) | text field — no inner structure |

## Diagnostics

Per-emission diagnostic mapping (all reuses; no new
`DiagnosticCategory` cases):

| Situation | Diagnostic on emit | `RoundTripLoss` on cross-format |
|---|---|---|
| `BlockNodeType` without native D2/DOT shape (closest-fit + marker emitted) | `.lossyTransform(.shapeDowngrade, "block shape <kind> downgraded to <native>")` | `.shapeDowngrade` |
| `blockArrow` to D2/DOT (closest-fit + 2 markers) | `.lossyTransform(.shapeDowngrade, "block_arrow has no native D2/DOT shape; emitted as <native>")` | `.shapeDowngrade` (same-format restored via markers) |
| `widthInColumns > 1` to DOT (no native span) | `.lossyTransform(.slotUnsupported, "DOT has no native column span; preserved via block-width marker")` | none (same-format restored; cross-format Mermaid keeps via direct emission) |
| `BlockEdge` thickness/pattern outside the native D2/DOT vocabulary | `.lossyTransform(.styleDrop, "block edge attr <field>=<value> not natively expressible")` | `.styleDrop` |
| `classDef`/inline styles that don't fit native D2 `style:` / DOT `style=` | `.lossyTransform(.styleDrop, "block style attr dropped from native emission; preserved via marker")` | `.styleDrop` |
| ID containing `.`, space, or other D2/DOT-reserved characters | `.lossyTransform(.idSanitization, "block ID '<src>' sanitized to '<dst>' for <format>")` | `.idSanitization` |
| `block-beta` keyword variant on Mermaid import | `.informational(.shapeDowngrade, "block-beta canonicalized to block on import")` | none |

**Pairing rule.** Every emitted `RoundTripLoss` on a cross-format
direction must have a matching `.lossyTransform` or `.featureDropped`
diagnostic on the export step that produced it. Already enforced by
`RoundTripHarness`; the pairing is by typed `DiagnosticCategory`
equality, not by keyword matching.

**Throw boundary.** None. Block is always representable as a digraph-
with-containers in both D2 and DOT, even if lossy. No
`DiagramError.unsupportedOnPlatform` triggered.

## Test plan

### Same-format round-trip fixtures

Two new fixtures, each exercising every new marker kind at least once:

```
Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-block/
  input.d2          # nested grid w/ blockArrow, spans, styles, classes, edges
  expected.d2       # canonical re-emission after parse + export

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-block/
  input.dot         # same coverage as d2-block, DOT idiom
  expected.dot      # canonical re-emission
```

Each fixture must exercise:

- ≥2-level nested composite
- `columns N` setting on at least one container (`N >= 2`)
- One `widthInColumns > 1` span
- One `blockArrow` with ≥2 directions
- One `space` cell
- One `classDef` + ≥1 `class` apply
- One `BlockEdge` with non-default `thickness`, `pattern`, and
  `arrowType*`
- One `BlockNode` with a `BlockNodeType` requiring a `blockShapeFallback`
  marker (e.g. `leanLeft`, `trapezoid`)
- A non-empty `diagramTitle`, `accTitle`, and `accDescr`

This guarantees every new marker kind has at least one round-trip
fixture exercise.

### Cross-format pair fixtures

Two new unordered pairs (four directed fixtures):

```
Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-block/
  source.mermaid → expected.d2
  source.d2      → expected.mermaid

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-block/
  source.mermaid → expected.dot
  source.dot     → expected.mermaid
```

Cross-format fixtures focus on the structural subset that both formats
preserve cleanly; lossy attributes (e.g. `trapezoid` shape on cross-
format to a non-marker-aware consumer) are documented in the fixture's
`allowed-losses.txt` as `.shapeDowngrade` / `.styleDrop` /
`.idSanitization` entries.

### Unit tests

| Suite | Coverage |
|---|---|
| `D2BlockMapperTests` | Importer side — every `Kind` parse path, missing-marker fallback, malformed-marker fallback, container nesting depth ≥3, grid-columns ≥1 round-trip, ID sanitization. |
| `D2BlockExporterTests` | Exporter side — every `BlockNodeType` emission path, every `BlockEdge` variant, every marker kind emission, no-marker-on-trivial-shapes optimization, classDef → native fold + marker pairing. |
| `D2BlockProbeTests` | Positive: grid-columns presence triggers; ≥2 block-distinctive shapes trigger. Negative: pure flowchart-shaped graph rejected; architecture probe still wins on `{cloud, queue}`-heavy input; marker-less ambiguity not classified. |
| `DOTBlockMapperTests` | Same as D2 mapper tests, DOT idiom. Plus `rank=same` row reconstruction. |
| `DOTBlockExportTests` | Same as D2 exporter tests, DOT idiom. Plus `rank=same` row emission, cluster ID sanitization. |
| `DOTBlockProbeTests` | Same as D2 probe tests, DOT idiom. Plus the `box3d` ambiguity tiebreaker (block-distinctive shape majority). |
| `D2BlockRoundTripTests` | Drives `RoundTripHarness` over the same-format fixture. |
| `DOTBlockRoundTripTests` | Same, DOT side. |

### Existing parameterized suites

- `CrossFormatRoundTripTests` automatically picks up the four new
  cross-format fixtures via the existing discovery loop.
- `CorpusSnapshotTests` automatically picks up the two new corpus
  entries on the next baseline-recording run.

### Snapshot baselines

Two new corpus entries → six new snapshots (2 SVG + 2 image + 2 ASCII).
Baseline counts move 1298 → 1304 total.

## Discipline gates

Must stay green at every commit boundary:

- `Scripts/check-diagnostic-discipline.sh` — typed factories only.
- `Scripts/check-file-sizes.sh` — each new file under 500 lines (the
  mapper/exporter pattern lands at 200–350 lines per file in Waves
  E–G; block has slightly more shape variety, so allowance for ~400
  lines per file is reasonable).
- `Scripts/check-sendable-annotations.sh` — no new `@unchecked
  Sendable`.
- `Scripts/strict-concurrency-check.sh` — Swift 6 strict mode passes.
- `Scripts/linux-check.sh` — the new D2/DOT slice files compile on
  Linux (no `canImport(CoreGraphics)` dependencies).
- `Scripts/bootstrap-smoke-check.sh` — the local merge gate; must pass
  end-to-end.

## Commit plan (high-level)

Wave J lands as a single bottom-up sequence with verification gates at
each boundary (the same shape as Wave G, scaled to block's marker
count):

1. Spec + plan commits.
2. `D2RecoveryMarker.swift` + `DOTRecoveryMarker.swift` — 11 new `Kind`
   cases each, with emit + parse helpers.
3. `D2BlockMapper.swift` — D2 → `BlockDiagram` mapping (no exporter yet).
4. `D2BlockExporter.swift` — `BlockDiagram` → D2 source.
5. `D2BlockProbe.swift` + `D2Importer.parse` routing + `D2Exporter.export`
   dispatch.
6. `DOTBlockMapper.swift` + `DOTBlockExport.swift` + `DOTBlockProbe.swift`
   + dispatch wiring.
7. Same-format round-trip fixtures (`d2-block/`, `dot-block/`) + their
   harness tests.
8. Cross-format pair fixtures (`cross-mermaid-d2-block/`,
   `cross-mermaid-dot-block/`).
9. Corpus entries (2) + snapshot baseline regeneration for the two new
   entries.
10. COVERAGE.md / BASELINES.md / CLAUDE.md closer commit.

Each step closes with the relevant test filter passing:
`swift test --filter D2BlockMapperTests`, etc. The full discipline-gate
sweep runs at the closer commit.

## Open questions

None at spec time. The `subroutine → DOT box3d` and "rank=same for DOT
grid rows" decisions were made during brainstorming and are intentional
design choices, not unresolved.
