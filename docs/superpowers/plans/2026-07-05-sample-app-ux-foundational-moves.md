# DiagramKitSample UX — Three Foundational Moves Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize the DiagramKitSample app's UX by (1) fixing four verified shipping bugs, (2) giving every control real interaction states via one shared `ButtonStyle`, (3) replacing the hand-rolled shell with native `NavigationSplitView` + `.inspector` + real sheets, and (4) adopting real Liquid Glass on the floating chrome.

**Architecture:** Four sequenced phases, each independently shippable. Phase 0 fixes bugs. Phase 1 introduces `PlaygroundButtonStyle` and rolls it across the design-system controls. Phase 2 rebuilds the shell on native containers (this properly resolves the iPad-toolbar and column-overflow bugs). Phase 3 introduces a `.glassChrome()` modifier + a single `GlassEffectContainer` over the canvas and converts the floating toolbars/HUDs/popovers to real Liquid Glass, then retires the fake `glassBg`/`Surface(.glass)`. Sequencing is deliberate: glass lands *after* native containers so sheets/popovers already carry system glass and the canvas is stable for `scrollEdgeEffect`/`backgroundExtensionEffect`.

**Tech Stack:** Swift 6, SwiftUI (macOS 26 / iOS 26 floor), swift-testing, the existing `PlaygroundTokens`/`ZedTrekTheme` design system, `LiveEditorStore` (`@Observable`, `@Bindable`).

## Global Constraints

- **Platform floor:** macOS 26 + iOS 26. All Liquid Glass APIs (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`, `.glassProminent`, `.scrollEdgeEffect`, `.backgroundExtensionEffect`) are available; no availability gating needed beyond the existing `#if os(...)` / `#if canImport(...)` splits.
- **All chrome tinting MUST route through `tokens.palette`.** Never hardcode chrome colors. This keeps all 10 Zed Trek themes intact. Glass MUST be tinted (`.glassEffect(.regular.tint(tokens.palette.<token>), in: shape)`) — untinted glass lets the vivid diagram bleed through and breaks the chrome/diagram separation.
- **Glass is for the floating navigation/control layer ONLY.** Never glassify content backgrounds (`bgApp`, `bgPanel`, `bgSurface`, `bgField`, editor code background, canvas, status bar body).
- **Every visual change is spot-checked across all 10 Zed Trek themes × light/dark** before its commit (Settings → theme picker, or seed via `-uitest-state`).
- **Repo conventions (from project memory):** work directly on `main`, commit-by-commit. Never run a full `swift test`; always `swift test --filter <ExactSuiteName>`. `swift build` compiles the library + the `DiagramKitSample` executable. Fix pre-existing failures forward rather than documenting around them.
- **Verification vocabulary used below:**
  - `BUILD` = `swift build` (must succeed, no new warnings).
  - `RUN` = `swift run DiagramKitSample`, then perform the described interaction and confirm the described result visually.
  - `THEME SWEEP` = in the running app open Settings (⌘, on macOS) and cycle all 10 themes × light/dark, confirming no regression.
  - `TEST <Suite>` = `swift test --filter <Suite>`.

---

## File-structure map (new files)

- `Sources/DiagramKitSample/Views/DesignSystem/Components/PlaygroundButtonStyle.swift` — the shared interactive button style + its pure state-mapping helper.
- `Sources/DiagramKitSample/Views/DesignSystem/GlassChrome.swift` — the `.glassChrome(...)` view modifier + `PlaygroundGlass` tint helpers.
- `Tests/DiagramKitTests/PlaygroundButtonStyleTests.swift` — unit tests for the pure state mapping.
- `Tests/DiagramKitTests/GlassChromeTests.swift` — unit tests for the pure tint/shape resolution.
- `Tests/DiagramKitTests/StatusbarSignalsTests.swift` — pins the status bar to real signals only (Phase 0 / B3).

Modified files are named per task.

---

# Phase 0 — Verified bug fixes

Independent, cheap, ship-now. B1 gets an interim fix here (Phase 2 replaces it properly); B2 and B3 are permanent.

### Task 0.1: B3 — remove fake status-bar telemetry

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift:22-45` (segment list), `:220-230` (fake computed props)
- Test: `Tests/DiagramKitTests/StatusbarSignalsTests.swift` (create)

**Interfaces:**
- Produces: nothing consumed downstream. This is a pure deletion + a guard test.

- [ ] **Step 1: Read the current segment composition**

Open `StatusbarView.swift`. Confirm `snapshotCount` returns the literal `"1044"` (`:226-229`) and `lastRenderText` returns `"—"` (`:220-224`), and note which segments in `body` (`:22-45`) render them (the "snapshots" segment and the "render" segment).

- [ ] **Step 2: Write a guard test that fails on hardcoded telemetry**

Create `Tests/DiagramKitTests/StatusbarSignalsTests.swift`. Because the computed props are `private`, assert at the source level that the forbidden literals are gone (a lightweight guard, in the style of the repo's discipline checks):

```swift
import Testing
import Foundation

@Suite("Statusbar shows no fake telemetry")
struct StatusbarSignalsTests {
    @Test("StatusbarView contains no hardcoded 1044 / em-dash telemetry")
    func noHardcodedTelemetry() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()      // DiagramKitTests
            .deletingLastPathComponent()      // Tests
            .deletingLastPathComponent()      // repo root
            .appendingPathComponent("Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift")
        let src = try String(contentsOf: url, encoding: .utf8)
        #expect(!src.contains("\"1044\""), "Remove the hardcoded snapshotCount placeholder")
        #expect(!src.contains("mirror the design's em dash"), "Remove the placeholder lastRenderText")
    }
}
```

- [ ] **Step 3: Run the test — expect FAIL**

Run: `TEST StatusbarSignalsTests`
Expected: FAIL (both literals currently present).

- [ ] **Step 4: Delete the fake props and their segments**

Remove `snapshotCount` and `lastRenderText` computed properties entirely. Remove the two `body` segments that rendered them (the "snapshots" segment and the placeholder "render" segment). Leave the genuine signals (engine/worker/swift/fonts/diagnostics/backend/corpus/sample). If a real last-render ms readout is desired later, it is a separate feature — do not stub it.

- [ ] **Step 5: Run the test — expect PASS; build**

Run: `TEST StatusbarSignalsTests` → PASS
Run: `BUILD`

- [ ] **Step 6: RUN + commit**

`RUN`: seed `-uitest-state editing-flow-1`, confirm the status bar no longer shows "1044" or a placeholder render segment.

```bash
git add Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift Tests/DiagramKitTests/StatusbarSignalsTests.swift
git commit -m "fix(sample): remove fake 1044/em-dash status-bar telemetry (B3)"
```

---

### Task 0.2: B1 — interim iPad toolbar fix (wrap regularLayout in NavigationStack)

**Files:**
- Modify: `Sources/DiagramKitSample/Views/LiveEditorView.swift:82-90`

**Interfaces:**
- Consumes: existing `regularLayout` and `LiveEditorToolbar`.
- Produces: nothing new. Phase 2 (Task 2.1) replaces this NavigationStack with `NavigationSplitView`.

- [ ] **Step 1: Confirm the defect**

In `LiveEditorView.swift`, verify the compact branch wraps in `NavigationStack` (`:72`) but the iOS `else` branch attaches `.toolbar` to a bare `regularLayout` (`:82-86`) with no navigation ancestor — so on iPad the toolbar items don't render.

- [ ] **Step 2: Wrap the iOS regular branch in a NavigationStack**

Change the iOS `else` branch (`:82-87`) to:

```swift
} else {
    NavigationStack {
        regularLayout
            .toolbar {
                LiveEditorToolbar(store: store)
            }
    }
}
```

Leave the `#else` (macOS) branch untouched — macOS attaches `LiveEditorToolbar` via the window `.toolbar` in `DiagramKitSampleApp.swift:142-146`.

- [ ] **Step 3: BUILD**

Run: `BUILD`

- [ ] **Step 4: RUN on iPad idiom + commit**

`RUN` in an iPad simulator (or resize to a regular-width window): confirm the theme / view-options / actions / **inspector-toggle** buttons now render in the toolbar, and the inspector toggle opens/closes the inspector.

```bash
git add Sources/DiagramKitSample/Views/LiveEditorView.swift
git commit -m "fix(sample): restore iPad primary toolbar via NavigationStack (B1, interim)"
```

---

### Task 0.3: B2 — make Settings reachable on iPhone

**Files:**
- Modify: `Sources/DiagramKitSample/Views/LiveEditorView.swift` (compact layout, `:106-167`)
- Modify: `Sources/DiagramKitSample/Views/SidebarView.swift` (the sheet content shown on iPhone) OR add a nav-bar Settings button — see Step 2.

**Interfaces:**
- Consumes: `store.presentSettings()`, `store.dismissSettings()`, `store.state.settingsPresented`, `SettingsSheet`.
- Produces: a compact-reachable Settings entry + a `.sheet`-presented `SettingsSheet` on iOS compact.

- [ ] **Step 1: Add a Settings row to the iPhone controls sheet**

In `SidebarView.swift` (shown via the compact `.sheet` at `LiveEditorView.swift:148-166`), add a Settings button near the top:

```swift
Button {
    store.presentSettings()
} label: {
    Label("Settings", systemImage: "gearshape")
}
```

- [ ] **Step 2: Render SettingsSheet as a real sheet in compactLayout**

In `LiveEditorView.swift` `compactLayout` (`:106`), attach a settings sheet to the outer `VStack`:

```swift
.sheet(isPresented: Binding(
    get: { store.state.settingsPresented },
    set: { if !$0 { store.dismissSettings() } }
)) {
    NavigationStack {
        SettingsSheet(store: store)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { store.dismissSettings() }
                }
            }
    }
}
```

Note: presenting Settings from the controls sheet may require dismissing that sheet first (`showingControls = false`) so the two sheets don't conflict — set `showingControls = false` in the Step-1 button action before `store.presentSettings()`.

- [ ] **Step 3: BUILD**

Run: `BUILD`

- [ ] **Step 4: RUN on iPhone idiom + commit**

`RUN` in an iPhone simulator: open the controls sheet (slider button, top-trailing), tap Settings, confirm the Settings sheet appears and every tab (General / Render backend / Editor / Fonts / Theme / Mutations / Parity) is reachable, and Done dismisses it.

```bash
git add Sources/DiagramKitSample/Views/LiveEditorView.swift Sources/DiagramKitSample/Views/SidebarView.swift
git commit -m "fix(sample): make Settings reachable on iPhone compact (B2)"
```

---

# Phase 1 — Move 2: shared `PlaygroundButtonStyle`

One component gives press + hover + cursor + focus + disabled feedback to the whole control surface. Highest leverage, lowest risk. Do before the structural refactor.

### Task 1.1: Create `PlaygroundButtonStyle` with a pure, tested state mapping

**Files:**
- Create: `Sources/DiagramKitSample/Views/DesignSystem/Components/PlaygroundButtonStyle.swift`
- Test: `Tests/DiagramKitTests/PlaygroundButtonStyleTests.swift`

**Interfaces:**
- Produces:
  - `struct ButtonVisualState: Equatable { var opacity: Double; var scale: Double }`
  - `enum PlaygroundButtonKind { case chrome; case tile }` (chrome = default; tile = rail/toolbar square that also wants a hover background)
  - `func playgroundButtonVisualState(isPressed: Bool, isEnabled: Bool) -> ButtonVisualState` (pure)
  - `struct PlaygroundButtonStyle: ButtonStyle` and `extension ButtonStyle where Self == PlaygroundButtonStyle { static var playground: Self }`

- [ ] **Step 1: Write failing tests for the pure state mapping**

Create `Tests/DiagramKitTests/PlaygroundButtonStyleTests.swift`:

```swift
import Testing
@testable import DiagramKitSample

@Suite("PlaygroundButtonStyle state mapping")
struct PlaygroundButtonStyleTests {
    @Test("Idle enabled is full opacity, full scale")
    func idle() {
        let s = playgroundButtonVisualState(isPressed: false, isEnabled: true)
        #expect(s.opacity == 1.0)
        #expect(s.scale == 1.0)
    }

    @Test("Pressed dips opacity and scale")
    func pressed() {
        let s = playgroundButtonVisualState(isPressed: true, isEnabled: true)
        #expect(s.opacity == 0.6)
        #expect(s.scale == 0.97)
    }

    @Test("Disabled dims regardless of press")
    func disabled() {
        let s = playgroundButtonVisualState(isPressed: false, isEnabled: false)
        #expect(s.opacity == 0.4)
        #expect(s.scale == 1.0)
    }

    @Test("Disabled wins over pressed for opacity")
    func disabledPressed() {
        let s = playgroundButtonVisualState(isPressed: true, isEnabled: false)
        #expect(s.opacity == 0.4)
    }
}
```

Note: `DiagramKitSample` must be importable `@testable`. It already is a test-target dependency (`Package.swift:203`); if `@testable import DiagramKitSample` fails to resolve symbols, confirm the target builds for tests and that the helper is declared non-`private` (internal).

- [ ] **Step 2: Run the tests — expect FAIL**

Run: `TEST PlaygroundButtonStyleTests`
Expected: FAIL — `playgroundButtonVisualState` undefined.

- [ ] **Step 3: Implement the style + pure helper**

Create `Sources/DiagramKitSample/Views/DesignSystem/Components/PlaygroundButtonStyle.swift`:

```swift
import SwiftUI

struct ButtonVisualState: Equatable {
    var opacity: Double
    var scale: Double
}

/// Pure mapping from interaction inputs to visual state. Disabled dimming
/// takes precedence over the pressed dip.
func playgroundButtonVisualState(isPressed: Bool, isEnabled: Bool) -> ButtonVisualState {
    if !isEnabled { return ButtonVisualState(opacity: 0.4, scale: 1.0) }
    if isPressed  { return ButtonVisualState(opacity: 0.6, scale: 0.97) }
    return ButtonVisualState(opacity: 1.0, scale: 1.0)
}

struct PlaygroundButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let s = playgroundButtonVisualState(isPressed: configuration.isPressed, isEnabled: isEnabled)
        return configuration.label
            .opacity(s.opacity)
            .scaleEffect(s.scale)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            #if os(macOS)
            .pointerStyle(.link)
            #endif
    }
}

extension ButtonStyle where Self == PlaygroundButtonStyle {
    /// Chrome buttons: adds pressed dip, disabled dimming, and (macOS) a
    /// link cursor. Replaces bare `.buttonStyle(.plain)` on design-system
    /// controls. Keep `.plain` only where a control must show zero chrome.
    static var playground: PlaygroundButtonStyle { PlaygroundButtonStyle() }
}
```

- [ ] **Step 4: Run the tests — expect PASS; build**

Run: `TEST PlaygroundButtonStyleTests` → PASS
Run: `BUILD`

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/Components/PlaygroundButtonStyle.swift Tests/DiagramKitTests/PlaygroundButtonStyleTests.swift
git commit -m "feat(sample): add PlaygroundButtonStyle (press/disabled/cursor) with tested state mapping"
```

---

### Task 1.2: Add a hover treatment for rail/toolbar tiles

**Files:**
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Components/ActivityRailItem.swift`

**Interfaces:**
- Consumes: `PlaygroundButtonStyle` (`.playground`), `tokens.palette.rowHover`, `tokens.palette.accentTint16`.
- Produces: the hover pattern (`@State isHovering` + `.onHover` + conditional background) reused verbatim by Task 1.3's tile targets.

- [ ] **Step 1: Add hover state to ActivityRailItem**

Replace the `body` of `ActivityRailItem` (`:18-32`) so an inactive tile highlights on hover and the button uses `.playground`:

```swift
@State private var isHovering = false

var body: some View {
    Button(action: action) {
        Image(systemName: systemImage).font(.system(size: 18))
            .foregroundStyle(isActive ? tokens.palette.accent : tokens.palette.fg3)
            .frame(width: 38, height: 38)
            .background(tileBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(alignment: .leading) {
                if isActive {
                    RoundedRectangle(cornerRadius: 2).fill(tokens.palette.accent)
                        .frame(width: 2.5).padding(.vertical, 9).offset(x: -10)
                }
            }
    }
    .buttonStyle(.playground)
    .onHover { isHovering = $0 }
    #if os(iOS)
    .hoverEffect(.highlight)
    #endif
    .help(help)
}

private var tileBackground: Color {
    if isActive { return tokens.palette.accentTint16 }
    if isHovering { return tokens.palette.rowHover }
    return .clear
}
```

- [ ] **Step 2: BUILD**

Run: `BUILD`

- [ ] **Step 3: RUN + THEME SWEEP + commit**

`RUN` (macOS): hover the rail tiles — inactive tiles highlight, cursor becomes a hand, pressing dips. `THEME SWEEP`: hover highlight visible in all 10 themes × light/dark.

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/Components/ActivityRailItem.swift
git commit -m "feat(sample): hover + press feedback on activity rail tiles"
```

---

### Task 1.3: Roll `.playground` across the design-system controls

**Files (replace `.buttonStyle(.plain)` → `.buttonStyle(.playground)`; add the Task-1.2 hover pattern to the tile-shaped ones):**
- `Sources/DiagramKitSample/Views/DesignSystem/Components/SidebarNavItem.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/SegmentedFormatControl.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/MenuRow.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/ToolbarPill.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/SwatchTile.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/ChipGroup.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/CodeChip.swift`
- `Sources/DiagramKitSample/Views/DesignSystem/Components/DotPicker.swift`, `ColorDotPicker.swift`
- `Sources/DiagramKitSample/Views/Workspace/WorkspaceModePicker.swift`
- `Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift` (all seven buttons)
- `Sources/DiagramKitSample/Views/Visual/VisualToolPalette.swift`, `Views/Visual/CanvasCenterToolbar.swift`

**Interfaces:**
- Consumes: `.buttonStyle(.playground)` from Task 1.1; hover pattern from Task 1.2.

**Scope guard:** Do NOT blindly convert all ~110 `.plain` sites. Convert the DS components + shell chrome above. Leave `.plain` where a control legitimately shows zero chrome (e.g. plain text links inside prose, list-row wrappers that manage their own selection background). When unsure, prefer `.playground` — it degrades gracefully.

The transform is mechanical. For each file:

- [ ] **Step 1: Swap the style**

Replace each `.buttonStyle(.plain)` with `.buttonStyle(.playground)`.

- [ ] **Step 2: (tile-shaped controls only) add hover**

For fixed-size square/pill tiles (`SwatchTile`, `WorkspaceModePicker` pills, `ToolbarPill`, the `CanvasZoomToolbar` icon buttons), add the `@State private var isHovering` + `.onHover { isHovering = $0 }` + conditional `rowHover` background from Task 1.2. For `CanvasZoomToolbar`'s per-button backgrounds (e.g. `fitButton` at `:75-80`), blend `rowHover` in when `isHovering` and not already accent-tinted.

- [ ] **Step 3: BUILD after each file (or each small batch)**

Run: `BUILD`

- [ ] **Step 4: RUN + THEME SWEEP**

`RUN`: exercise the mode picker, format control, swatches, zoom toolbar — all show press + hover + hand cursor; disabled zoom-in/out (`CanvasZoomToolbar.swift:99-100`) now dims via the style instead of the manual `.opacity`. Remove the now-redundant manual `.opacity(... ? 0.35 : 1.0)` on the zoom buttons since `.playground` handles disabled dimming (keep the `.disabled(...)`).
`THEME SWEEP`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift Sources/DiagramKitSample/Views/Visual/VisualToolPalette.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/Workspace/WorkspaceModePicker.swift
git commit -m "feat(sample): adopt PlaygroundButtonStyle across design-system + chrome controls"
```

---

### Task 1.4: Loading + empty states (finish the interaction-state gaps)

**Files:**
- Modify: `Sources/DiagramKitSample/Views/PreviewCanvas.swift` (add `.rendering` overlay)
- Modify: `Sources/DiagramKitSample/Views/Visual/RenderFailedSheet.swift` (retry in-flight)
- Modify: `Sources/DiagramKitSample/Views/FullWindow/CorpusBrowserView.swift`, `SnippetsLibraryView.swift`, `Views/History/HistoryView.swift` (empty states → `ContentUnavailableView`)

**Interfaces:**
- Consumes: `store.renderStatus` (`.rendering`/`.failed`/`.idle`), existing filtered collections.

- [ ] **Step 1: Add a rendering overlay to PreviewCanvas**

In `PreviewCanvas.swift` where render states are handled (`:43-101`), add, for the image path:

```swift
if store.renderStatus == .rendering {
    ProgressView()
        .controlSize(.small)
        .padding(8)
        .background(.thinMaterial, in: Capsule())   // becomes .glassEffect in Phase 3
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(12)
}
```

Apply `.opacity(0.6)` to the stale image while `store.renderStatus == .rendering` so it reads as pending.

- [ ] **Step 2: Retry in-flight state in RenderFailedSheet**

In `RenderFailedSheet.swift` (`:41-48`), disable the retry button and swap its label to a spinner while rendering:

```swift
.disabled(store.renderStatus == .rendering)
```

and in the label, `if store.renderStatus == .rendering { ProgressView().controlSize(.small) } else { /* existing label */ }`.

- [ ] **Step 3: Replace hand-rolled empty states with ContentUnavailableView**

In `CorpusBrowserView.swift:224-234`, `SnippetsLibraryView.swift:112-122`, `HistoryView.swift:144-160`, replace the `VStack { Image; Text }` empties with:

```swift
// filtered-empty (search) cases:
ContentUnavailableView.search
// intrinsic-empty cases, e.g. History:
ContentUnavailableView("No history yet", systemImage: "clock.arrow.circlepath",
    description: Text("Renders you run will appear here."))
```

- [ ] **Step 4: BUILD + RUN**

Run: `BUILD`.
`RUN`: trigger a large re-render → spinner + dimmed stale image; force a render failure → retry shows spinner and disables while running; open Corpus/Snippets with a non-matching search and History with no entries → native empty states.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/PreviewCanvas.swift Sources/DiagramKitSample/Views/Visual/RenderFailedSheet.swift Sources/DiagramKitSample/Views/FullWindow/CorpusBrowserView.swift Sources/DiagramKitSample/Views/FullWindow/SnippetsLibraryView.swift Sources/DiagramKitSample/Views/History/HistoryView.swift
git commit -m "feat(sample): rendering/loading, retry in-flight, and ContentUnavailableView empty states"
```

---

# Phase 2 — Move 1: native containers

Replace the hand-rolled shell with `NavigationSplitView` + `.inspector`, and the dimmed-`ZStack` "sheets" with real `.sheet`/`.popover`. This is the enabling refactor; it properly resolves B1 (supersedes Task 0.2) and the iPad column-overflow, and restores structural hierarchy. This phase is iterative SwiftUI work — verify by build + run at each step; there is no meaningful unit test for column geometry, so acceptance is the described visual behavior.

### Task 2.1: Rebuild the shell body on `NavigationSplitView`

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift` (the `body` HStack `:32-45`)
- Modify: `Sources/DiagramKitSample/Views/LiveEditorView.swift:82-90` (remove the interim NavigationStack from Task 0.2 — `NavigationSplitView` provides the toolbar host)

**Interfaces:**
- Consumes: `ActivityRail`, `ActivityPanel`, `bodyForMode`, `store.state.activeRailTab`.
- Produces: a `@State private var columnVisibility: NavigationSplitViewVisibility` on the shell; the rail stays as a fixed leading strip *outside* the split, the panel becomes the split sidebar.

- [ ] **Step 1: Convert the three columns to NavigationSplitView + keep the rail as a fixed leading strip**

Replace the `HStack` (`PlaygroundShell.swift:32-45`) with the rail pinned left and a `NavigationSplitView` owning panel↔content:

```swift
HStack(spacing: 0) {
    ActivityRail(store: store)                       // fixed 52pt section switcher
    NavigationSplitView(columnVisibility: $columnVisibility) {
        ActivityPanel(store: store)
            .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 320)
    } detail: {
        bodyForMode
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .navigationSplitViewStyle(.balanced)
}
```

Add `@State private var columnVisibility: NavigationSplitViewVisibility = .all`. Drive it from the existing `sidebarVisible` AppStorage: `.doubleColumn`/`.detailOnly` when the panel is hidden. Delete the old `if sidebarVisible { ActivityPanel(...) }` conditional.

- [ ] **Step 2: Remove the interim NavigationStack (Task 0.2) from the iOS regular branch**

In `LiveEditorView.swift`, revert the Task-0.2 wrap — `regularLayout` now hosts its own `NavigationSplitView`, so the branch is again:

```swift
} else {
    regularLayout
        .toolbar { LiveEditorToolbar(store: store) }
}
```

(The `NavigationSplitView` inside `PlaygroundShell` is the toolbar host on iOS regular.)

- [ ] **Step 3: BUILD + RUN (macOS + iPad)**

Run: `BUILD`.
`RUN` macOS: the sidebar (panel) now has the native collapse animation and the toolbar sidebar-toggle; drag the divider to resize. iPad regular: toolbar renders (B1 properly fixed), sidebar collapses in portrait automatically.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift Sources/DiagramKitSample/Views/LiveEditorView.swift
git commit -m "refactor(sample): rebuild shell columns on NavigationSplitView (supersedes B1 interim)"
```

---

### Task 2.2: Move the inspector to the `.inspector` modifier

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift` (remove the `if inspectorVisible { Divider(); InspectorView }` and attach `.inspector`)
- Modify: `Sources/DiagramKitSample/Views/Workspace/InspectorView.swift:42-44` (drop the manual `.frame(width: 312)` + hand-drawn border)

**Interfaces:**
- Consumes: `store.state.inspectorOpen`, `store.openInspector()`, existing `⌘I` and toolbar toggle.
- Produces: inspector presented natively; `InspectorView` no longer sets its own width/border.

- [ ] **Step 1: Attach `.inspector` to the NavigationSplitView detail**

Wrap or modify the `NavigationSplitView` (Task 2.1) with:

```swift
.inspector(isPresented: Binding(
    get: { store.state.inspectorOpen },
    set: { store.state.inspectorOpen = $0 }
)) {
    InspectorView(store: store)
        .inspectorColumnWidth(min: 280, ideal: 312, max: 380)
}
```

Remove the old `if inspectorVisible { Divider(); InspectorView(store: store) }` block from the HStack.

- [ ] **Step 2: Strip the inspector's manual frame + border**

In `InspectorView.swift:42-44`, delete `.frame(width: 312)` and the `.overlay(Rectangle()…border…)` — the `.inspector` modifier owns width, the divider, and the slide-in.

- [ ] **Step 3: BUILD + RUN**

Run: `BUILD`.
`RUN`: the inspector toggle (toolbar) and `⌘I` open/close a native inspector with a resize handle; it no longer shoves the content by hand.

- [ ] **Step 4: (B4) mark non-functional inspector sections**

While here, resolve B4: the presentational-only "Arrange" and "Diagram direction" sections in `InspectorView` should either be removed or visibly marked (e.g. a "Preview only" caption + `.disabled(true)` so they don't read as live controls). Prefer removal if they drive nothing.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift Sources/DiagramKitSample/Views/Workspace/InspectorView.swift
git commit -m "refactor(sample): present inspector via .inspector modifier; mark dead controls (B4)"
```

---

### Task 2.3: Convert the four hand-rolled overlays to real `.sheet`/`.popover`

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift:60-116` (Explain, Export, Convert, Settings overlays)

**Interfaces:**
- Consumes: `store.state.exportSheet.isOpen`/`closeExportSheet()`, `convertSheet`, `diagnosticExplainTarget`/`dismissExplain()`, `settingsPresented`/`dismissSettings()`.
- Produces: native modality; removes the `Color.black.opacity(...)` scrims and `.onTapGesture` dismissals.

- [ ] **Step 1: Replace Export + Convert + Settings dimmed ZStacks with `.sheet`**

For each, delete the `if …isOpen { ZStack { Color.black.opacity(...); Sheet() } }` block and attach a `.sheet` to the shell's root, e.g.:

```swift
.sheet(isPresented: Binding(get: { store.state.exportSheet.isOpen },
                            set: { if !$0 { store.closeExportSheet() } })) {
    ExportSheet(store: store)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #endif
}
```

Repeat for `ConvertSheet` (`convertSheet`) and `SettingsSheet` (`settingsPresented`/`dismissSettings`). For `SettingsSheet`, also remove the fixed `748×520` frame (`SettingsSheet.swift:26`) and the traffic-light dismiss `Circle` (`:35`) — replace with a `Done`/close button in a `.toolbar`.

- [ ] **Step 2: Replace the Explain overlay with a `.popover`**

The Explain popover (`:60-67`) anchors to a diagnostics row; present it via `.popover(item:)` from the row that triggers it (in `DiagnosticsDrawer`/inspector) rather than a full-shell dimmed ZStack. If a precise anchor isn't readily available, use a `.sheet` with `.presentationDetents([.medium])` as the interim.

- [ ] **Step 3: BUILD + RUN + THEME SWEEP**

Run: `BUILD`.
`RUN`: Export/Convert/Settings/Explain now present as native sheets/popovers — Escape dismisses (macOS), drag-to-dismiss + detents (iOS), and VoiceOver scopes to the modal. Confirm no double-mount (the CitationOverlay export path noted in the parity audit should not also mount these — verify only one presentation site remains).
`THEME SWEEP`.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Workspace/PlaygroundShell.swift Sources/DiagramKitSample/Views/Settings/SettingsSheet.swift
git commit -m "refactor(sample): present Export/Convert/Settings/Explain as native sheets/popovers"
```

---

### Task 2.4: iPad adaptivity + 44pt touch targets

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Workspace/InspectorView.swift` (close button 24→44 hit area), `Views/Workspace/WorkspaceModePicker.swift` (22pt pills), `Views/Workspace/CitationOverlay.swift` (22×22 button), `Views/Inspector/ThemeBuilderCard.swift` (20×20 swatches), `Views/Workspace/TitlebarView.swift` (bare Image buttons)
- Modify: `Sources/DiagramKitSample/Views/Workspace/StatusbarView.swift` (compact-width collapse)

**Interfaces:**
- Consumes: `horizontalSizeClass` (already used in `LiveEditorView`).

- [ ] **Step 1: Enforce 44pt hit areas on touch**

For each listed control, wrap the tap target so it meets 44×44 under UIKit without changing the visual glyph size:

```swift
.frame(minWidth: 44, minHeight: 44)   // gate with #if canImport(UIKit) where it would bloat macOS chrome
.contentShape(Rectangle())
```

Prefer gating the min-size to `#if canImport(UIKit)` so macOS density is preserved.

- [ ] **Step 2: Collapse the status bar on compact/narrow widths**

In `StatusbarView.swift`, when `horizontalSizeClass == .compact` (or width below a threshold), render only the essential subset (render status + diagnostics button + active sample) instead of all segments. Keep the full row on macOS/regular.

- [ ] **Step 3: BUILD + RUN (iPad + iPhone)**

Run: `BUILD`.
`RUN` iPad/iPhone: the inspector close, mode pills, citation, and swatch controls are comfortably tappable; the status bar no longer overflows on narrow widths.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Workspace Sources/DiagramKitSample/Views/Inspector/ThemeBuilderCard.swift
git commit -m "feat(sample): 44pt touch targets + compact status bar for iPad/iPhone"
```

---

# Phase 3 — Move 3: real Liquid Glass on the floating chrome

Lands after native containers so real sheets/popovers already carry system glass and the canvas is stable. Introduces one modifier + one container; converts the floating layer; retires the fakes.

### Task 3.1: Add the `.glassChrome()` modifier with a tested tint helper

**Files:**
- Create: `Sources/DiagramKitSample/Views/DesignSystem/GlassChrome.swift`
- Test: `Tests/DiagramKitTests/GlassChromeTests.swift`

**Interfaces:**
- Produces:
  - `enum PlaygroundGlassRole { case toolbar; case hud; case popoverCard }`
  - `func playgroundGlassTint(role: PlaygroundGlassRole, palette: PlaygroundPalette) -> Color` (pure)
  - `extension View { func glassChrome(_ role: PlaygroundGlassRole, in shape: some Shape) -> some View }`

- [ ] **Step 1: Write failing tests for the pure tint resolver**

Create `Tests/DiagramKitTests/GlassChromeTests.swift`:

```swift
import Testing
import SwiftUI
@testable import DiagramKitSample

@Suite("Glass chrome tint resolution")
struct GlassChromeTests {
    @Test("Toolbar tint uses the chrome token")
    func toolbarTint() {
        let p = ZedTrekTheme.zedTrekDark.palette(for: .dark)
        #expect(playgroundGlassTint(role: .toolbar, palette: p) == p.bgChrome)
    }

    @Test("HUD tint uses the accent token")
    func hudTint() {
        let p = ZedTrekTheme.zedTrekDark.palette(for: .dark)
        #expect(playgroundGlassTint(role: .hud, palette: p) == p.accent)
    }

    @Test("Popover card tint uses the panel token")
    func popoverTint() {
        let p = ZedTrekTheme.zedTrekDark.palette(for: .dark)
        #expect(playgroundGlassTint(role: .popoverCard, palette: p) == p.bgPanel)
    }
}
```

(Confirm the exact default case name for `ZedTrekTheme` and its `palette(for:)` signature in `ZedTrekTheme.swift`; adjust `zedTrekDark` if the enum case differs.)

- [ ] **Step 2: Run tests — expect FAIL**

Run: `TEST GlassChromeTests` → FAIL (`playgroundGlassTint` undefined).

- [ ] **Step 3: Implement the modifier + tint helper**

Create `Sources/DiagramKitSample/Views/DesignSystem/GlassChrome.swift`:

```swift
import SwiftUI

enum PlaygroundGlassRole {
    case toolbar      // floating canvas toolbars, zoom cluster, tool palette
    case hud          // transient selection HUD / toasts / stage banner
    case popoverCard  // free-floating (non-.popover) editor cards
}

/// Pure: which palette token tints the glass for a given role. Keeps all
/// tinting routed through the theme so the 10 Zed Trek palettes survive.
func playgroundGlassTint(role: PlaygroundGlassRole, palette: PlaygroundPalette) -> Color {
    switch role {
    case .toolbar:     return palette.bgChrome
    case .hud:         return palette.accent
    case .popoverCard: return palette.bgPanel
    }
}

extension View {
    /// Real Liquid Glass for the floating chrome layer, tinted from the
    /// active theme. Replaces hand-rolled `fill(material)+stroke+shadow`.
    func glassChrome(_ role: PlaygroundGlassRole, in shape: some Shape) -> some View {
        modifier(GlassChromeModifier(role: role, shape: AnyShape(shape)))
    }
}

private struct GlassChromeModifier: ViewModifier {
    let role: PlaygroundGlassRole
    let shape: AnyShape
    @Environment(\.playgroundTokens) private var tokens

    func body(content: Content) -> some View {
        content.glassEffect(
            .regular.tint(playgroundGlassTint(role: role, palette: tokens.palette)),
            in: shape
        )
    }
}
```

- [ ] **Step 4: Run tests — expect PASS; build**

Run: `TEST GlassChromeTests` → PASS
Run: `BUILD`

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem/GlassChrome.swift Tests/DiagramKitTests/GlassChromeTests.swift
git commit -m "feat(sample): add tinted .glassChrome() Liquid Glass modifier with tested tint resolver"
```

---

### Task 3.2: Convert the three floating canvas toolbars to glass inside one container

**Files:**
- Modify: `Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift:52-60` (background block)
- Modify: `Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift:115-123`, `Views/Visual/VisualToolPalette.swift:34-42`
- Modify: `Sources/DiagramKitSample/Views/Visual/VisualPane.swift` (wrap the canvas overlays in a `GlassEffectContainer`), `Views/PreviewCanvas.swift` (zoom bar overlay)

**Interfaces:**
- Consumes: `.glassChrome(.toolbar, in:)` from Task 3.1.

- [ ] **Step 1: Swap each toolbar's fill+stroke+shadow for `.glassChrome`**

In `CanvasZoomToolbar.swift`, replace the `.background(RoundedRectangle…fill(bgChrome.opacity(0.92))…stroke…).shadow(...)` (`:52-60`) with:

```swift
.glassChrome(.toolbar, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
```

Do the same in `CanvasCenterToolbar.swift` and `VisualToolPalette.swift` (matching their corner radii). Delete the manual `.shadow` — glass provides its own.

- [ ] **Step 2: Wrap the canvas overlay cluster in a GlassEffectContainer**

In `VisualPane.swift` where the tool palette + center bar + zoom bar overlay the canvas, wrap them:

```swift
GlassEffectContainer(spacing: 12) {
    // existing palette / center bar / zoom bar overlays
}
```

Do the same for the `PreviewCanvas` zoom-bar overlay region so overlapping glass surfaces morph/merge correctly.

- [ ] **Step 3: Convert the tool buttons to glass button styles**

In `VisualToolPalette.swift`, change tool buttons from `.buttonStyle(.playground)` + manual accent fill to `.buttonStyle(.glass)`, and the active/selected tool to `.buttonStyle(.glassProminent)` — drop the hand-drawn `accentTint16` selection fill.

- [ ] **Step 4: BUILD + RUN + THEME SWEEP (critical)**

Run: `BUILD`.
`RUN`: the floating toolbars are now real glass lensing the diagram; the active tool reads via `.glassProminent`; overlapping overlays morph.
`THEME SWEEP` — **this is the highest-risk step for theming.** Confirm on the busiest diagrams (large flowcharts) that the tinted glass keeps toolbar text legible and the brand tint survives in all 10 themes × light/dark. If any theme lets the diagram bleed through illegibly, increase the tint opacity in `playgroundGlassTint` for that role (still via the token).

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/CanvasZoomToolbar.swift Sources/DiagramKitSample/Views/Visual/CanvasCenterToolbar.swift Sources/DiagramKitSample/Views/Visual/VisualToolPalette.swift Sources/DiagramKitSample/Views/Visual/VisualPane.swift Sources/DiagramKitSample/Views/PreviewCanvas.swift
git commit -m "feat(sample): convert floating canvas toolbars to Liquid Glass in a GlassEffectContainer"
```

---

### Task 3.3: Glass the HUD, toasts, and free-floating popover cards

**Files:**
- Modify: `Sources/DiagramKitSample/Views/Visual/SelectionHUD.swift:24`, `Views/Visual/SubgraphCommitToast.swift:29-33`, `Views/Visual/VisualPane.swift:172` (stage banner), `Views/Visual/Gantt/GanttEditCanvas.swift:304` (drag pill)
- Modify: `Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift:127-131`, `Views/Visual/QuickFixCard.swift:48-52`, `Views/Workspace/CitationOverlay.swift:60-62`, `Views/Visual/EdgeEditPopover.swift:91`

**Interfaces:**
- Consumes: `.glassChrome(.hud, in:)` and `.glassChrome(.popoverCard, in:)` from Task 3.1.

**Scope guard:** Do NOT touch content presented via a real `.popover`/`.sheet` (ShapeCatalog/IconBrowser/Rearrange/ThemeSwatch via `CanvasCenterToolbar` popovers, and the sheets migrated in Task 2.3) — they already inherit system glass; adding glass inside stacks two materials.

- [ ] **Step 1: HUD/toasts → `.glassChrome(.hud, ...)`**

`SelectionHUD` (`:24`), `SubgraphCommitToast` (`:29-33`), stage banner (`VisualPane.swift:172`), Gantt drag pill (`:304`): replace `Capsule().fill(...)`/`RoundedRectangle().fill(.regularMaterial).shadow(...)` with `.glassChrome(.hud, in: Capsule())` (or the matching rounded rect). Include these inside the Task-3.2 `GlassEffectContainer` where they share the canvas overlay space so a toast near the zoom bar morphs cleanly.

- [ ] **Step 2: Free-floating cards → `.glassChrome(.popoverCard, ...)`**

`NodeEditPopover` (`:127-131`), `QuickFixCard` (`:48-52`), `CitationOverlay` (`:60-62`), `EdgeEditPopover` (`:91`): replace `RoundedRectangle().fill(.regularMaterial).shadow(...)` with `.glassChrome(.popoverCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))`.

- [ ] **Step 3: BUILD + RUN + THEME SWEEP**

Run: `BUILD`.
`RUN`: select a node (HUD glass), commit a subgraph (toast glass), open node/edge edit + quick-fix cards (card glass). `THEME SWEEP`.

- [ ] **Step 4: Commit**

```bash
git add Sources/DiagramKitSample/Views/Visual/SelectionHUD.swift Sources/DiagramKitSample/Views/Visual/SubgraphCommitToast.swift Sources/DiagramKitSample/Views/Visual/VisualPane.swift Sources/DiagramKitSample/Views/Visual/Gantt/GanttEditCanvas.swift Sources/DiagramKitSample/Views/Visual/NodeEditPopover.swift Sources/DiagramKitSample/Views/Visual/QuickFixCard.swift Sources/DiagramKitSample/Views/Workspace/CitationOverlay.swift Sources/DiagramKitSample/Views/Visual/EdgeEditPopover.swift
git commit -m "feat(sample): Liquid Glass on selection HUD, toasts, and floating editor cards"
```

---

### Task 3.4: Retire the fake `glassBg` / `Surface(.glass)` and add edge effects

**Files:**
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Components/Surface.swift:64-66` (the `.glass` case)
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/Components/ToolbarPill.swift:54-60`, `Views/Support/RenderHealthPill.swift:35-42` (fill `glassBg`)
- Modify (add edge effects): `Sources/DiagramKitSample/Views/Editor/DiagramEditorPane.swift:22` and the sheet scroll bodies; `Views/PreviewCanvas.swift`/`Views/Visual/Flowchart/FlowchartEditCanvas.swift` (canvas background)
- Modify: `Sources/DiagramKitSample/Views/DesignSystem/PlaygroundTokens.swift:47` (remove `glassBg` once unused) + `PlaygroundPalette+ZedTrekFamily.swift:52,89`

**Interfaces:**
- Consumes: `.glassChrome(...)`, `.scrollEdgeEffect`, `.backgroundExtensionEffect`.

- [ ] **Step 1: Point `Surface(.glass)` at real glass**

In `Surface.swift`, change the `.glass` background case (`:64-66`) to apply `.glassEffect(.regular.tint(tokens.palette.bgChrome), in: shape)` instead of `fill(glassBg).background(.ultraThinMaterial)`. Convert the two pills (`ToolbarPill`, `RenderHealthPill`) to `.glassChrome(.toolbar, in: .capsule)` (or `.glassEffect(.regular, in: .capsule)`).

- [ ] **Step 2: Remove the dead `glassBg` token**

Once no callsite references `glassBg` (grep to confirm), delete `var glassBg` from `PlaygroundPalette` (`PlaygroundTokens.swift:47`) and its assignments in `PlaygroundPalette+ZedTrekFamily.swift`.

Run: `grep -rn "glassBg" Sources/` → expect no results before deleting the declaration.

- [ ] **Step 3: Add scroll-edge + background-extension effects**

Add `.scrollEdgeEffect(.soft, for: .top)` (and `.bottom` where a footer pins) to scroll containers that sit under pinned chrome: the editor scroll (`DiagramEditorPane.swift:22`), the Export/Convert sheet bodies, inspector, and panel lists. Add `.backgroundExtensionEffect()` to the canvas background in `PreviewCanvas`/`FlowchartEditCanvas` so the floating glass genuinely lenses the diagram content.

- [ ] **Step 4: BUILD + RUN + THEME SWEEP**

Run: `BUILD` (must have zero `glassBg` references).
`RUN`: scroll content dissolves into the top edge instead of hard-clipping; the floating glass toolbars refract the diagram beneath them.
`THEME SWEEP`.

- [ ] **Step 5: Commit**

```bash
git add Sources/DiagramKitSample/Views/DesignSystem Sources/DiagramKitSample/Views/Support/RenderHealthPill.swift Sources/DiagramKitSample/Views/Editor/DiagramEditorPane.swift Sources/DiagramKitSample/Views/PreviewCanvas.swift Sources/DiagramKitSample/Views/Visual/Flowchart/FlowchartEditCanvas.swift
git commit -m "feat(sample): retire fake glassBg/Surface(.glass); add scrollEdge + backgroundExtension effects"
```

---

## Final verification (after all phases)

- [ ] `BUILD` clean, no new warnings.
- [ ] `TEST PlaygroundButtonStyleTests`, `TEST GlassChromeTests`, `TEST StatusbarSignalsTests` all pass.
- [ ] `TEST LiveEditorStoreEditorLifecycleTests` and `TEST WorkspaceModeDefaultTests` still pass (no store regressions).
- [ ] `RUN` on macOS, iPad-regular, and iPhone-compact idioms: no unreachable feature (Settings on all three), toolbar present on all three, sheets native, glass floating chrome legible.
- [ ] `THEME SWEEP` across all 10 Zed Trek themes × light/dark with a large flowchart loaded — no illegible glass, no broken tint.
- [ ] `git grep -n "glassBg"` returns nothing; `git grep -n '"1044"'` returns nothing.

---

## Self-review notes (author)

- **Spec coverage:** All three foundational moves + the four verified bugs (B1 Task 0.2→2.1, B2 Task 0.3, B3 Task 0.1, B4 Task 2.2) + the interaction-state tail (loading/empty Task 1.4) are covered. Roadmap P2/P3 items not in the three moves (typography collapse, de-bordering, canvas hover-highlight, animated segmented indicator) are intentionally deferred — they are not part of the three moves this plan scopes; track separately.
- **Type consistency:** `playgroundButtonVisualState`/`ButtonVisualState`/`.playground` (Phase 1) and `playgroundGlassTint`/`PlaygroundGlassRole`/`.glassChrome` (Phase 3) are used consistently across their tasks.
- **Known unverified assumptions to check at execution time:** exact `ZedTrekTheme` default case name + `palette(for:)` signature (Task 3.1 test); whether `@testable import DiagramKitSample` resolves internal symbols (Task 1.1); the exact `InspectorView` section names for B4 (Task 2.2); presence of a clean anchor for the Explain `.popover` (Task 2.3, has a `.sheet` fallback).
