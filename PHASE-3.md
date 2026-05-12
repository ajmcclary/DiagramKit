# Phase 3: D2 Importer Vertical Slice — ✅ COMPLETE

**Completed**: 2026-05-12
**Tests**: 97/97 targeted tests pass (D2Parser, D2Importer, D2 fixtures, probe collision, multi-format corpus, registry, Mermaid importer)
**Verification gates**: File sizes, `@unchecked Sendable`, strict concurrency, package dump, and build-tests pass
**Mermaid regressions**: None (ImporterRegistryTests and MermaidImporterTests pass)

Goal: prove the importer architecture with the highest-ROI non-Mermaid format.

## Overview

The d2 importer is the first non-Mermaid format. It proves the `DiagramSourceImporter` protocol, `ImporterRegistry` prepending, and multi-format corpus infrastructure. The parser maps basic d2 syntax (nodes, edges, labels, containers, direction, simple shape hints) to `DiagramPayload.flowchart(ParsedGraphModel)`, reusing the existing flowchart layout and render pipelines.

---

## Architecture (Implemented)

```
Sources/DiagramKitD2/
├── D2Importer.swift           ✅ DiagramSourceImporter conformance
├── D2Parser.swift             ✅ Recursive-descent parser (d2 source → D2Document + diagnostics)
├── D2AST.swift                ✅ Minimal d2 AST types
├── D2Mapper.swift             ✅ D2AST → ParsedGraphModel mapping
├── D2Probe.swift              ✅ Narrow probe function
└── D2Shapes.swift             ✅ Shape name mapping (d2 → NodeShape)
```

---

## Key Design Decisions (All Honored)

### 1. Skip full d2 AST/IR/compiler port ✅

The upstream d2 compiler (AST → IR → layout → render) is a ~40-package Go codebase with ELK-based layout. DiagramKit already has its own layout engine (ELK) and SVG/CG renderers. The importer only parses d2 source and maps it to `DiagramPayload.flowchart`.

### 2. Parser approach: line-oriented recursive descent ✅

d2's grammar is line-oriented (`key: value`, `A -> B`, `{ }` blocks). A recursive-descent parser consuming tokenized lines is sufficient for the first slice.

### 3. Map to `ParsedGraphModel` directly ✅

The target is `DiagramPayload.flowchart(ParsedGraphModel)` — the same struct Mermaid's flowchart parser produces. Reuses layout, SVG, CG, and ASCII renderers unchanged.

### 4. Narrow probe with format-specific guards ✅

Rejects Mermaid/DOT/PlantUML/Structurizr. Three d2-positive signatures: edge arrows, dot-chained keys, and block+colon syntax.

### 5. Diagnostics for unsupported features ✅

Unsupported constructs emit `DiagramDiagnostic.severity = .unsupported` with source line numbers.

### 6. D2 corpus fixtures remain inline; no new snapshot baselines ✅

Inline fixtures carry `"skipSnapshots": ["d2"]` and live in `D2CorpusFixtureTests.swift` so `CorpusMultiFormatTests.swift` stays below the file-size gate. No `test-diagrams.json` edits, no `CorpusSnapshotTests` changes, no new baselines.

---

## Implementation Deviations from Original Plan

### Naming: `D2EdgeStyle` → `D2EdgeKind`

The plan used `D2EdgeStyle` for the edge kind enum. Implementation uses `D2EdgeKind` to avoid confusion with `original_src_types.EdgeStyle` (which represents line rendering style — solid/dotted/etc.).

### Parser: `=` separator support added

The plan assumed only `:` as key-value separator. d2 uses both `:` (`A: Start`) and `=` (`vars.d = 1`, `style.fill = "red"`). Implementation supports `=` as a fallback delimiter, preventing parse crashes on `vars.*` and `style.*` lines — they now correctly emit `.unsupported` diagnostics instead of throwing `DiagramError`.

### Parser: bare `direction: right` as top-level directive

The plan's parse rules showed `direction: right` → "populate current container's direction" but the dot-notation handler (`A.direction: right`) didn't cover bare `direction` without a dot. Implementation treats `direction` (no dot) as a dedicated AST statement (`D2Statement.direction`) instead of a synthetic node. The mapper applies it to `MermaidGraph.direction` without adding a visible `direction` node.

### Mapper: node table is order-preserving and merge-aware

The initial vertical slice appended every node/property statement directly to `nodesInOrder`, so `A: Database` plus `A.shape: cylinder` produced duplicate `A` nodes and edge-only diagrams did not materialize `A`/`B` nodes at all. The mapper now maintains an ordered node table, merges property statements into existing nodes, synthesizes missing edge endpoints, and records synthesized endpoints in the containing subgraph.

### AST types: `public` everywhere

All types are `public` in the library target (the plan omitted explicit access modifiers in examples).

---

## File Change Summary (Actual)

| File | Action | Status |
|---|---|---|
| `Package.swift` | Add `DiagramKitD2` target, product, deps | ✅ |
| `Sources/DiagramKitD2/D2AST.swift` | New — d2 AST types | ✅ |
| `Sources/DiagramKitD2/D2Parser.swift` | New — recursive-descent parser | ✅ |
| `Sources/DiagramKitD2/D2Mapper.swift` | New — D2AST → `ParsedGraphModel` mapper | ✅ |
| `Sources/DiagramKitD2/D2Probe.swift` | New — narrow probe | ✅ |
| `Sources/DiagramKitD2/D2Shapes.swift` | New — shape mapping table | ✅ |
| `Sources/DiagramKitD2/D2Importer.swift` | New — DiagramSourceImporter conformance | ✅ |
| `Sources/DiagramKit/MermaidPipeline.swift` | Edit — add `D2Importer()` + `import DiagramKitD2` | ✅ |
| `Tests/DiagramKitTests/D2ParserTests.swift` | New — 20 parser unit tests | ✅ |
| `Tests/DiagramKitTests/D2ImporterTests.swift` | New — 22 importer unit tests | ✅ |
| `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift` | Edit — 8 d2 probe collision tests + `import DiagramKitD2` | ✅ |
| `Tests/DiagramKitTests/D2CorpusFixtureTests.swift` | New — 6 inline d2 fixture tests | ✅ |
| `Tests/DiagramKitTests/CorpusMultiFormatTests.swift` | Restored to schema/playground coverage only after fixture split | ✅ |
| `Tests/DiagramKitTests/ImporterRegistryTests.swift` | Edit — D2-first registry assertion + `import DiagramKitD2` | ✅ |

### Files intentionally NOT changed

- Any rendering code (SVG, CG, ASCII)
- Layout engine (ELK)
- `DiagramKitModel` types (no new payload cases)
- `DiagramKitImport` protocol/registry (already designed for this)
- `DiagramKitTestSupport` (CorpusEntry already supports multi-format)
- `CorpusSnapshotTests.swift` (no d2 snapshot rendering in Phase 3)
- `test-diagrams.json` (no new real entries until Phase 10)
- Snapshot baselines (no new baselines until Phase 10)

---

## Verification Gate Results

```
swift package dump-package                  ✅ package graph loads
swift build --build-tests                   ✅ library + tests compile
Scripts/check-file-sizes.sh                 ✅ Passes with pre-existing warnings; all touched files under 500 lines
Scripts/check-sendable-annotations.sh  ✅ All @unchecked Sendable documented/allowlisted
Scripts/strict-concurrency-check.sh    ✅ DiagramKit first-party targets clean
git diff --check                            ✅ no whitespace errors

swift test --filter D2ParserTests              ✅ 20/20
swift test --filter D2ImporterTests            ✅ 22/22
swift test --filter D2FixtureTests             ✅ 6/6
swift test --filter ProbeCollisionMatrixTests  ✅ 16/16 (8 D2 + 8 pre-existing)
swift test --filter MultiFormatDecodingTests   ✅ 5/5
swift test --filter MultiFormatFixtureMetadataTests ✅ 6/6
swift test --filter PlaygroundCorpusDecodingTests   ✅ 1/1 (when CoreGraphics is available)
swift test --filter MultiFormatBackwardCompatibilityTests ✅ 4/4
swift test --filter MultiFormatValidationTests ✅ 3/3
swift test --filter MultiFormatSparseMatrixTests ✅ 3/3
swift test --filter ImporterRegistryTests      ✅ 7/7 (updated for D2-first)
swift test --filter MermaidImporterTests       ✅ 4/4 (no regressions)

Not run by request: snapshots and Linux/Docker check.
```

---

## Deferred to Later Phases

- Full d2 styling parity (colors, fonts, stroke widths, opacity, shadows, etc.)
- D2 layout engine parity (near placement, grid, fixed positions)
- Non-flowchart mappings (sequence, class, ER, c4, architecture)
- Exporting d2 from DiagramDocument
- `icon`, `tooltip`, `link`, `near`, `constraint`, `grid-*`, `classes`, `style`
- `vars`, `layers`, `scenarios`, `steps`, `imports`
- Glob patterns and filter selectors
- SQL table and class shapes
- Markdown block strings (fall back to plain text)
- Edge indices and multi-edge deduplication
- Image shapes
- Real `test-diagrams.json` multi-format entries
- D2 snapshot baselines (SVG, image, ASCII)

---

## Original Plan (Preserved for Reference)

<details>
<summary>Click to expand original PHASE-3.md plan</summary>

### Work Stream 1: `DiagramKitD2` Target

```swift
.target(
    name: "DiagramKitD2",
    dependencies: ["DiagramKitModel", "DiagramKitImport"],
    swiftSettings: strictConcurrencySettings
),
```

Add to `DiagramKit` umbrella target dependencies (unconditional):

```swift
.target(name: "DiagramKitD2"),
```

Add product:

```swift
.library(name: "DiagramKitD2", targets: ["DiagramKitD2"]),
```

### Work Stream 2: D2 AST Types (`D2AST.swift`)

All types are value types (`Sendable`).

```swift
struct D2Document: Sendable { var statements: [D2Statement] }
enum D2Statement: Sendable {
    case nodeDefinition(D2NodeDefinition)
    case edgeDefinition(D2EdgeDefinition)
    case containerOpen(D2ContainerOpen)
    case containerClose
}
struct D2NodeDefinition: Sendable {
    var id: String; var label: String?; var shape: String?
    var direction: String?; var tooltip: String?; var link: String?
    var icon: String?; var width: Double?; var height: Double?
}
struct D2EdgeDefinition: Sendable {
    var source: String; var target: String; var label: String?
    var sourceArrow: Bool; var targetArrow: Bool; var edgeKind: D2EdgeKind
}
enum D2EdgeKind: Sendable { case directional; case bidirectional; case undirected }
struct D2ContainerOpen: Sendable { var id: String; var label: String? }
```

### Work Stream 3: d2 Parser (`D2Parser.swift`)

Parse rules:

| Input pattern | AST output |
|---|---|
| `id: value` | `D2NodeDefinition` |
| `id: value {` | `D2NodeDefinition` + `D2ContainerOpen` |
| `id {` | `D2ContainerOpen` (value nil) |
| `A -> B` | `D2EdgeDefinition` (directional) |
| `A -> B: label` | `D2EdgeDefinition` with label |
| `A <-> B` | `D2EdgeDefinition` (bidirectional) |
| `A -- B` | `D2EdgeDefinition` (undirected) |
| `}` | `D2ContainerClose` |
| `# ...` | skip (comment) |
| `shape: <name>` | populate current node's shape |
| `direction: right|down|up|left` | populate current container's direction |
| `style.*`, `vars.*`, etc. | emit `.unsupported` diagnostic |

### Work Stream 4: d2 → ParsedGraphModel Mapper (`D2Mapper.swift`)

Core mapping:

| d2 construct | ParsedGraphModel field |
|---|---|
| `name: label` | `nodesInOrder: [(id: name, node: MermaidNode(...))]` |
| `name { ... }` | `subgraphs: [MermaidSubgraph(...)]` |
| `A -> B` | `edges: [MermaidEdge(source: "A", target: "B", arrowHeadEnd: .arrow)]` |
| `A <-> B` | `edges: [MermaidEdge(source: "A", target: "B", arrowHeadStart: .arrow, arrowHeadEnd: .arrow)]` |
| `A -- B` | `edges: [MermaidEdge(source: "A", target: "B", arrowHeadEnd: .none)]` |
| `direction: right` | `direction: .LR` |

### Work Stream 5: Shape Mapping (`D2Shapes.swift`)

9 shapes supported; 8 deferred with diagnostics.

### Work Stream 6: D2 Probe (`D2Probe.swift`)

Three positive signatures, negative guards for Mermaid/DOT/PlantUML/Structurizr.

### Work Stream 7: D2 Importer (`D2Importer.swift`)

`DiagramSourceImporter` conformance wiring parser + mapper.

### Work Stream 8: Registry Integration

```swift
public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
    importers: [D2Importer(), MermaidImporter()]
)
```

### Work Stream 9: Diagnostics for Unsupported Constructs

17 diagnostic categories covering all known unsupported d2 constructs.

### Work Stream 10: Tests

- 20 parser unit tests
- 22 importer unit tests
- 8 probe collision tests
- 6 inline d2 fixture tests
- Updated ImporterRegistryTests
</details>
