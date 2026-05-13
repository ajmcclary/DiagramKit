# Playground: Interactive Editor Integration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the playground's modal `InspectorView` with a persistent, canvas-driven `DiagramEditorPane` that co-owns a `DiagramEditor` with `LiveEditorStore`, supports tap-to-select on the preview via a new public `boundsLookup` binding on `DiagramView`, and surfaces every public `DiagramEditor` mutation (including flowchart insert-node / insert-edge).

**Architecture:** Source text remains the canonical state. The store owns one persistent `DiagramEditor` re-seeded on every successful parse. Structural mutations export back into `state.source`, which re-triggers the normal render path. Tap-to-select converts view-coords → diagram-coords with the committed pan/zoom transform, queries `DiagramBoundsLookup.element(at:)`, and writes `editor.selection`. A SwiftUI overlay draws a 2pt accent-color outline around the selected element. A floating drawer hosts the pane; Cmd-I toggles it.

**Tech Stack:** Swift 6, SwiftUI, `swift-testing` for library tests, XCTest (via xcodegen-generated test bundle) for playground tests, `DiagramKitInteractive` (`DiagramEditor`, mutations), `DiagramKitViews` (`DiagramView` API addition), `DiagramKitModel` (`DiagramBoundsLookup`).

---

## File Structure

**Created**

- `Tests/DiagramKitTests/DiagramViewBoundsLookupBindingTests.swift` — library API test
- `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift` — new SwiftUI pane (~350 lines target, split if >500)
- `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests.swift`
- `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/TapCoordinateConversionTests.swift`
- `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/TapToSelectTests.swift`

**Modified**

- `Sources/DiagramKitViews/DiagramView.swift` — new `boundsLookup` binding (UIKit + AppKit)
- `Examples/DiagramPlayground/project.yml` — new `DiagramPlaygroundTests` target + scheme test action
- `Examples/DiagramPlayground/Models/LiveEditorState.swift` — `inspectorOpen` field + Codable migration
- `Examples/DiagramPlayground/Models/LiveEditorStore.swift` — persistent `editor`, `boundsLookup`, selection, mutations, drawer toggle, tap dispatch, structural undo/redo
- `Examples/DiagramPlayground/Views/PreviewCanvas.swift` — `boundsLookup` binding flow, tap gesture, selection overlay
- `Examples/DiagramPlayground/Views/LiveEditorView.swift` — drawer overlay, `@FocusState`, `CommandGroup(replacing: .undoRedo)`, compact-mode `.inspector` case
- `Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift` — Inspector toolbar button with Cmd-I
- `Examples/DiagramPlayground/Views/ActionsView.swift` — remove Inspector button + `onShowInspector` parameter
- `Examples/DiagramPlayground/Views/Toolbar/ActionsPanel.swift` — remove Inspector sheet + state flag

**Deleted**

- `Examples/DiagramPlayground/Views/Inspector/InspectorView.swift`
- `Examples/DiagramPlayground/Views/Inspector/` (directory, once empty)

---

## Phase 1 — Library API: `DiagramView.boundsLookup` binding

### Task 1: Write the failing test for `boundsLookup` publication

**Files:**
- Create: `Tests/DiagramKitTests/DiagramViewBoundsLookupBindingTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
#if canImport(UIKit) || canImport(AppKit)
import Testing
import Foundation
@testable import DiagramKit
@testable import DiagramKitCommon
@testable import DiagramKitModel
@testable import DiagramKitRenderingCG
@testable import DiagramKitViews

@MainActor
@Suite("DiagramView bounds-lookup binding")
struct DiagramViewBoundsLookupBindingTests {

    @Test("PreparedDiagram exposes a non-nil lookup with node IDs after a successful prepare")
    func lookupPopulatedAfterSuccessfulPrepare() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        let source = "flowchart LR\n  A --> B\n"

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = { [weak layer] in
                if layer?.source == source, !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            layer.source = source
        }

        let lookup = layer.preparedDiagram?.positioned.lookup
        #expect(lookup != nil)
        #expect(lookup?.allElementIDs.contains("node:A") == true)
        #expect(lookup?.allElementIDs.contains("node:B") == true)
    }

    @Test("PreparedDiagram is nil after a parse error so the lookup binding publishes nil")
    func lookupNilAfterParseError() async {
        DiagramEngine.bootstrap()
        let layer = DiagramLayer()
        let bogus = "not-a-diagram-source\n"

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            layer.onPrepareComplete = { [weak layer] in
                if layer?.source == bogus, !resumed {
                    resumed = true
                    continuation.resume()
                }
            }
            layer.source = bogus
        }

        #expect(layer.preparedDiagram == nil)
        #expect(layer.parseError != nil)
    }

    @Test("DiagramView default initializer (no boundsLookup binding) compiles")
    func defaultInitializerCompiles() {
        // Compile-time check: existing call sites must keep working with the
        // new parameter's default value. Body is empty on purpose; success is
        // a clean build.
        _ = DiagramView(source: "")
    }
}
#endif
```

- [ ] **Step 2: Run the test to verify it fails to compile**

Run: `swift test --filter DiagramViewBoundsLookupBindingTests`

Expected: compile error on `_ = DiagramView(source: "")` is fine (existing call); the test body itself compiles, but `defaultInitializerCompiles` will pass trivially. The other two tests should compile and pass against today's `preparedDiagram.positioned.lookup` (it's already public). Re-read the output: if all three pass, that's expected because the test only exercises the lookup-publishing source, not the new binding. We rely on Task 2 to add the binding and a separate compile-time check confirms the new parameter exists.

If any test fails to compile due to an API mismatch (e.g., `positioned` not visible), inspect `DiagramKitRenderingCG/PreparedDiagram.swift` to confirm `positioned: PositionedGraph` is `public`.

- [ ] **Step 3: Commit the failing/baseline test**

```bash
git add Tests/DiagramKitTests/DiagramViewBoundsLookupBindingTests.swift
git commit -m "test(views): add baseline tests for DiagramView bounds-lookup publication"
```

### Task 2: Add the `boundsLookup` binding to `DiagramView`

**Files:**
- Modify: `Sources/DiagramKitViews/DiagramView.swift` (UIKit branch lines 8–96, AppKit branch lines 98–187)

- [ ] **Step 1: Add the binding declaration, init parameter, coordinator wiring, and `publish` write — UIKit branch**

Replace the UIKit struct's stored properties, init, `makeCoordinator`, `makeUIView`, `updateUIView`, and `Coordinator` with:

```swift
/// A SwiftUI view that renders a Mermaid diagram.
@available(iOS 26.0, macCatalyst 26.0, visionOS 26.0, *)
@MainActor
public struct DiagramView: UIViewRepresentable {
    private let source: String
    private let theme: DiagramTheme
    private let layoutConfig: LayoutConfig
    @Binding private var parseError: Error?
    @Binding private var diagramBounds: CGRect
    @Binding private var boundsLookup: DiagramBoundsLookup?

    public init(
        source: String,
        theme: DiagramTheme = .default,
        layoutConfig: LayoutConfig = LayoutConfig(),
        parseError: Binding<Error?> = .constant(nil),
        diagramBounds: Binding<CGRect> = .constant(.zero),
        boundsLookup: Binding<DiagramBoundsLookup?> = .constant(nil)
    ) {
        self.source = source
        self.theme = theme
        self.layoutConfig = layoutConfig
        self._parseError = parseError
        self._diagramBounds = diagramBounds
        self._boundsLookup = boundsLookup
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            parseError: $parseError,
            diagramBounds: $diagramBounds,
            boundsLookup: $boundsLookup
        )
    }

    public func makeUIView(context: Context) -> DiagramNativeView {
        let view = DiagramNativeView()
        context.coordinator.attach(to: view)
        view.theme = theme
        view.layoutConfig = layoutConfig
        view.source = source
        return view
    }

    public func updateUIView(_ view: DiagramNativeView, context: Context) {
        context.coordinator.updateBindings(
            parseError: $parseError,
            diagramBounds: $diagramBounds,
            boundsLookup: $boundsLookup
        )

        if view.theme != theme {
            view.theme = theme
        }

        if view.layoutConfig != layoutConfig {
            view.layoutConfig = layoutConfig
        }

        if view.source != source {
            view.source = source
        }
    }

    public final class Coordinator {
        fileprivate var parseError: Binding<Error?>
        fileprivate var diagramBounds: Binding<CGRect>
        fileprivate var boundsLookup: Binding<DiagramBoundsLookup?>
        fileprivate weak var view: DiagramNativeView?
        fileprivate var token: AnyObject?

        fileprivate init(
            parseError: Binding<Error?>,
            diagramBounds: Binding<CGRect>,
            boundsLookup: Binding<DiagramBoundsLookup?>
        ) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            self.boundsLookup = boundsLookup
        }

        @MainActor
        fileprivate func attach(to view: DiagramNativeView) {
            self.view = view
            self.token = view.diagramLayer.addPrepareCompletionHandler { [weak self, weak view] in
                self?.publish(from: view)
            }
        }

        @MainActor
        fileprivate func updateBindings(
            parseError: Binding<Error?>,
            diagramBounds: Binding<CGRect>,
            boundsLookup: Binding<DiagramBoundsLookup?>
        ) {
            self.parseError = parseError
            self.diagramBounds = diagramBounds
            self.boundsLookup = boundsLookup
        }

        @MainActor
        fileprivate func publish(from view: DiagramNativeView?) {
            guard let view else { return }
            parseError.wrappedValue = view.parseError
            diagramBounds.wrappedValue = view.diagramBounds
            boundsLookup.wrappedValue = view.diagramLayer.preparedDiagram?.positioned.lookup
        }
    }
}
```

- [ ] **Step 2: Mirror the same changes in the AppKit branch**

Apply the same five edits (stored property, init parameter, `makeCoordinator`, coordinator stored property + init + `updateBindings` signature + `publish` body) to the `#elseif canImport(AppKit)` branch lower in the same file. The shape is identical; only the typealiases differ (`NSViewRepresentable`, `makeNSView`, `updateNSView`).

- [ ] **Step 3: Confirm the library tests still pass and the new default initializer compiles**

Run: `swift test --filter DiagramViewBoundsLookupBindingTests`

Expected: 3 / 3 tests pass, including `defaultInitializerCompiles` (which proves the new `boundsLookup` parameter's default value keeps the API source-compatible).

- [ ] **Step 4: Run the broader DiagramView regression suite to make sure existing bindings still publish**

Run: `swift test --filter DiagramViewReviewRegressionTests`

Expected: existing pass count unchanged.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitViews/DiagramView.swift
git commit -m "feat(views): add public boundsLookup binding to DiagramView"
```

---

## Phase 2 — Playground test infrastructure

### Task 3: Add a `DiagramPlaygroundTests` xcodeproj target

**Files:**
- Modify: `Examples/DiagramPlayground/project.yml`
- Create: `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/Placeholder.swift`

- [ ] **Step 1: Add the test target and schemes entries to `project.yml`**

Open `Examples/DiagramPlayground/project.yml`. Inside `targets:`, after the `DiagramPlayground-iOS` block, append:

```yaml
  DiagramPlaygroundTests:
    type: bundle.unit-test
    platform: macOS
    deploymentTarget: "26.0"
    sources:
      - Tests/DiagramPlaygroundTests
    dependencies:
      - target: DiagramPlayground
      - package: DiagramKit
        product: DiagramKit
      - package: DiagramKit
        product: DiagramKitInteractive
      - package: DiagramKit
        product: DiagramKitModel
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lukilabs.DiagramPlaygroundTests
        GENERATE_INFOPLIST_FILE: YES
```

Then, inside the `schemes:` block, update the existing `DiagramPlayground` scheme to wire the test target into its `test` action by adding a `test:` section after `run:`:

```yaml
  DiagramPlayground:
    build:
      targets:
        DiagramPlayground: all
        DiagramPlaygroundTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - DiagramPlaygroundTests
    archive:
      config: Release
```

- [ ] **Step 2: Create a placeholder test file so xcodegen has a non-empty source directory**

Create `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/Placeholder.swift`:

```swift
import XCTest

final class PlaygroundPlaceholderTests: XCTestCase {
    func testPlaceholder() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 3: Regenerate the xcodeproj**

Run: `cd Examples/DiagramPlayground && xcodegen generate && cd -`

Expected: xcodegen reports `Created project at … DiagramPlayground.xcodeproj` with no errors.

- [ ] **Step 4: Run the placeholder test to confirm the target builds and runs**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/PlaygroundPlaceholderTests/testPlaceholder | tail -40`

Expected: `** TEST SUCCEEDED **` with 1 test executed.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/project.yml \
        Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/Placeholder.swift \
        Examples/DiagramPlayground/DiagramPlayground.xcodeproj
git commit -m "test(playground): add DiagramPlaygroundTests xcodeproj target"
```

---

## Phase 3 — `LiveEditorState.inspectorOpen`

### Task 4: Write the failing test for `inspectorOpen` Codable round-trip

**Files:**
- Create: `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStateInspectorOpenTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import DiagramPlayground

final class LiveEditorStateInspectorOpenTests: XCTestCase {

    func test_inspectorOpenDefaultsToFalse() {
        let state = LiveEditorState()
        XCTAssertFalse(state.inspectorOpen)
    }

    func test_inspectorOpenSurvivesEncodeDecodeRoundTrip() throws {
        var state = LiveEditorState()
        state.inspectorOpen = true
        let encoded = LiveEditorStateCodec.encode(state)
        let decoded = try LiveEditorStateCodec.decode(encoded)
        XCTAssertTrue(decoded.inspectorOpen)
    }

    func test_legacySnapshotWithoutInspectorOpenDecodesAsFalse() throws {
        // Older serialized states do not include the inspectorOpen key.
        // Decoding such a snapshot must default to false (no crash, no flip).
        let legacyJSON = """
        {"source":"flowchart TD\\nA --> B\\n","selectedThemeName":"Zinc Light","configJSON":"{}","gridEnabled":false,"panZoomEnabled":true,"editorMode":"code","updateMode":"auto","sourceFormat":"mermaid"}
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try JSONDecoder().decode(LiveEditorState.self, from: data)
        XCTAssertFalse(decoded.inspectorOpen)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/LiveEditorStateInspectorOpenTests | tail -40`

Expected: compile error — `Value of type 'LiveEditorState' has no member 'inspectorOpen'`.

### Task 5: Add `inspectorOpen` to `LiveEditorState`

**Files:**
- Modify: `Examples/DiagramPlayground/Models/LiveEditorState.swift`

- [ ] **Step 1: Add the stored property**

After line 63 (`public var updateMode: UpdateMode`), insert:

```swift

    // MARK: - Inspector pane

    /// Whether the floating Inspector drawer is currently open.
    public var inspectorOpen: Bool
```

- [ ] **Step 2: Add the init parameter**

In the `public init(...)` signature, after `updateMode: UpdateMode = .auto`, add a parameter and assignment:

Signature line:
```swift
        updateMode: UpdateMode = .auto,
        inspectorOpen: Bool = false
```

Body, after `self.updateMode = updateMode`:
```swift
        self.inspectorOpen = inspectorOpen
```

- [ ] **Step 3: Extend `CodingKeys` and `init(from:)`**

In the `CodingKeys` enum, after `case updateMode`, add:

```swift
        case inspectorOpen
```

In `public init(from decoder: Decoder) throws`, after `self.updateMode = try c.decodeIfPresent(...)`, add:

```swift
        self.inspectorOpen = try c.decodeIfPresent(Bool.self, forKey: .inspectorOpen) ?? false
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/LiveEditorStateInspectorOpenTests | tail -40`

Expected: 3 / 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/Models/LiveEditorState.swift \
        Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStateInspectorOpenTests.swift
git commit -m "feat(playground): persist Inspector drawer state in LiveEditorState"
```

---

## Phase 4 — `LiveEditorStore`: persistent `DiagramEditor` + bounds lookup

### Task 6: Write the failing test for the persistent `editor` lifecycle

**Files:**
- Create: `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel
@testable import DiagramPlayground

@MainActor
final class LiveEditorStoreEditorLifecycleTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    func test_editorIsNilForEmptySource() {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        XCTAssertNil(store.editor)
    }

    func test_editorIsRebuiltAfterValidFlowchartSource() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: ""))
        store.setSource("flowchart TD\nA --> B\n", origin: .system)

        try await waitForEditor(store: store)

        XCTAssertNotNil(store.editor)
        XCTAssertEqual(store.editor?.document.type, .flowchart)
        XCTAssertEqual(store.editor?.preferredExportFormat, store.state.sourceFormat.formatID)
    }

    func test_editorRetainsPreviousValueOnParseError() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        let firstEditor = try XCTUnwrap(store.editor)

        store.setSource("garbage that cannot parse", origin: .system)
        try await waitForRender(store: store)

        XCTAssertTrue(store.editor === firstEditor)
        XCTAssertNotNil(store.parseError)
    }

    // MARK: - Helpers

    /// Drive the render path until `store.editor` becomes non-nil or the
    /// helper times out.
    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never populated within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            // Force-feed the render lifecycle: in production this is driven by
            // DiagramView's prepareCompletion. In tests we call the entry point
            // directly with a zero bounds, simulating a successful render.
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }

    /// Drive the render path one tick so the store observes the most recent
    /// state transition.
    private func waitForRender(store: LiveEditorStore, timeout: TimeInterval = 1) async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
        store.didCompleteRender(parseError: NSError(domain: "test", code: 1), diagramBounds: .zero)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests | tail -40`

Expected: compile error — `Value of type 'LiveEditorStore' has no member 'editor'`.

### Task 7: Implement the persistent `editor` + re-seed in `LiveEditorStore`

**Files:**
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift`

- [ ] **Step 1: Add the import for `DiagramKitInteractive`**

At the top of the file, after `import DiagramKitModel`, add:

```swift
import DiagramKitInteractive
```

- [ ] **Step 2: Add the stored property and helper**

After the `historyStore` property (around line 109), add:

```swift

    // MARK: - Interactive editor (Phase 7)

    /// Persistent DiagramEditor. Re-seeded from `state.source` on every
    /// successful parse; nil until at least one render has succeeded.
    public private(set) var editor: DiagramEditor?

    /// Mirrors what `DiagramView` publishes for the current preview source.
    /// Used by the canvas tap dispatch and the selection overlay.
    public var boundsLookup: DiagramBoundsLookup?
```

- [ ] **Step 3: Re-seed the editor inside `didCompleteRender(...)`**

Replace the body of `didCompleteRender(parseError:diagramBounds:)` with:

```swift
    public func didCompleteRender(parseError: Error?, diagramBounds: CGRect) {
        self.parseError = parseError
        self.diagramBounds = diagramBounds

        if let parseError {
            _ = parseError  // keep the last valid preview visible
            renderStatus = .failed
        } else if state.source.isEmpty {
            renderStatus = .idle
            editor = nil
        } else {
            renderStatus = .rendered
            seedEditorFromSource()
            // Auto-save history after successful renders
            historyStore.autoSaveIfNeeded(state: previewState)
        }
    }

    /// Re-seed `editor` from the currently committed `state.source`.
    ///
    /// Runs on every successful render. Preserves selection by element ID
    /// when the element still exists in the new layout; otherwise clears.
    private func seedEditorFromSource() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let document = try await DiagramEngine.parse(self.state.source)
                await self.applySeededEditor(document: document)
            } catch {
                // Parse failures are already surfaced via parseError; leave
                // the existing editor in place so structural undo state isn't
                // destroyed by a transient text-edit-in-progress.
            }
        }
    }

    /// Apply a freshly-parsed document to the persistent editor.
    @MainActor
    private func applySeededEditor(document: DiagramDocument) async {
        let previousSelectionID = editor?.selection?.elementID
        let formatID = state.sourceFormat.formatID

        let newEditor = DiagramEditor(
            document: document,
            preferredExportFormat: formatID,
            exportRegistry: DiagramPipeline.defaultExportRegistry
        )
        try? newEditor.syncSource()

        // Best-effort selection restore: depends on the lookup being current.
        // The DiagramView preview path also publishes a lookup; the canvas
        // overlay uses that. We only need to clear stale selection here.
        if let previousSelectionID,
           let lookup = boundsLookup,
           let restored = lookup.selection(for: previousSelectionID) {
            newEditor.selection = restored
        } else {
            newEditor.selection = nil
        }

        editor = newEditor
    }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests | tail -40`

Expected: 3 / 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/Models/LiveEditorStore.swift \
        Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests.swift
git commit -m "feat(playground): own a persistent DiagramEditor on LiveEditorStore"
```

---

## Phase 5 — Tap dispatch: coordinate math + selection routing

### Task 8: Write the failing test for `tapPointInDiagramCoordinates`

**Files:**
- Create: `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/TapCoordinateConversionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import DiagramPlayground
import CoreGraphics

final class TapCoordinateConversionTests: XCTestCase {

    func test_identityTransformReturnsTapMinusCenteringOffset() {
        // viewSize 400x300, diagramBounds 100x100, no zoom, no pan.
        // The diagram is centered, so the centering offset on each axis is
        // (viewSize - diagramSize)/2 = (150, 100).
        // A tap at (170, 110) lands at (20, 10) in diagram-coords.
        let point = LiveEditorStore.tapPointInDiagramCoordinates(
            viewPoint: CGPoint(x: 170, y: 110),
            viewSize: CGSize(width: 400, height: 300),
            diagramBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            zoomScale: 1,
            panOffset: .zero
        )
        XCTAssertEqual(point.x, 20, accuracy: 0.0001)
        XCTAssertEqual(point.y, 10, accuracy: 0.0001)
    }

    func test_zoomScaleDividesOutOfTapCoordinates() {
        // viewSize 400x300, diagramBounds 100x100, zoom 2x.
        // Scaled diagram is 200x200, centered at offset ((400-200)/2, (300-200)/2) = (100, 50).
        // A tap at (140, 70) is (40, 20) in screen-px from the diagram origin;
        // divided by zoom 2 gives (20, 10) in diagram-coords.
        let point = LiveEditorStore.tapPointInDiagramCoordinates(
            viewPoint: CGPoint(x: 140, y: 70),
            viewSize: CGSize(width: 400, height: 300),
            diagramBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            zoomScale: 2,
            panOffset: .zero
        )
        XCTAssertEqual(point.x, 20, accuracy: 0.0001)
        XCTAssertEqual(point.y, 10, accuracy: 0.0001)
    }

    func test_panOffsetSubtractsBeforeZoomDivision() {
        // viewSize 400x300, diagramBounds 100x100, zoom 2x, pan (30, 20).
        // Centering offset (100, 50). Effective draw origin = (130, 70).
        // A tap at (170, 90) is (40, 20) in screen-px → (20, 10) in diagram.
        let point = LiveEditorStore.tapPointInDiagramCoordinates(
            viewPoint: CGPoint(x: 170, y: 90),
            viewSize: CGSize(width: 400, height: 300),
            diagramBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
            zoomScale: 2,
            panOffset: CGSize(width: 30, height: 20)
        )
        XCTAssertEqual(point.x, 20, accuracy: 0.0001)
        XCTAssertEqual(point.y, 10, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/TapCoordinateConversionTests | tail -30`

Expected: compile error — `Type 'LiveEditorStore' has no member 'tapPointInDiagramCoordinates'`.

### Task 9: Implement `tapPointInDiagramCoordinates`

**Files:**
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift`

- [ ] **Step 1: Add the static function at the bottom of the file (before the closing types)**

Inside the `LiveEditorStore` class body, after `private func writeToPasteboard(...)` and `commitCurrentStateToPreview()`, add:

```swift

    // MARK: - Tap coordinate math (Phase 7)

    /// Convert a tap point in `DiagramView` view-space into diagram-space.
    ///
    /// The preview frames `DiagramView` at `diagramBounds * zoomScale` and
    /// centers it inside `viewSize`, then translates by `panOffset`. This
    /// helper inverts that transform.
    ///
    /// `nonisolated` so unit tests can call it without crossing the
    /// `@MainActor` boundary.
    nonisolated public static func tapPointInDiagramCoordinates(
        viewPoint: CGPoint,
        viewSize: CGSize,
        diagramBounds: CGRect,
        zoomScale: CGFloat,
        panOffset: CGSize
    ) -> CGPoint {
        let scaledWidth = diagramBounds.width * zoomScale
        let scaledHeight = diagramBounds.height * zoomScale
        let centerX = (viewSize.width - scaledWidth) / 2 + panOffset.width
        let centerY = (viewSize.height - scaledHeight) / 2 + panOffset.height
        let localX = (viewPoint.x - centerX) / zoomScale
        let localY = (viewPoint.y - centerY) / zoomScale
        return CGPoint(x: localX, y: localY)
    }
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/TapCoordinateConversionTests | tail -30`

Expected: 3 / 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Models/LiveEditorStore.swift \
        Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/TapCoordinateConversionTests.swift
git commit -m "feat(playground): add pure tap-coordinate conversion helper"
```

### Task 10: Write the failing test for `setSelection(_:)` and `handleTapAt(_:viewSize:)`

**Files:**
- Create: `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/TapToSelectTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
import DiagramKit
import DiagramKitModel
@testable import DiagramPlayground

@MainActor
final class TapToSelectTests: XCTestCase {

    override func setUp() async throws {
        DiagramEngine.bootstrap()
    }

    func test_setSelectionWritesIntoEditor() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)

        let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        store.setSelection(selection)
        XCTAssertEqual(store.editor?.selection?.elementID, "node:A")

        store.setSelection(nil)
        XCTAssertNil(store.editor?.selection)
    }

    func test_handleTapWithoutLookupIsNoop() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        // boundsLookup intentionally nil
        store.handleTapAt(viewPoint: CGPoint(x: 50, y: 50), viewSize: CGSize(width: 200, height: 200))
        XCTAssertNil(store.editor?.selection)
    }

    func test_handleTapHittingNodeSetsSelection() async throws {
        // Use a real parse + layout to get a populated DiagramBoundsLookup.
        // DiagramBoundsLookup.Entry is private, so we cannot synthesize one
        // directly — we drive the real pipeline and tap at the actual node bounds.
        let source = "flowchart TD\nA[Start] --> B[End]\n"
        let graph = try await DiagramEngine.layout(source)
        let lookup = graph.lookup
        let store = LiveEditorStore(state: LiveEditorState(source: source))
        try await waitForEditor(store: store)
        store.boundsLookup = lookup
        store.diagramBounds = CGRect(x: 0, y: 0, width: graph.width, height: graph.height)
        store.state.zoomScale = 1
        store.state.panOffset = .zero

        let aSelection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        let aBounds = try XCTUnwrap(lookup.bounds(of: aSelection))
        let viewSize = CGSize(width: graph.width + 200, height: graph.height + 200)
        // Tap at the geometric centre of node A in view-coords, accounting for
        // the centering offset that PreviewCanvas applies.
        let centerX = (viewSize.width - graph.width) / 2 + CGFloat(aBounds.minX + aBounds.width / 2)
        let centerY = (viewSize.height - graph.height) / 2 + CGFloat(aBounds.minY + aBounds.height / 2)

        store.handleTapAt(viewPoint: CGPoint(x: centerX, y: centerY), viewSize: viewSize)
        XCTAssertEqual(store.editor?.selection?.elementID, "node:A")
    }

    func test_handleTapMissingAnyElementClearsSelection() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        store.boundsLookup = DiagramBoundsLookup.empty(diagramType: .flowchart)
        store.editor?.selection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")

        store.handleTapAt(viewPoint: .zero, viewSize: CGSize(width: 200, height: 200))
        XCTAssertNil(store.editor?.selection)
    }

    private func waitForEditor(store: LiveEditorStore, timeout: TimeInterval = 5) async throws {
        let start = Date()
        while store.editor == nil {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("editor never populated within \(timeout)s")
                return
            }
            try await Task.sleep(nanoseconds: 25_000_000)
            store.didCompleteRender(parseError: nil, diagramBounds: .zero)
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/TapToSelectTests | tail -40`

Expected: compile errors — `Value of type 'LiveEditorStore' has no member 'setSelection'` and `'handleTapAt'`.

### Task 11: Implement `setSelection` and `handleTapAt`

**Files:**
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift`

- [ ] **Step 1: Add the action methods**

In the `LiveEditorStore` class body, after the `tapPointInDiagramCoordinates` helper added in Task 9, add:

```swift

    // MARK: - Selection (Phase 7)

    /// Write `selection` into the persistent editor. Used by both the canvas
    /// tap dispatch and any keyboard-driven picker.
    public func setSelection(_ selection: DiagramSelection?) {
        editor?.selection = selection
    }

    /// Convert a view-space tap into a selection on `editor`.
    ///
    /// Uses the committed `state.zoomScale` and `state.panOffset` — never the
    /// in-flight gesture state — so the result matches what the user sees.
    public func handleTapAt(viewPoint: CGPoint, viewSize: CGSize) {
        guard let lookup = boundsLookup else { return }
        let localPoint = Self.tapPointInDiagramCoordinates(
            viewPoint: viewPoint,
            viewSize: viewSize,
            diagramBounds: diagramBounds,
            zoomScale: state.zoomScale ?? 1,
            panOffset: state.panOffset ?? .zero
        )
        let diagramPoint = DiagramPoint(x: Double(localPoint.x), y: Double(localPoint.y))
        setSelection(lookup.element(at: diagramPoint))
    }
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/TapToSelectTests | tail -40`

Expected: 4 / 4 tests pass.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Models/LiveEditorStore.swift \
        Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/TapToSelectTests.swift
git commit -m "feat(playground): wire tap-to-select through LiveEditorStore"
```

---

## Phase 6 — Mutations, inspector toggle, and undo/redo routing

### Task 12: Extend the lifecycle tests with mutation-flow expectations

**Files:**
- Modify: `Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests.swift`

- [ ] **Step 1: Add the new test cases**

Append two methods inside the existing `LiveEditorStoreEditorLifecycleTests` class, just before the helpers section:

```swift
    func test_performSetLabelUpdatesSourceAndPreservesSelection() async throws {
        let store = LiveEditorStore(state: LiveEditorState(source: "flowchart TD\nA --> B\n"))
        try await waitForEditor(store: store)
        let selection = DiagramSelection(diagramType: .flowchart, elementID: "node:A")
        store.setSelection(selection)

        try store.performMutation(.setLabel(of: selection, to: "Renamed"))
        try await waitForRenderTick(store: store)

        XCTAssertTrue(store.state.source.contains("Renamed"))
        XCTAssertEqual(store.editor?.selection?.elementID, "node:A")
    }

    func test_toggleInspectorFlipsState() {
        let store = LiveEditorStore(state: LiveEditorState())
        XCTAssertFalse(store.state.inspectorOpen)
        store.toggleInspector()
        XCTAssertTrue(store.state.inspectorOpen)
        store.toggleInspector()
        XCTAssertFalse(store.state.inspectorOpen)
    }
```

Also add the new helper inside the helpers section:

```swift
    /// Tick a successful render so re-seed runs after a mutation.
    private func waitForRenderTick(store: LiveEditorStore, timeout: TimeInterval = 1) async throws {
        try await Task.sleep(nanoseconds: 50_000_000)
        store.didCompleteRender(parseError: nil, diagramBounds: .zero)
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests | tail -40`

Expected: compile errors — `Value of type 'LiveEditorStore' has no member 'performMutation'` and `'toggleInspector'`.

### Task 13: Implement `performMutation`, `performFlowchartMutation`, `toggleInspector`, structural undo helpers

**Files:**
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift`

- [ ] **Step 1: Add the new methods**

After the `setSelection` / `handleTapAt` block added in Task 11, append:

```swift

    // MARK: - Mutations (Phase 7)

    /// Most recent mutation error, surfaced inline by the editor pane.
    /// Cleared automatically on the next successful mutation.
    public private(set) var lastMutationError: String?

    /// Apply a core mutation through the persistent editor, then push the
    /// exported source back into `state.source` (origin: `.system` so manual
    /// mode does not block the round-trip).
    ///
    /// No-ops silently when `editor` is nil — the pane gates buttons on
    /// `store.editor != nil`, so this only protects against races.
    public func performMutation(_ mutation: DiagramMutation) throws {
        guard let editor else { return }
        do {
            try editor.perform(mutation)
            lastMutationError = nil
            if let source = editor.source, source != state.source {
                setSource(source, origin: .system)
            }
        } catch {
            lastMutationError = error.localizedDescription
            throw error
        }
    }

    /// Apply a flowchart-specific mutation through the persistent editor.
    ///
    /// No-ops silently when `editor` is nil.
    public func performFlowchartMutation(_ mutation: FlowchartMutation) throws {
        guard let editor else { return }
        do {
            try editor.performFlowchart(mutation)
            lastMutationError = nil
            if let source = editor.source, source != state.source {
                setSource(source, origin: .system)
            }
        } catch {
            lastMutationError = error.localizedDescription
            throw error
        }
    }

    // MARK: - Inspector pane (Phase 7)

    /// Toggle the floating Inspector drawer.
    public func toggleInspector() {
        state.inspectorOpen.toggle()
    }

    /// Delegate to `editor.undoManager.undo()`.
    public func undoStructural() {
        editor?.undoManager.undo()
    }

    /// Delegate to `editor.undoManager.redo()`.
    public func redoStructural() {
        editor?.undoManager.redo()
    }
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `xcodebuild test -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground -destination 'platform=macOS' -only-testing:DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests | tail -40`

Expected: 5 / 5 tests pass (3 original + 2 new).

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Models/LiveEditorStore.swift \
        Examples/DiagramPlayground/Tests/DiagramPlaygroundTests/LiveEditorStoreEditorLifecycleTests.swift
git commit -m "feat(playground): route DiagramEditor mutations + inspector toggle through the store"
```

---

## Phase 7 — `DiagramEditorPane` SwiftUI view

> The pane has no automated tests — there is no playground snapshot infrastructure. Each task ends with a manual verification step in `swift run DiagramPlayground` and a commit. Tasks are split so each commit produces a coherent, visible improvement.

### Task 14: Create the pane skeleton with parse/family banners

**Files:**
- Create: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- [ ] **Step 1: Write the file**

```swift
//
//  DiagramEditorPane.swift
//  DiagramPlayground
//
//  Floating Inspector drawer that hosts DiagramKitInteractive's
//  DiagramEditor. Replaces the modal InspectorView. Renders disabled
//  banners when the document is missing or non-flowchart.
//

import SwiftUI
import DiagramKit
import DiagramKitInteractive
import DiagramKitModel

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
struct DiagramEditorPane: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                content
                    .padding(16)
            }
        }
        .frame(minWidth: 320, idealWidth: 360)
        .background(.regularMaterial)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(store.theme.effectiveLine()).opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, x: -2, y: 0)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Inspector")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(store.theme.foreground))
            Spacer(minLength: 0)
            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            // Cmd-I lives on the toolbar button (Task 24) — keep this button
            // shortcut-free to avoid duplicate shortcut warnings.
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if store.editor == nil {
            disabledBanner(
                icon: "doc.text",
                message: "Parse the source to enable interactive editing."
            )
        } else if let editor = store.editor, editor.document.type != .flowchart {
            disabledBanner(
                icon: "exclamationmark.triangle",
                message: "Interactive editing is not yet available for \(editor.document.type.rawValue) diagrams."
            )
        } else {
            // Real sections land in Tasks 15–18.
            placeholderSection
        }
    }

    private var placeholderSection: some View {
        Text("Editor sections will land in subsequent tasks.")
            .font(.system(size: 12))
            .foregroundColor(Color(store.theme.effectiveMuted()))
    }

    private func disabledBanner(icon: String, message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(store.theme.effectiveMuted()))
            Text(message)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 2: Confirm the project still builds**

Run: `swift build` (no need to launch the app yet — `DiagramEditorPane` is currently unused).

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "feat(playground): scaffold DiagramEditorPane with parse/family banners"
```

### Task 15: Add the title section

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- [ ] **Step 1: Replace `placeholderSection` and add the title section view**

In the file, find the lines:

```swift
        } else {
            // Real sections land in Tasks 15–18.
            placeholderSection
        }
```

Replace with:

```swift
        } else if let editor = store.editor {
            VStack(alignment: .leading, spacing: 18) {
                TitleSection(store: store, editor: editor)
                if let message = store.lastMutationError {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
```

Delete the `placeholderSection` property (no longer used) and append the section view:

```swift

// MARK: - Title section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct TitleSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Document title", store: store)
            HStack(spacing: 6) {
                TextField("Untitled", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Set") {
                    try? store.performMutation(.setTitle(draft.isEmpty ? nil : draft))
                }
                Button("Clear") {
                    try? store.performMutation(.setTitle(nil))
                }
                .disabled(editor.document.title == nil)
            }
            Text("Currently: \(editor.document.title ?? "—")")
                .font(.system(size: 10))
                .foregroundColor(Color(store.theme.effectiveMuted()))
        }
        .onAppear {
            draft = editor.document.title ?? ""
        }
        .onChange(of: editor.document.title) { _, newValue in
            draft = newValue ?? ""
        }
    }
}

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private func sectionLabel(_ text: String, store: LiveEditorStore) -> some View {
    Text(text)
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(Color(store.theme.effectiveMuted()))
        .textCase(.uppercase)
}
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "feat(playground): add title section to DiagramEditorPane"
```

### Task 16: Add the selection + label + delete sections

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- [ ] **Step 1: Extend the main `else` branch and append new section views**

Find the `else if let editor = store.editor {` body and replace its inner `VStack` with:

```swift
        } else if let editor = store.editor {
            VStack(alignment: .leading, spacing: 18) {
                TitleSection(store: store, editor: editor)
                Divider()
                SelectionSection(store: store, editor: editor)
                Divider()
                LabelSection(store: store, editor: editor)
                Divider()
                DeleteSection(store: store, editor: editor)
                if let message = store.lastMutationError {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
            }
        }
```

Append at the bottom of the file:

```swift

// MARK: - Selection section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct SelectionSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Selection", store: store)
            if let lookup = store.boundsLookup, !lookup.allElementIDs.isEmpty {
                Picker("Selected element", selection: pickerBinding(lookup: lookup)) {
                    Text("None").tag(String?.none)
                    Section("Nodes") {
                        ForEach(nodeIDs(lookup: lookup), id: \.self) { id in
                            Text(displayName(id: id, lookup: lookup)).tag(String?.some(id))
                        }
                    }
                    Section("Edges") {
                        ForEach(edgeIDs(lookup: lookup), id: \.self) { id in
                            Text(displayName(id: id, lookup: lookup)).tag(String?.some(id))
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            } else {
                Text("No selectable elements in this diagram.")
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            }
        }
    }

    private func pickerBinding(lookup: DiagramBoundsLookup) -> Binding<String?> {
        Binding(
            get: { editor.selection?.elementID },
            set: { newID in
                if let newID, let selection = lookup.selection(for: newID) {
                    store.setSelection(selection)
                } else {
                    store.setSelection(nil)
                }
            }
        )
    }

    private func nodeIDs(lookup: DiagramBoundsLookup) -> [String] {
        lookup.allElementIDs.filter { $0.hasPrefix("node:") }
    }

    private func edgeIDs(lookup: DiagramBoundsLookup) -> [String] {
        lookup.allElementIDs.filter { $0.hasPrefix("edge:") }
    }

    private func displayName(id: String, lookup: DiagramBoundsLookup) -> String {
        guard let sel = lookup.selection(for: id) else { return id }
        if let label = lookup.label(for: sel), !label.isEmpty {
            return "\(label) (\(id))"
        }
        return id
    }
}

// MARK: - Label section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct LabelSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Label", store: store)
            HStack(spacing: 6) {
                TextField("Label…", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button("Rename") {
                    guard let selection = editor.selection else { return }
                    try? store.performMutation(.setLabel(of: selection, to: draft))
                }
                .disabled(editor.selection == nil)
            }
        }
        .onChange(of: editor.selection) { _, _ in
            updateDraft()
        }
        .onAppear { updateDraft() }
    }

    private func updateDraft() {
        guard let selection = editor.selection,
              let label = store.boundsLookup?.label(for: selection) else {
            draft = ""
            return
        }
        draft = label
    }
}

// MARK: - Delete section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct DeleteSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        HStack {
            Button("Delete selected", role: .destructive) {
                guard let selection = editor.selection else { return }
                try? store.performMutation(.deleteElement(selection))
            }
            .disabled(editor.selection == nil)
            Spacer(minLength: 0)
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "feat(playground): add selection / label / delete sections to DiagramEditorPane"
```

### Task 17: Add insert-node and insert-edge sections

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- [ ] **Step 1: Insert two new section views into the main `VStack`**

Find the existing main `VStack`:

```swift
                TitleSection(store: store, editor: editor)
                Divider()
                SelectionSection(store: store, editor: editor)
                Divider()
                LabelSection(store: store, editor: editor)
                Divider()
                DeleteSection(store: store, editor: editor)
```

Replace with:

```swift
                TitleSection(store: store, editor: editor)
                Divider()
                SelectionSection(store: store, editor: editor)
                Divider()
                LabelSection(store: store, editor: editor)
                Divider()
                InsertNodeSection(store: store, editor: editor)
                Divider()
                InsertEdgeSection(store: store, editor: editor)
                Divider()
                DeleteSection(store: store, editor: editor)
```

- [ ] **Step 2: Append the new section views**

At the bottom of the file, append:

```swift

// MARK: - Insert-node section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct InsertNodeSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var idDraft: String = ""
    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var shape: ShapeChoice = .rectangle
    @SwiftUI.State private var localError: String?

    enum ShapeChoice: String, CaseIterable, Identifiable {
        case rectangle, round, stadium, circle, rhombus
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Insert node", store: store)
            HStack(spacing: 6) {
                TextField("ID (e.g. n3)", text: $idDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(maxWidth: 80)
                TextField("Label", text: $labelDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
            HStack(spacing: 6) {
                Picker("Shape", selection: $shape) {
                    ForEach(ShapeChoice.allCases) { c in
                        Text(c.label).tag(c)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 140)
                Spacer(minLength: 0)
                Button("Insert") {
                    insert()
                }
                .disabled(labelDraft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let localError {
                Text(localError)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }

    private func insert() {
        let id = idDraft.trimmingCharacters(in: .whitespaces).isEmpty
            ? Self.nextDefaultID(existing: store.boundsLookup?.allElementIDs ?? [])
            : idDraft
        do {
            try store.performFlowchartMutation(.insertNode(id: id, label: labelDraft, type: shape.rawValue))
            idDraft = ""
            labelDraft = ""
            localError = nil
        } catch {
            localError = error.localizedDescription
        }
    }

    static func nextDefaultID(existing: [String]) -> String {
        let nodeIDs = Set(existing.compactMap { $0.hasPrefix("node:") ? String($0.dropFirst(5)) : nil })
        var n = 1
        while nodeIDs.contains("n\(n)") { n += 1 }
        return "n\(n)"
    }
}

// MARK: - Insert-edge section

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct InsertEdgeSection: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    @SwiftUI.State private var fromID: String?
    @SwiftUI.State private var toID: String?
    @SwiftUI.State private var labelDraft: String = ""
    @SwiftUI.State private var idDraft: String = ""
    @SwiftUI.State private var localError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Insert edge", store: store)
            HStack(spacing: 6) {
                fromPicker
                Image(systemName: "arrow.right")
                    .font(.system(size: 11))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
                toPicker
            }
            HStack(spacing: 6) {
                TextField("Label (optional)", text: $labelDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                TextField("Edge ID (optional)", text: $idDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(maxWidth: 100)
                Button("Insert") {
                    insert()
                }
                .disabled(fromID == nil || toID == nil)
            }
            if let localError {
                Text(localError)
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
        .onAppear { seedFromCurrentSelection() }
        .onChange(of: editor.selection) { _, _ in seedFromCurrentSelection() }
    }

    private var fromPicker: some View {
        Picker("From", selection: $fromID) {
            Text("From…").tag(String?.none)
            ForEach(nodeIDs(), id: \.self) { id in
                Text(displayName(id: id)).tag(String?.some(id))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private var toPicker: some View {
        Picker("To", selection: $toID) {
            Text("To…").tag(String?.none)
            ForEach(nodeIDs(), id: \.self) { id in
                Text(displayName(id: id)).tag(String?.some(id))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }

    private func nodeIDs() -> [String] {
        (store.boundsLookup?.allElementIDs ?? []).filter { $0.hasPrefix("node:") }
    }

    private func displayName(id: String) -> String {
        guard let sel = store.boundsLookup?.selection(for: id) else { return id }
        if let label = store.boundsLookup?.label(for: sel), !label.isEmpty {
            return label
        }
        return id
    }

    private func seedFromCurrentSelection() {
        if let selection = editor.selection,
           selection.elementID.hasPrefix("node:"),
           fromID == nil {
            fromID = selection.elementID
        }
    }

    private func insert() {
        guard
            let fromID,
            let toID,
            let lookup = store.boundsLookup,
            let fromSel = lookup.selection(for: fromID),
            let toSel = lookup.selection(for: toID)
        else { return }
        let id = idDraft.trimmingCharacters(in: .whitespaces)
        let label = labelDraft.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : labelDraft
        do {
            try store.performFlowchartMutation(.insertEdge(id: id, from: fromSel, to: toSel, label: label))
            labelDraft = ""
            idDraft = ""
            self.fromID = nil
            self.toID = nil
            localError = nil
        } catch {
            localError = error.localizedDescription
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "feat(playground): add insert-node and insert-edge sections to DiagramEditorPane"
```

### Task 18: Add the undo / redo footer

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- [ ] **Step 1: Add a footer to the main `VStack` and append the section view**

Find the closing `if let message = store.lastMutationError {` block inside the main `VStack`. Replace the whole `VStack` body with:

```swift
                TitleSection(store: store, editor: editor)
                Divider()
                SelectionSection(store: store, editor: editor)
                Divider()
                LabelSection(store: store, editor: editor)
                Divider()
                InsertNodeSection(store: store, editor: editor)
                Divider()
                InsertEdgeSection(store: store, editor: editor)
                Divider()
                DeleteSection(store: store, editor: editor)
                Divider()
                UndoRedoFooter(store: store, editor: editor)
                if let message = store.lastMutationError {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                if !editor.lastExportDiagnostics.isEmpty {
                    ForEach(editor.lastExportDiagnostics.indices, id: \.self) { idx in
                        let d = editor.lastExportDiagnostics[idx]
                        Text("\(String(describing: d.severity)): \(d.message)")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                }
```

At the bottom of the file, append:

```swift

// MARK: - Undo / redo footer

@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
private struct UndoRedoFooter: View {
    @Bindable var store: LiveEditorStore
    let editor: DiagramEditor

    var body: some View {
        HStack(spacing: 8) {
            Button {
                store.undoStructural()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!editor.undoManager.canUndo)

            Button {
                store.redoStructural()
            } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!editor.undoManager.canRedo)

            Spacer(minLength: 0)

            if !editor.undoManager.undoActionName.isEmpty {
                Text("Last: \(editor.undoManager.undoActionName)")
                    .font(.system(size: 10))
                    .foregroundColor(Color(store.theme.effectiveMuted()))
            }
        }
    }
}
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift
git commit -m "feat(playground): add undo/redo footer + diagnostics to DiagramEditorPane"
```

---

## Phase 8 — `PreviewCanvas`: bounds lookup, tap gesture, selection overlay

### Task 19: Plumb the new `boundsLookup` binding from `DiagramView` into the store

**Files:**
- Modify: `Examples/DiagramPlayground/Views/PreviewCanvas.swift`

- [ ] **Step 1: Add a local `@State` mirror and forward to the store**

Near the other `@SwiftUI.State` declarations at the top of `PreviewCanvas`, add:

```swift
    @SwiftUI.State private var liveBoundsLookup: DiagramBoundsLookup?
```

In `diagramContent(in:)`, update the `DiagramView(...)` call to pass the new binding. Find:

```swift
                DiagramView(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    parseError: parseErrorBinding,
                    diagramBounds: $liveDiagramBounds
                )
```

Replace with:

```swift
                DiagramView(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    parseError: parseErrorBinding,
                    diagramBounds: $liveDiagramBounds,
                    boundsLookup: $liveBoundsLookup
                )
```

Add an import for `DiagramKitModel` at the top of the file if not already present:

```swift
import DiagramKitModel
```

After the existing `.onChange(of: liveParseErrorMessage)` chain at the end of `diagramContent(in:)`, append:

```swift
        .onChange(of: liveBoundsLookup) { _, newValue in
            store.boundsLookup = newValue
        }
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/PreviewCanvas.swift
git commit -m "feat(playground): publish DiagramBoundsLookup from PreviewCanvas to the store"
```

### Task 20: Add the tap gesture and selection overlay to the preview

**Files:**
- Modify: `Examples/DiagramPlayground/Views/PreviewCanvas.swift`

- [ ] **Step 1: Add the tap gesture inside the `panZoomInteractions(...)` ZStack**

Replace the body of `diagramContent(in:)` with the version below — same shape as today, but with the tap gesture and the selection overlay attached. (Lines you keep are unchanged; only the inner `ZStack` is updated.)

```swift
    @ViewBuilder
    private func diagramContent(in geometry: GeometryProxy) -> some View {
        let zoomScale = currentZoomScale
        let scaledWidth = max(store.diagramBounds.width * zoomScale, 1)
        let scaledHeight = max(store.diagramBounds.height * zoomScale, 1)

        panZoomInteractions(
            ZStack {
                DiagramView(
                    source: store.previewSource,
                    theme: store.previewTheme,
                    layoutConfig: store.previewLayoutConfig,
                    parseError: parseErrorBinding,
                    diagramBounds: $liveDiagramBounds,
                    boundsLookup: $liveBoundsLookup
                )
                .frame(width: scaledWidth, height: scaledHeight)
                .offset(effectivePanOffset)

                selectionOverlay(geometry: geometry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .clipped()
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        let isMidGesture = gestureBaseZoomScale != nil || activePanTranslation != .zero
                        guard !isMidGesture else { return }
                        store.handleTapAt(viewPoint: event.location, viewSize: geometry.size)
                    }
            )
        )
        .onChange(of: store.diagramBounds) { _, newBounds in
            refreshAutomaticFit(bounds: newBounds, viewSize: geometry.size)
        }
        .onChange(of: geometry.size) { _, newSize in
            refreshAutomaticFit(bounds: store.diagramBounds, viewSize: newSize)
        }
        .onChange(of: liveDiagramBounds) { _, _ in
            forwardRenderCompletion()
        }
        .onChange(of: liveParseErrorMessage) { _, _ in
            forwardRenderCompletion()
        }
        .onChange(of: liveBoundsLookup) { _, newValue in
            store.boundsLookup = newValue
        }
    }

    @ViewBuilder
    private func selectionOverlay(geometry: GeometryProxy) -> some View {
        if let selection = store.editor?.selection,
           let bounds = store.boundsLookup?.bounds(of: selection) {
            let zoom = currentZoomScale
            let scaledWidth = store.diagramBounds.width * zoom
            let scaledHeight = store.diagramBounds.height * zoom
            let centerX = (geometry.size.width - scaledWidth) / 2 + effectivePanOffset.width
            let centerY = (geometry.size.height - scaledHeight) / 2 + effectivePanOffset.height
            let originX = centerX + CGFloat(bounds.minX) * zoom
            let originY = centerY + CGFloat(bounds.minY) * zoom
            let width = CGFloat(bounds.width) * zoom
            let height = CGFloat(bounds.height) * zoom

            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(store.previewTheme.effectiveAccent()), lineWidth: 2)
                .frame(width: width, height: height)
                .position(x: originX + width / 2, y: originY + height / 2)
                .allowsHitTesting(false)
        }
    }
```

The single `.onChange(of: liveBoundsLookup)` from the new body is the canonical mirror — Task 19's Step 1 added an identical line; this wholesale rewrite supersedes it.

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Manual verification — tap selects, drag doesn't**

Run: `swift run DiagramPlayground`

Verify:
1. The default flowchart sample loads.
2. Click on a node — the 2pt accent outline appears around it.
3. Click on empty canvas — outline disappears.
4. Drag-pan or pinch-zoom — outline stays correctly anchored; ending a drag does not accidentally re-select.

Quit the app.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/PreviewCanvas.swift
git commit -m "feat(playground): tap-to-select with accent outline overlay on the preview"
```

---

## Phase 9 — `LiveEditorView`: drawer overlay, undo command, compact mode

### Task 21: Overlay `DiagramEditorPane` as a floating drawer

**Files:**
- Modify: `Examples/DiagramPlayground/Views/LiveEditorView.swift`

- [ ] **Step 1: Wrap the editor/preview split in a `ZStack` overlay**

Replace `regularLayout` and `editorPreviewSplit` with:

```swift
    private var regularLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationTitle("Samples")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color(store.theme.background), for: .navigationBar)
                .toolbarColorScheme(store.theme.background.isLight ? .light : .dark, for: .navigationBar)
                #endif
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
                #endif
        } detail: {
            editorPreviewSplit
                .navigationTitle("Editor")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color(store.theme.background), for: .navigationBar)
                .toolbarColorScheme(store.theme.background.isLight ? .light : .dark, for: .navigationBar)
                #endif
                .sheet(isPresented: $showingFullWindowPreview) {
                    fullWindowPreviewSheet
                }
        }
        .navigationSplitViewStyle(.automatic)
        #if os(macOS)
        .frame(minWidth: 900, minHeight: 600)
        #endif
    }

    private var editorPreviewSplit: some View {
        #if os(macOS)
        HSplitView {
            EditorPane(store: store)
                .frame(minWidth: 300)
            previewWithDrawer
                .frame(minWidth: 400)
        }
        #else
        HStack(spacing: 0) {
            EditorPane(store: store)
                .frame(minWidth: 280)

            Divider()
                .background(Color(store.theme.effectiveLine()).opacity(0.3))

            previewWithDrawer
                .frame(minWidth: 300)
        }
        #endif
    }

    private var previewWithDrawer: some View {
        ZStack(alignment: .trailing) {
            PreviewCanvas(store: store, onFullWindowPreview: { showingFullWindowPreview = true })
            if store.state.inspectorOpen {
                DiagramEditorPane(store: store)
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: store.state.inspectorOpen)
    }
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Manual verification — drawer toggles correctly**

Run: `swift run DiagramPlayground`

The drawer is not toggleable from the UI yet (that lands in Task 24). Verify the build still launches and the preview renders.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/LiveEditorView.swift
git commit -m "feat(playground): overlay DiagramEditorPane as a floating drawer over the preview"
```

### Task 22: Add the structural undo `CommandGroup` (macOS)

**Files:**
- Modify: `Examples/DiagramPlayground/DiagramPlaygroundApp.swift`
- Modify: `Examples/DiagramPlayground/Views/LiveEditorView.swift`

- [ ] **Step 1: Declare a focus enum in `LiveEditorView.swift`**

Near the top of the file (above `struct LiveEditorView`), add:

```swift
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
enum DiagramPlaygroundFocus: Hashable {
    case text
    case inspector
}
```

And inside `LiveEditorView`, add a focus state:

```swift
    @FocusState var focus: DiagramPlaygroundFocus?
```

Bind focus in the editor and inspector — in `editorPreviewSplit`'s `EditorPane(store: store)` call, attach:

```swift
            EditorPane(store: store)
                .focused($focus, equals: .text)
                .frame(minWidth: 300)
```

In `previewWithDrawer`'s `DiagramEditorPane(store: store)` call, attach:

```swift
                DiagramEditorPane(store: store)
                    .focused($focus, equals: .inspector)
                    .padding(.vertical, 12)
                    .padding(.trailing, 12)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
```

- [ ] **Step 2: Add the `CommandGroup` in `DiagramPlaygroundApp.swift`**

Inside the `#if os(macOS)` `.commands { ... }` block on the `WindowGroup`, replace the existing body:

```swift
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" menu item
            }
        }
```

with:

```swift
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" menu item
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { store.undoStructural() }
                    .keyboardShortcut("z", modifiers: [.command])
                    .disabled(store.editor?.undoManager.canUndo != true)
                Button("Redo") { store.redoStructural() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(store.editor?.undoManager.canRedo != true)
            }
        }
```

> NOTE: This is intentionally a simple swap — when the structural editor has no work to undo, the menu item is disabled and Cmd-Z falls through to the focused control's native undo via the responder chain. The earlier focus-state plumbing is wired so the next iteration (out of scope here) can gate by focus if a user complains.

- [ ] **Step 3: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/LiveEditorView.swift \
        Examples/DiagramPlayground/DiagramPlaygroundApp.swift
git commit -m "feat(playground): route Cmd-Z to DiagramEditor.undoManager when structural undo is available"
```

### Task 23: Add the iPhone compact-mode `.inspector` case

**Files:**
- Modify: `Examples/DiagramPlayground/Views/LiveEditorView.swift`

- [ ] **Step 1: Extend `CompactMode` and the picker**

At the bottom of the file, replace the `CompactMode` enum with:

```swift
private enum CompactMode: CaseIterable {
    case edit
    case view
    case inspector

    var label: String {
        switch self {
        case .edit: return "Edit"
        case .view: return "View"
        case .inspector: return "Inspect"
        }
    }
}
```

In `compactLayout`'s `switch compactMode` block, replace it with:

```swift
                switch compactMode {
                case .edit:
                    EditorPane(store: store)
                case .view:
                    PreviewCanvas(store: store, onFullWindowPreview: nil)
                case .inspector:
                    DiagramEditorPane(store: store)
                }
```

- [ ] **Step 2: Build the iOS target via xcodebuild**

Run: `xcodebuild build -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground-iOS -destination 'generic/platform=iOS' | tail -10`

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add Examples/DiagramPlayground/Views/LiveEditorView.swift
git commit -m "feat(playground): add Edit/View/Inspect compact-mode tabs for iPhone"
```

---

## Phase 10 — Toolbar button, actions panel cleanup, Inspector deletion

### Task 24: Add the Inspector toolbar toggle with Cmd-I

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift`

- [ ] **Step 1: Add an Inspector toggle to each toolbar group**

The file declares the toolbar twice — a macOS variant around line 23 (`ToolbarItemGroup(placement: .primaryAction)` block at line 45) and an iOS variant around line 127 (`ToolbarItemGroup(placement: .topBarTrailing)` block at line 139). In both groups, add this as the **last** child (so it sits on the trailing edge of the toolbar):

```swift
            Button {
                store.toggleInspector()
            } label: {
                Image(systemName: store.state.inspectorOpen
                    ? "slider.horizontal.below.rectangle.fill"
                    : "slider.horizontal.below.rectangle")
            }
            .help("Inspector (⌘I)")
            .keyboardShortcut("i", modifiers: [.command])
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Manual verification — Cmd-I toggles the drawer**

Run: `swift run DiagramPlayground`

Verify:
1. Press Cmd-I — the drawer slides in from the right.
2. Press Cmd-I again — it slides out.
3. Click the toolbar Inspector icon — toggles the same way.
4. Click the X in the drawer header — drawer closes.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift
git commit -m "feat(playground): add Inspector toolbar toggle with Cmd-I shortcut"
```

### Task 25: Remove the modal Inspector from `ActionsView` / `ActionsPanel`

**Files:**
- Modify: `Examples/DiagramPlayground/Views/ActionsView.swift`
- Modify: `Examples/DiagramPlayground/Views/Toolbar/ActionsPanel.swift`

- [ ] **Step 1: Drop the `onShowInspector` parameter from `ActionsView`**

In `ActionsView.swift`, delete the property declaration:

```swift
    /// Called when the user taps "Inspector".
    let onShowInspector: () -> Void
```

Delete the entire `actionButton(label: "Inspector", ...)` block in the "View" section so that section now contains only the "Full-Window Preview" button.

- [ ] **Step 2: Update the `ActionsPanel` call site**

In `ActionsPanel.swift`, remove the `onShowInspector: { showingInspector = true }` argument from the `ActionsView(...)` call. Also delete:
- `@SwiftUI.State private var showingInspector = false`
- The entire trailing `.sheet(isPresented: $showingInspector) { ... }` block (the one containing `InspectorView(store: store, isPresented: $showingInspector)`).

- [ ] **Step 3: Build to confirm**

Run: `swift build`

Expected: build succeeds with no warnings about unused state.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/ActionsView.swift \
        Examples/DiagramPlayground/Views/Toolbar/ActionsPanel.swift
git commit -m "refactor(playground): retire the modal Inspector entry from ActionsView/ActionsPanel"
```

### Task 26: Delete the legacy `InspectorView.swift`

**Files:**
- Delete: `Examples/DiagramPlayground/Views/Inspector/InspectorView.swift`
- Delete: `Examples/DiagramPlayground/Views/Inspector/` (directory)

- [ ] **Step 1: Remove the file and regenerate the xcodeproj**

Run:

```bash
rm Examples/DiagramPlayground/Views/Inspector/InspectorView.swift
rmdir Examples/DiagramPlayground/Views/Inspector
cd Examples/DiagramPlayground && xcodegen generate && cd -
```

- [ ] **Step 2: Build to confirm**

Run: `swift build`

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add -A Examples/DiagramPlayground/
git commit -m "refactor(playground): delete legacy InspectorView replaced by DiagramEditorPane"
```

---

## Phase 11 — Full manual verification + discipline gates

### Task 27: End-to-end manual verification

**Files:** none modified

- [ ] **Step 1: Launch the playground**

Run: `swift run DiagramPlayground`

Walk through the following checklist. Each item should pass; if any fails, capture the symptom and add a follow-up fix task.

- [ ] Cmd-I toggles the drawer; the X button closes it; the toolbar button toggles it.
- [ ] With the default flowchart sample loaded, click a node → 2pt accent ring appears around it. The "Selection" picker also reflects the chosen node.
- [ ] Edit the source in the text editor (e.g., add a new node `D[New]`); the preview updates and the drawer's "Selection" picker now lists the new node.
- [ ] In the drawer, change "Document title" to "Demo" and click "Set" → the text editor's source gains a `title:` frontmatter line; preview updates.
- [ ] Select a node, type a new label, click "Rename" → source updates with the new label; selection stays on the same node ID.
- [ ] In "Insert node", leave ID blank, type "Q" as the label, pick "round", "Insert" → a new round node `n1` (or next free `nN`) appears at the end of the source; preview updates.
- [ ] In "Insert edge", pick a `from` and `to` from the menus, optional label "yes", "Insert" → a new edge appears in the source and preview.
- [ ] Select an edge or node, click "Delete selected" → source updates; selection clears.
- [ ] Click Undo in the footer (or press Cmd-Z while the drawer is the focused surface) → the last structural change reverses.
- [ ] Click Redo → the change is re-applied.
- [ ] Tap empty preview space → selection clears; the picker shows "None".
- [ ] Pan + zoom with two-finger gestures or scroll-wheel + drag — the selection outline stays anchored to the element.
- [ ] Switch the active sample to a sequence diagram → the drawer shows "Interactive editing is not yet available for sequence diagrams"; the canvas no longer shows an outline.
- [ ] Switch back to a flowchart → editing resumes.
- [ ] Convert / Export / Copy / History / Load actions in the Actions popover all still work (no regression).

Quit the app.

- [ ] **Step 2: Manual verification on iOS simulator**

Run: `xcodebuild -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj -scheme DiagramPlayground-iOS -destination 'platform=iOS Simulator,name=iPhone 15' build | tail -10`

Expected: `** BUILD SUCCEEDED **`. (Full simulator run is out of scope for the plan but the build must succeed.)

### Task 28: Run the full discipline-gate sweep

**Files:** none modified

- [ ] **Step 1: Build and library tests**

Run:

```bash
swift build && swift build --build-tests
swift test --filter DiagramViewBoundsLookupBindingTests
swift test --filter DiagramViewReviewRegressionTests
```

Expected: all green.

- [ ] **Step 2: Playground tests**

Run:

```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS' | tail -40
```

Expected: `** TEST SUCCEEDED **` with all of the new `PlaygroundPlaceholderTests`, `LiveEditorStateInspectorOpenTests`, `LiveEditorStoreEditorLifecycleTests`, `TapCoordinateConversionTests`, and `TapToSelectTests` reporting pass.

- [ ] **Step 3: Static gates**

Run:

```bash
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
```

Expected: all pass. If `Scripts/check-file-sizes.sh` flags `DiagramEditorPane.swift` over 500 lines, split out `InsertNodeSection` and `InsertEdgeSection` into a separate file `DiagramEditorPaneInsertSections.swift` and re-run.

- [ ] **Step 4: Linux check (optional)**

If Docker or Podman is running locally:

```bash
Scripts/linux-check.sh
```

Expected: pass. The `DiagramKitViews` change is already platform-gated, so Linux compilation is unaffected.

If Docker/Podman is unavailable, note this gate as "skipped due to environment" — per the `CLAUDE.md` policy this is not a source failure.

- [ ] **Step 5: Smoke check**

Run:

```bash
Scripts/bootstrap-smoke-check.sh
```

Expected: all-green.

### Task 29: Wrap up

**Files:** none modified

- [ ] **Step 1: Quick `git log` sanity check**

Run: `git log --oneline -30`

Confirm the commits land in a coherent sequence that tells the story of the feature, with each commit's tests/changes self-contained.

- [ ] **Step 2: Push or hand off**

If a remote workflow applies, push and open a PR. Otherwise the branch is ready for review.

---

## Notes on file size

`DiagramEditorPane.swift` is split into a single primary view + 6 private section structs in the same file by design — they all consume the same `store` and `editor` props, and grouping them avoids one-import-per-section noise. If the file approaches the 500-line warning during implementation, peel out `InsertNodeSection` and `InsertEdgeSection` into `DiagramEditorPaneInsertSections.swift` and re-run `Scripts/check-file-sizes.sh`.

## Notes on test target additions

The new `DiagramPlaygroundTests` target lives only on the macOS scheme. The iOS scheme stays test-free for now since the tests exercise pure model code that is identical on both platforms. If iOS-specific coverage becomes important, mirror the target on the iOS scheme later.
