# Visual Editor Plan 3/6 — Subgraph UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Full subgraph editing — insert an empty subgraph from the toolbar, drag nodes into/out of subgraph boundaries, rename/ungroup/delete subgraphs, and right-click context menus for every canvas element.

**Architecture:** Four new `FlowchartMutation` cases (`insertSubgraph`, `moveToSubgraph`, `ungroupSubgraph`, `renameSubgraph`) plus `deleteElement` support for `group:` selections, all in `DiagramKitInteractive`. **Load-bearing constraint:** `MermaidSubgraph` is a mutable `final class` and undo snapshots share instances — every subgraph mutation must deep-copy the forest (`_copySubgraphForest`) before modifying, or undo corrupts. UI: toolbar Subgraph button + prompt sheets, drag-to-join on the select tool with ghost + boundary highlight, and a `.contextMenu` driven by `onContinuousHover` position tracking.

**Tech Stack:** Swift 6, swift-testing (Interactive mutation tests), XCTest (Playground store tests), SwiftUI (macOS-first).

**Spec:** `docs/superpowers/specs/2026-07-04-visual-editor-design.md` Sections 1 (subgraph mutations), 3 (context menus), 4 (subgraph UX).

## Global Constraints

- Work directly on `main`, commit-by-commit. No branches, no worktrees, no stash.
- Never run bare `swift test` — always `swift test --filter <ExactSuiteName>`.
- Diagnostics only via typed factories; gate `Scripts/check-diagnostic-discipline.sh`.
- Swift files: warn 500 / error 1000 lines.
- Store methods must call `performFlowchartMutation` / `performMutation`, never `editor.performFlowchart` directly (preserves the `.mutation`-origin undo convention).
- New `FlowchartMutation` cases require: enum case + `undoActionName` + `==` + `hash(into:)` (discriminators continue 6, 7, 8, 9 after plan 1's 4–5) + `_applyFlowchart` dispatch + `LiveEditorStore.undoKind/undoLabel` switch arms (they are exhaustive and WILL break the sample-app build if missed).

## Reference — verified facts this plan builds on

- `MermaidSubgraph`: `final class` with `var id/label: String`, `var nodeIds: [String]`, `var children: [MermaidSubgraph]`, `var direction: Direction?`, `var shape: NodeShape?`, `var altBkg: Bool`; init takes all with defaults (`src_types.swift:304`).
- `DiagramEditor.subgraphID(title:members:)` → deterministic `slug_hash8` id + sanitization diagnostics (`FlowchartSubgraphMutation.swift:75`).
- `_deleteElement` handles `node:` / `edge:` prefixes via `_withFlowGraphPayload` (`DiagramEditor+Mutations.swift:171`); `group:` currently throws `.unknownElementKind`.
- `DiagramBoundsLookup`: `allElementIDs: [String]`, `selection(for:) -> DiagramSelection?`, `bounds(of:) -> DiagramRect?`; group elements have ids `"group:<subgraphID>"`. `DiagramRect` has `minX/maxX/minY/maxY/width/height` and `contains(DiagramPoint)`.
- `FlowchartEditCanvas`: `.select`-tool drag is currently a no-op (`handleDragChanged` line ~248) — the open slot for drag-to-join. Coordinate helpers `diagramPoint(from:viewSize:)` and `viewRect(for:in:)` exist. `nodeID(at:in:)` returns the hit element's `elementID`.
- `SubgraphPromptSheet` pattern for prompts; store fields `isSubgraphPromptOpen` / `lastSubgraphCommit` are stored properties on `LiveEditorStore` (main class file — extensions cannot add stored properties).
- `EdgeEditPopover` exists but is **never presented** — `VisualPane.stagePopover` always shows `NodeEditPopover` for `.labelEdited`. Task 7 fixes the dispatch.
- `UndoEntry.Kind` cases: `noop/setLabel/setTitle/insertNode/insertEdge/deleteElement/groupIntoSubgraph` (`LiveEditorStore+Visual.swift:143`).
- Store editor seeding in tests: force-feed `store.didCompleteRender(parseError: nil, diagramBounds: .zero)` in the wait loop (see `ShapeInsertFlowTests.waitForEditor`).

## File Structure

- `Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift` (new) — forest deep-copy/find helpers + the four mutation implementations.
- `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift` — enum cases, dispatch, Equatable/Hashable, undo names.
- `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` — `group:` branch in `_deleteElement`.
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift` — two stored prompt properties.
- `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift` — prompt/rename/move/delete-marquee helpers + subgraph queries + undo switch arms.
- `Sources/DiagramKitSample/Views/Visual/SubgraphTitleSheet.swift` (new) — shared title prompt (empty-insert + rename modes).
- `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift` — Subgraph button.
- `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift` — drag-to-join + hover tracking + context menu attachment.
- `Sources/DiagramKitSample/Views/Visual/Flowchart/CanvasContextMenu.swift` (new) — per-element menu items.
- `Sources/DiagramKitSample/Views/Visual/VisualPane.swift` — sheet wiring + edge/node popover dispatch.
- Tests: `Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift` (new, swift-testing), `Tests/DiagramKitTests/Playground/SubgraphToolbarFlowTests.swift` (new, XCTest).

---

### Task 1: Forest utilities + `insertSubgraph` mutation

**Files:**
- Create: `Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (undo switch arms — see Global Constraints)
- Test: `Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift`

**Interfaces:**
- Consumes: `DiagramEditor.subgraphID(title:members:)`, `_commitMutation` plumbing.
- Produces:
  - `FlowchartMutation.insertSubgraph(title: String)`
  - `static DiagramEditor._copySubgraphForest(_: [original_src_types.MermaidSubgraph]) -> [original_src_types.MermaidSubgraph]` (deep copy)
  - `static DiagramEditor._findSubgraph(_ id: String, in: [original_src_types.MermaidSubgraph]) -> original_src_types.MermaidSubgraph?` (recursive)
  - Tasks 2–4 use both helpers.

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift` with the shared fixture used by Tasks 1–3 (this file grows across tasks):

```swift
// Visual editor plan 3 — subgraph forest mutations.
// MermaidSubgraph is a reference type; these tests deliberately pin
// undo integrity (deep-copy correctness) for every mutation.

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

/// Flowchart with nodes A,B,C and one subgraph g1 [Group One] holding [A, B].
private func groupedDoc() -> DiagramDocument {
    let nodes = ["A", "B", "C"].map {
        (id: $0, node: original_src_types.MermaidNode(id: $0, label: "Node \($0)", shape: .rectangle))
    }
    let sub = original_src_types.MermaidSubgraph(id: "g1", label: "Group One", nodeIds: ["A", "B"])
    let model = original_src_types.MermaidGraph(
        direction: .TD, nodesInOrder: nodes,
        edges: [original_src_types.MermaidEdge(source: "A", target: "C", style: .solid)],
        subgraphs: [sub]
    )
    return DiagramDocument(payload: .flowchart(model))
}

@MainActor
private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

private func subgraphs(_ editor: DiagramEditor) -> [original_src_types.MermaidSubgraph] {
    guard case .flowchart(let model) = editor.document.payload else { return [] }
    return model.subgraphs
}

private func node(_ sel: String) -> DiagramSelection {
    DiagramSelection(diagramType: .flowchart, elementID: "node:\(sel)")
}

@Suite @MainActor
struct FlowchartSubgraphOpsTests {

    // MARK: - insertSubgraph

    @Test("insertSubgraph adds an empty subgraph with the title as label")
    func insertEmpty() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Fresh Group"))
        let subs = subgraphs(editor)
        #expect(subs.count == 2)
        let fresh = subs.first { $0.label == "Fresh Group" }
        #expect(fresh != nil)
        #expect(fresh?.nodeIds.isEmpty == true)
    }

    @Test("two insertSubgraph calls with the same title mint distinct ids")
    func insertTwiceSameTitle() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Twin"))
        try await editor.performFlowchart(.insertSubgraph(title: "Twin"))
        let ids = subgraphs(editor).map(\.id)
        #expect(ids.count == 3)
        #expect(Set(ids).count == 3)
    }

    @Test("insertSubgraph undo removes the subgraph")
    func insertUndo() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Ephemeral"))
        editor.undoManager.undo()
        #expect(subgraphs(editor).count == 1)
    }

    @Test("empty subgraph source renders without crashing")
    func emptySubgraphRenders() throws {
        let source = "graph TD\n  subgraph empty_1 [Empty]\n  end\n  A[Solo]\n"
        let svg = try source.renderDiagramSVG()
        #expect(svg.contains("<svg"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: BUILD FAILURE — `type 'FlowchartMutation' has no member 'insertSubgraph'`.

(If `renderDiagramSVG()` has a different signature, check `Sources/DiagramKitModel/` String extensions — CLAUDE.md names `renderDiagramSVG(...)` as a `String` instance method; adjust the *test* call site only.)

- [ ] **Step 3: Implement**

Create `Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift`:

```swift
// Visual editor plan 3 — subgraph forest mutations.
//
// CONCURRENCY / UNDO NOTE: `MermaidSubgraph` is a mutable final class.
// Undo snapshots hold references to the same instances, so every
// mutation here deep-copies the forest first (`_copySubgraphForest`)
// and mutates only the copies. Mutating a subgraph in place would
// silently corrupt every snapshot on the undo stack.

import DiagramKitCommon
import DiagramKitModel

extension DiagramEditor {

    // MARK: - Forest helpers

    static func _copySubgraphForest(
        _ subs: [original_src_types.MermaidSubgraph]
    ) -> [original_src_types.MermaidSubgraph] {
        subs.map { sub in
            original_src_types.MermaidSubgraph(
                id: sub.id,
                label: sub.label,
                nodeIds: sub.nodeIds,
                children: _copySubgraphForest(sub.children),
                direction: sub.direction,
                shape: sub.shape,
                altBkg: sub.altBkg
            )
        }
    }

    static func _findSubgraph(
        _ id: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> original_src_types.MermaidSubgraph? {
        for sub in subs {
            if sub.id == id { return sub }
            if let hit = _findSubgraph(id, in: sub.children) { return hit }
        }
        return nil
    }

    // MARK: - insertSubgraph

    func _insertSubgraph(
        title: String,
        into document: DiagramDocument
    ) throws -> (DiagramDocument, [DiagramDiagnostic]) {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        var (id, diagnostics) = Self.subgraphID(title: title, members: [])
        var salt = 1
        while Self._findSubgraph(id, in: model.subgraphs) != nil {
            (id, _) = Self.subgraphID(title: title, members: ["salt:\(salt)"])
            salt += 1
        }
        var forest = Self._copySubgraphForest(model.subgraphs)
        forest.append(original_src_types.MermaidSubgraph(id: id, label: title, nodeIds: []))
        model.subgraphs = forest
        doc.payload = .flowchart(model)
        return (doc, diagnostics)
    }
}
```

In `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`:

1. Enum case (after `setNodeStyle`):

```swift
    /// Insert a fresh empty subgraph titled `title`. The id is the
    /// deterministic slug+hash of the title, salted on collision so
    /// repeated inserts with the same title stay distinct.
    case insertSubgraph(title: String)
```

2. `undoActionName`: `case .insertSubgraph: return "Insert Subgraph"`
3. `==`: `case (.insertSubgraph(let a), .insertSubgraph(let b)): return a == b`
4. `hash(into:)`:

```swift
        case .insertSubgraph(let title):
            hasher.combine(6)
            hasher.combine(title)
```

5. `_applyFlowchart`: `case .insertSubgraph(let title): return try _insertSubgraph(title: title, into: document)`

In `Sources/DiagramKitSample/Models/LiveEditorStore.swift` — `undoKind(for: FlowchartMutation)` gains `case .insertSubgraph: return .groupIntoSubgraph`; `undoLabel(for:)` gains:

```swift
        case .insertSubgraph(let title):
            return "Insert subgraph \(title)"
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: PASS (4 tests). If `emptySubgraphRenders` crashes in layout, STOP — that is a real empty-compound-node layout bug to fix before shipping empty-subgraph UI; investigate `_buildSubgraphNode` with zero children.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift
git commit -m "Visual editor 3a — insertSubgraph mutation + subgraph forest deep-copy helpers"
```

---

### Task 2: `moveToSubgraph` mutation

**Files:**
- Modify: `Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (undo switch arms)
- Test: append to `Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift`

**Interfaces:**
- Consumes: `_copySubgraphForest`, `_findSubgraph` (Task 1).
- Produces: `FlowchartMutation.moveToSubgraph(selections: [DiagramSelection], target: String?)` — `nil` target = move to root. Task 6 (drag-to-join) and Task 7 (context menu) call it.

- [ ] **Step 1: Add failing tests**

Append inside `struct FlowchartSubgraphOpsTests`:

```swift
    // MARK: - moveToSubgraph

    @Test("moveToSubgraph adds a root node to the target subgraph")
    func moveIntoGroup() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("C")], target: "g1"))
        #expect(subgraphs(editor).first?.nodeIds == ["A", "B", "C"])
    }

    @Test("moveToSubgraph with nil target moves a member to root")
    func moveToRoot() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("A")], target: nil))
        #expect(subgraphs(editor).first?.nodeIds == ["B"])
    }

    @Test("moveToSubgraph between groups removes from the old group")
    func moveBetweenGroups() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.insertSubgraph(title: "Second"))
        let secondID = subgraphs(editor).first { $0.label == "Second" }!.id
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("A")], target: secondID))
        let subs = subgraphs(editor)
        #expect(subs.first { $0.id == "g1" }?.nodeIds == ["B"])
        #expect(subs.first { $0.id == secondID }?.nodeIds == ["A"])
    }

    @Test("moveToSubgraph unknown target throws elementNotFound")
    func moveUnknownTarget() async {
        let editor = makeEditor(groupedDoc())
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.moveToSubgraph(selections: [node("C")], target: "nope"))
        }
    }

    @Test("moveToSubgraph undo restores previous membership (deep-copy pin)")
    func moveUndoRestoresMembership() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.moveToSubgraph(selections: [node("A")], target: nil))
        editor.undoManager.undo()
        // Fails if the mutation edited the shared MermaidSubgraph
        // instance instead of a deep copy.
        #expect(subgraphs(editor).first?.nodeIds == ["A", "B"])
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: BUILD FAILURE — no member `moveToSubgraph`.

- [ ] **Step 3: Implement**

In `FlowchartSubgraphOps.swift`, add:

```swift
    // MARK: - moveToSubgraph

    static func _removeNodeIDs(
        _ ids: Set<String>,
        from subs: [original_src_types.MermaidSubgraph]
    ) {
        for sub in subs {
            sub.nodeIds.removeAll { ids.contains($0) }
            _removeNodeIDs(ids, from: sub.children)
        }
    }

    func _moveToSubgraph(
        selections: [DiagramSelection],
        target: String?,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        guard !selections.isEmpty else {
            throw DiagramEditorError.invalidSubgraphSelection(reason: "selection is empty")
        }
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        var nodeIDs: [String] = []
        for sel in selections {
            try _validateSelection(sel, matches: document)
            guard sel.elementID.hasPrefix("node:") else {
                throw DiagramEditorError.invalidSubgraphSelection(
                    reason: "selection '\(sel.elementID)' is not a node"
                )
            }
            let id = String(sel.elementID.dropFirst(5))
            guard model.nodesInOrder.contains(where: { $0.id == id }) else {
                throw DiagramEditorError.elementNotFound(id: id, kind: "node")
            }
            nodeIDs.append(id)
        }

        let forest = Self._copySubgraphForest(model.subgraphs)
        if let target, Self._findSubgraph(target, in: forest) == nil {
            throw DiagramEditorError.elementNotFound(id: target, kind: "subgraph")
        }
        Self._removeNodeIDs(Set(nodeIDs), from: forest)
        if let target, let destination = Self._findSubgraph(target, in: forest) {
            destination.nodeIds.append(contentsOf: nodeIDs)
        }
        model.subgraphs = forest
        doc.payload = .flowchart(model)
        return doc
    }
```

In `DiagramEditor+Flowchart.swift`:

1. Case: `case moveToSubgraph(selections: [DiagramSelection], target: String?)` with doc comment "Re-parent node membership; `nil` target = move to root."
2. `undoActionName`: `case .moveToSubgraph: return "Move To Subgraph"`
3. `==`: `case (.moveToSubgraph(let aS, let aT), .moveToSubgraph(let bS, let bT)): return aS == bS && aT == bT`
4. `hash`: discriminator `7`, combine selections + target.
5. `_applyFlowchart`: `case .moveToSubgraph(let selections, let target): return (try _moveToSubgraph(selections: selections, target: target, into: document), [])`

`LiveEditorStore.swift`: `undoKind` → `.setLabel`; `undoLabel`:

```swift
        case .moveToSubgraph(let selections, let target):
            return "Move \(selections.count) node(s) → \(target ?? "root")"
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift
git commit -m "Visual editor 3b — moveToSubgraph mutation with undo-safe forest copy"
```

---

### Task 3: `ungroupSubgraph` + `renameSubgraph` mutations

**Files:**
- Modify: `Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (undo switch arms)
- Test: append to `Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift`

**Interfaces:**
- Consumes: `_copySubgraphForest`, `_findSubgraph`.
- Produces: `FlowchartMutation.ungroupSubgraph(id: String)`, `FlowchartMutation.renameSubgraph(id: String, title: String)`. Task 7 calls both.

- [ ] **Step 1: Add failing tests**

Append inside the suite:

```swift
    // MARK: - ungroupSubgraph

    @Test("ungroupSubgraph removes the group, keeps nodes and edges")
    func ungroupRoot() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.ungroupSubgraph(id: "g1"))
        #expect(subgraphs(editor).isEmpty)
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.nodesInOrder.count == 3)
        #expect(model.edges.count == 1)
    }

    @Test("ungroup nested subgraph promotes members and children to parent")
    func ungroupNested() async throws {
        let inner = original_src_types.MermaidSubgraph(id: "inner", label: "Inner", nodeIds: ["B"])
        let outer = original_src_types.MermaidSubgraph(
            id: "outer", label: "Outer", nodeIds: ["A"], children: [inner]
        )
        let nodes = ["A", "B"].map {
            (id: $0, node: original_src_types.MermaidNode(id: $0, label: $0, shape: .rectangle))
        }
        let model = original_src_types.MermaidGraph(
            direction: .TD, nodesInOrder: nodes, edges: [], subgraphs: [outer]
        )
        let editor = makeEditor(DiagramDocument(payload: .flowchart(model)))

        try await editor.performFlowchart(.ungroupSubgraph(id: "inner"))

        let subs = subgraphs(editor)
        #expect(subs.count == 1)
        #expect(subs.first?.id == "outer")
        #expect(Set(subs.first?.nodeIds ?? []) == Set(["A", "B"]))
        #expect(subs.first?.children.isEmpty == true)
    }

    @Test("ungroup unknown id throws")
    func ungroupUnknown() async {
        let editor = makeEditor(groupedDoc())
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.ungroupSubgraph(id: "nope"))
        }
    }

    @Test("ungroup undo restores the group (deep-copy pin)")
    func ungroupUndo() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.ungroupSubgraph(id: "g1"))
        editor.undoManager.undo()
        #expect(subgraphs(editor).count == 1)
        #expect(subgraphs(editor).first?.nodeIds == ["A", "B"])
    }

    // MARK: - renameSubgraph

    @Test("renameSubgraph changes the label and keeps the id")
    func rename() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.renameSubgraph(id: "g1", title: "Renamed"))
        #expect(subgraphs(editor).first?.label == "Renamed")
        #expect(subgraphs(editor).first?.id == "g1")
    }

    @Test("rename unknown id throws")
    func renameUnknown() async {
        let editor = makeEditor(groupedDoc())
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.renameSubgraph(id: "nope", title: "X"))
        }
    }

    @Test("rename undo restores the old label (deep-copy pin)")
    func renameUndo() async throws {
        let editor = makeEditor(groupedDoc())
        try await editor.performFlowchart(.renameSubgraph(id: "g1", title: "Renamed"))
        editor.undoManager.undo()
        #expect(subgraphs(editor).first?.label == "Group One")
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: BUILD FAILURE — no member `ungroupSubgraph`.

- [ ] **Step 3: Implement**

In `FlowchartSubgraphOps.swift`, add:

```swift
    // MARK: - ungroupSubgraph

    func _ungroupSubgraph(
        id: String,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        var forest = Self._copySubgraphForest(model.subgraphs)

        if let idx = forest.firstIndex(where: { $0.id == id }) {
            // Root-level: children float up to root; member nodes
            // simply lose group membership (they stay in nodesInOrder).
            let sub = forest.remove(at: idx)
            forest.insert(contentsOf: sub.children, at: idx)
        } else if let parent = Self._findParent(of: id, in: forest) {
            let idx = parent.children.firstIndex { $0.id == id }!
            let sub = parent.children.remove(at: idx)
            parent.children.insert(contentsOf: sub.children, at: idx)
            parent.nodeIds.append(contentsOf: sub.nodeIds)
        } else {
            throw DiagramEditorError.elementNotFound(id: id, kind: "subgraph")
        }

        model.subgraphs = forest
        doc.payload = .flowchart(model)
        return doc
    }

    static func _findParent(
        of id: String,
        in subs: [original_src_types.MermaidSubgraph]
    ) -> original_src_types.MermaidSubgraph? {
        for sub in subs {
            if sub.children.contains(where: { $0.id == id }) { return sub }
            if let hit = _findParent(of: id, in: sub.children) { return hit }
        }
        return nil
    }

    // MARK: - renameSubgraph

    func _renameSubgraph(
        id: String,
        title: String,
        into document: DiagramDocument
    ) throws -> DiagramDocument {
        var doc = document
        guard case .flowchart(var model) = doc.payload else {
            throw DiagramEditorError.notAFlowchart
        }
        let forest = Self._copySubgraphForest(model.subgraphs)
        guard let sub = Self._findSubgraph(id, in: forest) else {
            throw DiagramEditorError.elementNotFound(id: id, kind: "subgraph")
        }
        sub.label = title
        model.subgraphs = forest
        doc.payload = .flowchart(model)
        return doc
    }
```

In `DiagramEditor+Flowchart.swift`: cases `ungroupSubgraph(id: String)` (doc: "Dissolve a subgraph, promoting members and children to its parent scope") and `renameSubgraph(id: String, title: String)` (doc: "Retitle; the stable id is preserved"); `undoActionName` "Ungroup Subgraph" / "Rename Subgraph"; `==` field-wise; `hash` discriminators `8` and `9`; `_applyFlowchart` arms returning `(try _ungroupSubgraph(id: id, into: document), [])` and `(try _renameSubgraph(id: id, title: title, into: document), [])`.

`LiveEditorStore.swift`: `undoKind` → `.setLabel` for both; `undoLabel`:

```swift
        case .ungroupSubgraph(let id):
            return "Ungroup \(id)"
        case .renameSubgraph(let id, let title):
            return "Rename \(id) → \(title)"
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: PASS (16 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift
git commit -m "Visual editor 3c — ungroupSubgraph + renameSubgraph mutations"
```

---

### Task 4: `deleteElement` on `group:` selections

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift` (`_deleteElement`)
- Modify: `Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift` (extract/collect helpers)
- Test: append to `Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift`

**Interfaces:**
- Consumes: `_copySubgraphForest`.
- Produces: `DiagramMutation.deleteElement` accepting `group:<id>` — removes the subgraph tree, its member nodes (transitive), and incident edges. Task 7's context menu uses it.

- [ ] **Step 1: Add failing tests**

```swift
    // MARK: - deleteElement(group:)

    @Test("deleteElement on a group removes subgraph, member nodes, and incident edges")
    func deleteGroup() async throws {
        let editor = makeEditor(groupedDoc())
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "group:g1")
        try await editor.perform(.deleteElement(sel))
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.subgraphs.isEmpty)
        #expect(model.nodesInOrder.map(\.id) == ["C"])
        #expect(model.edges.isEmpty)  // A→C died with A
    }

    @Test("deleteElement on unknown group throws")
    func deleteUnknownGroup() async {
        let editor = makeEditor(groupedDoc())
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "group:nope")
        await #expect(throws: DiagramEditorError.self) {
            try await editor.perform(.deleteElement(sel))
        }
    }

    @Test("deleteElement group undo restores everything (deep-copy pin)")
    func deleteGroupUndo() async throws {
        let editor = makeEditor(groupedDoc())
        let sel = DiagramSelection(diagramType: .flowchart, elementID: "group:g1")
        try await editor.perform(.deleteElement(sel))
        editor.undoManager.undo()
        guard case .flowchart(let model) = editor.document.payload else {
            #expect(Bool(false)); return
        }
        #expect(model.subgraphs.count == 1)
        #expect(model.nodesInOrder.count == 3)
        #expect(model.edges.count == 1)
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: `deleteGroup` and `deleteGroupUndo` FAIL (throws `.unknownElementKind`); `deleteUnknownGroup` passes vacuously (wrong error, still `DiagramEditorError`) — acceptable.

- [ ] **Step 3: Implement**

In `FlowchartSubgraphOps.swift`, add:

```swift
    // MARK: - Group deletion support

    /// Remove and return the subgraph with `id` from a (copied)
    /// forest, searching recursively. Returns nil when absent.
    static func _extractSubgraph(
        _ id: String,
        from forest: inout [original_src_types.MermaidSubgraph]
    ) -> original_src_types.MermaidSubgraph? {
        if let idx = forest.firstIndex(where: { $0.id == id }) {
            return forest.remove(at: idx)
        }
        for sub in forest {
            var children = sub.children
            if let hit = _extractSubgraph(id, from: &children) {
                sub.children = children
                return hit
            }
        }
        return nil
    }

    /// All node ids transitively contained in `sub` (its own plus
    /// every descendant subgraph's).
    static func _allMemberNodeIDs(in sub: original_src_types.MermaidSubgraph) -> Set<String> {
        var ids = Set(sub.nodeIds)
        for child in sub.children {
            ids.formUnion(_allMemberNodeIDs(in: child))
        }
        return ids
    }
```

In `Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift`, in `_deleteElement`'s `_withFlowGraphPayload` closure, insert a new branch between the `edge:` branch and the final `else`:

```swift
            } else if id.hasPrefix("group:") {
                let groupID = String(id.dropFirst(6))
                var forest = Self._copySubgraphForest(graph.subgraphs)
                guard let removed = Self._extractSubgraph(groupID, from: &forest) else {
                    throw DiagramEditorError.elementNotFound(id: groupID, kind: "subgraph")
                }
                let memberIDs = Self._allMemberNodeIDs(in: removed)
                graph.subgraphs = forest
                graph.nodesInOrder.removeAll { memberIDs.contains($0.id) }
                graph.edges.removeAll {
                    memberIDs.contains($0.source) || memberIDs.contains($0.target)
                }
            } else {
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowchartSubgraphOpsTests`
Expected: PASS (19 tests).

Also: `swift test --filter DiagramEditorMutationTests` and `swift test --filter DiagramMutationTests` — Expected: PASS (delete/label paths untouched for node/edge).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/DiagramEditor+Mutations.swift Sources/DiagramKitInteractive/FlowchartSubgraphOps.swift Tests/DiagramKitTests/Interactive/FlowchartSubgraphOpsTests.swift
git commit -m "Visual editor 3d — deleteElement handles group: selections (subgraph + members + edges)"
```

---

### Task 5: Store prompts + toolbar Subgraph button + title sheet

**Files:**
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (two stored properties)
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift` (methods)
- Create: `Sources/DiagramKitSample/Views/Visual/SubgraphTitleSheet.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/VisualPane.swift` (sheet wiring)
- Test: `Tests/DiagramKitTests/Playground/SubgraphToolbarFlowTests.swift`

**Interfaces:**
- Consumes: `insertSubgraph`/`renameSubgraph`/`moveToSubgraph`/`deleteElement` mutations; `performFlowchartMutation`/`performMutation`; `editor.beginUndoGrouping()/endUndoGrouping()`.
- Produces (Tasks 6–7 use):
  - Stored: `var subgraphTitlePrompt: SubgraphTitlePrompt?` where `enum SubgraphTitlePrompt: Equatable { case insertEmpty; case rename(id: String, currentTitle: String) }`
  - `func openEmptySubgraphPrompt()`, `func openRenamePrompt(subgraphID: String)`, `func cancelTitlePrompt()`, `func commitTitlePrompt(title: String) async`
  - `var flowchartSubgraphs: [(id: String, label: String)]` (flattened forest, depth-first)
  - `func subgraphID(containing nodeID: String) -> String?` (deepest membership)
  - `func deleteMarqueeSelection() async` (one undo group)

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/SubgraphToolbarFlowTests.swift`:

```swift
//
//  SubgraphToolbarFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 3 — store-side subgraph flows: empty-insert
//  prompt, rename prompt, membership query, marquee delete.
//

#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class SubgraphToolbarFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    private let groupedSource = """
    graph TD
      subgraph g1 [Group One]
        A --> B
      end
      C
    """

    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never became available")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    private func makeStore() async throws -> LiveEditorStore {
        let store = LiveEditorStore(state: LiveEditorState(source: groupedSource))
        try await waitForEditor(store: store)
        return store
    }

    func test_commitEmptySubgraphPromptInsertsSubgraph() async throws {
        let store = try await makeStore()
        store.openEmptySubgraphPrompt()
        XCTAssertEqual(store.subgraphTitlePrompt, .insertEmpty)
        await store.commitTitlePrompt(title: "Fresh")
        XCTAssertNil(store.subgraphTitlePrompt)
        XCTAssertTrue(store.flowchartSubgraphs.contains { $0.label == "Fresh" })
    }

    func test_commitRenamePromptRenames() async throws {
        let store = try await makeStore()
        store.openRenamePrompt(subgraphID: "g1")
        guard case .rename(let id, let current) = store.subgraphTitlePrompt else {
            XCTFail("expected rename prompt"); return
        }
        XCTAssertEqual(id, "g1")
        XCTAssertEqual(current, "Group One")
        await store.commitTitlePrompt(title: "Renamed")
        XCTAssertTrue(store.flowchartSubgraphs.contains { $0.label == "Renamed" })
    }

    func test_subgraphContainingNode() async throws {
        let store = try await makeStore()
        XCTAssertEqual(store.subgraphID(containing: "A"), "g1")
        XCTAssertNil(store.subgraphID(containing: "C"))
    }

    func test_deleteMarqueeSelectionDeletesAllInOneUndoStep() async throws {
        let store = try await makeStore()
        store.setMarqueeSelection(["node:A", "node:C"])
        await store.deleteMarqueeSelection()

        guard case .flowchart(let model) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        XCTAssertEqual(model.nodesInOrder.map(\.id), ["B"])
        XCTAssertTrue(store.state.marqueeSelection.isEmpty)

        store.editor?.undoManager.undo()
        guard case .flowchart(let restored) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        XCTAssertEqual(restored.nodesInOrder.count, 3)
    }
}
#endif
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter SubgraphToolbarFlowTests`
Expected: BUILD FAILURE — no member `openEmptySubgraphPrompt`.

- [ ] **Step 3: Implement store side**

In `Sources/DiagramKitSample/Models/LiveEditorStore.swift`, next to `isSubgraphPromptOpen`'s declaration (search `isSubgraphPromptOpen` — it is a stored property on the class), add:

```swift
    /// Active subgraph title prompt (empty-insert or rename), or nil.
    public var subgraphTitlePrompt: SubgraphTitlePrompt?
```

In `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift`, add at file scope (near `SubgraphCommit`):

```swift
/// Which flavor of subgraph title prompt is open.
public enum SubgraphTitlePrompt: Equatable, Sendable {
    case insertEmpty
    case rename(id: String, currentTitle: String)
}
```

and inside `extension LiveEditorStore` (after `dismissSubgraphToast`):

```swift
    // MARK: - Subgraph toolbar / rename / membership (visual editor plan 3)

    public func openEmptySubgraphPrompt() {
        subgraphTitlePrompt = .insertEmpty
    }

    public func openRenamePrompt(subgraphID: String) {
        let title = flowchartSubgraphs.first { $0.id == subgraphID }?.label ?? subgraphID
        subgraphTitlePrompt = .rename(id: subgraphID, currentTitle: title)
    }

    public func cancelTitlePrompt() {
        subgraphTitlePrompt = nil
    }

    public func commitTitlePrompt(title: String) async {
        guard let prompt = subgraphTitlePrompt else { return }
        defer { subgraphTitlePrompt = nil }
        do {
            switch prompt {
            case .insertEmpty:
                try await performFlowchartMutation(.insertSubgraph(title: title))
            case .rename(let id, _):
                try await performFlowchartMutation(.renameSubgraph(id: id, title: title))
            }
        } catch {
            // performFlowchartMutation already recorded the error.
        }
    }

    /// Flattened subgraph forest, depth-first (parents before children).
    public var flowchartSubgraphs: [(id: String, label: String)] {
        guard let payload = editor?.document.payload else { return [] }
        let roots: [original_src_types.MermaidSubgraph]
        switch payload {
        case .flowchart(let graph), .stateDiagram(let graph):
            roots = graph.subgraphs
        default:
            return []
        }
        var out: [(id: String, label: String)] = []
        func walk(_ subs: [original_src_types.MermaidSubgraph]) {
            for sub in subs {
                out.append((id: sub.id, label: sub.label))
                walk(sub.children)
            }
        }
        walk(roots)
        return out
    }

    /// Deepest subgraph directly containing `nodeID`, or nil at root.
    public func subgraphID(containing nodeID: String) -> String? {
        guard let payload = editor?.document.payload else { return nil }
        let roots: [original_src_types.MermaidSubgraph]
        switch payload {
        case .flowchart(let graph), .stateDiagram(let graph):
            roots = graph.subgraphs
        default:
            return nil
        }
        func walk(_ subs: [original_src_types.MermaidSubgraph]) -> String? {
            for sub in subs {
                if let deeper = walk(sub.children) { return deeper }
                if sub.nodeIds.contains(nodeID) { return sub.id }
            }
            return nil
        }
        return walk(roots)
    }

    /// Delete every marquee-selected element as one undo step.
    public func deleteMarqueeSelection() async {
        guard let editor, !state.marqueeSelection.isEmpty else { return }
        let type = editor.document.type
        editor.beginUndoGrouping()
        for id in state.marqueeSelection.sorted() {
            let sel = DiagramSelection(diagramType: type, elementID: id)
            try? await performMutation(.deleteElement(sel))
        }
        editor.endUndoGrouping()
        setMarqueeSelection([])
        setVisualStage(.idle)
    }
```

- [ ] **Step 4: Run store tests**

Run: `swift test --filter SubgraphToolbarFlowTests`
Expected: PASS (4 tests). (`deleteMarqueeSelection` sorted order: deleting `node:A` kills edge A→B too; deleting `node:C` leaves `B` — matches the assertion.)

- [ ] **Step 5: UI — title sheet, toolbar button, pane wiring**

Create `Sources/DiagramKitSample/Views/Visual/SubgraphTitleSheet.swift`:

```swift
//
//  SubgraphTitleSheet.swift
//  DiagramPlayground
//
//  Shared title prompt for empty-subgraph insert and subgraph rename
//  (visual editor plan 3). Sibling of SubgraphPromptSheet, which
//  remains dedicated to the marquee → group flow.
//

import SwiftUI

struct SubgraphTitleSheet: View {
    @Bindable var store: LiveEditorStore
    let prompt: SubgraphTitlePrompt

    @SwiftUI.State private var titleDraft: String = ""

    private var heading: String {
        switch prompt {
        case .insertEmpty: return "Name the new subgraph"
        case .rename: return "Rename subgraph"
        }
    }

    private var commitLabel: String {
        switch prompt {
        case .insertEmpty: return "Add"
        case .rename: return "Rename"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(heading)
                .font(.system(size: 13, weight: .semibold))
            TextField("Subgraph title", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") {
                    store.cancelTitlePrompt()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                Spacer()
                Button(commitLabel) {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    guard !title.isEmpty else { return }
                    Task { await store.commitTitlePrompt(title: title) }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(titleDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
        .onAppear {
            if case .rename(_, let current) = prompt {
                titleDraft = current
            }
        }
    }
}
```

In `CanvasCenterToolbar.swift`, after the Shapes button (inside the `HStack`):

```swift
            Button {
                store.openEmptySubgraphPrompt()
            } label: {
                Label("Subgraph", systemImage: "rectangle.3.group")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Add a labeled group to the canvas")
            .accessibilityIdentifier(A11yID.Visual.subgraphButton)
```

Add to `A11yID.Visual` in `View+Accessibility.swift`:

```swift
        public static let subgraphButton = "visual.centerToolbar.subgraph"
```

In `VisualPane.swift`'s `subgraphLayer`, after the existing `isSubgraphPromptOpen` block:

```swift
        if let prompt = store.subgraphTitlePrompt {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { store.cancelTitlePrompt() }
                SubgraphTitleSheet(store: store, prompt: prompt)
            }
        }
```

- [ ] **Step 6: Build + commit**

Run: `swift build` — Expected: Build complete.

```bash
git add Sources/DiagramKitSample/Models/LiveEditorStore.swift Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift Sources/DiagramKitSample/Views/Visual/SubgraphTitleSheet.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/Visual/VisualPane.swift Sources/DiagramKitSample/Views/Support/View+Accessibility.swift Tests/DiagramKitTests/Playground/SubgraphToolbarFlowTests.swift
git commit -m "Visual editor 3e — toolbar Subgraph button + title prompts + store subgraph queries"
```

---

### Task 6: Drag-to-join on the select tool

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift`

**Interfaces:**
- Consumes: `store.performFlowchartMutation(.moveToSubgraph…)`, `store.subgraphID(containing:)`, `liveBoundsLookup.allElementIDs/selection(for:)/bounds(of:)`, existing `diagramPoint`/`viewRect`/`nodeID(at:in:)` helpers.
- Produces: UI behavior only — drag a node (select tool) → ghost follows cursor, hovered subgraph boundary highlights, drop inside → `moveToSubgraph(target:)`, drop on empty canvas from inside a group → `moveToSubgraph(target: nil)`, unchanged membership → no mutation.

- [ ] **Step 1: Add drag state and helpers**

In `FlowchartEditCanvas.swift`, add state vars (after `edgeDragSourceID`):

```swift
    // Visual editor plan 3 — drag-to-join (select tool).
    @SwiftUI.State private var nodeDragElementID: String?
    @SwiftUI.State private var nodeDragCurrent: CGPoint?
    @SwiftUI.State private var dropTargetGroupID: String?
```

Add helpers (near `nodeID(at:in:)`):

```swift
    /// Deepest (smallest-area) subgraph whose bounds contain the view
    /// point. Returns the bare subgraph id (no "group:" prefix).
    private func groupID(at viewPoint: CGPoint, in viewSize: CGSize) -> String? {
        guard let lookup = liveBoundsLookup else { return nil }
        let p = diagramPoint(from: viewPoint, viewSize: viewSize)
        var best: (id: String, area: Double)?
        for elementID in lookup.allElementIDs where elementID.hasPrefix("group:") {
            guard
                let sel = lookup.selection(for: elementID),
                let b = lookup.bounds(of: sel),
                b.contains(p)
            else { continue }
            let area = b.width * b.height
            if best == nil || area < best!.area {
                best = (String(elementID.dropFirst(6)), area)
            }
        }
        return best?.id
    }
```

(If `DiagramRect.contains(_:)` takes a labeled parameter, match the call in `DiagramBoundsLookup.swift:133`.)

- [ ] **Step 2: Wire the select-tool drag**

In `handleDragChanged`, replace the `case .select, .pan:` arm with:

```swift
        case .select:
            if nodeDragElementID == nil {
                guard
                    let elementID = nodeID(at: value.startLocation, in: viewSize),
                    elementID.hasPrefix("node:")
                else { break }
                nodeDragElementID = elementID
            }
            nodeDragCurrent = value.location
            dropTargetGroupID = groupID(at: value.location, in: viewSize)
        case .pan:
            break
```

In `handleDragEnded`, extend the `defer` block to also clear the new state:

```swift
            nodeDragElementID = nil
            nodeDragCurrent = nil
            dropTargetGroupID = nil
```

and replace its `case .select, .pan:` arm with:

```swift
        case .select:
            commitNodeDrag(end: value.location, viewSize: viewSize)
        case .pan:
            break
```

Add the commit:

```swift
    // MARK: - Drag-to-join commit (visual editor plan 3)

    private func commitNodeDrag(end: CGPoint, viewSize: CGSize) {
        guard let elementID = nodeDragElementID else { return }
        let nodeID = String(elementID.dropFirst(5))
        let target = groupID(at: end, in: viewSize)
        let current = store.subgraphID(containing: nodeID)
        guard target != current else { return }  // unchanged → no mutation
        let sel = DiagramSelection(diagramType: editorType, elementID: elementID)
        Task {
            try? await store.performFlowchartMutation(
                .moveToSubgraph(selections: [sel], target: target)
            )
        }
    }
```

- [ ] **Step 3: Ghost + highlight overlays**

In `body`'s `ZStack` (after the `edgeRubberBand` block):

```swift
                if let current = nodeDragCurrent, let elementID = nodeDragElementID {
                    nodeDragGhost(at: current, elementID: elementID, in: geometry)
                }
                if let targetID = dropTargetGroupID {
                    dropTargetHighlight(groupID: targetID, in: geometry)
                }
```

Add the overlay builders:

```swift
    // MARK: - Drag-to-join overlays

    @ViewBuilder
    private func nodeDragGhost(at point: CGPoint, elementID: String, in geometry: GeometryProxy) -> some View {
        let sel = DiagramSelection(diagramType: editorType, elementID: elementID)
        let size: CGSize = {
            if let b = liveBoundsLookup?.bounds(of: sel) {
                return CGSize(width: CGFloat(b.width), height: CGFloat(b.height))
            }
            return CGSize(width: 80, height: 36)
        }()
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentColor.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
            )
            .frame(width: size.width, height: size.height)
            .position(point)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func dropTargetHighlight(groupID: String, in geometry: GeometryProxy) -> some View {
        let sel = DiagramSelection(diagramType: editorType, elementID: "group:\(groupID)")
        if let bounds = liveBoundsLookup?.bounds(of: sel) {
            let rect = viewRect(for: bounds, in: geometry.size)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.green.opacity(0.85), lineWidth: 2.5)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
    }
```

- [ ] **Step 4: Build + regression tests**

Run: `swift build` — Expected: Build complete.
Run: `swift test --filter FlowchartEditCanvasStageTests` — Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift
git commit -m "Visual editor 3f — drag-to-join: node ghost, boundary highlight, moveToSubgraph on drop"
```

---

### Task 7: Right-click context menus + edge popover dispatch

**Files:**
- Create: `Sources/DiagramKitSample/Views/Visual/Flowchart/CanvasContextMenu.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift` (hover tracking + `.contextMenu`)
- Modify: `Sources/DiagramKitSample/Views/Visual/VisualPane.swift` (edge vs node popover dispatch)

**Interfaces:**
- Consumes: all plan-3 mutations via store helpers; `ShapeCatalogCategory` (plan 2); `store.flowchartSubgraphs`, `store.subgraphID(containing:)`, `store.deleteMarqueeSelection()`, `store.openRenamePrompt(subgraphID:)`, `store.openEmptySubgraphPrompt()`, `store.insertShapeFromCatalog(alias:)`.
- Produces: UI only.

- [ ] **Step 1: Create the menu component**

Create `Sources/DiagramKitSample/Views/Visual/Flowchart/CanvasContextMenu.swift`:

```swift
//
//  CanvasContextMenu.swift
//  DiagramPlayground
//
//  Right-click menu for the flowchart canvas (visual editor plan 3).
//  The canvas resolves the element under the cursor at menu-open time
//  (via continuous hover tracking) and passes it here.
//

import SwiftUI
import DiagramKitInteractive

struct CanvasContextMenu: View {
    @Bindable var store: LiveEditorStore
    let element: DiagramSelection?

    var body: some View {
        if !store.state.marqueeSelection.isEmpty {
            multiSelectionMenu
        } else if let element {
            if element.elementID.hasPrefix("node:") {
                nodeMenu(element)
            } else if element.elementID.hasPrefix("edge:") {
                edgeMenu(element)
            } else if element.elementID.hasPrefix("group:") {
                groupMenu(element)
            } else {
                emptyCanvasMenu
            }
        } else {
            emptyCanvasMenu
        }
    }

    // MARK: - Node

    @ViewBuilder
    private func nodeMenu(_ element: DiagramSelection) -> some View {
        let nodeID = String(element.elementID.dropFirst(5))
        Button("Edit…") {
            store.editor?.selection = element
            store.setVisualStage(.labelEdited)
        }
        Menu("Change shape") {
            ForEach(ShapeCatalogCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.items) { item in
                        Button(item.name) {
                            Task {
                                try? await store.performFlowchartMutation(
                                    .setNodeShape(of: element, toShape: item.alias)
                                )
                            }
                        }
                    }
                }
            }
        }
        Menu("Move to subgraph") {
            if store.subgraphID(containing: nodeID) != nil {
                Button("Root (no subgraph)") {
                    move(element, to: nil)
                }
            }
            ForEach(store.flowchartSubgraphs, id: \.id) { sub in
                if sub.id != store.subgraphID(containing: nodeID) {
                    Button(sub.label) {
                        move(element, to: sub.id)
                    }
                }
            }
        }
        Divider()
        deleteButton(element, label: "Delete")
    }

    private func move(_ element: DiagramSelection, to target: String?) {
        Task {
            try? await store.performFlowchartMutation(
                .moveToSubgraph(selections: [element], target: target)
            )
        }
    }

    // MARK: - Edge

    @ViewBuilder
    private func edgeMenu(_ element: DiagramSelection) -> some View {
        Button("Edit…") {
            store.editor?.selection = element
            store.setVisualStage(.labelEdited)
        }
        Divider()
        deleteButton(element, label: "Delete")
    }

    // MARK: - Group

    @ViewBuilder
    private func groupMenu(_ element: DiagramSelection) -> some View {
        let groupID = String(element.elementID.dropFirst(6))
        Button("Rename…") {
            store.openRenamePrompt(subgraphID: groupID)
        }
        Button("Ungroup") {
            Task {
                try? await store.performFlowchartMutation(.ungroupSubgraph(id: groupID))
            }
        }
        Divider()
        deleteButton(element, label: "Delete Subgraph")
    }

    // MARK: - Multi-selection

    @ViewBuilder
    private var multiSelectionMenu: some View {
        Button("Group into subgraph…") {
            store.openSubgraphPrompt()
        }
        Divider()
        Button("Delete \(store.state.marqueeSelection.count) elements", role: .destructive) {
            Task { await store.deleteMarqueeSelection() }
        }
    }

    // MARK: - Empty canvas

    @ViewBuilder
    private var emptyCanvasMenu: some View {
        Menu("Add shape") {
            ForEach(ShapeCatalogCategory.allCases) { category in
                Section(category.title) {
                    ForEach(category.items) { item in
                        Button(item.name) {
                            Task { await store.insertShapeFromCatalog(alias: item.alias) }
                        }
                    }
                }
            }
        }
        Button("Add subgraph") {
            store.openEmptySubgraphPrompt()
        }
    }

    // MARK: - Shared

    private func deleteButton(_ element: DiagramSelection, label: String) -> some View {
        Button(label, role: .destructive) {
            Task { try? await store.performMutation(.deleteElement(element)) }
        }
    }
}
```

- [ ] **Step 2: Attach to the canvas with hover tracking**

In `FlowchartEditCanvas.swift`:

1. State (after `dropTargetGroupID`):

```swift
    // Visual editor plan 3 — right-click needs a position; SwiftUI's
    // contextMenu doesn't provide one, so track the last hover point.
    @SwiftUI.State private var hoverPoint: CGPoint?
```

2. After `.simultaneousGesture(doubleTapGesture(in: geometry))`, add:

```swift
            .onContinuousHover { phase in
                if case .active(let point) = phase {
                    hoverPoint = point
                }
            }
            .contextMenu {
                CanvasContextMenu(store: store, element: elementAtHover(in: geometry.size))
            }
```

3. Helper:

```swift
    private func elementAtHover(in viewSize: CGSize) -> DiagramSelection? {
        guard let hoverPoint, let lookup = liveBoundsLookup else { return nil }
        return lookup.element(at: diagramPoint(from: hoverPoint, viewSize: viewSize))
    }
```

- [ ] **Step 3: Fix the edge/node popover dispatch**

In `VisualPane.swift`, replace the `stagePopover`'s `.labelEdited` case body:

```swift
        case .labelEdited:
            VStack {
                Spacer()
                if store.editor?.selection?.elementID.hasPrefix("edge:") == true {
                    EdgeEditPopover(store: store)
                        .padding(.bottom, 60)
                } else {
                    NodeEditPopover(store: store)
                        .padding(.bottom, 60)
                }
            }
```

(`EdgeEditPopover` already exists with line/arrow pickers + delete; this makes it reachable for the first time.)

- [ ] **Step 4: Build + smoke**

Run: `swift build` — Expected: Build complete.
Run: `swift run DiagramKitSample` in background ~8s → running → kill.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/Flowchart/CanvasContextMenu.swift Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift Sources/DiagramKitSample/Views/Visual/VisualPane.swift
git commit -m "Visual editor 3g — right-click context menus + edge popover dispatch"
```

---

### Task 8: Closer — gates + regression sweep

**Files:** none new (verification only).

- [ ] **Step 1: Gates**

```bash
Scripts/check-file-sizes.sh > /dev/null 2>&1; echo "file-sizes: $?"
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh > /dev/null 2>&1; echo "sendable: $?"
```
Expected: all 0 / clean. Watch `FlowchartEditCanvas.swift` — it grows in Tasks 6–7; if it crosses 500 lines the gate only warns, but if it approaches 1000 split the drag-to-join code into `FlowchartEditCanvas+DragToJoin.swift`.

- [ ] **Step 2: Suites**

```bash
swift test --filter FlowchartSubgraphOpsTests
swift test --filter FlowchartSubgraphMutationTests
swift test --filter SubgraphToolbarFlowTests
swift test --filter SubgraphCommitFlowTests
swift test --filter DiagramEditorMutationTests
swift test --filter DiagramEditorUndoTests
swift test --filter ShapeInsertFlowTests
```
Expected: all PASS.

- [ ] **Step 3: Launch smoke**

`swift run DiagramKitSample` background ~8s → running → kill.

- [ ] **Step 4: Commit only if the closer forced fixes** (`"Visual editor 3h — closer fixes"`).

---

## Plan Self-Review (done at authoring time)

- **Spec coverage:** Section 1 mutations (`insertSubgraph`/`moveToSubgraph`/`ungroupSubgraph`/`renameSubgraph`) → Tasks 1–3; Section 3 context menus (node/edge/multi/subgraph/empty-canvas, multi-delete in one undo group) → Tasks 5 (deleteMarqueeSelection) + 7; Section 4 (toolbar button, drag-to-join with ghost + highlight + no-op drop, ungroup) → Tasks 5–6. Spec's "Delete" on subgraph context menu → Task 4 (`deleteElement` group support). Position-animation polish from Section 4 ("node animates to its computed position") ships as the existing render-pipeline transition; no extra animation work — noted deviation, acceptable.
- **Placeholder scan:** clean; the one conditional instruction (Task 1 render-crash stop) names the exact investigation entry point.
- **Type consistency:** `SubgraphTitlePrompt` cases match between store and sheet; `moveToSubgraph(selections:target:)` matches Tasks 2/6/7; discriminators 6–9 unique; `flowchartSubgraphs` tuple shape `(id:label:)` consistent.
- **Risk register:** empty-subgraph layout (pinned by `emptySubgraphRenders`, with explicit stop instruction); `MermaidSubgraph` reference semantics (pinned by three undo tests); `onContinuousHover` position staleness on scroll (cosmetic; canvas doesn't scroll — diagram is centered).
