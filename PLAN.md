# DiagramPlayground v2 — Design-to-Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the v2 DiagramPlayground envisioned in `Diagrams/*.jsx` as a native SwiftUI app on top of the existing `Examples/DiagramPlayground` target — Code / Visual / Split workspace with multi-format import/export, a full diagnostics drawer, a 28×5 exporter-coverage matrix, a 422-entry corpus browser, a three-format cross view, an importer-registry probe, a snippets library, and a per-panel source-citation overlay.

**Architecture:** Keep the existing `LiveEditorStore` (`@Observable`, `@MainActor`) as the single source of truth and grow it to host workspace mode, visual-mode editor state (`DiagramEditor`), diagnostics-drawer state, sheet/overlay state, coverage/corpus/probe selections, and a citations-overlay flag. Replace `LiveEditorView`'s `NavigationSplitView` with a custom three-column shell (`PlaygroundShell`) so we can drive Titlebar / Sidebar / Inspector / Statusbar layout precisely. Visual editing piggybacks on `DiagramKitInteractive.DiagramEditor` + `DiagramMutation` / `FlowchartMutation`. Sheets and overlays render as `.fullScreenCover` / `.sheet` / `ZStack` overlays. New full-window screens (Coverage, Corpus, Cross-format, Probe, Snippets) take the place of editor+preview when active.

**Tech Stack:** SwiftUI (macOS 26 / iOS 26), `DiagramKit` umbrella (`DiagramKitViews`, `DiagramKitInteractive`, `DiagramKitMermaid`/`D2`/`Graphviz`/`Structurizr`/`PlantUML`, `DiagramKitTestSupport.RoundTripHarness`), `swift-testing` for unit tests, `SnapshotTesting` for view snapshots, `XCUITest` for accessibility audits via `Scripts/playground-a11y-check.sh`.

**Design-fiction items called out by the JSX:**
1. `FlowchartMutation.groupIntoSubgraph(selections:title:)` — the design's state-6 commit refers to a mutation that does **not** exist in `DiagramKitInteractive` today. Phase 5 adds it.
2. `~/.diagramkit/themes/<name>.json` writes from `ThemeBuilderCard` — Phase 10 implements an in-memory theme override; on-disk theme writes stay out of scope.
3. The 28×5 coverage matrix, importer-probe order, and 422-entry corpus stats — populate from real `ExporterRegistry`/`ImporterRegistry` introspection where possible, with a typed `CoverageMatrixSeed` fallback that exactly matches the families/columns the JSX shows.

---

## File Structure

The plan adds a `Views/Workspace/` tree and reorganizes a few existing files. Final layout (Apple-only `Examples/DiagramPlayground/`):

```text
Examples/DiagramPlayground/
├─ DiagramPlaygroundApp.swift            (modify)
├─ Models/
│  ├─ LiveEditorStore.swift              (modify: workspaceMode, visualEditor, drawer, sheets, fullscreen, citations, etc.)
│  ├─ LiveEditorState.swift              (modify: same)
│  ├─ Workspace/
│  │  ├─ WorkspaceMode.swift             (new: .code/.visual/.split enum)
│  │  ├─ FullScreenSurface.swift         (new: .coverage/.corpus/.crossFormat/.probe/.snippets)
│  │  ├─ DiagnosticsDrawerState.swift    (new: severity / category / tier / paired filters)
│  │  ├─ ExportSheetState.swift          (new: target, rtCheck)
│  │  ├─ ConvertSheetState.swift         (new: target, rtAssertion result)
│  │  ├─ VisualEditorState.swift         (new: tool, selection, popover, undo cursor)
│  │  └─ CitationsModel.swift            (new: per-screen CitationPin list + .showCitations)
│  ├─ Coverage/
│  │  ├─ CoverageMatrixSeed.swift        (new: 28 families × 5 formats × cell state)
│  │  └─ CoverageMatrixProvider.swift    (new: live ExporterRegistry probe + diff vs seed)
│  ├─ Corpus/
│  │  ├─ CorpusEntry.swift               (new: id, fam, format, badge, linuxFacet, diagFacet)
│  │  └─ CorpusIndex.swift               (new: loads test-diagrams.json, builds facets)
│  ├─ Probe/
│  │  └─ ImporterProbeRunner.swift       (new: feeds one source through ImporterRegistry, records winner)
│  ├─ Snippets/
│  │  └─ Snippet.swift + SnippetLibrary.swift (new: 28 patterns)
│  ├─ Mutations/
│  │  └─ MutationCatalog.swift           (new: presenter list for Inspector card)
│  └─ Theme/
│     ├─ ThemeBuilderState.swift         (new: token overrides + dirty flag)
│     └─ ThemePreset.swift               (new: dark/light/forest/neutral)
├─ Views/
│  ├─ LiveEditorView.swift               (modify: hand off to PlaygroundShell)
│  ├─ Workspace/
│  │  ├─ PlaygroundShell.swift           (new: titlebar + body grid + statusbar root)
│  │  ├─ TitlebarView.swift              (new)
│  │  ├─ WorkspaceModePicker.swift       (new)
│  │  ├─ StatusbarView.swift             (new)
│  │  ├─ SidebarView+v2.swift            (modify SidebarView)
│  │  ├─ InspectorView.swift             (new: multi-section accordion replacing parts of DiagramEditorPane)
│  │  ├─ InspectorDocumentSection.swift  (new)
│  │  ├─ InspectorRenderBackendSection.swift (new)
│  │  ├─ InspectorThemeSection.swift     (new)
│  │  ├─ InspectorDiagnosticsSection.swift   (new)
│  │  ├─ InspectorHistorySection.swift   (new)
│  │  ├─ InspectorCitationsToggle.swift  (new)
│  │  ├─ CitationOverlay.swift           (new: numbered pins per screen)
│  │  └─ KPill.swift / KSegment.swift / KSwatch.swift (new: small chrome primitives)
│  ├─ EditorPane.swift                   (modify: tabs, minimap, bi-sel)
│  ├─ PreviewCanvas.swift                (modify: render-health pill, zoom group, render-backend slot)
│  ├─ Visual/
│  │  ├─ VisualPane.swift                (new: family dispatch + tools + HUD + state stepper)
│  │  ├─ Flowchart/FlowchartEditCanvas.swift     (new)
│  │  ├─ Sequence/SequenceEditCanvas.swift       (new)
│  │  ├─ Gantt/GanttEditCanvas.swift             (new)
│  │  ├─ VisualToolPalette.swift                 (new)
│  │  ├─ SelectionHUD.swift                      (new)
│  │  ├─ UndoTimelineView.swift                  (new)
│  │  ├─ NodeEditPopover.swift                   (new)
│  │  ├─ EdgeEditPopover.swift                   (new)
│  │  ├─ QuickFixCard.swift                      (new)
│  │  ├─ SubgraphOverlay.swift                   (new)
│  │  ├─ SubgraphCommitToast.swift               (new)
│  │  └─ RenderFailedSheet.swift                 (new)
│  ├─ Drawers/
│  │  ├─ DiagnosticsDrawer.swift                 (new)
│  │  └─ DiagnosticExplainPopover.swift          (new)
│  ├─ Sheets/
│  │  ├─ ExportSheet.swift                       (new — replaces ShareView.swift after parity)
│  │  └─ ConvertSheet.swift                      (new)
│  ├─ FullWindow/
│  │  ├─ CoverageMatrixView.swift                (new)
│  │  ├─ CorpusBrowserView.swift                 (new)
│  │  ├─ ThreeFormatView.swift                   (new)
│  │  ├─ ImporterProbeView.swift                 (new)
│  │  └─ SnippetsLibraryView.swift               (new)
│  ├─ Inspector/
│  │  ├─ ThemeBuilderCard.swift                  (new)
│  │  ├─ MutationsCatalogCard.swift              (new)
│  │  └─ PlatformRow.swift                       (new)
│  └─ Support/RenderHealthPill.swift             (new)
├─ Resources/
│  ├─ test-diagrams.json                  (existing)
│  └─ snippets/                           (new: 28 .mmd / .d2 / .dot files)
└─ UITests/
   ├─ WorkspaceModeTests.swift            (new)
   ├─ VisualFlowchartStateTests.swift     (new)
   ├─ DiagnosticsDrawerTests.swift        (new)
   ├─ ExportSheetTests.swift              (new)
   ├─ ConvertSheetTests.swift             (new)
   ├─ CoverageMatrixTests.swift           (new)
   ├─ CorpusBrowserTests.swift            (new)
   ├─ ImporterProbeTests.swift            (new)
   ├─ SnippetsLibraryTests.swift          (new)
   ├─ CitationsOverlayTests.swift         (new)
   └─ AccessibilityAuditTests.swift       (modify: extend screen list)
```

Library-side changes (outside `Examples/`):

```text
Sources/DiagramKitInteractive/
├─ DiagramEditor+Flowchart.swift          (modify: + .groupIntoSubgraph(selections:title:))
├─ FlowchartSubgraphMutation.swift        (new: subgraph-grouping mutation + inverse)
└─ DiagramEditorError.swift               (modify: + .invalidSubgraphSelection)
Tests/DiagramKitTests/
└─ Interactive/FlowchartSubgraphMutationTests.swift (new)
```

`A11yID` (in `Examples/DiagramPlayground/Models/A11yID.swift` — currently embedded; promote to own file if not already) gets new constants for every actionable control the plan adds. The XCUI suite asserts presence after each phase.

---

## Phase Map

| Phase | Theme | Demoable outcome |
|------:|------|-----------------|
| **1** | Workspace shell | Code-mode functional under new Titlebar/Sidebar/Inspector/Statusbar. Mode picker shows Code/Visual/Split (Visual disabled). |
| **2** | Split mode + Editor/Preview enhancements | Tabs, minimap, bidirectional selection, render-backend segmented, RenderHealthPill (ok), zoom group. |
| **3** | Visual mode — flowchart | 7-state flowchart edit canvas with tool palette, selection HUD, undo timeline, node/edge popovers, quick-fix card. |
| **4** | Visual mode — sequence + gantt | Message-drag sequence canvas + date-bar-drag gantt canvas. |
| **5** | Subgraph grouping | New `FlowchartMutation.groupIntoSubgraph` in `DiagramKitInteractive` + marquee/commit/toast/overlay UI. |
| **6** | Diagnostics drawer | Bottom drawer w/ severity + category + tier + paired filters + Explain popover. |
| **7** | Export + Convert sheets | ExportSheet (10 targets, per-target preview, round-trip toggle). ConvertSheet (Mermaid→D2/DOT/STZ/PUML w/ RoundTripLoss callouts). |
| **8** | Coverage matrix + Corpus browser | Full-window 28×5 coverage view with hover tip. Full-window 422-entry corpus grid with family/format/diag/Linux facets. |
| **9** | Cross-format + Importer probe + Snippets | Three-format side-by-side, registry-probe sequence view, 28-pattern snippets library. |
| **10** | Inspector cards + render-failed + citations | ThemeBuilderCard, MutationsCatalogCard, PlatformRow, slow/failed render states, RenderFailedSheet, source-citation overlay system. |

Each phase ends with a green `swift build`, a passing `swift test --filter <PhaseSuite>`, and an XCUI smoke run for the affected screens via `Scripts/playground-a11y-check.sh` (skipped if Xcode/xcodegen unavailable, per CLAUDE.md).

---

# Phase 1 — Workspace shell

**Goal:** Replace `NavigationSplitView` chrome with a custom three-column shell (`PlaygroundShell`) carrying Titlebar, Sidebar, body, Inspector, and Statusbar. Code mode continues to work end-to-end through the new shell. Visual / Split mode picker is wired in but only Code is selectable.

**Files:**
- Create: `Examples/DiagramPlayground/Models/Workspace/WorkspaceMode.swift`
- Create: `Examples/DiagramPlayground/Models/Workspace/CitationsModel.swift`
- Modify: `Examples/DiagramPlayground/Models/LiveEditorState.swift` (add `workspaceMode: WorkspaceMode`, `showCitations: Bool`)
- Modify: `Examples/DiagramPlayground/Models/LiveEditorStore.swift` (expose mode + setters)
- Create: `Examples/DiagramPlayground/Views/Workspace/PlaygroundShell.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/TitlebarView.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/WorkspaceModePicker.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/StatusbarView.swift`
- Modify: `Examples/DiagramPlayground/Views/SidebarView.swift` (add format-chip filter, search field, sample tree section headers)
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorView.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorDocumentSection.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorRenderBackendSection.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorThemeSection.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorDiagnosticsSection.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorHistorySection.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/InspectorCitationsToggle.swift`
- Create: `Examples/DiagramPlayground/Views/Workspace/KPill.swift`
- Modify: `Examples/DiagramPlayground/Views/LiveEditorView.swift` (delegate body to `PlaygroundShell`)
- Modify: `Examples/DiagramPlayground/Models/A11yID.swift` (add `titlebar.modeCode/Visual/Split`, `sidebar.search`, `sidebar.formatChip.<id>`, `inspector.section.<name>`, `statusbar.backend`, `inspector.citationsToggle`)
- Test: `Tests/DiagramKitTests/Playground/WorkspaceModeTests.swift` (new)
- Test: `Examples/DiagramPlayground/UITests/WorkspaceShellSmokeTests.swift` (new)

### Task 1.1 — Workspace mode enum

- [ ] **Step 1: Write the failing test**

Create `Tests/DiagramKitTests/Playground/WorkspaceModeTests.swift`:

```swift
import Testing
@testable import DiagramPlayground

@Suite("WorkspaceMode")
struct WorkspaceModeTests {
    @Test("All three cases are CaseIterable in source order")
    func ordering() {
        #expect(WorkspaceMode.allCases == [.code, .visual, .split])
    }

    @Test("Default is .split per the design tweaks default")
    func defaultValue() {
        #expect(WorkspaceMode.default == .split)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

```
swift test --filter WorkspaceModeTests
```
Expected: build failure ("Cannot find 'WorkspaceMode' in scope").

- [ ] **Step 3: Add the type**

Create `Examples/DiagramPlayground/Models/Workspace/WorkspaceMode.swift`:

```swift
import Foundation

public enum WorkspaceMode: String, CaseIterable, Codable, Sendable, Hashable {
    case code, visual, split
    public static let `default`: WorkspaceMode = .split
    public var label: String {
        switch self {
        case .code:   return "Code"
        case .visual: return "Visual"
        case .split:  return "Split"
        }
    }
    public var sfSymbol: String {
        switch self {
        case .code:   return "chevron.left.forwardslash.chevron.right"
        case .visual: return "wand.and.stars"
        case .split:  return "rectangle.split.2x1"
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```
swift test --filter WorkspaceModeTests
```
Expected: PASS.

- [ ] **Step 5: Commit**

```
git add Examples/DiagramPlayground/Models/Workspace/WorkspaceMode.swift Tests/DiagramKitTests/Playground/WorkspaceModeTests.swift
git commit -m "playground: add WorkspaceMode enum (Code/Visual/Split)"
```

### Task 1.2 — Persist workspace mode on the store

- [ ] **Step 1: Write the failing test**

Append to `WorkspaceModeTests.swift`:

```swift
@Test("Store round-trips workspace mode through LiveEditorState codec")
@MainActor
func storeRoundTrip() async throws {
    let store = LiveEditorStore.previewing()
    store.state.workspaceMode = .visual
    let data = try LiveEditorStateCodec.encode(store.state)
    let decoded = try LiveEditorStateCodec.decode(data)
    #expect(decoded.workspaceMode == .visual)
}
```

- [ ] **Step 2: Run the test, expect "unknown property" failure.**

```
swift test --filter WorkspaceModeTests/storeRoundTrip
```

- [ ] **Step 3: Wire `workspaceMode` and `showCitations` into `LiveEditorState`**

Modify `LiveEditorState.swift` to add:

```swift
public var workspaceMode: WorkspaceMode = .default
public var showCitations: Bool = false
```

Update `LiveEditorStateCodec.swift` to include both keys, defaulting if missing during decode (`workspaceMode = .default`, `showCitations = false`) so existing on-disk state stays loadable.

- [ ] **Step 4: Add setter helpers to `LiveEditorStore`**

In `LiveEditorStore.swift` add:

```swift
public func setWorkspaceMode(_ mode: WorkspaceMode) { state.workspaceMode = mode }
public func setShowCitations(_ flag: Bool) { state.showCitations = flag }
```

- [ ] **Step 5: Run tests; commit.**

```
swift test --filter WorkspaceModeTests
git add Examples/DiagramPlayground/Models/
git commit -m "playground: persist workspaceMode + showCitations on the store"
```

### Task 1.3 — Titlebar view + WorkspaceModePicker

- [ ] **Step 1: Write a UITest stub asserting the picker exists**

Create `Examples/DiagramPlayground/UITests/WorkspaceShellSmokeTests.swift`:

```swift
import XCTest

final class WorkspaceShellSmokeTests: XCTestCase {
    func test_titlebarHasModePicker() {
        let app = launchPlayground(initialState: .clean)
        XCTAssertTrue(app.buttons[A11yID.titlebarModeCode.rawValue].exists)
        XCTAssertTrue(app.buttons[A11yID.titlebarModeVisual.rawValue].exists)
        XCTAssertTrue(app.buttons[A11yID.titlebarModeSplit.rawValue].exists)
    }
}
```

- [ ] **Step 2: Add the three accessibility identifiers**

Modify `Models/A11yID.swift`:

```swift
public static let titlebarModeCode = A11yID("titlebar.mode.code")
public static let titlebarModeVisual = A11yID("titlebar.mode.visual")
public static let titlebarModeSplit = A11yID("titlebar.mode.split")
```

- [ ] **Step 3: Implement `WorkspaceModePicker`**

Create `Views/Workspace/WorkspaceModePicker.swift`:

```swift
import SwiftUI

struct WorkspaceModePicker: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 2) {
            ForEach(WorkspaceMode.allCases, id: \.self) { mode in
                Button {
                    store.setWorkspaceMode(mode)
                } label: {
                    Label(mode.label, systemImage: mode.sfSymbol)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(store.state.workspaceMode == mode
                                      ? Color.accentColor.opacity(0.18)
                                      : .clear)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(mode == .code   ? A11yID.titlebarModeCode.rawValue
                                       : mode == .visual ? A11yID.titlebarModeVisual.rawValue
                                                         : A11yID.titlebarModeSplit.rawValue)
                .disabled(mode == .visual) // Phase 3 enables this
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial))
    }
}
```

- [ ] **Step 4: Implement `TitlebarView`**

Create `Views/Workspace/TitlebarView.swift`:

```swift
import SwiftUI

struct TitlebarView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.3.group")
                .foregroundStyle(.secondary)
            Text(store.activeSample.fileName)
                .font(.system(size: 13, weight: .medium))
            if store.isDirty {
                Circle().fill(.orange).frame(width: 6, height: 6)
            }
            Spacer()
            WorkspaceModePicker(store: store)
            Spacer()
            Button {
                store.rerender()
            } label: { Image(systemName: "arrow.clockwise") }
            .keyboardShortcut("r", modifiers: .command)
            Button {
                store.beginExport()
            } label: { Image(systemName: "square.and.arrow.up") }
            .keyboardShortcut("e", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
```

- [ ] **Step 5: Run the UITest after Phase 1.5 wires the shell. For now, build only.**

```
swift build
```

- [ ] **Step 6: Commit.**

```
git add Examples/DiagramPlayground/Views/Workspace/{TitlebarView,WorkspaceModePicker}.swift Examples/DiagramPlayground/Models/A11yID.swift Examples/DiagramPlayground/UITests/WorkspaceShellSmokeTests.swift
git commit -m "playground: TitlebarView + WorkspaceModePicker"
```

### Task 1.4 — Sidebar v2 (format chips + search + tree)

- [ ] **Step 1: Failing UITest** — assert the five format chips and a search field are reachable:

```swift
func test_sidebarSurfacesFormatChips() {
    let app = launchPlayground(initialState: .clean)
    for fmt in ["mermaid","d2","dot","structurizr","plantuml"] {
        XCTAssertTrue(app.buttons["sidebar.formatChip.\(fmt)"].exists, fmt)
    }
    XCTAssertTrue(app.searchFields["sidebar.search"].exists)
}
```

- [ ] **Step 2: Add `A11yID.sidebarFormatChip(_:)` and `A11yID.sidebarSearch`.**

Add to `A11yID.swift`:

```swift
public static let sidebarSearch = A11yID("sidebar.search")
public static func sidebarFormatChip(_ format: String) -> A11yID {
    A11yID("sidebar.formatChip.\(format)")
}
```

- [ ] **Step 3: Implement `SidebarView` redesign**

Modify `Views/SidebarView.swift` to render: brand row (`DKMark`), search field bound to `store.state.sidebarSearch`, five format chips (single-select stored in `store.state.sidebarFormatFilter: SourceFormat?`), section list (Pinned / Open / Recent / Corpus shortcut / Library / Snippets). Each row drives `store.selectSample(_:)`.

Add `sidebarSearch: String = ""` and `sidebarFormatFilter: SourceFormat? = nil` to `LiveEditorState.swift`.

- [ ] **Step 4: Run smoke; commit.**

```
swift build
git add Examples/DiagramPlayground/Views/SidebarView.swift Examples/DiagramPlayground/Models/LiveEditorState.swift Examples/DiagramPlayground/Models/A11yID.swift Examples/DiagramPlayground/UITests/WorkspaceShellSmokeTests.swift
git commit -m "playground: sidebar v2 (format chips + search + tree)"
```

### Task 1.5 — Inspector multi-section accordion

- [ ] **Step 1: Failing UITest**

```swift
func test_inspectorSurfacesAllSections() {
    let app = launchPlayground(initialState: .clean)
    for id in ["inspector.section.document","inspector.section.renderBackend",
               "inspector.section.theme","inspector.section.diagnostics",
               "inspector.section.history"] {
        XCTAssertTrue(app.otherElements[id].exists, id)
    }
}
```

- [ ] **Step 2: Add `A11yID.inspectorSection(_:)`.**

- [ ] **Step 3: Implement `InspectorView`**

Create `Views/Workspace/InspectorView.swift` that hosts a `ScrollView` and stacks the five section views in order:

```swift
struct InspectorView: View {
    @Bindable var store: LiveEditorStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InspectorDocumentSection(store: store)
                InspectorRenderBackendSection(store: store)
                InspectorThemeSection(store: store)
                InspectorDiagnosticsSection(store: store)
                InspectorHistorySection(store: store)
                InspectorCitationsToggle(store: store)
            }
            .padding(16)
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }
}
```

- [ ] **Step 4: Implement each section.**

`InspectorDocumentSection.swift` — KV grid (File, Family, Format, Nodes, Edges, Layout ms, Paint ms, Bundled fonts) derived from `store.activeSample` and `store.lastRender.stats`.

`InspectorRenderBackendSection.swift` — 3-way segmented (`SVG`/`Image`/`ASCII`) bound to `store.state.renderBackend: RenderBackend`; per-backend KV grid (viewBox+exporter for SVG, dimensions+scale+`DiagramImageRenderer` for Image, cols+`AsciiRenderOutput` for ASCII); toggles for "Render on every keystroke" and "Worker thread · 8 MB stack" (read-only — pinned `true`).

`InspectorThemeSection.swift` — 4 swatch tiles for `ThemePreset` (`dark`,`light`,`forest`,`neutral`) + accent color row of seven swatches.

`InspectorDiagnosticsSection.swift` — Empty state when `store.lastRender.diagnostics.isEmpty`; otherwise list of severity icon + message + code + line + category, each row buttoned to `store.jumpToDiagnostic(_:)` which deep-links the editor.

`InspectorHistorySection.swift` — Render from `store.history.entries`, current entry highlighted, click jumps state.

`InspectorCitationsToggle.swift` — Single SwiftUI `Toggle` bound to `store.state.showCitations`.

`KPill.swift` — minimal reusable pill primitive with tones `.ok`, `.warn`, `.info`, `.accent`, `.neutral`.

- [ ] **Step 5: Add a `RenderBackend` enum.**

Add to `Models/LiveEditorConfig.swift` (or a new file `Models/Workspace/RenderBackend.swift`):

```swift
public enum RenderBackend: String, Codable, CaseIterable, Sendable {
    case svg, image, ascii
    public var label: String { rawValue.uppercased() }
}
```

- [ ] **Step 6: Build, run smoke, commit.**

```
swift build
git add Examples/DiagramPlayground/Views/Workspace/Inspector*.swift Examples/DiagramPlayground/Views/Workspace/KPill.swift Examples/DiagramPlayground/Models/Workspace/RenderBackend.swift
git commit -m "playground: Inspector v2 (Document/RenderBackend/Theme/Diagnostics/History + Citations toggle)"
```

### Task 1.6 — Statusbar

- [ ] **Step 1: Failing UITest** — assert `A11yID.statusbarBackend` exists.

- [ ] **Step 2: Implement `StatusbarView`** with segments matching the JSX: ready dot, "worker · 8 MB stack" (static), "Swift 6.3" (static, derived from `#if compiler(>=6.0)`), "fonts registered Noto Sans · Mono" (from `DiagramFontRegistry.bundledFamilies` if exposed; else hard-coded), backend chip bound to `store.state.renderBackend`, last render ms, "1044 snapshots" (read from `BaselineStats.shared` — Phase 1 lands a hard-coded constant; Phase 10 wires the real number), corpus count, current sample id (monospace).

- [ ] **Step 3: Commit.**

### Task 1.7 — PlaygroundShell + LiveEditorView delegation

- [ ] **Step 1: Implement `PlaygroundShell`** as a `Grid` (or `HStack` of three columns inside a `VStack` with Titlebar on top + Statusbar on bottom). For Phase 1 the body shows `EditorPane(store:)` only (Code mode). Sidebar visibility uses an `@AppStorage`-backed toggle.

- [ ] **Step 2: Modify `LiveEditorView`** so the macOS/iPad regular path returns `PlaygroundShell(store: store)`. The compact iOS path stays on the existing segmented layout.

- [ ] **Step 3: Build, run all Phase 1 UITests, commit.**

```
swift build
Scripts/playground-a11y-check.sh   # opt-in; record as skipped if env lacks Xcode/xcodegen
swift test --filter WorkspaceModeTests
git add Examples/DiagramPlayground/Views/Workspace/PlaygroundShell.swift Examples/DiagramPlayground/Views/LiveEditorView.swift
git commit -m "playground: hand LiveEditorView over to PlaygroundShell (Code mode)"
```

**Phase 1 done when:** Mode picker shows three options, only Code is enabled. Sidebar shows brand, search, format chips, tree. Inspector accordion shows all five sections, citations toggle present. Statusbar segments render. Existing tests (`swift test --filter PlaygroundSmoke` / etc.) stay green.

---

# Phase 2 — Split mode + Editor/Preview enhancements

**Goal:** Enable the Split-mode artboard. Editor pane gains tabs, minimap, and bidirectional selection. Preview pane gets a render-health pill, zoom group, and respects the Inspector's render-backend toggle.

**Files:**
- Modify: `Views/EditorPane.swift`
- Create: `Views/Editor/EditorTabBar.swift`
- Create: `Views/Editor/EditorMinimap.swift`
- Modify: `Views/PreviewCanvas.swift` + `Views/PreviewToolbar.swift`
- Create: `Views/Support/RenderHealthPill.swift`
- Create: `Views/Workspace/SplitDivider.swift`
- Modify: `Models/LiveEditorStore.swift` (open-tabs list, hovered line, bi-sel state)
- Test: `Tests/DiagramKitTests/Playground/BidirectionalSelectionTests.swift` (new)
- Test: `Examples/DiagramPlayground/UITests/SplitModeTests.swift` (new)

### Task 2.1 — Multi-tab editor

- [ ] **Step 1: Failing test** — `BidirectionalSelectionTests` asserts that `store.openTabs` defaults to three sample ids and `closeTab(_:)` removes one but keeps the active one alive.

- [ ] **Step 2: Add `openTabs: [String]` and `activeTabId: String` to `LiveEditorState.swift`.** Default to `["pipeline-flow","phases-timeline","phases-gantt"]`, matching the JSX `openTabIds` constant.

- [ ] **Step 3: Add `openTab(_:)`, `closeTab(_:)`, `activateTab(_:)` on `LiveEditorStore`.**

- [ ] **Step 4: Implement `EditorTabBar`** with one button per `openTab` (language-color dot, file name, `×`-close button) plus a trailing `+` button that opens a sample-picker menu. Wire to store.

- [ ] **Step 5: Modify `EditorPane`** to host `EditorTabBar` above the existing `NativeCodeEditor`.

- [ ] **Step 6: Run tests + commit.**

### Task 2.2 — Minimap

- [ ] **Step 1: Failing snapshot test** — record a `SnapshotTesting` baseline for `EditorPane` with `state.showMinimap = true`. Add this test only after the renderer exists; for the failure step, write a test that asserts `EditorPane`'s body type contains a `EditorMinimap` view.

- [ ] **Step 2: Implement `EditorMinimap`** — derives from `store.activeSourceLines` and overlays a viewport rectangle from `store.state.editorViewport`. Use `Canvas { ctx, _ in … }` for line rendering.

- [ ] **Step 3: Add `showMinimap: Bool = true` to `LiveEditorState`, surface as a toggle on the Inspector → Render-backend section.**

- [ ] **Step 4: Run snapshot to record, then re-run to confirm. Commit.**

### Task 2.3 — Bidirectional selection

- [ ] **Step 1: Failing test** — `BidirectionalSelectionTests.test_hoverLine_setsBiSelLine`:

```swift
@MainActor
@Test func hoverLineSetsBiSelLine() {
    let store = LiveEditorStore.previewing()
    store.hoverEditorLine(2)
    #expect(store.state.biSelLine == 2)
    #expect(store.state.biSelNode == "A")
}
```

- [ ] **Step 2: Add `biSelLine: Int?` + `biSelNode: String?` to `LiveEditorState`.** Add `hoverEditorLine(_:)` and `hoverPreviewNode(_:)` on the store. Both methods consult `store.activeSample.lineToNode` and `store.activeSample.nodeToLine` (precomputed at parse time from `DiagramImportResult` ranges) — add a `Models/SourceMap.swift` module that builds this map after every successful parse.

- [ ] **Step 3: Modify `NativeCodeEditor`** to call `store.hoverEditorLine(_:)` on row hover and to apply a highlight when `state.biSelLine == row`.

- [ ] **Step 4: Modify `PreviewCanvas`** so the rendered SVG nodes call `store.hoverPreviewNode(_:)` on pointer enter.

- [ ] **Step 5: Run tests + commit.**

### Task 2.4 — Render-backend toggle + RenderHealthPill (ok state)

- [ ] **Step 1: Failing UITest** — assert preview switches when backend changes:

```swift
func test_inspectorRenderBackend_switchesPreviewLabel() {
    let app = launchPlayground(initialState: .clean)
    app.buttons["inspector.renderBackend.ascii"].tap()
    XCTAssertTrue(app.staticTexts["preview.backend.ascii"].exists)
}
```

- [ ] **Step 2: Add `renderBackend: RenderBackend = .svg` to `LiveEditorState`.**

- [ ] **Step 3: Wire `PreviewCanvas`** to render via `renderDiagramSVG` / `DiagramImageRenderer` / `renderDiagramASCII` based on `store.state.renderBackend`. Show the backend label in the preview footer.

- [ ] **Step 4: Implement `RenderHealthPill`** with three constructors `.ok(layoutMs:paintMs:)`, `.slow(...)`, `.failed(error:)`. Phase 2 only renders `.ok`; slow/failed states are wired in Phase 10.

- [ ] **Step 5: Run UITest, commit.**

### Task 2.5 — Zoom group + Split-mode toggle

- [ ] **Step 1: Add `previewZoom: Double = 1.0` to state. Bound to `[0.25, 4.0]`. Buttons in `PreviewToolbar`: zoom-out, label, zoom-in, fit. Hotkeys `⌘+` / `⌘-` / `⌘0`.**

- [ ] **Step 2: Enable Split mode in `WorkspaceModePicker`** by removing the `.disabled(mode == .visual)` — leave Visual disabled for Phase 3; remove `disabled` for `.split`.

- [ ] **Step 3: In `PlaygroundShell`**, switch the body grid based on `store.state.workspaceMode`: `.code` → editor full width; `.split` → editor + preview; `.visual` → fall through to Phase 3.

- [ ] **Step 4: Run all phase tests, commit.**

**Phase 2 done when:** Split mode is selectable and shows editor + preview side-by-side. Hover-highlighting works in both directions. Render backend toggle in Inspector swaps preview surface. Zoom controls work. RenderHealthPill (ok) shows in preview header.

---

# Phase 3 — Visual mode (flowchart)

**Goal:** Implement the seven-state flowchart edit canvas from `visual.jsx`. Surface `DiagramEditor` + `FlowchartMutation` mutations through pop-overs and a state stepper.

**Files:**
- Create: `Models/Workspace/VisualEditorState.swift`
- Create: `Views/Visual/VisualPane.swift`
- Create: `Views/Visual/Flowchart/FlowchartEditCanvas.swift`
- Create: `Views/Visual/VisualToolPalette.swift`
- Create: `Views/Visual/SelectionHUD.swift`
- Create: `Views/Visual/UndoTimelineView.swift`
- Create: `Views/Visual/NodeEditPopover.swift`
- Create: `Views/Visual/EdgeEditPopover.swift`
- Create: `Views/Visual/QuickFixCard.swift`
- Create: `Views/Visual/StateStepper.swift`
- Test: `Tests/DiagramKitTests/Playground/VisualEditorStateTests.swift` (new)
- Test: `Tests/DiagramKitTests/Interactive/FlowchartLabelMutationTests.swift` (new — exercises the editor through the playground store)
- Test: `Examples/DiagramPlayground/UITests/VisualFlowchartStateTests.swift` (new)

### Task 3.1 — Bring up `DiagramEditor` in the store

- [ ] **Step 1: Failing test** — `VisualEditorStateTests.test_editorIsLazilyCreatedForCurrentSample`:

```swift
@MainActor
@Test func editorWiresToActiveSample() async throws {
    let store = LiveEditorStore.previewing()
    store.activateSample(id: "pipeline-flow")
    let editor = try #require(store.visualEditor)
    #expect(editor.document.id == "pipeline-flow")
    #expect(editor.canUndo == false)
}
```

- [ ] **Step 2: Add `visualEditor: DiagramEditor?` to `LiveEditorStore`** and instantiate it on every sample activation. Use the canonical Apple-only worker bootstrap (`DiagramEngine.bootstrap()` called from `DiagramPlaygroundApp.init`).

- [ ] **Step 3: Add `visualState: VisualEditorState.Stage` with `.idle/.nodeSelected/.labelEdited/.edgeDrag/.undone/.marquee/.subgraphCommitted` to state.**

- [ ] **Step 4: Run test + commit.**

### Task 3.2 — VisualPane shell with tool palette + selection HUD

- [ ] **Step 1: Failing UITest** — visual-mode picker is enabled; tapping it shows the canvas + tool palette identifiers.

```swift
func test_visualMode_showsToolPalette() {
    let app = launchPlayground(initialState: .visualFlow)
    app.buttons[A11yID.titlebarModeVisual.rawValue].tap()
    XCTAssertTrue(app.buttons["visual.tool.select"].exists)
    XCTAssertTrue(app.buttons["visual.tool.connector"].exists)
}
```

- [ ] **Step 2: Enable Visual mode in `WorkspaceModePicker`.** Add `seedSample(_:)` to `XCTestCase+PlaygroundLaunch` so `.visualFlow` selects `pipeline-flow`.

- [ ] **Step 3: Implement `VisualPane`** that switches on `store.activeSample.family` and dispatches to `FlowchartEditCanvas`. Layer a `VisualToolPalette`, `SelectionHUD`, and `StateStepper` on top.

- [ ] **Step 4: Implement `VisualToolPalette`** as a vertical floating strip (Select / Hand / Marquee / Connector / divider / Undo / Redo) bound to `store.visualEditor?.tool` (an enum we add: `VisualTool { case select, pan, marquee, connector }`).

- [ ] **Step 5: Implement `SelectionHUD`** — top-right accent pill showing live selection (`node:A`, `edge:G→H`, count for marquee).

- [ ] **Step 6: Run UITest + commit.**

### Task 3.3 — FlowchartEditCanvas — idle / nodeSelected / labelEdited

- [ ] **Step 1: Failing snapshot tests** — record three baselines for `FlowchartEditCanvas` in stages `.idle`, `.nodeSelected`, `.labelEdited`.

- [ ] **Step 2: Implement `FlowchartEditCanvas`** using `Canvas` (or layered `Path`s in a `ZStack`). Draw nodes from a `FlowchartScene` derived from `store.visualEditor?.document.payload`. On click, set `store.state.visualState = .nodeSelected` and `store.visualEditor?.selection = .node("A")`. Draw an accent ring + four corner handles when selected.

- [ ] **Step 3: Wire double-click to `.labelEdited`** which presents `NodeEditPopover` (Task 3.5). Committing the field calls `store.visualEditor?.perform(.setLabel(of: .node("A"), to: …))`.

- [ ] **Step 4: Record snapshots + commit.**

### Task 3.4 — EdgeDrag / Marquee / Undone stages

- [ ] **Step 1: Failing UITest** — `app.staticTexts["visual.state.edgeDrag.banner"].exists` after the connector tool drags from G to "type a label…".

- [ ] **Step 2: Implement gesture pipeline.** Adding edges fires `FlowchartMutation.insertEdge(id:from:to:label:)`. Cancelling reverts.

- [ ] **Step 3: Implement marquee selection** — drag-rect in `VisualPane`. Selected nodes become `DiagramSelection.multi([…])`. Add multi-selection support to `LiveEditorStore` (likely a `Set<String>` of node IDs + sentinel `multi` case).

- [ ] **Step 4: `Undo`** uses `store.visualEditor?.undoManager.undo()`. Verify state transitions to `.undone`.

- [ ] **Step 5: Tests + commit.**

### Task 3.5 — NodeEditPopover + EdgeEditPopover + QuickFixCard

- [ ] **Step 1: Failing snapshot tests.**

- [ ] **Step 2: Implement `NodeEditPopover`** — label field (focused when `state == .labelEdited`), sub-label, shape picker (rect / rounded / diamond / subroutine), style chips (default / ok / warn / err / muted). Footer `⌫ delete · ↵ commit`. Commit → `setLabel`; Delete → `deleteElement`.

- [ ] **Step 3: Implement `EdgeEditPopover`** — style segmented (solid/dashed/dotted), arrowhead segmented (none/→/↔), three-waypoint track (the JSX shows three; for v1 expose only an "Auto-route" reset). Commit fires `FlowchartMutation.insertEdge`.

- [ ] **Step 4: Implement `QuickFixCard`** — pulls from `store.lastRender.diagnostics` filtered by hovered line. Buttons map to documented fixes (rename / widen / wrap). Wiring back to actual mutations is best-effort: "Rename label" focuses the popover; "Widen node" sets `style: .widen` on the node payload (Phase 5 candidate); "Wrap text" inserts `<br/>` at cursor.

- [ ] **Step 5: Tests + commit.**

### Task 3.6 — UndoTimelineView + StateStepper

- [ ] **Step 1: Failing test** — feed the editor three mutations and assert `store.undoEntries` returns three entries plus a current-cursor index.

- [ ] **Step 2: Implement `LiveEditorStore.undoEntries: [UndoEntry]`** by observing `visualEditor?.undoManager`'s grouped action names. Each entry pairs `kind: UndoEntry.Kind` (`.noop / .setLabel / .insertEdge / .deleteElement / .groupIntoSubgraph`), message, timestamp.

- [ ] **Step 3: Implement `UndoTimelineView`** bottom strip (entries left→right, cursor highlighted, future dimmed).

- [ ] **Step 4: Implement `StateStepper`** — 7 numbered steps + ‹/› nav. Hidden by default; reveals with a "Demo states" toggle on the Inspector → Mutations card (Phase 10). For Phase 3 ship the stepper always-visible behind a `state.demoStepperVisible: Bool = false` (default off) to keep production UI clean — only enable in UITests.

- [ ] **Step 5: Tests + commit.**

**Phase 3 done when:** Visual mode renders the flowchart canvas. Click selects, double-click edits label, dragging from a handle starts an edge, marquee selects three nodes, undo reverts, the undo timeline reflects history. All seven stages from `visual.jsx` are reproducible by UITest.

---

# Phase 4 — Visual mode (sequence + gantt)

**Goal:** Wire the family dispatch in `VisualPane` to two more canvases — message drag for sequence diagrams and date-bar drag for gantt diagrams.

**Files:**
- Create: `Views/Visual/Sequence/SequenceEditCanvas.swift`
- Create: `Views/Visual/Gantt/GanttEditCanvas.swift`
- Test: `Examples/DiagramPlayground/UITests/VisualSequenceTests.swift`
- Test: `Examples/DiagramPlayground/UITests/VisualGanttTests.swift`

### Task 4.1 — SequenceEditCanvas

- [ ] **Step 1: Failing UITest** — `.visualSequence` initial state shows five lifelines and six messages; dragging message[2] up reorders.

- [ ] **Step 2: Implement `SequenceEditCanvas`.** Render lifeline boxes + dashed lines + message rows from `store.visualEditor?.document.payload.sequence`. Implement `SequenceMutation.move(messageId:to:)` if `DiagramEditor+Sequence.swift` does not already exist — Phase 4 stays UI-only when the mutation is missing and prints a `.lossyTransform` diagnostic banner.

- [ ] **Step 3: Drag handle ghosts the row, draws a target insertion line. Commit on release.**

- [ ] **Step 4: Tests + commit.**

### Task 4.2 — GanttEditCanvas

- [ ] **Step 1: Failing UITest** — `.visualGantt` shows the 13-row chart with a TODAY marker at week 82; dragging the right-end handle of row 8 shows a `+6w` tooltip.

- [ ] **Step 2: Implement `GanttEditCanvas`** with section bands, week ticks, today marker (from `DIAGRAMKIT_GANTT_TODAY` env var). Drag-end gesture on each bar shows a delta tooltip and on release calls `GanttMutation.resizeTask(id:end:)` (add the mutation in `DiagramKitInteractive` if missing — out-of-scope fallback: in-memory only, mark `.featureDropped(.diagramFamilyUnsupported)` in the diagnostics if user clicks "Save").

- [ ] **Step 3: Tests + commit.**

**Phase 4 done when:** Switching to a sequence sample then Visual mode shows the sequence canvas with drag-to-reorder. Same for a gantt sample.

---

# Phase 5 — Subgraph grouping (library + UI)

**Goal:** Implement the design-fiction `.groupIntoSubgraph(selections:title:)` mutation in `DiagramKitInteractive`, then wire marquee → group → commit → toast / overlay UI.

**Files:**
- Modify: `Sources/DiagramKitInteractive/DiagramEditor+Flowchart.swift`
- Create: `Sources/DiagramKitInteractive/FlowchartSubgraphMutation.swift`
- Modify: `Sources/DiagramKitInteractive/DiagramEditorError.swift` (add `.invalidSubgraphSelection`)
- Create: `Tests/DiagramKitTests/Interactive/FlowchartSubgraphMutationTests.swift`
- Create: `Views/Visual/SubgraphOverlay.swift`
- Create: `Views/Visual/SubgraphCommitToast.swift`
- Modify: `Views/Visual/MutationsCatalogCard.swift` (Phase 10) — flag this entry as no-longer-fiction

### Task 5.1 — Library mutation

- [ ] **Step 1: Failing test** — wrap three nodes from `pipeline-flow` into a subgraph called "renderers" via the editor; assert the resulting `DiagramDocument` has the expected `FlowchartGraph.subgraphs` entry and that source synthesis through `MermaidExporter` reproduces a `subgraph renderers ... end` block.

```swift
@Test func groupIntoSubgraph_wrapsThreeNodes() throws {
    let editor = try DiagramEditor.loading(samples.pipelineFlow)
    try editor.perform(.flowchart(.groupIntoSubgraph(selections: [.node("I"), .node("S"), .node("A")], title: "renderers")))
    let exported = try MermaidExporter().export(editor.document)
    #expect(exported.source.contains("subgraph renderers"))
    #expect(editor.canUndo)
    editor.undoManager.undo()
    #expect(!exported.source.contains("subgraph renderers"))
}
```

- [ ] **Step 2: Run, watch it fail at "extra argument `groupIntoSubgraph`".**

- [ ] **Step 3: Implement `FlowchartMutation.groupIntoSubgraph(selections:title:)`** as a new case. The applier wraps the named nodes in a fresh `FlowchartSubgraph` with a deterministic stable ID derived from the title slug + content hash. The inverse mutation is `flattenSubgraph(id:)`, registered through `DiagramEditor+Undo.swift`.

- [ ] **Step 4: Add `.invalidSubgraphSelection` error** for empty selection or cross-graph selection.

- [ ] **Step 5: Run test + commit.**

```
git add Sources/DiagramKitInteractive/ Tests/DiagramKitTests/Interactive/
git commit -m "interactive: FlowchartMutation.groupIntoSubgraph + flattenSubgraph inverse"
```

### Task 5.2 — Marquee → group UI flow

- [ ] **Step 1: Failing UITest** — start in `.visualFlowMarquee`, tap "Group" in the contextual toolbar, expect the toast and overlay to appear.

- [ ] **Step 2: Add a "Group" button to `VisualToolPalette`** that's enabled when `store.visualEditor?.selection` is a multi-selection. Tapping it sheets a tiny "Name this subgraph" prompt; confirm fires `groupIntoSubgraph`.

- [ ] **Step 3: Implement `SubgraphOverlay`** — dashed rect + title pill overlaid on the canvas, computed from the bounding box of the grouped node positions.

- [ ] **Step 4: Implement `SubgraphCommitToast`** — bottom-trailing transient toast with ⌘Z hint; auto-dismiss after 2.5s.

- [ ] **Step 5: Tests + commit.**

**Phase 5 done when:** Marquee-selecting 3 nodes and clicking Group commits a subgraph, the overlay shows the dashed rect, the toast appears, and `⌘Z` removes the subgraph. Library tests pass on Linux too.

---

# Phase 6 — Diagnostics drawer

**Goal:** Implement the bottom drawer with severity + category + tier + paired-with-loss facet rows, a category list grouped by severity, a scrollable row list with code/cat/source-location, and a per-row "Explain" popover.

**Files:**
- Create: `Models/Workspace/DiagnosticsDrawerState.swift`
- Create: `Views/Drawers/DiagnosticsDrawer.swift`
- Create: `Views/Drawers/DiagnosticExplainPopover.swift`
- Modify: `Models/LiveEditorStore.swift` (drawer state, filter helpers)
- Test: `Examples/DiagramPlayground/UITests/DiagnosticsDrawerTests.swift`
- Test: `Tests/DiagramKitTests/Playground/DiagnosticsFilterTests.swift`

### Task 6.1 — Drawer state + open/close

- [ ] **Step 1: Failing test** — `DiagnosticsFilterTests` defaults: `state.diagDrawerOpen = false`, severity `.all`, category `nil`, tier `nil`, paired `.all`. Toggling open flips it. Setting severity `.warn` survives a state-codec round-trip.

- [ ] **Step 2: Implement `DiagnosticsDrawerState`** and add a `diagDrawer: DiagnosticsDrawerState` substate to `LiveEditorState`. Encode/decode it.

- [ ] **Step 3: Add Statusbar button** "Diagnostics · n" that toggles the drawer.

- [ ] **Step 4: Commit.**

### Task 6.2 — Drawer layout (facets + list + explain popover)

- [ ] **Step 1: Failing UITest** — open drawer, click `.warn` chip, confirm row list filters; click `Explain` on a row, confirm popover.

- [ ] **Step 2: Implement `DiagnosticsDrawer`** as a `.bottom` sliding overlay (height ~360pt; CGRect from a `matchedGeometryEffect`). Three facet rows top, two-column body bottom — left side is the category list grouped by severity (`.lossyTransform` 13 entries, `.featureDropped` 4 entries, `.informational` 2 entries — derive counts from `DiagnosticCategory.allCases`), right side scrollable row list.

- [ ] **Step 3: Source rows from `store.allDiagnostics`** — union of parse-tier (`DiagramImportResult.diagnostics`) and layout-tier (`PositionedGraph.diagnostics`). Each row knows its `tier` enum.

- [ ] **Step 4: Implement `DiagnosticExplainPopover`** — floating card with code title, `.lossyTransform` chip, rationale prose citing `docs/diagnostic-severity-discipline.md §1`, action buttons (Rename label / Widen node / Wrap with `<br/>` / Open Sources →).

- [ ] **Step 5: Tests + commit.**

**Phase 6 done when:** Drawer slides up from below, all four facet axes filter the row list, Explain popover opens on a row, action buttons trigger the appropriate mutations or open the right `Sources/*` path in Finder via `NSWorkspace.shared.activateFileViewerSelecting(_:)`.

---

# Phase 7 — Export + Convert sheets

**Goal:** Replace `Views/ShareView.swift` with the design's full-bleed Export sheet (Render + Source target groups, per-target preview, round-trip toggle). Add the Convert sheet (Mermaid→target with `RoundTripHarness` assertion + typed `RoundTripLoss` callouts).

**Files:**
- Create: `Models/Workspace/ExportSheetState.swift`
- Create: `Models/Workspace/ConvertSheetState.swift`
- Create: `Views/Sheets/ExportSheet.swift`
- Create: `Views/Sheets/ConvertSheet.swift`
- Modify: `Views/Workspace/TitlebarView.swift` (Export button opens the sheet)
- Delete: `Views/ShareView.swift` (after parity is reached — keep for one phase)
- Test: `Examples/DiagramPlayground/UITests/ExportSheetTests.swift`
- Test: `Examples/DiagramPlayground/UITests/ConvertSheetTests.swift`
- Test: `Tests/DiagramKitTests/Playground/RoundTripIntegrationTests.swift`

### Task 7.1 — ExportSheet target list + preview

- [ ] **Step 1: Failing test** — `RoundTripIntegrationTests.test_d2Export_emitsTypedLosses`:

```swift
@Test func d2Export_yieldsTypedLosses() throws {
    let doc = try DiagramEngine.shared.parse(SampleDiagrams.pipelineFlow.source)
    let result = try ExporterRegistry.shared.export(doc, to: .d2)
    let losses = try RoundTripHarness().runSameFormat(.d2, document: doc)
    #expect(!result.diagnostics.isEmpty)
    #expect(!losses.isEmpty)
}
```

- [ ] **Step 2: Implement `ExportSheetState`** with `target: ExportTarget` (10 cases: `.svg`, `.png1x/png2x/png3x`, `.ascii`, `.mermaid`, `.d2`, `.dot`, `.structurizr`, `.plantuml`) and `rtCheck: Bool`. Persist on the state.

- [ ] **Step 3: Implement `ExportSheet`** — left aside lists targets, right pane shows live preview by switching on target (reuse `PreviewCanvas` for SVG/Image/ASCII; show `SourcePreview` for source targets). Actions: Copy / Share / Save (⌘S).

- [ ] **Step 4: Implement round-trip toggle.** When enabled, render a footer summary: "✓ paired" / "▲ 2 losses (`.styleDrop`, `.shapeDowngrade`)". Use `RoundTripHarness().runSameFormat(_:document:)`.

- [ ] **Step 5: Save target** writes via `NSSavePanel` / `UIDocumentPickerViewController` depending on platform.

- [ ] **Step 6: Tests + commit.**

### Task 7.2 — ConvertSheet (Mermaid → target with RoundTripLoss callouts)

- [ ] **Step 1: Failing test** — running convert from `pipeline-flow` to `.d2` produces a `ConvertResult` with two `RoundTripLoss` entries paired to `.styleDrop` + `.shapeDowngrade` diagnostics.

- [ ] **Step 2: Implement `ConvertSheet`** as a two-pane diff (source on left, target on right) with target-format chips and a loss list at the bottom. Each loss row shows category + message + source file citation + "Open Sources/* →" jump.

- [ ] **Step 3: Tests + commit.**

**Phase 7 done when:** `⌘E` opens the Export sheet, picking any target shows a preview, the round-trip toggle annotates pairs cleanly. The Convert sheet shows a working Mermaid→D2 diff with typed losses.

---

# Phase 8 — Coverage matrix + Corpus browser

**Goal:** Two full-window screens that replace the editor+preview body when active — a 28×5 exporter-coverage matrix and the full 422-entry corpus browser.

**Files:**
- Create: `Models/Workspace/FullScreenSurface.swift` (enum: `.none / .coverage / .corpus / .crossFormat / .probe / .snippets`)
- Create: `Models/Coverage/CoverageMatrixSeed.swift`
- Create: `Models/Coverage/CoverageMatrixProvider.swift`
- Create: `Models/Corpus/CorpusEntry.swift`
- Create: `Models/Corpus/CorpusIndex.swift`
- Create: `Views/FullWindow/CoverageMatrixView.swift`
- Create: `Views/FullWindow/CorpusBrowserView.swift`
- Create: `Views/FullWindow/CorpusThumbnail.swift`
- Modify: `Views/SidebarView.swift` (Coverage matrix + Corpus browser links pin the fullscreen)
- Test: `Tests/DiagramKitTests/Playground/CoverageMatrixSeedTests.swift`
- Test: `Tests/DiagramKitTests/Playground/CorpusIndexTests.swift`
- Test: `Examples/DiagramPlayground/UITests/CoverageMatrixTests.swift`
- Test: `Examples/DiagramPlayground/UITests/CorpusBrowserTests.swift`

### Task 8.1 — Full-screen routing

- [ ] **Step 1: Failing UITest** — tapping the Coverage row in the sidebar replaces the body with `coverage.matrix.grid`.

- [ ] **Step 2: Add `fullScreen: FullScreenSurface = .none` to state.** Update `PlaygroundShell` body to switch on it; the Sidebar + Inspector remain visible unless `fullScreen` requires the whole gutter (per JSX `gridColumn: "2 / span 3"`).

- [ ] **Step 3: Tests + commit.**

### Task 8.2 — Coverage matrix seed + provider

- [ ] **Step 1: Failing test** — `CoverageMatrixSeedTests.test_matchesJSXCounts`: 28 families × 5 formats = 140 cells; counts of `.ok`/`.lossy`/`.unsupported`/`.partial`/`.host` match the design's KPill tallies.

- [ ] **Step 2: Implement `CoverageMatrixSeed`** as a static `[CoverageCell]` table sourced verbatim from `surfaces.jsx COVERAGE` (28×5).

- [ ] **Step 3: Implement `CoverageMatrixProvider`** that probes `ExporterRegistry.shared` for each (family, format) pair and reconciles with the seed; emits a `.warning` row if any divergence between seed and registry. (Drift detector — pins us to the design.)

- [ ] **Step 4: Tests + commit.**

### Task 8.3 — CoverageMatrixView

- [ ] **Step 1: Failing snapshot test** — render `CoverageMatrixView` in light/dark; baseline.

- [ ] **Step 2: Implement `CoverageMatrixView`** with column headers (5 format chips + a host star for Mermaid), 28 family rows (glyph + family id + entry count), 140 cells. Hovering a cell shows `CoverageTip` (state title + family→format + blurb + diagnostic-category badge).

- [ ] **Step 3: Snapshot + commit.**

### Task 8.4 — CorpusIndex (loads test-diagrams.json)

- [ ] **Step 1: Failing test** — `CorpusIndexTests.test_load`: count is 422, three Linux-approximate ids appear in the approximate facet, every entry has a non-empty thumbnail family.

- [ ] **Step 2: Implement `CorpusIndex`** that decodes `Examples/DiagramPlayground/Resources/test-diagrams.json` into `[CorpusEntry]` plus precomputed facets (family / format / diag clean+warn / Linux full+approximate).

- [ ] **Step 3: Tests + commit.**

### Task 8.5 — CorpusBrowserView

- [ ] **Step 1: Failing snapshot.**

- [ ] **Step 2: Implement `CorpusBrowserView`** — header subhead ("422 entries · 28 families · 1044 baselines"), search field, four facet rows (Family chips top 12 + `all`, Format chips, Diagnostic state `clean`/`warn`, Linux `full`/`approximate`). Body is a `LazyVGrid` of `CorpusThumbnail` cards. Click selects + opens the entry in editor.

- [ ] **Step 3: Implement `CorpusThumbnail`** with per-family stylized SVG mini-thumbnails. Use `Canvas` per family; data shapes from JSX `ThumbFlow`/`ThumbSeq`/...

- [ ] **Step 4: Tests + commit.**

**Phase 8 done when:** Coverage + Corpus appear as full-window screens. Filters work. Clicking a corpus card returns to Split mode with that sample active.

---

# Phase 9 — Cross-format + Importer probe + Snippets

**Goal:** Three more full-window screens — three-format side-by-side, an importer-registry probe sequence, and a 28-pattern snippet library.

**Files:**
- Create: `Models/Probe/ImporterProbeRunner.swift`
- Create: `Models/Snippets/Snippet.swift` + `SnippetLibrary.swift`
- Create: `Resources/snippets/*.{mmd,d2,dot,dsl,puml}` (28 files)
- Create: `Views/FullWindow/ThreeFormatView.swift`
- Create: `Views/FullWindow/ImporterProbeView.swift`
- Create: `Views/FullWindow/SnippetsLibraryView.swift`
- Test: `Tests/DiagramKitTests/Playground/ImporterProbeRunnerTests.swift`
- Test: `Tests/DiagramKitTests/Playground/SnippetLibraryTests.swift`
- Test: `Examples/DiagramPlayground/UITests/ThreeFormatViewTests.swift`
- Test: `Examples/DiagramPlayground/UITests/ImporterProbeViewTests.swift`
- Test: `Examples/DiagramPlayground/UITests/SnippetsLibraryTests.swift`

### Task 9.1 — ThreeFormatView

- [ ] **Step 1: Failing snapshot.**

- [ ] **Step 2: Implement** — three columns (Mermaid / D2 / DOT), each with format pill, source `<pre>`, diagnostic list, exporter file-path footer. Header KPill "parse → export · paired ✓". Footer round-trip pill referencing `RoundTripHarness.runCrossFormatRoundTrip`.

- [ ] **Step 3: Source content** derived live by running the active flowchart through `MermaidExporter`, `D2Exporter`, `DOTExporter`.

- [ ] **Step 4: Tests + commit.**

### Task 9.2 — ImporterProbeRunner + View

- [ ] **Step 1: Failing test** — feed five sample sources through `ImporterProbeRunner`; assert the winner is `D2Importer` for D2 sample, `GraphvizImporter` for DOT sample, …, and `MermaidImporter` is last and wins only for Mermaid.

- [ ] **Step 2: Implement `ImporterProbeRunner`** that calls `ImporterRegistry.shared.probe(source:)` and exposes the ordered probe results: `[ProbeStep]` with `step.importer: String`, `step.verdict: .match / .skip / .notReached`.

- [ ] **Step 3: Implement `ImporterProbeView`** — left sample picker (5 rows), center pipeline (source `<pre>` → ordered probe list → result block), header KPill "resolved · <winner>".

- [ ] **Step 4: Tests + commit.**

### Task 9.3 — SnippetsLibrary

- [ ] **Step 1: Failing test** — `SnippetLibraryTests.test_28PatternsLoad`: 28 snippets, one per family, every snippet parses without error through `DiagramEngine.shared.parse(_:)`.

- [ ] **Step 2: Author 28 snippet files** under `Examples/DiagramPlayground/Resources/snippets/`. The JSX shows 9 displayed; populate all 28 from the family list. Each snippet is paste-ready.

- [ ] **Step 3: Implement `SnippetLibrary`** that loads `Bundle.main.urls(forResourcesWithExtension:nil)` for the snippets folder and exposes `[Snippet]` to the UI.

- [ ] **Step 4: Implement `SnippetsLibraryView`** — grid of snippet cards, search field with `⌘K`, "Insert at cursor ↵" button per card. Insert mutates `store.visualEditor?.document` or, in Code mode, inserts the snippet at the current cursor of `NativeCodeEditor`.

- [ ] **Step 5: Tests + commit.**

**Phase 9 done when:** All three new fullscreen surfaces work, and round-trip / probe / snippets data is real (not hardcoded).

---

# Phase 10 — Inspector cards, render-failed, citations, polish

**Goal:** Wire the last three Inspector accordion cards (ThemeBuilder, MutationsCatalog, Platform), surface render-health slow/failed states, ship the source-citation overlay system, and close out the design-debt list.

**Files:**
- Create: `Models/Theme/ThemeBuilderState.swift`
- Create: `Models/Mutations/MutationCatalog.swift`
- Create: `Views/Inspector/ThemeBuilderCard.swift`
- Create: `Views/Inspector/MutationsCatalogCard.swift`
- Create: `Views/Inspector/PlatformRow.swift`
- Create: `Views/Visual/RenderFailedSheet.swift`
- Create: `Views/Workspace/CitationOverlay.swift`
- Create: `Models/Workspace/CitationSet.swift` (per-screen pin tables — mirrors `CITATION_SETS` from `app.jsx`)
- Modify: `Views/Support/RenderHealthPill.swift` (slow / failed states + hover popover)
- Modify: `Examples/DiagramPlayground/UITests/AccessibilityAuditTests.swift` (extend screen list)
- Test: `Examples/DiagramPlayground/UITests/CitationsOverlayTests.swift`
- Test: `Examples/DiagramPlayground/UITests/ThemeBuilderTests.swift`
- Test: `Examples/DiagramPlayground/UITests/MutationsCatalogTests.swift`
- Test: `Examples/DiagramPlayground/UITests/RenderHealthTests.swift`

### Task 10.1 — ThemeBuilderCard

- [ ] **Step 1: Failing test** — toggling `bg` swatch changes `store.themeBuilder.overrides["bg"]` and the preview recolors. Resetting clears it.

- [ ] **Step 2: Implement `ThemeBuilderState`** with `overrides: [String: BMColor]` + `dirty: Bool`. Add to state, codec it.

- [ ] **Step 3: Implement `ThemeBuilderCard`** as an Inspector accordion with 11 token rows (`bg`/`fg`/`surface`/`border`/`line`/`accent`/`muted`/`noteBkg`/`noteBorder`/`success`/`warning`/`error` — last three flagged "sem") + 2 font rows. Each row has label + swatch + hex + reset.

- [ ] **Step 4: Drive `DiagramRenderOptions.theme`** from the override map so preview repaints with overrides applied. (No on-disk write — design-fiction note in the footer.)

- [ ] **Step 5: Tests + commit.**

### Task 10.2 — MutationsCatalogCard

- [ ] **Step 1: Failing test** — tapping "demo →" on `.setLabel` row sets `state.visualState = .labelEdited`.

- [ ] **Step 2: Implement `MutationCatalog`** — list of 8 catalog entries grouped by `document` / `node` / `edge` / `subgraph` / `sentinel`. `groupIntoSubgraph` is no-longer-fiction now (Phase 5 landed it); flag in the source comment.

- [ ] **Step 3: Implement `MutationsCatalogCard`** with "demo →" buttons that drive `state.visualState` to the target stage.

- [ ] **Step 4: Tests + commit.**

### Task 10.3 — PlatformRow

- [ ] **Step 1: Implement `PlatformRow`** with a green dot + "✓ full parity" by default; amber dot + "⚠ approximate · char-count fallback" for `ishikawa` / `treeView` / `eventModeling`. Source cite always `Sources/DiagramKitCommon/src_text_metrics.swift`.

- [ ] **Step 2: Test + commit.**

### Task 10.4 — RenderHealthPill: slow + failed

- [ ] **Step 1: Failing UITest** — force a slow render by routing through `LiveEditorStore.simulateSlowRender()`; pill shows amber `⚠` and exposes a hover popover with per-step ms.

- [ ] **Step 2: Implement `RenderHealthPill.slow(stages:[(label:String, ms:Double)])` + `.failed(error:DiagramError)`.** Hover popover renders the breakdown; the failed variant shows the error case + thrown-from origin.

- [ ] **Step 3: Implement `RenderFailedSheet`** — pulled up automatically when `store.lastRender.status == .failed`. Shows the typed `DiagramError` plus stack trace + "↻ Run on worker · 8 MB stack" action that retries `DiagramEngine._runOnWorker` (already canonical — the button just rebuilds the render request).

- [ ] **Step 4: Tests + commit.**

### Task 10.5 — Source-citation overlay system

- [ ] **Step 1: Failing UITest** — toggling `state.showCitations = true` reveals at least four `citation.pin.<n>` identifiers on the current screen.

- [ ] **Step 2: Implement `CitationSet`** — per-`(workspaceMode, fullScreen, overlay)` table of `CitationPin` records (top/left/right/side/num/label). Seed verbatim from `app.jsx CITATION_SETS`.

- [ ] **Step 3: Implement `CitationOverlay`** — a `ZStack` overlay that places `CitePin` views at absolute offsets when `state.showCitations == true`. Each pin is a numbered chip with a hover label.

- [ ] **Step 4: Wire into `PlaygroundShell`** so the overlay floats above every artboard.

- [ ] **Step 5: Tests + commit.**

### Task 10.6 — Accessibility audit extension + final cleanup

- [ ] **Step 1: Extend `AccessibilityAuditTests`** to cover the new screens: Visual flow / Visual sequence / Visual gantt / Diagnostics drawer / Export sheet / Convert sheet / Coverage / Corpus / Cross-format / Probe / Snippets / Render-failed. Each entry seeds initial state via `-uitest-state <id>` (already supported per `DiagramPlaygroundApp.init()`).

- [ ] **Step 2: Run `Scripts/playground-a11y-check.sh`** locally; record skip if env unavailable.

- [ ] **Step 3: Run all gates.**

```
swift test --filter PlaygroundSmoke
swift test --filter WorkspaceModeTests
swift test --filter VisualEditorStateTests
swift test --filter DiagnosticsFilterTests
swift test --filter CoverageMatrixSeedTests
swift test --filter CorpusIndexTests
swift test --filter ImporterProbeRunnerTests
swift test --filter SnippetLibraryTests
swift test --filter RoundTripIntegrationTests
swift test --filter FlowchartSubgraphMutationTests
Scripts/bootstrap-smoke-check.sh
```

- [ ] **Step 4: Commit.**

```
git commit -m "playground: Phase 10 — inspector cards + render-health + citations + a11y audit"
```

**Phase 10 done when:** All 14 artboards from the JSX have a Swift equivalent. Source citations toggle works on every screen. Slow + failed render states surface end-to-end. Accessibility audit passes on every screen.

---

## Cross-cutting concerns

- **A11yID hygiene** — every new actionable control adds an `A11yID` constant before the UITest is written. `Examples/DiagramPlayground/UITests/IdentifierPresenceTests.swift` ships at end of each phase with a new line per identifier.
- **Snapshot baselines** — every new view ships at least one `SnapshotTesting` baseline. Snapshots go under `Tests/DiagramKitTests/__Snapshots__/Playground/<View>.png` (image) or `<View>.svg` (vector).
- **Snippets fixtures** — Phase 9 adds 28 small text files; they belong on the `DiagramPlayground` target's resources list. Update `Examples/DiagramPlayground/project.yml`.
- **Linux portability** — the playground stays Apple-only, but every library change (Phase 5's `groupIntoSubgraph` + Phase 4's mutation candidates) must compile on Linux. Add a `LinuxPortability_GroupIntoSubgraphTests` cell in `Tests/DiagramKitLinuxTests/`.
- **Discipline gates** — `Scripts/check-file-sizes.sh` (500-line warning / 1000-line error) runs after every phase. If `LiveEditorStore.swift` grows past 1000 lines split it by concern (workspace, visual, drawer, sheet, fullscreen).
- **Strict concurrency** — every new `@Observable` model must conform to `Sendable` either naturally or with a `Concurrency Contract` banner per `Scripts/check-sendable-annotations.sh`.
- **Frequent commits** — one commit per task (each task is a logical unit) so reverting any single feature stays cheap.
- **No half-built features** — Phase N+1 cannot start until Phase N is green (`swift test --filter` for the phase suite + UITest suite). The mode-picker `.disabled` pattern lets us ship the chrome before the feature lands.

## Verification recipe

After each phase:

```
swift build
swift build --build-tests
swift test --filter <PhaseSuite>
Scripts/check-file-sizes.sh
Scripts/check-sendable-annotations.sh
Scripts/strict-concurrency-check.sh
# Optional, environment-dependent (skipped if Xcode/xcodegen unavailable):
Scripts/playground-a11y-check.sh
```

After Phase 10:

```
Scripts/bootstrap-smoke-check.sh
Scripts/rebaseline-snapshots.sh   # only if Phase 10 changed shared theme tokens
```

## Risk Register

| Risk | Mitigation |
|---|---|
| `DiagramEditor` lacks selection multi-cases for marquee | Phase 3 Task 3.4 widens `DiagramSelection` to support a `.multi(Set<DiagramSelection>)` case in the library; covered by a unit test and added to the round-trip exclusion list. |
| `FlowchartMutation.groupIntoSubgraph` doesn't survive the round trip through every exporter (DOT lacks subgraphs in our exporter) | Phase 5 Task 5.1 emits `.featureDropped(.diagramFamilyUnsupported)` from `DOTExporter` when a subgraph is present; pair test asserts diagnostics. |
| The 422-entry corpus blows up the playground startup time | `CorpusIndex.shared` is lazy; only the entry currently selected ends up materialized. The thumbnail grid uses `LazyVGrid` + on-demand `Canvas` rendering. |
| Render-health pill thrashes during fast typing | Debounce in `LiveEditorStore.rerender()` already exists; add a 250 ms minimum dwell before the pill flips from `.ok` to `.slow`. |
| Visual mode + Sequence/Gantt mutations may not all land in `DiagramKitInteractive` | Phase 4 explicitly falls back to in-memory mutations and surfaces a `.featureDropped` diagnostic when the matching library mutation is missing. |
| `playground-a11y-check.sh` fails on CI without Xcode | Per `CLAUDE.md`, record as environment-skipped — never a source failure. |

---

## Execution Handoff

Plan complete and saved to `PLAN.md`. Two execution options:

1. **Subagent-Driven (recommended)** — dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session via `superpowers:executing-plans`, batch with checkpoints.

Which approach?
