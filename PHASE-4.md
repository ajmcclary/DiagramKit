# Phase 4: DOT Importer Vertical Slice — Plan

Date: 2026-05-12 (revised 2026-05-12 per review). **Status: COMPLETE** as of
2026-05-12. This document is the executable plan for Phase 4 of the DiagramKit
multi-format roadmap. It follows `PHASE-3.md` (complete: D2 importer) and
precedes Phase 5 (Structurizr importer).

## Goal

Add Graphviz DOT as the next focused graph-language importer. Prove the
importer architecture with a narrow DOT vertical slice that maps to
`DiagramPayload.flowchart`, parallel to the D2 slice.

## Architecture Overview

```
Sources/DiagramKitGraphviz/
├── GraphvizImporter.swift     DiagramSourceImporter conformance
├── DOTAST.swift               Minimal DOT AST types
├── DOTLexer.swift             Token types + lexer
├── DOTParser.swift            Recursive-descent parser
├── DOTMapper.swift            DOTAST → ParsedGraphModel mapping
└── DOTProbe.swift             Narrow probe function
```

The Graphviz importer is structurally identical to the D2 importer: parse a
subset of DOT, map to `ParsedGraphModel`, emit diagnostics for unsupported
constructs, and reuse the existing flowchart layout and render pipelines.
There are no new diagram types, no layout changes, no renderer changes, no
snapshot baselines, and no real corpus edits.

Splitting the lexer (`DOTLexer.swift`) from the parser prevents the parser
file from growing past the 500-line warning threshold.

## Work Stream 1: `DiagramKitGraphviz` Target

Add a single new SPM target and product. Follows the `DiagramKitD2` pattern
exactly.

### Package.swift changes

**Products** — add:

```swift
.library(name: "DiagramKitGraphviz", targets: ["DiagramKitGraphviz"]),
```

**Targets** — add:

```swift
.target(
    name: "DiagramKitGraphviz",
    dependencies: ["DiagramKitModel", "DiagramKitImport"],
    swiftSettings: strictConcurrencySettings
),
```

**Umbrella target** — add `DiagramKitGraphviz` as a dependency of `DiagramKit`:

```swift
.target(
    name: "DiagramKit",
    dependencies: [
        // ... existing deps ...
        .target(name: "DiagramKitD2"),
        .target(name: "DiagramKitGraphviz"),   // NEW
        // ...
    ]
),
```

**Test target** — add `DiagramKitGraphviz` as a dependency of `DiagramKitTests`:

```swift
.testTarget(
    name: "DiagramKitTests",
    dependencies: [
        // ... existing deps ...
        "DiagramKitD2",
        "DiagramKitGraphviz",                  // NEW
        // ...
    ]
),
```

## Work Stream 2: DOT AST Types (`DOTAST.swift`)

All types are value types (`Sendable`). The AST models the narrow DOT subset
we parse — not the full DOT language.

### DOT Graph types

```swift
/// Top-level: a DOT document is a graph or digraph with a list of statements.
public struct DOTDocument: Sendable {
    public var kind: DOTGraphKind          // graph or digraph
    public var strict: Bool                // strict graph / strict digraph
    public var id: String?                 // graph name (optional in DOT)
    public var statements: [DOTStatement]

    public init(kind: DOTGraphKind, strict: Bool = false,
                id: String? = nil, statements: [DOTStatement] = []) {
        self.kind = kind
        self.strict = strict
        self.id = id
        self.statements = statements
    }
}

public enum DOTGraphKind: Sendable {
    case graph                             // undirected
    case digraph                           // directed
}
```

### DOT Statement types

```swift
public enum DOTStatement: Sendable {
    case nodeStatement(DOTNodeStatement)       // `A;` or `A [attr=val];`
    case edgeStatement(DOTEdgeStatement)       // `A -> B;` or `A -- B;`
    case attrStatement(DOTAttrStatement)       // `node [shape=box];` or `edge [color=red];`
    case subgraph(DOTSubgraph)                 // `subgraph cluster_0 { ... }`
    case graphAttr(String, String)             // graph-level key=value (e.g., rankdir)
}

public struct DOTNodeStatement: Sendable {
    public var id: String
    public var attributes: [DOTAttribute]
    public var label: String? { attributes.first(where: { $0.key == "label" })?.value }

    public init(id: String, attributes: [DOTAttribute] = []) {
        self.id = id
        self.attributes = attributes
    }
}

public struct DOTEdgeStatement: Sendable {
    public var source: String
    public var target: String
    public var directed: Bool                  // true for `->`, false for `--`
    public var attributes: [DOTAttribute]
    public var label: String? { attributes.first(where: { $0.key == "label" })?.value }

    public init(source: String, target: String,
                directed: Bool = true, attributes: [DOTAttribute] = []) {
        self.source = source
        self.target = target
        self.directed = directed
        self.attributes = attributes
    }
}

public struct DOTAttrStatement: Sendable {
    public var target: DOTAttrTarget           // node, edge, or graph
    public var attributes: [DOTAttribute]

    public init(target: DOTAttrTarget, attributes: [DOTAttribute]) {
        self.target = target
        self.attributes = attributes
    }
}

public enum DOTAttrTarget: Sendable {
    case node                                // `node [shape=box]`
    case edge                                // `edge [color=red]`
    case graph                               // `graph [rankdir=LR]`
}

public struct DOTSubgraph: Sendable {
    public var id: String?                     // e.g., "cluster_0" (nil for anonymous)
    public var statements: [DOTStatement]

    public init(id: String? = nil, statements: [DOTStatement] = []) {
        self.id = id
        self.statements = statements
    }

    /// True when this subgraph's id starts with "cluster_" — DOT convention
    /// for clusters that render as named containers.
    public var isCluster: Bool {
        id?.hasPrefix("cluster_") ?? false
    }

    /// The display label for this subgraph. Derived from `label` attribute
    /// on a graph-level attr statement within the subgraph, or from the id
    /// itself (stripping `cluster_` prefix).
    public func displayLabel(from attributes: [DOTAttribute]) -> String? {
        attributes.first(where: { $0.key == "label" })?.value
            ?? id.map { $0.hasPrefix("cluster_") ? String($0.dropFirst(8)) : $0 }
    }
}

public struct DOTAttribute: Sendable, Hashable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}
```

**Design notes**:

- `DOTAttrStatement` captures default attribute assignments (`node [...]`,
  `edge [...]`, `graph [...]`) as explicit AST nodes. The mapper applies
  them to subsequent nodes/edges.
- `DOTSubgraph.id` is optional — DOT allows anonymous subgraphs. Only
  `subgraph cluster_*` subgraphs map to `MermaidSubgraph` containers.
  Anonymous subgraphs are semantically scoping boundaries with no visual
  container.
- `DOTAttribute` is a simple key-value pair. DOT attribute values can be
  quoted (`"value"`) or unquoted (`value`). The parser strips quotes.
- Graph-level attributes like `rankdir=LR` and `rank=same` are captured as
  `DOTStatement.graphAttr(key, value)` — simple key-value pairs rather
  than full attribute lists, since the DOT grammar allows both
  `rankdir=LR` and `graph [rankdir=LR]` forms for graph-level attributes.

## Work Stream 3: DOT Lexer (`DOTLexer.swift`)

A tokenizer that consumes raw DOT source and produces a stream of
`DOTToken` values for the parser.

### Token types

```swift
public enum DOTToken: Sendable, Equatable {
    case identifier(String)          // `A`, `graph`, `digraph`, `shape`, etc.
    case string(String)              // quoted string, quotes stripped
    case openBrace                   // `{`
    case closeBrace                  // `}`
    case openBracket                 // `[`
    case closeBracket                // `]`
    case semicolon                   // `;`
    case equals                      // `=`
    case comma                       // `,`
    case directedEdge                // `->`
    case undirectedEdge              // `--`
}
```

### Lexer / Preprocessing

- Strips `// ...` single-line comments and `/* ... */` block comments.
- Strips `#` line comments (some DOT variants accept these).
- Tokenizes on whitespace and punctuation: `{`, `}`, `;`, `[`, `]`, `=`,
  `->`, `--`, `,`.
- DOT identifiers: alphanumeric plus `_`, may be quoted in double-quotes.
- Strings in double-quotes return their content minus the quotes.

## Work Stream 4: DOT Parser (`DOTParser.swift`)

A recursive-descent parser consuming the token stream from `DOTLexer`.
Returns `(DOTDocument, [DiagramDiagnostic])`.

### Grammar subset (header required)

```
document      := header "{" statement* "}"
header        := "strict"? ("graph" | "digraph") ID?

statement     := node_stmt ";"
               | edge_stmt ";"
               | attr_stmt ";"
               | subgraph
               | graph_attr_stmt ";"

node_stmt     := ID attr_list?
edge_stmt     := ID ("->" | "--") ID attr_list?
               | edge_stmt ("->" | "--") ID   // chained: A -> B -> C

attr_stmt     := ("graph" | "node" | "edge") attr_list

graph_attr_stmt := ID "=" ID

attr_list     := "[" a_list? "]"
a_list        := ID "=" ID ("," ID "=" ID)*
```

**Header is required**: the `document` rule does NOT make `header`
optional. Every DOT document parsed through this importer must start with
`graph`, `digraph`, or `strict graph`/`strict digraph`. This matches the
probe contract — bare `A -> B` routes to D2, never to Graphviz.

### Parse rules (narrow subset)

| Input pattern | AST output |
|---|---|
| `digraph G { }` | `DOTDocument(kind: .digraph, id: "G")` |
| `strict digraph G { }` | `DOTDocument(kind: .digraph, strict: true, id: "G")` |
| `graph { }` | `DOTDocument(kind: .graph, id: nil)` |
| `A;` | `DOTStatement.nodeStatement(.init(id: "A"))` |
| `A [label="Start"];` | node with attribute |
| `A -> B;` | `DOTEdgeStatement(source: "A", target: "B", directed: true)` |
| `A -- B;` | `DOTEdgeStatement(source: "A", target: "B", directed: false)` |
| `A -> B [label="Edge"];` | edge with attribute |
| `node [shape=box];` | `DOTAttrStatement(target: .node, attrs: ...)` |
| `edge [color=red];` | `DOTAttrStatement(target: .edge, attrs: ...)` |
| `graph [rankdir=LR];` | `DOTAttrStatement(target: .graph, attrs: ...)` |
| `rankdir=LR;` | `DOTStatement.graphAttr("rankdir", "LR")` |
| `subgraph cluster_0 { A; B; }` | `DOTStatement.subgraph(.init(id: "cluster_0", ...))` |
| `subgraph { A; B; }` | anonymous subgraph |
| `// comment` / `/* comment */` | skip |

### Key parser behaviors

1. **Chained edges**: `A -> B -> C` parses as two edge statements: `A -> B`
   and `B -> C`. This matches DOT semantics.

2. **Trailing semicolons**: DOT uses `;` as statement terminators. The
   parser treats `;` as a delimiter so `A;` is a node statement and
   `A -> B;` is an edge statement. Statements without `;` at end-of-line
   within braces are also accepted (lenient parsing).

3. **Whitespace resilience**: DOT is whitespace-insensitive.
   `digraph{ A->B }` parses identically to `digraph {\n  A -> B\n}`.
   The tokenizer collapses whitespace runs.

4. **Quoted identifiers and attribute values**: `"node name" [label="A Node"];`
   — identifiers and attribute values may be quoted. The lexer strips
   quotes and delivers the content as `.string` or `.identifier` tokens.

5. **Attribute lists**: `[label="Node", shape=box, color=red]` — key-value
   pairs separated by commas within brackets.

6. **Unquoted attribute values**: `shape=box` (no quotes) is valid DOT.
   The parser accepts both `shape=box` and `shape="box"`.

7. **Balanced braces**: The parser validates that `{` and `}` are balanced.
   Unbalanced braces produce `DiagramError`.

8. **Edge chains with attribute lists**: `A -> B -> C [label="path"]` —
   the attribute list applies to the last edge (`B -> C`) only.

9. **Nested subgraphs in edges**: We do NOT support `A -> subgraph { B; C }`
   in this slice. Emit `.unsupported` diagnostic.

## Work Stream 5: DOT → ParsedGraphModel Mapper (`DOTMapper.swift`)

Converts `DOTDocument` → `ParsedGraphModel` (typealias for `MermaidGraph`)
plus diagnostics. Follows the `D2Mapper` pattern: ordered node table with
merge and edge-endpoint synthesis.

### Core mapping table

| DOT construct | ParsedGraphModel field |
|---|---|
| `digraph` + `rankdir=LR` | `direction: .LR` |
| `digraph` (no `rankdir`) | `direction: .TD` (default) |
| `graph` (undirected) | `direction: .TD` (no direction concept for undirected) |
| `A [label="Start"]` | `nodesInOrder`: `(id: "A", node: MermaidNode(label: "Start", shape: .rectangle))` |
| `A;` (no label) | `nodesInOrder`: `(id: "A", node: MermaidNode(label: "A", shape: .rectangle))` |
| `A -> B` | `edges`: `MermaidEdge(source: "A", target: "B", arrowHeadEnd: .arrow)` |
| `A -- B` | `edges`: `MermaidEdge(source: "A", target: "B", arrowHeadEnd: .none)` |
| `subgraph cluster_0 { ... }` | `subgraphs`: `MermaidSubgraph(id: "cluster_0", label: ..., nodeIds: [...])` |
| anonymous `subgraph { ... }` | nodes/edges inlined in parent; no visual container |
| `node [shape=box, style=filled]` | sets default attributes for subsequent node statements |
| `edge [color=red]` | deferred → `.unsupported` diagnostic |
| `graph [rankdir=LR]` | `direction: .LR` |

### Key mapper behaviors

1. **Node table is order-preserving and merge-aware** — same pattern as D2
   mapper. `A;` followed by `A [label="Start"];` merges into one node.
   `A [label="X"];` after `A [label="Y"];` emits a diagnostic (duplicate
   node with different label) and keeps the first label.

2. **Edge-only endpoint synthesis** — same pattern as D2 mapper. When
   `A -> B` appears and `A` or `B` don't exist in the node table, the
   mapper synthesizes nodes with the endpoint ID as the label.

3. **Chained edges** — `A -> B -> C` produces two edges: `A -> B` and
   `B -> C`. Both endpoints are synthesized if not already defined.

4. **Cluster subgraphs** — `subgraph cluster_*` maps to
   `MermaidSubgraph(id:..., label:..., nodeIds: [...])`. The label
   derived from a `label` attribute within the subgraph, or from the id
   with `cluster_` prefix stripped. Anonymous subgraphs are NOT clusters
   — their nodes/edges flow into the parent scope.

5. **Default attribute tracking** — `node [shape=box]` sets a default
   shape applied to all subsequent node statements that don't have an
   explicit `shape` attribute. `edge [color=red]` is captured as a
   pending default but emits `.unsupported` diagnostic (edge styling not
   yet supported). These defaults are scoped to the current subgraph; they
   reset when exiting the subgraph.

6. **Graph-level `rankdir` → direction** — `rankdir=LR` maps to
   `direction: .LR`. `rankdir=TB` maps to `direction: .TD`. `rankdir=BT`
   maps to `direction: .BT`. `rankdir=RL` maps to `direction: .RL`.
   This applies ONLY at the top-level graph scope, not in nested
   subgraphs (ELK layout doesn't support per-subgraph direction).

7. **Node shape mapping** — DOT `shape` attribute values map to
   `NodeShape`:
   - `box`, `rect`, `rectangle` → `.rectangle`
   - `ellipse`, `oval` → `.ellipse`
   - `circle` → `.circle`
   - `diamond` → `.diamond`
   - `cylinder` → `.cylinder`
   - `hexagon` → `.hexagon`
   - `parallelogram`, `trapezium`, `invtrapezium`, `triangle`, `point`,
     `doublecircle`, `tripleoctagon`, `invtriangle`, `Mdiamond`,
     `Msquare`, `Mcircle`, `note`, `tab`, `folder`, `box3d`,
     `component` — plus the full graphviz `record`-based and bioinformatics
     shape families — all emit `.unsupported` diagnostic with fallback to
     `.rectangle`
   - `plaintext`, `none` → `.text`
   - `record`, `Mrecord` → `.unsupported` diagnostic (record nodes not yet supported)

8. **Duplicate edges preserved; `strict` emits diagnostic** — Non-strict
   DOT graphs may contain multiple edges between the same pair. The mapper
   preserves all edges (no deduplication). When `doc.strict == true`, the
   mapper emits a diagnostic: "strict mode not yet supported; duplicate
   edges preserved." This avoids silently dropping valid non-strict edges
   and surfaces the deferral explicitly.

9. **Subgraph label extraction** — When a subgraph contains
   `graph [label="Container Name"];` or `label="Container Name";`, the
   mapper extracts the label. When absent, the subgraph's display label
   is derived from the `cluster_*` id with the prefix stripped.

## Work Stream 6: DOT Probe (`DOTProbe.swift`)

A narrow probe function that requires explicit DOT structure. It must NOT
false-match on D2, Mermaid, PlantUML, or Structurizr source.

```swift
/// Returns true when `source` appears to be Graphviz DOT rather than any
/// other known format. This is a narrow probe — it requires `graph`,
/// `digraph`, or `strict graph` / `strict digraph` structure.
public func isDOTSource(_ source: String) -> Bool {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    let firstLine = trimmed.split(separator: "\n").first?
        .trimmingCharacters(in: .whitespaces) ?? ""

    // Bare A -> B without a graph/digraph/strict header is D2-shaped input,
    // to avoid ambiguity. Headers are required for importer routing.

    let lower = firstLine.lowercased()

    // PlantUML / Structurizr guards
    if trimmed.contains("@startuml") || trimmed.contains("@start") { return false }
    if trimmed.hasPrefix("workspace {") || trimmed.hasPrefix("workspace{") { return false }

    // Tokenize the first line to avoid prefix-only false matches
    // (e.g. "digraphy" would match hasPrefix("digraph")).
    let tokens = lower.split(separator: " ", omittingEmptySubsequences: true)
    guard let firstToken = tokens.first else { return false }

    // "strict digraph" / "strict graph" — two-token header
    if firstToken == "strict", tokens.count >= 2 {
        let second = tokens[1]
        if second == "digraph" || second == "graph" { return true }
        return false
    }

    // Single-token headers: digraph, graph
    if firstToken == "digraph" { return true }

    if firstToken == "graph" {
        // Reject Mermaid's "graph TD", "graph LR", etc.
        // After "graph", the next token is a direction keyword for Mermaid,
        // or an optional graph name / "{" for DOT.
        if tokens.count >= 2 {
            let second = tokens[1]
            if ["td", "lr", "bt", "rl", "tb"].contains(where: {
                second.hasPrefix($0)
            }) {
                return false
            }
        }
        return true
    }

    return false
}
```

**Probe design rationale**:

- The probe tokenizes the first line and checks token boundaries rather
  than raw `hasPrefix`, avoiding false matches on words like `digraphy`.
  This is narrower than D2's `contains("->")` probe, so DOT is ordered
  BEFORE D2 in the registry.
- Mermaid's `graph TD` / `graph LR` headers start with `graph` followed
  by a direction keyword. The probe explicitly rejects these.
- Bare `A -> B` without a container is NOT DOT — it remains D2-shaped
  input. The DOT probe requires a `graph`/`digraph`/`strict` header.
- `strict` keyword is DOT-specific and provides a strong positive signal.
- PlantUML `@startuml` and Structurizr `workspace {` are explicitly
  rejected before the DOT header check.

## Work Stream 7: GraphvizImporter (`GraphvizImporter.swift`)

```swift
import Foundation
import DiagramKitModel
import DiagramKitImport

/// Graphviz DOT source-format importer.
///
/// Parses DOT source into a `DiagramDocument` with `DiagramPayload.flowchart`
/// by mapping DOT constructs to `ParsedGraphModel`. Unsupported DOT features
/// emit `.unsupported` diagnostics.
public struct GraphvizImporter: DiagramSourceImporter {

    public let name = "Graphviz"
    public let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    public init() {}

    public func supports(source: String) -> Bool {
        isDOTSource(source)
    }

    public func parse(_ source: String) throws -> DiagramImportResult {
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)

        let parser = DOTParser()
        let (dotDoc, parseDiagnostics) = try parser.parse(tokens)

        let mapper = DOTMapper()
        let (graph, mapDiagnostics) = mapper.map(dotDoc)

        let allDiagnostics = parseDiagnostics + mapDiagnostics
        let payload = DiagramPayload.flowchart(graph)
        let document = DiagramDocument(payload: payload)

        return DiagramImportResult(document: document, diagnostics: allDiagnostics)
    }
}
```

## Work Stream 8: Registry Integration

Update `DiagramPipeline.defaultRegistry` to prepend `GraphvizImporter()`
before `D2Importer()` and `MermaidImporter()`:

```swift
public static let defaultRegistry: ImporterRegistry = ImporterRegistry(
    importers: [GraphvizImporter(), D2Importer(), MermaidImporter()]
)
```

**Probe order rationale**: DOT's probe requires explicit `digraph`/`graph`/
`strict` headers — narrower than D2's `->`/`-->`/dot-chain probe. DOT must
fire first so `digraph G { A -> B }` routes to `GraphvizImporter`, not
`D2Importer`.

The import in `MermaidPipeline.swift`:

```swift
import DiagramKitGraphviz
```

## Work Stream 9: Diagnostics for Unsupported DOT Constructs

The parser and mapper emit `.unsupported` diagnostics for DOT features
outside the narrow vertical slice. Categories:

| DOT feature | Diagnostic |
|---|---|
| `shape=record` / `shape=Mrecord` | "record nodes not yet supported; rendered as rectangle" |
| `shape=parallelogram`, `shape=trapezium`, `shape=triangle`, etc. | "\(shape) shape not yet supported; rendered as rectangle" |
| `style=filled`, `style=dashed`, `style=dotted`, etc. | "node/edge style not yet supported" |
| `color=*`, `fillcolor=*`, `fontcolor=*`, `bgcolor=*`, `pencolor=*` | "color attributes not yet supported" |
| `fontname`, `fontsize` | "font attributes not yet supported" |
| `penwidth`, `arrowsize`, `arrowhead` | "line/arrow attributes not yet supported" |
| `rank=same`, `rank=min`, `rank=max` | "rank constraints not yet supported" |
| `constraint=false`, `weight=N` | "edge weight/constraint not yet supported" |
| `splines`, `overlap`, `sep`, `pad`, `margin`, `nodesep`, `ranksep` | "layout engine attributes not yet supported" |
| `url`, `href`, `target`, `tooltip` | "hyperlink attributes not yet supported" |
| `image`, `imagescale`, `imagepos` | "image attributes not yet supported" |
| `bgcolor`, `pencolor`, `labelloc`, `labeljust` | "graph appearance attributes not yet supported" |
| `compound=true`, `lhead`, `ltail` | "compound edge attributes not yet supported" |
| `concentrate=true` | "edge concentration not yet supported" |
| `center=true`, `resolution`, `page`, `viewport`, `ratio`, `size` | "graph layout attributes not yet supported" |
| `A -> subgraph { ... }` | "edges to subgraphs not yet supported" |
| `A:n -> B:s` (port syntax) | "port syntax not yet supported" |
| HTML-like labels (`<TABLE>`, `<FONT>`, etc.) | "HTML-like labels not yet supported" |
| `strict` keyword | Diagnostic only — "strict mode not yet supported; duplicate edges preserved." Parsed but edge dedup deferred. |

### Diagnostic emission strategy

- **Parser emits diagnostics** for unsupported constructs discovered during
  parsing (HTML labels, port syntax, nested subgraph edges).
- **Mapper emits diagnostics** for supported constructs with unsupported
  attributes (shape=record, color=red, etc.) and for deferred features
  (default edge attributes, compound edges, strict mode, etc.).
- **Diagnostics carry `line` information** when available from the parser.
  Mapper-level diagnostics carry no line info (they fire during AST walk).
- **Never silent no-op**: every unrecognized attribute or unsupported
  construct produces a diagnostic. No information is silently dropped.

## Work Stream 10: Tests

### 10a. `DOTParserTests` (new file: `Tests/DiagramKitTests/DOTParserTests.swift`)

Parser unit tests for the lexer and recursive-descent parser. At least
18 tests:

| Test name | Description |
|---|---|
| `parseEmptyDigraph` | `digraph G {}` → document with kind=.digraph, id="G", zero statements |
| `parseEmptyGraph` | `graph {}` → document with kind=.graph |
| `parseStrictDigraph` | `strict digraph G {}` → strict=true, kind=.digraph |
| `parseStrictGraph` | `strict graph G {}` → strict=true, kind=.graph |
| `parseSingleNode` | `digraph { A; }` → one DOTNodeStatement with id="A" |
| `parseNodeWithLabel` | `digraph { A [label="Start"]; }` → node with label attribute |
| `parseNodeWithMultipleAttrs` | `digraph { A [label="X", shape=box]; }` → two attributes |
| `parseDirectedEdge` | `digraph { A -> B; }` → edge with directed=true |
| `parseUndirectedEdge` | `graph { A -- B; }` → edge with directed=false |
| `parseEdgeWithLabel` | `digraph { A -> B [label="Edge"]; }` → edge with label attribute |
| `parseChainedEdge` | `digraph { A -> B -> C; }` → two edge statements |
| `parseNodeDefaultAttr` | `digraph { node [shape=box]; A; }` → attr statement + node |
| `parseSubgraphCluster` | `digraph { subgraph cluster_0 { A; B; } }` → subgraph with id="cluster_0" |
| `parseAnonymousSubgraph` | `digraph { subgraph { A; } }` → subgraph with nil id |
| `parseGraphRankdir` | `digraph { rankdir=LR; }` → graphAttr("rankdir", "LR") |
| `parseComments` | `digraph { // comment\nA; /* block */\nB; }` — comments stripped, nodes parsed |
| `parseUnquotedAttrValue` | `digraph { A [shape=box]; }` → attribute with key="shape", value="box" |
| `parseThrowsOnUnbalancedBraces` | `digraph { A;` → throws `DiagramError` |
| `parseWhitespaceInsensitive` | `digraph{A->B}` parses identically to `digraph {\n  A -> B\n}` |

### 10b. `DOTImporterTests` (new file: `Tests/DiagramKitTests/DOTImporterTests.swift`)

Importer unit tests. At least 24 tests:

**supports tests:**

| Test name | Description |
|---|---|
| `supportsDigraph` | `digraph G { A -> B }` → true |
| `supportsGraph` | `graph G { A -- B }` → true |
| `supportsStrictDigraph` | `strict digraph G { }` → true |
| `rejectsMermaidGraphTD` | `graph TD\nA-->B` → false |
| `rejectsBareEdge` | `A -> B` → false (no digraph/graph header) |
| `rejectsD2Source` | `A: Start\nA -> B` → false |
| `rejectsPlantUML` | `@startuml\nAlice -> Bob: Hello\n@enduml` → false |
| `rejectsStructurizr` | `workspace { model { user = person } }` → false |

**parse tests:**

| Test name | Description |
|---|---|
| `parseNodeLabel` | `digraph { A [label="Start"]; }` → node with label "Start" |
| `parseEdgeOnlyEndpointSynthesis` | `digraph { A -> B; }` → two nodes synthesized with ids "A" and "B" |
| `parseDirectedEdge` | `digraph { A -> B; }` → edge with `arrowHeadEnd: .arrow` |
| `parseUndirectedEdge` | `graph { A -- B; }` → edge with `arrowHeadEnd: .none` |
| `parseMultipleEdges` | `digraph { A -> B; B -> C; C -> A; }` → three edges |
| `parseDefaultNodeShape` | `digraph { node [shape=box]; A; }` → A has shape .rectangle |
| `parseRankdirLR` | `digraph { rankdir=LR; A -> B; }` → direction = .LR |
| `parseSubgraphCluster` | `digraph { subgraph cluster_0 { A; B; } }` → one subgraph with nodeIds ["A", "B"] |
| `parseSubgraphClusterLabel` | `digraph { subgraph cluster_0 { label="Group"; A; } }` → subgraph label = "Group" |
| `parseNestedSubgraph` | `digraph { subgraph cluster_0 { subgraph cluster_1 { A; } } }` → nested subgraphs |
| `parseChainedEdges` | `digraph { A -> B -> C; }` → two edges, three nodes |
| `preservesDuplicateEdges` | `digraph { A -> B; A -> B; }` → two edges (not deduplicated) |
| `emitsDiagnosticForRecordShape` | `digraph { A [shape=record]; }` → diagnostic |
| `emitsDiagnosticForColorAttribute` | `digraph { A [color=red]; }` → diagnostic |
| `emitsDiagnosticForStyleFilled` | `digraph { A [style=filled]; }` → diagnostic |
| `emitsDiagnosticForRankSame` | `digraph { rank=same; A; B; }` → diagnostic |
| `emitsDiagnosticForStrict` | `strict digraph G { A -> B }` → diagnostic about strict mode |

**layout smoke tests:**

| Test name | Description |
|---|---|
| `dotLayoutSmoke` | Parse simple digraph, run `DiagramPipeline.layout`, verify non-empty positioned output |
| `dotLayoutWithClusterSmoke` | Parse digraph with cluster subgraph, layout, verify subgraph present |
| `dotLayoutWithUndirectedSmoke` | Parse undirected graph, layout, verify non-empty output |

### 10c. Probe Collision Tests (edit `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift`)

Add DOT probe collision tests. At least 12 new tests:

| Test name | Description |
|---|---|
| `dotProbeAcceptsDigraph` | `GraphvizImporter().supports(source: "digraph G { A -> B }")` → true |
| `dotProbeAcceptsGraph` | `GraphvizImporter().supports(source: "graph G { A -- B }")` → true |
| `dotProbeAcceptsStrictDigraph` | `GraphvizImporter().supports(source: "strict digraph G { }")` → true |
| `dotProbeRejectsMermaidGraphTD` | `GraphvizImporter().supports(source: "graph TD\nA-->B")` → false |
| `dotProbeRejectsMermaidFlowchart` | `GraphvizImporter().supports(source: "flowchart LR\nA-->B")` → false |
| `dotProbeRejectsD2Source` | `GraphvizImporter().supports(source: "A: Start\nA -> B")` → false |
| `dotProbeRejectsBareEdge` | `GraphvizImporter().supports(source: "A -> B")` → false |
| `dotProbeRejectsPlantUML` | `GraphvizImporter().supports(source: "@startuml\nAlice -> Bob: Hello\n@enduml")` → false |
| `dotProbeRejectsStructurizr` | `GraphvizImporter().supports(source: "workspace { model { user = person } }")` → false |
| `dotProbeRejectsPrefixMatch` | `GraphvizImporter().supports(source: "digraphy { }")` → false (token boundary) |
| `registryPrependsGraphvizBeforeD2` | `registry.importer(for: "digraph G { A -> B }")?.name == "Graphviz"` |
| `registryFallsBackToD2ForBareEdge` | `registry.importer(for: "A -> B")?.name == "D2"` |
| `registryFallsBackToMermaidForGraphTD` | `registry.importer(for: "graph TD\nA-->B")?.name == "Mermaid"` |

### 10d. `DOTCorpusFixtureTests` (new file: `Tests/DiagramKitTests/DOTCorpusFixtureTests.swift`)

Inline corpus fixtures with `skipSnapshots: ["graphviz"]`. At least 6 tests,
following the `D2CorpusFixtureTests.swift` pattern:

| Test name | Description |
|---|---|
| `dotSimpleFlowFixtureDecodes` | Inline fixture with digraph node+edge, Mermaid/DOT source pair |
| `dotContainersFixtureDecodes` | Inline fixture with cluster subgraph |
| `dotUndirectedFixtureDecodes` | Inline fixture with undirected graph |
| `dotUnsupportedFixtureHasDiagnostics` | Inline fixture with record shape + color attrs → `expectedDiagnostics` |
| `dotSourceForFormat` | `entry.source(for: "graphviz")` returns the DOT source |
| `dotParseThroughImporter` | Parse DOT source via `GraphvizImporter`, layout, verify non-empty |

### 10e. Registry Tests (edit `Tests/DiagramKitTests/ImporterRegistryTests.swift`)

Update existing registry tests for the new three-importer order:

| Test | Change |
|---|---|
| `defaultRegistryOrder` | Assert `registry.importers[0].name == "Graphviz"`, `[1] == "D2"`, last == "Mermaid" |
| `prependingPutsFirst` | Extend to show `GraphvizImporter()` prepended before D2+Mermaid |

### 10f. Existing Test Regressions

Run and verify no regressions:

```bash
swift test --filter D2ParserTests
swift test --filter D2ImporterTests
swift test --filter D2FixtureTests
swift test --filter MermaidImporterTests
swift test --filter MermaidLegacyAPITests
swift test --filter DiagramRegistryTests
swift test --filter MultiFormatDecodingTests
swift test --filter MultiFormatFixtureMetadataTests
swift test --filter MultiFormatBackwardCompatibilityTests
swift test --filter MultiFormatValidationTests
swift test --filter MultiFormatSparseMatrixTests
swift test --filter PlaygroundCorpusDecodingTests
```

## File Change Summary

| File | Action | Status |
|---|---|---|
| `Package.swift` | Add `DiagramKitGraphviz` target, product, deps. Add to umbrella + test target deps | Done |
| `Sources/DiagramKitGraphviz/DOTAST.swift` | New — DOT AST types | Done |
| `Sources/DiagramKitGraphviz/DOTLexer.swift` | New — DOT token types + lexer | Done |
| `Sources/DiagramKitGraphviz/DOTParser.swift` | New — recursive-descent parser | Done |
| `Sources/DiagramKitGraphviz/DOTMapper.swift` | New — DOTAST → `ParsedGraphModel` mapper | Done |
| `Sources/DiagramKitGraphviz/DOTProbe.swift` | New — narrow DOT probe | Done |
| `Sources/DiagramKitGraphviz/GraphvizImporter.swift` | New — `DiagramSourceImporter` conformance | Done |
| `Sources/DiagramKit/MermaidPipeline.swift` | Edit — add `GraphvizImporter()` to `defaultRegistry` + `import DiagramKitGraphviz` | Done |
| `Tests/DiagramKitTests/DOTParserTests.swift` | New — 19 parser unit tests (all pass) | Done |
| `Tests/DiagramKitTests/DOTImporterTests.swift` | New — 30 importer unit tests (all pass) | Done |
| `Tests/DiagramKitTests/ProbeCollisionMatrixTests.swift` | Edit — 13 DOT probe collision tests + `import DiagramKitGraphviz` (all pass) | Done |
| `Tests/DiagramKitTests/DOTCorpusFixtureTests.swift` | New — 6 inline DOT fixture tests (all pass) | Done |
| `Tests/DiagramKitTests/ImporterRegistryTests.swift` | Edit — Graphviz-first registry assertion + `import DiagramKitGraphviz` (all pass) | Done |

### Files intentionally NOT changed

- Rendering code (SVG, CG, ASCII) — unchanged
- Layout engine (ELK) — unchanged
- `DiagramKitModel` types — no new payload cases
- `DiagramKitImport` protocol/registry — already designed for this
- `DiagramKitTestSupport` — no new types needed
- `CorpusSnapshotTests.swift` — no DOT snapshot rendering in Phase 4
- `test-diagrams.json` — no new real entries
- Snapshot baselines — no new baselines
- D2 importer sources (`Sources/DiagramKitD2/`) — unchanged
- Mermaid parser/rendering sources — unchanged

## Verification Gates

```bash
swift package dump-package
swift build --build-tests
swift test --filter DOTParserTests
swift test --filter DOTImporterTests
swift test --filter DOTCorpusFixtureTests
swift test --filter ProbeCollisionMatrixTests
swift test --filter ImporterRegistryTests
swift test --filter D2ParserTests           # regression
swift test --filter D2ImporterTests         # regression
swift test --filter MermaidImporterTests    # regression
swift test --filter DiagramRegistryTests    # regression
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
git diff --check
```

`Scripts/check-file-sizes.sh` may report pre-existing warnings. Phase 4
should not add new warnings; splitting `DOTLexer.swift` and `DOTParser.swift`
keeps each new file under 500 lines.

No snapshot recording. No Linux check unless Docker/Podman is available
(record as skipped due to environment otherwise).

## Design Decisions

### 1. DOT probe is narrower than D2 probe — Graphviz goes first

**Decision**: `GraphvizImporter()` is prepended before `D2Importer()` in
the default registry. DOT's probe requires explicit `digraph`/`graph`/
`strict` headers, which is narrower than D2's `->`/dot-chain probe.

**Rationale**: `digraph G { A -> B }` contains `->` which would match D2's
probe. DOT must fire first. If Graphviz were after D2, D2 would claim DOT
source. The probe guard rails in each importer's `supports()` prevent
cross-format false-positives, but probe order is the primary defense.

### 2. Bare `A -> B` is NOT DOT

**Decision**: The DOT probe requires a `digraph`/`graph`/`strict` header.
Bare `A -> B` without a container remains D2-shaped input. The parser also
requires a header — the `document` grammar rule is `header "{" ... "}"`,
not `header? "{" ... "}"`.

**Rationale**: DOT is a container language — every valid DOT document starts
with `graph`/`digraph`/`strict` followed by `{`. A bare edge floating at
top level is D2 syntax, not DOT. Requiring the header everywhere (probe,
parser grammar, tests) keeps the boundary clean and avoids ambiguous routing.

### 3. `strict` parsed, dedup deferred

The `strict` keyword in DOT means "no multi-edges between the same pair
of nodes." Non-strict DOT graphs may contain multiple edges between the
same pair, and the mapper must preserve them. In this vertical slice the
mapper preserves all edges (no deduplication). When `doc.strict == true`
it emits a diagnostic: "strict mode not yet supported; duplicate edges
preserved." This avoids silently dropping valid non-strict edges and
surfaces the deferral explicitly.

### 4. Anonymous subgraphs don't create containers

DOT's anonymous `subgraph { ... }` is a scoping boundary — it groups nodes
for layout purposes without creating a visible container. In this vertical
slice, anonymous subgraphs inline their nodes/edges into the parent scope
and do not produce `MermaidSubgraph` entries. Only `subgraph cluster_*`
creates named containers.

### 5. Default attribute scoping

When `node [shape=box]` appears inside a subgraph, it applies to all
subsequent nodes within that subgraph only. When the parser exits the
subgraph, the defaults reset to the parent's defaults. This scoping
matches DOT semantics.

### 6. `edge` default attributes emit diagnostics

`edge [color=red]` and similar default edge attributes are parsed but emit
`.unsupported` diagnostics because edge styling is not yet supported in the
DiagramKit mapping. The default is tracked internally for future use.

### 7. Graph-level attributes vs. graph-attr-statements

DOT allows both `rankdir=LR;` (bare assignment) and `graph [rankdir=LR];`
(attribute list form) for graph-level attributes. The parser handles both:

- `rankdir=LR;` → `DOTStatement.graphAttr("rankdir", "LR")`
- `graph [rankdir=LR];` → `DOTStatement.attrStatement(.graph, ...)`

The mapper checks both forms to extract direction and other graph-level
settings.

### 8. No new payload cases, no new diagram types

DOT maps to the existing `DiagramPayload.flowchart(ParsedGraphModel)`.
No changes to `DiagramType`, `DiagramPayload`, or `PositionedContent`.
Layout and rendering reuse the existing flowchart paths unchanged.

### 9. Mermaid `graph TD` ≠ DOT `graph G`

Mermaid's `graph TD\nA-->B` and DOT's `graph G { A -- B }` both start with
`graph` but are entirely different languages. The DOT probe explicitly
rejects Mermaid's `graph TD` / `graph LR` pattern by testing for direction
keywords immediately after `graph`. The D2 probe also rejects DOT's
`digraph` / `graph` / `strict` headers. Both guard rails are tested.

### 10. No snapshot baselines

DOT fixtures carry `skipSnapshots: ["graphviz"]` and do not produce
snapshot baselines. No real `test-diagrams.json` entries are added. This
matches the D2 Phase 3 pattern.

### 11. Lexer split from parser

The lexer (`DOTLexer.swift`) is a separate file from the parser to keep
both files under the 500-line gate. The lexer owns token type definitions
and preprocessing (comment stripping, tokenization). The parser consumes
`[DOTToken]` and emits `DOTDocument` + diagnostics.

## Deferred to Later Phases

- DOT record nodes and HTML-like labels
- DOT node/edge styling (colors, fonts, line styles, fill, penwidth)
- DOT layout engine attributes (rank, weight, constraint, splines, overlap,
  sep, pad, margins, nodesep, ranksep, concentrate, compound)
- DOT hyperlink attributes (URL, href, target, tooltip)
- DOT image attributes
- DOT port syntax (`A:n -> B:s`)
- Edges to subgraphs (`A -> subgraph { B; C; }`)
- Multi-node edge chains with attributes on intermediate segments
- DOT `strict` enforcement (edge deduplication)
- DOT default edge attributes (parsed but unsupported)
- Layout-based attributes (`rank=same`, `rank=min`, `rank=max`)
- DOT graph appearance (bgcolor, pencolor, labelloc, labeljust)
- Comma-separated node lists (`A, B, C;` — not standard DOT grammar;
  lenient parsing deferred)
- Real `test-diagrams.json` multi-format entries
- DOT snapshot baselines (SVG, image, ASCII)

## Implementation Notes (2026-05-12)

### Parser fixes made during implementation

Three bugs surfaced during initial test runs that required parser corrections:

1. **Header ID consumption** (`parseHeader`). The plan specified `ID?` as the
   optional graph name, but the original code only *peeked* the identifier
   without consuming it. For `digraph G { }`, the lexer produces
   `[identifier("digraph"), identifier("G"), openBrace]`. After consuming
   `digraph`, the next token was `identifier("G")` — `parseDocument` then
   called `expect(.openBrace)` which failed. Fixed by consuming the optional
   graph ID when the next token is `{`.

2. **Subgraph ID consumption** (`parseSubgraph`). Same pattern as header:
   `subgraph cluster_0 { ... }` was tokenized as
   `[identifier("subgraph"), identifier("cluster_0"), openBrace, ...]`.
   The optional subgraph ID had to be explicitly consumed before expecting
   `{`. Fixed identically to header parsing.

3. **Chained edge handling** (`parseEdgeStatement`). The original
   implementation returned only the first edge (`A -> B`) from `A -> B -> C`
   because it could not "unread" consumed tokens for re-entry through
   `parseStatement`. Fixed by adding a `pendingStatements: [DOTStatement]`
   buffer to `State`. When a chain is detected, subsequent segments are
   buffered and flushed at the end of `parseDocument`. The attribute list
   at the end of the chain is applied to the last buffered edge.

### Test suite results

| Suite | Tests | Status |
|---|---|---|
| `DOTParserTests` | 19 | All pass |
| `DOTImporterTests` | 30 | All pass (includes 3 layout smoke tests) |
| `ProbeCollisionMatrixTests` | 28 | All pass (13 new DOT tests + existing D2/Mermaid) |
| `DOTCorpusFixtureTests` | 6 | All pass |
| `ImporterRegistryTests` | 7 | All pass (updated for 3-importer order) |
| `D2ParserTests` | 20 | All pass (regression) |
| `D2ImporterTests` | 22 | All pass (regression) |

### One test correction

The `dotLayoutSmoke` test originally used `digraph { A: Start; ... }` syntax,
which is D2 colon-assignment, not DOT. DOT uses `A [label="Start"]`. The
test was corrected to use valid DOT syntax before the final run.

---

*This plan was prepared from live codebase analysis of Package.swift,
Sources/DiagramKitD2/, Sources/DiagramKit/, Tests/DiagramKitTests/,
and the existing Phase 0-3 documentation as they exist at 2026-05-12.
Revised per review to fix headerless-DOT inconsistency, `strict`
semantics, comma-separated node lists, probe token boundaries, lexer
split, and "unchanged files" phrasing.*
