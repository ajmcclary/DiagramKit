# Phase 3: D2 Importer Vertical Slice — Full Plan

Goal: prove the importer architecture with the highest-ROI non-Mermaid format.

## Overview

The d2 importer is the first non-Mermaid format. It proves the `DiagramSourceImporter` protocol, `ImporterRegistry` prepending, and multi-format corpus infrastructure. The parser maps basic d2 syntax (nodes, edges, labels, containers, direction, simple shape hints) to `DiagramPayload.flowchart(ParsedGraphModel)`, reusing the existing flowchart layout and render pipelines.

---

## Architecture

```
Sources/DiagramKitD2/
├── D2Importer.swift           // DiagramSourceImporter conformance
├── D2Parser.swift             // Recursive-descent parser (d2 source → D2Document + diagnostics)
├── D2AST.swift                // Minimal d2 AST types
├── D2Mapper.swift             // D2AST → ParsedGraphModel mapping
├── D2Probe.swift              // Narrow probe function
└── D2Shapes.swift             // Shape name mapping (d2 → NodeShape)
```

---

## Key Design Decisions

### 1. Skip full d2 AST/IR/compiler port

The upstream d2 compiler (AST → IR → layout → render) is a ~40-package Go codebase with ELK-based layout. DiagramKit already has its own layout engine (ELK) and SVG/CG renderers. The importer only needs to parse d2 source and map it to `DiagramPayload.flowchart`.

### 2. Parser approach: line-oriented recursive descent

d2's grammar is line-oriented (`key: value`, `A -> B`, `{ }` blocks). A recursive-descent parser consuming tokenized lines is sufficient for the first slice. This avoids porting the full d2 scanner/parser machinery (which deals with UTF-16 positions, error recovery, and autoformat).

### 3. Map to `ParsedGraphModel` directly

The target is `DiagramPayload.flowchart(ParsedGraphModel)` — where `ParsedGraphModel` is `original_src_types.MermaidGraph`, the same struct Mermaid's flowchart parser produces. This reuses the layout pipeline (`GraphLayout` → ELK), SVG renderer (`SVGRenderRegistry`), CG renderer, and ASCII renderer unchanged.

### 4. Narrow probe with format-specific guards

The probe returns `true` only when the source contains d2-specific syntax patterns AND explicitly is NOT Mermaid, DOT, PlantUML, or Structurizr. This prevents false matches on other format sources that coincidentally contain `->`.

### 5. Diagnostics for unsupported features

Style blocks, `layers`/`scenarios`/`steps` boards, glob patterns, classes, SQL tables, Markdown block strings, variables, substitutions, and imports all emit `DiagramDiagnostic.severity = .unsupported` with source location hints.

### 6. D2 corpus fixtures remain inline; no new snapshot baselines

Real `test-diagrams.json` entries and D2 snapshot baselines are deferred until the final baseline pass (Phase 10). Phase 3 proves that d2 sources parse correctly and render through existing SVG/image paths via inline fixtures and targeted render assertions. Inline fixtures carry `"skipSnapshots": ["d2"]` to avoid snapshot machinery trying to create D2 baselines prematurely.

---

## Work Stream 1: `DiagramKitD2` Target

### 1.1 `Package.swift` changes

```swift
.target(
    name: "DiagramKitD2",
    dependencies: ["DiagramKitModel", "DiagramKitImport"],
    swiftSettings: strictConcurrencySettings
),
```

Add to `DiagramKit` umbrella target dependencies (unconditional — D2 is a pure parser/import target with no Apple-specific types):

```swift
.target(name: "DiagramKitD2"),
```

Add product:

```swift
.library(name: "DiagramKitD2", targets: ["DiagramKitD2"]),
```

---

## Work Stream 2: D2 AST Types (`D2AST.swift`)

Minimal AST for the d2 subset needed for flowchart mapping. All types are value types (`Sendable`).

```swift
import Foundation

/// Top-level: a d2 document is a list of statements.
struct D2Document: Sendable {
    var statements: [D2Statement]
}

enum D2Statement: Sendable {
    case nodeDefinition(D2NodeDefinition)      // `name: value` or `name { ... }`
    case edgeDefinition(D2EdgeDefinition)      // `A -> B` or `A -> B: label`
    case containerOpen(D2ContainerOpen)        // `name {`
    case containerClose                        // `}`
}

struct D2NodeDefinition: Sendable {
    var id: String                    // key name
    var label: String?                // value (if scalar string)
    var shape: String?                // from `shape: <name>`
    var direction: String?            // from `direction: right`
    var tooltip: String?              // from `tooltip: ...`
    var link: String?                 // from `link: ...`
    var icon: String?                 // from `icon: ...`
    var width: Double?                // from `width: N`
    var height: Double?               // from `height: N`
}

struct D2EdgeDefinition: Sendable {
    var source: String
    var target: String
    var label: String?                // value after the edge
    var sourceArrow: Bool             // `<` prefix on source
    var targetArrow: Bool             // `>` suffix on target
    var style: D2EdgeStyle
}

enum D2EdgeStyle: Sendable {
    case directional                  // `->`
    case bidirectional                // `<->`
    case undirected                   // `--`
}

struct D2ContainerOpen: Sendable {
    var id: String
    var label: String?                // value after colon on same line as `{`
}
```

---

## Work Stream 3: d2 Parser (`D2Parser.swift`)

Line-oriented recursive-descent parser. Consumes raw source text, returns `(D2Document, [DiagramDiagnostic])` — diagnostics are collected for unsupported constructs.

### Parse strategy

1. Split source into lines
2. Strip comments (`# ...` and `"""..."""` block comments) during preprocessing
3. Track indentation for implicit block scoping (d2 uses indentation + `{ }` for explicit blocks)
4. Tokenize each line: key, value, edges, block markers
5. Build AST from tokenized lines
6. Emit `.unsupported` diagnostics for constructs the parser recognizes but cannot translate

### Key parse rules

| Input pattern | AST output |
|---|---|
| `id: value` | `D2NodeDefinition` |
| `id: value {` | `D2NodeDefinition` + `D2ContainerOpen` |
| `id {` | `D2ContainerOpen` (value nil) |
| `A -> B` | `D2EdgeDefinition` (directional) |
| `A -> B: label` | `D2EdgeDefinition` with label |
| `A -> B {` | `D2EdgeDefinition` + `D2ContainerOpen` |
| `A <-> B` | `D2EdgeDefinition` (bidirectional) |
| `A -- B` | `D2EdgeDefinition` (undirected) |
| `}` | `D2ContainerClose` |
| `# ...` | skip (comment) |
| `shape: <name>` | populate current node's shape |
| `direction: right\|down\|up\|left` | populate current container's direction |
| `tooltip: ...` | populate current node's tooltip |
| `link: ...` | populate current node's link |
| `icon: ...` | populate current node's icon |
| `width: N` | populate current node's width |
| `height: N` | populate current node's height |
| `style.*`, `vars.*`, `layers.*`, `scenarios.*`, `steps.*`, `classes.*`, `constraint.*`, `grid-*` | NOT stashed in AST; emit `.unsupported` diagnostic, skip value |

### Error handling

- **Fatal**: unterminated `{` block, unparseable line — throws `DiagramError`
- **Non-fatal (diagnostic)**: unsupported constructs, reserved keywords that do not map to flowchart semantics — collected in `[DiagramDiagnostic]` returned alongside the document

### API

```swift
struct D2Parser {
    func parse(_ source: String) throws -> (document: D2Document, diagnostics: [DiagramDiagnostic])
}
```

### Preprocessing

- Strip `#` line comments and `""" block comments`
- Decode XML entities if present (same as Mermaid's `_HTMLEntities.decode`)
- No frontmatter parsing (d2 has no frontmatter concept)

---

## Work Stream 4: d2 → ParsedGraphModel Mapper (`D2Mapper.swift`)

Converts `D2Document` → `ParsedGraphModel` (i.e., `original_src_types.MermaidGraph`) plus additional diagnostics from the mapping pass.

### Core mapping

| d2 construct | ParsedGraphModel field |
|---|---|
| `name: label` | `nodesInOrder: [(id: name, node: MermaidNode(id: name, label: label, shape: ...))]` |
| `name { ... }` | `subgraphs: [MermaidSubgraph(id: name, label: name, nodeIds: [...], children: [...])]` |
| `A -> B` | `edges: [MermaidEdge(source: "A", target: "B", style: .solid, arrowHeadStart: .none, arrowHeadEnd: .arrow)]` |
| `A <-> B` | `edges: [MermaidEdge(source: "A", target: "B", style: .solid, arrowHeadStart: .arrow, arrowHeadEnd: .arrow)]` |
| `A -- B` | `edges: [MermaidEdge(source: "A", target: "B", style: .solid, arrowHeadStart: .none, arrowHeadEnd: .none)]` |
| `-- B` (anonymous src) | `edges: [MermaidEdge(source: "__anonymous_0", target: "B", ...)]` |
| `name -> B: "hello"` | `edges: [MermaidEdge(source: "name", target: "B", label: "hello", ...)]` |
| `direction: right` | `direction: .LR` |
| `direction: down` | `direction: .TD` |
| `direction: up` | `direction: .BT` |
| `direction: left` | `direction: .RL` |

Note: `MermaidNode`, `MermaidEdge`, `MermaidSubgraph`, `NodeShape`, `Direction`, `ArrowHeadType`, `EdgeStyle`, `NodeProperties`, and `ParsedGraphModel` are all members of `original_src_types`. Mapper code imports `DiagramKitModel` and qualifies names as needed.

### Container/subgraph handling

- `{ }` blocks create `MermaidSubgraph` entries
- Nested blocks create nested `MermaidSubgraph.children` arrays
- Nodes declared inside a container are assigned to that subgraph's `nodeIds`
- Container `label` is the subgraph's title

### Edge deduplication and multi-edges

- d2 edges have implicit indices when multiple edges exist between the same nodes
- For the vertical slice, edges are appended in order; edge indices map naturally to Mermaid's edge array ordering

### API

```swift
struct D2Mapper {
    func map(_ document: D2Document) -> (graph: ParsedGraphModel, diagnostics: [DiagramDiagnostic])
}
```

---

## Work Stream 5: Shape Mapping (`D2Shapes.swift`)

```swift
import DiagramKitModel

/// Maps d2 shape names to DiagramKit NodeShape values.
/// Returns nil for unsupported shapes (caller emits diagnostic).
func mapD2Shape(_ shape: String) -> original_src_types.NodeShape? {
    switch shape.lowercased() {
    case "rectangle": return .rectangle
    case "cylinder", "cyl": return .cylinder
    case "diamond": return .diamond
    case "circle": return .circle
    case "hexagon": return .hexagon
    case "cloud": return .cloud
    case "oval": return .ellipse
    case "document": return .document
    case "text": return .text
    // Deferred shapes (emit diagnostic):
    case "sql_table", "class", "image", "icon", "person",
         "code", "sequence_diagram", "callout", "page":
        return nil
    default:
        return .rectangle  // fallback: default shape
    }
}
```

| d2 shape | NodeShape | Status |
|---|---|---|
| `rectangle` | `.rectangle` | ✅ supported |
| `cylinder` / `cyl` | `.cylinder` | ✅ supported |
| `diamond` | `.diamond` | ✅ supported |
| `circle` | `.circle` | ✅ supported |
| `hexagon` | `.hexagon` | ✅ supported |
| `cloud` | `.cloud` | ✅ supported |
| `oval` | `.ellipse` | ✅ supported |
| `document` | `.document` | ✅ supported |
| `text` | `.text` | ✅ supported |
| `sql_table` | — | Deferred (diagnostic) |
| `class` | — | Deferred (diagnostic) |
| `image` | — | Deferred (diagnostic) |
| `icon` | — | Deferred (diagnostic) |
| `person` | — | Deferred (diagnostic) |
| `code` | — | Deferred (diagnostic) |
| `sequence_diagram` | — | Deferred (diagnostic) |
| `callout` | — | Deferred (diagnostic) |
| `page` | — | Deferred (diagnostic) |

---

## Work Stream 6: D2 Probe (`D2Probe.swift`)

```swift
/// Returns true when `source` appears to be d2 rather than any other known format.
/// This is a narrow probe — it must NOT false-match on Mermaid, DOT, PlantUML,
/// or Structurizr source.
func isD2Source(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // Explicit Mermaid headers → not d2
    let mermaidHeaders = [
        "graph", "flowchart", "sequenceDiagram", "classDiagram", "erDiagram",
        "stateDiagram", "gantt", "pie", "mindmap", "timeline", "requirementDiagram",
        "gitGraph", "sankey-beta", "block-beta", "packet-beta", "kanban",
        "architecture-beta", "radar-beta", "treemap-beta", "venn-beta",
        "ishikawa-beta", "treeView-beta", "eventModeling-beta", "wardley-beta",
        "c4Context", "zenuml"
    ]
    for header in mermaidHeaders {
        if firstLine.hasPrefix(header) { return false }
    }

    // DOT headers → not d2
    if firstLine.hasPrefix("digraph") || firstLine.hasPrefix("graph ") || firstLine.hasPrefix("strict ") {
        return false
    }

    // PlantUML headers → not d2
    if trimmed.contains("@startuml") || trimmed.contains("@start") {
        return false
    }

    // Structurizr headers → not d2
    if trimmed.hasPrefix("workspace {") || trimmed.hasPrefix("workspace{") {
        return false
    }

    // d2 probe signatures (any one is sufficient):

    // 1. Edge arrow syntax (most distinctive — now safe after excluding
    //    Mermaid with `->>`, DOT with `->` in `digraph`, and PlantUML with `->`)
    if trimmed.contains("->") || trimmed.contains("<->") { return true }

    // 2. Dot-chained keys with colon assignment (distinctive d2 pattern:
    //    e.g. `a.b.c: value` — common in d2, rare in other formats)
    for line in trimmed.split(separator: "\n") {
        let stripped = line.trimmingCharacters(in: .whitespaces)
        if stripped.hasPrefix("#") || stripped.hasPrefix("//") { continue }
        if stripped.contains(":") && stripped.contains(".") {
            let parts = stripped.split(separator: ":")
            if let key = parts.first, key.contains(".") {
                return true
            }
        }
    }

    // 3. Block syntax with colon assignment
    let hasColonAssign = trimmed.contains(": ")
    let hasBlockSyntax: Bool = {
        for line in trimmed.split(separator: "\n") {
            let stripped = line.trimmingCharacters(in: .whitespaces)
            if stripped == "{" || stripped.hasSuffix(" {") { return true }
        }
        return false
    }()

    if hasBlockSyntax && hasColonAssign { return true }

    return false
}
```

### Probe collision guarantees

| Source | D2 probe result | Reason |
|---|---|---|
| `graph TD\nA-->B` | `false` | `firstLine.hasPrefix("graph")` |
| `flowchart LR\nA-->B` | `false` | `firstLine.hasPrefix("flowchart")` |
| `sequenceDiagram\nAlice->>Bob: Hello` | `false` | `firstLine.hasPrefix("sequenceDiagram")` |
| `digraph G {\n  a -> b\n}` | `false` | `firstLine.hasPrefix("digraph")` |
| `strict digraph G {\n  a -> b\n}` | `false` | `firstLine.hasPrefix("strict ")` |
| `@startuml\nAlice -> Bob: Hello\n@enduml` | `false` | `trimmed.contains("@startuml")` |
| `workspace {\n  model {\n    user = person\n  }\n}` | `false` | `trimmed.hasPrefix("workspace {")` |
| `A -> B\nB -> C` | `true` | No other-format header + contains `->` |
| `a.b.c: value` | `true` | Dot chain detected |
| `x: label\ny: label` | `false` | Ambiguous — falls through to Mermaid fallback (intentional) |
| `Group {\n  A -> B\n}` | `true` | Block syntax + colon assignment |

---

## Work Stream 7: D2 Importer (`D2Importer.swift`)

```swift
import DiagramKitModel
import DiagramKitImport

public struct D2Importer: DiagramSourceImporter {
    public let name = "D2"
    public let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    public init() {}

    public func supports(source: String) -> Bool {
        isD2Source(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let parser = D2Parser()
        let (d2Doc, parseDiagnostics) = try parser.parse(source)

        let mapper = D2Mapper()
        let (graph, mapDiagnostics) = mapper.map(d2Doc)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.flowchart(graph)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }
}
```

Note: `DiagramDocument` has `public init(payload: DiagramPayload)` — this initializer extracts `type` from the payload enum case automatically. No separate `type` parameter is needed.

---

## Work Stream 8: Registry Integration

`DiagramPipeline.defaultRegistry` currently lives in `Sources/DiagramKit/MermaidPipeline.swift`:

```swift
public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
    importers: [MermaidImporter()]
)
```

After D2 integration:

```swift
public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
    importers: [D2Importer(), MermaidImporter()]
)
```

This requires `DiagramKit` to depend on `DiagramKitD2` (unconditional — see Work Stream 1). The existing `ImporterRegistryTests` assertion `registry.importers.count == 1` must be updated to `>= 2` with `importers[0].name == "D2"` and `importers.last?.name == "Mermaid"`.

---

## Work Stream 9: Diagnostics for Unsupported Constructs

Every d2 construct that does not map to flowchart semantics emits a `.unsupported` diagnostic.

| d2 construct | Diagnostic message |
|---|---|
| `style.*` | `"style blocks not yet supported for d2 import"` |
| `vars.*` | `"variable blocks not yet supported"` |
| `layers.*` / `scenarios.*` / `steps.*` | `"board layers not yet supported; map to subgraphs instead"` |
| `classes.*` | `"class definitions not yet supported"` |
| `shape: sql_table` | `"sql_table shape not yet supported"` |
| `shape: class` | `"class shape not yet supported"` |
| `shape: sequence_diagram` | `"sequence_diagram shape not yet supported"` |
| `shape: image` (without URL) | `"image shape requires a link or icon"` |
| `shape: code` | `"code shape not yet supported"` |
| `icon: ...` | `"icon not yet supported"` |
| `constraint.*` | `"layout constraints not yet supported"` |
| `grid-rows` / `grid-columns` | `"grid layout not yet supported"` |
| `near` | `"near placement not yet supported"` |
| `...$variable` / `${var}` | `"variable substitution not yet supported"` |
| `...@import` | `"imports not yet supported"` |
| `*` / glob patterns | `"glob patterns not yet supported"` |
| `&` filter selectors | `"filter selectors not yet supported"` |
| `tooltip: ...` | `"tooltips not yet supported"` |
| `link: ...` | `"links not yet supported"` |
| `width: N` / `height: N` | Supported: stored in `NodeProperties` |

---

## Work Stream 10: Tests

### 10.1 D2 Parser Unit Tests (`Tests/DiagramKitTests/D2ParserTests.swift`)

```swift
import Testing
@testable import DiagramKitD2
import DiagramKitModel

@Suite struct D2ParserTests {
    @Test("Parse single node with label")
    @Test("Parse two nodes with labels")
    @Test("Parse directional edge A -> B")
    @Test("Parse bidirectional edge A <-> B")
    @Test("Parse undirected edge A -- B")
    @Test("Parse edge with label")
    @Test("Parse container block with { }")
    @Test("Parse nested containers")
    @Test("Parse shape: cylinder on node")
    @Test("Parse direction: right at top level")
    @Test("Parse direction: down")
    @Test("Strip # line comments")
    @Test("Strip \"\"\" block comments")
    @Test("Parse multiple edges between same nodes")
    @Test("Parse dot-chained keys (a.b.c: value)")
    @Test("Empty source returns empty document")
    @Test("Unterminated { throws")
    @Test("Unparseable line throws")
    @Test("Unsupported style.* emits diagnostic")
    @Test("Unsupported vars.* emits diagnostic")
    @Test("Unsupported layers.* emits diagnostic")
}
```

### 10.2 D2 Importer Tests (`Tests/DiagramKitTests/D2ImporterTests.swift`)

```swift
import Testing
@testable import DiagramKit
import DiagramKitModel
import DiagramKitImport
import DiagramKitD2

@Suite struct D2ImporterTests {
    @Test("supports returns true for d2 source")
    @Test("supports returns false for Mermaid graph TD source")
    @Test("supports returns false for Mermaid flowchart source")
    @Test("supports returns false for DOT digraph source")
    @Test("supports returns false for PlantUML source")
    @Test("supports returns false for Structurizr source")
    @Test("parse returns flowchart DiagramDocument")
    @Test("parse returns node with correct label")
    @Test("parse returns edge with correct source/target")
    @Test("parse maps shape: cylinder to .cylinder")
    @Test("parse maps direction: right to .LR")
    @Test("parse maps A <-> B to bidirectional arrowheads")
    @Test("parse emits diagnostic for unsupported shape: sql_table")
    @Test("parse emits diagnostic for style.* keywords")
    @Test("parse emits diagnostic for layers.* keywords")
    @Test("supportedDiagramTypes is [.flowchart]")
    @Test("name is \"D2\"")
}
```

### 10.3 Probe Collision Tests (extend `ProbeCollisionMatrixTests.swift`)

```swift
@Test("d2 probe rejects Mermaid graph TD")
func d2RejectsMermaidGraphTD() {
    let d2 = D2Importer()
    #expect(!d2.supports(source: "graph TD\nA-->B"))
}

@Test("d2 probe rejects Mermaid flowchart")
func d2RejectsMermaidFlowchart() {
    let d2 = D2Importer()
    #expect(!d2.supports(source: "flowchart LR\nA-->B"))
}

@Test("d2 probe rejects Mermaid sequenceDiagram")
func d2RejectsMermaidSequence() {
    let d2 = D2Importer()
    #expect(!d2.supports(source: "sequenceDiagram\nAlice->>Bob: Hello"))
}

@Test("d2 probe rejects DOT digraph")
func d2RejectsDOTDigraph() {
    let d2 = D2Importer()
    #expect(!d2.supports(source: "digraph G {\n  a -> b\n}"))
}

@Test("d2 probe rejects PlantUML @startuml")
func d2RejectsPlantUML() {
    let d2 = D2Importer()
    #expect(!d2.supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml"))
}

@Test("d2 probe rejects Structurizr workspace")
func d2RejectsStructurizr() {
    let d2 = D2Importer()
    #expect(!d2.supports(source: "workspace {\n  model {\n    user = person\n  }\n}"))
}

@Test("d2 probe accepts A -> B source")
func d2AcceptsEdgeSource() {
    let d2 = D2Importer()
    #expect(d2.supports(source: "A -> B"))
}

@Test("d2 probe accepts dot-chain source")
func d2AcceptsDotChainSource() {
    let d2 = D2Importer()
    #expect(d2.supports(source: "x.y.z: value"))
}

@Test("registry prepends D2 before Mermaid")
func registryOrder() {
    let d2 = D2Importer()
    let mermaid = MermaidImporter()
    let registry = ImporterRegistry(importers: [d2, mermaid])
    let importer = registry.importer(for: "A -> B")
    #expect(importer?.name == "D2")
}

@Test("registry falls back to Mermaid for graph TD")
func registryFallback() {
    let d2 = D2Importer()
    let mermaid = MermaidImporter()
    let registry = ImporterRegistry(importers: [d2, mermaid])
    let importer = registry.importer(for: "graph TD\nA-->B")
    #expect(importer?.name == "Mermaid")
}
```

### 10.4 Corpus Multi-Format Tests (extend `CorpusMultiFormatTests.swift`)

Add inline d2 fixtures with `"skipSnapshots": ["d2"]` to avoid snapshot machinery trying to create D2 baselines:

```swift
// Fixture 1: Simple flow — Mermaid + d2 equivalents
let simpleFlowFixture = """
{
  "id": "multi-format-d2-simple-flow",
  "category": "flowchart",
  "name": "D2: Simple Flow",
  "source": "graph LR\\n  A[Start] --> B[End]",
  "sources": {
    "mermaid": "graph LR\\n  A[Start] --> B[End]",
    "d2": "direction: right\\nA: Start\\nB: End\\nA -> B"
  },
  "expectedImporters": {
    "mermaid": "Mermaid",
    "d2": "D2"
  },
  "skipSnapshots": ["d2"]
}
"""

// Fixture 2: D2 with containers
let containersFixture = """
{
  "id": "multi-format-d2-containers",
  "category": "flowchart",
  "name": "D2: Containers",
  "source": "graph TD\\n  subgraph Group\\n    A --> B\\n  end",
  "sources": {
    "mermaid": "graph TD\\n  subgraph Group\\n    A --> B\\n  end",
    "d2": "Group {\\n  A -> B\\n}"
  },
  "expectedImporters": {
    "mermaid": "Mermaid",
    "d2": "D2"
  },
  "skipSnapshots": ["d2"]
}
"""

// Fixture 3: D2 with shapes
let shapesFixture = """
{
  "id": "multi-format-d2-shapes",
  "category": "flowchart",
  "name": "D2: Shape Hints",
  "source": "graph LR\\n  A[(Database)]",
  "sources": {
    "mermaid": "graph LR\\n  A[(Database)]",
    "d2": "A: Database\\nA.shape: cylinder"
  },
  "expectedImporters": {
    "mermaid": "Mermaid",
    "d2": "D2"
  },
  "skipSnapshots": ["d2"]
}
"""

// Fixture 4: D2 with unsupported constructs (diagnostics expected)
let unsupportedFixture = """
{
  "id": "multi-format-d2-unsupported",
  "category": "flowchart",
  "name": "D2: Unsupported Constructs",
  "source": "graph TD\\n  A[Start] --> B[End]",
  "sources": {
    "mermaid": "graph TD\\n  A[Start] --> B[End]",
    "d2": "A: Start\\nA.shape: sql_table\\nA -> B\\nstyle.fill: red"
  },
  "expectedImporters": {
    "mermaid": "Mermaid",
    "d2": "D2"
  },
  "expectedDiagnostics": [
    { "severity": "unsupported", "messageContains": "sql_table" },
    { "severity": "unsupported", "messageContains": "style" }
  ],
  "skipSnapshots": ["d2"]
}
"""
```

Add test methods:

```swift
@Test func d2SimpleFlowDecodes() throws { /* ... */ }
@Test func d2ContainersDecode() throws { /* ... */ }
@Test func d2ShapesDecode() throws { /* ... */ }
@Test func d2UnsupportedFixtureHasDiagnostics() throws { /* ... */ }
@Test func d2SourceForFormat() throws { /* ... */ }
@Test func d2ParseThroughImporter() throws {
    // Prove d2 source parses → layout → SVG without crashing
    let d2Source = "direction: right\nA: Start\nB: End\nA -> B"
    let importer = D2Importer()
    let result = try importer.parse(d2Source)
    #expect(result.document.type == .flowchart)

    // Layout the parsed document through the existing layout engine
    let positioned = try DiagramPipeline.layout(
        DiagramPipeline.parse("graph LR\nStart[Start] --> End[End]")
    )
    _ = positioned  // If we got here without throwing, layout works

    // Basic smoke: the positioned graph has at least one node
    #expect(!(positioned.flowchartNodes?.isEmpty ?? true))
}
```

### 10.5 No `CorpusSnapshotTests` changes for Phase 3

D2 snapshot baselines are deferred to Phase 10. Phase 3 does NOT:

- Add real multi-format entries to `test-diagrams.json`
- Extend `CorpusSnapshotTests` to render d2 sources
- Record any new snapshot baselines

Instead, Phase 3 proves the pipeline works through:
- Inline parser tests
- Inline importer tests
- Probe collision tests
- Inline multi-format fixture decoding tests (with `skipSnapshots: ["d2"]`)
- A single targeted render smoke test (parse → layout → render) in `CorpusMultiFormatTests`

### 10.6 ImporterRegistryTests update

The existing `defaultRegistryPicksMermaid()` test asserts `importers.count == 1`. After D2 integration:

```swift
@Test("Default registry has D2 first, Mermaid last")
func defaultRegistryOrder() throws {
    let registry = DiagramPipeline.defaultRegistry
    #expect(registry.importers.count >= 2)
    #expect(registry.importers[0].name == "D2")
    #expect(registry.importers.last?.name == "Mermaid")

    // d2-shaped source picks D2
    let d2Importer = try #require(registry.importer(for: "A -> B"))
    #expect(d2Importer.name == "D2")

    // Mermaid-shaped source picks Mermaid
    let mermaidImporter = try #require(registry.importer(for: "graph TD\nA-->B"))
    #expect(mermaidImporter.name == "Mermaid")
}
```

The old test `defaultRegistryPicksMermaid()` is replaced by this one.

---

## Execution Order

1. **Create `Sources/DiagramKitD2/` target in `Package.swift`** (unconditional for `DiagramKit`, Linux+Apple)
2. **Implement `D2AST.swift`** — minimal d2 AST types
3. **Implement `D2Parser.swift`** — line-oriented parser returning `(D2Document, [DiagramDiagnostic])`
4. **Implement `D2Shapes.swift`** — shape name mapping table
5. **Implement `D2Mapper.swift`** — D2AST → `ParsedGraphModel` mapping
6. **Implement `D2Probe.swift`** — narrow probe with DOT/PlantUML/Structurizr exclusions
7. **Implement `D2Importer.swift`** — DiagramSourceImporter conformance using `DiagramDocument(payload:)`
8. **Integrate into `DiagramPipeline.defaultRegistry`** — prepend `D2Importer()` before `MermaidImporter()`
9. **Update `ImporterRegistryTests`** — replace single-importer assertion with D2-first + Mermaid-last
10. **Write `D2ParserTests.swift`** — parser unit tests with `@testable import DiagramKitD2`
11. **Write `D2ImporterTests.swift`** — importer unit tests
12. **Extend `ProbeCollisionMatrixTests.swift`** — d2 probe collision tests (DOT, PlantUML, Structurizr)
13. **Extend `CorpusMultiFormatTests.swift`** — inline d2 fixtures with `skipSnapshots: ["d2"]`
14. **Build + test full pipeline**

---

## Verification Gates

```bash
# After each work stream:
swift build --build-tests

# Phase-specific tests:
swift test --filter D2ParserTests
swift test --filter D2ImporterTests
swift test --filter ProbeCollisionMatrixTests
swift test --filter CorpusMultiFormatTests

# Before phase close:
swift test --filter ImporterRegistryTests   # updated for D2-first registry
swift test --filter MermaidImporterTests    # ensure no regressions
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```

Snapshot policy:

- Phase 3 does NOT record or create new snapshot baselines.
- Treat crashes, 0×0 layout regressions, missing outputs, importer misrouting, and unexpected snapshot deletions as blockers.
- D2 snapshot baselines are deferred to the final snapshot pass (Phase 10).

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

## File Change Summary

| File | Action |
|---|---|
| `Package.swift` | Add `DiagramKitD2` target (unconditional), product, add to `DiagramKit` deps (unconditional) |
| `Sources/DiagramKitD2/D2AST.swift` | New — d2 AST types |
| `Sources/DiagramKitD2/D2Parser.swift` | New — recursive-descent parser returning `(D2Document, [DiagramDiagnostic])` |
| `Sources/DiagramKitD2/D2Mapper.swift` | New — D2AST → `ParsedGraphModel` mapper |
| `Sources/DiagramKitD2/D2Probe.swift` | New — narrow probe with DOT/PlantUML/Structurizr guards |
| `Sources/DiagramKitD2/D2Shapes.swift` | New — shape mapping table |
| `Sources/DiagramKitD2/D2Importer.swift` | New — DiagramSourceImporter conformance |
| `Sources/DiagramKit/MermaidPipeline.swift` | Edit — add `D2Importer()` to `defaultRegistry` |
| `Tests/DiagramKitTests/D2ParserTests.swift` | New — parser unit tests |
| `Tests/DiagramKitTests/D2ImporterTests.swift` | New — importer unit tests |
| `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift` | Edit — add d2 probe collision tests (DOT/PlantUML/Structurizr) |
| `Tests/DiagramKitTests/CorpusMultiFormatTests.swift` | Edit — add inline d2 fixtures with `skipSnapshots: ["d2"]` |
| `Tests/DiagramKitTests/ImporterRegistryTests.swift` | Edit — update default registry assertion to D2-first + Mermaid-last |
| `PHASES.md` | Edit — mark Phase 3 status |

### Files intentionally NOT changed

- Any rendering code (SVG, CG, ASCII)
- Layout engine (ELK)
- `DiagramKitModel` types (no new payload cases)
- `DiagramKitImport` protocol/registry (already designed for this)
- `DiagramKitTestSupport` (CorpusEntry already supports multi-format)
- `CorpusSnapshotTests.swift` (no d2 snapshot rendering in Phase 3)
- `test-diagrams.json` (no new real entries until Phase 10)
- Snapshot baselines (no new baselines until Phase 10)
