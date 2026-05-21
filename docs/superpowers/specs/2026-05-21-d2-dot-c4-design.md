# 2026-05-21 — D2 + DOT C4 coverage (Wave G)

## Summary

Add `c4` import + export to the `DiagramKitD2` and `DiagramKitGraphviz`
slices, taking D2 coverage from 8/28 to 9/28 and DOT coverage from
7/28 to 8/28 in each direction. The `c4` family is the candidate
[COVERAGE.md §2](../../../COVERAGE.md#2-d2-and-dot-expansion-mostly-mismatch-narrow-opportunities)
explicitly flags as the next defensible D2/DOT extension ("maps via
flowchart … both formats can express containment graphs but lose the
C4 view-type metadata; would need `.lossyTransform` diagnostics").

C4 already has importers/exporters for Mermaid (native), PlantUML, and
Structurizr. Wave G slots D2 and DOT into the same canonical
`C4Diagram` payload model and grows the c4 cross-format graph from
3 unordered pairs (mermaid↔plantuml, mermaid↔structurizr,
plantuml↔structurizr) to 10 unordered pairs.

The work is bidirectional, lossless on same-format round-trip via
comment-encoded recovery markers, and lossy-with-typed-diagnostics on
cross-format paths. No new `DiagnosticCategory` cases, no new
`RoundTripLoss` cases, no new public surface.

This builds on:

- [`2026-05-19-coverage-expansion-design.md`](2026-05-19-coverage-expansion-design.md)
  (Wave 2 — D2/DOT class/state/er): per-family mapper + exporter
  layering this spec extends.
- [`2026-05-20-coverage-marker-recovery-design.md`](2026-05-20-coverage-marker-recovery-design.md):
  the comment-encoded recovery-marker pattern and the existing
  `D2RecoveryMarker.scanner` / `DOTRecoveryMarker.scanner`
  infrastructure.
- [`2026-05-20-d2-dot-coverage-wave-e-design.md`](2026-05-20-d2-dot-coverage-wave-e-design.md)
  (Wave E): the structural-probe-plus-marker-recovery dispatch
  pattern in `D2Importer.parse` and `GraphvizImporter.parse`.
- [`2026-05-21-d2-sequence-design.md`](2026-05-21-d2-sequence-design.md)
  (Wave F): the same family-probe / exporter-dispatch / marker-recovery
  shape on a single format.

## Matrix delta

| Family | D2 (was → now) | DOT (was → now) |
|--------|:--------------:|:---------------:|
| c4     | — → ✓          | — → ✓           |

Totals after Wave G:

- D2 import: 8/28 → **9/28**
- D2 export: 8/28 → **9/28**
- DOT import: 7/28 → **8/28**
- DOT export: 7/28 → **8/28**

## Scope

### In scope

- New D2 c4 mapper (`D2C4Mapper`), exporter (`D2C4Export`), and
  structural probe (`D2C4Probe`) in `Sources/DiagramKitD2/C4/` and
  `Sources/DiagramKitD2/Exporter/`.
- New DOT c4 mapper (`DOTC4Mapper`), exporter (`DOTC4Export`), and
  structural probe (`DOTC4Probe`) in `Sources/DiagramKitGraphviz/C4/`.
- Routing-chain extension in `D2Importer.parse` and
  `GraphvizImporter.parse`: insert c4 probe after the existing
  architecture/mindmap/treeView marker-forced branches, before the
  flowchart fallback.
- Exporter dispatch extension in `D2Exporter` and `DOTExporter` for
  the `.c4(let diagram)` payload case.
- Eleven new shared `Kind` cases on both `D2RecoveryMarker.Kind`
  (currently 27) and `DOTRecoveryMarker.Kind` (currently 15):
  `c4DiagramKind`, `c4ShapeKind`, `c4External`, `c4Technology`,
  `c4Description`, `c4Sprite`, `c4Tag`, `c4Link`, `c4BoundaryKind`,
  `c4RelKind`, `c4Color`. Both `c4Technology` and `c4Description`
  attach to either shape or relationship declarations — the scanner
  correlates by `latestDeclaration(before:in:)` so no separate
  `c4-rel-tech` / `c4-rel-descr` cases are needed. The existing
  `family` case is reused for the `family=c4` marker (no new case).
- Two new same-format round-trip fixtures:
  - `roundtrip/d2-c4/` — same-format D2.
  - `roundtrip/dot-c4/` — same-format DOT.
- Seven new cross-format unordered pairs (14 directed cases) added to
  the existing `CrossFormatRoundTripTests` parameterized suite:
  - `mermaid↔d2`, `mermaid↔dot`
  - `plantuml↔d2`, `plantuml↔dot`
  - `structurizr↔d2`, `structurizr↔dot`
  - `d2↔dot`
- Four new test suites under `Tests/DiagramKitTests/`:
  `D2/D2C4MapperTests`, `D2/D2C4ExportTests`,
  `Graphviz/DOTC4MapperTests`, `Graphviz/DOTC4ExportTests`. Plus two
  same-format suites under `Tests/DiagramKitTests/RoundTrip/`:
  `D2C4RoundTripTests`, `DOTC4RoundTripTests`.
- Two new corpus entries in
  `Sources/DiagramKitSample/Resources/test-diagrams.json` (one d2 c4,
  one dot c4), bringing corpus to 426 entries.
- [`COVERAGE.md`](../../../COVERAGE.md) updates: import + export
  totals, round-trip discipline counts, partial-support detail
  Wave G closer, backlog summary closer, removal of `c4` from the
  §2 D2/DOT candidate table.
- [`BASELINES.md`](../../../BASELINES.md) updates: snapshot counts
  (437→439 SVG, 437→439 image, 424→426 ASCII; 1298→1304 total) and
  corpus entry count.
- [`CLAUDE.md`](../../../CLAUDE.md) updates: corpus count
  (`424 entries` → `426 entries`).

### Out of scope

- **D2 `vars` / `style` blocks on c4 input.** No `C4Diagram` payload
  landing slot. Surfaces `featureDropped(.slotUnsupported, …)` on
  parse. Same policy as the existing D2 architecture mapper.
- **DOT `splines` / `rank` / layout-engine attrs on c4 input.**
  Same — no landing slot, `featureDropped(.slotUnsupported, …)`.
- **C4 `dynamic` kind ordering semantics across D2/DOT.** The
  diagram kind round-trips via the `c4DiagramKind` marker, but
  D2/DOT lack an ordered-edge model. Cross-format export of a
  `dynamic` c4 to D2/DOT emits a `lossyTransform(.slotUnsupported, …)`
  per dropped sequence index. Closing this would require a
  Wave-F-style sequence treatment of c4 dynamic; explicitly punted.
- **PlantUML sprite catalog rendering on the D2/DOT side.** Sprite
  strings round-trip as opaque strings via the `c4Sprite` marker;
  D2/DOT exporters do not render sprite art (no native facility).
- **C4 `deployment` kind deployment-DSL extended features.** Basic
  deployment nodes round-trip via the same shape/boundary mechanism
  this spec adds; the extended PlantUML deployment dialect features
  (already a separate slice, closed by
  [`2026-05-20-plantuml-deployment-design.md`](2026-05-20-plantuml-deployment-design.md))
  are not bridged into D2/DOT through c4.
- **New public surface.** None. `C4Diagram` and its substructures
  already exist in `Sources/DiagramKitModel/src_c4_types.swift`. New
  files stay internal to their slices.
- **New `DiagnosticCategory` cases.** All emissions reuse
  `.shapeDowngrade` / `.styleDrop` / `.slotUnsupported` /
  `.idSanitization`.
- **New `RoundTripLoss` cases.** All observed losses map to the
  existing enum.
- **`C4Shape` extra slots** (`shadowing`, `shapeOverride`, `techn`,
  `legendText`, `legendSprite`) and `C4Diagram.accDescr` round-trip
  via Mermaid's native syntax but are silently dropped on D2/DOT
  emission. No `c4-*` marker is allocated for these; they fall under
  the existing `.styleDrop` silent policy. Could be added in a
  follow-up wave if a user need surfaces.
- **`parentBoundary == "global"` is the sentinel** for "outside all
  authored boundaries" on both `C4Shape` and `C4Boundary`. The D2/DOT
  exporters treat `"global"` and `""` identically when deciding
  whether a shape is a root-level shape.

## File layout

### D2 slice (`Sources/DiagramKitD2/`)

```
C4/
  D2C4Mapper.swift              # D2 AST → C4Diagram (importer side)
  D2C4Probe.swift               # structural probe + marker-forced override
Exporter/
  D2C4Export.swift              # C4Diagram → D2 source (exporter side)
D2RecoveryMarker.swift          # extend Kind enum with 10 new c4 cases
```

### DOT slice (`Sources/DiagramKitGraphviz/`)

```
C4/
  DOTC4Mapper.swift             # DOT AST → C4Diagram
  DOTC4Probe.swift              # structural probe + marker-forced override
DOTC4Export.swift               # C4Diagram → DOT source
DOTRecoveryMarker.swift         # extend Kind enum with 10 new c4 cases
```

### Dispatch insertion points

| Site | Change |
|------|--------|
| `D2Importer.parse` | Insert `D2C4Probe.detect(...)` call after architecture/mindmap/treeView probes, before flowchart fallback. Route to `D2C4Mapper.map(...)`. |
| `D2Exporter.export` | Add `case .c4(let diagram):` to the payload switch, dispatch to `D2C4Export.export(diagram, options:)`. |
| `GraphvizImporter.parse` | Insert `DOTC4Probe.detect(...)` in the probe cascade, same position as D2. Route to `DOTC4Mapper.map(...)`. |
| `DOTExporter.export` | Add `case .c4(let diagram):` to the payload switch, dispatch to `DOTC4Export.export(diagram, options:)`. |

No changes to umbrella `DiagramKit`, no changes to `DiagramKitModel`,
no changes to `DiagramKitImport` / `DiagramKitExport` protocol surface.

## Encoding rules

### Shape kind mapping (22 `C4ShapeType` → native shapes)

D2 has more native c4-flavored shapes than DOT, so DOT pays more
markers for tier disambiguation.

| C4 type | D2 native | DOT native | Marker(s) |
|---------|-----------|------------|-----------|
| `person`, `external_person` | `shape: person` | `shape: oval` | `c4ShapeKind: person` (DOT); `c4External` for `external_` variant (both) |
| `system`, `external_system` | `shape: rectangle` | `shape: box` | `c4External` for `external_` variant |
| `system_db`, `external_system_db` | `shape: cylinder` | `shape: cylinder` | `c4External` for `external_` variant |
| `system_queue`, `external_system_queue` | `shape: queue` | `shape: box` + marker | `c4ShapeKind: system_queue` (DOT); `c4External` for `external_` |
| `container`, `external_container` | `shape: rectangle` + marker | `shape: box` + marker | `c4ShapeKind: container` (both — distinguishes tier); `c4External` |
| `container_db`, `external_container_db` | `shape: cylinder` + marker | `shape: cylinder` + marker | `c4ShapeKind: container_db`; `c4External` |
| `container_queue`, `external_container_queue` | `shape: queue` + marker | `shape: box` + marker | `c4ShapeKind: container_queue`; `c4External` |
| `component`, `external_component` | `shape: hexagon` | `shape: component` | `c4External` for `external_` |
| `component_db`, `external_component_db` | `shape: cylinder` + marker | `shape: cylinder` + marker | `c4ShapeKind: component_db`; `c4External` |
| `component_queue`, `external_component_queue` | `shape: queue` + marker | `shape: box` + marker | `c4ShapeKind: component_queue`; `c4External` |

The `c4ShapeKind` marker is what disambiguates the **system / container
/ component tier** when natural shapes collide (cylinder is reused by
three tiers; queue by three; box by several on DOT). D2 saves one
marker (queue) that DOT pays.

### Boundary nesting

- **D2**: native block syntax — `boundaryAlias: "Label" { childA; childB }`.
  Nesting is free. `C4Boundary.type` (System/Container/Enterprise/etc.)
  emits a `c4BoundaryKind` marker on the boundary's declaration line.
  `parentBoundary` is implicit from D2 lexical nesting (no marker
  needed).
- **DOT**: `subgraph cluster_<alias> { label = "..."; ... }`. Same
  nesting story. `c4BoundaryKind` marker on the cluster opener.
- `C4BoundaryOrigin.viewScopeSynthesized` boundaries do not
  re-export (existing rule, no change).

### Relationship encoding

C4 has 7 directional flavors: `rel`, `birel`, `rel_u`, `rel_d`,
`rel_l`, `rel_r`, `rel_b`. D2/DOT have only `->` / `<->` / `--`.

Encoding rule (mirrors Wave F's `seq-arrow-type` strategy):

- Always emit `->` for non-bidirectional flavors, `<->` for `birel`.
- `c4RelKind: <flavor>` marker on the edge line carries the exact
  flavor.
- Label emits as the native edge label.
- `technology`, `description` emit as `c4Technology` / `c4Description`
  markers on the edge line. The scanner correlates them to the
  preceding edge declaration via `latestDeclaration(before:in:)`.
- `sprite`, `tags`, `link`, colors emit as their respective markers
  on the edge line.

### Diagram kind

`C4DiagramKind` (`context` / `container` / `component` / `dynamic` /
`deployment`) is the kind of the diagram itself and has no
representation in D2/DOT syntax. Emitted as a top-of-file marker:

```
# diagramkit:family=c4
# diagramkit:c4-diagram-kind=C4Container
```

The payload uses `C4DiagramKind.rawValue` directly (`"C4Context"`,
`"C4Container"`, `"C4Component"`, `"C4Dynamic"`, `"C4Deployment"`).

The probe uses the `family=c4` marker as the marker-forced override;
the `c4DiagramKind` marker carries the kind through round-trip. If
absent on import (hand-written D2/DOT c4 source), the mapper defaults
to `.context` and emits `informational(.shapeDowngrade, …)`:
"C4 diagram kind defaulted to .context (no `c4-diagram-kind` marker)".

## Recovery marker design

### New marker case names (11, shared by both formats)

| Case | Payload | Attached to | Notes |
|------|---------|-------------|-------|
| `c4DiagramKind` | `String` (raw `C4DiagramKind`) | top-of-file | Required for kind round-trip. |
| `c4ShapeKind` | `String` (raw `C4ShapeType`) | shape declaration | Disambiguates tier-vs-kind collisions. |
| `c4External` | (presence-only) | shape declaration | Marks `external_*` variant. |
| `c4Technology` | `String` | shape or edge declaration | Tech slot on Container/Component shapes + relationships. |
| `c4Description` | `String` | shape, boundary, or edge declaration | Description slot. |
| `c4Sprite` | `String` | shape declaration | Sprite name (PlantUML iconography). |
| `c4Tag` | `String` (single payload — `tags` is `String?` on shape/boundary/relationship) | shape, boundary, or edge declaration | One marker per declaration carrying the full `tags` string. |
| `c4Link` | `String` (URL) | shape, boundary, or edge declaration | Link slot. |
| `c4BoundaryKind` | `String` (raw boundary type) | boundary declaration | Boundary type. |
| `c4RelKind` | `String` (raw `C4RelationshipKind`) | edge declaration | Distinguishes `rel_u`/`rel_d`/etc. from plain `rel`. |
| `c4Color` | `String` (packed `bg=…;font=…;border=…` or `text=…;line=…`) | shape, boundary, or edge declaration | All shape/boundary/relationship colors packed into one marker per declaration to keep marker count down. |

All 11 rows above are new case names in each format's `Kind` enum.
The implicit `# diagramkit:family=c4` marker reuses the existing
`family` case shared by Waves E/F (no new case).

### Scanner reuse

Both formats already host a `RecoveryMarkerScanner<Kind>` with comment
prefix `#`. The new case names plug into the existing scanner with
matching `emit*` / `parseKind` branches. `latestDeclaration(before:in:)`
remains the positional-correlation primitive.

## Diagnostics

All reuse existing `DiagnosticCategory` cases. No new categories.

| Situation | Diagnostic | Tier |
|-----------|------------|------|
| Import: c4 source missing `c4-diagram-kind` marker | `lossyTransform(.shapeDowngrade, …)` | parse |
| Import: shape with no `c4-shape-kind` marker but ambiguous native shape (e.g., DOT `cylinder` could be system_db / container_db / component_db) | `lossyTransform(.shapeDowngrade, …)` defaulting to system tier | parse |
| Cross-format export of a shape kind with no native (e.g., `system_queue` on DOT) | `lossyTransform(.shapeDowngrade, …)` paired with the marker that recovers it | export |
| Cross-format export of `dynamic` kind drops ordering | `lossyTransform(.slotUnsupported, …)` per dropped sequence index | export |
| D2 `vars` / `style` / DOT `splines` / `rank` on c4 input | `featureDropped(.slotUnsupported, …)` | parse |
| Cross-format export drops `sprite` / `tags` / `colors` to a format that has no slot | `lossyTransform(.styleDrop, …)` | export |

### Silent drops (per [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md))

- D2 layout hints (`direction`, `near`) on c4 input: silent.
- DOT layout-engine-specific attrs not in the above list: silent.
- C4 `config` font choices on cross-format export: silent (font
  config is per-format).

## Cross-format bridges

Each bridge is mediated by the canonical `C4Diagram` payload — no
format-specific shortcut paths. The mapper / exporter on each side
only ever talks to the typed payload.

**Shared subset** that all five formats round-trip losslessly:

- All 22 `C4ShapeType` values
- All 5 `C4DiagramKind` values
- All 7 `C4RelationshipKind` values
- Element fields: `alias`, `label`, `technology`, `description`,
  `link`
- Boundary fields: `alias`, `label`, `type`, `description`, nesting
- Relationship fields: `from`, `to`, `label`, `technology`,
  `description`

**Lossy on cross-format export to D2/DOT only** (paired with
`lossyTransform` diagnostics + recovery markers on same-format
re-export):

- `sprite` (PlantUML icon names) — no D2/DOT visual equivalent
- `tags` set
- `colors` (bgColor/fontColor/borderColor for shapes;
  textColor/lineColor for relationships)
- `wrap` width hints

Same-format D2 c4 → D2 c4 and DOT c4 → DOT c4 are **lossless** via
markers.

### Cross-format fixtures (7 unordered = 14 directed)

```
roundtrip/cross/
  mermaid-d2-c4-context.{mmd,d2}
  mermaid-dot-c4-context.{mmd,dot}
  plantuml-d2-c4-context.{puml,d2}
  plantuml-dot-c4-context.{puml,dot}
  structurizr-d2-c4-context.{dsl,d2}
  structurizr-dot-c4-context.{dsl,dot}
  d2-dot-c4-context.{d2,dot}
```

Each fixture pair uses the **same shared-subset content** — no sprite
/ tag / color metadata that would be lossy across the bridge. Each
file pair is exercised in both directions by the parameterized
`CrossFormatRoundTripTests` suite.

## Test plan

### Round-trip suites

- `Tests/DiagramKitTests/RoundTrip/D2C4RoundTripTests.swift` — wraps
  the `d2-c4` fixture for D2 → D2 round-trip via
  `RoundTripHarness`.
- `Tests/DiagramKitTests/RoundTrip/DOTC4RoundTripTests.swift` — same
  for DOT.
- Fixture additions to the parameterized
  `CrossFormatRoundTripTests`: 7 new unordered pairs (14 directed
  cases).

### Importer / parser unit tests

- `Tests/DiagramKitTests/D2/D2C4MapperTests.swift`:
  - one case per `C4ShapeType` (22)
  - one case per `C4DiagramKind` (5)
  - one case per `C4RelationshipKind` (7)
  - nested boundaries (≥2 deep)
  - marker recovery: `c4Technology` on container, `c4Sprite` on
    person, `c4Tag` repeated, `c4Link` on boundary, packed
    `c4Color`
  - default fallbacks: missing `c4-diagram-kind` marker
    (informational), ambiguous cylinder defaulting to `system_db`
    (informational)
  - rejection: malformed marker payload surfaces
    `featureDropped(.slotUnsupported, …)`
- `Tests/DiagramKitTests/Graphviz/DOTC4MapperTests.swift` — same
  shape, DOT-idiomatic source.

### Exporter unit tests

- `Tests/DiagramKitTests/D2/D2C4ExportTests.swift`:
  - golden-string per `C4ShapeType` (22)
  - golden-string per `C4RelationshipKind` (7)
  - boundary nesting golden
  - marker emission discipline: one marker per declaration line
    where possible; packed `c4Color`; no duplicate markers; markers
    appear before next declaration
- `Tests/DiagramKitTests/Graphviz/DOTC4ExportTests.swift` — same
  shape.

### Probe tests

- Probe behaviour is exercised through the mapper tests (probe runs
  inside `D2Importer.parse` / `GraphvizImporter.parse`); dedicated
  probe suites are out of scope unless a failure during
  implementation makes them load-bearing.

### Corpus + snapshots

- 2 new entries in
  `Sources/DiagramKitSample/Resources/test-diagrams.json` (one d2 c4
  context, one dot c4 context).
- 6 new snapshot baselines (2 SVG + 2 image + 2 ASCII) recorded via
  the chunked `Scripts/rebaseline-snapshots.sh --target svg` and
  `--target image --chunk 10`. Corpus count goes 424 → 426; snapshot
  count goes 1298 → 1304.

### Linux

`c4` parse / layout / render is already Linux-portable (one of the 28
Linux-supported families). The new D2/DOT importers/exporters use no
CoreText. `Tests/DiagramKitLinuxTests/` requires no additions —
the zero-unsupported-families lockdown already covers c4.

### Discipline gates run before commit

- `Scripts/check-file-sizes.sh` — new files stay under 500 lines
  (warning) / 1000 (error). `D2C4Mapper` and `DOTC4Mapper` may brush
  the 500-line warning given 22 shape types × bidirectional mapping;
  budget for splitting into `D2C4Mapper+Shapes.swift` /
  `D2C4Mapper+Relationships.swift` extensions if the warning fires.
- `Scripts/check-diagnostic-discipline.sh` — every emission uses
  typed factories.
- `Scripts/check-sendable-annotations.sh`,
  `Scripts/strict-concurrency-check.sh`,
  `Scripts/linux-check.sh` (Docker; record skipped if unavailable).

### Acceptance criteria

1. `swift build` and `swift build --build-tests` clean.
2. `swift test --filter D2C4MapperTests` /
   `DOTC4MapperTests` / `D2C4ExportTests` / `DOTC4ExportTests`
   all green.
3. `swift test --filter "RoundTrip"` green with the 16 new cases
   (2 same-format + 14 cross-format directed).
4. `swift test --filter CorpusSnapshotTests` green after baselines
   recorded for the 2 new entries (chunked execution per
   [CLAUDE.md](../../../CLAUDE.md)).
5. `Scripts/bootstrap-smoke-check.sh` green (linux-check skipped if
   Docker unavailable, recorded as such).
6. [`COVERAGE.md`](../../../COVERAGE.md),
   [`BASELINES.md`](../../../BASELINES.md), and
   [`CLAUDE.md`](../../../CLAUDE.md) updates committed in the same
   line of work.

## Doc updates

- **COVERAGE.md** — flip the four matrix cells (c4 × D2/DOT, import +
  export), bump D2 to 9/28 and DOT to 8/28 in both Totals rows, add a
  Wave G bullet under "Partial-support detail" mirroring the Wave F
  bullet's structure, append a new closed item to the "Backlog
  summary" list, update round-trip fixture counts (38 → 40
  same-format; 62 → 76 cross-format directed; 31 → 38 unordered),
  remove the `c4` row from the §2 D2/DOT candidate table.
- **BASELINES.md** — snapshot counts (437 → 439 SVG, 437 → 439 image,
  424 → 426 ASCII; 1298 → 1304 total) and corpus entry count
  (424 → 426).
- **CLAUDE.md** — corpus count (`424 entries` → `426 entries`).
- No changes to ARCHITECTURE.md, README.md, AGENTS.md,
  ATTRIBUTION.md, or docs/diagnostic-severity-discipline.md — Wave G
  introduces no new public surface and no new diagnostic categories.
