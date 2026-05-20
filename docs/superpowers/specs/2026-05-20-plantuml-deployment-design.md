# 2026-05-20 — PlantUML deployment dialect → `architecture` payload

## Summary

Lift PlantUML deployment diagrams (`node`, `artifact`, `database`, `cloud`,
`frame`, `folder`, `package`, `card`, `queue`, `stack`, `storage`, `agent`,
`actor`, `boundary`) into DiagramKit's existing `architecture` payload as a
new PlantUML dialect peer to the Wave-3 component dialect. The work is
bidirectional (import and export), lossless on PlantUML same-format
round-trip via comment-encoded recovery markers, and lossy-with-typed-
diagnostics on cross-format paths.

This is the next step after [`2026-05-19-coverage-expansion-design.md`](2026-05-19-coverage-expansion-design.md)
(Wave 3 closed PlantUML component) and the 2026-05-20 marker/residuals
specs. No matrix cell moves; PlantUML × architecture is already `✓`. The
work widens what counts as a successful import for that intersection.

## Scope

### In scope

- `@startuml` bodies that `PlantUMLFamilyProbe` routes as deployment via
  a new `isPlantUMLDeploymentBody(_:)` probe.
- Deployment shape vocabulary: 14 keywords extending
  `ArchitectureServiceKind`.
- N-level nested groups (`cloud { node { artifact } }`) via
  `ArchitectureGroup.parentGroupId` chains.
- Edges: `-->`, `<--`, `<-->`, `..>` (dependency), with optional
  `: label` and `<<stereotype>>`.
- Decorations preserved via recovery markers: stereotypes (`<<router>>`),
  `#color` tags, `note left|right|above|below of X … end note`,
  `legend … endlegend`.
- Bidirectional: importer (`PlantUMLDeploymentParser` +
  `PlantUMLDeploymentMapper`) and exporter
  (`PlantUMLDeploymentExporter`), routed through the existing
  `PlantUMLImporter`/`PlantUMLExporter` cascades.

### Out of scope

- `salt` / wireframe / mockup DSL — no DiagramKit target payload, already
  documented OOS in COVERAGE.md.
- PlantUML layout hints (`together { … }`, `skinparam nodesep`,
  `left to right direction`). Parsed and dropped with
  `.featureDropped(.slotUnsupported, …)`.
- Corpus expansion. No new entries in
  `Sources/DiagramKitSample/Resources/test-diagrams.json`; no new
  SVG/image/ASCII snapshot baselines.
- New cross-format fixture pair. Reuses Wave 3's `mermaid↔plantuml
  architecture` pair plus the new `.deploymentShapeFlattened`
  `RoundTripLoss` case (paired to `.shapeDowngrade`
  `DiagnosticCategory`) to cover the lossy projection.

## Matrix impact

Zero new cells. PlantUML × architecture is already `✓` in both import and
export from Wave 3. Deployment widens what `✓` means for that cell.
COVERAGE.md gets a single-paragraph update under "Partial-support
detail" noting deployment-dialect coverage. No backlog item to close —
this is roadmap-style expansion.

## Public payload surface

### One change

`ArchitectureServiceKind` (in
`Sources/DiagramKitModel/src_architecture_types.swift`) gains 14 new
cases:

```swift
public enum ArchitectureServiceKind: String, Sendable, Equatable, CaseIterable {
    case service       // existing — default
    case component     // existing — PlantUML `[Bracketed]`
    case interface     // existing — PlantUML `interface () X`
    case node          // new
    case artifact      // new
    case database      // new
    case cloud         // new
    case frame         // new
    case folder        // new
    case package       // new
    case card          // new
    case queue         // new
    case stack         // new
    case storage       // new
    case agent         // new
    case actor         // new (deployment-flavored; distinct from sequence actor)
    case boundary      // new
}
```

### Blast radius

- **Source-breaking** for any exhaustive `switch` over
  `ArchitectureServiceKind` in third-party code. Release notes call this
  out.
- In-tree exhaustive switches must each add an arm or a `default:`. The
  implementation plan enumerates the sites; expected locations include
  every architecture exporter (D2 / DOT / Mermaid / Structurizr /
  PlantUML), the CG renderer's architecture path, and the SVG
  renderer's architecture path.
- `ArchitectureService.init(kind: = .service)` default preserves source
  compatibility for callers that don't pass `kind:`.

### Non-PlantUML architecture exporters — shape-flattening rule

D2 / DOT / Mermaid / Structurizr architecture exporters render any kind
outside `.service` / `.component` / `.interface` as `service` (lossy)
and emit
`.lossyTransform(.shapeDowngrade, "kind=<raw> downgraded to service for <format>")`
once per affected entity (reusing the existing `.shapeDowngrade`
`DiagnosticCategory` case, no new category needed). PlantUML deployment
is the only exporter that preserves the full vocabulary.

## Importer architecture

### File layout

```
Sources/DiagramKitPlantUML/Deployment/
  PlantUMLDeploymentAST.swift
  PlantUMLDeploymentParser.swift
  PlantUMLDeploymentMapper.swift
```

### Probe — `isPlantUMLDeploymentBody(_:)`

Added to `Sources/DiagramKitPlantUML/PlantUMLFamilyProbe.swift`:

```swift
public func isPlantUMLDeploymentBody(_ body: String) -> Bool {
    let deploymentKeywords: Set<String> = [
        "node", "artifact", "database", "cloud", "frame", "folder",
        "package", "card", "queue", "stack", "storage", "agent",
        "boundary"
        // NOTE: `actor` is intentionally excluded — overlaps with
        //       sequence/use-case. `interface`/`component` already
        //       route to Component dialect.
    ]
    for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let firstToken = trimmed.split(separator: " ", maxSplits: 1).first else { continue }
        if deploymentKeywords.contains(String(firstToken)),
           trimmed.contains("\"") || trimmed.hasSuffix("{") {
            return true
        }
    }
    return false
}
```

### Cascade slot

In `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`: between
`isPlantUMLComponentBody` and `isPlantUMLClassBody`. Reasoning: a body
mixing `[Bracketed]` and `node "X"` is a hybrid PlantUML accepts;
Component already claims `[Bracketed]` and existing tests depend on
that, so we keep Component priority and let deployment-only bodies fall
through to the new probe. Bodies whose only `actor` is followed by
deployment shapes still match because the probe walks every line.

### AST shape

```swift
struct PlantUMLDeploymentAST {
    var title: String?
    var roots: [Node]
    var edges: [Edge]
    var notes: [NoteAttachment]
    var legend: String?
}

indirect enum Node {
    case shape(Shape)
    case group(Group)
}

struct Shape {
    var id: String
    var label: String?
    var kind: ArchitectureServiceKind
    var stereotype: String?
    var color: String?
}

struct Group {
    var id: String
    var label: String?
    var kind: ArchitectureServiceKind
    var stereotype: String?
    var color: String?
    var children: [Node]
}

struct Edge {
    var lhsId: String
    var rhsId: String
    var direction: EdgeDirection      // forward / backward / both
    var style: EdgeStyle              // solid / dashed
    var label: String?
    var stereotype: String?
}
```

### Parser

Line-oriented with a simple block stack for `{ … }` nesting.

- Shape lines: `<keyword> "<label>" [as <id>] [<<stereotype>>] [#color] [{]`
- Edge lines: `<lhs> <arrow> <rhs> [: <label>] [<<stereotype>>]`
- Notes: `note left|right|above|below of <id>` … `end note` blocks
  attached to the named shape
- `legend` … `endlegend` block captured as a single string

Structural errors surface through `PlantUMLDiagnostics` (existing).

### Mapper

Walks AST roots depth-first, emitting `ArchitectureGroup`s and
`ArchitectureService`s with the right `parentGroupId` chain.

- `Group.kind` becomes the group's visual kind via a
  `deployment-group-kind` recovery marker (`ArchitectureGroup` has no
  `kind` field, and a recovery marker keeps the public payload from
  growing further).
- `Shape.stereotype` / `.color` → recovery marker per service.
- `Edge` → `ArchitectureEdge` with synthesized
  `lhsDirection: .R, rhsDirection: .L` (PlantUML edges don't carry
  direction tokens).
- `Edge.style == dashed` → recovery marker on the edge by index.
- `notes` / `legend` → recovery markers attached to the document.

### Import-side diagnostics

All categories below already exist on `DiagnosticCategory` (see
`Sources/DiagramKitCommon/DiagnosticCategory.swift`); no new categories
are required by this spec.

- `together { … }`, `skinparam`, other unsupported constructs →
  `.featureDropped(.slotUnsupported, "PlantUML layout hint '<token>' has no architecture-payload slot")`;
  parsing continues.
- Unknown shape keywords (PlantUML plugins / unrecognized tokens) →
  `.featureDropped(.slotUnsupported, …)`; line is skipped.
- Recovery markers referencing entityIds not present in the parsed body
  → `.lossyTransform(.recoveryMarkerMalformed, "orphan marker references missing id <id>")`;
  marker is dropped.

## Exporter architecture

### New file

`Sources/DiagramKitPlantUML/Exporter/PlantUMLDeploymentExporter.swift`.

### Dispatch

`PlantUMLExporter` cascades by payload type. The architecture-payload
branch today routes to `PlantUMLComponentExporter`. We add a
discriminator: if any service or group has a kind in the deployment
vocabulary (anything beyond `.service`/`.component`/`.interface`), OR
if the document carries a deployment-flavored recovery marker, route to
`PlantUMLDeploymentExporter`. Otherwise keep Wave 3 routing to
`PlantUMLComponentExporter`.

### Output shape

```
@startuml
title <document title>          ' if present
<recovery markers as comments>  ' DK-MARKER lines

cloud "Public Cloud" as cloud_1 {
  node "Worker" as node_2 {
    artifact "worker.jar" as artifact_3
  }
}
database "Postgres" as database_4
node_2 --> database_4 : reads

legend
<verbatim legend body>
endlegend
@enduml
```

### Emission order (deterministic, snapshot-stable)

1. `@startuml`
2. `title` line if `ArchitectureDiagram.diagramTitle` is set
3. Recovery-marker comments (sorted by category, then by stable ID)
4. Top-level groups and services in original document order
   (foreign-source documents: sorted by stable ID)
5. Nested children indented 2 spaces per level
6. Edges in original order (foreign sources: sorted by `(lhsId, rhsId)`)
7. `note left of …` / `note right of …` blocks for any service with a
   notes recovery marker
8. `legend` block if present
9. `@enduml`

### Shape keyword mapping

```swift
extension ArchitectureServiceKind {
    var plantUMLDeploymentKeyword: String {
        switch self {
        case .service:   return "node"
        case .component: return "component"  // unreachable: dispatched to Component exporter
        case .interface: return "interface"  // unreachable: dispatched to Component exporter
        case .node:      return "node"
        case .artifact:  return "artifact"
        case .database:  return "database"
        case .cloud:     return "cloud"
        case .frame:     return "frame"
        case .folder:    return "folder"
        case .package:   return "package"
        case .card:      return "card"
        case .queue:     return "queue"
        case .stack:     return "stack"
        case .storage:   return "storage"
        case .agent:     return "agent"
        case .actor:     return "actor"
        case .boundary:  return "boundary"
        }
    }
}
```

### Edge emission

- Direction tokens (`lhsDirection`/`rhsDirection`) are ignored on
  export — PlantUML deployment uses `-->`/`<--`/`<-->`/`..>` only. Style
  comes from the edge's recovery marker if present; otherwise `-->`.
- `service_a --> service_b : <label>` when `edge.label != nil`.
- Stereotype emitted via recovery marker round-trip, not in the arrow
  syntax itself.

### Identifier handling

- Always emit `as <id>` so labels can change without breaking edge
  references.
- Labels emit verbatim from `ArchitectureService.title`; when `title`
  is `nil`, omit the quoted string and rely on `as <id>`.

### Export-side diagnostics

All categories below already exist on `DiagnosticCategory`; no new
categories are required by this spec.

- Service with `.component` / `.interface` somehow reaching the
  deployment exporter →
  `.featureDropped(.slotUnsupported, "non-deployment kind <raw> in deployment exporter")`;
  falls back to `node`. (Defensive; dispatcher should prevent.)
- Marker encoding failure (embedded `' diagramkit:` tokens after
  sanitization) →
  `.lossyTransform(.recoveryMarkerMalformed, …)`.

## Recovery-marker schema

`Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift` extends the
existing `Kind` enum with 9 cases. No new file.

### New `Kind` cases

```swift
case deploymentServiceStereotype(serviceId: String, stereotype: String)
case deploymentServiceColor(serviceId: String, color: String)
case deploymentGroupKind(groupId: String, kindRawValue: String)
case deploymentGroupStereotype(groupId: String, stereotype: String)
case deploymentGroupColor(groupId: String, color: String)
case deploymentEdgeStyle(edgeIndex: Int, style: String)          // "dashed" | "dotted"
case deploymentEdgeStereotype(edgeIndex: Int, stereotype: String)
case deploymentNote(serviceId: String, position: String, base64Body: String)
case deploymentLegend(base64Body: String)
```

### Wire format

```
' diagramkit:deployment-service-stereotype=worker_1,router
' diagramkit:deployment-service-color=db_3,#FF6600
' diagramkit:deployment-group-kind=cloud_2,cloud
' diagramkit:deployment-edge-style=4,dashed
' diagramkit:deployment-note=worker_1,right,b64:VGhpcyBub2RlIGhhbmRsZXMgYWxsIGluY29taW5nIHRyYWZmaWMu
' diagramkit:deployment-legend=b64:UmVxdWlyZXMgVlBOIGFjY2Vzcw==
```

### Encoding rules

- Identifiers/stereotypes: `sanitize(...)` (existing) — strips `\n`,
  `\r`, `"`, `,`.
- Colors: emitted verbatim including the leading `#`.
- Free text (notes, legend): base64-encoded, matching the existing
  `sequence-participant-properties` / `…-links` pattern.
- Edges are referenced by **index** in `ArchitectureDiagram.edges`
  because edges don't carry IDs. The exporter never reorders edges, so
  index is stable.

### Group kind storage

`ArchitectureGroup` has no `kind` field. Rather than add one (would
bloat the public payload and most consumers don't care), we encode the
group's deployment kind via the `deployment-group-kind` marker. On
import, the deployment mapper reads the marker and remembers the kind
for export-time round-trip; renderers that don't care ignore it.

### Decoding on import

Pre-lexer scan via `RecoveryMarkerScanner` collects every marker before
the parser runs. Mapper consults the marker map keyed by
`(category, entityId)` when building services/groups/edges/notes.
Orphan markers emit `.lossyTransform(.recoveryMarkerMalformed, …)` and
are dropped.

### Loss-typing for the round-trip harness

`RoundTripLoss` gains three cases:

- `.deploymentShapeFlattened` — cross-format export only
- `.deploymentDecorationDropped` — cross-format export only
- `.deploymentLegendDropped` — cross-format export only

Each pairs to a typed `DiagnosticCategory` per
[`docs/diagnostic-severity-discipline.md`](../../diagnostic-severity-discipline.md).
No keyword matching.

## Testing strategy

Filter convention: every test invocation uses an exact `--filter` of the
suite name, never a substring. Full `swift test` runs are out.

### New unit suites

```
Tests/DiagramKitTests/PlantUML/Deployment/
  PlantUMLDeploymentProbeTests.swift
  PlantUMLDeploymentParserTests.swift
  PlantUMLDeploymentMapperTests.swift
  PlantUMLDeploymentExporterTests.swift
  PlantUMLDeploymentRecoveryMarkerTests.swift
```

Swift Testing (`@Suite` + `@Test`), matching the slice's existing
style.

### Probe-cascade regression test

`PlantUMLProbeCascadeTests` (new or extended): one body per dialect
(C4, activity, state, ER, useCase, object, component, **deployment**,
class, sequence), each asserting it routes to its expected mapper.
Catches the failure mode where a future probe change makes
deployment-only bodies route to Component or Class.

### Round-trip fixture (gates the matrix cell)

```
Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/
  plantuml-deployment-comprehensive.json
```

Single same-format fixture, driven by `RoundTripHarness` in
`Sources/DiagramKitTestSupport`. Lossless expectation. Exercises:

- All 14 deployment shape kinds, each at least once
- 3 levels of nesting (cloud > node > artifact)
- Two edges: one solid labeled (`-->: serves`), one dashed dependency
  (`..>: depends`)
- One stereotype, one color tag, one note, one legend block
- One service whose label is omitted (`as id` only)

No cross-format pair fixture — Wave 3's `mermaid↔plantuml architecture`
pair plus the new `.deploymentShapeFlattened` `RoundTripLoss` case
covers the lossy projection.

### Existing-fixture impact

- Wave 3's `mermaid↔plantuml architecture` fixture must still pass —
  the dispatcher discriminator (component vs deployment) defaults to
  Component for bodies with no deployment markers.
- `PlantUMLComponentExporter` and `PlantUMLComponentMapper` each gain
  one new test asserting they still claim bodies that lack deployment
  vocabulary.

### Discipline-gate sweep

- `Scripts/check-diagnostic-discipline.sh` — every new diagnostic uses
  typed `.lossyTransform` / `.featureDropped` / `.informational`
  factories. This spec deliberately reuses existing
  `DiagnosticCategory` cases (`.shapeDowngrade`, `.slotUnsupported`,
  `.recoveryMarkerMalformed`); the script must remain green without
  adding new categories.
- `Scripts/check-file-sizes.sh` — Parser/Mapper/Exporter stay under the
  500-line warning. If any approaches it, split (e.g.
  `PlantUMLDeploymentParser+Shapes.swift`, `…+Edges.swift`).
- `Scripts/check-sendable-annotations.sh` — no new `@unchecked
  Sendable`s expected.
- `Scripts/strict-concurrency-check.sh` — clean under Swift 6 strict.
- `Scripts/linux-check.sh` — Deployment slice is parse-side only; no
  CoreText / CG. Must build green on Linux, or recorded as skipped if
  Docker/Podman isn't running.

### Failure-mode catalog (turns into TDD test names)

- Body with `node` keyword but no quoted label → parser error,
  `.unsupportedDiagram` diagnostic.
- Body mixing `[Component]` and `node "X"` → routes to Component
  (existing precedence); deployment-only shapes get
  `.featureDropped`.
- N-level deep nesting (5+) → no stack overflow, output indentation
  correct.
- Stereotype/color/note attached to non-existent service →
  `.lossyTransform(.recoveryMarkerMalformed, …)`; dropped.
- Empty `legend … endlegend` → emits the block on export, decoded as
  empty string.

## File layout summary

### Added (10)

```
Sources/DiagramKitPlantUML/Deployment/PlantUMLDeploymentAST.swift
Sources/DiagramKitPlantUML/Deployment/PlantUMLDeploymentParser.swift
Sources/DiagramKitPlantUML/Deployment/PlantUMLDeploymentMapper.swift
Sources/DiagramKitPlantUML/Exporter/PlantUMLDeploymentExporter.swift

Tests/DiagramKitTests/PlantUML/Deployment/PlantUMLDeploymentProbeTests.swift
Tests/DiagramKitTests/PlantUML/Deployment/PlantUMLDeploymentParserTests.swift
Tests/DiagramKitTests/PlantUML/Deployment/PlantUMLDeploymentMapperTests.swift
Tests/DiagramKitTests/PlantUML/Deployment/PlantUMLDeploymentExporterTests.swift
Tests/DiagramKitTests/PlantUML/Deployment/PlantUMLDeploymentRecoveryMarkerTests.swift

Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/plantuml-deployment-comprehensive.json
```

### Modified (8)

```
Sources/DiagramKitModel/src_architecture_types.swift
    — extend ArchitectureServiceKind with 14 new cases

Sources/DiagramKitPlantUML/PlantUMLFamilyProbe.swift
    — add isPlantUMLDeploymentBody(_:)

Sources/DiagramKitPlantUML/PlantUMLImporter.swift
    — slot deployment between Component and Class in the cascade

Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift
    — extend Kind enum with 9 deployment cases + emit/parse helpers

Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift
    — dispatch architecture payload to Deployment or Component based on
      kind vocabulary or recovery-marker presence

Sources/DiagramKitTestSupport/RoundTripLoss.swift
    — add deploymentShapeFlattened / deploymentDecorationDropped /
      deploymentLegendDropped cases. Pair each to the existing
      DiagnosticCategory (.shapeDowngrade for shape flattening,
      .slotUnsupported for decoration drops). No new DiagnosticCategory
      cases needed.

Sources/DiagramKitD2/D2Exporter.swift              (architecture path)
Sources/DiagramKitGraphviz/DOTExporter.swift       (architecture path)
Sources/DiagramKitMermaid/Exporter/...             (Mermaid architecture exporter)
Sources/DiagramKitStructurizr/StructurizrExporter.swift  (architecture path, if it
                                                          exposes one)
    — emit .lossyTransform(.shapeDowngrade, …) for any kind beyond
      .service/.component/.interface, and add a defensive default arm
      to any exhaustive switch on ArchitectureServiceKind. The
      implementation plan begins by grepping for every exhaustive
      switch on ArchitectureServiceKind to enumerate the exact files
      and call sites that need an arm.

COVERAGE.md
    — note PlantUML deployment dialect under "Partial-support detail"
      (no matrix cell change; documents what got widened)
```

## Concurrency and Linux contracts

- Deployment parser / mapper / exporter are pure functions over value
  types; no `@unchecked Sendable` needed.
- No worker-thread invariants disturbed (parse path stays on the
  engine's existing dispatch).
- All new files live in `DiagramKitPlantUML` and `DiagramKitModel`,
  both Linux-portable. No `BMColor`/`BMFont`/`BMImage`/CoreText usage.

## Public-surface diff summary

- `ArchitectureServiceKind` gains 14 cases. Source-breaking for
  exhaustive switches in third-party code. Release notes call this
  out.
- No other public types, structs, or functions added. Everything else
  is internal to `DiagramKitPlantUML` or test-only.

## Open questions

None at design close. Implementation-plan stage may surface more.

## References

- [COVERAGE.md](../../../COVERAGE.md) — coverage matrix and partial-support detail
- [CLAUDE.md](../../../CLAUDE.md) — repo conventions, layer rules, discipline gates
- [docs/diagnostic-severity-discipline.md](../../diagnostic-severity-discipline.md) —
  typed-factory decision tree for diagnostics
- [Sources/DiagramKitCommon/RecoveryMarker/](../../../Sources/DiagramKitCommon/RecoveryMarker/) —
  shared marker scanner / declaration index used by D2 / DOT / PlantUML / Structurizr
- [Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift](../../../Sources/DiagramKitPlantUML/PlantUMLRecoveryMarker.swift) —
  existing PlantUML marker emitter; extended here
- [docs/superpowers/specs/2026-05-19-coverage-expansion-design.md](2026-05-19-coverage-expansion-design.md) —
  Wave 1/2/3 spec; Wave 3 added the Component dialect this spec mirrors
- [docs/superpowers/specs/2026-05-20-coverage-marker-recovery-design.md](2026-05-20-coverage-marker-recovery-design.md) —
  comment-encoded recovery-marker pattern this spec extends
- [docs/superpowers/specs/2026-05-20-import-coverage-residuals-design.md](2026-05-20-import-coverage-residuals-design.md) —
  Wave D residuals; `ArchitectureServiceKind` was introduced there
