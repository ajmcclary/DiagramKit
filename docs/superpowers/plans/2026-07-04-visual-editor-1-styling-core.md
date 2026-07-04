# Visual Editor Plan 1/6 — Styling Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Visual node styling for flowcharts — change an existing node's shape, border style, and colors from the node menu, serialized as deduplicated generated `classDef` entries and v11 `@{ shape: … }` metadata in the Mermaid source.

**Architecture:** Two new `FlowchartMutation` cases (`setNodeShape`, `setNodeStyle`) in `DiagramKitInteractive` ride the existing atomic `performFlowchart → _commitMutation` path. A pure `StyleClassManager` owns generated-classDef lifecycle (find-or-create `vsN`, reassign, GC). The Mermaid flowchart exporter gains `@{ shape:, icon:, img:, … }` metadata emission so all ~70 `NodeShape` cases round-trip faithfully. The sample app's `NodeEditPopover` is rebuilt to drive the new mutations.

**Tech Stack:** Swift 6 (strict concurrency), swift-testing (`@Test`/`#expect`), SwiftPM, SwiftUI (sample app, macOS-first).

**Spec:** `docs/superpowers/specs/2026-07-04-visual-editor-design.md` (Sections 1, 2, part of 3, 7).

## Global Constraints

- Work directly on `main`, commit-by-commit. No branches, no worktrees, no stash.
- Never run bare `swift test` — always `swift test --filter <ExactSuiteName>`. Filters must be exact suite names (substring filters can match corpus parameterized tests and hang).
- No thread pools in production parse/layout/render code (existing `_runOnWorker` dispatch is untouched by this plan).
- Diagnostics only via typed factories: `DiagramDiagnostic.lossyTransform(.<cat>, …)` / `.featureDropped(.<cat>, …)` / `.informational(.<cat>, …)`. Never `DiagramDiagnostic(severity:message:)`. Gate: `Scripts/check-diagnostic-discipline.sh`.
- Swift files: warn at 500 lines, error at 1000 (`Scripts/check-file-sizes.sh`).
- Pattern-match typed payload enums; never cast to `Any`.
- The model-type namespace is `original_src_types` (e.g. `original_src_types.MermaidGraph`); `ParsedGraphModel` is a public typealias for `original_src_types.MermaidGraph`.
- Undo is snapshot-based and registered inside `_commitMutation` — new mutations get undo for free; do not add per-mutation undo code.
- After editing `Package.swift` (not expected in this plan): `swift package resolve`.

---

### Task 1: `NodeStyleSpec` + `FlowchartBorderStyle`

**Files:**
- Create: `Sources/DiagramKitInteractive/NodeStyleSpec.swift`
- Test: `Tests/DiagramKitTests/Interactive/NodeStyleSpecTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `public struct NodeStyleSpec: Sendable, Equatable, Hashable` with `fill: String?`, `stroke: String?`, `textColor: String?`, `borderStyle: FlowchartBorderStyle?`, `isEmpty: Bool`, `classDefProperties: [String: String]`, `init(fill:stroke:textColor:borderStyle:)`, `init(classDefProperties:)`. `public enum FlowchartBorderStyle: String, Sendable, CaseIterable, Hashable { case solid, dashed, thick }`. Tasks 2, 4, 6 use these exact names.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Interactive/NodeStyleSpecTests.swift`:

```swift
// Visual editor plan 1 — NodeStyleSpec value semantics.

import Testing
@testable import DiagramKitInteractive

@Suite
struct NodeStyleSpecTests {

    @Test("classDefProperties maps colors and normalizes hex to lowercase")
    func propertiesMapping() {
        let spec = NodeStyleSpec(
            fill: "#E8F5E9", stroke: "#2E7D32", textColor: "#1B5E20", borderStyle: .dashed
        )
        #expect(spec.classDefProperties == [
            "fill": "#e8f5e9",
            "stroke": "#2e7d32",
            "color": "#1b5e20",
            "stroke-dasharray": "5 5",
        ])
    }

    @Test("thick border maps to stroke-width, solid adds nothing")
    func borderMapping() {
        #expect(NodeStyleSpec(borderStyle: .thick).classDefProperties == ["stroke-width": "3px"])
        #expect(NodeStyleSpec(borderStyle: .solid).classDefProperties.isEmpty)
    }

    @Test("empty spec has no properties and reports isEmpty")
    func emptySpec() {
        let spec = NodeStyleSpec()
        #expect(spec.isEmpty)
        #expect(spec.classDefProperties.isEmpty)
    }

    @Test("init(classDefProperties:) round-trips a generated map")
    func roundTripFromProperties() {
        let original = NodeStyleSpec(fill: "#fff3e0", stroke: "#ef6c00", borderStyle: .dashed)
        let rebuilt = NodeStyleSpec(classDefProperties: original.classDefProperties)
        #expect(rebuilt == original)
    }

    @Test("init(classDefProperties:) reads thick from stroke-width")
    func thickFromProperties() {
        let spec = NodeStyleSpec(classDefProperties: ["stroke-width": "3px"])
        #expect(spec.borderStyle == .thick)
    }

    @Test("equal styles written differently normalize equal")
    func normalization() {
        let a = NodeStyleSpec(fill: "#AABBCC")
        let b = NodeStyleSpec(fill: "#aabbcc")
        #expect(a.classDefProperties == b.classDefProperties)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter NodeStyleSpecTests`
Expected: BUILD FAILURE — `cannot find 'NodeStyleSpec' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/DiagramKitInteractive/NodeStyleSpec.swift`:

```swift
// Visual editor — typed node style value for the setNodeStyle mutation.
// Maps 1:1 onto Mermaid classDef properties (fill:, stroke:, color:,
// stroke-dasharray: / stroke-width:). Colors are lowercase "#rrggbb"
// hex strings so equal styles always compare equal.

/// Border rendering for a flowchart node. `solid` is the Mermaid
/// default and contributes no classDef property.
public enum FlowchartBorderStyle: String, Sendable, CaseIterable, Hashable {
    case solid
    case dashed
    case thick
}

/// The node-menu styling surface: background, border, and text color
/// plus border style. All fields optional — an empty spec means
/// "clear visual styling".
public struct NodeStyleSpec: Sendable, Equatable, Hashable {
    public var fill: String?
    public var stroke: String?
    public var textColor: String?
    public var borderStyle: FlowchartBorderStyle?

    public init(
        fill: String? = nil,
        stroke: String? = nil,
        textColor: String? = nil,
        borderStyle: FlowchartBorderStyle? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
        self.textColor = textColor
        self.borderStyle = borderStyle
    }

    public var isEmpty: Bool {
        fill == nil && stroke == nil && textColor == nil && borderStyle == nil
    }

    /// Canonical classDef property map. Keys are Mermaid classDef
    /// property names; hex values lowercased so identical styles
    /// hash identically (StyleClassManager dedup relies on this).
    public var classDefProperties: [String: String] {
        var props: [String: String] = [:]
        if let fill { props["fill"] = fill.lowercased() }
        if let stroke { props["stroke"] = stroke.lowercased() }
        if let textColor { props["color"] = textColor.lowercased() }
        switch borderStyle {
        case .dashed: props["stroke-dasharray"] = "5 5"
        case .thick: props["stroke-width"] = "3px"
        case .solid, nil: break
        }
        return props
    }

    /// Rebuild a spec from a classDef property map (used to seed the
    /// node menu from a node's effective style). Absent border
    /// properties yield `borderStyle == nil`, which the UI treats as
    /// solid.
    public init(classDefProperties props: [String: String]) {
        self.fill = props["fill"]?.lowercased()
        self.stroke = props["stroke"]?.lowercased()
        self.textColor = props["color"]?.lowercased()
        if props["stroke-dasharray"] != nil {
            self.borderStyle = .dashed
        } else if props["stroke-width"] != nil {
            self.borderStyle = .thick
        } else {
            self.borderStyle = nil
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter NodeStyleSpecTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/NodeStyleSpec.swift Tests/DiagramKitTests/Interactive/NodeStyleSpecTests.swift
git commit -m "Visual editor 1a — NodeStyleSpec typed style value"
```

---

### Task 2: `styleClassMigration` diagnostic category + `StyleClassManager`

**Files:**
- Modify: `Sources/DiagramKitCommon/DiagnosticCategory.swift` (add `.styleClassMigration` to the `.info` tier)
- Modify: `docs/diagnostic-severity-discipline.md` (category table row)
- Create: `Sources/DiagramKitInteractive/StyleClassManager.swift`
- Test: `Tests/DiagramKitTests/Interactive/StyleClassManagerTests.swift`

**Interfaces:**
- Consumes: `NodeStyleSpec` from Task 1; `original_src_types.MermaidGraph` (`classDefs: [String: [String: String]]`, `classAssignments: [String: [String]]`, `nodeStyles: [String: [String: String]]`, `defaultClassDef: [String: String]?`, `edgeClassAssignments: [String: String]`, `edges[*].classes: [String]?`).
- Produces (used by Tasks 4 and 6):
  - `StyleClassManager.isGeneratedClassName(_ name: String) -> Bool`
  - `StyleClassManager.applyStyle(_ spec: NodeStyleSpec, toNode nodeID: String, in graph: original_src_types.MermaidGraph) -> (graph: original_src_types.MermaidGraph, diagnostics: [DiagramDiagnostic])`
  - `StyleClassManager.effectiveStyle(forNode nodeID: String, in graph: original_src_types.MermaidGraph) -> NodeStyleSpec`
  - `DiagnosticCategory.styleClassMigration` (severity `.info`)

- [ ] **Step 1: Add the diagnostic category**

In `Sources/DiagramKitCommon/DiagnosticCategory.swift`, under the `// MARK: - .info` group (after `case commentPreserved`), add:

```swift
    case styleClassMigration
```

In the `severity` switch, add `.styleClassMigration` to the `.info` branch (the one returning `.info`, alongside `.identifierEscape, .commentPreserved`).

In `docs/diagnostic-severity-discipline.md`, add a row to the category table:

```markdown
| `styleClassMigration` | `.info` | Inline `style` statement migrated to a generated classDef by a visual-editor mutation. Round-trip stable. |
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/StyleClassManagerTests.swift`:

```swift
// Visual editor plan 1 — generated-classDef lifecycle.

import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitInteractive

private func graph(
    nodes: [String],
    classDefs: [String: [String: String]] = [:],
    classAssignments: [String: [String]] = [:],
    nodeStyles: [String: [String: String]] = [:]
) -> original_src_types.MermaidGraph {
    original_src_types.MermaidGraph(
        direction: .TD,
        nodesInOrder: nodes.map {
            (id: $0, node: original_src_types.MermaidNode(id: $0, label: $0, shape: .rectangle))
        },
        edges: [],
        classDefs: classDefs,
        classAssignments: classAssignments,
        nodeStyles: nodeStyles
    )
}

private let greenSpec = NodeStyleSpec(fill: "#e8f5e9", stroke: "#2e7d32")

@Suite
struct StyleClassManagerTests {

    @Test("generated-name detection")
    func generatedNames() {
        #expect(StyleClassManager.isGeneratedClassName("vs1"))
        #expect(StyleClassManager.isGeneratedClassName("vs42"))
        #expect(!StyleClassManager.isGeneratedClassName("vs"))
        #expect(!StyleClassManager.isGeneratedClassName("vsx"))
        #expect(!StyleClassManager.isGeneratedClassName("important"))
        #expect(!StyleClassManager.isGeneratedClassName("vs1b"))
    }

    @Test("first style mints vs1 and assigns it")
    func mintsFirstClass() {
        let (result, diags) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: graph(nodes: ["A"]))
        #expect(result.classDefs["vs1"] == greenSpec.classDefProperties)
        #expect(result.classAssignments["A"] == ["vs1"])
        #expect(diags.isEmpty)
    }

    @Test("identical style on a second node reuses the class")
    func dedup() {
        var g = graph(nodes: ["A", "B"])
        (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        let (result, _) = StyleClassManager.applyStyle(greenSpec, toNode: "B", in: g)
        #expect(result.classDefs.count == 1)
        #expect(result.classAssignments["B"] == ["vs1"])
    }

    @Test("restyling the sole member GCs the orphaned class")
    func garbageCollection() {
        var g = graph(nodes: ["A"])
        (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        let orange = NodeStyleSpec(fill: "#fff3e0")
        let (result, _) = StyleClassManager.applyStyle(orange, toNode: "A", in: g)
        #expect(result.classDefs["vs1"] == nil)
        #expect(result.classDefs["vs2"] == orange.classDefProperties)
        #expect(result.classAssignments["A"] == ["vs2"])
    }

    @Test("mint skips names taken by user classDefs")
    func skipsUserNames() {
        let g = graph(nodes: ["A"], classDefs: ["vs1": ["fill": "#123456"]])
        let (result, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        // "vs1" is occupied by a (user) class with different props → mint vs2.
        #expect(result.classDefs["vs2"] == greenSpec.classDefProperties)
        #expect(result.classAssignments["A"] == ["vs2"])
    }

    @Test("user-authored class assignments and defs survive restyling")
    func userClassesUntouched() {
        let g = graph(
            nodes: ["A"],
            classDefs: ["important": ["fill": "#ff0000"]],
            classAssignments: ["A": ["important"]]
        )
        let (result, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        #expect(result.classDefs["important"] == ["fill": "#ff0000"])
        #expect(result.classAssignments["A"] == ["important", "vs1"])
    }

    @Test("inline style migrates to generated class with info diagnostic")
    func inlineMigration() {
        let g = graph(nodes: ["A"], nodeStyles: ["A": ["fill": "#ff0000"]])
        let (result, diags) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        #expect(result.nodeStyles["A"] == nil)
        #expect(diags.count == 1)
        #expect(diags.first?.category == .styleClassMigration)
        #expect(diags.first?.severity == .info)
    }

    @Test("empty spec clears generated assignment and GCs")
    func clearStyling() {
        var g = graph(nodes: ["A"])
        (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
        let (result, _) = StyleClassManager.applyStyle(NodeStyleSpec(), toNode: "A", in: g)
        #expect(result.classDefs.isEmpty)
        #expect(result.classAssignments["A"] == nil)
    }

    @Test("effectiveStyle resolves classes then inline overrides")
    func effectiveStyleResolution() {
        let g = graph(
            nodes: ["A"],
            classDefs: ["vs1": ["fill": "#e8f5e9", "stroke": "#2e7d32"]],
            classAssignments: ["A": ["vs1"]],
            nodeStyles: ["A": ["fill": "#ffffff"]]
        )
        let spec = StyleClassManager.effectiveStyle(forNode: "A", in: g)
        #expect(spec.fill == "#ffffff")      // inline wins
        #expect(spec.stroke == "#2e7d32")    // class survives
    }

    @Test("effectiveStyle on unstyled node is empty")
    func effectiveStyleEmpty() {
        let spec = StyleClassManager.effectiveStyle(forNode: "A", in: graph(nodes: ["A"]))
        #expect(spec.isEmpty)
    }

    @Test("identical edit sequences produce identical graphs")
    func deterministicNaming() {
        func run() -> original_src_types.MermaidGraph {
            var g = graph(nodes: ["A", "B"])
            (g, _) = StyleClassManager.applyStyle(greenSpec, toNode: "A", in: g)
            (g, _) = StyleClassManager.applyStyle(NodeStyleSpec(fill: "#fff3e0"), toNode: "B", in: g)
            return g
        }
        let a = run(), b = run()
        #expect(a.classDefs == b.classDefs)
        #expect(a.classAssignments == b.classAssignments)
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter StyleClassManagerTests`
Expected: BUILD FAILURE — `cannot find 'StyleClassManager' in scope`.

- [ ] **Step 4: Write the implementation**

Create `Sources/DiagramKitInteractive/StyleClassManager.swift`:

```swift
// Visual editor — deduplicated generated-classDef lifecycle.
// Style edits from the visual editor land as shared `vsN` classDefs:
// one class per unique style, reused across nodes, orphans removed.
// User-authored classDefs are never edited or GC'd.

import DiagramKitCommon
import DiagramKitModel

public enum StyleClassManager {

    /// A classDef name is "generated" iff it is `vs` followed by one
    /// or more digits. A user who hand-writes such a name opts into
    /// generated-class semantics (documented in the design spec).
    public static func isGeneratedClassName(_ name: String) -> Bool {
        guard name.hasPrefix("vs") else { return false }
        let digits = name.dropFirst(2)
        return !digits.isEmpty && digits.allSatisfy(\.isNumber)
    }

    /// Apply `spec` to `nodeID`: migrate any inline style, drop the
    /// node's previous generated-class assignment, find-or-create the
    /// class matching `spec`, and garbage-collect orphaned generated
    /// classes. Pure — returns the updated graph.
    public static func applyStyle(
        _ spec: NodeStyleSpec,
        toNode nodeID: String,
        in graph: original_src_types.MermaidGraph
    ) -> (graph: original_src_types.MermaidGraph, diagnostics: [DiagramDiagnostic]) {
        var graph = graph
        var diagnostics: [DiagramDiagnostic] = []

        if graph.nodeStyles[nodeID] != nil {
            graph.nodeStyles.removeValue(forKey: nodeID)
            diagnostics.append(.informational(
                .styleClassMigration,
                message: "Inline 'style \(nodeID) …' replaced by a generated classDef assignment"
            ))
        }

        var assignments = graph.classAssignments[nodeID] ?? []
        assignments.removeAll(where: isGeneratedClassName)

        let props = spec.classDefProperties
        if !props.isEmpty {
            let reusable = graph.classDefs
                .filter { isGeneratedClassName($0.key) && $0.value == props }
                .keys
                .sorted()
                .first
            let className: String
            if let reusable {
                className = reusable
            } else {
                var n = 1
                while graph.classDefs["vs\(n)"] != nil { n += 1 }
                className = "vs\(n)"
                graph.classDefs[className] = props
            }
            assignments.append(className)
        }

        if assignments.isEmpty {
            graph.classAssignments.removeValue(forKey: nodeID)
        } else {
            graph.classAssignments[nodeID] = assignments
        }

        let referenced = Set(graph.classAssignments.values.flatMap { $0 })
            .union(graph.edgeClassAssignments.values)
            .union(graph.edges.flatMap { $0.classes ?? [] })
        for name in graph.classDefs.keys where isGeneratedClassName(name) && !referenced.contains(name) {
            graph.classDefs.removeValue(forKey: name)
        }

        return (graph, diagnostics)
    }

    /// Resolve the node's effective style for seeding the node menu:
    /// default classDef → assigned classes in order (later wins,
    /// matching mermaid-js) → inline `style` overrides.
    public static func effectiveStyle(
        forNode nodeID: String,
        in graph: original_src_types.MermaidGraph
    ) -> NodeStyleSpec {
        var merged: [String: String] = graph.defaultClassDef ?? [:]
        for className in graph.classAssignments[nodeID] ?? [] {
            if let def = graph.classDefs[className] {
                merged.merge(def) { _, new in new }
            }
        }
        if let inline = graph.nodeStyles[nodeID] {
            merged.merge(inline) { _, new in new }
        }
        return NodeStyleSpec(classDefProperties: merged)
    }
}
```

Note: if `DiagramDiagnostic.category` / `.severity` accessors used in the test have different property names, check `Sources/DiagramKitCommon/` (`DiagramDiagnostic` type) and adjust the *test* to the real accessor names — do not change the diagnostic type.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter StyleClassManagerTests`
Expected: PASS (11 tests).

Run: `Scripts/check-diagnostic-discipline.sh`
Expected: exit 0 (new category is emitted via the `.informational` factory only).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitCommon/DiagnosticCategory.swift Sources/DiagramKitInteractive/StyleClassManager.swift Tests/DiagramKitTests/Interactive/StyleClassManagerTests.swift docs/diagnostic-severity-discipline.md
git commit -m "Visual editor 1b — StyleClassManager + styleClassMigration diagnostic category"
```

---

### Task 3: `setNodeShape` mutation

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift` (new case + application + Equatable/Hashable/undoActionName)
- Modify: `Sources/DiagramKitInteractive/DiagramEditorError.swift` (add `unknownShapeAlias`)
- Test: `Tests/DiagramKitTests/Interactive/FlowchartNodeShapeMutationTests.swift`

**Interfaces:**
- Consumes: `original_src_types.NodeShape.resolve(alias:)`; existing `performFlowchart` plumbing.
- Produces: `FlowchartMutation.setNodeShape(of: DiagramSelection, toShape: String)` (alias string, matching `insertNode(type:)`'s convention — the spec's `to: NodeShape` is realized as an alias to keep `original_src_types` off the mutation surface); `DiagramEditorError.unknownShapeAlias(alias: String)`. Task 6 calls `performFlowchart(.setNodeShape(of:toShape:))`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/FlowchartNodeShapeMutationTests.swift`:

```swift
// Visual editor plan 1 — setNodeShape mutation.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .stateDiagram]
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock")
    }
}

private func flowDoc(_ nodes: [String]) -> DiagramDocument {
    let mNodes = nodes.map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    return DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(direction: .TD, nodesInOrder: mNodes, edges: [])
    ))
}

private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@Suite @MainActor
struct FlowchartNodeShapeMutationTests {

    @Test("setNodeShape changes an existing node's shape")
    func changesShape() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .diamond)
    }

    @Test("setNodeShape accepts v11 aliases")
    func v11Alias() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "docs"))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .stackedDocument)
    }

    @Test("unknown alias throws unknownShapeAlias and leaves state untouched")
    func unknownAlias() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "not-a-shape"))
        }
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .rectangle)
    }

    @Test("missing node throws elementNotFound")
    func missingNode() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))
        }
    }

    @Test("edge selection throws unknownElementKind")
    func edgeSelection() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "edge:A->B")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))
        }
    }

    @Test("undo restores the previous shape")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeShape(of: sel, toShape: "diamond"))
        editor.undoManager.undo()

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.first(where: { $0.id == "A" })?.node.shape == .rectangle)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter FlowchartNodeShapeMutationTests`
Expected: BUILD FAILURE — `type 'FlowchartMutation' has no member 'setNodeShape'`.

- [ ] **Step 3: Implement**

In `Sources/DiagramKitInteractive/DiagramEditorError.swift`, add a case to the `DiagramEditorError` enum (match the file's existing formatting/description pattern — it has cases like `duplicateNodeID(id: String)`):

```swift
    /// `setNodeShape` received an alias that `NodeShape.resolve` does
    /// not recognize.
    case unknownShapeAlias(alias: String)
```

If the enum has a `description`/`errorDescription` switch, add:

```swift
        case .unknownShapeAlias(let alias):
            return "Unknown node shape alias '\(alias)'"
```

In `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`:

1. Add the case to `FlowchartMutation` (after `setEdgeStyle`):

```swift
    /// Change the shape of an existing node. `toShape` is a Mermaid
    /// shape alias (same vocabulary as `insertNode(type:)`), resolved
    /// via `NodeShape.resolve(alias:)`. Throws `.unknownShapeAlias`
    /// for unrecognized aliases.
    case setNodeShape(of: DiagramSelection, toShape: String)
```

2. Add to `undoActionName`:

```swift
        case .setNodeShape:
            return "Change Node Shape"
```

3. Add to `==`:

```swift
        case (.setNodeShape(let aSel, let aShape), .setNodeShape(let bSel, let bShape)):
            return aSel == bSel && aShape == bShape
```

4. Add to `hash(into:)`:

```swift
        case .setNodeShape(let sel, let shape):
            hasher.combine(4)
            hasher.combine(sel)
            hasher.combine(shape)
```

5. Add to `_applyFlowchart`'s switch:

```swift
        case .setNodeShape(let selection, let alias):
            return (try _setFlowchartNodeShape(of: selection, toAlias: alias, into: document), [])
```

6. Add the implementation (below `_setFlowchartEdgeStyle`):

```swift
    func _setFlowchartNodeShape(
        of selection: DiagramSelection,
        toAlias alias: String,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        try _validateSelection(selection, matches: document)
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        guard selection.elementID.hasPrefix("node:") else {
            throw DiagramEditorError.unknownElementKind(id: selection.elementID)
        }
        let nodeID = String(selection.elementID.dropFirst(5))
        guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
            throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
        }
        guard let shape = original_src_types.NodeShape.resolve(alias: alias) else {
            throw DiagramEditorError.unknownShapeAlias(alias: alias)
        }
        model.nodesInOrder = model.nodesInOrder.map { entry in
            guard entry.id == nodeID else { return entry }
            var node = entry.node
            node.shape = shape
            return (id: entry.id, node: node)
        }
        doc.payload = .flowchart(model)
        return doc
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter FlowchartNodeShapeMutationTests`
Expected: PASS (6 tests).

Also run the neighboring suites to catch exhaustive-switch breakage:
`swift test --filter DiagramEditorFlowchartTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Sources/DiagramKitInteractive/DiagramEditorError.swift Tests/DiagramKitTests/Interactive/FlowchartNodeShapeMutationTests.swift
git commit -m "Visual editor 1c — setNodeShape flowchart mutation"
```

---

### Task 4: `setNodeStyle` mutation

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`
- Test: `Tests/DiagramKitTests/Interactive/FlowchartNodeStyleMutationTests.swift`

**Interfaces:**
- Consumes: `NodeStyleSpec` (Task 1), `StyleClassManager.applyStyle` (Task 2), `performFlowchart` plumbing.
- Produces: `FlowchartMutation.setNodeStyle(of: DiagramSelection, to: NodeStyleSpec)`. Task 6 calls `performFlowchart(.setNodeStyle(of:to:))`.

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/FlowchartNodeStyleMutationTests.swift`:

```swift
// Visual editor plan 1 — setNodeStyle mutation through StyleClassManager.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitExport
import DiagramKitImport
@testable import DiagramKitInteractive

private struct MockExporter: DiagramExporter {
    let name: String = "Mock"
    let formatID: DiagramFormatID = .mermaid
    let supportedDiagramTypes: Set<DiagramType> = [.flowchart, .stateDiagram]
    func export(_ document: DiagramDocument) throws -> DiagramExportResult {
        DiagramExportResult(source: "mock")
    }
}

private func flowDoc(
    _ nodes: [String],
    nodeStyles: [String: [String: String]] = [:]
) -> DiagramDocument {
    let mNodes = nodes.map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    return DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(
            direction: .TD, nodesInOrder: mNodes, edges: [], nodeStyles: nodeStyles
        )
    ))
}

private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

private let greenSpec = NodeStyleSpec(fill: "#e8f5e9", stroke: "#2e7d32")

@Suite @MainActor
struct FlowchartNodeStyleMutationTests {

    @Test("setNodeStyle creates classDef and assignment")
    func createsClass() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.classDefs["vs1"] == greenSpec.classDefProperties)
        #expect(model.classAssignments["A"] == ["vs1"])
    }

    @Test("inline-style migration surfaces the info diagnostic on the editor")
    func migrationDiagnosticSurfaces() async throws {
        let editor = makeEditor(flowDoc(["A"], nodeStyles: ["A": ["fill": "#ff0000"]]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))
        #expect(editor.lastExportDiagnostics.contains { $0.category == .styleClassMigration })
    }

    @Test("missing node throws elementNotFound")
    func missingNode() async {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:Z")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))
        }
    }

    @Test("undo restores previous classDefs and assignments")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        try await editor.performFlowchart(.setNodeStyle(of: sel, to: greenSpec))
        editor.undoManager.undo()

        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.classDefs.isEmpty)
        #expect(model.classAssignments.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter FlowchartNodeStyleMutationTests`
Expected: BUILD FAILURE — `type 'FlowchartMutation' has no member 'setNodeStyle'`.

- [ ] **Step 3: Implement**

In `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`:

1. `FlowchartMutation` case:

```swift
    /// Set the visual style of an existing node. Routed through
    /// `StyleClassManager`: the style lands as a shared generated
    /// classDef (`vsN`), deduplicated across nodes; an empty spec
    /// clears the node's generated styling.
    case setNodeStyle(of: DiagramSelection, to: NodeStyleSpec)
```

2. `undoActionName`:

```swift
        case .setNodeStyle:
            return "Style Node"
```

3. `==`:

```swift
        case (.setNodeStyle(let aSel, let aSpec), .setNodeStyle(let bSel, let bSpec)):
            return aSel == bSel && aSpec == bSpec
```

4. `hash(into:)`:

```swift
        case .setNodeStyle(let sel, let spec):
            hasher.combine(5)
            hasher.combine(sel)
            hasher.combine(spec)
```

5. `_applyFlowchart` switch:

```swift
        case .setNodeStyle(let selection, let spec):
            return try _setFlowchartNodeStyle(of: selection, to: spec, into: document)
```

6. Implementation:

```swift
    func _setFlowchartNodeStyle(
        of selection: DiagramSelection,
        to spec: NodeStyleSpec,
        into document: DiagramDocument
    ) throws -> (DiagramDocument, [DiagramDiagnostic]) {
        try _validateSelection(selection, matches: document)
        var doc = document
        guard case .flowchart(let model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        guard selection.elementID.hasPrefix("node:") else {
            throw DiagramEditorError.unknownElementKind(id: selection.elementID)
        }
        let nodeID = String(selection.elementID.dropFirst(5))
        guard model.nodesInOrder.contains(where: { $0.id == nodeID }) else {
            throw DiagramEditorError.elementNotFound(id: nodeID, kind: "node")
        }
        let (updated, diagnostics) = StyleClassManager.applyStyle(spec, toNode: nodeID, in: model)
        doc.payload = .flowchart(updated)
        return (doc, diagnostics)
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter FlowchartNodeStyleMutationTests`
Expected: PASS (4 tests). (If `DiagramDiagnostic` exposes its category under a different property name, fix the test accessor, not the source.)

Run: `swift test --filter DiagramEditorMutationTests` — Expected: PASS (no exhaustive-switch fallout).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Tests/DiagramKitTests/Interactive/FlowchartNodeStyleMutationTests.swift
git commit -m "Visual editor 1d — setNodeStyle flowchart mutation via StyleClassManager"
```

---

### Task 5: Exporter `@{ shape: … }` + properties metadata emission

**Files:**
- Modify: `Sources/DiagramKitModel/src_types.swift` (three missing `resolve` aliases + `CaseIterable`)
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift`
- Test: `Tests/DiagramKitTests/Export/MermaidFlowchartMetadataExportTests.swift`

**Interfaces:**
- Consumes: `original_src_types.NodeShape` (rawValues become the emitted `shape:` names), `original_src_types.NodeProperties` (`icon`, `form`, `pos`, `img`, `w`, `h`), `MermaidExportHelpers.escapeBracketLabel`, `MermaidImporter().parse(_:) -> DiagramImportResult`.
- Produces: exported flowchart source where the 15 classic shapes keep their bracket markers and every other shape is emitted as `id[label]@{ shape: <rawValue> }`; node `properties` (icon/img/w/h/pos/form) are emitted as additional metadata pairs. The `.lossyTransform(.shapeDowngrade, …)` path in this exporter is deleted.

- [ ] **Step 1: Close the `resolve(alias:)` gaps and add `CaseIterable`**

In `Sources/DiagramKitModel/src_types.swift`:

1. Change the enum declaration to `public enum NodeShape: String, Sendable, CaseIterable {`.
2. In `resolve(alias:)`, three rawValues currently do not resolve to themselves. Fix:
   - In the line `case "curbed-trapezoid", "curv-trap", "display": return .curvedTrapezoid` add `"curved-trapezoid"`:
     `case "curbed-trapezoid", "curved-trapezoid", "curv-trap", "display": return .curvedTrapezoid`
   - Add two new lines (near the other `state-*` cases):
     `case "state-start": return .stateStart`
     `case "state-end": return .stateEnd`

- [ ] **Step 2: Write the failing tests**

Create `Tests/DiagramKitTests/Export/MermaidFlowchartMetadataExportTests.swift`:

```swift
// Visual editor plan 1 — @{ shape:/properties } metadata emission.

import Testing
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport
import DiagramKitMermaid
@testable import DiagramKit

private func doc(_ nodes: [(String, original_src_types.MermaidNode)]) -> DiagramDocument {
    DiagramDocument(payload: .flowchart(
        original_src_types.MermaidGraph(
            direction: .TD,
            nodesInOrder: nodes.map { (id: $0.0, node: $0.1) },
            edges: []
        )
    ))
}

@Suite
struct MermaidFlowchartMetadataExportTests {

    @Test("every NodeShape rawValue resolves to itself")
    func rawValuesResolve() {
        for shape in original_src_types.NodeShape.allCases {
            #expect(
                original_src_types.NodeShape.resolve(alias: shape.rawValue) == shape,
                "rawValue '\(shape.rawValue)' does not resolve to itself"
            )
        }
    }

    @Test("classic shapes keep bracket markers")
    func classicMarkers() throws {
        let node = original_src_types.MermaidNode(id: "A", label: "Start", shape: .rounded)
        let result = try MermaidExporter().export(doc([("A", node)]))
        #expect(result.source.contains("A(Start)"))
        #expect(!result.source.contains("@{"))
    }

    @Test("non-classic shape emits @{ shape: } metadata with no shapeDowngrade")
    func metadataShape() throws {
        let node = original_src_types.MermaidNode(id: "C", label: "Files", shape: .stackedDocument)
        let result = try MermaidExporter().export(doc([("C", node)]))
        #expect(result.source.contains("C[Files]@{ shape: stacked-document }"))
        #expect(!result.diagnostics.contains { $0.category == .shapeDowngrade })
    }

    @Test("non-classic shape with empty label emits bare id + metadata")
    func metadataShapeNoLabel() throws {
        let node = original_src_types.MermaidNode(id: "C", label: "C", shape: .cloud)
        let result = try MermaidExporter().export(doc([("C", node)]))
        #expect(result.source.contains("C@{ shape: cloud }"))
    }

    @Test("icon properties are emitted and parse back")
    func iconProperties() throws {
        let node = original_src_types.MermaidNode(
            id: "I", label: "User", shape: .iconCircle,
            properties: original_src_types.NodeProperties(icon: "fa:user", pos: "b", h: 48)
        )
        let result = try MermaidExporter().export(doc([("I", node)]))
        let reparsed = try MermaidImporter().parse(result.source)
        guard case .flowchart(let graph) = reparsed.document.payload else {
            #expect(Bool(false)); return
        }
        let round = graph.nodesById["I"]
        #expect(round?.shape == .iconCircle)
        #expect(round?.properties?.icon == "fa:user")
        #expect(round?.properties?.pos == "b")
        #expect(round?.properties?.h == 48)
    }

    @Test("full non-classic shape round-trip: export then re-parse preserves shape")
    func shapeRoundTrip() throws {
        for shape in [original_src_types.NodeShape.cloud, .document, .windowPane, .bowTieRectangle, .stateStart, .curvedTrapezoid] {
            let node = original_src_types.MermaidNode(id: "N", label: "Label", shape: shape)
            let result = try MermaidExporter().export(doc([("N", node)]))
            let reparsed = try MermaidImporter().parse(result.source)
            guard case .flowchart(let graph) = reparsed.document.payload else {
                #expect(Bool(false)); return
            }
            #expect(graph.nodesById["N"]?.shape == shape, "shape \(shape) did not round-trip")
        }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `swift test --filter MermaidFlowchartMetadataExportTests`
Expected: FAIL — `metadataShape` and `shapeRoundTrip` fail (downgraded markers, `.shapeDowngrade` diagnostics); `rawValuesResolve` passes after Step 1.

- [ ] **Step 4: Implement the exporter change**

In `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift`:

1. Replace the `(open, close, lossy)` tuple with a two-form emission. Replace `shapeMarker(for:)` entirely with:

```swift
    /// Emission form for a `NodeShape`: the 15 classic flowchart
    /// shapes use their native bracket markers; every other shape is
    /// emitted as v11 `@{ shape: <rawValue> }` metadata, which the
    /// parser resolves back losslessly (`resolve(alias:)` accepts
    /// every rawValue).
    private enum ShapeEmission {
        case marker(open: String, close: String)
        case metadata(shapeName: String)
    }

    private static func shapeEmission(for shape: original_src_types.NodeShape) -> ShapeEmission {
        switch shape {
        case .rectangle: return .marker(open: "[", close: "]")
        case .rounded: return .marker(open: "(", close: ")")
        case .stadium: return .marker(open: "([", close: "])")
        case .subroutine: return .marker(open: "[[", close: "]]")
        case .cylinder: return .marker(open: "[(", close: ")]")
        case .diamond: return .marker(open: "{", close: "}")
        case .hexagon: return .marker(open: "{{", close: "}}")
        case .circle: return .marker(open: "((", close: "))")
        case .doublecircle: return .marker(open: "(((", close: ")))")
        case .trapezoid: return .marker(open: "[/", close: "/]")
        case .trapezoidAlt: return .marker(open: "[\\", close: "\\]")
        case .asymmetric: return .marker(open: ">", close: "]")
        case .ellipse: return .marker(open: "(-", close: "-)")
        case .parallelogram: return .marker(open: "[/", close: "\\]")
        case .parallelogramAlt: return .marker(open: "[\\", close: "/]")
        default: return .metadata(shapeName: shape.rawValue)
        }
    }

    /// Metadata pairs for a node's `@{ … }` block: the shape (when
    /// emission is metadata-form) plus any parser-visible
    /// `NodeProperties`. `properties.shape` and `.label` are skipped —
    /// shape comes from `node.shape`, the label from the bracket text.
    private static func metadataPairs(
        for node: original_src_types.MermaidNode,
        emission: ShapeEmission
    ) -> [String] {
        var pairs: [String] = []
        if case .metadata(let shapeName) = emission {
            pairs.append("shape: \(shapeName)")
        }
        guard let props = node.properties else { return pairs }
        if let icon = props.icon { pairs.append("icon: \"\(icon)\"") }
        if let form = props.form { pairs.append("form: \"\(form)\"") }
        if let pos = props.pos { pairs.append("pos: \"\(pos)\"") }
        if let img = props.img { pairs.append("img: \"\(img)\"") }
        if let w = props.w { pairs.append("w: \(formatNumber(w))") }
        if let h = props.h { pairs.append("h: \(formatNumber(h))") }
        return pairs
    }

    private static func formatNumber(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
```

2. In `emit(_:)`, replace the node-emission block (currently lines 52–67: `let shape = shapeMarker(for: node.shape)` through `lines.append(nodeLine)`) with:

```swift
                let emission = shapeEmission(for: node.shape)
                var nodeLine: String
                switch emission {
                case .marker(let open, let close):
                    if node.label.isEmpty || node.label == nodeId {
                        nodeLine = "  \(sanitizedId)\(open)\(close)"
                    } else {
                        let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(node.label)
                        diagnostics.append(contentsOf: escDiags)
                        nodeLine = "  \(sanitizedId)\(open)\(escaped)\(close)"
                    }
                case .metadata:
                    if node.label.isEmpty || node.label == nodeId {
                        nodeLine = "  \(sanitizedId)"
                    } else {
                        let (escaped, escDiags) = MermaidExportHelpers.escapeBracketLabel(node.label)
                        diagnostics.append(contentsOf: escDiags)
                        nodeLine = "  \(sanitizedId)[\(escaped)]"
                    }
                }
                let pairs = metadataPairs(for: node, emission: emission)
                if !pairs.isEmpty {
                    nodeLine += "@{ \(pairs.joined(separator: ", ")) }"
                }
                lines.append(nodeLine)
```

3. Delete the now-unused `shapeMarker(for:)` and the `.lossyTransform(.shapeDowngrade, …)` emission that referenced it. Note: keep the `.shapeDowngrade` category itself — the D2/DOT exporters still use it.

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter MermaidFlowchartMetadataExportTests`
Expected: PASS (6 tests).

- [ ] **Step 6: Run the blast-radius suites**

```bash
swift test --filter MermaidExporterTests
swift test --filter SameFormatRoundTripTests
swift test --filter CorpusRoundTripTests
swift test --filter LossPairingTests
```
Expected: all PASS. The Mermaid flowchart round-trip cell (`RoundTripCellRegistry.mermaidFlowchart`, `allowedLosses: [.idSanitization, .anonymousSubgraphRename]`) needs no change — this task removes losses, it doesn't add any. If a corpus entry now round-trips *more* faithfully and a fixture asserted the old downgraded output, update that fixture's expectation to the new faithful output.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitModel/src_types.swift Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidFlowchartExport.swift Tests/DiagramKitTests/Export/MermaidFlowchartMetadataExportTests.swift
git commit -m "Visual editor 1e — Mermaid exporter emits @{ shape:/properties } metadata; all NodeShapes round-trip"
```

---

### Task 6: Rebuild the node menu (sample app)

**Files:**
- Create: `Sources/DiagramKitSample/Views/Support/ColorHex.swift`
- Create: `Sources/DiagramKitSample/Views/Visual/NodeStyleControls.swift`
- Rewrite: `Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift`

**Interfaces:**
- Consumes: `store.performMutation(_: DiagramMutation)`, `store.performFlowchartMutation(_: FlowchartMutation)` (both `async throws`, `Sources/DiagramKitSample/Models/LiveEditorStore.swift:626/644`), `store.editor?.selection`, `store.editor?.document`, `store.editor?.beginUndoGrouping()/endUndoGrouping()`, `store.setVisualStage(_:)`, `store.boundsLookup?.label(for:)`, `StyleClassManager.effectiveStyle(forNode:in:)`, `NodeStyleSpec`, `FlowchartBorderStyle`, `A11yID.Visual.nodePopover`.
- Produces: UI only — no new APIs consumed by later tasks. (Plan 2 will replace the shape `Picker` with the catalog popover; keep the picker component small and self-contained for that swap.)

No automated UI tests (repo convention: canvas/popover SwiftUI views are untested). Verification is compile + manual smoke.

- [ ] **Step 1: Create the hex color bridge**

Create `Sources/DiagramKitSample/Views/Support/ColorHex.swift`:

```swift
//
//  ColorHex.swift
//  DiagramPlayground
//
//  SwiftUI.Color ↔ "#rrggbb" bridge for the node style controls.
//  NodeStyleSpec carries lowercase hex strings; ColorPicker speaks
//  Color. sRGB both ways.
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#else
import UIKit
#endif

extension Color {
    init?(hexRGB: String) {
        var hex = hexRGB.trimmingCharacters(in: .whitespaces).lowercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: 1
        )
    }

    var hexRGB: String? {
        #if canImport(AppKit)
        guard let converted = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int((converted.redComponent * 255).rounded())
        let g = Int((converted.greenComponent * 255).rounded())
        let b = Int((converted.blueComponent * 255).rounded())
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        let r = Int((red * 255).rounded())
        let g = Int((green * 255).rounded())
        let b = Int((blue * 255).rounded())
        #endif
        return String(format: "#%02x%02x%02x", r, g, b)
    }
}
```

- [ ] **Step 2: Create the style controls component**

Create `Sources/DiagramKitSample/Views/Visual/NodeStyleControls.swift`:

```swift
//
//  NodeStyleControls.swift
//  DiagramPlayground
//
//  Border + color controls for the node menu. Edits a NodeStyleSpec
//  draft; the popover commits it via FlowchartMutation.setNodeStyle.
//

import SwiftUI
import DiagramKitInteractive

struct NodeStyleControls: View {
    @Binding var borderStyle: FlowchartBorderStyle
    @Binding var fillColor: Color
    @Binding var strokeColor: Color
    @Binding var textColor: Color
    @Binding var styleDirty: Bool

    /// Theme-harmonized preset fills (fill, stroke, text).
    private static let presets: [(fill: String, stroke: String, text: String)] = [
        ("#e8f5e9", "#2e7d32", "#1b5e20"),  // green
        ("#fff3e0", "#ef6c00", "#e65100"),  // orange
        ("#ffebee", "#c62828", "#b71c1c"),  // red
        ("#e3f2fd", "#1565c0", "#0d47a1"),  // blue
        ("#f3e5f5", "#6a1b9a", "#4a148c"),  // purple
        ("#f4f4f5", "#a1a1aa", "#18181b"),  // zinc
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Border", selection: $borderStyle) {
                ForEach(FlowchartBorderStyle.allCases, id: \.self) { style in
                    Text(style.rawValue.capitalized).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: borderStyle) { styleDirty = true }

            Grid(alignment: .leading, verticalSpacing: 6) {
                GridRow {
                    Text("Background").font(.system(size: 11))
                    ColorPicker("", selection: $fillColor, supportsOpacity: false)
                        .labelsHidden()
                }
                GridRow {
                    Text("Border color").font(.system(size: 11))
                    ColorPicker("", selection: $strokeColor, supportsOpacity: false)
                        .labelsHidden()
                }
                GridRow {
                    Text("Text color").font(.system(size: 11))
                    ColorPicker("", selection: $textColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            .onChange(of: fillColor) { styleDirty = true }
            .onChange(of: strokeColor) { styleDirty = true }
            .onChange(of: textColor) { styleDirty = true }

            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.fill) { preset in
                    Button {
                        fillColor = Color(hexRGB: preset.fill) ?? fillColor
                        strokeColor = Color(hexRGB: preset.stroke) ?? strokeColor
                        textColor = Color(hexRGB: preset.text) ?? textColor
                        styleDirty = true
                    } label: {
                        Circle()
                            .fill(Color(hexRGB: preset.fill) ?? .gray)
                            .stroke(Color(hexRGB: preset.stroke) ?? .gray, lineWidth: 2)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Preset \(preset.fill)")
                }
            }
        }
    }
}
```

- [ ] **Step 3: Rewrite the popover**

Replace the full contents of `Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift` with:

```swift
//
//  NodeEditPopover.swift
//  DiagramPlayground
//
//  Node menu — label, shape, border, and colors. Commits through
//  DiagramMutation.setLabel + FlowchartMutation.setNodeShape /
//  .setNodeStyle inside one undo group. Style edits land in the
//  source as deduplicated `vsN` classDefs (StyleClassManager).
//

import SwiftUI
import DiagramKitInteractive
import DiagramKitModel

struct NodeEditPopover: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var initialLabel: String = ""
    @SwiftUI.State private var shapeAlias: String = "rectangle"
    @SwiftUI.State private var initialShapeAlias: String = "rectangle"
    @SwiftUI.State private var borderStyle: FlowchartBorderStyle = .solid
    @SwiftUI.State private var fillColor: Color = Color(hexRGB: "#f4f4f5") ?? .white
    @SwiftUI.State private var strokeColor: Color = Color(hexRGB: "#a1a1aa") ?? .gray
    @SwiftUI.State private var textColor: Color = Color(hexRGB: "#18181b") ?? .black
    @SwiftUI.State private var styleDirty: Bool = false
    @SwiftUI.State private var hadStyle: Bool = false

    /// Classic flowchart shapes offered until the plan-2 catalog
    /// replaces this picker. Aliases resolve via NodeShape.resolve.
    private static let shapeChoices: [(alias: String, label: String)] = [
        ("rectangle", "Rectangle"), ("rounded", "Rounded"), ("stadium", "Stadium"),
        ("subroutine", "Subroutine"), ("cylinder", "Cylinder"), ("diamond", "Diamond"),
        ("hexagon", "Hexagon"), ("circle", "Circle"), ("doublecircle", "Double Circle"),
        ("trapezoid", "Trapezoid"), ("trapezoid-alt", "Trapezoid Alt"),
        ("asymmetric", "Asymmetric"), ("ellipse", "Ellipse"),
        ("parallelogram", "Parallelogram"), ("parallelogram-alt", "Parallelogram Alt"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Edit node")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let selection = store.editor?.selection {
                    Text(selection.elementID)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Label", text: $labelDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Picker("Shape", selection: $shapeAlias) {
                ForEach(currentShapeChoices, id: \.alias) { choice in
                    Text(choice.label).tag(choice.alias)
                }
            }
            .font(.system(size: 11))

            NodeStyleControls(
                borderStyle: $borderStyle,
                fillColor: $fillColor,
                strokeColor: $strokeColor,
                textColor: $textColor,
                styleDirty: $styleDirty
            )

            if hadStyle {
                Button("Clear styling", action: clearStyling)
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button(role: .destructive, action: deleteSelected) {
                    Label("Delete", systemImage: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                Spacer()
                Button("Cancel") {
                    store.setVisualStage(.nodeSelected)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                Button("Commit") {
                    commit()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(labelDraft.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .accessibilityIdentifier(A11yID.Visual.nodePopover)
        .onAppear {
            seedDraftFromSelection()
        }
    }

    /// The classic list, plus the node's current shape when it is
    /// not classic (so opening + committing never clobbers a v11
    /// shape the user set in source).
    private var currentShapeChoices: [(alias: String, label: String)] {
        if Self.shapeChoices.contains(where: { $0.alias == shapeAlias }) {
            return Self.shapeChoices
        }
        return Self.shapeChoices + [(alias: shapeAlias, label: shapeAlias)]
    }

    private func currentNode() -> original_src_types.MermaidNode? {
        guard
            let selection = store.editor?.selection,
            selection.elementID.hasPrefix("node:"),
            case .flowchart(let graph) = store.editor?.document.payload
        else { return nil }
        return graph.nodesById[String(selection.elementID.dropFirst(5))]
    }

    private func currentGraph() -> original_src_types.MermaidGraph? {
        guard case .flowchart(let graph) = store.editor?.document.payload else { return nil }
        return graph
    }

    private func seedDraftFromSelection() {
        guard let selection = store.editor?.selection else { return }
        if let label = store.boundsLookup?.label(for: selection) {
            labelDraft = label
            initialLabel = label
        }
        guard let node = currentNode(), let graph = currentGraph() else { return }
        shapeAlias = node.shape.rawValue
        initialShapeAlias = node.shape.rawValue

        let spec = StyleClassManager.effectiveStyle(forNode: node.id, in: graph)
        hadStyle = !spec.isEmpty
        borderStyle = spec.borderStyle ?? .solid
        if let fill = spec.fill, let color = Color(hexRGB: fill) { fillColor = color }
        if let stroke = spec.stroke, let color = Color(hexRGB: stroke) { strokeColor = color }
        if let text = spec.textColor, let color = Color(hexRGB: text) { textColor = color }
        styleDirty = false
    }

    private func draftSpec() -> NodeStyleSpec {
        NodeStyleSpec(
            fill: fillColor.hexRGB,
            stroke: strokeColor.hexRGB,
            textColor: textColor.hexRGB,
            borderStyle: borderStyle
        )
    }

    private func commit() {
        guard let selection = store.editor?.selection, let editor = store.editor else { return }
        let labelChanged = labelDraft != initialLabel
        let shapeChanged = shapeAlias != initialShapeAlias
        let spec = draftSpec()
        Task {
            editor.beginUndoGrouping()
            defer { editor.endUndoGrouping() }
            if labelChanged {
                try? await store.performMutation(.setLabel(of: selection, to: labelDraft))
            }
            if shapeChanged {
                try? await store.performFlowchartMutation(.setNodeShape(of: selection, toShape: shapeAlias))
            }
            if styleDirty {
                try? await store.performFlowchartMutation(.setNodeStyle(of: selection, to: spec))
            }
        }
        store.setVisualStage(.nodeSelected)
    }

    private func clearStyling() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performFlowchartMutation(.setNodeStyle(of: selection, to: NodeStyleSpec()))
        }
        store.setVisualStage(.nodeSelected)
    }

    private func deleteSelected() {
        guard let selection = store.editor?.selection else { return }
        Task {
            try? await store.performMutation(.deleteElement(selection))
        }
        store.setVisualStage(.idle)
    }
}
```

Note: the old popover's sub-label field and style chips are removed (chips were dead UI; sub-label editing had no mutation). If `SubLabel` removal breaks a caller, check `Views/Visual/` usages — `NodeEditPopover` is only instantiated from the visual pane.

- [ ] **Step 4: Build**

Run: `swift build`
Expected: builds clean (warnings only if pre-existing). Fix any `onChange` signature mismatch per the toolchain (macOS 26 floor supports the zero-parameter `onChange(of:_:)` form used above).

- [ ] **Step 5: Manual smoke check**

Run: `swift run DiagramKitSample`
- Open a flowchart in the visual pane, double-click a node.
- Change background color, commit → the source pane gains `classDef vs1 …` and `:::vs1` (or a `class` line) on that node.
- Style a second node identically → no second classDef appears.
- Change the first node's color → `vs2` appears; if `vs1` orphaned, it disappears.
- Change shape to Diamond → node marker in source becomes `{…}`.
- Undo once → the whole popover commit reverts as one step.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/Support/ColorHex.swift Sources/DiagramKitSample/Views/Visual/NodeStyleControls.swift Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift
git commit -m "Visual editor 1f — node menu: shape, border, and color controls wired to mutations"
```

---

### Task 7: Corpus entry, snapshots, docs, gates (closer)

**Files:**
- Modify: `Sources/DiagramKitSample/Resources/test-diagrams.json`
- Create: recorded baselines under `Tests/DiagramKitTests/__Snapshots__/`
- Modify: `BASELINES.md`, `CLAUDE.md` (counts)

**Interfaces:** none produced; this task locks the new exporter/styling behavior into the corpus + snapshot gates.

- [ ] **Step 1: Add the corpus entry**

In `Sources/DiagramKitSample/Resources/test-diagrams.json`, find the highest existing `flow-N-` id (`grep -o '"flow-[0-9]*' Sources/DiagramKitSample/Resources/test-diagrams.json | sort -u`) and use the next integer N. Append to the `diagrams` array (after the last flowchart-category entry), with N substituted:

```json
{
  "id": "flow-N-visual-styles",
  "category": "flowchart",
  "name": "Visual Editor Generated Styles",
  "source": "graph TD\n  A[Start]:::vs1 --> B{Decide}:::vs2\n  B --> C[Files]@{ shape: stacked-document }\n  C --> D[Done]:::vs1\n  classDef vs1 fill:#e8f5e9,stroke:#2e7d32,color:#1b5e20\n  classDef vs2 fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:5 5"
}
```

Bump both counters by 1: `_counts.flowchart` (42 → 43) and `metadata.counts.flowchart` (50 → 51) — they intentionally differ; preserve the offset.

- [ ] **Step 2: Verify corpus integrity suites**

```bash
swift test --filter CorpusEntryFormatIDTests
swift test --filter CorpusMultiFormatTests
swift test --filter CorpusRoundTripTests
```
Expected: all PASS (the new entry round-trips with no disallowed losses — that is the point of this entry).

- [ ] **Step 3: Record snapshots for the new entry**

```bash
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=flow-N-visual-styles swift test --filter CorpusSnapshotTests
```
(substitute the chosen N). Expected: records exactly 3 new baselines (1 SVG `.txt`, 1 image `.png`, 1 ASCII `.txt`). Then verify non-record mode passes:

```bash
SNAPSHOT_DIAGRAM_IDS=flow-N-visual-styles swift test --filter CorpusSnapshotTests
```
Expected: PASS. (Known caveat: the *full* CorpusSnapshotTests run has a pre-existing signal-10; always use `SNAPSHOT_DIAGRAM_IDS`.)

- [ ] **Step 4: Update baseline docs**

- `BASELINES.md`: corpus 426 → 427 entries; snapshots 439 SVG → 440, 439 image → 440, 426 ASCII → 427 (total 1304 → 1307; on-disk 437 PNG → 438, 861 `.txt` → 863). Match the file's existing phrasing.
- `CLAUDE.md`: same counts appear in "Testing And Snapshots" (426/439/439/426/1304/437/861) and the corpus line in "Forward Roadmap" says 424 — set both mentions to 427 (fixing the stale 424 while there).

- [ ] **Step 5: Run the discipline gates**

```bash
Scripts/check-file-sizes.sh
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh
swift test --filter "RoundTrip"
```
Expected: all exit 0 / PASS. If Docker/Podman is not running, record `linux-check.sh` as environment-skipped (do not run it as part of this task; strict-concurrency build is exercised by `swift build` in Task 6).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Resources/test-diagrams.json Tests/DiagramKitTests/__Snapshots__/ BASELINES.md CLAUDE.md
git commit -m "Visual editor 1g — corpus entry + snapshots for generated classDefs and @{ shape: } metadata"
```

---

## Plan Self-Review (done at authoring time)

- **Spec coverage:** Section 1 `setNodeShape`/`setNodeStyle` → Tasks 3–4; Section 1 exporter enhancement → Task 5; Section 2 StyleClassManager (dedup, GC, user-class protection, inline migration, deterministic naming, effective-style resolution) → Task 2; Section 3 node-menu portion → Task 6; Section 7 testing (mutation suites, StyleClassManagerTests, round-trip, corpus/snapshots) → Tasks 1–5, 7. Icon/image *emission* is included in Task 5 per Section 8's decomposition note ("1 unlocks 4–5"); icon/image *mutations and rendering* are plans 4–5.
- **Deviations from spec, intentional:** `setNodeShape(of:toShape: String)` uses an alias string instead of the spec table's `NodeShape` value, matching `insertNode(type:)` and keeping `original_src_types` off the mutation surface. New `DiagramEditorError.unknownShapeAlias` case (spec's error contract said "unchanged"; this is a strict addition for a new failure mode).
- **Type consistency:** `NodeStyleSpec`/`FlowchartBorderStyle`/`StyleClassManager.applyStyle`/`effectiveStyle` names match across Tasks 1, 2, 4, 6; `setNodeShape(of:toShape:)` matches between Tasks 3 and 6; `hasher.combine(4)`/`(5)` discriminators follow the existing 0–3.
- **Known soft spots called out inline:** `DiagramDiagnostic` accessor names (Tasks 2/4 note: fix the test, not the type), `onChange` signature (Task 6 Step 4), corpus id N (Task 7 Step 1 determines it), `_counts` vs `metadata.counts` offset (Task 7 Step 1).
