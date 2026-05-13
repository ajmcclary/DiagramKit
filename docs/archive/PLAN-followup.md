# DiagramKit Remaining-Work Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the three open work streams flagged in
[PHASES.md](PHASES.md) — DOT exporter, PlantUML family slices beyond
sequence, and broader ASCII renderer coverage — so DiagramKit reaches
feature parity across importers, exporters, and renderers for every
diagram family in the corpus.

**Architecture:** Each phase is a PR-sized slice that mirrors an
established pattern already in the repo. DOT exports mirror the
existing `D2Exporter`. PlantUML family slices mirror the existing
sequence slice (probe → parser → AST → mapper → importer dispatch +
exporter). ASCII renderers mirror the existing `renderSequenceAscii` /
`renderClassAscii` / `renderErAscii` / `renderXYChartAscii` pattern
under `Sources/DiagramKitModel/src_ascii_*` with dispatch wiring in
`Sources/DiagramKit/src_ascii_index.swift`.

**Tech Stack:** Swift 6.3, SwiftPM, XCTest + swift-testing,
SnapshotTesting, Bash governance scripts, Docker/Podman for Linux
checks, GitHub Actions for CI.

---

## Ground Rules

- Preserve the worker-thread invariant: no thread pool, no cooperative
  pool, no `Task.detached` for `DiagramEngine._runOnWorker` or
  `DiagramWorkerThread.run`.
- Preserve snapshot determinism:
  `DiagramFontRegistry.registerBundledFontsIfNeeded()` remains first
  in every pipeline method. `DIAGRAMKIT_GANTT_TODAY` is pinned by
  `CorpusSnapshotTests.loadDiagrams()`; do not regress that.
- Preserve parser dispatch order: narrower `hasPrefix` /
  `isPlantUML*Body` probes precede broader fallbacks. Update the
  existing chain in `PlantUMLImporter.parse` rather than adding a new
  one.
- Preserve type safety: pattern-match
  `DiagramDocument.payload`, `typedPayload`, and
  `PositionedGraph.content`; do not cast payloads through `Any`.
- Preserve color semantics: do not compare or round-trip colors
  through `hexString`; use the `BMColor.cssColorString` helper or
  RGBA components.
- Record SVG/image/ASCII snapshots only for intentional changes.
  Use `SNAPSHOT_DIAGRAM_IDS` chunks for corpus recording.
- Files over 500 lines warn; files over 1000 lines fail
  `Scripts/check-file-sizes.sh`. Split renderers / mappers when they
  approach the warning band.
- Tests use swift-testing (`@Suite`, `@Test`, `#expect`) except where
  XCTest is already established for a suite.

## Phase Overview

| Phase | Scope | Open work item | Verification |
| --- | --- | --- | --- |
| 0 | Baseline + tracking | All | Required |
| 1 | DOT exporter | PHASES.md "DOT exporter" | Required |
| 2 | PlantUML class slice (importer + exporter) | PHASES.md "PlantUML family slices" | Required |
| 3 | PlantUML state/activity slice | PHASES.md "PlantUML family slices" | Required |
| 4 | PlantUML mindmap slice | PHASES.md "PlantUML family slices" | Required |
| 5 | PlantUML gantt slice | PHASES.md "PlantUML family slices" | Required |
| 6 | PlantUML C4 slice | PHASES.md "PlantUML family slices" | Required |
| 7 | ASCII renderer framework + Pie chart | PHASES.md "ASCII renderer coverage" | Required |
| 8 | ASCII tree-shaped families (mindmap, treeView, ishikawa) | same | Required |
| 9 | ASCII time-based families (gantt, gitGraph, timeline, journey) | same | Required |
| 10 | ASCII box-cluster families (block, c4, architecture, eventModeling, wardley, kanban) | same | Required |
| 11 | ASCII specialty chart families (sankey, radar, treemap, venn, quadrantChart, packet, requirement, zenuml) | same | Required |
| 12 | Release verification | All | Required before release tag |

## File-Layout Decisions

- **DOT exporter:** lives next to `GraphvizImporter` in
  `Sources/DiagramKitGraphviz/`. Top-level entry point in
  `DOTExporter.swift`; flowchart emission helpers in
  `DOTFlowchartExport.swift`. Mirrors the
  `Sources/DiagramKitD2/D2Exporter.swift` /
  `D2FlowchartExport` split.
- **PlantUML family slices:** each slice gets its own subdirectory
  under `Sources/DiagramKitPlantUML/` (e.g. `Class/`, `State/`,
  `Mindmap/`, `Gantt/`, `C4/`). Inside the directory: `*AST.swift`,
  `*Parser.swift`, `*Mapper.swift`, `*Probe.swift`. The matching
  exporter file goes under `Sources/DiagramKitPlantUML/Exporter/`
  (e.g. `PlantUMLClassExporter.swift`).
- **ASCII renderers:** family-specific renderers live in
  `Sources/DiagramKitModel/src_ascii_<family>.swift`. The dispatch
  switch in `Sources/DiagramKit/src_ascii_index.swift` routes by
  `DiagramRegistry.detect` result. Helpers reused across families
  (canvas, edge routing, multiline, ANSI) stay in their existing
  `src_ascii_*.swift` modules — do not duplicate.

---

## Phase 0 — Baseline and Tracking

**Outcome:** Clean baseline, branch hygiene, environment skips
recorded before any new work lands.

**Files:**
- Read only: `PHASES.md`, `BASELINES.md`, `CLAUDE.md`,
  `ARCHITECTURE.md`, `docs/archive/PLAN.md`.

- [ ] Confirm worktree is clean.

```bash
git status --short
```

Expected: no output.

- [ ] Confirm package dump.

```bash
swift package dump-package > /dev/null
```

Expected: exits 0.

- [ ] Confirm tests build.

```bash
swift build --build-tests
```

Expected: exits 0.

- [ ] Record environmental skips before starting:
  - Docker/Podman unavailable → record `linux-check.sh` skipped by
    environment in `BASELINES.md` if it changes from current state.
  - Missing Xcode platform runtimes → record platform build skipped
    by environment.

- [ ] Keep one commit per phase, or one commit per task if a phase
  becomes large. Use a conventional-style prefix: `feat:`, `fix:`,
  `test:`, `docs:`, `refactor:`.

---

## Phase 1 — DOT Exporter (DiagramKitGraphviz)

**Outcome:** `DiagramExportLoader.export(to: .graphviz, …)` produces
valid DOT source for `.flowchart` documents instead of returning a
`.unsupported` diagnostic. `DOTExporter` is registered in the default
export registry alongside `MermaidExporter`, `D2Exporter`,
`StructurizrExporter`, and `PlantUMLExporter`.

**Files:**
- Create: `Sources/DiagramKitGraphviz/DOTExporter.swift`
- Create: `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift`
- Modify: `Sources/DiagramKit/DiagramPipeline.swift`
  (defaultExportRegistry registration around line 52).
- Modify: `Package.swift` — ensure `DiagramKitGraphviz` is a target
  dependency for the umbrella `DiagramKit` product (it already is via
  the importer; confirm).
- Create: `Tests/DiagramKitTests/Export/DOTExporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/ExportMatrixTests.swift` —
  add `.graphviz` to the supported-format coverage.
- Modify: `Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift`
  — replace the current "graphviz returns unsupported" test with a
  positive round-trip test.

### Task 1.1 — Write the DOT exporter identity test

- [ ] Create `Tests/DiagramKitTests/Export/DOTExporterTests.swift`
  with the identity assertion.

```swift
import Testing
import DiagramKitModel
import DiagramKitGraphviz

@Suite struct DOTExporterTests {

    @Test("DOT exporter has correct name and format ID")
    func identity() {
        let exporter = DOTExporter()
        #expect(exporter.name == "Graphviz")
        #expect(exporter.formatID == .graphviz)
        #expect(exporter.supportedDiagramTypes.contains(.flowchart))
        #expect(!exporter.supportedDiagramTypes.contains(.sequenceDiagram))
    }
}
```

- [ ] Run it to confirm it fails.

```bash
swift test --filter DOTExporterTests/identity
```

Expected: FAIL with "cannot find 'DOTExporter' in scope".

### Task 1.2 — Implement `DOTExporter` skeleton

- [ ] Create `Sources/DiagramKitGraphviz/DOTExporter.swift`.

```swift
import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

/// Graphviz DOT source-format exporter.
///
/// Emits valid DOT source for flowchart diagrams from
/// `DiagramDocument`. Mirrors the `GraphvizImporter` coverage
/// (flowchart only) and the `D2Exporter` shape.
public struct DOTExporter: DiagramExporter {
    public let name = "Graphviz"
    public let formatID = DiagramFormatID.graphviz
    public let supportedDiagramTypes: Set<DiagramType> = [.flowchart]

    public init() {}

    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .flowchart(let model):
            return try DOTFlowchartExport.emit(model, title: document.title)
        default:
            return DiagramExportResult(
                source: "",
                diagnostics: [
                    DiagramDiagnostic(
                        severity: .unsupported,
                        message: "DOT export for '\(document.type.rawValue)' is not supported"
                    )
                ]
            )
        }
    }
}
```

- [ ] Re-run the identity test.

```bash
swift test --filter DOTExporterTests/identity
```

Expected: FAIL on `DOTFlowchartExport` not in scope.

### Task 1.3 — Implement the flowchart emission helper

- [ ] Create `Sources/DiagramKitGraphviz/DOTFlowchartExport.swift`.

```swift
import Foundation
import DiagramKitModel
import DiagramKitImport
import DiagramKitExport

enum DOTFlowchartExport {

    static func emit(_ model: ParsedGraphModel, title: String? = nil) throws -> DiagramExportResult {
        var lines: [String] = []
        let diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")

        if let title, !title.isEmpty {
            lines.append("  labelloc=\"t\";")
            lines.append("  label=\(quoted(singleLineTitle(title)));")
        }

        switch model.direction {
        case .LR, .RL:
            lines.append("  rankdir=LR;")
        default:
            lines.append("  rankdir=TB;")
        }

        for (nodeId, node) in model.nodesInOrder {
            let sanitizedId = sanitizeDOTID(nodeId)
            let shape = dotShape(for: node.shape)
            let label = node.label.isEmpty ? nodeId : node.label
            lines.append("  \(sanitizedId) [label=\(quoted(label)), shape=\(shape)];")
        }

        for edge in model.edges {
            let src = sanitizeDOTID(edge.source)
            let tgt = sanitizeDOTID(edge.target)
            if let label = edge.label, !label.isEmpty {
                lines.append("  \(src) -> \(tgt) [label=\(quoted(label))];")
            } else {
                lines.append("  \(src) -> \(tgt);")
            }
        }

        lines.append("}")

        return DiagramExportResult(
            source: lines.joined(separator: "\n"),
            diagnostics: diagnostics
        )
    }

    private static func quoted(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return "\"\(escaped)\""
    }

    private static func sanitizeDOTID(_ id: String) -> String {
        // DOT bareword IDs match [A-Za-z\200-\377_][0-9A-Za-z\200-\377_]*.
        // Anything else gets quoted.
        let allowedFirst = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let allowedTail = allowedFirst.union(.decimalDigits)
        guard let first = id.unicodeScalars.first,
              allowedFirst.contains(first),
              id.unicodeScalars.dropFirst().allSatisfy({ allowedTail.contains($0) }) else {
            return quoted(id)
        }
        return id
    }

    private static func singleLineTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "\n", with: " ")
             .replacingOccurrences(of: "\r", with: " ")
    }

    private static func dotShape(for shape: original_src_types.MermaidNodeShape) -> String {
        switch shape {
        case .rectangle, .roundedRectangle: return "box"
        case .round, .stadium: return "ellipse"
        case .circle: return "circle"
        case .diamond: return "diamond"
        case .hexagon: return "hexagon"
        case .parallelogram, .parallelogramAlt: return "parallelogram"
        case .trapezoid, .trapezoidAlt: return "trapezium"
        case .cylinder: return "cylinder"
        case .subroutine: return "box3d"
        default: return "box"
        }
    }
}
```

- [ ] Re-run the identity test.

```bash
swift test --filter DOTExporterTests/identity
```

Expected: PASS.

### Task 1.4 — Add flowchart-emission tests

- [ ] Append to `DOTExporterTests.swift`.

```swift
    @Test("DOT flowchart export produces valid DOT source")
    func flowchartExport() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Start", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "End", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "go", style: .solid)
            ]
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try DOTExporter().export(doc)

        #expect(result.source.contains("digraph G {"))
        #expect(result.source.contains("rankdir=LR;"))
        #expect(result.source.contains("A [label=\"Start\""))
        #expect(result.source.contains("A -> B [label=\"go\"];"))
        #expect(result.source.hasSuffix("}"))
    }

    @Test("DOT exporter quotes non-bareword identifiers")
    func quotesNonBarewordIds() throws {
        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: [
                (id: "node 1", node: original_src_types.MermaidNode(id: "node 1", label: "One", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "Two", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "node 1", target: "B", label: nil, style: .solid)
            ]
        )
        let result = try DOTExporter().export(DiagramDocument(payload: .flowchart(graph)))

        #expect(result.source.contains("\"node 1\" [label=\"One\""))
        #expect(result.source.contains("\"node 1\" -> B;"))
    }

    @Test("DOT export unsupported type returns diagnostic")
    func unsupportedType() throws {
        let doc = DiagramDocument(type: .sequenceDiagram)
        let result = try DOTExporter().export(doc)
        #expect(result.source.isEmpty)
        #expect(result.diagnostics.contains { $0.severity == .unsupported })
    }
```

- [ ] Run the suite.

```bash
swift test --filter DOTExporterTests
```

Expected: PASS for all four tests.

### Task 1.5 — Round-trip test through `GraphvizImporter`

- [ ] Append a round-trip test that re-parses DOT output through
  `GraphvizImporter` and confirms node IDs and edges survive.

```swift
    @Test("DOT export round-trips through GraphvizImporter")
    func roundTripsThroughImporter() throws {
        let graph = ParsedGraphModel(
            direction: .LR,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "Start", shape: .rectangle)),
                (id: "B", node: original_src_types.MermaidNode(id: "B", label: "End", shape: .rectangle))
            ],
            edges: [
                original_src_types.MermaidEdge(source: "A", target: "B", label: "go", style: .solid)
            ]
        )
        let result = try DOTExporter().export(DiagramDocument(payload: .flowchart(graph)))

        let reparsed = try GraphvizImporter().parse(result.source).document
        guard case .flowchart(let reparsedGraph) = reparsed.payload else {
            Issue.record("Expected flowchart payload")
            return
        }
        #expect(reparsedGraph.nodesInOrder.map(\.id) == ["A", "B"])
        #expect(reparsedGraph.edges.count == 1)
        #expect(reparsedGraph.edges.first?.source == "A")
        #expect(reparsedGraph.edges.first?.target == "B")
        #expect(reparsedGraph.edges.first?.label == "go")
    }
```

- [ ] Run.

```bash
swift test --filter DOTExporterTests/roundTripsThroughImporter
```

Expected: PASS.

### Task 1.6 — Register `DOTExporter` in `DiagramPipeline.defaultExportRegistry`

- [ ] Modify `Sources/DiagramKit/DiagramPipeline.swift` around line 52.
  Add `DOTExporter` registration after `D2Exporter`. The file already
  imports `DiagramKitGraphviz` via re-exports, but confirm by
  checking `ReExports.swift`.

```swift
    public static let defaultExportRegistry: ExporterRegistry = {
        var registry = ExporterRegistry.empty
            .registering(MermaidExporter())
        registry = registry.registering(D2Exporter())
        registry = registry.registering(DOTExporter())
        registry = registry.registering(StructurizrExporter())
        registry = registry.registering(PlantUMLExporter())
        return registry
    }()
```

- [ ] If `DOTExporter` is not visible from the umbrella module, add
  `import DiagramKitGraphviz` at the top of `DiagramPipeline.swift`
  next to the other format-target imports.

### Task 1.7 — Update `DiagramExportLoader` test for graphviz

- [ ] Open `Tests/DiagramKitTests/Export/DiagramExportLoaderTests.swift`,
  locate the test that currently asserts a `.unsupported` diagnostic
  for `.graphviz`, and rewrite it as a positive case.

```swift
    @Test("DiagramExportLoader produces DOT source for graphviz format")
    func graphvizExportSucceeds() throws {
        let graph = ParsedGraphModel(
            direction: .TB,
            nodesInOrder: [
                (id: "A", node: original_src_types.MermaidNode(id: "A", label: "A", shape: .rectangle))
            ],
            edges: []
        )
        let doc = DiagramDocument(payload: .flowchart(graph))
        let result = try DiagramExportLoader.export(
            doc,
            to: .graphviz,
            registry: DiagramPipeline.defaultExportRegistry
        )
        #expect(result.source.contains("digraph G {"))
        #expect(result.diagnostics.allSatisfy { $0.severity != .unsupported })
    }
```

### Task 1.8 — Extend `ExportMatrixTests` coverage

- [ ] Open
  `Tests/DiagramKitTests/Export/ExportMatrixTests.swift` and add
  `.graphviz` to whatever supported-format list it iterates over.
  Confirm the matrix asserts non-empty source for flowchart payloads
  across `.mermaid`, `.d2`, `.graphviz` and `.unsupported` diagnostic
  for non-flowchart payloads.

### Task 1.9 — Update `PHASES.md` and `BASELINES.md`

- [ ] In `PHASES.md`, remove the "DOT exporter" bullet from
  Active work. Note the closing commit in `BASELINES.md` under a new
  "Post-remediation feature work" subsection.

### Phase 1 Verification

- [ ] `swift test --filter DOTExporterTests`
- [ ] `swift test --filter DiagramExportLoaderTests`
- [ ] `swift test --filter ExportMatrixTests`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(graphviz): add DOTExporter for flowchart documents`

---

## Phase 2 — PlantUML Class Slice

**Outcome:** PlantUML class diagrams parse into
`DiagramPayload.classDiagram` and serialize back through a new
`PlantUMLClassExport`. `PlantUMLImporter.parse` routes class bodies
to the new parser; `PlantUMLExporter.supportedDiagramTypes` includes
`.classDiagram`.

**Files:**
- Create: `Sources/DiagramKitPlantUML/Class/PlantUMLClassAST.swift`
- Create: `Sources/DiagramKitPlantUML/Class/PlantUMLClassParser.swift`
- Create: `Sources/DiagramKitPlantUML/Class/PlantUMLClassMapper.swift`
- Create: `Sources/DiagramKitPlantUML/Exporter/PlantUMLClassExporter.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLFamilyProbe.swift` — the
  `isPlantUMLClassBody` probe already exists; confirm coverage and
  add tests if missing.
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
- Create: `Tests/DiagramKitTests/PlantUMLClassImporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json` —
  add 2–3 PlantUML class corpus entries with `expectedImporters`.

### Task 2.1 — AST and parser scaffolding

- [ ] Read `Sources/DiagramKitPlantUML/Sequence/PlantUMLSequenceAST.swift`
  for the AST shape and split conventions.
- [ ] Create `Sources/DiagramKitPlantUML/Class/PlantUMLClassAST.swift`:

```swift
import Foundation

public struct PlantUMLClassAST: Sendable {
    public var classes: [PlantUMLClassDecl]
    public var relationships: [PlantUMLClassRelationship]
    public var notes: [PlantUMLClassNote]
}

public struct PlantUMLClassDecl: Sendable {
    public enum Kind: String, Sendable { case classDecl, interfaceDecl, abstractDecl, enumDecl, annotationDecl }
    public var kind: Kind
    public var name: String
    public var label: String?
    public var stereotype: String?
    public var members: [PlantUMLClassMember]
}

public struct PlantUMLClassMember: Sendable {
    public enum Visibility: String, Sendable { case publicVis = "+", privateVis = "-", protectedVis = "#", packageVis = "~", none = "" }
    public enum Kind: String, Sendable { case field, method }
    public var visibility: Visibility
    public var kind: Kind
    public var raw: String
}

public struct PlantUMLClassRelationship: Sendable {
    public enum Kind: String, Sendable {
        case inheritance, realization, composition, aggregation,
             association, dependency
    }
    public var source: String
    public var target: String
    public var kind: Kind
    public var label: String?
    public var sourceCardinality: String?
    public var targetCardinality: String?
}

public struct PlantUMLClassNote: Sendable {
    public var attachedTo: String?
    public var position: String?
    public var text: String
}
```

- [ ] Create `Sources/DiagramKitPlantUML/Class/PlantUMLClassParser.swift`
  modeled on `PlantUMLSequenceParser`. It accepts the body text
  between `@startuml` and `@enduml`. Supports:
  - `class Name`, `interface Name`, `abstract class Name`,
    `enum Name`, `annotation Name`
  - Member declarations inside `{ … }` blocks: `+field: Type`,
    `+method(): Type`
  - Relationship arrows: `--|>` (inheritance), `..|>` (realization),
    `*--` (composition), `o--` (aggregation), `-->` (association),
    `..>` (dependency)
  - Cardinality strings on either end of an arrow (`"1" -- "*"`)
  - `note left of NAME : text` and `note "text" as Alias`

The parser surface:

```swift
public struct PlantUMLClassParser {
    public init() {}
    public func parse(_ body: String) -> PlantUMLClassAST { /* … */ }
}
```

- [ ] Write the failing parser test
  `Tests/DiagramKitTests/PlantUMLClassImporterTests.swift`:

```swift
import Testing
import DiagramKitModel
import DiagramKitPlantUML

@Suite struct PlantUMLClassImporterTests {

    @Test("Parses simple class with fields and methods")
    func simpleClass() throws {
        let source = """
        @startuml
        class Person {
          +name: String
          +age: Int
          +greet(): Void
        }
        @enduml
        """

        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload, got \(result.document.payload)")
            return
        }
        #expect(model.classes.contains(where: { $0.name == "Person" }))
        let person = model.classes.first(where: { $0.name == "Person" })
        #expect(person?.attributes.count == 2)
        #expect(person?.methods.count == 1)
    }
}
```

- [ ] Run it.

```bash
swift test --filter PlantUMLClassImporterTests
```

Expected: FAIL.

- [ ] Implement the parser, mapper, and the importer dispatch in
  `PlantUMLImporter.parse` so the test passes. The dispatch site is
  currently:

```swift
        // Check Class
        if isPlantUMLClassBody(body) {
            throw DiagramError.notYetImplemented("PlantUML Class diagrams not yet implemented (Slice 6B)")
        }
```

  Replace with:

```swift
        if isPlantUMLClassBody(body) {
            let ast = PlantUMLClassParser().parse(body)
            let (model, diagnostics) = PlantUMLClassMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .classDiagram(model)),
                diagnostics: diagnostics
            )
        }
```

- [ ] Rerun the test until PASS.

### Task 2.2 — Mapper covers inheritance, composition, aggregation

- [ ] Add tests for each relationship arrow style, including a
  cardinality-decorated edge.

```swift
    @Test("Maps inheritance and composition relationships")
    func inheritanceAndComposition() throws {
        let source = """
        @startuml
        class Animal
        class Dog
        class Tail
        Animal <|-- Dog
        Dog *-- Tail
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .classDiagram(let model) = result.document.payload else {
            Issue.record("Expected classDiagram payload"); return
        }
        let inheritance = model.relationships.first { $0.source == "Animal" && $0.target == "Dog" }
        #expect(inheritance?.kind == .inheritance)
        let composition = model.relationships.first { $0.source == "Dog" && $0.target == "Tail" }
        #expect(composition?.kind == .composition)
    }
```

- [ ] Implement `PlantUMLClassMapper.map` in the new mapper file.
  Translate the AST `Kind` cases into the `ClassDiagram` model's
  relationship kinds. Inspect `Sources/DiagramKitModel/ClassDiagram*.swift`
  (or `Types.swift`) for the canonical `ClassRelationshipKind` enum
  before wiring.

### Task 2.3 — Exporter

- [ ] Add `Sources/DiagramKitPlantUML/Exporter/PlantUMLClassExporter.swift`
  with a `PlantUMLClassExport.emit(_:)` function mirroring
  `PlantUMLSequenceExport.emit`. It walks `ClassDiagram` and emits:

```swift
@startuml
class Foo {
  +field: Type
  +method(): Type
}
Foo --|> Bar : extends
@enduml
```

- [ ] Update `PlantUMLExporter.supportedDiagramTypes` to include
  `.classDiagram` and add a `.classDiagram` case to its `switch`.

```swift
public struct PlantUMLExporter: DiagramExporter {
    public let supportedDiagramTypes: Set<DiagramType> = [
        .sequenceDiagram,
        .classDiagram,
    ]
    // …
    public func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        switch document.payload {
        case .sequenceDiagram(let model):
            return try PlantUMLSequenceExport.emit(model)
        case .classDiagram(let model):
            return try PlantUMLClassExport.emit(model)
        default:
            // existing fallback
        }
    }
}
```

- [ ] Add round-trip tests in
  `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift` matching
  the sequence pattern (export → re-parse → assert structural
  fidelity).

### Task 2.4 — Corpus entries + snapshot baselines

- [ ] Add 2–3 PlantUML class entries to
  `Examples/DiagramPlayground/Resources/test-diagrams.json`. Use the
  D2 multi-format entry shape as a template (`sources`,
  `expectedImporters`). The `source` field should hold the Mermaid
  equivalent so existing snapshot infrastructure works.
- [ ] Record SVG / image / ASCII baselines via the chunked snapshot
  command:

```bash
SNAPSHOT_TESTING_RECORD=true \
  SNAPSHOT_DIAGRAM_IDS=plantuml-class-1,plantuml-class-2 \
  swift test --filter CorpusSnapshotTests
```

- [ ] Confirm `CorpusMultiFormatSnapshotTests` picks up the new
  entries.

### Task 2.5 — Probe collision check

- [ ] Run `swift test --filter ProbeCollisionMatrixTests`. Confirm
  no new collisions appear. If a PlantUML class entry is mistakenly
  detected by another importer, tighten the probe in
  `Sources/DiagramKitPlantUML/PlantUMLFamilyProbe.swift`.

### Phase 2 Verification

- [ ] `swift test --filter PlantUMLClassImporterTests`
- [ ] `swift test --filter PlantUMLExporterTests`
- [ ] `swift test --filter ProbeCollisionMatrixTests`
- [ ] `swift test --filter CorpusMultiFormatSnapshotTests`
- [ ] `swift build --build-tests`
- [ ] Commit:
  `feat(plantuml): add class diagram importer + exporter slice`

---

## Phase 3 — PlantUML State / Activity Slice

**Outcome:** PlantUML state machines and basic activity diagrams parse
into `DiagramPayload.stateDiagram` and serialize back. The activity
syntax (`start`, `stop`, `:action;`, `if/else/endif`) maps into the
same `stateDiagram` payload because Mermaid uses one model for both.

**Files:**
- Create: `Sources/DiagramKitPlantUML/State/PlantUMLStateAST.swift`
- Create: `Sources/DiagramKitPlantUML/State/PlantUMLStateParser.swift`
- Create: `Sources/DiagramKitPlantUML/State/PlantUMLStateMapper.swift`
- Create: `Sources/DiagramKitPlantUML/Exporter/PlantUMLStateExporter.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
- Create: `Tests/DiagramKitTests/PlantUMLStateImporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json`

### Task 3.1 — AST + Parser

- [ ] Repeat the Phase 2.1 pattern. The state AST supports:
  - `state Name`, `state Name <<choice>>`, `state Composite { … }`
  - Initial / final pseudostates: `[*]`
  - Transitions: `A --> B : event`, `[*] --> A`, `A --> [*]`
  - Activity action lines: `:do work;`
  - Conditionals: `if (cond) then (yes) … else (no) … endif`
  - Forks/joins: `fork`, `fork again`, `end fork`

- [ ] Write the failing test, then build out the parser. The test
  signature mirrors Task 2.1's `simpleClass`, e.g.:

```swift
    @Test("Parses state transitions including initial pseudostate")
    func simpleState() throws {
        let source = """
        @startuml
        [*] --> Idle
        Idle --> Working : start
        Working --> [*]
        @enduml
        """
        let result = try PlantUMLImporter().parse(source)
        guard case .stateDiagram(let graph) = result.document.payload else {
            Issue.record("Expected stateDiagram payload"); return
        }
        let nodeIds = Set(graph.nodesInOrder.map(\.id))
        #expect(nodeIds.contains("Idle"))
        #expect(nodeIds.contains("Working"))
        // Initial pseudostate convention varies in the importer —
        // align test with whatever `Sources/DiagramKitModel/src_state_parser.swift`
        // emits for `[*]`.
    }
```

### Task 3.2 — Importer dispatch

- [ ] In `PlantUMLImporter.parse`, replace the existing
  `isPlantUMLStateBody` rejection with a real dispatch:

```swift
        if isPlantUMLStateBody(body) {
            let ast = PlantUMLStateParser().parse(body)
            let (graph, diagnostics) = PlantUMLStateMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .stateDiagram(graph)),
                diagnostics: diagnostics
            )
        }
```

### Task 3.3 — Exporter

- [ ] Repeat the Phase 2.3 pattern with a state exporter that emits:

```swift
@startuml
[*] --> Idle
Idle --> Working : start
Working --> [*]
@enduml
```

- [ ] Update `PlantUMLExporter.supportedDiagramTypes` to include
  `.stateDiagram` and add a `.stateDiagram` case to `export(_:)`.

### Task 3.4 — Corpus + snapshots

- [ ] Add 2–3 PlantUML state/activity corpus entries with
  `expectedImporters`. Record baselines via the same chunked command
  used in Task 2.4.

### Phase 3 Verification

- [ ] `swift test --filter PlantUMLStateImporterTests`
- [ ] `swift test --filter PlantUMLExporterTests`
- [ ] `swift test --filter ProbeCollisionMatrixTests`
- [ ] `swift build --build-tests`
- [ ] Commit:
  `feat(plantuml): add state/activity importer + exporter slice`

---

## Phase 4 — PlantUML Mindmap Slice

**Outcome:** PlantUML mindmaps (`@startmindmap` / `@endmindmap`) parse
into `DiagramPayload.mindmap`. `@startwbs` / `@endwbs` is accepted as
a mindmap synonym for now. Round-trip through a new
`PlantUMLMindmapExport`.

**Files:**
- Create: `Sources/DiagramKitPlantUML/Mindmap/PlantUMLMindmapAST.swift`
- Create: `Sources/DiagramKitPlantUML/Mindmap/PlantUMLMindmapParser.swift`
- Create: `Sources/DiagramKitPlantUML/Mindmap/PlantUMLMindmapMapper.swift`
- Create: `Sources/DiagramKitPlantUML/Exporter/PlantUMLMindmapExporter.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift` —
  replace the `startKind == "mindmap" || startKind == "wbs"`
  rejection with dispatch.
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
- Create: `Tests/DiagramKitTests/PlantUMLMindmapImporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json`

### Task 4.1 — AST + Parser

- [ ] Mindmap syntax is indent-based:

```text
@startmindmap
* Root
** Child A
*** Grandchild A1
** Child B
@endmindmap
```

  The parser counts leading `*` (or `+`/`-` in the alt syntax) to
  determine depth and the rest of the line as the node label.

- [ ] Implement `PlantUMLMindmapAST` with `root: PlantUMLMindmapNode`
  where each node has `label`, `children`, optional `color`,
  optional `shape`.
- [ ] Implement `PlantUMLMindmapParser.parse(_ body:)` that returns
  the AST. Reject lines that don't begin with `*`/`+`/`-` with a
  `.unsupported` diagnostic threaded through the mapper.

### Task 4.2 — Mapper + Importer dispatch

- [ ] In `PlantUMLMindmapMapper`, map the AST tree to whatever
  `MindmapDiagram` node structure
  `Sources/DiagramKitModel/MindmapDiagram*.swift` (or `Types.swift`)
  defines.
- [ ] In `PlantUMLImporter.parse`, replace the early
  `notYetImplemented` block for `startKind == "mindmap" || "wbs"`
  with:

```swift
        if startKind == "mindmap" || startKind == "wbs" {
            let ast = PlantUMLMindmapParser().parse(body)
            let (model, diagnostics) = PlantUMLMindmapMapper().map(ast)
            return DiagramImportResult(
                document: DiagramDocument(payload: .mindmap(model)),
                diagnostics: diagnostics
            )
        }
```

### Task 4.3 — Exporter

- [ ] Implement `PlantUMLMindmapExport.emit(_:)` to walk the
  `MindmapDiagram` and emit `@startmindmap` … `@endmindmap` with the
  `*` indentation form.
- [ ] Wire into `PlantUMLExporter.export(_:)` and
  `supportedDiagramTypes`.

### Task 4.4 — Tests + corpus

- [ ] Write parser, mapper, and round-trip tests.
- [ ] Add 2 corpus entries.

### Phase 4 Verification

- [ ] `swift test --filter PlantUMLMindmapImporterTests`
- [ ] `swift test --filter PlantUMLExporterTests`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(plantuml): add mindmap importer + exporter slice`

---

## Phase 5 — PlantUML Gantt Slice

**Outcome:** PlantUML Gantt charts (`@startgantt` / `@endgantt`) parse
into `DiagramPayload.gantt` and round-trip through a new
`PlantUMLGanttExport`.

**Files:**
- Create: `Sources/DiagramKitPlantUML/Gantt/PlantUMLGanttAST.swift`
- Create: `Sources/DiagramKitPlantUML/Gantt/PlantUMLGanttParser.swift`
- Create: `Sources/DiagramKitPlantUML/Gantt/PlantUMLGanttMapper.swift`
- Create: `Sources/DiagramKitPlantUML/Exporter/PlantUMLGanttExporter.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
- Create: `Tests/DiagramKitTests/PlantUMLGanttImporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json`

### Task 5.1 — AST + Parser

- [ ] PlantUML Gantt syntax:

```text
@startgantt
project starts 2024-01-15
[Design] lasts 10 days
[Build] lasts 20 days
[Build] starts at [Design]'s end
@endgantt
```

  Cover: `project starts <ISO date>`, `[Task] lasts N days`,
  `[Task] starts at [Other]'s end`, `[Task] is colored in <color>`.

- [ ] Implement parser, AST, mapper. The mapper produces a
  `GanttDiagram` matching the existing model. Honor
  `DIAGRAMKIT_GANTT_TODAY` so PlantUML-sourced Gantt entries inherit
  the same deterministic today-marker.

### Task 5.2 — Importer dispatch

- [ ] Replace the early `startKind == "gantt"` rejection in
  `PlantUMLImporter.parse` with dispatch to `PlantUMLGanttParser`.

### Task 5.3 — Exporter

- [ ] Implement `PlantUMLGanttExport.emit(_:)` and wire it into
  `PlantUMLExporter`.

### Task 5.4 — Tests + corpus

- [ ] Parser, mapper, and round-trip tests, plus 2 corpus entries.
- [ ] Confirm corpus tests still pass under the pinned
  `DIAGRAMKIT_GANTT_TODAY`.

### Phase 5 Verification

- [ ] `swift test --filter PlantUMLGanttImporterTests`
- [ ] `swift test --filter PlantUMLExporterTests`
- [ ] `swift test --filter CorpusMultiFormatSnapshotTests`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(plantuml): add gantt importer + exporter slice`

---

## Phase 6 — PlantUML C4 Slice

**Outcome:** PlantUML C4 (`!include <C4/…>`, `Person(…)`,
`System(…)`, `Container(…)`, `Rel(…)`) parses into
`DiagramPayload.c4`. A new `PlantUMLC4Export` round-trips. The
`isPlantUMLC4Body` probe already exists in
`PlantUMLFamilyProbe.swift`; verify and extend.

**Files:**
- Create: `Sources/DiagramKitPlantUML/C4/PlantUMLC4AST.swift`
- Create: `Sources/DiagramKitPlantUML/C4/PlantUMLC4Parser.swift`
- Create: `Sources/DiagramKitPlantUML/C4/PlantUMLC4Mapper.swift`
- Create: `Sources/DiagramKitPlantUML/Exporter/PlantUMLC4Exporter.swift`
- Modify: `Sources/DiagramKitPlantUML/PlantUMLImporter.swift`
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLExporter.swift`
- Create: `Tests/DiagramKitTests/PlantUMLC4ImporterTests.swift`
- Modify: `Tests/DiagramKitTests/Export/PlantUMLExporterTests.swift`
- Modify: `Examples/DiagramPlayground/Resources/test-diagrams.json`

### Task 6.1 — AST + Parser

- [ ] Cover the common C4 macros:
  - `Person(alias, "Label", "Description")`
  - `System(alias, "Label", "Description")`
  - `System_Ext(alias, "Label", "Description")`
  - `Container(alias, "Label", "Technology", "Description")`
  - `ContainerDb(alias, "Label", "Technology", "Description")`
  - `Component(alias, "Label", "Technology", "Description")`
  - `Rel(from, to, "Label", "Technology")`
  - `Rel_Back(from, to, "Label")`
  - `Boundary(alias, "Label", "Type") { … }`
- [ ] Implement the AST as a sequence of declarations + relationships +
  nested boundaries. Reuse the helper utilities already in
  `PlantUMLSequenceParser` for stripping quoted strings.

### Task 6.2 — Mapper + dispatch

- [ ] Replace the `isPlantUMLC4Body` rejection in
  `PlantUMLImporter.parse` with dispatch into the new parser.

### Task 6.3 — Exporter

- [ ] Re-introduce a PlantUML C4 exporter. Note: a previous
  `PlantUMLC4Exporter.swift` was deleted in commit `a20e94e`
  (Phase 7 doc cleanup) — that prior version was unwired. The new
  exporter must:
  - Live at
    `Sources/DiagramKitPlantUML/Exporter/PlantUMLC4Exporter.swift`.
  - Expose `enum PlantUMLC4Export { static func emit(_ model:) }`
    rather than a separate `DiagramExporter` struct so it slots into
    the existing `PlantUMLExporter` switch.
  - Be added to `PlantUMLExporter.supportedDiagramTypes` and the
    `export(_:)` switch.

### Task 6.4 — Tests + corpus

- [ ] Add parser, mapper, and round-trip tests.
- [ ] Add 2 PlantUML C4 corpus entries.

### Phase 6 Verification

- [ ] `swift test --filter PlantUMLC4ImporterTests`
- [ ] `swift test --filter PlantUMLExporterTests`
- [ ] `swift test --filter ProbeCollisionMatrixTests`
- [ ] `swift build --build-tests`
- [ ] After this phase, update `PHASES.md` "Active work" to remove
  the PlantUML family-slices bullet.
- [ ] Commit: `feat(plantuml): add C4 importer + exporter slice`

---

## Phase 7 — ASCII Renderer Framework + Pie Chart

**Outcome:** A single new family (Pie) ships an ASCII renderer.
That phase establishes the canonical template — file location,
naming, dispatch, theme/ANSI threading, corpus integration — so the
later ASCII phases reuse the pattern unchanged.

**Files:**
- Create: `Sources/DiagramKitModel/src_ascii_pie.swift`
- Modify: `Sources/DiagramKit/src_ascii_index.swift` — replace the
  `.pie` `throw notYetImplemented` with a dispatch to the new
  renderer.
- Create: `Tests/DiagramKitTests/PieAsciiRendererTests.swift`
- Modify: `Tests/DiagramKitTests/CorpusSnapshotTests.swift` if any
  Pie corpus entries currently set `skipSnapshots.ascii: true`;
  remove that flag once the renderer is in place.
- Modify: any Pie entry in
  `Examples/DiagramPlayground/Resources/test-diagrams.json` that
  carries `"skipSnapshots": { "ascii": true }`.

### Task 7.1 — Write the failing renderer test

- [ ] Create `Tests/DiagramKitTests/PieAsciiRendererTests.swift`:

```swift
import Testing
import DiagramKit

@Suite struct PieAsciiRendererTests {

    @Test("Pie ASCII renderer emits totals and slice rows")
    func basicPie() throws {
        let source = """
        pie title Fruit
            "Apple" : 30
            "Banana" : 20
            "Cherry" : 10
        """
        let output = try renderDiagramASCII(source)
        #expect(output.contains("Fruit"))
        #expect(output.contains("Apple"))
        #expect(output.contains("Banana"))
        #expect(output.contains("Cherry"))
        // 30 + 20 + 10 == 60; 30 / 60 == 50 %
        #expect(output.contains("50"))
    }
}
```

- [ ] Run.

```bash
swift test --filter PieAsciiRendererTests
```

Expected: FAIL with `notYetImplemented("Pie Chart ASCII rendering")`.

### Task 7.2 — Implement the renderer

- [ ] Create `Sources/DiagramKitModel/src_ascii_pie.swift`:

```swift
import Foundation

public func renderPieAscii(
    _ source: String,
    _ config: original_src_ascii_index.AsciiConfig,
    _ colorMode: original_src_ascii_index.AsciiThemeColorMode,
    _ theme: original_src_ascii_index.AsciiTheme
) throws -> String {
    let parsed = try parseMermaid(source)
    guard case .pie(let chart) = parsed.payload else {
        throw DiagramError.notYetImplemented("Pie Chart ASCII rendering: non-pie payload")
    }

    let total = chart.slices.reduce(0.0) { $0 + $1.value }
    guard total > 0 else { return chart.title ?? "" }

    var lines: [String] = []
    if let title = chart.title, !title.isEmpty {
        lines.append(title)
        lines.append(String(repeating: "=", count: title.count))
    }

    let maxLabelWidth = chart.slices.map(\.label.count).max() ?? 0

    for slice in chart.slices {
        let percent = slice.value / total * 100
        let barWidth = Int((percent / 2.0).rounded()) // 0–50 chars
        let bar = String(repeating: "#", count: barWidth)
        let paddedLabel = slice.label.padding(
            toLength: maxLabelWidth,
            withPad: " ",
            startingAt: 0
        )
        let pctString = String(format: "%5.1f", percent)
        lines.append("\(paddedLabel) | \(bar) \(pctString)%")
    }

    return lines.joined(separator: "\n")
}
```

  Adjust the field names (`chart.slices`, `slice.label`, `slice.value`,
  `chart.title`) to match the actual `PieChart` model in
  `Sources/DiagramKitModel/` before committing.

### Task 7.3 — Dispatch

- [ ] In `Sources/DiagramKit/src_ascii_index.swift`, replace:

```swift
        case .pie:
            throw DiagramError.notYetImplemented("Pie Chart ASCII rendering")
```

  with:

```swift
        case .pie:
            return try renderPieAscii(preprocessedText, config, resolvedColorMode, theme)
```

  Add `renderPieAscii` to the import list if it isn't already
  re-exported by `DiagramKitModel`.

### Task 7.4 — Tests pass, snapshot baseline

- [ ] Rerun the renderer suite.

```bash
swift test --filter PieAsciiRendererTests
```

Expected: PASS.

- [ ] Identify Pie corpus entries:

```bash
grep -l "\"type\":\\s*\"pie\"" Examples/DiagramPlayground/Resources/test-diagrams.json || true
```

  (Pie entries may use a different filter — check `category` or
  `type` field that the corpus uses.)

- [ ] Remove `"skipSnapshots": { "ascii": true }` from those entries.
- [ ] Record ASCII baselines via chunked execution:

```bash
SNAPSHOT_TESTING_RECORD=true \
  SNAPSHOT_DIAGRAM_IDS=<pie-ids-comma-separated> \
  swift test --filter CorpusSnapshotTests/asciiSnapshot
```

### Task 7.5 — Update `BASELINES.md`

- [ ] Bump the ASCII baseline count (currently 174). Note the new
  Pie entries.

### Phase 7 Verification

- [ ] `swift test --filter PieAsciiRendererTests`
- [ ] `SNAPSHOT_DIAGRAM_IDS=<pie-ids> swift test --filter CorpusSnapshotTests`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(ascii): add pie chart ASCII renderer`

---

## Phase 8 — ASCII Tree-Shaped Families

**Outcome:** Mindmap, TreeView, and Ishikawa ship ASCII renderers
following the Phase 7 template. They share a common tree-drawing
utility extracted in Task 8.0.

**Families covered (3):** `mindmap`, `treeView`, `ishikawa`.

**Files:**
- Create: `Sources/DiagramKitModel/src_ascii_tree_utils.swift` —
  shared tree-drawing helpers.
- Create: `Sources/DiagramKitModel/src_ascii_mindmap.swift`
- Create: `Sources/DiagramKitModel/src_ascii_treeview.swift`
- Create: `Sources/DiagramKitModel/src_ascii_ishikawa.swift`
- Modify: `Sources/DiagramKit/src_ascii_index.swift` — replace three
  `notYetImplemented` lines with dispatch.
- Create: `Tests/DiagramKitTests/MindmapAsciiRendererTests.swift`
- Create: `Tests/DiagramKitTests/TreeViewAsciiRendererTests.swift`
- Create: `Tests/DiagramKitTests/IshikawaAsciiRendererTests.swift`
- Modify: corpus entries to drop `skipSnapshots.ascii`.

### Task 8.0 — Extract shared tree-drawing utility

- [ ] Create `Sources/DiagramKitModel/src_ascii_tree_utils.swift`
  containing a generic indented-tree formatter:

```swift
import Foundation

public protocol AsciiTreeNode {
    var asciiLabel: String { get }
    var asciiChildren: [Self] { get }
}

public enum AsciiTreeStyle {
    case unicode, asciiSafe
}

public func renderAsciiTree<Node: AsciiTreeNode>(
    root: Node,
    style: AsciiTreeStyle = .unicode
) -> String {
    var lines: [String] = []
    appendNode(root, prefix: "", isTail: true, isRoot: true, style: style, lines: &lines)
    return lines.joined(separator: "\n")
}

private func appendNode<Node: AsciiTreeNode>(
    _ node: Node,
    prefix: String,
    isTail: Bool,
    isRoot: Bool,
    style: AsciiTreeStyle,
    lines: inout [String]
) {
    let branch: String
    let cont: String
    switch (style, isTail) {
    case (.unicode, true):  branch = "└── "; cont = "    "
    case (.unicode, false): branch = "├── "; cont = "│   "
    case (.asciiSafe, true):  branch = "`-- "; cont = "    "
    case (.asciiSafe, false): branch = "|-- "; cont = "|   "
    }
    if isRoot {
        lines.append(node.asciiLabel)
    } else {
        lines.append(prefix + branch + node.asciiLabel)
    }
    let nextPrefix = isRoot ? "" : prefix + cont
    let children = node.asciiChildren
    for (idx, child) in children.enumerated() {
        appendNode(
            child,
            prefix: nextPrefix,
            isTail: idx == children.count - 1,
            isRoot: false,
            style: style,
            lines: &lines
        )
    }
}
```

### Task 8.1 — Mindmap renderer

- [ ] Write the failing test:

```swift
    @Test("Mindmap ASCII renderer emits nested tree")
    func basicMindmap() throws {
        let source = """
        mindmap
          root((Root))
            Child A
              Grandchild A1
            Child B
        """
        let output = try renderDiagramASCII(source)
        #expect(output.contains("Root"))
        #expect(output.contains("Child A"))
        #expect(output.contains("Grandchild A1"))
        #expect(output.contains("├──") || output.contains("|--"))
    }
```

- [ ] Implement `renderMindmapAscii` adapting `MindmapDiagram` to
  the `AsciiTreeNode` protocol from Task 8.0.
- [ ] Add the dispatch case in `src_ascii_index.swift`.

### Task 8.2 — TreeView renderer

- [ ] Repeat the Task 8.1 pattern. The TreeView payload already maps
  cleanly onto `AsciiTreeNode`.

### Task 8.3 — Ishikawa renderer

- [ ] Ishikawa (fishbone) layout is more bespoke than a vertical
  tree — branches grow diagonally on either side of a horizontal
  spine. Render as ASCII by:
  - Emitting the effect label as a right-aligned arrow target.
  - Drawing two-column rows for each cause group.

  Example acceptance output (Unicode):

```text
                  Cause 1       Cause 3
                     \\           /
                      \\         /
        ────────────────────────────► Effect
                      /         \\
                     /           \\
                  Cause 2       Cause 4
```

- [ ] Failing test asserts presence of the effect label and at least
  one branch arrow line.
- [ ] Implement `renderIshikawaAscii` directly (it does not use the
  shared tree utility — drawing is canvas-based). Reuse
  `original_src_ascii_canvas` helpers.

### Task 8.4 — Corpus + snapshots

- [ ] Drop `skipSnapshots.ascii` from corpus entries for mindmap,
  treeView, and ishikawa.
- [ ] Record new ASCII baselines per Task 7.4.

### Phase 8 Verification

- [ ] `swift test --filter MindmapAsciiRendererTests`
- [ ] `swift test --filter TreeViewAsciiRendererTests`
- [ ] `swift test --filter IshikawaAsciiRendererTests`
- [ ] `SNAPSHOT_DIAGRAM_IDS=<mindmap-ids,treeView-ids,ishikawa-ids> swift test --filter CorpusSnapshotTests/asciiSnapshot`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(ascii): add tree-shaped family renderers`

---

## Phase 9 — ASCII Time-Based Families

**Outcome:** Gantt, GitGraph, Timeline, and User Journey ship ASCII
renderers. They share a horizontal-axis utility extracted in
Task 9.0.

**Families covered (4):** `gantt`, `gitGraph`, `timeline`, `journey`.

**Files:**
- Create: `Sources/DiagramKitModel/src_ascii_axis_utils.swift`
- Create: `Sources/DiagramKitModel/src_ascii_gantt.swift`
- Create: `Sources/DiagramKitModel/src_ascii_gitgraph.swift`
- Create: `Sources/DiagramKitModel/src_ascii_timeline.swift`
- Create: `Sources/DiagramKitModel/src_ascii_journey.swift`
- Modify: `Sources/DiagramKit/src_ascii_index.swift`
- Create: one test file per family under `Tests/DiagramKitTests/`.
- Modify: corpus entries (gantt has 7 entries, journey ~2, gitGraph
  several, timeline several).

### Task 9.0 — Horizontal-axis helper

- [ ] Create `Sources/DiagramKitModel/src_ascii_axis_utils.swift`
  exposing `formatHorizontalAxis(start:end:width:granularity:)` and
  related helpers (tick computation, label collision handling).

### Task 9.1 — Gantt renderer

- [ ] Failing test:

```swift
    @Test("Gantt ASCII renderer emits header row and task bars")
    func basicGantt() throws {
        // Pin today-marker for determinism inside the test.
        setenv("DIAGRAMKIT_GANTT_TODAY", "2024-06-15", 1)
        defer { unsetenv("DIAGRAMKIT_GANTT_TODAY") }

        let source = """
        gantt
            title Test
            dateFormat YYYY-MM-DD
            section A
                Task1 :a1, 2024-06-10, 5d
                Task2 :after a1, 5d
        """
        let output = try renderDiagramASCII(source)
        #expect(output.contains("Test"))
        #expect(output.contains("Task1"))
        #expect(output.contains("Task2"))
    }
```

- [ ] Implement `renderGanttAscii`. Render rows as `<label> | <bar>`
  where the bar spans the task's date range, scaled into the canvas
  width.

### Task 9.2 — GitGraph renderer

- [ ] Render the commit graph as an ASCII Git log:

```text
* feat: branch
|\\
| * fix: hotfix
|/
* chore: init
```

- [ ] Adapt the existing `original_src_gitgraph_layout` output —
  the positioned commit lanes give you everything needed.

### Task 9.3 — Timeline renderer

- [ ] Render as vertical events with timestamps:

```text
2024-01 ─┐
         │  Event A
2024-03 ─┤
         │  Event B
2024-05 ─┘
```

### Task 9.4 — Journey renderer

- [ ] Render as a matrix: actors across the top, tasks down the
  side, scores in each cell.

### Task 9.5 — Corpus + snapshots

- [ ] Drop `skipSnapshots.ascii` from corpus entries for all four
  families. Record ASCII baselines.

### Phase 9 Verification

- [ ] One swift-testing suite per family passes.
- [ ] `SNAPSHOT_DIAGRAM_IDS=<combined-ids> swift test --filter CorpusSnapshotTests/asciiSnapshot`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(ascii): add time-based family renderers`

---

## Phase 10 — ASCII Box-Cluster Families

**Outcome:** Block, C4, Architecture, EventModeling, Wardley, and
Kanban ship ASCII renderers. All of these draw boxes connected by
lines on a canvas; they share the same canvas helpers used by the
existing flowchart ASCII path (`original_src_ascii_canvas`,
`original_src_ascii_edge_routing`).

**Families covered (6):** `block`, `c4`, `architecture`,
`eventModeling`, `wardleyBeta`, `kanban`.

**Files:**
- Create: `Sources/DiagramKitModel/src_ascii_block.swift`
- Create: `Sources/DiagramKitModel/src_ascii_c4.swift`
- Create: `Sources/DiagramKitModel/src_ascii_architecture.swift`
- Create: `Sources/DiagramKitModel/src_ascii_eventmodeling.swift`
- Create: `Sources/DiagramKitModel/src_ascii_wardley.swift`
- Create: `Sources/DiagramKitModel/src_ascii_kanban.swift`
- Modify: `Sources/DiagramKit/src_ascii_index.swift`
- Create: one test file per family.
- Modify: corpus entries.

### Task 10.1 — Canvas-renderer template

- [ ] Each of the six families follows the same outline:
  1. Parse + layout the diagram (reuse the existing layout output).
  2. Allocate an `original_src_ascii_canvas.AsciiCanvas` sized to
     the layout bounds, scaled into a target column width.
  3. Stamp each layout node as an ASCII box
     (`original_src_ascii_shapes_rectangle` or the matching shape
     variant).
  4. Stamp edges via `original_src_ascii_edge_routing`.
  5. Return the canvas's `render(useAscii:)` output.

  Implement this pattern once for `renderBlockAscii` and use it as
  the reference for the remaining five. Each renderer file should
  stay under 300 lines; pull family-specific shape choices into
  a `boxStyle(for:)` helper.

### Task 10.2 – 10.6 — Per-family renderer

- [ ] Repeat the Task 10.1 outline for `c4`, `architecture`,
  `eventModeling`, `wardleyBeta`, `kanban`. Each task:
  - Failing test asserting node labels appear in the output.
  - Renderer file.
  - Dispatch swap in `src_ascii_index.swift`.
  - Drop `skipSnapshots.ascii` from corpus entries.

### Phase 10 Verification

- [ ] One swift-testing suite per family passes.
- [ ] `SNAPSHOT_DIAGRAM_IDS=<combined-ids> swift test --filter CorpusSnapshotTests/asciiSnapshot`
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(ascii): add box-cluster family renderers`

---

## Phase 11 — ASCII Specialty Chart Families

**Outcome:** The remaining families — Sankey, Radar, Treemap, Venn,
QuadrantChart, Packet, Requirement, ZenUML — ship ASCII renderers.
Each is bespoke because the chart types do not map onto a shared
template.

**Families covered (8):** `sankey`, `radar`, `treemap`, `venn`,
`quadrantChart`, `packet`, `requirement`, `zenuml`.

**Files:**
- Create: `Sources/DiagramKitModel/src_ascii_sankey.swift`
- Create: `Sources/DiagramKitModel/src_ascii_radar.swift`
- Create: `Sources/DiagramKitModel/src_ascii_treemap.swift`
- Create: `Sources/DiagramKitModel/src_ascii_venn.swift`
- Create: `Sources/DiagramKitModel/src_ascii_quadrant.swift`
- Create: `Sources/DiagramKitModel/src_ascii_packet.swift`
- Create: `Sources/DiagramKitModel/src_ascii_requirement.swift`
- Create: `Sources/DiagramKitModel/src_ascii_zenuml.swift`
- Modify: `Sources/DiagramKit/src_ascii_index.swift`
- Create: one test file per family.
- Modify: corpus entries.

### Task 11.1 — Sankey

- [ ] Render as left-column source labels, right-column target
  labels, with `>` arrows in between and value annotations.

### Task 11.2 — Radar

- [ ] Render as a labeled axis list with values, similar to the Pie
  template:

```text
Radar: Skills
  Speed       | ████████░░ 80
  Strength    | ██████░░░░ 60
  Endurance   | █████████░ 90
```

### Task 11.3 — Treemap

- [ ] Render as a nested indented tree with proportional `#` bars
  next to each leaf, similar to Pie/Radar.

### Task 11.4 — Venn

- [ ] Render two- or three-set Venn diagrams as labeled bullet
  lists with `∩` notation for intersections:

```text
A only: 10
B only: 8
A ∩ B: 4
```

### Task 11.5 — QuadrantChart

- [ ] Render a 2x2 grid with quadrant labels and point lists:

```text
                ^ y-axis
   high impact  |  high impact
   low effort   |  high effort
   --------------------------
   low impact   |  low impact
   low effort   |  high effort
                v
```

### Task 11.6 — Packet

- [ ] Render packet diagrams as numbered byte-range rows:

```text
0–7   | Version
8–15  | Header length
16–31 | Total length
```

### Task 11.7 — Requirement

- [ ] Render requirement diagrams as a nested labeled tree linking
  requirements to their `satisfies` / `derives` targets.

### Task 11.8 — ZenUML

- [ ] Render ZenUML lifelines as a Mermaid-sequence-style ASCII
  diagram. The closest analogue already exists in
  `src_ascii_sequence.swift`; consider extracting a shared
  lifelines helper rather than duplicating logic.

### Task 11.9 — Coverage cleanup

- [ ] After Phase 11, every `case` in
  `Sources/DiagramKit/src_ascii_index.swift` should dispatch to a
  real renderer. Verify nothing throws `notYetImplemented`:

```bash
grep -n "notYetImplemented" Sources/DiagramKit/src_ascii_index.swift
```

Expected: no matches.

- [ ] Update `BASELINES.md` ASCII baseline count to 422 (parity
  with SVG / image).
- [ ] Update `PHASES.md` "Active work" to remove the ASCII coverage
  bullet.

### Phase 11 Verification

- [ ] Per-family swift-testing suites pass.
- [ ] `swift test --filter CorpusSnapshotTests/asciiSnapshot`
  produces no new failures (record baselines via
  `SNAPSHOT_DIAGRAM_IDS` chunks; the full corpus run still has the
  known signal-10 caveat).
- [ ] `swift build --build-tests`
- [ ] Commit: `feat(ascii): add specialty chart family renderers`

---

## Phase 12 — Release Verification

**Outcome:** Every open work item from the post-remediation
`PHASES.md` has a merged closing commit, governance gates aggregate
green or carry an explicit environment skip, and `BASELINES.md` /
`PHASES.md` reflect the new feature-complete state.

**Files:**
- Modify: `PHASES.md`
- Modify: `BASELINES.md`
- Modify: `README.md` — bump status line if the feature-complete
  state warrants it.

- [ ] Re-read `PHASES.md`. Confirm all three Active-Work bullets
  have been removed.
- [ ] Re-run targeted suites from Phases 1–11.
- [ ] Run the snapshot chunks affected by the new renderers, one
  family at a time. The full corpus run still has the known
  signal-10 caveat.
- [ ] Run governance scripts.

```bash
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
SKIP_LINUX_CHECK=1 Scripts/linux-check.sh
Scripts/bootstrap-smoke-check.sh
```

Expected: all gates pass or report environment skips for missing
runtimes; no source failures.

- [ ] Update `BASELINES.md`:
  - ASCII baseline count: 422 (matches SVG / image).
  - Test source count: bump per new test files added.
  - Build time: re-measure on the local toolchain.
  - Append a "Post-remediation feature work" section listing the
    closing commit for the DOT exporter, each PlantUML slice, and
    each ASCII family.
- [ ] Update `README.md` status line if the additions are
  release-worthy:
  - Bump `1044 snapshot baselines` to the new total.
  - Drop the "remaining work" sentence pointing at PHASES.md, since
    PHASES.md no longer has open Active Work entries.
- [ ] Prepare a release-note summary grouped by family/format.
- [ ] Tag a release if requested.

---

## Final Acceptance Criteria

- `DOTExporter` produces parser-compatible DOT for flowchart
  documents; `DiagramExportLoader.export(to: .graphviz, …)` succeeds.
- PlantUML importer handles class, state/activity, mindmap, gantt,
  and C4 in addition to sequence. PlantUML exporter covers the same
  set.
- Every `case` in `Sources/DiagramKit/src_ascii_index.swift`
  dispatches to a real renderer; `grep notYetImplemented` returns
  nothing in that file.
- `Examples/DiagramPlayground/Resources/test-diagrams.json` has at
  least 2 round-trippable corpus entries per new PlantUML family
  slice, and ASCII snapshot baselines exist for every diagram
  family.
- `swift build --build-tests` passes.
- `Scripts/bootstrap-smoke-check.sh` aggregates green or reports
  only environment skips.
- `PHASES.md` "Active work" section is empty (or replaced with a
  new horizon).
