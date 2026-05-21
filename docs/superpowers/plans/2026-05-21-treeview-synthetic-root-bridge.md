# treeView Synthetic-Root Bridge — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `TreeViewDiagram.root` carry a single documented convention (synthetic `/` at level -1 means "Mermaid multi-root container") and update the four cross-format exporters + the D2/DOT importers to honor it. Close the Wave H Mermaid ↔ PlantUML treeView deferral and the silently-skipping Mermaid ↔ D2/DOT treeView fixtures.

**Architecture:** Documented convention (no payload-model change). Each exporter detects `root.name == "/" && root.level == -1` on entry and branches: Mermaid + D2 + DOT handle both shapes losslessly; PlantUML drops sibling roots with a typed diagnostic. D2 and DOT importers add a multi-root branch that synthesizes the synthetic `/` container so Mermaid → D2/DOT → Mermaid round-trips losslessly. One new `RoundTripLoss.syntheticRootFlattened` case (PlantUML-only trigger).

**Tech Stack:** Swift 6 / Swift Package Manager. swift-testing for new test cases. The existing `RoundTripHarness` and `RoundTripFixtureLoader` for cross-format coverage. `Scripts/check-diagnostic-discipline.sh` for typed-factory enforcement.

**Spec:** [`docs/superpowers/specs/2026-05-21-treeview-synthetic-root-bridge-design.md`](../specs/2026-05-21-treeview-synthetic-root-bridge-design.md)

---

## File map

| Slice | File | Action |
|-------|------|--------|
| Model | `Sources/DiagramKitModel/src_treeview_types.swift` | Add doc-comment on `TreeViewDiagram` + `TreeViewNode` defining the canonical convention |
| Test support | `Sources/DiagramKitTestSupport/RoundTripLoss.swift` | Add `.syntheticRootFlattened` case + matching `RoundTripLossKind` |
| Mermaid exporter | `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift` | Convention-aware branch in `emit(_:)` |
| D2 exporter | `Sources/DiagramKitD2/D2TreeViewExporter.swift` | Forest emission for synthetic-root payloads |
| DOT exporter | `Sources/DiagramKitGraphviz/DOTTreeViewExport.swift` | Forest emission for synthetic-root payloads |
| PlantUML exporter | `Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift` | Effective-root selection + `.featureDropped` per dropped sibling |
| D2 importer | `Sources/DiagramKitD2/D2TreeViewMapper.swift` | Multi-root branch synthesizes `/` container |
| DOT importer | `Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift` | Same shape as D2 importer |
| Fixtures (rename) | `Tests/.../cross-mermaid-{d2,dot}-treeView/01-basic.mermaid` → `.mmd` | Unblock silent skip |
| Fixtures (new, cross) | `Tests/.../cross-mermaid-d2-treeView/02-multi-root.mmd` | Multi-root Mermaid → D2 → Mermaid |
| Fixtures (new, cross) | `Tests/.../cross-mermaid-dot-treeView/02-multi-root.mmd` | Multi-root Mermaid → DOT → Mermaid |
| Fixtures (new, cross) | `Tests/.../cross-mermaid-plantuml-treeView/{01-basic.mmd,02-multi-root.mmd}` | Mermaid → PlantUML (single + multi-root with drop) |
| Fixtures (new, cross) | `Tests/.../cross-plantuml-mermaid-treeView/01-basic.puml` | PlantUML → Mermaid |
| Fixtures (new, same) | `Tests/.../d2-treeView/02-multi-root.d2` | Same-format D2 multi-root |
| Fixtures (new, same) | `Tests/.../dot-treeView/02-multi-root.dot` | Same-format DOT multi-root |
| Test harness | `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift` | Two new Mermaid ↔ PlantUML methods; delete `:837-844` masking comment |
| Cross registry | `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift` | Two new constants for Mermaid ↔ PlantUML treeView; refresh Wave H comment block |
| Sidecar (new) | `Tests/.../cross-mermaid-plantuml-treeView/02-multi-root.json` | Per-fixture sidecar admitting `.syntheticRootFlattened` |
| Coverage doc | `COVERAGE.md` | Wave I closer paragraph; update cross-format pairs line; update fixture totals |

No new files in `Sources/`. All Sources changes are localized edits.

---

## Task 1: Add `RoundTripLoss.syntheticRootFlattened` case

**Files:**
- Modify: `Sources/DiagramKitTestSupport/RoundTripLoss.swift`
- Test: covered transitively by Task 5 PlantUML diagnostic test; no dedicated unit test needed since the case is a pure data enum.

- [ ] **Step 1: Add the enum case**

Edit `Sources/DiagramKitTestSupport/RoundTripLoss.swift`. After the existing `case deploymentLegendDropped` (line 25):

```swift
    /// Mermaid multi-root treeView input (synthetic `/` container with 2+
    /// children) was flattened on export to a format that cannot represent
    /// multi-root payloads (currently only PlantUML WBS), dropping all but
    /// the first sibling.
    case syntheticRootFlattened
```

- [ ] **Step 2: Add the kind mapping**

In the same file, in the `kind` switch (line 27 area), add a new branch BEFORE the closing brace:

```swift
        case .syntheticRootFlattened: return .syntheticRootFlattened
```

- [ ] **Step 3: Add the description mapping**

In the `description` switch (line 49 area), add:

```swift
        case .syntheticRootFlattened:
            return "syntheticRootFlattened"
```

- [ ] **Step 4: Add to `RoundTripLossKind`**

In the `RoundTripLossKind` enum (line 92 area), append `syntheticRootFlattened` to the comma-separated case list. Final state:

```swift
public enum RoundTripLossKind: String, Hashable, Sendable, CaseIterable, Codable {
    case idSanitization, shapeDowngrade, subgraphFlatten, boundaryFlatten
    case c4SlotDrop, titleDrop, configDrop, styleDrop
    case accessibilityDrop, anonymousSubgraphRename, d2DuplicateOverride
    case classStereotypeDrop, stateActionDrop, cardinalityDrop
    case deploymentShapeFlattened, deploymentDecorationDropped, deploymentLegendDropped
    case syntheticRootFlattened
}
```

- [ ] **Step 5: Verify the test support target compiles**

Run:
```bash
swift build --target DiagramKitTestSupport
```
Expected: clean build (any switch-exhaustiveness errors in other code would surface here).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitTestSupport/RoundTripLoss.swift
git commit -m "Add RoundTripLoss.syntheticRootFlattened case (Wave I)"
```

---

## Task 2: Document the canonical convention on `TreeViewDiagram` / `TreeViewNode`

**Files:**
- Modify: `Sources/DiagramKitModel/src_treeview_types.swift`

This is documentation only — no behavior change, no test.

- [ ] **Step 1: Add doc-comment on `TreeViewNode`**

In `src_treeview_types.swift`, prepend the existing `public struct TreeViewNode: Sendable, Equatable {` declaration (line 10) with:

```swift
/// One node in a `TreeViewDiagram`.
///
/// `level` is the depth at which the node appears: real user-visible nodes
/// start at `0` and increment with nesting. The single exception is the
/// **synthetic-root sentinel** described on `TreeViewDiagram` — a
/// `TreeViewNode` with `name == "/"` AND `level == -1` is the Mermaid
/// parser's multi-root container and has no source counterpart.
```

- [ ] **Step 2: Add doc-comment on `TreeViewDiagram`**

Prepend the `public struct TreeViewDiagram: Sendable, Equatable {` declaration (line 58) with:

```swift
/// Canonical payload for treeView diagrams across every importer.
///
/// `root` represents the user-visible root structure with one sentinel:
///
/// > A `root` whose `name == "/"` AND `level == -1` is a **synthetic
/// > multi-root container** introduced by the Mermaid treeView parser to
/// > host two or more sibling roots declared at level 0. Its children are
/// > the user-visible roots; the container itself has no source counterpart.
///
/// All other importers (D2, DOT, PlantUML) produce a `TreeViewDiagram`
/// whose `root` is the actual user-visible root at level 0 — no synthetic
/// container.
///
/// Exporters detect the convention on entry and adapt:
/// - `MermaidTreeViewExport` accepts both shapes.
/// - `D2TreeViewExport` / `DOTTreeViewExport` strip the synthetic root and
///   emit children as a top-level forest (lossless).
/// - `PlantUMLTreeViewExporter` emits the first child as the WBS `*` root
///   and drops additional siblings with `.featureDropped(.slotUnsupported,
///   …)` per drop.
```

- [ ] **Step 3: Verify build**

```bash
swift build --target DiagramKitModel
```
Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitModel/src_treeview_types.swift
git commit -m "Document TreeViewDiagram synthetic-root convention (Wave I)"
```

---

## Task 3: Mermaid exporter — accept real-root payloads

**Files:**
- Modify: `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift`
- Test: `Tests/DiagramKitTests/Mermaid/MermaidTreeViewExportTests.swift` (create new file)

The existing single-root path walks `model.root.children`. For real-root payloads (no synthetic), this drops the root itself. New branch emits the root as the first top-level entry then descends.

- [ ] **Step 1: Write failing tests**

Create `Tests/DiagramKitTests/Mermaid/MermaidTreeViewExportTests.swift`:

```swift
import Testing
import DiagramKitModel
@testable import DiagramKitMermaid

@Suite("MermaidTreeViewExport convention bridging")
struct MermaidTreeViewExportTests {

    @Test("synthetic-root payload emits children only (existing behavior)")
    func syntheticRootEmitsChildrenOnly() throws {
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory,
            children: [
                TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory,
                             children: [TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)])
            ]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic])
        let result = try MermaidTreeViewExport.emit(diagram)
        let lines = result.source.split(separator: "\n").map(String.init)
        #expect(lines.contains("treeView-beta"))
        #expect(lines.contains("    alpha/"))
        #expect(lines.contains("        leaf"))
        #expect(!lines.contains("/"), "synthetic / must never appear in output")
    }

    @Test("real-root payload emits root then descendants")
    func realRootEmitsRoot() throws {
        // Simulates a D2/DOT/PlantUML-imported payload: root at level 0.
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(
            id: 1, level: 0, name: "alpha", nodeType: .directory,
            children: [leaf]
        )
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try MermaidTreeViewExport.emit(diagram)
        let lines = result.source.split(separator: "\n").map(String.init)
        #expect(lines.contains("treeView-beta"))
        #expect(lines.contains("alpha/"), "real root must appear at indent 0")
        #expect(lines.contains("    leaf"), "leaf must be indented one level")
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
swift test --filter MermaidTreeViewExportTests
```
Expected: `realRootEmitsRoot` FAILS — `alpha/` not in output because the exporter currently walks `root.children` and drops the root itself.

- [ ] **Step 3: Add the convention branch**

Edit `Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift`. Replace the body of `emit(_:)` lines 18-38 with:

```swift
    static func emit(_ model: TreeViewDiagram) throws -> DiagramExportResult {
        var lines: [String] = ["treeView-beta"]
        let diagnostics: [DiagramDiagnostic] = []

        // The treeView grammar does not recognise a `title` keyword
        // nor accessibility metadata; skip them.
        _ = model.diagramTitle
        _ = model.accTitle
        _ = model.accDescr

        // Convention detection: synthetic `/` at level -1 means "Mermaid
        // multi-root container" — emit children as top-level entries. A
        // real root at level 0 (D2/DOT/PlantUML payloads) emits the root
        // itself as the first top-level entry. See TreeViewDiagram docs.
        let isSyntheticRoot = (model.root.name == "/" && model.root.level == -1)
        let topLevelRoots: [TreeViewNode] = isSyntheticRoot
            ? model.root.children
            : [model.root]

        let treeLines = MermaidExportHelpers.emitIndentedTree(
            roots: topLevelRoots,
            indentUnit: "    ",
            childrenOf: { $0.children },
            emitNode: { node, _ in [renderLine(node)] }
        )
        lines.append(contentsOf: treeLines)

        let source = lines.joined(separator: "\n") + "\n"
        return DiagramExportResult(source: source, diagnostics: diagnostics)
    }
```

- [ ] **Step 4: Re-run tests, verify pass**

```bash
swift test --filter MermaidTreeViewExportTests
```
Expected: both tests PASS.

- [ ] **Step 5: Verify Mermaid same-format treeView round-trip still passes**

```bash
swift test --filter MermaidTreeViewRoundTrip
```
Expected: PASS (synthetic-root branch is byte-identical to today's behavior; same-format Mermaid input always has synthetic `/`).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitMermaid/Exporter/MermaidExport/MermaidTreeViewExport.swift Tests/DiagramKitTests/Mermaid/MermaidTreeViewExportTests.swift
git commit -m "Mermaid treeView exporter: accept real-root payloads (Wave I)"
```

---

## Task 4: D2 exporter — emit forest for synthetic-root payloads

**Files:**
- Modify: `Sources/DiagramKitD2/D2TreeViewExporter.swift`
- Test: `Tests/DiagramKitTests/D2/D2TreeViewExportConventionTests.swift` (create new file)

D2 supports forest natively (multiple zero-in-degree nodes coexist). The existing path emits `tree.root.name` verbatim, which for synthetic `/` would emit a literal `/` node. The fix emits each child as a top-level declaration, with the `treeRoot` marker firing only on the first child.

- [ ] **Step 1: Write failing tests**

Create `Tests/DiagramKitTests/D2/D2TreeViewExportConventionTests.swift`:

```swift
import Testing
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2 treeView exporter — convention bridging")
struct D2TreeViewExportConventionTests {

    @Test("real-root payload emits root verbatim (existing behavior)")
    func realRootVerbatim() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try D2TreeViewExport.emit(diagram, title: nil)
        let src = result.source
        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"))
        #expect(src.contains("alpha: \"alpha\""))
        #expect(src.contains("alpha -> leaf"))
        #expect(!src.contains("/: \"/\""), "synthetic / must never appear")
    }

    @Test("synthetic-root payload emits forest with first-child marker")
    func syntheticRootForest() throws {
        let a = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .file)
        let b = TreeViewNode(id: 2, level: 0, name: "beta", nodeType: .file)
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [a, b]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, a, b])
        let result = try D2TreeViewExport.emit(diagram, title: nil)
        let src = result.source

        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"), "marker pins the first child")
        #expect(src.contains("alpha: \"alpha\""))
        #expect(src.contains("beta: \"beta\""))
        #expect(!src.contains("/: \"/\""), "synthetic / must never appear")
        // Forest emission: NO `alpha -> beta` edge, the children are separate roots.
        #expect(!src.contains("alpha -> beta"))
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
swift test --filter D2TreeViewExportConventionTests
```
Expected: `syntheticRootForest` FAILS — source contains `/: "/"` because the current code emits `tree.root.name` verbatim.

- [ ] **Step 3: Add the convention branch**

Edit `Sources/DiagramKitD2/D2TreeViewExporter.swift`. Replace the body of `emit(_:title:)` lines 15-32 with:

```swift
    static func emit(_ tree: TreeViewDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append(D2RecoveryMarker.emitFamily("treeView"))
        if let t = title, !t.isEmpty {
            lines.append("# title: \(singleLine(t))")
        }

        // Convention detection: synthetic `/` at level -1 means "Mermaid
        // multi-root container". Emit each child as a top-level forest
        // declaration; D2 supports multiple zero-in-degree nodes natively.
        // The tree-root marker fires on the FIRST child only (ordering
        // hint for the importer; see D2TreeViewMapper multi-root path).
        let isSyntheticRoot = (tree.root.name == "/" && tree.root.level == -1)
        let topLevelRoots: [TreeViewNode] = isSyntheticRoot ? tree.root.children : [tree.root]

        if let first = topLevelRoots.first {
            lines.append(D2RecoveryMarker.emitTreeRoot(first.name))
        }
        for root in topLevelRoots {
            emitNode(root, lines: &lines, diagnostics: &diagnostics)
            emitEdges(parent: root, lines: &lines)
        }

        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }
```

- [ ] **Step 4: Re-run tests, verify pass**

```bash
swift test --filter D2TreeViewExportConventionTests
```
Expected: both tests PASS.

- [ ] **Step 5: Verify D2 same-format treeView round-trip still passes**

```bash
swift test --filter D2TreeViewRoundTrip
```
Expected: PASS (same-format D2 inputs always have real root, so single-root path is taken — byte-identical to today).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitD2/D2TreeViewExporter.swift Tests/DiagramKitTests/D2/D2TreeViewExportConventionTests.swift
git commit -m "D2 treeView exporter: forest emission for synthetic-root (Wave I)"
```

---

## Task 5: DOT exporter — emit forest for synthetic-root payloads

**Files:**
- Modify: `Sources/DiagramKitGraphviz/DOTTreeViewExport.swift`
- Test: `Tests/DiagramKitTests/Graphviz/DOTTreeViewExportConventionTests.swift` (create new file)

Same shape as Task 4 for DOT.

- [ ] **Step 1: Write failing tests**

Create `Tests/DiagramKitTests/Graphviz/DOTTreeViewExportConventionTests.swift`:

```swift
import Testing
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOT treeView exporter — convention bridging")
struct DOTTreeViewExportConventionTests {

    @Test("real-root payload emits root verbatim (existing behavior)")
    func realRootVerbatim() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try DOTTreeViewExport.emit(diagram, title: nil)
        let src = result.source
        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"))
        #expect(src.contains("alpha [label=\"alpha\"];"))
        #expect(src.contains("alpha -> leaf;"))
        #expect(!src.contains("[label=\"/\"]"), "synthetic / must never appear")
    }

    @Test("synthetic-root payload emits forest with first-child marker")
    func syntheticRootForest() throws {
        let a = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .file)
        let b = TreeViewNode(id: 2, level: 0, name: "beta", nodeType: .file)
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [a, b]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, a, b])
        let result = try DOTTreeViewExport.emit(diagram, title: nil)
        let src = result.source

        #expect(src.contains("# diagramkit:family=treeView"))
        #expect(src.contains("# diagramkit:tree-root=alpha"), "marker pins the first child")
        #expect(src.contains("alpha [label=\"alpha\"];"))
        #expect(src.contains("beta [label=\"beta\"];"))
        #expect(!src.contains("[label=\"/\"]"), "synthetic / must never appear")
        // Forest emission: NO `alpha -> beta` edge, the children are separate roots.
        #expect(!src.contains("alpha -> beta;"))
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
swift test --filter DOTTreeViewExportConventionTests
```
Expected: `syntheticRootForest` FAILS — source contains `[label="/"]` because the current code emits `tree.root.name` verbatim.

- [ ] **Step 3: Add the convention branch**

Edit `Sources/DiagramKitGraphviz/DOTTreeViewExport.swift`. Replace `emit(_:title:)` lines 11-30 with:

```swift
    static func emit(_ tree: TreeViewDiagram, title: String?) throws -> DiagramExportResult {
        var lines: [String] = []
        var diagnostics: [DiagramDiagnostic] = []

        lines.append("digraph G {")
        lines.append("  \(DOTRecoveryMarker.emitFamily("treeView"))")
        if let t = title, !t.isEmpty {
            lines.append("  // title: \(singleLine(t))")
        }

        // Convention detection: synthetic `/` at level -1 means "Mermaid
        // multi-root container". Emit each child as a top-level forest
        // declaration; DOT supports multiple zero-in-degree nodes
        // natively. The tree-root marker fires on the FIRST child only
        // (ordering hint for the importer; see DOTTreeViewMapper
        // multi-root path).
        let isSyntheticRoot = (tree.root.name == "/" && tree.root.level == -1)
        let topLevelRoots: [TreeViewNode] = isSyntheticRoot ? tree.root.children : [tree.root]

        if let first = topLevelRoots.first {
            lines.append("  \(DOTRecoveryMarker.emitTreeRoot(first.name))")
        }
        for root in topLevelRoots {
            emitNode(root, indent: "  ", lines: &lines, diagnostics: &diagnostics)
            emitEdges(parent: root, indent: "  ", lines: &lines)
        }

        lines.append("}")
        return DiagramExportResult(
            source: lines.joined(separator: "\n") + "\n",
            diagnostics: diagnostics
        )
    }
```

- [ ] **Step 4: Re-run tests, verify pass**

```bash
swift test --filter DOTTreeViewExportConventionTests
```
Expected: both tests PASS.

- [ ] **Step 5: Verify DOT same-format treeView round-trip still passes**

```bash
swift test --filter DOTTreeViewRoundTrip
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitGraphviz/DOTTreeViewExport.swift Tests/DiagramKitTests/Graphviz/DOTTreeViewExportConventionTests.swift
git commit -m "DOT treeView exporter: forest emission for synthetic-root (Wave I)"
```

---

## Task 6: PlantUML exporter — effective-root selection + drop diagnostic

**Files:**
- Modify: `Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift`
- Test: `Tests/DiagramKitTests/PlantUML/PlantUMLTreeViewExporterConventionTests.swift` (create new file)

PlantUML WBS permits a single `*` root. Synthetic-root payloads emit the first child as the root; additional siblings drop with `.featureDropped(.slotUnsupported, …)`.

- [ ] **Step 1: Write failing tests**

Create `Tests/DiagramKitTests/PlantUML/PlantUMLTreeViewExporterConventionTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitPlantUML

@Suite("PlantUMLTreeViewExporter — convention bridging")
struct PlantUMLTreeViewExporterConventionTests {

    @Test("real-root payload emits `* root` (existing behavior)")
    func realRootEmits() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let root = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let diagram = TreeViewDiagram(root: root, nodes: [root, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source
        #expect(src.contains("@startwbs"))
        #expect(src.contains("* alpha"))
        #expect(src.contains("** leaf"))
        #expect(result.diagnostics.allSatisfy { $0.category != .slotUnsupported })
    }

    @Test("synthetic-root with single child emits child as `*` losslessly")
    func syntheticSingleChild() throws {
        let leaf = TreeViewNode(id: 2, level: 1, name: "leaf", nodeType: .file)
        let only = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .directory, children: [leaf])
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [only]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, only, leaf])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source
        #expect(src.contains("* alpha"))
        #expect(src.contains("** leaf"))
        #expect(!src.contains("* /"))
        // Lossless — no slotUnsupported diagnostic.
        #expect(result.diagnostics.allSatisfy { $0.category != .slotUnsupported })
    }

    @Test("synthetic-root with multi children emits first as `*`, drops siblings with diagnostic")
    func syntheticMultiChildDrop() throws {
        let a = TreeViewNode(id: 1, level: 0, name: "alpha", nodeType: .file)
        let b = TreeViewNode(id: 2, level: 0, name: "beta", nodeType: .file)
        let c = TreeViewNode(id: 3, level: 0, name: "gamma", nodeType: .file)
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: [a, b, c]
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic, a, b, c])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source

        #expect(src.contains("* alpha"), "first child becomes the root")
        #expect(!src.contains("* beta"), "second child must NOT appear as a root")
        #expect(!src.contains("* gamma"), "third child must NOT appear as a root")
        #expect(!src.contains("* /"))

        // Two dropped siblings → two .slotUnsupported diagnostics.
        let drops = result.diagnostics.filter { $0.category == .slotUnsupported }
        #expect(drops.count == 2)
        #expect(drops.allSatisfy { $0.severity == .unsupported })
        let messages = drops.map(\.message)
        #expect(messages.contains { $0.contains("beta") })
        #expect(messages.contains { $0.contains("gamma") })
    }

    @Test("synthetic-root with zero children emits empty @startwbs/@endwbs")
    func syntheticZeroChildren() throws {
        let synthetic = TreeViewNode(
            id: 0, level: -1, name: "/", nodeType: .directory, children: []
        )
        let diagram = TreeViewDiagram(root: synthetic, nodes: [synthetic])
        let result = try PlantUMLTreeViewExporter().export(diagram)
        let src = result.source
        #expect(src.contains("@startwbs"))
        #expect(src.contains("@endwbs"))
        #expect(!src.contains("* /"))
        #expect(!src.contains("* "))
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
swift test --filter PlantUMLTreeViewExporterConventionTests
```
Expected: `syntheticMultiChildDrop`, `syntheticSingleChild`, and `syntheticZeroChildren` FAIL — current code emits literal `/` and never drops siblings.

- [ ] **Step 3: Apply the convention-aware rewrite**

Edit `Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift`. Replace the body of `export(_:)` lines 30-74 with:

```swift
    public func export(_ diagram: TreeViewDiagram) throws -> DiagramExportResult {
        var diagnostics: [DiagramDiagnostic] = []
        var lines: [String] = ["@startwbs"]

        if let title = diagram.diagramTitle, !title.isEmpty {
            lines.append("title \(title.replacingOccurrences(of: "\n", with: " "))")
        }

        if diagram.accTitle != nil || diagram.accDescr != nil {
            diagnostics.append(.lossyTransform(
                .accessibilityDrop,
                message: "PlantUML WBS does not preserve accessibility metadata"
            ))
        }

        // Convention detection: pick the effective root (the user-visible
        // subtree the `*` root represents) and the dropped-siblings list.
        // PlantUML WBS supports exactly one `*` root per @startwbs block.
        let isSyntheticRoot = (diagram.root.name == "/" && diagram.root.level == -1)
        let effectiveRoot: TreeViewNode?
        let droppedSiblings: [TreeViewNode]
        if isSyntheticRoot {
            let children = diagram.root.children
            effectiveRoot = children.first
            droppedSiblings = Array(children.dropFirst())
        } else {
            effectiveRoot = diagram.root
            droppedSiblings = []
        }

        // Collect descriptions/icons/cssClasses in ascending id order
        // — walk only the effective root (markers for dropped siblings
        // would be orphaned).
        var descMarkers: [(id: Int, line: String)] = []
        var iconMarkers: [(id: Int, line: String)] = []
        var cssMarkers: [(id: Int, line: String)] = []
        if let root = effectiveRoot {
            walk(root) { node in
                if let d = node.description, !d.isEmpty {
                    descMarkers.append((node.id,
                        PlantUMLRecoveryMarker.emitTreeViewNodeDescription(nodeId: node.id, body: d)))
                }
                if let icon = node.iconId, !icon.isEmpty {
                    iconMarkers.append((node.id,
                        PlantUMLRecoveryMarker.emitTreeViewNodeIcon(nodeId: node.id, iconId: icon)))
                }
                if let css = node.cssClass, !css.isEmpty {
                    cssMarkers.append((node.id,
                        PlantUMLRecoveryMarker.emitTreeViewNodeCssClass(nodeId: node.id, cssClass: css)))
                }
            }
        }
        descMarkers.sort { $0.id < $1.id }
        iconMarkers.sort { $0.id < $1.id }
        cssMarkers.sort { $0.id < $1.id }
        lines.append(contentsOf: descMarkers.map { $0.line })
        lines.append(contentsOf: iconMarkers.map { $0.line })
        lines.append(contentsOf: cssMarkers.map { $0.line })

        // Emit the WBS root. If the synthetic container is empty we emit
        // a bare @startwbs/@endwbs (degenerate; matches "empty tree"
        // behavior on the parser side). The unchanged `node.level + 1`
        // mapping in `emitNode` yields the correct WBS depth: the
        // effective root is always at level 0 (whether that's a real
        // root or a synthetic-root child), giving depth 1 = `*`.
        if let root = effectiveRoot {
            emitNode(root, lines: &lines, diagnostics: &diagnostics)
        }

        // Emit one diagnostic per dropped sibling (in declaration order).
        for sibling in droppedSiblings {
            diagnostics.append(.featureDropped(
                .slotUnsupported,
                message: "additional WBS root '\(sibling.name)' dropped " +
                         "(@startwbs supports a single root)"
            ))
        }

        lines.append("@endwbs")
        return DiagramExportResult(source: lines.joined(separator: "\n") + "\n", diagnostics: diagnostics)
    }
```

- [ ] **Step 4: Confirm `emitNode` is unchanged**

The private `emitNode(_:lines:diagnostics:)` helper (lines 76-94 in the original file) is unchanged — `node.level + 1` already maps the effective root (always at level 0) to WBS depth 1, descendants to their natural depths. No edit to that function.

- [ ] **Step 5: Re-run tests, verify pass**

```bash
swift test --filter PlantUMLTreeViewExporterConventionTests
```
Expected: all four tests PASS.

- [ ] **Step 6: Verify PlantUML same-format treeView round-trip still passes**

```bash
swift test --filter PlantUMLTreeViewRoundTrip
```
Expected: PASS. Same-format PlantUML inputs always have real root (PlantUML parser doesn't insert synthetic), so `effectiveRoot == diagram.root`, `depthOverride == 1`, byte-identical to today's output.

- [ ] **Step 7: Commit**

```bash
git add Sources/DiagramKitPlantUML/Exporter/PlantUMLTreeViewExporter.swift Tests/DiagramKitTests/PlantUML/PlantUMLTreeViewExporterConventionTests.swift
git commit -m "PlantUML treeView exporter: convention bridge + drop diagnostic (Wave I)"
```

---

## Task 7: D2 importer — multi-root synthesizes `/` container

**Files:**
- Modify: `Sources/DiagramKitD2/D2TreeViewMapper.swift`
- Test: `Tests/DiagramKitTests/D2/D2TreeViewMapperConventionTests.swift` (create new file)

Add a structurally-detected multi-root branch BEFORE the marker-pinned single-root branch, so forest-export round-trips correctly bridge the convention.

- [ ] **Step 1: Write failing tests**

Create `Tests/DiagramKitTests/D2/D2TreeViewMapperConventionTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitD2

@Suite("D2TreeViewMapper — multi-root convention")
struct D2TreeViewMapperConventionTests {

    private func parseAndMap(_ source: String) throws -> (TreeViewDiagram?, [DiagramDiagnostic]) {
        // Mirrors D2Importer.swift:48-50 — parser sees raw source
        // (D2's `#` is a comment so markers are tolerated); scanner
        // extracts typed markers separately.
        let parser = D2Parser()
        let (doc, _) = try parser.parse(source)
        let scan = D2RecoveryMarker.scanner.scan(source: source)
        return D2TreeViewMapper().map(doc, markers: scan.markers)
    }

    @Test("single-root D2 input maps to real-root payload (existing behavior)")
    func singleRootRealRoot() throws {
        let src = """
        # diagramkit:family=treeView
        # diagramkit:tree-root=alpha
        alpha: "alpha"
        leaf: "leaf"
        alpha -> leaf
        """
        let (diagram, diagnostics) = try parseAndMap(src)
        #expect(diagram != nil)
        #expect(diagnostics.isEmpty)
        #expect(diagram?.root.name == "alpha")
        #expect(diagram?.root.level == 0)
    }

    @Test("multi-root D2 input synthesizes `/` container; alphabetical order")
    func multiRootSynthesizes() throws {
        let src = """
        # diagramkit:family=treeView
        beta: "beta"
        alpha: "alpha"
        """
        let (diagram, _) = try parseAndMap(src)
        #expect(diagram != nil)
        #expect(diagram?.root.name == "/")
        #expect(diagram?.root.level == -1)
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["alpha", "beta"], "alphabetical fallback ordering")
    }

    @Test("multi-root D2 input with tree-root marker hoists pinned root first")
    func multiRootMarkerHoist() throws {
        let src = """
        # diagramkit:family=treeView
        # diagramkit:tree-root=beta
        alpha: "alpha"
        beta: "beta"
        gamma: "gamma"
        """
        let (diagram, _) = try parseAndMap(src)
        #expect(diagram?.root.name == "/")
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["beta", "alpha", "gamma"], "marker pins beta first; rest alphabetical")
    }

    @Test("multi-root preserves each subtree's children")
    func multiRootSubtrees() throws {
        let src = """
        # diagramkit:family=treeView
        alpha: "alpha"
        beta: "beta"
        alpha -> a_leaf
        beta -> b_leaf
        a_leaf: "a_leaf"
        b_leaf: "b_leaf"
        """
        let (diagram, _) = try parseAndMap(src)
        let alpha = diagram?.root.children.first { $0.name == "alpha" }
        let beta = diagram?.root.children.first { $0.name == "beta" }
        #expect(alpha?.children.map(\.name) == ["a_leaf"])
        #expect(beta?.children.map(\.name) == ["b_leaf"])
    }

    @Test("no-root D2 input falls back to flowchart (existing behavior)")
    func noRootFallsBack() throws {
        // cycle: a -> b, b -> a → zero zero-in-degree roots
        let src = """
        # diagramkit:family=treeView
        a: "a"
        b: "b"
        a -> b
        b -> a
        """
        let (diagram, diagnostics) = try parseAndMap(src)
        #expect(diagram == nil)
        #expect(diagnostics.contains { $0.category == .slotUnsupported })
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
swift test --filter D2TreeViewMapperConventionTests
```
Expected: `multiRootSynthesizes`, `multiRootMarkerHoist`, `multiRootSubtrees` all FAIL — current mapper either uses the marker-pinned single-root path (dropping orphans) or falls back to flowchart with a `.slotUnsupported` diagnostic.

- [ ] **Step 3: Apply the multi-root branch**

Edit `Sources/DiagramKitD2/D2TreeViewMapper.swift`. Replace lines 43-77 (everything after `for stmt in doc.statements { … }` through the closing brace of `map(_:markers:)`) with:

```swift
        var rootMarker: String? = nil
        for marker in markers {
            if case .treeRoot(let id) = marker.kind { rootMarker = id }
        }
        let roots = allNodes.subtracting(hasIncoming)

        var allBuilt: [TreeViewNode] = []
        var nextID = 0
        func build(_ id: String, level: Int) -> TreeViewNode {
            let kidIDs = children[id] ?? []
            let assigned = nextID; nextID += 1
            let kids = kidIDs.map { build($0, level: level + 1) }
            let node = TreeViewNode(
                id: assigned,
                level: level,
                name: labels[id] ?? id,
                nodeType: kids.isEmpty ? .file : .directory,
                children: kids
            )
            allBuilt.append(node)
            return node
        }

        // Branch order matters. Structural multi-root takes precedence over
        // the marker: forest exports emit a tree-root marker pinning the
        // first child as an ordering hint, NOT as a single-root assertion.
        // Honoring `roots.count > 1` first means forest round-trips
        // synthesize the canonical `/` container, and the pre-existing
        // marker-pinned-with-orphans silent-drop bug closes naturally.
        if roots.count > 1 {
            var orderedRoots = roots.sorted()
            if let pinned = rootMarker,
               roots.contains(pinned),
               let idx = orderedRoots.firstIndex(of: pinned) {
                orderedRoots.remove(at: idx)
                orderedRoots.insert(pinned, at: 0)
            }
            let synthChildren = orderedRoots.map { build($0, level: 0) }
            let syntheticRoot = TreeViewNode(
                id: nextID, level: -1, name: "/", nodeType: .directory,
                children: synthChildren
            )
            nextID += 1
            allBuilt.append(syntheticRoot)
            return (TreeViewDiagram(root: syntheticRoot, nodes: allBuilt), diagnostics)
        }

        // Single-root paths below — byte-identical to pre-Wave-I behavior.
        if let pinned = rootMarker, allNodes.contains(pinned) {
            let root = build(pinned, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }
        if roots.count == 1 {
            let root = build(roots.first!, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }

        // roots.isEmpty: cycles or empty graph — fall back to flowchart.
        diagnostics.append(.featureDropped(
            .slotUnsupported,
            message: "TreeView requires at least one root; found 0. Falling back to flowchart."
        ))
        return (nil, diagnostics)
    }
}
```

- [ ] **Step 4: Re-run tests, verify pass**

```bash
swift test --filter D2TreeViewMapperConventionTests
```
Expected: all five tests PASS.

- [ ] **Step 5: Verify D2 same-format treeView round-trip still passes**

```bash
swift test --filter D2TreeViewRoundTrip
```
Expected: PASS (single-root D2 inputs unchanged).

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitD2/D2TreeViewMapper.swift Tests/DiagramKitTests/D2/D2TreeViewMapperConventionTests.swift
git commit -m "D2 treeView mapper: multi-root synthesizes / container (Wave I)"
```

---

## Task 8: DOT importer — multi-root synthesizes `/` container

**Files:**
- Modify: `Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift`
- Test: `Tests/DiagramKitTests/Graphviz/DOTTreeViewMapperConventionTests.swift` (create new file)

Parallel to Task 7. Same branch order rule.

- [ ] **Step 1: Write failing tests**

Create `Tests/DiagramKitTests/Graphviz/DOTTreeViewMapperConventionTests.swift`:

```swift
import Testing
import DiagramKitCommon
import DiagramKitModel
@testable import DiagramKitGraphviz

@Suite("DOTTreeViewMapper — multi-root convention")
struct DOTTreeViewMapperConventionTests {

    private func parseAndMap(_ source: String) throws -> (TreeViewDiagram?, [DiagramDiagnostic]) {
        // Mirrors GraphvizImporter.swift:42-47 — lex first, then parser
        // sees tokens; scanner extracts typed markers from raw source.
        let lexer = DOTLexer()
        let tokens = try lexer.tokenize(source)
        let parser = DOTParser()
        let (doc, _) = try parser.parse(tokens)
        let scan = DOTRecoveryMarker.scanner.scan(source: source)
        return DOTTreeViewMapper().map(doc, markers: scan.markers)
    }

    @Test("single-root DOT input maps to real-root payload (existing behavior)")
    func singleRootRealRoot() {
        let src = """
        digraph G {
          # diagramkit:family=treeView
          # diagramkit:tree-root=alpha
          alpha [label="alpha"];
          leaf [label="leaf"];
          alpha -> leaf;
        }
        """
        let (diagram, diagnostics) = try parseAndMap(src)
        #expect(diagram != nil)
        #expect(diagnostics.isEmpty)
        #expect(diagram?.root.name == "alpha")
    }

    @Test("multi-root DOT input synthesizes `/` container; alphabetical order")
    func multiRootSynthesizes() {
        let src = """
        digraph G {
          # diagramkit:family=treeView
          beta [label="beta"];
          alpha [label="alpha"];
        }
        """
        let (diagram, _) = try parseAndMap(src)
        #expect(diagram?.root.name == "/")
        #expect(diagram?.root.level == -1)
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["alpha", "beta"])
    }

    @Test("multi-root DOT input with tree-root marker hoists pinned root first")
    func multiRootMarkerHoist() {
        let src = """
        digraph G {
          # diagramkit:family=treeView
          # diagramkit:tree-root=beta
          alpha [label="alpha"];
          beta [label="beta"];
          gamma [label="gamma"];
        }
        """
        let (diagram, _) = try parseAndMap(src)
        let kidNames = (diagram?.root.children ?? []).map(\.name)
        #expect(kidNames == ["beta", "alpha", "gamma"])
    }
}
```

- [ ] **Step 2: Run tests, verify failure**

```bash
swift test --filter DOTTreeViewMapperConventionTests
```
Expected: `multiRootSynthesizes` and `multiRootMarkerHoist` FAIL.

- [ ] **Step 3: Apply the multi-root branch**

Edit `Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift`. Replace lines 44-78 (everything from `var rootMarker: String? = nil` through the closing brace of `map(_:markers:)`) with:

```swift
        var rootMarker: String? = nil
        for marker in markers {
            if case .treeRoot(let id) = marker.kind { rootMarker = id }
        }
        let roots = allNodes.subtracting(hasIncoming)

        var allBuilt: [TreeViewNode] = []
        var nextID = 0
        func build(_ id: String, level: Int) -> TreeViewNode {
            let kidIDs = children[id] ?? []
            let assigned = nextID; nextID += 1
            let kids = kidIDs.map { build($0, level: level + 1) }
            let node = TreeViewNode(
                id: assigned,
                level: level,
                name: labels[id] ?? id,
                nodeType: kids.isEmpty ? .file : .directory,
                children: kids
            )
            allBuilt.append(node)
            return node
        }

        // Branch order matters. See D2TreeViewMapper for rationale; this
        // is the parallel implementation for DOT.
        if roots.count > 1 {
            var orderedRoots = roots.sorted()
            if let pinned = rootMarker,
               roots.contains(pinned),
               let idx = orderedRoots.firstIndex(of: pinned) {
                orderedRoots.remove(at: idx)
                orderedRoots.insert(pinned, at: 0)
            }
            let synthChildren = orderedRoots.map { build($0, level: 0) }
            let syntheticRoot = TreeViewNode(
                id: nextID, level: -1, name: "/", nodeType: .directory,
                children: synthChildren
            )
            nextID += 1
            allBuilt.append(syntheticRoot)
            return (TreeViewDiagram(root: syntheticRoot, nodes: allBuilt), diagnostics)
        }

        if let pinned = rootMarker, allNodes.contains(pinned) {
            let root = build(pinned, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }
        if roots.count == 1 {
            let root = build(roots.first!, level: 0)
            return (TreeViewDiagram(root: root, nodes: allBuilt), diagnostics)
        }

        diagnostics.append(.featureDropped(
            .slotUnsupported,
            message: "TreeView requires at least one root; found 0. Falling back to flowchart."
        ))
        return (nil, diagnostics)
    }
}
```

- [ ] **Step 4: Re-run tests, verify pass**

```bash
swift test --filter DOTTreeViewMapperConventionTests
```
Expected: all three tests PASS.

- [ ] **Step 5: Verify DOT same-format treeView round-trip still passes**

```bash
swift test --filter DOTTreeViewRoundTrip
```
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitGraphviz/DOTTreeViewMapper.swift Tests/DiagramKitTests/Graphviz/DOTTreeViewMapperConventionTests.swift
git commit -m "DOT treeView mapper: multi-root synthesizes / container (Wave I)"
```

---

## Task 9: Silent-skip fix — rename `.mermaid` fixtures + delete masking comment

**Files:**
- Rename: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/01-basic.mermaid` → `01-basic.mmd`
- Rename: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/01-basic.mermaid` → `01-basic.mmd`
- Modify: `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift` — delete masking comment at `:837-844`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift` — refresh Wave H comment block at `:96-103`

- [ ] **Step 1: Rename the two fixture files**

```bash
git mv Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/01-basic.mermaid \
       Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/01-basic.mmd
git mv Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/01-basic.mermaid \
       Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/01-basic.mmd
```

- [ ] **Step 2: Delete the masking comment block in `CrossFormatRoundTripTests.swift`**

Open `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift`. Find the section header that reads `// MARK: D2 ↔ PlantUML (treeView) — Wave H` (currently around line 835). The lines immediately below it are an explanatory paragraph beginning with `// Mermaid ↔ PlantUML treeView is deliberately omitted:` and continuing through `// out of scope for Wave H.`. Delete that entire paragraph (the `//`-prefixed lines through "out of scope for Wave H."), keeping the `// MARK:` header line itself. After the edit the section reads:

```swift
    // MARK: D2 ↔ PlantUML (treeView) — Wave H

    @Test(
        "D2 → PlantUML → D2 (treeView)",
        …
```

- [ ] **Step 3: Refresh the comment block in `RoundTripCrossRegistry.swift`**

Open `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift`. Replace the comment block at lines 96-103 (starting `// Wave H — treeView cross-format pairs (PlantUML ↔ d2/dot only). …`) with:

```swift
    // Wave H + I — treeView cross-format pairs. PlantUML ↔ d2/dot landed
    // in Wave H; Mermaid ↔ PlantUML landed in Wave I along with the
    // synthetic-root convention bridge. The Mermaid ↔ D2 and Mermaid
    // ↔ DOT pairs (declared at the Wave-E methods) now run after Wave I
    // renamed their `.mermaid` fixtures to `.mmd` and the D2/DOT mappers
    // gained the multi-root synthesizing branch.
```

- [ ] **Step 4: Run the now-unblocked Mermaid ↔ D2 / DOT treeView tests**

```bash
swift test --filter mermaidD2TreeView
swift test --filter d2MermaidTreeView
swift test --filter mermaidDotTreeView
swift test --filter dotMermaidTreeView
```
Expected: all four PASS. (They will only run now that the fixture loader picks up `.mmd` extension. The basic fixture has a single root, so the synthetic-root path is not exercised yet — that lands in Task 10.)

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/ \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/ \
        Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift \
        Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift
git commit -m "Unblock silent-skip Mermaid↔D2/DOT treeView fixtures (Wave I)"
```

---

## Task 10: Add multi-root cross-format fixtures (Mermaid → D2, DOT)

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/02-multi-root.mmd`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/02-multi-root.mmd`

These fixtures depend on **both** the export-side forest emission (Task 4/5) and the import-side multi-root synthesis (Task 7/8) landing first.

- [ ] **Step 1: Create Mermaid → D2 multi-root fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/02-multi-root.mmd`:

```
treeView-beta
    alpha/
        a_leaf
    beta/
        b_leaf
    gamma
```

This input has three user-visible roots at level 0 (`alpha`, `beta`, `gamma`). Mermaid's parser will synthesize a `/` container at level -1 with those three as children. The D2 export must emit a forest; the D2 re-import must synthesize a fresh `/` container; the Mermaid re-export must produce the same input shape modulo declaration order.

- [ ] **Step 2: Create Mermaid → DOT multi-root fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/02-multi-root.mmd`:

```
treeView-beta
    alpha/
        a_leaf
    beta/
        b_leaf
    gamma
```

Same content as the D2 fixture above.

- [ ] **Step 3: Run the multi-root tests**

```bash
swift test --filter mermaidD2TreeView
swift test --filter mermaidDotTreeView
```
Expected: PASS. The harness round-trips through each leg and asserts structural equality. The new `.syntheticRootFlattened` loss is NOT triggered (D2/DOT preserve forest structure).

- [ ] **Step 4: Run the reverse-direction tests to confirm they still pass**

```bash
swift test --filter d2MermaidTreeView
swift test --filter dotMermaidTreeView
```
Expected: PASS. D2/DOT same-format fixtures are still single-root; reverse-direction tests are unaffected by the new multi-root fixture.

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-d2-treeView/02-multi-root.mmd \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-dot-treeView/02-multi-root.mmd
git commit -m "Multi-root Mermaid↔D2/DOT treeView fixtures (Wave I)"
```

---

## Task 11: Add same-format D2/DOT multi-root fixtures

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-treeView/02-multi-root.d2`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-treeView/02-multi-root.dot`

Exercise the same-format D2/DOT round-trip through the new multi-root paths in the mappers.

- [ ] **Step 1: Create D2 multi-root fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-treeView/02-multi-root.d2`:

```
# diagramkit:family=treeView
alpha: "alpha"
beta: "beta"
gamma: "gamma"
alpha -> a_leaf
beta -> b_leaf
a_leaf: "a_leaf"
b_leaf: "b_leaf"
```

No `tree-root` marker is present — the multi-root path runs purely on structural detection (three zero-in-degree nodes: `alpha`, `beta`, `gamma`).

- [ ] **Step 2: Create DOT multi-root fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-treeView/02-multi-root.dot`:

```
digraph G {
  # diagramkit:family=treeView
  alpha [label="alpha"];
  beta [label="beta"];
  gamma [label="gamma"];
  a_leaf [label="a_leaf"];
  b_leaf [label="b_leaf"];
  alpha -> a_leaf;
  beta -> b_leaf;
}
```

- [ ] **Step 3: Find the same-format D2/DOT treeView test names**

```bash
grep -n "d2TreeView\|dotTreeView" Tests/DiagramKitTests/RoundTrip/SameFormatRoundTripTests.swift | head
```
The fixtures discover automatically — no test code change needed.

- [ ] **Step 4: Run the same-format tests**

```bash
swift test --filter "RoundTrip.*d2TreeView"
swift test --filter "RoundTrip.*dotTreeView"
```
Expected: PASS on both old (`01-basic`, `02-nested`) and new (`02-multi-root`) fixtures. The forest exports re-import to a synthetic `/` container; the second export re-emits the forest in alphabetical order. Round-trip equality holds because the synthetic `/` is structurally equal across both passes (same children, same order).

- [ ] **Step 5: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/d2-treeView/02-multi-root.d2 \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/dot-treeView/02-multi-root.dot
git commit -m "Same-format D2/DOT multi-root treeView fixtures (Wave I)"
```

---

## Task 12: Add Mermaid ↔ PlantUML treeView fixtures and harness methods

**Files:**
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/01-basic.mmd`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/02-multi-root.mmd`
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/02-multi-root.json` (sidecar)
- Create: `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-plantuml-mermaid-treeView/01-basic.puml`
- Modify: `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift` — add two new constants
- Modify: `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift` — add two new `@Test` methods

This task closes the Wave H deferral.

- [ ] **Step 1: Create the fixture directories**

```bash
mkdir -p Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView
mkdir -p Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-plantuml-mermaid-treeView
```

- [ ] **Step 2: Create the single-root Mermaid → PlantUML fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/01-basic.mmd`:

```
treeView-beta
    project/
        src/
            App.tsx
            index.js
        README.md
```

- [ ] **Step 3: Create the single-root PlantUML → Mermaid fixture**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-plantuml-mermaid-treeView/01-basic.puml`:

```
@startwbs
* project
** src
*** App.tsx
*** index.js
** README.md
@endwbs
```

- [ ] **Step 4: Create the multi-root Mermaid → PlantUML fixture (lossy)**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/02-multi-root.mmd`:

```
treeView-beta
    alpha/
        a_leaf
    beta/
        b_leaf
    gamma
```

This input has three user-visible roots. PlantUML WBS can only express one — the first (`alpha`) becomes the WBS root; `beta` and `gamma` drop with `.featureDropped(.slotUnsupported, …)` diagnostics. The round-trip is intentionally lossy and the harness admits the loss via the sidecar in Step 5.

- [ ] **Step 5: Create the sidecar admitting the loss**

Create `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/02-multi-root.json`:

```json
{
  "additionalAllowedLosses": ["syntheticRootFlattened"],
  "note": "Multi-root Mermaid treeView cannot round-trip through PlantUML WBS (single-root grammar); two of three roots drop with .featureDropped(.slotUnsupported)."
}
```

- [ ] **Step 6: Add cross-registry constants**

Edit `Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift`. After the existing `plantumlDotTreeView` constant at line 107, insert:

```swift

    // Wave I — Mermaid ↔ PlantUML treeView (closes Wave H deferral).
    // Single-root inputs are lossless modulo idSanitization / titleDrop.
    // Multi-root Mermaid input admits .syntheticRootFlattened via per-
    // fixture sidecar (see cross-mermaid-plantuml-treeView/02-multi-root.json).
    static let mermaidPlantumlTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
    static let plantumlMermaidTreeView: Set<RoundTripLossKind> = [.idSanitization, .titleDrop]
```

- [ ] **Step 7: Add the two new `@Test` methods**

Edit `Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift`. After the existing `plantumlDotTreeView` method (around line 894), append a new section:

```swift
    // MARK: Mermaid ↔ PlantUML (treeView) — Wave I

    @Test(
        "Mermaid → PlantUML → Mermaid (treeView)",
        arguments: try fixtures(for: "cross-mermaid-plantuml-treeView", fromRoot: roundTripResourcesRoot())
    )
    func mermaidPlantumlTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.mermaidTreeView,
            legB: RoundTripCellRegistry.plantumlTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.mermaidPlantumlTreeView,
            fixture: fixture
        )
    }

    @Test(
        "PlantUML → Mermaid → PlantUML (treeView)",
        arguments: try fixtures(for: "cross-plantuml-mermaid-treeView", fromRoot: roundTripResourcesRoot())
    )
    func plantumlMermaidTreeView(fixture: RoundTripFixture) throws {
        try runCrossFormatRoundTrip(
            legA: RoundTripCellRegistry.plantumlTreeView,
            legB: RoundTripCellRegistry.mermaidTreeView,
            additionalAllowedLosses: RoundTripCrossRegistry.plantumlMermaidTreeView,
            fixture: fixture
        )
    }
```

- [ ] **Step 8: Run the new cross-format tests**

```bash
swift test --filter mermaidPlantumlTreeView
swift test --filter plantumlMermaidTreeView
```
Expected: PASS on `01-basic` (lossless single-root) and on `02-multi-root` (admits `.syntheticRootFlattened` via sidecar).

- [ ] **Step 9: Commit**

```bash
git add Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-mermaid-plantuml-treeView/ \
        Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/cross-plantuml-mermaid-treeView/ \
        Tests/DiagramKitTests/RoundTrip/RoundTripCrossRegistry.swift \
        Tests/DiagramKitTests/RoundTrip/CrossFormatRoundTripTests.swift
git commit -m "Mermaid↔PlantUML treeView pair + multi-root drop fixture (Wave I)"
```

---

## Task 13: Update COVERAGE.md

**Files:**
- Modify: `COVERAGE.md`

Reflect the closed Wave I work in the matrix doc.

- [ ] **Step 1: Update the round-trip discipline section**

Open `COVERAGE.md`. Find the line beginning `Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/ currently holds **43 …` (around line 98). Replace that paragraph with:

```markdown
`Tests/DiagramKitTests/RoundTrip/Resources/roundtrip/` currently holds **45
same-format fixtures** (+2 D2/DOT treeView multi-root fixtures in Wave I) and
**82 cross-format directed pairs** (41 unordered; +2 directed /
+1 unordered treeView × {mermaid↔plantuml} pair added in Wave I along with
+2 directed multi-root Mermaid → {d2,dot} fixtures and +2 renames unblocking
the silent skip).
```

- [ ] **Step 2: Update the cross-format pairs table row for treeView**

Find the `Cross-format pairs` row in the table (around line 107). Replace the `treeView` segment:

```text
treeView × {mermaid↔d2, mermaid↔dot, d2↔dot, d2↔plantuml, dot↔plantuml}
```

with:

```text
treeView × {mermaid↔d2, mermaid↔dot, d2↔dot, d2↔plantuml, dot↔plantuml, mermaid↔plantuml}
```

- [ ] **Step 3: Update the "Last audited" date and append a Wave I closer**

Change the line `Last audited: 2026-05-21 (Wave H).` (line 8) to:

```markdown
Last audited: 2026-05-21 (Wave I).
```

After the Wave H bullet block (which ends around line 237 with "Closes [`docs/superpowers/specs/2026-05-21-plantuml-treeview-design.md`](…)"), append:

```markdown
- **Wave I — treeView synthetic-root bridge.** Mermaid ↔ {D2, DOT,
  PlantUML} treeView cross-format paths gain bidirectional convention
  bridging (no matrix `⚠` involved; the convention mismatch had been
  blocked by silently-skipping Wave E fixtures and the Wave H PlantUML
  deferral). `TreeViewDiagram.root` now carries a documented canonical
  convention: a `root` with `name == "/"` AND `level == -1` is the
  Mermaid parser's synthetic multi-root container. The four cross-format
  exporters (Mermaid, D2, DOT, PlantUML) detect the convention on entry
  and adapt; D2/DOT importers gain a structural multi-root branch that
  synthesizes the same container so forest round-trips bridge cleanly.
  One new `RoundTripLoss.syntheticRootFlattened` case (PlantUML-only
  trigger — D2/DOT preserve forests losslessly). No new
  `DiagnosticCategory` cases (reuses `.slotUnsupported`). Closes
  [`docs/superpowers/specs/2026-05-21-treeview-synthetic-root-bridge-design.md`](docs/superpowers/specs/2026-05-21-treeview-synthetic-root-bridge-design.md).
```

- [ ] **Step 4: Append a Wave I entry to the Backlog summary**

In the "Backlog summary" section (around line 304), add a strikethrough entry after the Wave H entry:

```markdown
10. ~~**Mermaid ↔ {D2, DOT, PlantUML} treeView synthetic-root bridge.**~~
    Closed by Wave I (2026-05-21-treeview-synthetic-root-bridge spec).
    Documents the canonical `TreeViewDiagram.root` convention and
    extends D2/DOT importers + all four cross-format exporters to honor
    it. Unblocks the silently-skipping Mermaid ↔ D2/DOT treeView
    fixtures present since Wave E and closes the Wave H Mermaid ↔
    PlantUML treeView deferral.
```

- [ ] **Step 5: Verify the doc renders cleanly**

```bash
grep -n "Wave I" COVERAGE.md
```
Expected: at least three occurrences (closer paragraph, backlog entry, audit-date update).

- [ ] **Step 6: Commit**

```bash
git add COVERAGE.md
git commit -m "Wave I closer — COVERAGE.md updates"
```

---

## Task 14: Run the discipline gates

**Files:** none modified — verification only.

- [ ] **Step 1: Run the diagnostic discipline script**

```bash
Scripts/check-diagnostic-discipline.sh
```
Expected: PASS. The one new emit site (`PlantUMLTreeViewExporter` dropped-sibling diagnostic) uses the typed `.featureDropped(.slotUnsupported, message:)` factory.

- [ ] **Step 2: Run the file-size script**

```bash
Scripts/check-file-sizes.sh
```
Expected: PASS. No touched file is expected to cross the 500-line warning threshold.

- [ ] **Step 3: Run the sendable-annotation script**

```bash
Scripts/check-sendable-annotations.sh
```
Expected: PASS. No `@unchecked Sendable` changes.

- [ ] **Step 4: Run strict concurrency build**

```bash
Scripts/strict-concurrency-check.sh
```
Expected: PASS.

- [ ] **Step 5: Run the round-trip test suite**

```bash
swift test --filter RoundTrip
```
Expected: PASS on all same-format, cross-format, and new fixture combinations.

- [ ] **Step 6: Run the Linux check (if Docker/Podman available)**

```bash
Scripts/linux-check.sh
```
Expected: PASS, or "skipped due to environment" if Docker/Podman is not running locally. All touched files are Linux-portable (`DiagramKitModel`, `DiagramKitTestSupport`, format slices).

- [ ] **Step 7: Run the full local merge gate**

```bash
Scripts/bootstrap-smoke-check.sh
```
Expected: PASS (or matching skipped-environment behavior for `linux-check.sh`).

- [ ] **Step 8: No commit — this task is verification only**

If any gate fails, fix the underlying issue (do NOT add suppressions). Re-run the failing gate, then re-run the full sweep. Only after all gates pass do you proceed to merge.

---

## Self-review checklist (run before declaring done)

- Mermaid same-format treeView round-trip: byte-identical output? (Task 3 Step 5)
- D2 same-format treeView round-trip: byte-identical output for single-root fixtures? (Task 4 Step 5, Task 7 Step 5)
- DOT same-format treeView round-trip: byte-identical output for single-root fixtures? (Task 5 Step 5, Task 8 Step 5)
- PlantUML same-format treeView round-trip: byte-identical output? (Task 6 Step 6)
- Mermaid ↔ D2 treeView (Task 9 + Task 10): single-root lossless + multi-root lossless via forest?
- Mermaid ↔ DOT treeView (Task 9 + Task 10): same?
- Mermaid ↔ PlantUML treeView (Task 12): single-root lossless + multi-root admits `.syntheticRootFlattened` via sidecar?
- Same-format D2/DOT multi-root (Task 11): both pass after mapper change?
- COVERAGE.md (Task 13): three new Wave I references; cross-format pairs table row updated?
- Discipline gates (Task 14): all green?
