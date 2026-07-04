# Visual Editor Plan 2/6 — Shape Catalog + Insert Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A bottom-center canvas toolbar with a searchable, categorized shape catalog (Basic / Process / Technical) whose cells show pipeline-rendered previews; clicking a shape inserts a node with the next free id, selects it, and opens the label editor — and the node menu's shape picker is replaced by the same catalog.

**Architecture:** All sample-app work; zero library changes. A pure `ShapeCatalog` data model (alias/name/category) feeds a `ShapeCatalogView` grid whose thumbnails are rendered through the real `DiagramImageRenderer` (one tiny one-node diagram per shape, cached) — previews are correct by construction. `LiveEditorStore` gains `nextFlowchartNodeID()` + `insertShapeFromCatalog(alias:)` which ride the existing `performFlowchartMutation(.insertNode…)` path, then select the node and bounce `visualStage` to `.labelEdited` so the existing `NodeEditPopover` opens.

**Tech Stack:** Swift 6, SwiftUI (macOS-first sample app), XCTest for Playground store tests (matches `Tests/DiagramKitTests/Playground/` convention).

**Spec:** `docs/superpowers/specs/2026-07-04-visual-editor-design.md` Section 3 (toolbar + catalog + insert flow, node-menu shape button). **Spec deviation, intentional:** the spec says previews reuse "the shape path builders (`src_shape_clipping.swift`)" — that file is edge-endpoint clipping, not drawable paths. Previews instead render a one-node diagram through `DiagramImageRenderer` (cached), which is strictly more faithful. The toolbar ships with the Shapes button only; Subgraph/Icon/Image/Rearrange/Theme buttons land with plans 3–6.

## Global Constraints

- Work directly on `main`, commit-by-commit. No branches, no worktrees, no stash.
- Never run bare `swift test` — always `swift test --filter <ExactSuiteName>` (exact suite names; substrings can match corpus parameterized tests and hang).
- Diagnostics only via typed factories (not relevant here — no new emission sites — but the gate runs in the closer).
- Swift files: warn at 500 lines, error at 1000 (`Scripts/check-file-sizes.sh`).
- Playground/store tests are XCTest classes marked `@available(iOS 26.0, macOS 26.0, *)` under `Tests/DiagramKitTests/Playground/`; model-layer tests are swift-testing. Follow whichever the target directory uses.
- `DiagramEngine.bootstrap()` in `setUp` for any test that drives `LiveEditorStore` rendering.
- The store's mutation → `setSource(origin: .mutation)` convention preserves the editor's undo stack — new store methods must call the existing `performFlowchartMutation`, never `editor.performFlowchart` directly.

## Reference — existing APIs this plan builds on (verified)

- `LiveEditorStore.performFlowchartMutation(_: FlowchartMutation) async throws` (`Models/LiveEditorStore.swift:644`) — no-ops when `editor == nil`; records undo entry; pushes source with `.mutation` origin.
- `LiveEditorStore.setSelection(_: DiagramSelection)` and `editor.selection` (used by `LiveEditorStoreEditorLifecycleTests`).
- `LiveEditorStore.setVisualStage(_: VisualEditorState.Stage)` (`Models/LiveEditorStore+Visual.swift:25`); `VisualPane.stagePopover` shows `NodeEditPopover` when `visualStage == .labelEdited` (`Views/Visual/VisualPane.swift:80-90`).
- `LiveEditorStore.previewTheme: DiagramTheme`, `store.theme` — themes for rendering.
- `FlowchartMutation.insertNode(id:label:type:)` — `type` is a shape alias resolved via `NodeShape.resolve(alias:)`; **every `NodeShape` rawValue resolves to itself** (pinned by `MermaidFlowchartMetadataExportTests.rawValuesResolve`, plan 1).
- `DiagramImageRenderer(theme:config:sourceFormat:)`, `.scale`, `@MainActor renderImage(from: String, scale:) async throws -> BMImage?` (`Sources/DiagramKit/DiagramImageRenderer.swift`).
- `A11yID.Visual` namespace (`Views/Support/View+Accessibility.swift:141`).
- `VisualPane` bottom stack: `StateStepper` (optional) then `UndoTimelineView` (`Views/Visual/VisualPane.swift:26-43`) — the center toolbar slots above them.
- `NodeEditPopover` (plan 1) holds `@SwiftUI.State private var shapeAlias: String` and commits `setNodeShape(of:toShape:)`; its interim `Picker` is what this plan replaces.

---

### Task 1: `ShapeCatalog` data model

**Files:**
- Create: `Sources/DiagramKitSample/Models/ShapeCatalog.swift`
- Test: `Tests/DiagramKitTests/Playground/ShapeCatalogTests.swift`

**Interfaces:**
- Consumes: `original_src_types.NodeShape.resolve(alias:)` (test-side validation only).
- Produces (used by Tasks 3–5):
  - `struct ShapeCatalogItem: Identifiable, Hashable { let alias: String; let name: String; var id: String { alias } }`
  - `enum ShapeCatalogCategory: String, CaseIterable, Identifiable { case basic, process, technical; var title: String; var items: [ShapeCatalogItem]; var id: String { rawValue } }`
  - `enum ShapeCatalog { static let all: [ShapeCatalogItem]; static func search(_ query: String) -> [ShapeCatalogItem] }`

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/ShapeCatalogTests.swift`:

```swift
//
//  ShapeCatalogTests.swift
//  DiagramKitTests
//
//  Visual editor plan 2 — catalog data integrity: every alias must
//  resolve, no duplicates, all categories populated, search works.
//

import XCTest
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
final class ShapeCatalogTests: XCTestCase {

    func test_everyAliasResolvesToANodeShape() {
        for item in ShapeCatalog.all {
            XCTAssertNotNil(
                original_src_types.NodeShape.resolve(alias: item.alias),
                "catalog alias '\(item.alias)' does not resolve"
            )
        }
    }

    func test_noDuplicateAliases() {
        let aliases = ShapeCatalog.all.map(\.alias)
        XCTAssertEqual(aliases.count, Set(aliases).count)
    }

    func test_allCategoriesNonEmpty() {
        for category in ShapeCatalogCategory.allCases {
            XCTAssertFalse(category.items.isEmpty, "\(category.rawValue) is empty")
        }
    }

    func test_allEqualsConcatenationOfCategories() {
        let concatenated = ShapeCatalogCategory.allCases.flatMap(\.items)
        XCTAssertEqual(ShapeCatalog.all, concatenated)
    }

    func test_searchMatchesNameCaseInsensitively() {
        let hits = ShapeCatalog.search("DATA")
        XCTAssertTrue(hits.contains { $0.alias == "bow-tie-rectangle" })
    }

    func test_searchMatchesAlias() {
        let hits = ShapeCatalog.search("cyl")
        XCTAssertTrue(hits.contains { $0.alias == "cylinder" })
    }

    func test_emptySearchReturnsAll() {
        XCTAssertEqual(ShapeCatalog.search(""), ShapeCatalog.all)
        XCTAssertEqual(ShapeCatalog.search("   "), ShapeCatalog.all)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ShapeCatalogTests`
Expected: BUILD FAILURE — `cannot find 'ShapeCatalog' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Sources/DiagramKitSample/Models/ShapeCatalog.swift`. Aliases are `NodeShape` rawValues (every rawValue resolves to itself since plan 1); names follow the feature spec's grouping — Basic (standard flowchart), Process (process/system meaning), Technical (architecture / v11 set):

```swift
//
//  ShapeCatalog.swift
//  DiagramPlayground
//
//  Visual editor — the shape vocabulary offered by the center-toolbar
//  catalog and the node menu. Aliases are NodeShape rawValues, all of
//  which resolve through NodeShape.resolve(alias:) (pinned by
//  MermaidFlowchartMetadataExportTests.rawValuesResolve).
//

import Foundation

struct ShapeCatalogItem: Identifiable, Hashable {
    let alias: String
    let name: String
    var id: String { alias }
}

enum ShapeCatalogCategory: String, CaseIterable, Identifiable {
    case basic
    case process
    case technical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: return "Basic"
        case .process: return "Process"
        case .technical: return "Technical"
        }
    }

    var items: [ShapeCatalogItem] {
        switch self {
        case .basic: return ShapeCatalog.basic
        case .process: return ShapeCatalog.process
        case .technical: return ShapeCatalog.technical
        }
    }
}

enum ShapeCatalog {

    static let basic: [ShapeCatalogItem] = [
        .init(alias: "rectangle", name: "Rectangle"),
        .init(alias: "rounded", name: "Rounded"),
        .init(alias: "stadium", name: "Stadium"),
        .init(alias: "circle", name: "Circle"),
        .init(alias: "doublecircle", name: "Double Circle"),
        .init(alias: "diamond", name: "Decision"),
        .init(alias: "hexagon", name: "Hexagon"),
        .init(alias: "ellipse", name: "Ellipse"),
    ]

    static let process: [ShapeCatalogItem] = [
        .init(alias: "cylinder", name: "Database"),
        .init(alias: "subroutine", name: "Subroutine"),
        .init(alias: "parallelogram", name: "Input/Output"),
        .init(alias: "parallelogram-alt", name: "Output/Input"),
        .init(alias: "trapezoid", name: "Manual Operation"),
        .init(alias: "trapezoid-alt", name: "Manual Operation Alt"),
        .init(alias: "document", name: "Document"),
        .init(alias: "stacked-document", name: "Documents"),
        .init(alias: "lined-document", name: "Lined Document"),
        .init(alias: "tagged-document", name: "Tagged Document"),
        .init(alias: "asymmetric", name: "Odd"),
        .init(alias: "delay", name: "Delay"),
        .init(alias: "curved-trapezoid", name: "Display"),
        .init(alias: "sloped-rectangle", name: "Manual Input"),
        .init(alias: "flipped-triangle", name: "Manual File"),
        .init(alias: "flag", name: "Paper Tape"),
        .init(alias: "divided-rectangle", name: "Divided Process"),
        .init(alias: "stacked-rectangle", name: "Processes"),
        .init(alias: "lined-rectangle", name: "Shaded Process"),
        .init(alias: "notched-rectangle", name: "Card"),
        .init(alias: "tagged-rectangle", name: "Tagged Process"),
    ]

    static let technical: [ShapeCatalogItem] = [
        .init(alias: "cloud", name: "Cloud"),
        .init(alias: "horizontal-cylinder", name: "Queue"),
        .init(alias: "lined-cylinder", name: "Disk"),
        .init(alias: "bow-tie-rectangle", name: "Stored Data"),
        .init(alias: "window-pane", name: "Internal Storage"),
        .init(alias: "data-store", name: "Data Store"),
        .init(alias: "small-circle", name: "Start"),
        .init(alias: "framed-circle", name: "Stop"),
        .init(alias: "filled-circle", name: "Junction"),
        .init(alias: "crossed-circle", name: "Summary"),
        .init(alias: "fork", name: "Fork"),
        .init(alias: "join", name: "Join"),
        .init(alias: "hourglass", name: "Collate"),
        .init(alias: "triangle", name: "Extract"),
        .init(alias: "notched-pentagon", name: "Loop Limit"),
        .init(alias: "lightning-bolt", name: "Com Link"),
        .init(alias: "braces", name: "Comment"),
        .init(alias: "bang", name: "Bang"),
        .init(alias: "text", name: "Text Block"),
    ]

    static let all: [ShapeCatalogItem] = basic + process + technical

    /// Case-insensitive match on display name or alias. Empty /
    /// whitespace-only queries return the full catalog.
    static func search(_ query: String) -> [ShapeCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(trimmed) || $0.alias.lowercased().contains(trimmed)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ShapeCatalogTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Models/ShapeCatalog.swift Tests/DiagramKitTests/Playground/ShapeCatalogTests.swift
git commit -m "Visual editor 2a — ShapeCatalog data model (basic/process/technical)"
```

---

### Task 2: Store insert flow — `nextFlowchartNodeID` + `insertShapeFromCatalog`

**Files:**
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift` (add two methods to the `extension LiveEditorStore`)
- Test: `Tests/DiagramKitTests/Playground/ShapeInsertFlowTests.swift`

**Interfaces:**
- Consumes: `performFlowchartMutation(.insertNode(id:label:type:))`, `setSelection(_:)`, `setVisualStage(_:)`, `editor?.document.payload`.
- Produces (used by Task 4):
  - `func nextFlowchartNodeID(prefix: String = "n") -> String?` — next free `n1`, `n2`, … against existing node ids; `nil` when the editor/payload isn't a flow graph.
  - `func insertShapeFromCatalog(alias: String) async` — insert + select + `.labelEdited`.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/ShapeInsertFlowTests.swift`:

```swift
//
//  ShapeInsertFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 2 — catalog insert flow: next-free-id
//  generation and insert → select → label-edit stage.
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
final class ShapeInsertFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never became available")
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func test_nextIDSkipsExistingNodeIDs() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  n1 --> n2\n"))
        try await waitForEditor(store: store)
        XCTAssertEqual(store.nextFlowchartNodeID(), "n3")
    }

    func test_nextIDStartsAtOne() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        XCTAssertEqual(store.nextFlowchartNodeID(), "n1")
    }

    func test_nextIDNilWithoutEditor() {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        XCTAssertNil(store.nextFlowchartNodeID())
    }

    func test_insertShapeAddsSelectsAndOpensLabelEditor() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.insertShapeFromCatalog(alias: "cloud")

        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("payload is not a flowchart"); return
        }
        let node = graph.nodesInOrder.first { $0.id == "n1" }
        XCTAssertNotNil(node)
        XCTAssertEqual(node?.node.shape, .cloud)
        XCTAssertEqual(node?.node.label, "New node")
        XCTAssertEqual(store.editor?.selection?.elementID, "node:n1")
        XCTAssertEqual(store.state.visualStage, .labelEdited)
        XCTAssertTrue(store.state.source.contains("n1"))
    }

    func test_insertShapeNoOpsWithoutEditor() async {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        await store.insertShapeFromCatalog(alias: "cloud")
        XCTAssertEqual(store.state.visualStage, .idle)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter ShapeInsertFlowTests`
Expected: BUILD FAILURE — `value of type 'LiveEditorStore' has no member 'nextFlowchartNodeID'`.

- [ ] **Step 3: Implement**

In `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift`, add inside the `extension LiveEditorStore`, after `setDemoStepperVisible`:

```swift
    // MARK: - Shape catalog insert flow (visual editor plan 2)

    /// Next free node id of the form `<prefix>N` against the current
    /// flowchart payload. Returns nil when there is no editor or the
    /// payload is not a flow graph.
    public func nextFlowchartNodeID(prefix: String = "n") -> String? {
        guard let payload = editor?.document.payload else { return nil }
        let existing: Set<String>
        switch payload {
        case .flowchart(let graph), .stateDiagram(let graph):
            existing = Set(graph.nodesInOrder.map(\.id))
        default:
            return nil
        }
        var n = 1
        while existing.contains("\(prefix)\(n)") { n += 1 }
        return "\(prefix)\(n)"
    }

    /// Catalog click: insert a node with the next free id and a
    /// placeholder label, select it, and open the label editor so the
    /// user can immediately type its name. Errors are surfaced by
    /// `performFlowchartMutation` via `lastMutationError`.
    public func insertShapeFromCatalog(alias: String) async {
        guard let id = nextFlowchartNodeID() else { return }
        do {
            try await performFlowchartMutation(
                .insertNode(id: id, label: "New node", type: alias)
            )
            let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:\(id)")
            setSelection(selection)
            setVisualStage(.labelEdited)
        } catch {
            // performFlowchartMutation already recorded the error.
        }
    }
```

Note: `DiagramSelection` needs `import DiagramKitImport` or comes through `DiagramKit` — the file already imports `DiagramKit` and `DiagramKitInteractive`, which is sufficient (existing `commitSubgraph` constructs `DiagramSelection` in this file).

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter ShapeInsertFlowTests`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift Tests/DiagramKitTests/Playground/ShapeInsertFlowTests.swift
git commit -m "Visual editor 2b — store insert flow: nextFlowchartNodeID + insertShapeFromCatalog"
```

---

### Task 3: `ShapeThumbnail` — pipeline-rendered, cached previews

**Files:**
- Create: `Sources/DiagramKitSample/Views/Visual/ShapeThumbnail.swift`

**Interfaces:**
- Consumes: `DiagramImageRenderer(theme:)`, `renderImage(from:scale:)`, `BMImage`, `DiagramTheme`.
- Produces (used by Task 4): `struct ShapeThumbnail: View { init(alias: String, theme: DiagramTheme) }` — 44×32pt preview, renders asynchronously, cached per alias+theme.

No unit test (SwiftUI view + renderer integration; repo convention leaves canvas views untested). Verified by build + smoke.

- [ ] **Step 1: Write the view**

Create `Sources/DiagramKitSample/Views/Visual/ShapeThumbnail.swift`:

```swift
//
//  ShapeThumbnail.swift
//  DiagramPlayground
//
//  True-to-pipeline shape preview: renders a one-node diagram
//  (`p[" "]@{ shape: <alias> }`) through DiagramImageRenderer and
//  caches the bitmap per alias+theme. Previews can never drift from
//  the real renderer because they ARE the real renderer.
//

import SwiftUI
import DiagramKit
import DiagramKitCommon

@MainActor
final class ShapeThumbnailCache {
    static let shared = ShapeThumbnailCache()
    private var cache: [String: BMImage] = [:]

    func image(alias: String, theme: DiagramTheme) async -> BMImage? {
        let key = "\(theme.name.rawValue)/\(alias)"
        if let hit = cache[key] { return hit }
        let source = "flowchart TD\n  p[\" \"]@{ shape: \(alias) }\n"
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.scale = 2
        guard let image = try? await renderer.renderImage(from: source) else { return nil }
        cache[key] = image
        return image
    }
}

struct ShapeThumbnail: View {
    let alias: String
    let theme: DiagramTheme

    @SwiftUI.State private var image: BMImage?

    var body: some View {
        Group {
            if let image {
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.08))
            }
        }
        .frame(width: 44, height: 32)
        .task(id: alias) {
            image = await ShapeThumbnailCache.shared.image(alias: alias, theme: theme)
        }
    }
}
```

Note: if `DiagramImageRenderer` is a struct (not a class), `renderer.scale = 2` requires `var renderer` — adjust locally. If `DiagramTheme` has no `name: ThemeName` property, key the cache on `alias` alone and add a `// theme changes flush via app restart` comment — check `Sources/DiagramKitCommon/src_theme.swift` for the real property before guessing.

- [ ] **Step 2: Build**

Run: `swift build`
Expected: Build complete. Fix any of the two flagged API-shape issues per the note above.

- [ ] **Step 3: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/ShapeThumbnail.swift
git commit -m "Visual editor 2c — ShapeThumbnail: pipeline-rendered cached previews"
```

---

### Task 4: `ShapeCatalogView` + `CanvasCenterToolbar` + pane wiring

**Files:**
- Create: `Sources/DiagramKitSample/Views/Visual/ShapeCatalogView.swift`
- Create: `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/VisualPane.swift` (bottom stack)
- Modify: `Sources/DiagramKitSample/Views/Support/View+Accessibility.swift` (`A11yID.Visual` additions)

**Interfaces:**
- Consumes: `ShapeCatalog`/`ShapeCatalogCategory` (Task 1), `ShapeThumbnail` (Task 3), `store.insertShapeFromCatalog(alias:)` (Task 2), `store.previewTheme`, `store.visualEditor`.
- Produces (used by Task 5): `struct ShapeCatalogView: View { init(theme: DiagramTheme, onSelect: @escaping (String) -> Void) }`. `CanvasCenterToolbar(store:)` is terminal UI; plans 3–6 add buttons to it.

- [ ] **Step 1: Add accessibility identifiers**

In `Sources/DiagramKitSample/Views/Support/View+Accessibility.swift`, inside `public enum Visual` (after `subgraphToast`):

```swift
        public static let centerToolbar = "visual.centerToolbar"
        public static let shapesButton = "visual.centerToolbar.shapes"
        public static let shapeCatalog = "visual.shapeCatalog"
        public static let shapeCatalogSearch = "visual.shapeCatalog.search"
        public static func shapeCell(_ alias: String) -> String { "visual.shapeCatalog.cell.\(alias)" }
```

- [ ] **Step 2: Create the catalog view**

Create `Sources/DiagramKitSample/Views/Visual/ShapeCatalogView.swift`:

```swift
//
//  ShapeCatalogView.swift
//  DiagramPlayground
//
//  Searchable shape catalog grid, grouped Basic / Process /
//  Technical. Reused by the center toolbar (insert) and the node
//  menu (change shape) via the onSelect callback.
//

import SwiftUI
import DiagramKitCommon

struct ShapeCatalogView: View {
    let theme: DiagramTheme
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search shapes", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .accessibilityIdentifier(A11yID.Visual.shapeCatalogSearch)

            ScrollView {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ForEach(ShapeCatalogCategory.allCases) { category in
                        section(title: category.title, items: category.items)
                    }
                } else {
                    let hits = ShapeCatalog.search(query)
                    if hits.isEmpty {
                        Text("No shapes match “\(query)”")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        section(title: "Results", items: hits)
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 380, height: 420)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.shapeCatalog)
    }

    @ViewBuilder
    private func section(title: String, items: [ShapeCatalogItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { item in
                    cell(for: item)
                }
            }
        }
    }

    private func cell(for item: ShapeCatalogItem) -> some View {
        Button {
            onSelect(item.alias)
        } label: {
            VStack(spacing: 4) {
                ShapeThumbnail(alias: item.alias, theme: theme)
                Text(item.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 76, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .help("\(item.name) (\(item.alias))")
        .accessibilityIdentifier(A11yID.Visual.shapeCell(item.alias))
    }
}
```

- [ ] **Step 3: Create the center toolbar**

Create `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift`:

```swift
//
//  CanvasCenterToolbar.swift
//  DiagramPlayground
//
//  Floating bottom-center toolbar for the visual canvas. Plan 2
//  ships the Shapes catalog button; Subgraph / Icon / Image /
//  Rearrange / Theme buttons land with visual-editor plans 3–6.
//

import SwiftUI

struct CanvasCenterToolbar: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var showShapeCatalog = false

    var body: some View {
        HStack(spacing: 4) {
            Button {
                showShapeCatalog.toggle()
            } label: {
                Label("Shapes", systemImage: "square.on.circle")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Browse and add shapes")
            .accessibilityIdentifier(A11yID.Visual.shapesButton)
            .popover(isPresented: $showShapeCatalog, arrowEdge: .top) {
                ShapeCatalogView(theme: store.previewTheme) { alias in
                    showShapeCatalog = false
                    Task { await store.insertShapeFromCatalog(alias: alias) }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.centerToolbar)
    }
}
```

- [ ] **Step 4: Wire into VisualPane**

In `Sources/DiagramKitSample/Views/Visual/VisualPane.swift`, in the bottom `VStack` (currently `Spacer()` → optional `StateStepper` → `UndoTimelineView`), insert the toolbar above `UndoTimelineView`, gated to flow-graph families:

```swift
                Spacer()
                if store.state.demoStepperVisible {
                    StateStepper(store: store)
                        .padding(.bottom, 8)
                }
                if let editor = store.visualEditor,
                   editor.document.type == .flowchart || editor.document.type == .stateDiagram {
                    CanvasCenterToolbar(store: store)
                        .padding(.bottom, 8)
                }
                UndoTimelineView(store: store)
                    .padding(.bottom, 8)
```

(Replace the existing `Spacer()`…`UndoTimelineView` block with the above; the only addition is the `CanvasCenterToolbar` conditional.)

- [ ] **Step 5: Build and smoke**

Run: `swift build`
Expected: Build complete.

Run: `swift run DiagramKitSample` briefly (background, kill after ~8s) — app must launch. Full interactive smoke (open catalog, search, click a shape, see node inserted with label editor open) is a user-verification item.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/ShapeCatalogView.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/Visual/VisualPane.swift Sources/DiagramKitSample/Views/Support/View+Accessibility.swift
git commit -m "Visual editor 2d — center toolbar + searchable shape catalog with pipeline previews"
```

---

### Task 5: Node menu uses the catalog for shape changes

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift`

**Interfaces:**
- Consumes: `ShapeCatalogView(theme:onSelect:)` (Task 4), existing `shapeAlias` draft state + `setNodeShape` commit path (plan 1).
- Produces: UI only.

- [ ] **Step 1: Replace the interim Picker with a catalog button**

In `Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift`:

1. Add state (next to the other `@SwiftUI.State` vars):

```swift
    @SwiftUI.State private var showShapeCatalog: Bool = false
```

2. Replace the `Picker("Shape", …) … .font(.system(size: 11))` block with:

```swift
            HStack {
                Text("Shape")
                    .font(.system(size: 11))
                Spacer()
                Button {
                    showShapeCatalog.toggle()
                } label: {
                    HStack(spacing: 6) {
                        ShapeThumbnail(alias: shapeAlias, theme: store.previewTheme)
                            .frame(width: 30, height: 22)
                        Text(currentShapeName)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.gray.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showShapeCatalog, arrowEdge: .trailing) {
                    ShapeCatalogView(theme: store.previewTheme) { alias in
                        shapeAlias = alias
                        showShapeCatalog = false
                    }
                }
            }
```

3. Add the display-name helper (next to `currentShapeChoices`) and delete the now-unused `currentShapeChoices` computed property and the `shapeChoices` static array:

```swift
    private var currentShapeName: String {
        ShapeCatalog.all.first(where: { $0.alias == shapeAlias })?.name ?? shapeAlias
    }
```

4. In `seedDraftFromSelection()`, after the `boundsLookup` label read, add a fallback so freshly inserted nodes seed their label even before the bounds lookup refreshes:

```swift
        if labelDraft.isEmpty, let node = currentNode() {
            labelDraft = node.label
            initialLabel = node.label
        }
```

(Place this before the existing `guard let node = currentNode() …` line; the guard then continues to seed shape/style as today.)

- [ ] **Step 2: Build and verify tests still pass**

Run: `swift build`
Expected: Build complete (no more references to `shapeChoices`).

Run: `swift test --filter ShapeInsertFlowTests`
Expected: PASS (insert flow unchanged).

- [ ] **Step 3: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift
git commit -m "Visual editor 2e — node menu shape control opens the shape catalog"
```

---

### Task 6: Closer — gates + regression sweep

**Files:** none new (verification only; docs unchanged — no corpus/baseline deltas in this plan).

- [ ] **Step 1: Run the discipline gates**

```bash
Scripts/check-file-sizes.sh > /dev/null 2>&1; echo "file-sizes: $?"
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh > /dev/null 2>&1; echo "sendable: $?"
```
Expected: all exit 0. (New files are all under 200 lines.)

- [ ] **Step 2: Run the affected suites**

```bash
swift test --filter ShapeCatalogTests
swift test --filter ShapeInsertFlowTests
swift test --filter VisualEditorStateTests
swift test --filter LiveEditorStoreEditorLifecycleTests
swift test --filter FlowchartEditCanvasStageTests
```
Expected: all PASS.

- [ ] **Step 3: Launch smoke**

`swift run DiagramKitSample` in background for ~8s → still running → kill. Expected: app launches cleanly.

- [ ] **Step 4: Commit (only if anything changed)**

No commit expected — this task is verification. If a gate forced a fix, commit it with message `"Visual editor 2f — closer fixes"`.

---

## Plan Self-Review (done at authoring time)

- **Spec coverage (Section 3, this plan's slice):** center toolbar → Task 4; searchable grid grouped basic/process/technical → Tasks 1+4; vector previews → Task 3 (pipeline-rendered — documented deviation from the spec's stale `src_shape_clipping.swift` pointer); click → insert with next free id + placeholder label + auto-select + label editor opens → Task 2; node-menu shape button opens the catalog → Task 5. Other toolbar buttons are explicitly plans 3–6.
- **Placeholder scan:** clean — every code step has complete code; the two "check the real API shape" notes in Task 3 name the exact file to check and both possible outcomes.
- **Type consistency:** `ShapeCatalogItem.alias/name`, `ShapeCatalogCategory.items/title`, `ShapeCatalog.all/search`, `ShapeThumbnail(alias:theme:)`, `ShapeCatalogView(theme:onSelect:)`, `insertShapeFromCatalog(alias:)`, `nextFlowchartNodeID(prefix:)` — names match across Tasks 1–5.
- **Known soft spots:** `DiagramImageRenderer` class-vs-struct and `DiagramTheme.name` property (Task 3 note); popover `arrowEdge` behavior on macOS (cosmetic only).
