# DiagramPlayground Accessibility Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add accessibility labels, hints, values, and identifiers to every interactive control across the DiagramPlayground chrome, gated by an XCUI `performAccessibilityAudit` test target that runs via `xcodebuild`.

**Architecture:** A new typed helper file (`View+Accessibility.swift`) exposes four ergonomic modifiers and a single `A11yID` constant namespace. Per-view changes apply those modifiers per the spec's category rules (A: visible-text buttons → identifier only; B: `Label(_,systemImage:)` → identifier only; C: icon-only stateless → label+id; D: stateful toggles → label+value+hint+id; E: decorative glyphs → `accessibilityHidden`). A new xcodegen UI test target (`DiagramPlaygroundUITests`) hosts an `XCUIApplication.performAccessibilityAudit` suite plus an `IdentifierPresenceTests` suite that asserts every `A11yID` resolves to a real control. Implementation is opt-in to CI via `Scripts/playground-a11y-check.sh`, mirroring the `linux-check.sh` policy.

**Tech Stack:** Swift 6, SwiftUI, XCTest, XCUIApplication, xcodegen, xcodebuild.

**Spec reference:** `docs/superpowers/specs/2026-05-15-playground-accessibility-pass-design.md` (approved 2026-05-15). Tasks below reference category rules A–E from the spec's "Labeling Specification" section.

---

## File Structure

**New files:**
- `Examples/DiagramPlayground/Views/Support/View+Accessibility.swift` — typed modifiers (`a11y`, `a11yToggle`, `a11yIdentifier`) and `A11yID` namespace
- `Examples/DiagramPlayground/UITests/XCTestCase+PlaygroundLaunch.swift` — `launchPlayground(initialState:)` helper
- `Examples/DiagramPlayground/UITests/SmokeTests.swift` — single test proving the UI-test harness boots
- `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift` — per-state assertions that every `A11yID` resolves
- `Examples/DiagramPlayground/UITests/AccessibilityAuditTests.swift` — one audit per screen state
- `Scripts/playground-a11y-check.sh` — wraps `xcodebuild test` invocation

**Modified files:**
- `Examples/DiagramPlayground/project.yml` — new `DiagramPlaygroundUITests` xcodegen target + scheme
- `Examples/DiagramPlayground/DiagramPlaygroundApp.swift` — `#if DEBUG` launch-arg seeding (~10 lines)
- `Examples/DiagramPlayground/Views/PreviewToolbar.swift`
- `Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift`
- `Examples/DiagramPlayground/Views/Editor/EditorModePicker.swift`
- `Examples/DiagramPlayground/Views/Editor/SourceFormatPicker.swift`
- `Examples/DiagramPlayground/Views/ThemePicker.swift`
- `Examples/DiagramPlayground/Views/Toolbar/SampleDiagramPanel.swift`
- `Examples/DiagramPlayground/Views/Toolbar/VersionSecurityPanel.swift`
- `Examples/DiagramPlayground/Views/Toolbar/ActionsPanel.swift`
- `Examples/DiagramPlayground/Views/PreviewCanvas.swift`
- `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`
- `CLAUDE.md` — Commands + Discipline Gates entries
- `REVIEW.md` — Session 16 closure entry

---

## Task 1: A11yID namespace + typed view modifiers

**Files:**
- Create: `Examples/DiagramPlayground/Views/Support/View+Accessibility.swift`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p Examples/DiagramPlayground/Views/Support
```

- [ ] **Step 2: Write the helper file**

```swift
//
//  View+Accessibility.swift
//  DiagramPlayground
//
//  Typed accessibility modifiers + identifier namespace shared by
//  the views and the UI-test target.
//

import SwiftUI

// MARK: - A11yID namespace

/// Stable identifiers for every audited control in the playground.
/// The UI test target's `IdentifierPresenceTests` and the view code
/// both reference these constants — renaming one without the other
/// surfaces as a test failure.
public enum A11yID {
    public enum Editor {
        public static let titleSet = "editor.title.set"
        public static let titleClear = "editor.title.clear"
        public static let titleClose = "editor.title.close"
        public static let selectionPicker = "editor.selection.picker"
        public static let labelRename = "editor.label.rename"
        public static let insertNodeButton = "editor.insertNode.button"
        public static let insertNodeShapePicker = "editor.insertNode.shape"
        public static let insertEdgeButton = "editor.insertEdge.button"
        public static let insertEdgeFromPicker = "editor.insertEdge.from"
        public static let insertEdgeToPicker = "editor.insertEdge.to"
        public static let insertEdgeSwap = "editor.insertEdge.swap"
        public static let deleteSelected = "editor.delete.selected"
        public static let undo = "editor.undo"
        public static let redo = "editor.redo"
    }

    public enum Toolbar {
        public static let theme = "toolbar.theme"
        public static let view = "toolbar.view"
        public static let actions = "toolbar.actions"
        public static let info = "toolbar.info"
        public static let inspectorToggle = "toolbar.inspector"
        public static let render = "toolbar.render"
        public static let updateMode = "toolbar.updateMode"
    }

    public enum Preview {
        public static let fit = "preview.fit"
        public static let zoomIn = "preview.zoomIn"
        public static let zoomOut = "preview.zoomOut"
        public static let actualSize = "preview.actualSize"
        public static let panZoomToggle = "preview.panZoomToggle"
        public static let gridToggle = "preview.gridToggle"
        public static let fullWindow = "preview.fullWindow"
        public static let modePicker = "preview.mode"
    }

    public enum Pickers {
        public static let sourceFormat = "picker.sourceFormat"
        public static let editorMode = "picker.editorMode"
        public static let themeMenu = "picker.themeMenu"
        public static let sampleSearch = "picker.sampleSearch"
        public static let sampleSearchClear = "picker.sampleSearchClear"
    }

    public enum Panels {
        public static let versionInfoDone = "panel.versionInfo.done"
        public static let actionsShareDone = "panel.actions.shareDone"
        public static let actionsHistoryDone = "panel.actions.historyDone"
        public static let themePickerDone = "panel.themePicker.done"
        public static let viewOptionsDone = "panel.viewOptions.done"
    }
}

// MARK: - View modifiers

public extension View {
    /// Stateless control (Category C): label is the action verb.
    /// Optional hint clarifies non-obvious actions.
    func a11y(
        label: LocalizedStringKey,
        hint: LocalizedStringKey? = nil,
        id: String
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityIdentifier(id)
    }

    /// Stateful toggle (Category D): label is the noun, value reflects
    /// state, optional hint clarifies what toggling does. Applies the
    /// `.isSelected` trait when on.
    func a11yToggle(
        label: LocalizedStringKey,
        isOn: Bool,
        hint: LocalizedStringKey? = nil,
        id: String
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(isOn ? "On" : "Off")
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier(id)
    }

    /// Categories A + B: SwiftUI already derives the label from the
    /// button title or `Label` text. We just need a stable identifier.
    func a11yIdentifier(_ id: String) -> some View {
        accessibilityIdentifier(id)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build --target DiagramPlayground 2>&1 | tail -5`
Expected: Build succeeds. The helper file has no callers yet but should compile cleanly.

- [ ] **Step 4: Commit**

```bash
git add Examples/DiagramPlayground/Views/Support/View+Accessibility.swift
git commit -m "$(cat <<'EOF'
feat(playground): a11y helper modifiers and A11yID namespace

Typed surface for the upcoming accessibility pass: a11y(label:hint:id:),
a11yToggle(label:isOn:hint:id:), a11yIdentifier(_:), plus an A11yID
namespace shared by views and the new UI-test target.
EOF
)"
```

---

## Task 2: Add DiagramPlaygroundUITests target to xcodegen project

**Files:**
- Modify: `Examples/DiagramPlayground/project.yml`

- [ ] **Step 1: Add the UI test target to project.yml**

Open `Examples/DiagramPlayground/project.yml`. After the `DiagramPlayground-iOS` target block (currently ending at line 89), and before the `schemes:` block (line 90), insert:

```yaml
  DiagramPlaygroundUITests:
    type: bundle.ui-testing
    platform: macOS
    deploymentTarget: "26.0"
    sources:
      - UITests
    dependencies:
      - target: DiagramPlayground
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.lukilabs.DiagramPlaygroundUITests
        TEST_TARGET_NAME: DiagramPlayground
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_VERSION: "6.0"
```

In the `schemes:` block (around line 90), inside the existing `DiagramPlayground:` scheme entry, replace:

```yaml
  DiagramPlayground:
    build:
      targets:
        DiagramPlayground: all
    run:
      config: Debug
    archive:
      config: Release
```

with:

```yaml
  DiagramPlayground:
    build:
      targets:
        DiagramPlayground: all
        DiagramPlaygroundUITests: test
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - DiagramPlaygroundUITests
    archive:
      config: Release
```

- [ ] **Step 2: Create the UITests directory placeholder**

```bash
mkdir -p Examples/DiagramPlayground/UITests
```

- [ ] **Step 3: Regenerate the Xcode project**

Run: `(cd Examples/DiagramPlayground && xcodegen generate)`
Expected output: `Loaded project ... Generated project successfully`.

If `xcodegen` is not installed, run `brew install xcodegen` first. Document the install dependency in the failing case.

- [ ] **Step 4: Verify the new target compiles (will be empty)**

Run:
```bash
xcodebuild -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests \
  build-for-testing 2>&1 | tail -20
```

Expected: build succeeds. Test phase will fail later (no tests yet) — that is fine for now.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/project.yml \
        Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
        Examples/DiagramPlayground/UITests
git commit -m "$(cat <<'EOF'
build(playground): add DiagramPlaygroundUITests xcodegen target

UI-test bundle that hosts against the macOS DiagramPlayground app.
Scheme's test action wires it in. iOS host destination is deferred
to a follow-up per spec non-goal #6.
EOF
)"
```

---

## Task 3: Launch-arg state seeding in DiagramPlaygroundApp

**Files:**
- Modify: `Examples/DiagramPlayground/DiagramPlaygroundApp.swift`

- [ ] **Step 1: Add the seeding helper and call it from `init()`**

Open `Examples/DiagramPlayground/DiagramPlaygroundApp.swift`. Replace the entire `init()` method (currently lines 21-23) and the existing `@SwiftUI.State private var store = LiveEditorStore()` line (line 19) with:

```swift
    @SwiftUI.State private var store = LiveEditorStore()

    init() {
        DiagramEngine.bootstrap()
        #if DEBUG
        Self.seedFromLaunchArgumentsIfNeeded(store: store)
        #endif
    }
```

Then, at the bottom of the `DiagramPlaygroundApp` struct (just before the final `}` that closes the struct), insert:

```swift
    #if DEBUG
    /// Reads the `-uitest-state <state-id>` launch argument and seeds
    /// the store accordingly. Used by the UI test target's
    /// `launchPlayground(initialState:)` helper. No-op when the arg is
    /// missing or unrecognized.
    @MainActor
    private static func seedFromLaunchArgumentsIfNeeded(store: LiveEditorStore) {
        let args = CommandLine.arguments
        guard let flagIdx = args.firstIndex(of: "-uitest-state"),
              flagIdx + 1 < args.count else { return }
        let stateID = args[flagIdx + 1]
        switch stateID {
        case "empty":
            store.setSource("", origin: .system)
        case "editing-flow-1":
            if let sample = TestDiagrams.all.first(where: { $0.id == "flow-1-simple" }),
               let src = sample.source(for: "mermaid") {
                store.setSource(src, origin: .system)
                store.openInspector()
            }
        case "selection-flow-1":
            if let sample = TestDiagrams.all.first(where: { $0.id == "flow-1-simple" }),
               let src = sample.source(for: "mermaid") {
                store.setSource(src, origin: .system)
                store.openInspector()
                // Selection itself is performed by the test via the
                // selection Picker — we just need the inspector open.
            }
        case "error-garbage":
            store.setSource("not a real diagram \n garbage", origin: .system)
        case "theme-open":
            // Empty source is fine — the test pops the Theme menu
            // directly via toolbar identifier.
            store.setSource("", origin: .system)
        default:
            break
        }
    }
    #endif
```

- [ ] **Step 2: Verify `LiveEditorStore.openInspector()` exists; add if missing**

Run: `grep -n 'func openInspector' Examples/DiagramPlayground/Models/LiveEditorStore.swift`

Expected: one match. If no match, add this method to `LiveEditorStore` right after the existing `toggleInspector` method (search for `func toggleInspector`):

```swift
    /// Force-opens the inspector regardless of prior state. Used by
    /// UI tests that need a deterministic starting state.
    public func openInspector() {
        state.inspectorOpen = true
    }
```

- [ ] **Step 3: Verify build**

Run: `swift build --target DiagramPlayground 2>&1 | tail -5`
Expected: Build succeeds.

- [ ] **Step 4: Smoke-test manually (optional, do not commit any state)**

Skip if running headless. To smoke-test locally:
```bash
swift run DiagramPlayground -uitest-state editing-flow-1 &
APP_PID=$!
sleep 3
kill $APP_PID
```
Expected: app launches with flow-1-simple already loaded and the inspector open.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/DiagramPlaygroundApp.swift \
        Examples/DiagramPlayground/Models/LiveEditorStore.swift
git commit -m "$(cat <<'EOF'
feat(playground): DEBUG launch-arg state seeding for UI tests

Adds `-uitest-state <id>` argument parsing under #if DEBUG. Recognized
state IDs: empty, editing-flow-1, selection-flow-1, error-garbage,
theme-open. Mirrors the contract the UI test target's
launchPlayground(initialState:) helper depends on.
EOF
)"
```

---

## Task 4: PlaygroundLaunch helper + smoke test

**Files:**
- Create: `Examples/DiagramPlayground/UITests/XCTestCase+PlaygroundLaunch.swift`
- Create: `Examples/DiagramPlayground/UITests/SmokeTests.swift`

- [ ] **Step 1: Write the launch helper**

Create `Examples/DiagramPlayground/UITests/XCTestCase+PlaygroundLaunch.swift`:

```swift
//
//  XCTestCase+PlaygroundLaunch.swift
//  DiagramPlaygroundUITests
//
//  Helper that launches the playground app with a chosen initial
//  state via the `-uitest-state` launch argument.
//

import XCTest

enum PlaygroundState: String {
    case empty
    case editingFlow1 = "editing-flow-1"
    case selectionFlow1 = "selection-flow-1"
    case errorGarbage = "error-garbage"
    case themeOpen = "theme-open"
}

extension XCTestCase {
    /// Launches the DiagramPlayground macOS app, seeding it into the
    /// requested initial state, and returns the running app. Waits up
    /// to 10 seconds for the main window to appear.
    @MainActor
    func launchPlayground(initialState: PlaygroundState) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-state", initialState.rawValue]
        app.launch()
        let appeared = app.windows.firstMatch.waitForExistence(timeout: 10)
        XCTAssertTrue(appeared, "Playground main window did not appear within 10 s")
        return app
    }
}
```

- [ ] **Step 2: Write the failing smoke test**

Create `Examples/DiagramPlayground/UITests/SmokeTests.swift`:

```swift
//
//  SmokeTests.swift
//  DiagramPlaygroundUITests
//
//  Proves the UI-test harness boots before any audit work lands.
//

import XCTest

final class SmokeTests: XCTestCase {
    @MainActor
    func testAppLaunchesEmptyState() {
        let app = launchPlayground(initialState: .empty)
        XCTAssertTrue(app.windows.firstMatch.exists, "Main window should exist")
    }
}
```

- [ ] **Step 3: Regenerate the project to pick up the new sources**

Run: `(cd Examples/DiagramPlayground && xcodegen generate)`
Expected: `Generated project successfully`.

- [ ] **Step 4: Run the smoke test**

Run:
```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/SmokeTests 2>&1 | tail -30
```

Expected: `Test Suite 'SmokeTests' passed`. If it fails with launch failures, the most common cause is the app target's `PRODUCT_BUNDLE_IDENTIFIER` not matching what Xcode discovered — re-run `xcodegen generate` and re-test.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/UITests \
        Examples/DiagramPlayground/DiagramPlayground.xcodeproj
git commit -m "$(cat <<'EOF'
test(playground): UI-test launch helper and smoke test

XCTestCase+PlaygroundLaunch wraps XCUIApplication with the
`-uitest-state <id>` launch-argument contract. SmokeTests proves
the harness boots end to end before the audit suites land.
EOF
)"
```

---

## Task 5: A11y modifiers on PreviewToolbar.swift

**Files:**
- Modify: `Examples/DiagramPlayground/Views/PreviewToolbar.swift`
- Modify: `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift` *(create on first reference)*

The spec's labeling categories apply as follows:

| Control | File:line | Category | Identifier |
|---|---|---|---|
| `fitButton` | `PreviewToolbar.swift:60-82` | A (visible text "Fit") | `A11yID.Preview.fit` |
| `zoomOutButton` | `:84-95` | C (icon-only stateless) | `A11yID.Preview.zoomOut` |
| `zoomInButton` | `:97-108` | C | `A11yID.Preview.zoomIn` |
| `actualSizeButton` | `:110-118` | A (visible text "1:1") | `A11yID.Preview.actualSize` |
| `panZoomToggleButton` | `:120-132` | D (stateful) | `A11yID.Preview.panZoomToggle` |
| `gridToggleButton` | `:134-146` | D | `A11yID.Preview.gridToggle` |
| `fullWindowButton` | `:148-155` | C | `A11yID.Preview.fullWindow` |

- [ ] **Step 1: Write the failing identifier-presence test (creating the test file)**

Create `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift`:

```swift
//
//  IdentifierPresenceTests.swift
//  DiagramPlaygroundUITests
//
//  Asserts every A11yID constant resolves to a real, hittable
//  control in the relevant screen state. Catches the silent-failure
//  mode where a modifier is removed and the audit suite doesn't
//  notice because the element no longer renders.
//

import XCTest

final class IdentifierPresenceTests: XCTestCase {

    // MARK: - Preview toolbar

    @MainActor
    func testPreviewToolbar_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "preview.fit",
            "preview.zoomOut",
            "preview.zoomIn",
            "preview.actualSize",
            "preview.panZoomToggle",
            "preview.gridToggle",
            "preview.fullWindow",
        ]
        for id in ids {
            let element = app.buttons[id]
            XCTAssertTrue(
                element.waitForExistence(timeout: 3),
                "Expected preview toolbar control with identifier '\(id)' to exist"
            )
        }
    }
}
```

- [ ] **Step 2: Regenerate project; verify test fails**

Run:
```bash
(cd Examples/DiagramPlayground && xcodegen generate)
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testPreviewToolbar_allIdentifiersPresent 2>&1 | tail -15
```

Expected: FAIL — `Expected preview toolbar control with identifier 'preview.fit' to exist`.

- [ ] **Step 3: Apply modifiers to PreviewToolbar.swift**

Open `Examples/DiagramPlayground/Views/PreviewToolbar.swift`.

For `fitButton` (line 60-82), append `.a11yIdentifier(A11yID.Preview.fit)` after the existing `.help("Fit diagram to view")` on line 81. Resulting tail:
```swift
        .help("Fit diagram to view")
        .a11yIdentifier(A11yID.Preview.fit)
    }
```

For `zoomOutButton` (line 84-95), replace `.help("Zoom out")` (line 94) with:
```swift
        .help("Zoom out")
        .a11y(label: "Zoom out", id: A11yID.Preview.zoomOut)
```

For `zoomInButton` (line 97-108), replace `.help("Zoom in")` (line 107) with:
```swift
        .help("Zoom in")
        .a11y(label: "Zoom in", id: A11yID.Preview.zoomIn)
```

For `actualSizeButton` (line 110-118), append after `.help("Actual size (100%)")`:
```swift
        .help("Actual size (100%)")
        .a11yIdentifier(A11yID.Preview.actualSize)
```

For `panZoomToggleButton` (line 120-132), replace `.help(panZoomEnabled ? "Disable pan and zoom" : "Enable pan and zoom")` (line 131) with:
```swift
        .help(panZoomEnabled ? "Disable pan and zoom" : "Enable pan and zoom")
        .a11yToggle(
            label: "Pan and zoom",
            isOn: panZoomEnabled,
            hint: "Allows dragging and pinch-to-zoom on the preview",
            id: A11yID.Preview.panZoomToggle
        )
```

For `gridToggleButton` (line 134-146), replace `.help(gridEnabled ? "Hide grid" : "Show grid")` (line 145) with:
```swift
        .help(gridEnabled ? "Hide grid" : "Show grid")
        .a11yToggle(
            label: "Grid overlay",
            isOn: gridEnabled,
            hint: "Shows a reference grid behind the diagram",
            id: A11yID.Preview.gridToggle
        )
```

For `fullWindowButton` (line 148-155), replace `.help("Full-window preview")` (line 154) with:
```swift
        .help("Full-window preview")
        .a11y(label: "Full-window preview", id: A11yID.Preview.fullWindow)
```

- [ ] **Step 4: Run the test; expect PASS**

Run the same xcodebuild command as Step 2.
Expected: `Test Suite 'IdentifierPresenceTests' passed`.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/Views/PreviewToolbar.swift \
        Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift \
        Examples/DiagramPlayground/DiagramPlayground.xcodeproj
git commit -m "$(cat <<'EOF'
feat(playground): a11y modifiers on PreviewToolbar

Seven controls: fit / zoom-out / zoom-in / actual-size /
pan-zoom toggle / grid toggle / full-window. New
IdentifierPresenceTests case pins all seven identifiers.
EOF
)"
```

---

## Task 6: A11y modifiers on LiveEditorToolbar.swift (macOS + iOS arms)

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift`
- Modify: `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift`

| Control | File:line | Category | Identifier |
|---|---|---|---|
| Theme button (macOS) | `LiveEditorToolbar.swift:47-57` | B (Label) | `A11yID.Toolbar.theme` |
| View button (macOS) | `:60-70` | B | `A11yID.Toolbar.view` |
| Actions button (macOS) | `:73-82` | B | `A11yID.Toolbar.actions` |
| Info button (macOS) | `:85-94` | B | `A11yID.Toolbar.info` |
| Inspector toggle (macOS) | `:97-106` | D | `A11yID.Toolbar.inspectorToggle` |
| Render button (macOS) | `:111-123` | A (visible text "Render") | `A11yID.Toolbar.render` |
| Theme button (iOS) | `:152-156` | C | `A11yID.Toolbar.theme` |
| View button (iOS) | `:159-163` | C | `A11yID.Toolbar.view` |
| Actions button (iOS) | `:166-170` | C | `A11yID.Toolbar.actions` |
| Info button (iOS) | `:173-177` | C | `A11yID.Toolbar.info` |
| Inspector toggle (iOS) | `:180-187` | D | `A11yID.Toolbar.inspectorToggle` |
| `UpdateModePicker` | `:261-277` *(in UpdateModePicker struct)* | Picker (label arg) | `A11yID.Toolbar.updateMode` |
| Theme done (macOS sheet) | `:199-201` | A | `A11yID.Panels.themePickerDone` |
| View done | `:214-216` | A | `A11yID.Panels.viewOptionsDone` |
| Actions done | `:228-230` | A | `A11yID.Panels.actionsShareDone` |
| Info done | `:241-243` | A | `A11yID.Panels.versionInfoDone` |

- [ ] **Step 1: Extend IdentifierPresenceTests with the toolbar case**

Append to `IdentifierPresenceTests.swift`:

```swift
    @MainActor
    func testToolbar_macOS_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "toolbar.theme",
            "toolbar.view",
            "toolbar.actions",
            "toolbar.info",
            "toolbar.inspector",
            "toolbar.updateMode",
        ]
        for id in ids {
            let candidate = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                candidate.waitForExistence(timeout: 3),
                "Expected toolbar control with identifier '\(id)' to exist"
            )
        }
    }
```

The `descendants(matching: .any)` query is needed because some toolbar items resolve as `.toolbar`, others as `.button`, others as `.picker` depending on placement.

- [ ] **Step 2: Run; expect FAIL**

Run:
```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testToolbar_macOS_allIdentifiersPresent 2>&1 | tail -15
```

Expected: FAIL — first missing identifier listed.

- [ ] **Step 3: Apply modifiers — macOS arm**

In the macOS `#if os(macOS)` block (lines 17-126), append the indicated modifier after the existing `.help(...)` on each button:

```swift
            // Theme button (line 47-57)
            ...
            .help("Theme")
            .a11yIdentifier(A11yID.Toolbar.theme)

            // View button (line 60-70)
            ...
            .help("View options")
            .a11yIdentifier(A11yID.Toolbar.view)

            // Actions button (line 73-82)
            ...
            .help("Export, copy, and share")
            .a11yIdentifier(A11yID.Toolbar.actions)

            // Info button (line 85-94)
            ...
            .help("Version and security information")
            .a11yIdentifier(A11yID.Toolbar.info)

            // Inspector toggle (line 97-106) — replace existing
            // `.help("Inspector (⌘I)")` line so the toggle modifier
            // applies cleanly:
            .help("Inspector (⌘I)")
            .a11yToggle(
                label: "Inspector",
                isOn: store.state.inspectorOpen,
                hint: "Shows the editing controls panel",
                id: A11yID.Toolbar.inspectorToggle
            )
            .keyboardShortcut("i", modifiers: [.command])
```

For the `renderButton` (line 111-123), append after `.help("Render the current diagram")`:
```swift
        .help("Render the current diagram")
        .a11yIdentifier(A11yID.Toolbar.render)
```

For the four sheet "Done" buttons (lines 200, 215, 229, 242), append `.a11yIdentifier(...)` per the table:
```swift
                            Button("Done") { showingTheme = false }
                                .a11yIdentifier(A11yID.Panels.themePickerDone)
                            ...
                            Button("Done") { showingView = false }
                                .a11yIdentifier(A11yID.Panels.viewOptionsDone)
                            ...
                            Button("Done") { showingActions = false }
                                .a11yIdentifier(A11yID.Panels.actionsShareDone)
                            ...
                            Button("Done") { showingVersionInfo = false }
                                .a11yIdentifier(A11yID.Panels.versionInfoDone)
```

- [ ] **Step 4: Apply modifiers — iOS arm**

In the iOS `#if os(iOS)` block (lines 130-188), append per-button:

```swift
            // Theme button (line 152-156)
            Button { showingTheme = true } label: {
                Image(systemName: "paintpalette")
            }
            .a11y(label: "Theme", id: A11yID.Toolbar.theme)

            // View button (line 159-163)
            Button { showingView = true } label: {
                Image(systemName: "eye")
            }
            .a11y(label: "View options", id: A11yID.Toolbar.view)

            // Actions button (line 166-170)
            Button { showingActions = true } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .a11y(label: "Actions", hint: "Export, copy, share, history", id: A11yID.Toolbar.actions)

            // Info button (line 173-177)
            Button { showingVersionInfo = true } label: {
                Image(systemName: "info.circle")
            }
            .a11y(label: "Version and security info", id: A11yID.Toolbar.info)

            // Inspector toggle (line 180-187)
            Button { store.toggleInspector() } label: {
                Image(systemName: store.state.inspectorOpen
                    ? "slider.horizontal.below.rectangle.fill"
                    : "slider.horizontal.below.rectangle")
            }
            .a11yToggle(
                label: "Inspector",
                isOn: store.state.inspectorOpen,
                hint: "Shows the editing controls panel",
                id: A11yID.Toolbar.inspectorToggle
            )
            .keyboardShortcut("i", modifiers: [.command])
```

- [ ] **Step 5: Apply identifier to UpdateModePicker**

Find `UpdateModePicker` in the same file (around line 248-280). On the `Picker("Update Mode", selection: $updateMode) { … }` block, append `.a11yIdentifier(A11yID.Toolbar.updateMode)` after the closing `}` of the picker content.

- [ ] **Step 6: Run; expect PASS**

Run the same xcodebuild command as Step 2. Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Examples/DiagramPlayground/Views/Toolbar/LiveEditorToolbar.swift \
        Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift
git commit -m "$(cat <<'EOF'
feat(playground): a11y modifiers on LiveEditorToolbar (macOS + iOS)

Theme / View / Actions / Info / Inspector / Render / UpdateMode plus
the four sheet "Done" buttons. macOS arm uses identifier-only
(Label provides the a11y label); iOS arm uses explicit a11y(...)
because the buttons are bare Image(systemName:). Inspector is
a11yToggle in both arms.
EOF
)"
```

---

## Task 7: A11y modifiers on the three small pickers

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/EditorModePicker.swift`
- Modify: `Examples/DiagramPlayground/Views/Editor/SourceFormatPicker.swift`
- Modify: `Examples/DiagramPlayground/Views/ThemePicker.swift`
- Modify: `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift`

| Control | File | Category | Identifier |
|---|---|---|---|
| `EditorModePicker` segmented control | `EditorModePicker.swift` | Picker (label arg) | `A11yID.Pickers.editorMode` |
| `SourceFormatPicker` Menu button | `SourceFormatPicker.swift:36` | C (icon + chevron) | `A11yID.Pickers.sourceFormat` |
| `QuickThemeButton` rows | `ThemePicker.swift:26-50` | A (text-bearing buttons) | Not audited individually — Theme menu is the parent |
| Theme expand button | `ThemePicker.swift:56-65` | C | `A11yID.Pickers.themeMenu` |

- [ ] **Step 1: Inspect the three files to confirm exact lines**

Run: `grep -n 'Picker\|Menu\|Button\|Image(systemName' Examples/DiagramPlayground/Views/Editor/EditorModePicker.swift Examples/DiagramPlayground/Views/Editor/SourceFormatPicker.swift Examples/DiagramPlayground/Views/ThemePicker.swift`

This refreshes the line numbers before applying modifiers; SwiftUI file structure here is small and stable, but verify the line numbers in the table above haven't drifted.

- [ ] **Step 2: Extend IdentifierPresenceTests**

Append to `IdentifierPresenceTests.swift`:

```swift
    @MainActor
    func testSmallPickers_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let ids = [
            "picker.editorMode",
            "picker.sourceFormat",
            "picker.themeMenu",
        ]
        for id in ids {
            let candidate = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                candidate.waitForExistence(timeout: 3),
                "Expected picker with identifier '\(id)' to exist"
            )
        }
    }
```

- [ ] **Step 3: Run; expect FAIL**

```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testSmallPickers_allIdentifiersPresent 2>&1 | tail -10
```

- [ ] **Step 4: Apply modifiers**

In `EditorModePicker.swift`, find the inner `Picker(...)` and append `.a11yIdentifier(A11yID.Pickers.editorMode)`.

In `SourceFormatPicker.swift`, find the `Menu { ... } label: { ... }` block around line 36 and append `.a11y(label: "Source format", id: A11yID.Pickers.sourceFormat)` to the outer `Menu`.

In `ThemePicker.swift`, find the expand button (around line 56-65) and append:
```swift
.a11y(label: "All themes", hint: "Opens the full theme list", id: A11yID.Pickers.themeMenu)
```
For the inner checkmark `Image(systemName: "checkmark")` (line 49), append `.accessibilityHidden(true)` — it's category E (decorative). `QuickThemeButton` rows are text-bearing buttons (their label is the theme name) so SwiftUI's auto-derivation is sufficient; do not add row-level identifiers — the convention is that every identifier comes from `A11yID`, and dynamic per-theme constants would break that.

- [ ] **Step 5: Run; expect PASS**

Same xcodebuild command. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/EditorModePicker.swift \
        Examples/DiagramPlayground/Views/Editor/SourceFormatPicker.swift \
        Examples/DiagramPlayground/Views/ThemePicker.swift \
        Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift
git commit -m "$(cat <<'EOF'
feat(playground): a11y modifiers on small pickers

EditorModePicker / SourceFormatPicker / ThemePicker. Decorative
checkmark glyphs hidden; outer controls carry identifiers and
labels where icon-only.
EOF
)"
```

---

## Task 8: A11y modifiers on SampleDiagramPanel, VersionSecurityPanel, ActionsPanel

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Toolbar/SampleDiagramPanel.swift`
- Modify: `Examples/DiagramPlayground/Views/Toolbar/VersionSecurityPanel.swift`
- Modify: `Examples/DiagramPlayground/Views/Toolbar/ActionsPanel.swift`
- Modify: `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift`

| Control | File:line | Category | Identifier |
|---|---|---|---|
| Search field (TextField) | `SampleDiagramPanel.swift:60` | TextField (uses prompt as label) | `A11yID.Pickers.sampleSearch` |
| Search clear (xmark) | `:68-69` | C | `A11yID.Pickers.sampleSearchClear` |
| `magnifyingglass` glyphs | `:56, :303` | E (decorative) | hidden |
| Category disclosure (`:108`) | C (state) | D | not audited individually |
| Sample-row checkmark (`:164`) | E (decorative) | hidden | — |
| Badge icons (`:198`) | E (decorative) | hidden | — |
| `chart.bar.doc.horizontal` header (`VersionSecurityPanel.swift:31`) | E | hidden | — |
| `lock.shield` header (`:120`) | E | hidden | — |
| `link` (`:208`) | E (decorative — adjacent text) | hidden | — |
| `arrow.up.right` (`:219, :229`) | E | hidden | — |
| Done button (`:184`) | A | already covered by `A11yID.Panels.versionInfoDone` in Task 6 | — |
| OK button (`ActionsPanel.swift:48`) | A | none — generic alert dismiss, identifier optional | — |
| Done buttons (`:76, :94`) | A | `actionsShareDone` / `actionsHistoryDone` | covered in Task 6's identifiers; apply here |

- [ ] **Step 1: Extend IdentifierPresenceTests**

Append:

```swift
    @MainActor
    func testSamplePanel_searchControlsPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        // Open the sidebar/sample panel — the sample search field is
        // in the leading sidebar, always visible.
        let search = app.descendants(matching: .any).matching(identifier: "picker.sampleSearch").firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3), "Sample search field missing")
        // Type a query then expect the clear button to surface.
        search.click()
        search.typeText("flow")
        let clear = app.descendants(matching: .any).matching(identifier: "picker.sampleSearchClear").firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 3), "Sample search clear button missing")
    }
```

- [ ] **Step 2: Run; expect FAIL**

```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testSamplePanel_searchControlsPresent 2>&1 | tail -10
```

- [ ] **Step 3: Apply modifiers**

In `SampleDiagramPanel.swift`:

For the `TextField("Search samples...", text: $searchText)` at line 60, append `.a11yIdentifier(A11yID.Pickers.sampleSearch)` after the existing `.textFieldStyle(...)`.

For the clear button containing `Image(systemName: "xmark.circle.fill")` at line 69, append `.a11y(label: "Clear search", id: A11yID.Pickers.sampleSearchClear)` to the parent `Button`.

For the `Image(systemName: "magnifyingglass")` at lines 56 and 303, append `.accessibilityHidden(true)`.

For the category disclosure `Image(systemName: ...)` at line 108, append `.accessibilityHidden(true)` — the row's enclosing `Button` already exposes a label via its text content.

For the sample-row `Image(systemName: "checkmark")` at line 164, append `.accessibilityHidden(true)`.

For the `Image(systemName: badge.systemImage)` at line 198, append `.accessibilityHidden(true)` — the badge text alongside conveys meaning.

In `VersionSecurityPanel.swift`:

For all `Image(systemName: ...)` glyphs at lines 31, 86 (parameterized icon helper), 120, 208, 219, 229 — append `.accessibilityHidden(true)`. These all sit next to text labels.

For the `Button("Done") { ... }` at line 184, append `.a11yIdentifier(A11yID.Panels.versionInfoDone)`.

In `ActionsPanel.swift`:

For `Button("Done") { showingShareSheet = false }` at line 76, append `.a11yIdentifier(A11yID.Panels.actionsShareDone)`.
For `Button("Done") { showingHistory = false }` at line 94, append `.a11yIdentifier(A11yID.Panels.actionsHistoryDone)`.
The `Button("OK", role: .cancel)` at line 48 is a generic alert dismiss — leave unmodified (SwiftUI handles standard alert a11y).

- [ ] **Step 4: Run; expect PASS**

Same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/Views/Toolbar/SampleDiagramPanel.swift \
        Examples/DiagramPlayground/Views/Toolbar/VersionSecurityPanel.swift \
        Examples/DiagramPlayground/Views/Toolbar/ActionsPanel.swift \
        Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift
git commit -m "$(cat <<'EOF'
feat(playground): a11y modifiers on sample/version/actions panels

Sample search field + clear; decorative magnifying-glass, checkmark,
badge, header-icon glyphs hidden across panels; Done buttons carry
panel identifiers.
EOF
)"
```

---

## Task 9: A11y modifiers on PreviewCanvas.swift

**Files:**
- Modify: `Examples/DiagramPlayground/Views/PreviewCanvas.swift`
- Modify: `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift`

| Control | File:line | Category | Identifier |
|---|---|---|---|
| Mode picker button (`Image(systemName: mode.iconName)`) | `PreviewCanvas.swift:148-155` | D (state) | `A11yID.Preview.modePicker` |
| Warning glyphs (`:444, :473`) | E | hidden | — |
| `doc.text` empty-state (`:495`) | E | hidden | — |
| `minus.circle` errored-state | `:521` | E | hidden | — |
| `exclamationmark.bubble` | `:532` | E | hidden | — |
| `text.badge.xmark` | `:550` | E | hidden | — |

- [ ] **Step 1: Extend IdentifierPresenceTests**

Append:

```swift
    @MainActor
    func testPreviewCanvas_modePickerPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        let picker = app.descendants(matching: .any).matching(identifier: "preview.mode").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "Preview mode picker missing")
    }
```

- [ ] **Step 2: Run; expect FAIL**

```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testPreviewCanvas_modePickerPresent 2>&1 | tail -10
```

- [ ] **Step 3: Apply modifiers**

For the mode-picker button containing `Image(systemName: mode.iconName)` (lines 148-155), append to the `Button`:

```swift
.a11y(
    label: "Preview mode",
    hint: "Switches between SVG, image, and ASCII preview",
    id: A11yID.Preview.modePicker
)
```

For all decorative `Image(systemName: ...)` at lines 444, 473, 495, 521, 532, 550, append `.accessibilityHidden(true)`.

- [ ] **Step 4: Run; expect PASS**

Same command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/Views/PreviewCanvas.swift \
        Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift
git commit -m "$(cat <<'EOF'
feat(playground): a11y modifiers on PreviewCanvas

Preview-mode picker labeled as stateful control; warning / empty-state
/ errored-state decorative glyphs hidden from VoiceOver since the
adjacent text already conveys the meaning.
EOF
)"
```

---

## Task 10: A11y modifiers on DiagramEditorPane.swift

**Files:**
- Modify: `Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`
- Modify: `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift`

| Control | File:line | Category | Identifier |
|---|---|---|---|
| Close section button (xmark) | `DiagramEditorPane.swift:43-49` | C | `A11yID.Editor.titleClose` |
| Section-label icon `Image(systemName: icon)` (disabledBanner) | `:112-114` | E | hidden |
| Title "Set" | `:141-144` | A | `A11yID.Editor.titleSet` |
| Title "Clear" | `:145-148` | A | `A11yID.Editor.titleClear` |
| Selection Picker | `:183-196` | Picker (label arg) | `A11yID.Editor.selectionPicker` |
| Label "Rename" | `:252-254` | A | `A11yID.Editor.labelRename` |
| Insert-node shape Picker | `:308` | Picker | `A11yID.Editor.insertNodeShapePicker` |
| Insert-node "Insert" | `:317` | A | `A11yID.Editor.insertNodeButton` |
| Insert-edge `arrow.right` decorative | `:367` | C (swap action) | `A11yID.Editor.insertEdgeSwap` |
| Insert-edge "Insert" | `:380` | A | `A11yID.Editor.insertEdgeButton` |
| Insert-edge From Picker | `:391` | Picker | `A11yID.Editor.insertEdgeFromPicker` |
| Insert-edge To Picker | `:402` | Picker | `A11yID.Editor.insertEdgeToPicker` |
| Delete selected button | `:466-468` | A | `A11yID.Editor.deleteSelected` |
| Undo button | `:485-490` | D (label + dynamic value) | `A11yID.Editor.undo` |
| Redo button | `:492-497` | D | `A11yID.Editor.redo` |
| Error-bubble decorative icons | `:521, :532` | E | hidden |

Decision on `arrow.right` at line 367: if it's currently a static decoration (not a tappable swap), hide it. If it's a tappable swap-direction button, apply category C with the `insertEdgeSwap` identifier. Verify by inspecting the surrounding closure structure in Step 3.

- [ ] **Step 1: Extend IdentifierPresenceTests with editor-pane coverage**

Append:

```swift
    @MainActor
    func testEditorPane_allIdentifiersPresent() {
        let app = launchPlayground(initialState: .editingFlow1)
        // Inspector should already be open via `editing-flow-1` state.
        let ids = [
            "editor.title.set",
            "editor.title.clear",
            "editor.title.close",
            "editor.selection.picker",
            "editor.label.rename",
            "editor.insertNode.button",
            "editor.insertNode.shape",
            "editor.insertEdge.button",
            "editor.insertEdge.from",
            "editor.insertEdge.to",
            "editor.delete.selected",
            "editor.undo",
            "editor.redo",
        ]
        for id in ids {
            let candidate = app.descendants(matching: .any).matching(identifier: id).firstMatch
            XCTAssertTrue(
                candidate.waitForExistence(timeout: 3),
                "Expected editor-pane control with identifier '\(id)' to exist"
            )
        }
    }
```

`editor.insertEdge.swap` is omitted from the assertions in case the `arrow.right` glyph turns out to be decorative — adjust after Step 3 inspection.

- [ ] **Step 2: Run; expect FAIL**

```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/IdentifierPresenceTests/testEditorPane_allIdentifiersPresent 2>&1 | tail -10
```

- [ ] **Step 3: Inspect insert-edge `arrow.right` to decide swap vs decorative**

Run: `sed -n '360,395p' Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift`

- If the `Image(systemName: "arrow.right")` sits inside a `Button { ... } label: { ... }`, it is the swap-direction button → apply category C: `.a11y(label: "Swap from and to", id: A11yID.Editor.insertEdgeSwap)` on the `Button`. Append `"editor.insertEdge.swap"` to the assertion list.
- If it's a bare static `Image`, append `.accessibilityHidden(true)`. Drop `insertEdgeSwap` from the spec/IDs entirely.

- [ ] **Step 4: Apply modifiers**

Apply each modifier per the table:

```swift
            // Close section (line 43-49)
            Button { store.toggleInspector() } label: {
                Image(systemName: "xmark") ...
            }
            .buttonStyle(.plain)
            .a11y(label: "Close inspector", id: A11yID.Editor.titleClose)

            // Title Set (line 141-144)
            Button("Set") { ... }
                .disabled(editor.isExporting)
                .a11yIdentifier(A11yID.Editor.titleSet)

            // Title Clear (line 145-148)
            Button("Clear") { ... }
                .disabled(editor.isExporting || editor.document.title == nil)
                .a11yIdentifier(A11yID.Editor.titleClear)

            // Selection Picker (line 183-196)
            Picker("Selected element", selection: pickerBinding(lookup: lookup)) { ... }
                .pickerStyle(.menu)
                .labelsHidden()
                .a11yIdentifier(A11yID.Editor.selectionPicker)

            // Label Rename (line 252)
            Button("Rename") { ... }
                .a11yIdentifier(A11yID.Editor.labelRename)

            // Insert-node shape Picker (line 308)
            Picker("Shape", selection: $shape) { ... }
                .a11yIdentifier(A11yID.Editor.insertNodeShapePicker)

            // Insert-node Insert (line 317)
            Button("Insert") { ... }
                .a11yIdentifier(A11yID.Editor.insertNodeButton)

            // Insert-edge Insert (line 380)
            Button("Insert") { ... }
                .a11yIdentifier(A11yID.Editor.insertEdgeButton)

            // Insert-edge From Picker (line 391)
            Picker("From", selection: $fromID) { ... }
                .a11yIdentifier(A11yID.Editor.insertEdgeFromPicker)

            // Insert-edge To Picker (line 402)
            Picker("To", selection: $toID) { ... }
                .a11yIdentifier(A11yID.Editor.insertEdgeToPicker)

            // Delete (line 466)
            Button("Delete selected", role: .destructive) { ... }
                .a11yIdentifier(A11yID.Editor.deleteSelected)

            // Undo (line 485-490)
            Button { editor.undoManager.undo() } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .disabled(!editor.canUndo)
            .a11yToggle(
                label: "Undo",
                isOn: editor.canUndo,
                hint: editor.undoActionName ?? "",
                id: A11yID.Editor.undo
            )

            // Redo (line 492-497)
            Button { editor.undoManager.redo() } label: {
                Label("Redo", systemImage: "arrow.uturn.forward")
            }
            .disabled(!editor.canRedo)
            .a11yToggle(
                label: "Redo",
                isOn: editor.canRedo,
                hint: editor.redoActionName ?? "",
                id: A11yID.Editor.redo
            )
```

For the `Image(systemName: icon)` at line 112 inside `disabledBanner`, append `.accessibilityHidden(true)`.

For the error-bubble decorative icons at lines 521, 532, append `.accessibilityHidden(true)`.

For the `arrow.right` at line 367 — apply the decision made in Step 3.

- [ ] **Step 5: Run; expect PASS**

Same command. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Examples/DiagramPlayground/Views/Editor/DiagramEditorPane.swift \
        Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift
git commit -m "$(cat <<'EOF'
feat(playground): a11y modifiers on DiagramEditorPane

Thirteen-plus controls across title / selection / label / insert-node
/ insert-edge / delete / undo / redo sections. Undo and Redo use
a11yToggle with the dynamic undoActionName / redoActionName as the
accessibility hint (mirrors macOS Edit-menu pattern).
EOF
)"
```

---

## Task 11: AccessibilityAuditTests across five screen states

**Files:**
- Create: `Examples/DiagramPlayground/UITests/AccessibilityAuditTests.swift`

The five states (per spec): empty / editing / selection / error / theme-open.

- [ ] **Step 1: Write the audit test suite**

Create `Examples/DiagramPlayground/UITests/AccessibilityAuditTests.swift`:

```swift
//
//  AccessibilityAuditTests.swift
//  DiagramPlaygroundUITests
//
//  Drives XCUIApplication.performAccessibilityAudit across each
//  major screen state. Audit issue types include missing labels,
//  duplicate labels, hit-target size, contrast, dynamic-type
//  clipping, and trait coherence.
//

import XCTest

@available(macOS 14.0, *)
final class AccessibilityAuditTests: XCTestCase {

    @MainActor
    func testEmptyState() throws {
        let app = launchPlayground(initialState: .empty)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testEditingState() throws {
        let app = launchPlayground(initialState: .editingFlow1)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testSelectionState() throws {
        let app = launchPlayground(initialState: .selectionFlow1)
        // Select a node via the selection picker to exercise selection
        // / rename / delete controls.
        let picker = app.descendants(matching: .any).matching(identifier: "editor.selection.picker").firstMatch
        if picker.waitForExistence(timeout: 3) {
            picker.click()
            // First non-"None" item in the menu. SwiftUI menu rendering
            // varies; tolerate the absence by skipping selection if the
            // menu items don't surface as tappable.
            let firstNode = app.menuItems.element(boundBy: 1)
            if firstNode.waitForExistence(timeout: 2) {
                firstNode.click()
            }
        }
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testErrorState() throws {
        let app = launchPlayground(initialState: .errorGarbage)
        try app.performAccessibilityAudit()
    }

    @MainActor
    func testThemePickerOpenState() throws {
        let app = launchPlayground(initialState: .themeOpen)
        // Click the toolbar Theme button to surface the picker.
        let theme = app.descendants(matching: .any).matching(identifier: "toolbar.theme").firstMatch
        XCTAssertTrue(theme.waitForExistence(timeout: 3))
        theme.click()
        try app.performAccessibilityAudit()
    }
}
```

`performAccessibilityAudit()` with no `for:` argument defaults to the full audit set. Per-test opt-outs (if any prove infeasible to fix) take this shape:

```swift
try app.performAccessibilityAudit(for: .all) { issue in
    // Return `true` to ignore the issue. Document why inline.
    if issue.auditType == .contrast,
       issue.element?.identifier == "preview.fit" {
        return true // SwiftUI Material background contrast — known limitation
    }
    return false
}
```

Do not add suppressions speculatively; add only when the first run surfaces a concrete issue that cannot be fixed in scope.

- [ ] **Step 2: Regenerate project**

Run: `(cd Examples/DiagramPlayground && xcodegen generate)`

- [ ] **Step 3: Run the audit suite**

```bash
xcodebuild test \
  -project Examples/DiagramPlayground/DiagramPlayground.xcodeproj \
  -scheme DiagramPlayground \
  -destination 'platform=macOS,arch=arm64' \
  -only-testing:DiagramPlaygroundUITests/AccessibilityAuditTests 2>&1 | tee /tmp/a11y-audit.log | tail -60
```

Expected outcomes:
- **Best case:** All five tests pass. Move to Step 5.
- **Likely case:** A subset fails with XCTAccessibilityAuditIssue findings. For each failing issue, inspect the message:
  - **Missing label / duplicate label / unknown trait:** fix the offending modifier in the relevant view file. Commit fixes as `fix(playground): <description>` alongside the failing-state name. Re-run the audit.
  - **Contrast / hit-target / dynamic-type:** Per the spec, these may be opt-out candidates. Add a documented suppression in the test using the closure form above. Push back if any fix is genuinely in-scope (the spec's non-goal #3 covers dynamic-type only; contrast is in-scope and should be fixed when feasible).
- **Pathological case:** The audit infrastructure itself is misconfigured (test target fails to launch the app). Re-verify Task 4's smoke test still passes.

Repeat Step 3 until all five tests pass.

- [ ] **Step 4: Optional inspection — review the audit log if needed**

If you suppressed any issues in Step 3, scan `/tmp/a11y-audit.log` once more for any audit findings that were not investigated.

- [ ] **Step 5: Commit**

```bash
git add Examples/DiagramPlayground/UITests/AccessibilityAuditTests.swift \
        Examples/DiagramPlayground/DiagramPlayground.xcodeproj
git commit -m "$(cat <<'EOF'
test(playground): XCUI accessibility audit across five screen states

Empty / editing-flow-1 / selection-flow-1 / error-garbage /
theme-open. performAccessibilityAudit() with default issue-type
set. Any in-line suppressions are documented at the call site.
EOF
)"
```

(If Step 3 required additional commits to fix audit findings, those would have been committed already as `fix(playground): ...` commits before this one.)

---

## Task 12: Scripts/playground-a11y-check.sh

**Files:**
- Create: `Scripts/playground-a11y-check.sh`

- [ ] **Step 1: Write the script**

Create `Scripts/playground-a11y-check.sh`:

```bash
#!/usr/bin/env bash
#
# Scripts/playground-a11y-check.sh
#
# Opt-in CI lane for the DiagramPlayground accessibility audit.
# Mirrors the policy of Scripts/linux-check.sh: not invoked by
# bootstrap-smoke-check, run separately when needed.
#
# Usage:
#   Scripts/playground-a11y-check.sh
#
# Requires xcodegen (brew install xcodegen) and Xcode 15+.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/Examples/DiagramPlayground"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "✗ xcodegen not installed (brew install xcodegen)" >&2
    exit 2
fi

xcodegen generate >/dev/null

echo "▶ Running playground accessibility audit + identifier-presence tests…"
xcodebuild test \
    -project DiagramPlayground.xcodeproj \
    -scheme DiagramPlayground \
    -destination 'platform=macOS,arch=arm64' \
    -only-testing:DiagramPlaygroundUITests \
    -quiet

echo "✓ Playground accessibility audit passed"
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x Scripts/playground-a11y-check.sh`

- [ ] **Step 3: Execute it end-to-end**

Run: `Scripts/playground-a11y-check.sh`

Expected: a few minutes of xcodebuild output, ending with `✓ Playground accessibility audit passed`. If anything fails, investigate before committing.

- [ ] **Step 4: Commit**

```bash
git add Scripts/playground-a11y-check.sh
git commit -m "$(cat <<'EOF'
ci(playground): opt-in accessibility audit script

Scripts/playground-a11y-check.sh wraps the xcodebuild test invocation
that runs both AccessibilityAuditTests and IdentifierPresenceTests
under the DiagramPlaygroundUITests target. Opt-in per spec
(non-goal: not wired into bootstrap-smoke-check.sh; mirrors
linux-check.sh's policy).
EOF
)"
```

---

## Task 13: CLAUDE.md + REVIEW.md documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `REVIEW.md`

- [ ] **Step 1: Update CLAUDE.md Commands section**

In `CLAUDE.md`, find the `## Commands` section (search `grep -n '^## Commands' CLAUDE.md`). After the existing command block, before the blank line that precedes `## Target Layout`, add:

```markdown

# Playground accessibility audit (opt-in, requires Xcode + xcodegen):
Scripts/playground-a11y-check.sh
```

If the existing command block uses a different fence (a single ```bash block, etc.), insert the comment + command inside that block instead.

- [ ] **Step 2: Update CLAUDE.md Discipline Gates section**

In `CLAUDE.md`, find the `## Discipline Gates` section. After the existing `- Scripts/linux-check.sh - …` bullet, add:

```markdown
- `Scripts/playground-a11y-check.sh` - opt-in XCUI accessibility audit of the playground demo app. Runs `DiagramPlaygroundUITests` via `xcodebuild test`. Not part of `bootstrap-smoke-check.sh`; same policy as `linux-check.sh` (environment-dependent, slow).
```

- [ ] **Step 3: Update CLAUDE.md test source count**

Run: `find Tests Examples/DiagramPlayground/UITests -name '*.swift' | wc -l`

Update the test-source-count sentence in the `## Testing And Snapshots` section to match. As of writing the plan the count was 260; this pass adds 4 UI test files (`XCTestCase+PlaygroundLaunch.swift`, `SmokeTests.swift`, `IdentifierPresenceTests.swift`, `AccessibilityAuditTests.swift`) → new count is 264. The "What Lives Where" section mentions the test targets; append a one-line entry for `Examples/DiagramPlayground/UITests/`:

```markdown
- `Examples/DiagramPlayground/UITests/` - macOS-only XCUI test bundle (`DiagramPlaygroundUITests`) that runs `performAccessibilityAudit` across five screen states and pins per-control identifiers. Invoked via `Scripts/playground-a11y-check.sh`.
```

- [ ] **Step 4: Add REVIEW.md Session 16 entry**

In `REVIEW.md`, find the most recent `## Resolution Status — Session 15` block. Above the `## Deferred Effort — Recommendations` header (search `grep -n '^## Deferred Effort' REVIEW.md`), insert a new section:

```markdown
## Resolution Status — Session 16 (2026-05-15)

Closes the §5 Minor / polish bullet: "Accessibility labels missing across `DiagramEditorPane` insert/delete/undo controls — for a demo app, this is a missed showcase." Spec at `docs/superpowers/specs/2026-05-15-playground-accessibility-pass-design.md`; plan at `docs/superpowers/plans/2026-05-15-playground-accessibility-pass.md`. Thirteen tasks on `main`, plus any `fix(playground): ...` commits surfaced by Task 11's audit runs — add a row per audit-fix commit below the 13-row table if any landed.

| # | Item | Commit | What landed |
|---|---|---|---|
| 1 | A11yID + view modifiers | _commit_ | New `View+Accessibility.swift` with typed `a11y` / `a11yToggle` / `a11yIdentifier` modifiers plus `A11yID` namespace shared by views and the UI-test target. |
| 2 | UI test target | _commit_ | `project.yml` declares `DiagramPlaygroundUITests` (xcodegen, macOS host). Scheme wires the test phase. |
| 3 | Launch-arg seeding | _commit_ | `DiagramPlaygroundApp.init()` reads `-uitest-state <id>` under `#if DEBUG`; state IDs cover empty / editing-flow-1 / selection-flow-1 / error-garbage / theme-open. |
| 4 | UITests scaffold + smoke | _commit_ | `XCTestCase+PlaygroundLaunch` helper; `SmokeTests.testAppLaunchesEmptyState` proves the harness boots. |
| 5 | PreviewToolbar | _commit_ | 7 controls. |
| 6 | LiveEditorToolbar | _commit_ | macOS + iOS arms, plus `UpdateModePicker` and 4 sheet-done buttons. |
| 7 | Small pickers | _commit_ | EditorModePicker / SourceFormatPicker / ThemePicker. |
| 8 | Sample/Version/Actions panels | _commit_ | Search field + clear; decorative glyph hides; remaining sheet-done buttons. |
| 9 | PreviewCanvas | _commit_ | Preview mode picker stateful; warning / empty-state decorative glyphs hidden. |
| 10 | DiagramEditorPane | _commit_ | Title / Selection / Label / InsertNode / InsertEdge / Delete / Undo / Redo controls. Undo/Redo use `a11yToggle` with dynamic action-name hints. |
| 11 | AccessibilityAuditTests | _commit_ | `performAccessibilityAudit()` across all five screen states. |
| 12 | Audit script | _commit_ | `Scripts/playground-a11y-check.sh` — opt-in lane mirroring `linux-check.sh`. |
| 13 | Docs sync | _this commit_ | CLAUDE.md test count + What Lives Where; this REVIEW Session 16 entry. |

Session-end verification: `Scripts/playground-a11y-check.sh` ✓; `Scripts/check-sendable-annotations.sh` ✓; `Scripts/check-file-sizes.sh` reports only pre-existing yellow warnings. The §5 a11y bullet is closed.

---
```

Fill in commit SHAs once the prior tasks have been committed. Replace each `_commit_` placeholder by running `git log --oneline -13` and copying the appropriate short SHA.

- [ ] **Step 5: Verify CLAUDE.md formatting**

Run: `grep -n 'Scripts/playground-a11y-check\.sh' CLAUDE.md`

Expected: at least two matches (Commands + Discipline Gates).

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md REVIEW.md
git commit -m "$(cat <<'EOF'
docs: CLAUDE.md + REVIEW.md Session 16 closure for a11y pass

CLAUDE.md gains the playground a11y check in Commands and Discipline
Gates; test source count updated; What Lives Where mentions the new
UI test target. REVIEW.md Session 16 entry tabulates the thirteen
commits that closed the §5 a11y bullet.
EOF
)"
```

---

## Acceptance Verification

After Task 13, run the full check sequence to confirm the spec's acceptance criteria are met:

- [ ] `Scripts/playground-a11y-check.sh` exits 0.
- [ ] `xcodebuild test` reports zero accessibility audit findings across all five screen states.
- [ ] Every `A11yID` constant defined in `View+Accessibility.swift` is referenced by both an audited view and an `IdentifierPresenceTests` case. Verify with:
  ```bash
  grep -E 'A11yID\.[A-Z][a-zA-Z]+\.[a-zA-Z]+' \
       Examples/DiagramPlayground/Views Examples/DiagramPlayground/UITests \
       -r --include='*.swift' | sort -u | wc -l
  ```
- [ ] `swift test --filter LinuxPlatformGateTests` still green (library targets are untouched).
- [ ] `Scripts/check-sendable-annotations.sh` ✓.
- [ ] `Scripts/check-file-sizes.sh` reports no new yellow warnings (the helper file is ~120 lines; per-view edits add 5–15 lines each).
- [ ] CLAUDE.md `Commands` and `Discipline Gates` sections updated.
- [ ] REVIEW.md Session 16 entry present with non-placeholder commit SHAs.

If any criterion fails, investigate before declaring the pass complete.
