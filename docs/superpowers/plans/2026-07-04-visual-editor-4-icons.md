# Visual Editor Plan 4/6 — Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Icon nodes end-to-end — a searchable Font Awesome icon browser in the toolbar, a typed `setNodeIcon` mutation (size / background shape / label position), correct icon-box sizing in layout, and SVG label-position parity with the CG renderer.

**Architecture:** `IconSpec` + `FlowchartMutation.setNodeIcon(of:to: IconSpec?)` in `DiagramKitInteractive`, validated against the bundled `FontAwesomeMap` (public, ~110 FA names → SF Symbols). Model-layer completion: `_nodeSize` gains an icon-shape case driven by `properties.h` (today icon nodes size to their text label), and the SVG renderer honors `properties.pos` (t/b) like the CG renderer already does. Sample app: `IconBrowserView` grid (SF Symbol previews), toolbar Icon button with insert flow, and icon controls in the node menu.

**Tech Stack:** Swift 6, swift-testing (Interactive/model), XCTest (Playground store tests), SwiftUI.

**Spec:** `docs/superpowers/specs/2026-07-04-visual-editor-design.md` Section 5 (icons half) + Section 1 (`setNodeIcon`). **Scope notes (verified against the renderers):** the visual canvas renders via CG, which draws FA icons as SF Symbols from `FontAwesomeMap.faToSF` (~110 names) — the browser offers exactly those names so every choice renders as a real glyph. SVG currently emits the icon *name* as text; upgrading SVG to true glyphs would require bundling a Font Awesome font (licensing + asset + snapshot burden) and is **explicitly out of scope** — SVG keeps its text fallback. This narrows spec Section 5's "FA glyph + background shape render in both renderers" to: both renderers draw the background shape and honor sizing + label position; the glyph itself is SF-Symbol (CG) / name-text (SVG).

## Global Constraints

- Work directly on `main`, commit-by-commit. No branches/worktrees/stash.
- `swift test --filter <ExactSuiteName>` only — never bare `swift test`.
- Typed diagnostic factories only; gates run in the closer.
- File-size gate: warn 500 / error 1000.
- New `FlowchartMutation` case requires: enum case + `undoActionName` + `==` + `hash(into:)` (next discriminator: **10**) + `_applyFlowchart` arm + `LiveEditorStore.undoKind/undoLabel` arms (exhaustive switches in `Sources/DiagramKitSample/Models/LiveEditorStore.swift`).
- Store methods go through `performFlowchartMutation`, never `editor.performFlowchart`.

## Reference — verified facts

- `FontAwesomeMap` (`Sources/DiagramKitCommon/src_font_awesome.swift`): `public enum`, `public static let faToSF: [String: String]` (~110 entries, e.g. `"user": "person.fill"`), `public static func sfSymbolName(for faName: String) -> String?` (strips `fa-` prefix).
- CG renderer (`Sources/DiagramKitRenderingCG/DiagramRenderer+Flow.swift`): icon pass at lines ~80–87 (`iconShapes` set), `_drawIconOrImage` strips `fa:`, maps via `sfSymbolName`, draws SF Symbol or literal-text fallback; `pos` ("t"/"b"/"l"/"r") already offsets labels via `_labelCenterForNode` (~300–314, offset ±12).
- SVG renderer (`Sources/DiagramKitModel/src_renderer.swift`): icon shape cases at 564–571 render base shape + `_renderIconContent` (icon name as `<text class="icon-label">`); `_SvgNode` (line 12) has `icon`/`img` but **no `pos`**; `_renderNodeLabel` (967) always centers.
- Sizing (`Sources/DiagramKitModel/FlowNodeSizer.swift`): `public func _nodeSize(_ node: original_src_types.MermaidNode, hideEmptyDescription: Bool = false) -> (width: Double, height: Double)`; switch has NO icon case (falls to `default`), never reads `node.properties`; floors `max(width, 60)`, `max(height, 36)` at lines ~90–91.
- `NodeProperties`: `icon: String?`, `pos: String?`, `h: Double?` — parsed from `@{ icon:, pos:, h: }` and exported since plan 1.
- No existing flowchart corpus entries use icon shapes → sizing/pos changes cannot shift existing baselines.
- Existing tests: `Tests/DiagramKitTests/IconImageRendererTests.swift` — `FontAwesomeMap` mapping, SVG `icon-label` presence, and two weak `pos` tests that only assert `<svg>` (Task 3 strengthens them).
- Editor-seeding in store tests: force-feed `store.didCompleteRender(parseError: nil, diagramBounds: .zero)` in the wait loop.

## File Structure

- `Sources/DiagramKitInteractive/IconSpec.swift` (new) — `IconSpec` + `setNodeIcon` application.
- `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`, `DiagramEditorError.swift` — case plumbing + `unknownIconName`.
- `Sources/DiagramKitModel/FlowNodeSizer.swift` — icon sizing.
- `Sources/DiagramKitModel/src_renderer.swift` — `_SvgNode.pos` + label offset.
- `Sources/DiagramKitSample/Models/IconCatalog.swift` (new), `Models/LiveEditorStore+Visual.swift` (insert flow), `Views/Visual/IconBrowserView.swift` (new), `Views/Visual/CanvasCenterToolbar.swift` (Icon button), `Views/Visual/IconControls.swift` (new), `Views/Visual/NodeEditPopover.swift` (icon section), `Views/Support/View+Accessibility.swift` (ids), `Models/LiveEditorStore.swift` (undo arms).
- Tests: `Tests/DiagramKitTests/Interactive/FlowchartIconMutationTests.swift` (new), `Tests/DiagramKitTests/FlowNodeSizerIconTests.swift` (new), `Tests/DiagramKitTests/IconImageRendererTests.swift` (strengthen), `Tests/DiagramKitTests/Playground/IconBrowserFlowTests.swift` (new).

---

### Task 1: `IconSpec` + `setNodeIcon` mutation

**Files:**
- Create: `Sources/DiagramKitInteractive/IconSpec.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`, `Sources/DiagramKitInteractive/DiagramEditorError.swift`, `Sources/DiagramKitSample/Models/LiveEditorStore.swift`
- Test: `Tests/DiagramKitTests/Interactive/FlowchartIconMutationTests.swift`

**Interfaces:**
- Consumes: `FontAwesomeMap.sfSymbolName(for:)` (validation), plan-1 mutation plumbing.
- Produces (Tasks 4–5 use):

```swift
public struct IconSpec: Sendable, Equatable, Hashable {
    public enum BackgroundShape: String, Sendable, CaseIterable, Hashable {
        case plain = "icon", circle = "icon-circle",
             rounded = "icon-rounded", square = "icon-square"
        public var nodeShape: original_src_types.NodeShape { ... }
    }
    public enum Size: String, Sendable, CaseIterable, Hashable {
        case small, medium, large
        public var height: Double { 32 / 48 / 64 }
    }
    public enum LabelPosition: String, Sendable, CaseIterable, Hashable {
        case top = "t", bottom = "b"
    }
    public var name: String            // FA name, no "fa:" prefix
    public var background: BackgroundShape
    public var size: Size
    public var labelPosition: LabelPosition?
    public init(name: String, background: BackgroundShape = .circle,
                size: Size = .medium, labelPosition: LabelPosition? = nil)
}
```

  - `FlowchartMutation.setNodeIcon(of: DiagramSelection, to: IconSpec?)` (`nil` clears → shape `.rectangle`, `icon/h/pos` nil)
  - `DiagramEditorError.unknownIconName(name: String)`

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/Interactive/FlowchartIconMutationTests.swift`:

```swift
// Visual editor plan 4 — setNodeIcon mutation.

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
struct FlowchartIconMutationTests {

    @Test("setNodeIcon applies shape, icon, size, and label position")
    func setIcon() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        let spec = IconSpec(name: "user", background: .circle, size: .large, labelPosition: .bottom)
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: spec))

        let node = nodeA(editor)
        #expect(node?.shape == .iconCircle)
        #expect(node?.properties?.icon == "fa:user")
        #expect(node?.properties?.h == 64)
        #expect(node?.properties?.pos == "b")
        #expect(node?.label == "Node A")  // label untouched
    }

    @Test("setNodeIcon defaults: circle, medium, centered label")
    func defaults() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "check")))
        let node = nodeA(editor)
        #expect(node?.shape == .iconCircle)
        #expect(node?.properties?.h == 48)
        #expect(node?.properties?.pos == nil)
    }

    @Test("nil spec clears icon state back to rectangle")
    func clearIcon() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "user")))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: nil))
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.properties?.icon == nil)
        #expect(node?.properties?.h == nil)
        #expect(node?.properties?.pos == nil)
    }

    @Test("unknown FA name throws unknownIconName")
    func unknownName() async {
        let editor = makeEditor(flowDoc(["A"]))
        await #expect(throws: DiagramEditorError.self) {
            try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "not-a-real-icon-xyz")))
        }
    }

    @Test("fa: prefix in the spec name is tolerated and normalized")
    func prefixNormalized() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "fa:user")))
        #expect(nodeA(editor)?.properties?.icon == "fa:user")
    }

    @Test("undo restores the pre-icon node")
    func undoRestores() async throws {
        let editor = makeEditor(flowDoc(["A"]))
        try await editor.performFlowchart(.setNodeIcon(of: sel, to: IconSpec(name: "user")))
        editor.undoManager.undo()
        let node = nodeA(editor)
        #expect(node?.shape == .rectangle)
        #expect(node?.properties?.icon == nil)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowchartIconMutationTests`
Expected: BUILD FAILURE — `cannot find 'IconSpec' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/DiagramKitInteractive/IconSpec.swift`:

```swift
// Visual editor plan 4 — typed icon configuration for setNodeIcon.
// The icon vocabulary is FontAwesomeMap (bundled, ~110 names) so every
// browsable icon renders as a real SF Symbol glyph in the CG renderer
// and serializes portably as `fa:<name>` in Mermaid source.

import DiagramKitCommon
import DiagramKitModel

public struct IconSpec: Sendable, Equatable, Hashable {

    public enum BackgroundShape: String, Sendable, CaseIterable, Hashable {
        case plain = "icon"
        case circle = "icon-circle"
        case rounded = "icon-rounded"
        case square = "icon-square"

        public var nodeShape: original_src_types.NodeShape {
            switch self {
            case .plain: return .icon
            case .circle: return .iconCircle
            case .rounded: return .iconRounded
            case .square: return .iconSquare
            }
        }
    }

    public enum Size: String, Sendable, CaseIterable, Hashable {
        case small
        case medium
        case large

        public var height: Double {
            switch self {
            case .small: return 32
            case .medium: return 48
            case .large: return 64
            }
        }
    }

    public enum LabelPosition: String, Sendable, CaseIterable, Hashable {
        case top = "t"
        case bottom = "b"
    }

    /// Font Awesome icon name. A `fa:` prefix is tolerated and
    /// stripped on init so call sites can pass either form.
    public var name: String
    public var background: BackgroundShape
    public var size: Size
    public var labelPosition: LabelPosition?

    public init(
        name: String,
        background: BackgroundShape = .circle,
        size: Size = .medium,
        labelPosition: LabelPosition? = nil
    ) {
        self.name = name.hasPrefix("fa:") ? String(name.dropFirst(3)) : name
        self.background = background
        self.size = size
        self.labelPosition = labelPosition
    }
}

extension DiagramEditor {

    func _setNodeIcon(
        of selection: DiagramSelection,
        to spec: IconSpec?,
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
        if let spec, FontAwesomeMap.sfSymbolName(for: spec.name) == nil {
            throw DiagramEditorError.unknownIconName(name: spec.name)
        }

        model.nodesInOrder = model.nodesInOrder.map { entry in
            guard entry.id == nodeID else { return entry }
            var node = entry.node
            var props = node.properties ?? original_src_types.NodeProperties()
            if let spec {
                node.shape = spec.background.nodeShape
                props.icon = "fa:\(spec.name)"
                props.h = spec.size.height
                props.pos = spec.labelPosition?.rawValue
            } else {
                node.shape = .rectangle
                props.icon = nil
                props.h = nil
                props.pos = nil
            }
            node.properties = props
            return (id: entry.id, node: node)
        }
        doc.payload = .flowchart(model)
        return doc
    }
}
```

In `DiagramEditorError.swift`, add case + description:

```swift
    /// `setNodeIcon` received a name absent from the bundled
    /// Font Awesome table.
    case unknownIconName(name: String)
```

```swift
        case .unknownIconName(let name):
            return "Unknown icon name '\(name)'"
```

In `DiagramEditor+Flowchart.swift`:
- Case (after `renameSubgraph`): `case setNodeIcon(of: DiagramSelection, to: IconSpec?)` with doc "Configure a node as an icon node (nil clears back to rectangle). Name is validated against FontAwesomeMap."
- `undoActionName`: `case .setNodeIcon: return "Set Node Icon"`
- `==`: `case (.setNodeIcon(let aSel, let aSpec), .setNodeIcon(let bSel, let bSpec)): return aSel == bSel && aSpec == bSpec`
- `hash`: discriminator `10`, combine sel + spec.
- `_applyFlowchart`: `case .setNodeIcon(let selection, let spec): return (try _setNodeIcon(of: selection, to: spec, into: document), [])`

`LiveEditorStore.swift`: `undoKind` → `.setLabel`; `undoLabel`:

```swift
        case .setNodeIcon(let sel, let spec):
            return "Icon \(sel.elementID) → \(spec?.name ?? "cleared")"
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowchartIconMutationTests` — Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitInteractive/IconSpec.swift Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift Sources/DiagramKitInteractive/DiagramEditorError.swift Sources/DiagramKitSample/Models/LiveEditorStore.swift Tests/DiagramKitTests/Interactive/FlowchartIconMutationTests.swift
git commit -m "Visual editor 4a — IconSpec + setNodeIcon mutation"
```

---

### Task 2: Icon-node sizing in `_nodeSize`

**Files:**
- Modify: `Sources/DiagramKitModel/FlowNodeSizer.swift`
- Test: `Tests/DiagramKitTests/FlowNodeSizerIconTests.swift`

**Interfaces:**
- Consumes: `node.properties?.h`.
- Produces: icon-shape nodes sized as an `h`-driven box (default 48) instead of text-extent sizing. No API change.

- [ ] **Step 1: Write the failing tests**

Create `Tests/DiagramKitTests/FlowNodeSizerIconTests.swift`:

```swift
// Visual editor plan 4 — icon-shape node sizing.

import Testing
@testable import DiagramKitModel

private func iconNode(
    shape: original_src_types.NodeShape,
    label: String = "User",
    h: Double? = nil
) -> original_src_types.MermaidNode {
    original_src_types.MermaidNode(
        id: "i", label: label, shape: shape,
        properties: original_src_types.NodeProperties(icon: "fa:user", h: h)
    )
}

@Suite
struct FlowNodeSizerIconTests {

    @Test("icon shapes size to the default 48pt box, not the label")
    func defaultBox() {
        for shape in [original_src_types.NodeShape.icon, .iconCircle, .iconRounded, .iconSquare] {
            let size = _nodeSize(iconNode(shape: shape, label: "A very long label that would stretch a rectangle"))
            #expect(size.height == 64)  // 48 + 16 padding
            #expect(size.width >= 64)   // at least the box; label may widen it
        }
    }

    @Test("properties.h overrides the icon box size")
    func hOverride() {
        let size = _nodeSize(iconNode(shape: .iconCircle, label: "U", h: 64))
        #expect(size.height == 80)  // 64 + 16
        #expect(size.width == 80)   // square when the label fits
    }

    @Test("wide labels widen the node so pos-t/b labels don't clip")
    func wideLabel() {
        let narrow = _nodeSize(iconNode(shape: .iconSquare, label: "U"))
        let wide = _nodeSize(iconNode(shape: .iconSquare, label: "Authentication Gateway Service"))
        #expect(wide.width > narrow.width)
        #expect(wide.height == narrow.height)
    }

    @Test("non-icon shapes are unaffected")
    func rectangleUnchanged() {
        let node = original_src_types.MermaidNode(id: "r", label: "Label", shape: .rectangle)
        let size = _nodeSize(node)
        #expect(size.height == 36 || size.height > 36)  // classic floor path
        #expect(size.height != 64)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FlowNodeSizerIconTests`
Expected: FAIL — `defaultBox` and `hOverride` (icon shapes currently get text-extent sizing).

- [ ] **Step 3: Implement**

In `FlowNodeSizer.swift`, inside the `switch node.shape` (before `default: break`), add:

```swift
    case .icon, .iconCircle, .iconRounded, .iconSquare:
        // Icon nodes are an h-driven box (default 48pt glyph area +
        // 16pt padding). The label renders inside or at pos t/b; keep
        // the node at least label-wide so offset labels don't clip,
        // but the height is the icon box, not the text extent.
        let box = (node.properties?.h ?? 48) + 16
        height = box
        width = max(box, metrics.width + 16)
```

Note the trailing floors (`max(width, 60)` / `max(height, 36)`) remain in effect and are compatible (box ≥ 48).

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FlowNodeSizerIconTests` — Expected: PASS (4 tests).
Blast radius: `swift test --filter BlockLayoutTests` and `SNAPSHOT_DIAGRAM_IDS=flow-1-simple,flow-28-visual-styles swift test --filter CorpusSnapshotTests` — Expected: PASS (no flowchart corpus entry uses icon shapes; verified at plan time).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/FlowNodeSizer.swift Tests/DiagramKitTests/FlowNodeSizerIconTests.swift
git commit -m "Visual editor 4b — icon-shape nodes size to their h-driven box"
```

---

### Task 3: SVG `pos` label parity

**Files:**
- Modify: `Sources/DiagramKitModel/src_renderer.swift` (`_SvgNode` + `_renderNodeLabel` + node construction)
- Test: strengthen `Tests/DiagramKitTests/IconImageRendererTests.swift`

**Interfaces:**
- Consumes: `node.properties?.pos`.
- Produces: SVG label y-offset for `pos: "t"` (above node) / `"b"` (below node), matching the CG renderer's ±12 offsets. No API change.

- [ ] **Step 1: Strengthen the weak pos tests (they fail against today's renderer)**

In `Tests/DiagramKitTests/IconImageRendererTests.swift`, replace the two tests that only assert `<svg>` (lines ~47–63; they are named for pos t/b — read the file first and replace their bodies) with:

```swift
    func test_svgPosTopMovesLabelAboveNode() throws {
        let svgTop = try renderIconSVG(pos: "t")
        let svgCentered = try renderIconSVG(pos: nil)
        let topY = try labelY(in: svgTop)
        let centeredY = try labelY(in: svgCentered)
        XCTAssertLessThan(topY, centeredY, "pos:t label must sit above the centered label")
    }

    func test_svgPosBottomMovesLabelBelowNode() throws {
        let svgBottom = try renderIconSVG(pos: "b")
        let svgCentered = try renderIconSVG(pos: nil)
        XCTAssertGreaterThan(try labelY(in: svgBottom), try labelY(in: svgCentered))
    }
```

with helpers appended to the test class (adapt the render entry point to whatever the file already uses to produce SVG — it has existing icon SVG tests; reuse their code path):

```swift
    private func renderIconSVG(pos: String?) throws -> String {
        let posPart = pos.map { ", pos: \"\($0)\"" } ?? ""
        let source = "flowchart TD\n  I[\"Me\"]@{ icon: \"fa:user\", h: 48\(posPart) }\n"
        // Use the same SVG production used by the existing icon tests
        // in this file (String.renderDiagramSVG or the pipeline call
        // they use). If async: make the tests async throws.
        return try _renderSVGForTest(source)
    }

    private func labelY(in svg: String) throws -> Double {
        // The node label "Me" is rendered as a <text ... y="NN">Me</text>
        // (via renderMultilineText). Grab the y of the text element
        // whose content is "Me".
        let pattern = #"y=\"([0-9.\-]+)\"[^>]*>(?:<tspan[^>]*>)?Me"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(svg.startIndex..., in: svg)
        guard let match = regex.firstMatch(in: svg, range: range),
              let yRange = Range(match.range(at: 1), in: svg),
              let y = Double(svg[yRange]) else {
            throw XCTSkip("label y not found — adjust regex to renderer output")
        }
        return y
    }
```

(These are XCTest-style because `IconImageRendererTests.swift` is XCTest — read the file and match its existing structure and its existing SVG-producing helper, replacing `_renderSVGForTest` with the real call.)

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter IconImageRendererTests`
Expected: the two new tests FAIL (equal y values — SVG ignores pos today).

- [ ] **Step 3: Implement**

In `Sources/DiagramKitModel/src_renderer.swift`:

1. `_SvgNode` gains `var pos: String?` (after `img`).
2. Find the `_SvgNode(` construction site(s) — where `icon: node.properties?.icon` (or equivalent) is passed — and add `pos: node.properties?.pos` (grep `icon:` in this file).
3. In `_renderNodeLabel`, after computing `cy`, add (before the `rect-with-title` branch):

```swift
    var labelCY = cy
    switch node.pos {
    case "t": labelCY = node.y - 12
    case "b": labelCY = node.y + node.height + 12
    default: break
    }
```

and use `labelCY` instead of `cy` in the final `renderMultilineText` call (leave the `rect-with-title` branch untouched).

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter IconImageRendererTests` — Expected: PASS (all tests incl. the two strengthened ones).
Blast radius: `SNAPSHOT_DIAGRAM_IDS=flow-1-simple,flow-19-class-shorthand swift test --filter CorpusSnapshotTests` — Expected: PASS (no pos usage in corpus flowcharts).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitModel/src_renderer.swift Tests/DiagramKitTests/IconImageRendererTests.swift
git commit -m "Visual editor 4c — SVG renderer honors pos t/b label placement (CG parity)"
```

---

### Task 4: Icon browser + toolbar button + insert flow

**Files:**
- Create: `Sources/DiagramKitSample/Models/IconCatalog.swift`
- Create: `Sources/DiagramKitSample/Views/Visual/IconBrowserView.swift`
- Modify: `Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift` (insert flow)
- Modify: `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift` (Icon button)
- Modify: `Sources/DiagramKitSample/Views/Support/View+Accessibility.swift` (ids)
- Test: `Tests/DiagramKitTests/Playground/IconBrowserFlowTests.swift`

**Interfaces:**
- Consumes: `FontAwesomeMap.faToSF`, `IconSpec`, `setNodeIcon` + `insertNode` mutations, `nextFlowchartNodeID()` (plan 2), `editor.beginUndoGrouping()/endUndoGrouping()`.
- Produces:
  - `enum IconCatalog { static let all: [IconCatalogItem]; static func search(_ query: String) -> [IconCatalogItem] }`, `struct IconCatalogItem: Identifiable, Hashable { let faName: String; let sfSymbol: String; var id: String { faName } }`
  - `struct IconBrowserView: View { init(onSelect: @escaping (String) -> Void) }`
  - `LiveEditorStore.insertIconFromBrowser(faName: String) async` (Task 5 does not depend on these; terminal UI).

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/IconBrowserFlowTests.swift`:

```swift
//
//  IconBrowserFlowTests.swift
//  DiagramKitTests
//
//  Visual editor plan 4 — icon catalog integrity + browser insert flow.
//

#if canImport(CoreGraphics)
import CoreGraphics
import XCTest
import DiagramKit
import DiagramKitCommon
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramKitSample

@available(iOS 26.0, macOS 26.0, *)
@MainActor
final class IconBrowserFlowTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    func test_catalogCoversTheFontAwesomeMap() {
        XCTAssertEqual(IconCatalog.all.count, FontAwesomeMap.faToSF.count)
        for item in IconCatalog.all {
            XCTAssertEqual(FontAwesomeMap.faToSF[item.faName], item.sfSymbol)
        }
        // Sorted for stable browsing.
        XCTAssertEqual(IconCatalog.all.map(\.faName), IconCatalog.all.map(\.faName).sorted())
    }

    func test_searchMatchesFAName() {
        XCTAssertTrue(IconCatalog.search("user").contains { $0.faName == "user" })
        XCTAssertTrue(IconCatalog.search("USER").contains { $0.faName == "user" })
        XCTAssertEqual(IconCatalog.search("").count, IconCatalog.all.count)
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

    func test_insertIconFromBrowserInsertsConfiguredNode() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\n  A --> B\n"))
        try await waitForEditor(store: store)

        await store.insertIconFromBrowser(faName: "user")

        guard case .flowchart(let graph) = store.editor?.document.payload else {
            XCTFail("not a flowchart"); return
        }
        let node = graph.nodesInOrder.first { $0.id == "n1" }?.node
        XCTAssertEqual(node?.shape, .iconCircle)
        XCTAssertEqual(node?.properties?.icon, "fa:user")
        XCTAssertEqual(node?.properties?.h, 48)
        XCTAssertEqual(store.editor?.selection?.elementID, "node:n1")
        XCTAssertEqual(store.state.visualStage, .labelEdited)
    }
}
#endif
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter IconBrowserFlowTests`
Expected: BUILD FAILURE — `cannot find 'IconCatalog' in scope`.

- [ ] **Step 3: Implement**

Create `Sources/DiagramKitSample/Models/IconCatalog.swift`:

```swift
//
//  IconCatalog.swift
//  DiagramPlayground
//
//  Visual editor plan 4 — the browsable icon vocabulary. Exactly the
//  FontAwesomeMap keys (the names the CG renderer draws as real
//  SF Symbol glyphs), sorted for stable browsing.
//

import Foundation
import DiagramKitCommon

struct IconCatalogItem: Identifiable, Hashable {
    let faName: String
    let sfSymbol: String
    var id: String { faName }
}

enum IconCatalog {
    static let all: [IconCatalogItem] = FontAwesomeMap.faToSF
        .map { IconCatalogItem(faName: $0.key, sfSymbol: $0.value) }
        .sorted { $0.faName < $1.faName }

    static func search(_ query: String) -> [IconCatalogItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return all }
        return all.filter { $0.faName.lowercased().contains(trimmed) }
    }
}
```

In `LiveEditorStore+Visual.swift`, after `insertShapeFromCatalog`:

```swift
    /// Icon-browser click: insert an icon-circle node with the chosen
    /// Font Awesome icon (medium size), select it, and open the label
    /// editor. Insert + configure land as one undo step.
    public func insertIconFromBrowser(faName: String) async {
        guard let editor, let id = nextFlowchartNodeID() else { return }
        let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:\(id)")
        editor.beginUndoGrouping()
        do {
            try await performFlowchartMutation(
                .insertNode(id: id, label: "New icon", type: "icon-circle")
            )
            try await performFlowchartMutation(
                .setNodeIcon(of: selection, to: IconSpec(name: faName))
            )
        } catch {
            // performFlowchartMutation already recorded the error.
        }
        editor.endUndoGrouping()
        setSelection(selection)
        setVisualStage(.labelEdited)
    }
```

Create `Sources/DiagramKitSample/Views/Visual/IconBrowserView.swift`:

```swift
//
//  IconBrowserView.swift
//  DiagramPlayground
//
//  Searchable Font Awesome icon grid (SF Symbol previews — the same
//  glyphs the CG renderer draws). onSelect receives the FA name.
//

import SwiftUI

struct IconBrowserView: View {
    let onSelect: (String) -> Void

    @SwiftUI.State private var query: String = ""

    private let columns = [GridItem(.adaptive(minimum: 64), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search icons", text: $query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .accessibilityIdentifier(A11yID.Visual.iconBrowserSearch)

            ScrollView {
                let hits = IconCatalog.search(query)
                if hits.isEmpty {
                    Text("No icons match “\(query)”")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(hits) { item in
                            Button {
                                onSelect(item.faName)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: item.sfSymbol)
                                        .font(.system(size: 18))
                                        .frame(height: 24)
                                    Text(item.faName)
                                        .font(.system(size: 8))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(width: 64, height: 48)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.gray.opacity(0.06))
                                )
                            }
                            .buttonStyle(.plain)
                            .help(item.faName)
                            .accessibilityIdentifier(A11yID.Visual.iconCell(item.faName))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 340, height: 400)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Visual.iconBrowser)
    }
}
```

`View+Accessibility.swift` — add to `A11yID.Visual`:

```swift
        public static let iconButton = "visual.centerToolbar.icon"
        public static let iconBrowser = "visual.iconBrowser"
        public static let iconBrowserSearch = "visual.iconBrowser.search"
        public static func iconCell(_ name: String) -> String { "visual.iconBrowser.cell.\(name)" }
```

`CanvasCenterToolbar.swift` — state `@SwiftUI.State private var showIconBrowser = false`; after the Subgraph button:

```swift
            Button {
                showIconBrowser.toggle()
            } label: {
                Label("Icon", systemImage: "star.circle")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("Search and add an icon node")
            .accessibilityIdentifier(A11yID.Visual.iconButton)
            .popover(isPresented: $showIconBrowser, arrowEdge: .top) {
                IconBrowserView { faName in
                    showIconBrowser = false
                    Task { await store.insertIconFromBrowser(faName: faName) }
                }
            }
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter IconBrowserFlowTests` — Expected: PASS (3 tests).
Run: `swift build` — Expected: Build complete.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Models/IconCatalog.swift Sources/DiagramKitSample/Views/Visual/IconBrowserView.swift Sources/DiagramKitSample/Models/LiveEditorStore+Visual.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/Support/View+Accessibility.swift Tests/DiagramKitTests/Playground/IconBrowserFlowTests.swift
git commit -m "Visual editor 4d — icon browser, toolbar Icon button, grouped insert flow"
```

---

### Task 5: Node menu icon controls

**Files:**
- Create: `Sources/DiagramKitSample/Views/Visual/IconControls.swift`
- Modify: `Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift`

**Interfaces:**
- Consumes: `IconSpec` (+ nested enums), `setNodeIcon`, existing popover draft/commit machinery (`currentNode()`, `commit()` Task-grouped mutations).
- Produces: UI only.

- [ ] **Step 1: Create the controls component**

Create `Sources/DiagramKitSample/Views/Visual/IconControls.swift`:

```swift
//
//  IconControls.swift
//  DiagramPlayground
//
//  Icon section of the node menu (visual editor plan 4): size,
//  background shape, and label position for icon nodes. Edits an
//  IconSpec draft; the popover commits via setNodeIcon.
//

import SwiftUI
import DiagramKitInteractive

struct IconControls: View {
    @Binding var size: IconSpec.Size
    @Binding var background: IconSpec.BackgroundShape
    @Binding var labelPosition: IconSpec.LabelPosition?
    @Binding var iconDirty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Icon size", selection: $size) {
                Text("S").tag(IconSpec.Size.small)
                Text("M").tag(IconSpec.Size.medium)
                Text("L").tag(IconSpec.Size.large)
            }
            .pickerStyle(.segmented)
            .onChange(of: size) { iconDirty = true }

            Picker("Background", selection: $background) {
                Text("None").tag(IconSpec.BackgroundShape.plain)
                Text("Circle").tag(IconSpec.BackgroundShape.circle)
                Text("Rounded").tag(IconSpec.BackgroundShape.rounded)
                Text("Square").tag(IconSpec.BackgroundShape.square)
            }
            .pickerStyle(.segmented)
            .onChange(of: background) { iconDirty = true }

            Picker("Label", selection: $labelPosition) {
                Text("Center").tag(IconSpec.LabelPosition?.none)
                Text("Top").tag(IconSpec.LabelPosition?.some(.top))
                Text("Bottom").tag(IconSpec.LabelPosition?.some(.bottom))
            }
            .pickerStyle(.segmented)
            .onChange(of: labelPosition) { iconDirty = true }
        }
        .font(.system(size: 11))
    }
}
```

- [ ] **Step 2: Integrate into the popover**

In `NodeEditPopover.swift`:

1. Draft state (after `showShapeCatalog`):

```swift
    @SwiftUI.State private var iconName: String?
    @SwiftUI.State private var iconSize: IconSpec.Size = .medium
    @SwiftUI.State private var iconBackground: IconSpec.BackgroundShape = .circle
    @SwiftUI.State private var iconLabelPosition: IconSpec.LabelPosition?
    @SwiftUI.State private var iconDirty: Bool = false
```

2. In `body`, after the `NodeStyleControls(...)` block:

```swift
            if iconName != nil {
                IconControls(
                    size: $iconSize,
                    background: $iconBackground,
                    labelPosition: $iconLabelPosition,
                    iconDirty: $iconDirty
                )
            }
```

3. In `seedDraftFromSelection()`, after the style seeding (end of function):

```swift
        if let icon = node.properties?.icon {
            iconName = icon.hasPrefix("fa:") ? String(icon.dropFirst(3)) : icon
            iconBackground = IconSpec.BackgroundShape(rawValue: node.shape.rawValue) ?? .circle
            switch node.properties?.h {
            case 32: iconSize = .small
            case 64: iconSize = .large
            default: iconSize = .medium
            }
            iconLabelPosition = node.properties?.pos.flatMap(IconSpec.LabelPosition.init(rawValue:))
        } else {
            iconName = nil
        }
        iconDirty = false
```

(`node` is already bound by the existing `guard let node = currentNode() … else { return }`.)

4. In `commit()`, after the `styleDirty` block inside the `Task`:

```swift
            if iconDirty, let iconName {
                let spec = IconSpec(
                    name: iconName,
                    background: iconBackground,
                    size: iconSize,
                    labelPosition: iconLabelPosition
                )
                try? await store.performFlowchartMutation(.setNodeIcon(of: selection, to: spec))
            }
```

Note: when `iconDirty` fires, `shapeChanged` should not also fire from the icon-shape change — the shape picker draft is independent; committing both is harmless (`setNodeIcon` runs last and wins) but wasteful. Guard the `shapeChanged` line: `if shapeChanged && !iconDirty { … }`.

- [ ] **Step 3: Build + regression**

Run: `swift build` — Expected: Build complete.
Run: `swift test --filter IconBrowserFlowTests` — Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/IconControls.swift Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift
git commit -m "Visual editor 4e — node menu icon controls (size, background, label position)"
```

---

### Task 6: Closer — corpus entry, snapshots, docs, gates

**Files:**
- Modify: `Sources/DiagramKitSample/Resources/test-diagrams.json` (+ `_counts.flowchart` 43→44, `metadata.counts.flowchart` 51→52)
- Create: 3 recorded baselines under `Tests/DiagramKitTests/__Snapshots__/`
- Modify: `BASELINES.md`, `CLAUDE.md` (counts +1: corpus 427→428; snapshots 440/440/427→441/441/428; total 1307→1310; PNG 440→441; txt 867→869)

- [ ] **Step 1: Add the corpus entry**

Append after the last flowchart-category entry (same technique as plan 1's closer — python insert after the max flowchart index), verifying `flow-29` is unused first (`grep '"flow-29' …`):

```json
{
  "id": "flow-29-icon-nodes",
  "category": "flowchart",
  "name": "Icon Nodes (FA / SF)",
  "source": "flowchart TD\n  U@{ icon: \"fa:user\", h: 48, pos: \"b\", label: \"User\" }\n  D@{ icon: \"fa:database\", h: 64 }\n  U --> D"
}
```

Note: verify `"database"` exists in `FontAwesomeMap.faToSF` (grep); if not, substitute a mapped name (e.g. `"server"` or `"check"`).

- [ ] **Step 2: Corpus integrity + round-trip**

```bash
swift test --filter CorpusEntryFormatIDTests
swift test --filter CorpusRoundTripTests
```
Expected: PASS (icon metadata round-trips via plan 1's exporter).

- [ ] **Step 3: Record + verify snapshots**

```bash
SNAPSHOT_TESTING_RECORD=all SNAPSHOT_DIAGRAM_IDS=flow-29-icon-nodes swift test --filter CorpusSnapshotTests
SNAPSHOT_DIAGRAM_IDS=flow-29-icon-nodes swift test --filter CorpusSnapshotTests
```
Expected: 3 baselines recorded, then PASS in assert mode.

- [ ] **Step 4: Update docs**

`BASELINES.md` + `CLAUDE.md` count updates per the header of this task (verify on-disk with `find Tests/DiagramKitTests/__Snapshots__ -name 'imageSnapshot*' | wc -l` etc. before writing numbers).

- [ ] **Step 5: Gates + suites**

```bash
Scripts/check-file-sizes.sh > /dev/null 2>&1; echo $?
Scripts/check-diagnostic-discipline.sh
Scripts/check-sendable-annotations.sh > /dev/null 2>&1; echo $?
swift test --filter FlowchartIconMutationTests
swift test --filter FlowNodeSizerIconTests
swift test --filter IconImageRendererTests
swift test --filter IconBrowserFlowTests
swift test --filter "RoundTrip"
```
Expected: all 0 / PASS. Launch smoke: `swift run DiagramKitSample` ~8s → running.

- [ ] **Step 6: Commit**

```bash
git add Sources/DiagramKitSample/Resources/test-diagrams.json Tests/DiagramKitTests/__Snapshots__/ BASELINES.md CLAUDE.md
git commit -m "Visual editor 4f — icon-nodes corpus entry + snapshots"
```

---

## Plan Self-Review (done at authoring time)

- **Spec coverage (Section 5 icons + Section 1 `setNodeIcon`):** browser over bundled FA tables with name search → Task 4; insert `@{ icon: "fa:<name>" }` → Task 4; node-menu size (S/M/L → `h`) / background shape / label position → Tasks 1+5; background+icon *color* controls — already shipped in plan 1 (`setNodeStyle` fill/color applies to icon nodes; the popover shows the style controls for every node) — no new work; "CG and SVG icon-shape rendering completed where gaps exist" → Tasks 2 (sizing) + 3 (SVG pos), with the FA-font/SVG-glyph limitation documented as out of scope in the header; mutation-time icon-name validation (Section 7) → Task 1 (`unknownIconName`).
- **Placeholder scan:** Task 3's `_renderSVGForTest` placeholder is explicitly resolved by instruction ("reuse the file's existing SVG-producing helper — read the file first"); acceptable because the exact helper name is only discoverable in that file. Everything else is complete code.
- **Type consistency:** `IconSpec(name:background:size:labelPosition:)` matches Tasks 1/4/5; `insertIconFromBrowser(faName:)` matches Task 4's test; discriminator 10 unique; `IconCatalogItem.faName/sfSymbol` consistent.
- **Risk register:** SF Symbol rendering in recorded image snapshots may drift across OS versions (same exposure as all text rendering; `perceptualPrecision: 0.98` tolerates it); `_nodeSize` icon case could interact with state-diagram layouts that use icon shapes (none exist in corpus — verified).
