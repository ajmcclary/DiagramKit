# Visual Editor Plan 5/6 — Images Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Image-URL nodes end-to-end — a toolbar Image sheet (URL, display size, title), a typed `setNodeImage` mutation, deterministic placeholder rendering in the CG renderer, `w`/`h`-driven sizing, and async view-layer fetch + composite in the sample canvas.

**Architecture:** `ImageSpec` + `FlowchartMutation.setNodeImage(of:to: ImageSpec?)` in `DiagramKitInteractive` with scheme-only URL validation (http/https; never fetches). Model: `_nodeSize` gains an `imageSquare` case driven by `properties.w/h`. CG renderer: `_drawIconOrImage` gains an `img` branch drawing a deterministic framed placeholder (photo SF Symbol) — **the core pipeline stays fully offline**; SVG already emits a safe `<image href>`. Sample app: `RemoteImageCache` (in-memory, `URLSession`) + an overlay in `FlowchartEditCanvas` composites real bitmaps over placeholder rects on screen; fetch failure keeps the placeholder with a badge.

**Tech Stack:** Swift 6, swift-testing (Interactive/model), XCTest (Playground), SwiftUI.

**Spec:** `docs/superpowers/specs/2026-07-04-visual-editor-design.md` Section 5 (images half) + Section 1 (`setNodeImage`). **Scope note:** the spec's node menu covers icon controls; image nodes are configured at insert time via the sheet (URL/size/title). Post-insert image editing = source edit or delete+reinsert (YAGNI this cycle).

## Global Constraints

- Work directly on `main`, commit-by-commit. No branches/worktrees/stash.
- `swift test --filter <ExactSuiteName>` only.
- **No network in the core pipeline, ever** (spec Section 5). Mutation validation checks scheme/shape only; only the sample-app cache fetches.
- File-size gate warn 500 / error 1000; typed diagnostic factories only.
- New `FlowchartMutation` case: enum + `undoActionName` + `==` + `hash` (next discriminator: **11**) + `_applyFlowchart` arm + `LiveEditorStore.undoKind/undoLabel` arms.
- Known pre-existing: old corpus image baselines crash the snapshot harness on this machine (`NSInvalidArgumentException` in diff reporting). Only assert snapshots for session-recorded ids.

## Reference — verified facts

- CG (`Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift`): `_drawIconOrImage(props:bounds:in:contentHeight:)` (line ~316) handles **only** `props.icon`; `props.img` is ignored → image nodes draw an empty shape. The icon dispatch pass (~80–87) already includes `"image-square"` in its `iconShapes` set, so the placeholder branch slots straight into `_drawIconOrImage`. `_drawSFIcon(_:bounds:in:contentHeight:)` (same extension, private) draws an SF Symbol.
- SVG (`Sources/DiagramKitModel/src_renderer.swift` `_renderIconContent`, ~920): emits `<image xlink:href>` with a scheme denylist (`javascript:`, `data:`, `vbscript:`, `file:`) — already spec-compliant; no changes needed.
- Sizing (`Sources/DiagramKitModel/FlowNodeSizer.swift`): `.imageSquare` has no case (text-extent sizing); `properties.w/h` unread. Plan-4 icon case is the template.
- `NodeProperties`: `img: String?`, `w: Double?`, `h: Double?` — parsed + exported since plan 1.
- Store stored-property pattern: add next to `subgraphTitlePrompt` in `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (~line 730); methods in `LiveEditorStore+Visual.swift`; sheet presentation pattern in `VisualPane.subgraphLayer`.
- Insert-flow pattern: `insertIconFromBrowser` (grouped insertNode + configure mutation, `LiveEditorStore+Visual.swift`).
- `viewRect(for:in:)` + `liveBoundsLookup` in `FlowchartEditCanvas` map node bounds to view space (the composite overlay uses these).
- No corpus flowchart entries carry `img:` except none (only `IconImageRendererTests` uses one inline) — sizing change shifts nothing recorded.

## File Structure

- `Sources/DiagramKitInteractive/ImageSpec.swift` (new) — spec + mutation application + URL validation.
- `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`, `DiagramEditorError.swift` — plumbing + `invalidImageURL`.
- `Sources/DiagramKitModel/FlowNodeSizer.swift` — imageSquare sizing.
- `Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift` — placeholder branch.
- `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (+1 stored prop), `Models/LiveEditorStore+Visual.swift` (sheet methods + insert flow), `Views/Visual/ImageURLSheet.swift` (new), `Views/Visual/CanvasCenterToolbar.swift` (Image button), `Views/Visual/Flowchart/ImageNodeOverlay.swift` (new: cache + overlay), `Views/Visual/Flowchart/FlowchartEditCanvas.swift` (overlay wiring), `Views/Visual/VisualPane.swift` (sheet), `Views/Support/View+Accessibility.swift` (ids).
- Tests: `Tests/DiagramKitTests/Interactive/FlowchartImageMutationTests.swift` (new), extend `Tests/DiagramKitTests/FlowNodeSizerIconTests.swift`, `Tests/DiagramKitTests/Playground/ImageInsertFlowTests.swift` (new).

---

### Task 1: `ImageSpec` + `setNodeImage` mutation

**Files:**
- Create: `Sources/DiagramKitInteractive/ImageSpec.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`, `Sources/DiagramKitInteractive/DiagramEditorError.swift`, `Sources/DiagramKitSample/Models/LiveEditorStore.swift`
- Test: `Tests/DiagramKitTests/Interactive/FlowchartImageMutationTests.swift`

**Interfaces:**
- Produces (Tasks 4–5 use):

```swift
public struct ImageSpec: Sendable, Equatable, Hashable {
    public var urlString: String
    public var width: Double        // default 120
    public var height: Double       // default 90
    public var title: String?       // becomes the node label when set
    public init(urlString: String, width: Double = 120, height: Double = 90, title: String? = nil)
    public static func validateURL(_ urlString: String) -> Bool  // http/https + host, no fetch
}
```

  - `FlowchartMutation.setNodeImage(of: DiagramSelection, to: ImageSpec?)` (`nil` clears → rectangle, `img/w/h` nil, label untouched)
  - `DiagramEditorError.invalidImageURL(url: String)`

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/FlowchartImageMutationTests.swift`:

```swift
// Visual editor plan 5 — setNodeImage mutation.

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

@MainActor
private func makeEditor(_ doc: DiagramDocument) -> DiagramEditor {
    DiagramEditor(
        document: doc,
        preferredExportFormat: .mermaid,
        exportRegistry: ExporterRegistry.empty.registering(MockExporter())
    )
}

@MainActor
private func nodeA(_ editor: DiagramEditor) -> original_src_types.MermaidNode? {
    guard case .flowchart(let model) = editor.document.payload else { return nil }
    return model.nodesInOrder.first { $0.id == "A" }?.node
}

private let sel = DiagramSelection(diagramType: .flowchart, elementID: "node:A")

@Suite @MainActor
struct FlowchartImageMutationTests {

    @Test("setNodeImage applies shape, url, size, and title")
    func setImage() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let spec = ImageSpec(urlString: "https://example.com/x.png", width: 200, height: 150, title: "Diagram")
        try await editor.performFlowchart(.setNodeImage(of: sel, to: spec))
        let node = nodeA(editor)
        #expect(node?.shape == .imageSquare)
        #expect(node?.properties?.img == "https://example.com/x.png")
        #expect(node?.properties?.w == 200)
        #expect(node?.properties?.h == 150)
        #expect(node?.label == "Diagram")
    }

    @Test("nil title leaves the label untouched")
    func nilTitle() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: "https://example.com/x.png")))
        #expect(nodeA(editor)?.label == "Node A")
        #expect(nodeA(editor)?.properties?.w == 120)
        #expect(nodeA(editor)?.properties?.h == 90)
    }

    @Test("nil spec clears image state back to rectangle")
    func clearImage() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: "https://example.com/x.png")))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: nil))
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.properties?.img == nil)
        #expect(node?.properties?.w == nil)
        #expect(node?.properties?.h == nil)
    }

    @Test("non-http(s) URLs throw invalidImageURL and never mutate")
    func badURLs() async {
        let editor = makeEditor(flowDoc(["A"]))
        for bad in ["javascript:alert(1)", "file:///etc/passwd", "data:image/png;base64,AAAA", "not a url", ""] {
            await #expect(throws: DiagramEditorError.self) {
                try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: bad)))
            }
        }
        #expect(nodeA(editor)?.shape == .rectangle)
    }

    @Test("validateURL accepts http/https with host, rejects the rest")
    func validate() {
        #expect(ImageSpec.validateURL("https://example.com/a.png"))
        #expect(ImageSpec.validateURL("http://example.com/a.png"))
        #expect(!ImageSpec.validateURL("ftp://example.com/a.png"))
        #expect(!ImageSpec.validateURL("https://"))
        #expect(!ImageSpec.validateURL(""))
    }

    @Test("undo restores the pre-image node")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeImage(of: sel, to: ImageSpec(urlString: "https://example.com/x.png", title: "T")))
        editor.undoManager.undo()
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.label == "Node A")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowchartImageMutationTests`
Expected: BUILD FAILURE — `cannot find 'ImageSpec' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/DiagramKitInteractive/ImageSpec.swift`:

```swift
// Visual editor plan 5 — typed image-node configuration for
// setNodeImage. Validation is scheme/shape only (http/https + host):
// the mutation NEVER fetches; the core pipeline stays offline and the
// sample app's view layer does the actual loading.

import Foundation
import DiagramKitCommon
import DiagramKitModel

public struct ImageSpec: Sendable, Equatable, Hashable {
    public var urlString: String
    public var width: Double
    public var height: Double
    /// Becomes the node label when set; nil leaves the label alone.
    public var title: String?

    public init(
        urlString: String,
        width: Double = 120,
        height: Double = 90,
        title: String? = nil
    ) {
        self.urlString = urlString
        self.width = width
        self.height = height
        self.title = title
    }

    /// Shape-only URL validation: http/https scheme with a non-empty
    /// host. Never performs network access.
    public static func validateURL(_ urlString: String) -> Bool {
        guard
            let url = URL(string: urlString),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = url.host, !host.isEmpty
        else { return false }
        return true
    }
}

extension DiagramEditor {

    func _setNodeImage(
        of selection: DiagramSelection,
        to spec: ImageSpec?,
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
        if let spec, !ImageSpec.validateURL(spec.urlString) {
            throw DiagramEditorError.invalidImageURL(url: spec.urlString)
        }

        model.nodesInOrder = model.nodesInOrder.map { entry in
            guard entry.id == nodeID else { return entry }
            var node = entry.node
            var props = node.properties ?? original_src_types.NodeProperties()
            if let spec {
                node.shape = .imageSquare
                props.img = spec.urlString
                props.w = spec.width
                props.h = spec.height
                if let title = spec.title, !title.isEmpty {
                    node.label = title
                }
            } else {
                node.shape = .rectangle
                props.img = nil
                props.w = nil
                props.h = nil
            }
            node.properties = props
            return (id: entry.id, node: node)
        }
        doc.payload = .flowchart(model)
        return doc
    }
}
```

`DiagramEditorError.swift` — case + description:

```swift
    /// `setNodeImage` received a URL that is not http/https with a host.
    case invalidImageURL(url: String)
```

```swift
        case .invalidImageURL(let url):
            return "Invalid image URL '\(url)' (http/https with a host required)"
```

`DiagramEditor+Flowchart.swift` — case after `setNodeIcon`:

```swift
    /// Configure a node as an image node (nil clears back to
    /// rectangle). URL is validated for shape only — never fetched.
    case setNodeImage(of: DiagramSelection, to: ImageSpec?)
```

`undoActionName`: `"Set Node Image"`; `==` field-wise; `hash` discriminator `11`; `_applyFlowchart`: `return (try _setNodeImage(of: selection, to: spec, into: document), [])`.

`LiveEditorStore.swift`: `undoKind` → `.setLabel`; `undoLabel`:

```swift
        case .setNodeImage(let sel, let spec):
            return "Image \(sel.elementID) → \(spec?.urlString ?? "cleared")"
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowchartImageMutationTests` — Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/ImageSpec.swift Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Sources/DiagramKitInteractive/DiagramEditorError.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift Tests/DiagramKitTests/Interactive/FlowchartImageMutationTests.swift
git commit -m "Visual editor 5a — ImageSpec + setNodeImage mutation (offline URL validation)"
```

---

### Task 2: `imageSquare` sizing

**Files:**
- Modify: `Sources/DiagramKitModel/FlowNodeSizer.swift`
- Test: extend `Tests/DiagramKitTests/FlowNodeSizerIconTests.swift`

- [ ] **Step 1: Add failing tests** (append to the existing suite)

```swift
    @Test("imageSquare sizes to declared w/h with padding")
    func imageDeclaredSize() {
        let node = original_src_types.MermaidNode(
            id: "m", label: "Pic", shape: .imageSquare,
            properties: original_src_types.NodeProperties(img: "https://example.com/x.png", w: 200, h: 150)
        )
        let size = _nodeSize(node)
        #expect(size.width == 216)   // 200 + 16
        #expect(size.height == 166)  // 150 + 16
    }

    @Test("imageSquare defaults to 120x90 when w/h absent")
    func imageDefaultSize() {
        let node = original_src_types.MermaidNode(
            id: "m", label: "Pic", shape: .imageSquare,
            properties: original_src_types.NodeProperties(img: "https://example.com/x.png")
        )
        let size = _nodeSize(node)
        #expect(size.width == 136)   // 120 + 16
        #expect(size.height == 106)  // 90 + 16
    }
```

- [ ] **Step 2: Run** `swift test --filter FlowNodeSizerIconTests` — Expected: the two new tests FAIL.

- [ ] **Step 3: Implement** — in `FlowNodeSizer.swift`, add before the icon case:

```swift
    case .imageSquare:
        // Image nodes honor the declared display size (default 120×90)
        // + 16pt padding; labels don't drive the box, but keep the
        // node label-wide so titles don't clip.
        height = (node.properties?.h ?? 90) + 16
        width = max((node.properties?.w ?? 120) + 16, metrics.width + 16)
```

Note: `imageDeclaredSize`'s width assertion (216) holds because "Pic" measures well under 200pt; keep test labels short.

- [ ] **Step 4: Run** `swift test --filter FlowNodeSizerIconTests` — Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/FlowNodeSizer.swift Tests/DiagramKitTests/FlowNodeSizerIconTests.swift
git commit -m "Visual editor 5b — imageSquare nodes size to declared w/h"
```

---

### Task 3: CG deterministic placeholder

**Files:**
- Modify: `Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift` (`_drawIconOrImage`)

No CG-context unit test (test-runner limitation documented in `IconImageRendererTests.swift:65`); verified by build + the closer's session-recorded image snapshot.

- [ ] **Step 1: Implement** — in `_drawIconOrImage`, add an `img` branch BEFORE the icon branch:

```swift
        if let img = props.img, !img.isEmpty {
            // Deterministic offline placeholder: framed rect + photo
            // glyph. The real bitmap is composited by the host view
            // layer (sample app RemoteImageCache) — the core pipeline
            // never touches the network.
            let frame = bounds.insetBy(dx: 4, dy: 4)
            context.saveGState()
            context.setStrokeColor(theme.nodeTextColor(for: [:]).withAlphaComponent(0.35).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 3])
            context.stroke(frame)
            context.restoreGState()
            _drawSFIcon("photo", bounds: frame.insetBy(dx: frame.width * 0.3, dy: frame.height * 0.3), in: context, contentHeight: ch)
            return
        }
```

Check: `theme.nodeTextColor(for: [:])` returns a `BMColor` (used in the icon branch at line ~325) — `.withAlphaComponent(0.35).cgColor` is valid on NSColor/UIColor. If `nodeTextColor` has a different signature here, mirror the icon branch's usage exactly.

- [ ] **Step 2: Build** — `swift build` — Expected: Build complete.

- [ ] **Step 3: Commit**

```bash
git add Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift
git commit -m "Visual editor 5c — CG renders a deterministic framed placeholder for image nodes"
```

---

### Task 4: Toolbar Image button + URL sheet + insert flow

**Files:**
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore.swift` (stored prop `isImageSheetOpen`)
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift` (methods)
- Create: `Sources/DiagramKitSample/Views/Visual/ImageURLSheet.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift`, `Views/Visual/VisualPane.swift`, `Views/Support/View+Accessibility.swift`
- Test: `Tests/DiagramKitTests/Playground/ImageInsertFlowTests.swift`

**Interfaces:**
- Produces: `LiveEditorStore.isImageSheetOpen: Bool`, `openImageSheet()`, `cancelImageSheet()`, `insertImageFromSheet(urlString: String, width: Double, height: Double, title: String?) async`.

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/ImageInsertFlowTests.swift`:

```swift
//
//  ImageInsertFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 5 — image sheet insert flow.
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
final class ImageInsertFlowTests: XCTestCase {

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
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    func test_insertImageFromSheetInsertsConfiguredNode() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        store.openImageSheet()
        XCTAssertTrue(store.isImageSheetOpen)

        await store.insertImageFromSheet(
            urlString: "https://example.com/pic.png", width: 200, height: 150, title: "Pic"
        )

        XCTAssertFalse(store.isImageSheetOpen)
        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        let node = graph.nodesInOrder.first { $0.id == "n1" }?.node
        XCTAssertEqual(node?.shape, .imageSquare)
        XCTAssertEqual(node?.properties?.img, "https://example.com/pic.png")
        XCTAssertEqual(node?.properties?.w, 200)
        XCTAssertEqual(node?.label, "Pic")
        XCTAssertEqual(store.editor?.selection?.elementID, "node:n1")
        XCTAssertEqual(store.state.visualStage, .nodeSelected)
    }

    func test_invalidURLKeepsSheetOpenAndRecordsError() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)
        store.openImageSheet()

        await store.insertImageFromSheet(urlString: "ftp://nope", width: 120, height: 90, title: nil)

        XCTAssertTrue(store.isImageSheetOpen, "sheet stays open so the user can fix the URL")
        XCTAssertNotNil(store.lastMutationError)
        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        XCTAssertEqual(graph.nodesInOrder.count, 2, "no node inserted on invalid URL")
    }
}
#endif
```

- [ ] **Step 2: Run** `swift test --filter ImageInsertFlowTests` — Expected: BUILD FAILURE (`openImageSheet`).

- [ ] **Step 3: Implement store side**

`LiveEditorStore.swift`, next to `subgraphTitlePrompt`:

```swift
    /// True while the toolbar's image-URL sheet is on screen.
    public var isImageSheetOpen: Bool = false
```

`LiveEditorStore+Visual.swift`, after `insertIconFromBrowser`:

```swift
    // MARK: - Image sheet (visual editor plan 5)

    public func openImageSheet() {
        isImageSheetOpen = true
    }

    public func cancelImageSheet() {
        isImageSheetOpen = false
    }

    /// Image-sheet commit: validate the URL up front (cheap, offline),
    /// then insert + configure as one undo step. On an invalid URL the
    /// sheet stays open with lastMutationError set.
    public func insertImageFromSheet(
        urlString: String, width: Double, height: Double, title: String?
    ) async {
        guard let editor, let id = nextFlowchartNodeID() else { return }
        guard ImageSpec.validateURL(urlString) else {
            lastMutationError = "Invalid image URL '\(urlString)' (http/https required)"
            return
        }
        let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:\(id)")
        editor.beginUndoGrouping()
        do {
            try await performFlowchartMutation(
                .insertNode(id: id, label: title ?? "Image", type: "image-square")
            )
            try await performFlowchartMutation(
                .setNodeImage(of: selection, to: ImageSpec(
                    urlString: urlString, width: width, height: height, title: title
                ))
            )
        } catch {
            // performFlowchartMutation already recorded the error.
        }
        editor.endUndoGrouping()
        isImageSheetOpen = false
        setSelection(selection)
        setVisualStage(.nodeSelected)
    }
```

Note: `lastMutationError` must be settable here — it is declared in `LiveEditorStore.swift`; if it is `private(set)`, use the existing `_setLastMutationError(_:)` helper (used by `performSequenceMutation`) instead of direct assignment.

- [ ] **Step 4: Run** `swift test --filter ImageInsertFlowTests` — Expected: PASS (2 tests).

- [ ] **Step 5: UI**

Create `Sources/DiagramKitSample/Views/Visual/ImageURLSheet.swift`:

```swift
//
//  ImageURLSheet.swift
//  DiagramPlayground
//
//  Toolbar image-node sheet (visual editor plan 5): URL, display
//  size, optional title. Commit inserts an image-square node.
//

import SwiftUI

struct ImageURLSheet: View {
    @Bindable var store: LiveEditorStore

    @SwiftUI.State private var urlDraft: String = ""
    @SwiftUI.State private var widthDraft: String = "120"
    @SwiftUI.State private var heightDraft: String = "90"
    @SwiftUI.State private var titleDraft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add image from URL")
                .font(.system(size: 13, weight: .semibold))
            TextField("https://example.com/image.png", text: $urlDraft)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier(A11yID.Visual.imageURLField)
            HStack(spacing: 8) {
                TextField("Width", text: $widthDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Text("×").foregroundStyle(.secondary)
                TextField("Height", text: $heightDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                Spacer()
            }
            .font(.system(size: 11))
            TextField("Title (optional)", text: $titleDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
            if let error = store.lastMutationError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { store.cancelImageSheet() }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                Spacer()
                Button("Add") {
                    let title = titleDraft.trimmingCharacters(in: .whitespaces)
                    Task {
                        await store.insertImageFromSheet(
                            urlString: urlDraft.trimmingCharacters(in: .whitespaces),
                            width: Double(widthDraft) ?? 120,
                            height: Double(heightDraft) ?? 90,
                            title: title.isEmpty ? nil : title
                        )
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(urlDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier(A11yID.Visual.imageCommitButton)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
    }
}
```

`A11yID.Visual` additions:

```swift
        public static let imageButton = "visual.centerToolbar.image"
        public static let imageURLField = "visual.imageSheet.url"
        public static let imageCommitButton = "visual.imageSheet.commit"
```

`CanvasCenterToolbar.swift` — after the Icon button:

```swift
            Button {
                store.openImageSheet()
            } label: {
                Label("Image", systemImage: "photo")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Add an image node from a URL")
            .accessibilityIdentifier(A11yID.Visual.imageButton)
```

`VisualPane.swift` `subgraphLayer` — after the title-prompt block:

```swift
        // Image-URL sheet.
        if store.isImageSheetOpen {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { store.cancelImageSheet() }
                ImageURLSheet(store: store)
            }
        }
```

- [ ] **Step 6: Build + commit**

`swift build` — Expected: Build complete.

```bash
git add Sources/DiagramKitSample/Models/LiveEditorStore.swift Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift Sources/DiagramKitSample/Views/Visual/ImageURLSheet.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/Visual/VisualPane.swift Sources/DiagramKitSample/Views/Support/View+Accessibility.swift Tests/DiagramKitTests/Playground/ImageInsertFlowTests.swift
git commit -m "Visual editor 5d — toolbar Image button + URL sheet + grouped insert flow"
```

---

### Task 5: View-layer fetch + composite overlay

**Files:**
- Create: `Sources/DiagramKitSample/Views/Visual/Flowchart/ImageNodeOverlay.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift`

**Interfaces:**
- Consumes: `store.editor?.document.payload` (nodes with `properties.img`), `liveBoundsLookup.bounds(of:)`, `viewRect(for:in:)` math (replicated via passed-in converter closure).
- Produces: UI only. `RemoteImageCache` is `@MainActor` with an in-memory dictionary; failures cached as `.failed` so each URL fetches at most once per session.

- [ ] **Step 1: Create the cache + overlay**

Create `Sources/DiagramKitSample/Views/Visual/Flowchart/ImageNodeOverlay.swift`:

```swift
//
//  ImageNodeOverlay.swift
//  DiagramPlayground
//
//  Visual editor plan 5 — composites real bitmaps over the CG
//  renderer's deterministic image placeholders. All network access
//  lives HERE, in the sample app's view layer; the core pipeline
//  never fetches.
//

import SwiftUI
import DiagramKit
import DiagramKitModel

@MainActor
final class RemoteImageCache {
    enum Entry {
        case loaded(BMImage)
        case failed
    }

    static let shared = RemoteImageCache()
    private var cache: [String: Entry] = [:]
    private var inFlight: Set<String> = []

    func entry(for urlString: String) -> Entry? { cache[urlString] }

    func load(_ urlString: String) async -> Entry {
        if let hit = cache[urlString] { return hit }
        guard !inFlight.contains(urlString), let url = URL(string: urlString) else {
            return cache[urlString] ?? .failed
        }
        inFlight.insert(urlString)
        defer { inFlight.remove(urlString) }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard
                let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                let image = BMImage(data: data)
            else {
                cache[urlString] = .failed
                return .failed
            }
            cache[urlString] = .loaded(image)
            return .loaded(image)
        } catch {
            cache[urlString] = .failed
            return .failed
        }
    }
}

/// One node's composited image (or failure badge).
struct ImageNodeOverlayItem: View {
    let urlString: String
    let rect: CGRect

    @SwiftUI.State private var entry: RemoteImageCache.Entry?

    var body: some View {
        Group {
            switch entry {
            case .loaded(let image):
                #if canImport(AppKit)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                #endif
            case .failed:
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(4)
            case nil:
                Color.clear
            }
        }
        .frame(width: max(rect.width - 8, 1), height: max(rect.height - 8, 1))
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .task(id: urlString) {
            entry = await RemoteImageCache.shared.load(urlString)
        }
    }
}
```

- [ ] **Step 2: Wire into the canvas**

In `FlowchartEditCanvas.swift`:

1. Add a helper that lists image nodes with their view rects (near `elementAtHover`):

```swift
    /// (nodeID, url, viewRect) for every image node the lookup can place.
    private func imageNodeOverlays(in viewSize: CGSize) -> [(id: String, url: String, rect: CGRect)] {
        guard
            let lookup = liveBoundsLookup,
            case .flowchart(let graph) = store.editor?.document.payload
        else { return [] }
        return graph.nodesInOrder.compactMap { entry in
            guard let url = entry.node.properties?.img, !url.isEmpty else { return nil }
            let sel = DiagramSelection(diagramType: editorType, elementID: "node:\(entry.id)")
            guard let bounds = lookup.bounds(of: sel) else { return nil }
            return (id: entry.id, url: url, rect: viewRect(for: bounds, in: viewSize))
        }
    }
```

2. In `body`'s `ZStack`, directly after the `DiagramView` block (so overlays sit under selection chrome):

```swift
                ForEach(imageNodeOverlays(in: geometry.size), id: \.id) { item in
                    ImageNodeOverlayItem(urlString: item.url, rect: item.rect)
                }
```

- [ ] **Step 3: Build + launch smoke**

`swift build` — Expected: Build complete. `swift run DiagramKitSample` ~8s background → running → kill.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/Flowchart/ImageNodeOverlay.swift Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift
git commit -m "Visual editor 5e — async image fetch + composite overlay (view layer only)"
```

---

### Task 6: Closer — corpus entry, snapshots, docs, gates

Same procedure as plan 4's closer:

- [ ] **Step 1:** Add corpus entry after the last flowchart entry (verify `flow-30` unused; bump `_counts.flowchart` 44→45, `metadata.counts.flowchart` 52→53):

```json
{
  "id": "flow-30-image-node",
  "category": "flowchart",
  "name": "Image Node (Deterministic Placeholder)",
  "source": "flowchart TD\n  P[\"Photo\"]@{ img: \"https://example.com/pic.png\", w: 160, h: 120 }\n  P --> A[Next]"
}
```

(The image snapshot pins the deterministic placeholder — the URL is never fetched by the pipeline.)

- [ ] **Step 2:** `swift test --filter CorpusEntryFormatIDTests` + `swift test --filter CorpusRoundTripTests` — PASS.
- [ ] **Step 3:** Record + assert `SNAPSHOT_DIAGRAM_IDS=flow-30-image-node` (record then assert runs) — 3 baselines, PASS.
- [ ] **Step 4:** Update `BASELINES.md` + `CLAUDE.md`: corpus 428→429 (400 Mermaid-only), SVG/image 441→442, ASCII 428→429, total 1310→1313, PNG 441→442, txt 869→871, multi-format cases-per-test 428→429. Verify with on-disk `find` counts first.
- [ ] **Step 5:** Gates (file-sizes / diagnostic / sendable) + suites: `FlowchartImageMutationTests`, `FlowNodeSizerIconTests`, `ImageInsertFlowTests`, `IconImageRendererTests`, `"RoundTrip"` — all PASS. Launch smoke.
- [ ] **Step 6:** Commit `"Visual editor 5f — image-node corpus entry + snapshots"`.

---

## Plan Self-Review (done at authoring time)

- **Spec coverage:** Section 5 images — sheet (URL/size/title) → Task 4; `A@{ img:, w:, h:, label: }` serialization → Task 1 (+ plan-1 exporter, already emits img/w/h); deterministic framed placeholder at declared size → Tasks 2 (size) + 3 (CG placeholder); SVG `<image href>` → already shipped (verified, no work); async fetch + in-memory cache + composite → Task 5; fetch-failure badge → Task 5; "no network in core, ever" + scheme-only validation → Task 1. Section 1 `setNodeImage` row → Task 1.
- **Placeholder scan:** clean; two "check the real signature" notes name exact fallbacks (`_setLastMutationError`, mirror icon-branch color usage).
- **Type consistency:** `ImageSpec(urlString:width:height:title:)` matches Tasks 1/4; `insertImageFromSheet(urlString:width:height:title:)` matches test; discriminator 11 unique; `RemoteImageCache.Entry` consistent.
- **Risk register:** `BMImage(data:)` initializer availability (NSImage/UIImage both have it); overlay z-order under selection chrome (cosmetic); sandbox network entitlement for the sample app when actually fetching (runtime concern only, placeholder remains on failure).
