# DiagramKit → Multi-Format Diagram Toolkit: Architecture Analysis

Date: 2026-05-12. This document is a survey-and-plan artifact comparing DiagramKit
(mermaid-swift) with MusicToolkit (~/Workspace/packages/MusicToolkit) and the five
upstream format repositories staged at ~/Dev/Research/DiagramKit/{d2,graphviz,plantuml,zenuml,structurizr}.

## Table of Contents

1. [Current DiagramKit Architecture](#1-current-diagramkit-architecture)
2. [MusicToolkit Architecture (the model to mirror)](#2-musictoolkit-architecture)
3. [What DiagramKit Already Has Going for It](#3-what-diagramkit-already-has-going-for-it)
4. [What's Missing: The Four Gaps](#4-whats-missing-the-four-gaps)
5. [Format Analysis](#5-format-analysis)
   - [d2](#51-d2)
   - [graphviz](#52-graphviz)
   - [plantuml](#53-plantuml)
   - [zenuml](#54-zenuml)
   - [structurizr](#55-structurizr)
6. [The Sparse Matrix Problem](#6-the-sparse-matrix-problem)
7. [Recommended Phased Roadmap](#7-recommended-phased-roadmap)
8. [Naming Plan](#8-naming-plan)
9. [Test Corpus Reorganization](#9-test-corpus-reorganization)
10. [Open Questions](#10-open-questions)

---

## 1. Current DiagramKit Architecture

### 1.1 Target Layering

Six SPM targets, strict import direction:

```
DiagramKitCommon (Linux + Apple)
  → DiagramKitModel (Linux + Apple)
    → DiagramKitRenderingCG (Apple only)
    → DiagramKitTestSupport (Linux + Apple)
    → DiagramKitViews (Apple only)
      → DiagramKit (umbrella, public API + re-exports)
```

### 1.2 The Pipeline

**Parser.swift** (22 lines) — stateless enum `MermaidParser`:
```swift
static func parse(_ source: String) throws -> DiagramDocument {
    let decoded = _decodeXMLEntities(source)
    let (processed, frontmatter) = _parseFrontMatterAndStripped(decoded)
    let header = DiagramHeader.detect(from: processed)
    let descriptor = DiagramRegistry.detect(header)
    return try descriptor.parse(processed, frontmatter)
}
```

**DiagramDescriptor** — a struct carrying three closures per diagram family:
- `matches: @Sendable (DiagramHeader) -> Bool` — probe function
- `parse: @Sendable (String, DiagramFrontmatter?) throws -> DiagramDocument`
- `layout: @Sendable (DiagramDocument, LayoutConfig) throws -> PositionedGraph`

**DiagramRegistry** — ordered array of `DiagramDescriptor`, first-match-wins.
28 per-family extension files (`DiagramRegistry+Flowchart.swift` etc.). The
ordered `all` array lives in `DiagramDescriptor.swift`.

**DiagramHeader** — strips frontmatter, extracts first content-bearing line.
Used by `DiagramDescriptor.matches` for routing.

**DiagramPipeline** — stateless enum wrapping parse → layout → render:
- `parse(source) -> DiagramDocument`
- `layout(source/graph) -> PositionedGraph`
- `prepare(source) -> PreparedDiagram` (for CG rendering)
- `renderSVG(source/positioned) -> String`
- `renderASCII(source) -> String`

**DiagramEngine** — public `async throws` facade dispatching through
`_runOnWorker` (8 MB-stack `Thread`, not cooperative pool).

### 1.3 The Model (Types.swift)

- **28 `DiagramType` cases** — thorough coverage, already aware of c4, zenuml
- **28 `DiagramPayload` cases** — typed payloads, no `Any` casting
- **28 `PositionedContent` cases** — typed positioned results
- **`DiagramDocument`** — wraps `DiagramPayload`, has empty constructors
- **`PositionedGraph`** — wraps `DiagramDocument` + `PositionedContent` + dimensions

The model layer is already format-agnostic in its type system. Nothing in
`DiagramPayload`, `PositionedContent`, or `DiagramType` carries Mermaid syntax
knowledge. A d2 parser could populate `DiagramPayload.flowchart(...)` and the
layout/SVG/CG paths would render it unchanged.

### 1.4 The Live Editor (Playground-only)

`LiveEditorStore` lives in `Examples/DiagramPlayground/Models/` — not in the
library. It's `@Observable @MainActor`, owns source/theme/config state, render
lifecycle, export/copy/share actions, history, and URL loading. It is Mermaid-specific
(calls `DiagramEngine` / `DiagramImageRenderer` directly) and does not expose
selection or hit-testing.

---

## 2. MusicToolkit Architecture (the model to mirror)

MusicToolkit nails three things DiagramKit doesn't:

### 2.1 One Frozen Canonical Document

**Score** is the single in-memory model (`final class Score: @unchecked Sendable`).

- Every importer (7 formats) parses into `Score`
- Every exporter and renderer reads from `Score`
- `score.finish(settings:)` freezes the graph — this is the explicit boundary
  that makes `@unchecked Sendable` honest
- The "Importer-finalize exception" allows post-`finish` edits that depend
  on values computed by `finish` itself (e.g., bar `start`, beat `playbackStart`)
- Snapshot pattern: `Score.Snapshot: Codable, Sendable` for serialization

### 2.2 Importer Protocol + Registry

**ScoreImporter** protocol:
```swift
public protocol ScoreImporter: Sendable {
    var name: String { get }
    func supports(data: Data) -> Bool       // probe
    func readScore(from data: Data, settings: Settings) throws -> Score
    var diagnostics: [NotationDiagnostic] { get }  // non-fatal warnings
}
```

**ImporterRegistry** — ordered list of `[any ScoreImporter]`:
```swift
public struct ImporterRegistry: Sendable {
    public let importers: [any ScoreImporter]
    public func adding(_ importer: any ScoreImporter) -> Self { ... }
}
```

**ScoreLoader** — dispatch by probe:
```swift
public enum ScoreLoader {
    public static func loadScore(from data: Data, settings: Settings, registry: ImporterRegistry) throws -> Score {
        for importer in registry.importers where importer.supports(data: data) {
            return try importer.readScore(from: data, settings: settings)
        }
        throw UnsupportedFormatError()
    }
}
```

Probe order is **API contract**, enforced by `ProbeCollisionMatrixTests`.

### 2.3 One Target Per Format

22 SwiftPM targets, one per importer/exporter, with the umbrella
(`MusicToolkit`) re-exporting them:
- `MusicToolkitAlphaTex`, `MusicToolkitGuitarPro`, `MusicToolkitMusicXML`,
  `MusicToolkitMEI`, `MusicToolkitABC`, `MusicToolkitPAE`, `MusicToolkitMidi`,
  `MusicToolkitLilyPondExport`

Adding a format is: add a target, conform to `ScoreImporter`, register it.

### 2.4 Interactivity Primitives

**BoundsLookup** (in `MusicToolkitRendering/Bounds/`):
- Built by the renderer at the end of each render pass
- Read-only after `finish()`
- `selection(at: CGPoint) -> ScoreSelection?` — hit-testing
- `bounds(for: ScoreSelection) -> Bounds?` — reverse lookup
- `notesIntersecting(_: CGRect) -> [NoteBounds]` — marquee selection

**ScoreSelection** (in `MusicToolkitRendering/Canvas/`):
- Value type with stable IDs: `trackIndex`, `staffIndex`, `barIndex`, `beatID`, `noteID`
- Survives re-renders (IDs are model-level, not render-cache-level)

**What it deliberately skips**: no views, no editing UI, no observable state.
It ships the primitives and leaves the editor (Sonography) to consumers.

### 2.5 Exporter Protocol

Symmetric to importers, in `MusicToolkitExport`:
```swift
public protocol ScoreExportError: LocalizedError, Sendable {
    var diagnostics: [NotationDiagnostic] { get }
}
```
Per-format exporters (`MusicXmlExporter`, `AlphaTexExporter`, `LilyPondExporter`, etc.)

---

## 3. What DiagramKit Already Has Going for It

### 3.1 Format-Agnostic Model Layer

`DiagramPayload`, `PositionedContent`, `DiagramType` carry zero Mermaid syntax.
The layout engine (`GraphLayout`) and SVG renderer (`SVGRenderRegistry`) operate
on typed positioned content, not Mermaid source. A d2 parser could populate
`DiagramPayload.flowchart(...)` and the entire downstream pipeline would work
without change.

### 3.2 Clean Pipeline Seams

`DiagramPipeline` is a stateless enum with explicit parse → layout → render
boundaries. Layout and render have zero format awareness — they consume
`DiagramDocument` / `PositionedGraph`, not source strings.

### 3.3 DiagramRegistry Already Is a Dispatch Table

The `DiagramDescriptor` struct is effectively a per-family dispatch record with
`matches` + `parse` + `layout`. It's one abstraction away from a format-agnostic
protocol. The ordered `all` array is already a first-match-wins list.

### 3.4 Existing Format Support That Crosses Boundaries

The model already defines `DiagramType.c4`, `DiagramType.zenuml`, and
`DiagramType.sequenceDiagram` — these map directly to Structurizr, ZenUML,
d2/PlantUML sequence diagrams respectively.

### 3.5 Snapshot Test Infrastructure

`CorpusSnapshotTests` renders 396 diagrams through SVG, image, and ASCII paths.
The corpus is JSON-driven (`test-diagrams.json`). This is a natural foundation
for the multi-format test matrix.

---

## 4. What's Missing: The Four Gaps

### Gap 1: No Importer Protocol or Registry

`MermaidParser.parse(_:)` is hardcoded to Mermaid. There's no protocol that says
"I take a source string and produce a DiagramDocument." No probe-based dispatch.
No diagnostics surface.

### Gap 2: No Exporter Protocol

The only "export" is SVG rendering via `DiagramPipeline.renderSVG`. There's no way
to emit Mermaid source from a `DiagramDocument`, let alone emit d2 or PlantUML.

### Gap 3: No Interactivity Surface

`LiveEditorStore` is playground-only. There's no `BoundsLookup`, no
`DiagramSelection` value type, no hit-testing API, no `bounds(of:)` for cursor
highlighting. The library has zero interactivity primitives.

### Gap 4: Naming Is Mermaid-Coupled

`DiagramEngine`, `DiagramPipeline`, and `DiagramDocument` now use format-neutral
names, but `MermaidParser`, Mermaid-family registry types, and source-specific
helpers remain coupled to Mermaid. Those should become importer-specific once d2
or PlantUML lands.

---

## 5. Format Analysis

### 5.1 d2

**Repository**: ~/Dev/Research/DiagramKit/d2 (Go, Apache 2.0)
**Size**: ~40 Go packages, clean codebase
**Key packages**:
- `d2ast` — AST types (`Map`, `Key`, `Edge`, `KeyPath`, `Array`, etc.), strong node interface
- `d2parser` — recursive-descent parser, clean grammar
- `d2ir` — intermediate representation, maps AST → graph nodes/edges with positions
- `d2compiler` — AST → IR compilation
- `d2exporter` — IR → d2 source (round-trip capable)
- `d2layouts` — ELK-based layout (same engine DiagramKit uses)
- `d2renderers` — SVG export
- `d2oracle` — autoformat / query engine
- `d2format` — formatter

**Grammar**: Clean, well-defined. Key syntax:
- `shape: key` for node shapes (rectangle, cylinder, etc.)
- `A -> B` for edges (arrow types: `->`, `-->`, `<->`)
- `{ }` for nesting/containers
- `|` for Markdown-like table cells
- `style.*` assignments for theming

**Port to Swift feasibility**: High. The AST types (~30 types) map cleanly to
Swift structs/enums. Parser is recursive-descent (~2,000 lines Go → similar Swift).
The `d2ir` types map naturally to `DiagramPayload` cases.

**Diagram type coverage**:
- flowchart: full (nodes, edges, subgraphs, styles)
- sequence: partial (board/scenario/layers as containers, no lifeline semantics natively)
- class: partial (through nested maps and keys)
- ER: full (through shape: sql_table, shape: sql_relationship → `->` edges)
- c4: partial (containers and relationships, no explicit person/system semantics)
- architecture deployment: full (containers and edges)

**Probe signature**: `supports(source:)` keys on:
- Lines containing `: ` (key-value assignment)
- `->` or `-->` or `<->` edge syntax
- `shape:` keyword
- `vars:` / `layers:` / `scenarios:` / `steps:` block markers

### 5.2 graphviz

**Repository**: ~/Dev/Research/DiagramKit/graphviz (C, EPL 2.0)
**Size**: ~350K lines of C, mature codebase
**Key packages**:
- `lib/cgraph` — graph data structure (Agraph_t, Agnode_t, Agedge_t)
- `lib/dotgen` — DOT parser + hierarchical layout (dot algorithm)
- `lib/neatogen` — spring-model layout (neato/fdp)
- `lib/circogen` — circular layout (circo)
- `lib/sfdpgen` — scalable force-directed layout
- `lib/pack` — component packing
- `lib/gvc` — Graphviz context (orchestrator)

**Grammar (DOT)**: Published EBNF.
```
digraph G {
    A -> B [label="edge"];
    subgraph cluster_0 { ... }
    node [shape=box, style=filled];
}
```

**Port to Swift feasibility**: Medium. The DOT parser is ~5,000 lines of C in
`lib/dotgen/dotinit.c` + supporting files. A Swift port of just the parser
(not the layout engines, since DiagramKit already has ELK) would be ~2,000-3,000
lines. The graph structure maps to `DiagramDocument` + `ParsedGraphModel`.

**Diagram type coverage**:
- flowchart: full (the primary use case)
- The DOT language is fundamentally a graph language — no native sequence,
  class, ER, gantt, etc. constructs

**Probe signature**: `supports(source:)` keys on:
- `digraph` or `graph` keyword at start of meaningful content
- `{` following the header
- `->` or `--` edge syntax within braces

### 5.3 plantuml

**Repository**: ~/Dev/Research/DiagramKit/plantuml (Java, GPLv2+)
**Size**: Massive — 100+ Java source directories, decades of accumulation
**Key source**: `src/main/java/net/sourceforge/plantuml/`
**Key diagram families**:
- Sequence (`@startuml` with `->`, `-->`, `->>` arrows, actors, notes, boxes)
- Class (UML class diagrams with `+`, `-`, `#` visibility markers)
- Activity / State
- Component
- Mindmap (`@startmindmap`, `*` indentation)
- Gantt (`@startgantt`, task syntax)
- C4 (`@startuml` with `!include <C4/C4_Container>`)

**Grammar**: No clean grammar. PlantUML evolved organically over 15+ years.
No published EBNF. The parser is a collection of regex-based state machines
spread across hundreds of files.

**Port to Swift feasibility**: Low for a full port. Practical approach:
- Cover the major diagram families (sequence, class, state, mindmap, gantt, c4)
- Emit `DiagramDiagnostic` for unsupported constructs
- Leverage the existing Java codebase as a reference implementation, not a
  line-for-line port

**Diagram type coverage**:
- sequence: full (the primary use case)
- class: full
- state: full
- activity: full (maps to flowchart)
- mindmap: full
- gantt: full
- c4: full (via C4 library includes)
- flowchart: partial (activity diagrams map to flowcharts)

**Probe signature**: `supports(source:)` keys on:
- `@startuml` or `@startxxx` at start of meaningful content
- `@enduml` at end
- Can also detect by family-specific keywords within `@startuml` blocks

### 5.4 zenuml

**Repository**: ~/Dev/Research/DiagramKit/zenuml (TypeScript/Bun, MIT)
**Size**: Moderate — ANTLR-based TypeScript codebase
**Key structure**:
- `antlr/` — ANTLR4 grammar files (ZenUML.g4)
- `src/` — TypeScript source, parser/compiler/renderer
- `packages/mermaid-zenuml/` — the Mermaid integration

**Grammar**: Formal ANTLR grammar available. Cleanest of the five formats.
Sequence diagram only (`participant`, `->`, `async`, `sync`, etc.).

**Port to Swift feasibility**: High. ANTLR grammar can be used as reference
spec. The parse tree maps directly to `SequenceDiagram` model.

**Diagram type coverage**:
- sequence: full (the only diagram type)
- Everything else: not supported

**Probe signature**: `supports(source:)` keys on:
- `zenuml` keyword in the diagram header
- Already in `DiagramType.zenuml` and `DiagramRegistry+ZenUML.swift`

### 5.5 structurizr

**Repository**: ~/Dev/Research/DiagramKit/structurizr (Java, Apache 2.0)
**Size**: Moderate — ~24 Maven modules
**Key module**: `structurizr-dsl` — the DSL parser
**DSL structure**:
- `workspace { ... }` top-level container
- `model { ... }` — persons, softwareSystems, containers, components
- `views { ... }` — systemContext, container, component, deployment views
- `->` for relationships
- `!include`, `!docs`, `!adrs`, `!decisions` directives
- `structurizr-dsl/src/main/java/com/structurizr/dsl/` — ~130 parser files

**Grammar**: Well-structured recursive-descent parser (~130 Java source files).
Strong separation of concerns: `WorkspaceParser`, `ModelParser`, `ViewParser`,
`RelationshipParser`, etc. Tokenizer + DSL context stack.

**Port to Swift feasibility**: Medium. The DSL is well-structured. A Swift port
would focus on:
- `ModelDslContext` (person, softwareSystem, container, component, deploymentNode)
- `ViewsDslContext` (systemContext, container, component, deployment, dynamic)
- `RelationshipParser` (explicit + implicit relationships)
- Skip `!components`, `!plugin`, `!script` directives (out of scope)
- Skip healthCheck, autoLayout, terminology (can be diagnostics)

**Diagram type coverage**:
- c4: full (the only diagram family it supports natively)
- Everything else: not supported (but c4 model can be exported as PlantUML/Mermaid
  via its own exporters)

**Probe signature**: `supports(source:)` keys on:
- `workspace` keyword at start of meaningful content
- `{` following `workspace`
- `model {`, `views {` within workspace body

---

## 6. The Sparse Matrix Problem

Not every format supports every diagram type. This is an architectural constraint,
not a bug.

| Diagram Type    | Mermaid | d2  | graphviz | plantuml | structurizr | zenuml |
|-----------------|---------|-----|----------|----------|-------------|--------|
| flowchart       | ✅      | ✅  | ✅       | ✅(act)  | ❌          | ❌     |
| sequence        | ✅      | ⚠   | ❌       | ✅       | ❌          | ✅     |
| class           | ✅      | ⚠   | ❌       | ✅       | ❌          | ❌     |
| ER              | ✅      | ✅  | ❌       | ❌       | ❌          | ❌     |
| gantt           | ✅      | ❌  | ❌       | ✅       | ❌          | ❌     |
| mindmap         | ✅      | ❌  | ❌       | ✅       | ❌          | ❌     |
| state           | ✅      | ❌  | ❌       | ✅       | ❌          | ❌     |
| c4              | ✅      | ⚠   | ❌       | ✅       | ✅          | ❌     |
| architecture    | ✅      | ✅  | ❌       | ✅       | ⚠(deploy)   | ❌     |
| pie/xyChart/... | ✅      | ❌  | ❌       | ❌       | ❌          | ❌     |

⚠ = partial support

**Design principle**: `supportedDiagramTypes: Set<DiagramType>` makes the
constraint explicit. `DiagramDiagnostic` carries "I dropped the swimlane
styling" warnings on import. Never silently no-op.

**For import-then-export**: Mermaid C4 → Structurizr is meaningful.
Mermaid Gantt → Structurizr is not. Surface this as a diagnostic.

---

## 7. Recommended Phased Roadmap

### Phase 0 — Carve the Seams (no behavior change)

One mechanical commit: rename Mermaid → Diagram.

| Before                        | After                              |
|-------------------------------|------------------------------------|
| `MermaidRenderer`             | `DiagramEngine`                    |
| `MermaidPipeline`             | `DiagramPipeline`                  |
| `MermaidGraph`                | `DiagramDocument`                  |
| `MermaidView`                 | `DiagramView`                      |
| `MermaidParser`               | `DiagramParser` / `MermaidImporter`|
| `MermaidImageRenderer`        | `DiagramImageRenderer`             |
| `BeautifulMermaidError`       | `DiagramError`                     |
| `MermaidStructuralError`      | `DiagramStructuralError`           |
| `MermaidWorkerThread`         | `DiagramWorkerThread`              |
| `MermaidPreparation`          | `DiagramPreparation`               |
| `MermaidSourceNormalizer`     | `DiagramSourceNormalizer`          |
| `MermaidPreparerBootstrap`    | `DiagramPreparerBootstrap`         |

Keep `@available(..., renamed:)` Mermaid-prefixed typealiases for one release
cycle so the playground and downstream consumers don't break.

### Phase 1 — Importer Protocol + Registry

Mirror `ScoreImporter`:

```swift
public protocol DiagramSourceImporter: Sendable {
    var name: String { get }
    var supportedDiagramTypes: Set<DiagramType> { get }
    func supports(source: String) -> Bool          // text-only probe
    func parse(_ source: String,
               frontmatter: DiagramFrontmatter?) throws -> DiagramDocument
    var diagnostics: [DiagramDiagnostic] { get }
}

public struct ImporterRegistry: Sendable {
    public let importers: [any DiagramSourceImporter]
    public func adding(_ importer: any DiagramSourceImporter) -> Self { ... }
}

public enum DiagramLoader {
    public static func parse(
        _ source: String,
        registry: ImporterRegistry
    ) throws -> DiagramDocument
}
```

**MermaidImporter** becomes the first concrete conformer — same parsing code,
new home. Its `supports(source:)` keys on the existing `DiagramHeader.detect`
chain.

Add `ProbeCollisionMatrixTests` so probe order is contractual. The d2 probe
(`->` / `-->`) could false-match on Mermaid flowchart source — order matters.

Default registry: `ImporterRegistry.all` with Mermaid first (current behavior
preserved), then d2, then PlantUML, etc.

### Phase 2 — Add the Four New Formats, One Target Each

Ordered by ROI and corpus availability:

#### 2a. DiagramKitD2

- **Target**: `DiagramKitD2` (new SPM target)
- **Dependencies**: `DiagramKitModel`, `DiagramKitImport` (new target holding
  the protocol/registry)
- **Probe**: d2 blocks, `: ` assignment, `->`/`-->`/`<->` edge syntax,
  `shape:` keyword
- **Parser**: Port from `d2ast` → `d2parser` → `d2ir` in Go (~3,000 lines Go →
  ~4,000 lines Swift)
- **Coverage**: flowchart, sequence (partial), class (partial), ER, c4 (partial),
  architecture

#### 2b. DiagramKitGraphviz

- **Target**: `DiagramKitGraphviz`
- **Probe**: `digraph`/`graph` headers
- **Parser**: Port DOT parser from graphviz `lib/dotgen/` (~2,000 lines C →
  ~3,000 lines Swift)
- **Coverage**: flowchart only (DOT's native domain)

#### 2c. DiagramKitPlantUML

- **Target**: `DiagramKitPlantUML`
- **Probe**: `@startuml`/`@startxxx`
- **Parser**: Cover the major families — sequence, class, state, mindmap, gantt,
  c4. Emit diagnostics for the rest.
- **Coverage**: sequence, class, state, mindmap, gantt, c4, flowchart (via
  activity diagrams)

#### 2d. DiagramKitStructurizr

- **Target**: `DiagramKitStructurizr`
- **Probe**: `workspace {`
- **Parser**: Port from `structurizr-dsl` Java parser (~5,000 lines Java →
  ~6,000 lines Swift)
- **Coverage**: c4 only

**ZenUML** is already partially integrated (exists as `DiagramType.zenuml` and
`DiagramRegistry+ZenUML.swift`). A native `DiagramKitZenUML` target can follow
later — the Mermaid ZenUML integration already parses ZenUML into
`ZenUMLDiagram`, so no immediate work needed.

### Phase 3 — Exporter Protocol

Symmetric to importers:

```swift
public protocol DiagramExporter: Sendable {
    var name: String { get }
    var supportedDiagramTypes: Set<DiagramType> { get }
    func export(_ document: DiagramDocument) throws -> DiagramExportResult
}

public struct DiagramExportResult: Sendable {
    public let source: String
    public let diagnostics: [DiagramDiagnostic]
}
```

First three exporters to ship:
1. **MermaidExporter** (highest value — enables source-pane sync in editor)
2. **d2Exporter** (clean grammar, high round-trip fidelity)
3. **PlantUMLExporter** (covers ~80% of round-trip cases)

The conversion matrix is sparse. Mermaid C4 → Structurizr is meaningful;
Mermaid Gantt → Structurizr produces a diagnostic, not a silent no-op.

### Phase 4 — Interactivity Primitives

Mirror `BoundsLookup` and `ScoreSelection`:

#### 4a. Read-only Primitives (in rendering layer)

- Extend `PositionedContent` cases with **stable IDs** and **CGRect bounds** for
  every node, edge, and group
- Add `DiagramBoundsLookup` attached to `PreparedDiagram`:
  - `prepared.selection(at: CGPoint) -> DiagramSelection?`
  - `prepared.bounds(of: DiagramSelection) -> CGRect?`
- `DiagramSelection` value type with stable IDs (survives re-layouts):
  ```swift
  public struct DiagramSelection: Equatable, Hashable, Sendable {
      public var diagramType: DiagramType
      public var nodeID: String?
      public var edgeID: String?
      public var groupID: String?
      // ... stable IDs from the model layer
  }
  ```

This alone unlocks click-to-highlight, tooltips, hover, deep-linking —
without any editing.

#### 4b. Editing Layer (new optional target `DiagramKitInteractive`)

- `@Observable DiagramEditor` owning a `DiagramDocument`, undo stack, and
  selection state
- Small set of typed mutations: `insertNode`, `deleteNode`, `setEdgeLabel`, etc.
- Two-way source binding via re-emit through the exporter (source pane stays in sync)
- Ship just the model — not a turnkey `DiagramEditorView`. Let consumers
  build their own editor UI (matching MusicToolkit's philosophy)

### Phase 5 — Test Corpus Reorganization

Rekey `test-diagrams.json` so each entry can carry multiple source formats:

```json
{
  "id": "flow-1-simple",
  "category": "flowchart",
  "sources": {
    "mermaid": "graph TD\nA-->B",
    "d2": "A -> B",
    "graphviz": "digraph { A -> B }"
  }
}
```

This enables:
- `CorpusSnapshotTests` parametrized over `(format × diagram)`
- Import-then-export round-trip tests: parse d2 source, export to Mermaid,
  diff against canonical Mermaid source
- Sparse matrix coverage tests: assert `supportedDiagramTypes` matches actual
  parseable content

---

## 8. Naming Plan

The target layout after Phase 0-2:

```
Sources/
├── DiagramKitCommon          (no rename)
├── DiagramKitModel           (no rename)
├── DiagramKitImport          (NEW — protocol/registry/DiagramLoader)
├── DiagramKitMermaid         (was: Mermaid parser code in DiagramKit)
├── DiagramKitD2              (NEW)
├── DiagramKitGraphviz        (NEW)
├── DiagramKitPlantUML        (NEW)
├── DiagramKitStructurizr     (NEW)
├── DiagramKitZenUML          (NEW — extract from Mermaid ZenUML integration)
├── DiagramKitExport          (NEW — export protocol + per-format exporters)
├── DiagramKitRenderingCG     (no rename)
├── DiagramKitViews           (no rename)
├── DiagramKitInteractive     (NEW — Phase 4b)
├── DiagramKitTestSupport     (no rename)
└── DiagramKit                (umbrella, re-exports all format targets)
```

The existing per-family files in `Sources/DiagramKit/` (e.g.,
`DiagramRegistry+Flowchart.swift`) move into `Sources/DiagramKitMermaid/`.

---

## 9. Test Corpus Reorganization

Current state: `Examples/DiagramPlayground/Resources/test-diagrams.json` —
396 entries, Mermaid-only. Each entry has an `id`, `category`, and `source`
(Mermaid string). `CorpusSnapshotTests` renders every entry through SVG,
image, and ASCII.

After reorganization:
- Each entry gains a `sources` map: `{ "mermaid": "...", "d2": "...", ... }`
- `CorpusSnapshotTests` parametrizes over `(format, diagramId)`
- Round-trip tests: `parse(formatA) → export(formatB) → parse(formatB) →
  export(formatB)` — the second export should match the first (for lossless
  round-trips)
- Coverage matrix test: for each (format, diagramType) pair, assert that the
  importer's `supportedDiagramTypes` matches actual behavior

---

## 10. Open Questions

1. **Where does the `DiagramDocument.finish()` boundary go?** MusicToolkit's
   `Score.finish(settings:)` freezes the graph. DiagramKit's graph is already
   value-typed (`struct DiagramDocument`, `struct PositionedGraph`), so the freeze
   is implicit in construction. Does interactivity (Phase 4) require a mutable
   post-parse phase?

2. **Thread model for importers.** MusicToolkit importers are `Sendable` but
   not `@MainActor`. DiagramKit's `DiagramEngine` spawns an 8 MB-stack `Thread`
   per call. Should format importers follow the same pattern, or can they run on
   the cooperative pool? Parsing is typically compute-bound, not stack-deep.

3. **How much UI should DiagramKit own?** MusicToolkit ships zero views,
   leaving UI to consumers. DiagramKit now has an Apple-only `DiagramKitViews`
   target for display wrappers. Should the new `DiagramKitInteractive` follow a
   "model/primitives only" philosophy, or should it grow turnkey editor UI?

4. **PlantUML scope.** Full PlantUML support is impractical (decades of
   accumulated syntax). Reasonable target: sequence + class + state + mindmap +
   gantt + c4 — covering ~80% of PlantUML usage. Unsupported constructs get
   `DiagramDiagnostic` entries.

5. **Graphviz as a subset.** Graphviz DOT is fundamentally a flowchart/graph
   language. Should the importer map to `DiagramPayload.flowchart(...)` and
   stop there, rather than trying to force-fit other diagram types?

6. **ZenUML integration priority.** ZenUML is already partially integrated via
   Mermaid's ZenUML support. A native `DiagramKitZenUML` target is valuable
   but lower priority than d2/PlantUML — the Mermaid path already works.

7. **`DiagramDocument` naming.** `MermaidGraph` → `DiagramDocument` follows
   MusicToolkit's `Score` pattern (a "document" is a frozen parsed model).
   Alternative: `Diagram` (shorter but ambiguous with `DiagramType`).

8. **`@unchecked Sendable` policy.** DiagramKit already follows the green/yellow/red
   policy from `CONTRIBUTING.md`. Phase 4's `DiagramEditor` (with undo stack) will
   need careful concurrency annotation — likely `@MainActor` for the mutable
   part, `Sendable` for the frozen `DiagramDocument`.

---

*This document was prepared by analyzing the current codebase at
~/Dev/Research/DiagramKit/mermaid-swift, comparing against
~/Workspace/packages/MusicToolkit, and surveying the five upstream
format repositories staged at ~/Dev/Research/DiagramKit/{d2,graphviz,
plantuml,zenuml,structurizr}.*
