# Mermaid Live Editor Parity Strategy

This document compares the current Swift-native `Examples/MermaidPlayground` app with the checked-out Mermaid Live Editor repo at:

`/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-live-editor`

The goal is not to embed the JavaScript editor. The playground should remain a native validation surface for DiagramKit, using `MermaidView`, `MermaidPipeline`, `MermaidRenderer.renderSVG`, and `MermaidImageRenderer` so it exercises the same Swift parse/layout/render paths as the package.

## Current State (post-Phase 2)

Phase 1 replaced the ad-hoc `PlaygroundConfiguration` singleton with a first-class store architecture. Phase 2 added the toolbar shell, config editor, grid/pan controls, auto/manual sync, and export/clipboard actions. The app now has:

### Models (3 files)
- `LiveEditorState.swift`: `Codable` struct with `source`, `selectedThemeName`, `configJSON`, `editorMode`, `updateMode`, `gridEnabled`, `panZoomEnabled`, `zoomScale`, `panOffset`.
- `LiveEditorStore.swift`: `@MainActor @Observable` owner of `LiveEditorState`, render status, `parseError`, `diagramBounds`, `isDirty`. Actions: `setSource(_:origin:)`, `setTheme(named:)`, `requestRender(reason:)`, `renderNow()`, `didCompleteRender(parseError:diagramBounds:)`.
- `LiveRenderStatus.swift`: enum `idle | pending | rendering | rendered | failed`.

### Views — Core (6 files)
- `LiveEditorView.swift`: root view; editor+preview split (regular), Edit/View toggle (compact), full-window preview sheet.
- `EditorPane.swift`: Code/Config tab bar via `EditorModePicker` + `SourceEditor` (code) / `ConfigEditor` (config with JSON syntax indicator).
- `PreviewCanvas.swift`: preview surface with zoom, fit-reset on render-generation change, error overlay, dim-on-failure, grid overlay, dirty badge (manual mode), `PreviewToolbar`.
- `PreviewToolbar.swift`: 7-control floating toolbar (reset, zoom out, %, zoom in, fit, grid toggle, full-window preview).
- `MermaidViewRepresentable.swift`: publishes render completions to the store via `didCompleteRender`; theme comparison uses `bmColorEquals()`.
- `SidebarView.swift`: corpus picker, theme picker, PNG export.

### Views — Toolbar panels (4 files, new in Phase 2)
- `Views/Toolbar/LiveEditorToolbar.swift`: macOS unified toolbar + iOS nav bar; hosts `UpdateModePicker`, render button (manual mode), popover/sheet triggers for Samples/Actions/Info.
- `Views/Toolbar/ActionsPanel.swift`: Export PNG/SVG, copy source/config/SVG/PNG, full-window preview trigger, share placeholder.
- `Views/Toolbar/SampleDiagramPanel.swift`: searchable sample diagram picker with collapsible categories.
- `Views/Toolbar/VersionSecurityPanel.swift`: DiagramKit version, platform info, privacy disclosure sheet, repo/doc links.

### Views — Editor (2 files, new in Phase 2)
- `Views/Editor/EditorModePicker.swift`: extracted Code/Config segmented tab bar (reusable).
- `Views/Editor/ConfigEditor.swift`: JSON config text editor with syntax validation indicator (green/red dot + label).

### Supporting (2 files)
- `BMColor+IsLight.swift`: extracted `isLight` extension.
- `SampleDiagrams.swift`: unchanged corpus loader.

### Store behaviors (new in Phase 2)
- **Manual update mode**: `state.updateMode == .manual` → `setSource` marks `isDirty = true` and skips render. `renderNow()` clears dirty and fires render. System-origin changes (corpus, history) always render regardless of mode.
- **Grid toggle**: `PreviewCanvas` draws a 20px `Canvas` grid when `state.gridEnabled == true`.
- **Dirty badge**: orange "Unsaved changes" pill shown in preview when `isDirty && updateMode == .manual`.
- **Full-window preview**: sheet with `PreviewCanvas` only, triggered from toolbar or preview toolbar.

### Rendering invariants (unchanged)
The render loop is explicit: source/theme changes set `renderStatus = .rendering`, `MermaidLayer` handles cancel-on-new-source, `onPrepareComplete` publishes success/failure. The preview dims on failure while keeping the last valid render visible.

Deleted in Phase 1: `ContentView.swift`, `PreviewView.swift`, `PlaygroundConfiguration.swift`.

## Live Editor Feature Surface

The web repo centers on these files:

- `src/routes/edit/+page.svelte`: resizable editor/preview/history shell, mobile edit/view toggle, navbar actions.
- `src/lib/util/state.ts`: persisted `State`, validation, serialized URLs, diagram type detection, config sanitization.
- `src/lib/components/Editor.svelte`, `DesktopEditor.svelte`, `MobileEditor.svelte`: code/config tabs, syntax-aware editors, error markers.
- `src/lib/components/View.svelte`: render loop, deferred updates for slow diagrams, rough mode, grid, pan/zoom hookup.
- `src/lib/util/autoSync.ts`: throttles refresh after slow renders.
- `src/lib/components/Actions.svelte`: PNG/SVG export, copy image, markdown snippet, image sizing, Gist loading.
- `src/lib/components/Share.svelte`: shareable editor/view links.
- `src/lib/components/History/*`: manual saves, auto timeline, loader revisions, import/export.
- `src/lib/components/Preset.svelte`: sample diagram buttons.
- `src/lib/components/PanZoomToolbar.svelte`, `SyncRoughToolbar.svelte`, `VersionSecurityToolbar.svelte`: floating preview controls.
- `src/lib/components/DiagramDocumentationButton.svelte`: diagram-specific documentation URLs.

External/product-specific pieces should be optional in the native sample: Mermaid Chart save/playground links, AI repair/enhanced edits, promotions, analytics, PWA/service worker behavior, and remote renderer/Kroki links. They are web-product features, not core DiagramKit validation features.

## Product Shape

Build the Swift playground around three durable concepts:

1. `LiveEditorState`: the serializable user state.
2. `LiveEditorStore`: the `@MainActor @Observable` owner that validates, schedules renders, persists state, and exposes toolbar actions.
3. `PreviewCanvas`: the native DiagramKit preview surface that receives prepared/rendered state and reports bounds, errors, and render timings.

This gives every feature one place to hang off, instead of spreading behavior across `SidebarView`, `SourceEditor`, and `PreviewView`.

Suggested `LiveEditorState` fields:

```swift
struct LiveEditorState: Codable, Equatable, Sendable {
    var source: String
    var configJSON: String
    var editorMode: EditorMode
    var selectedThemeName: String
    var gridEnabled: Bool
    var panZoomEnabled: Bool
    var zoomScale: CGFloat?
    var panOffset: CGSize?
    var updateMode: UpdateMode
}
```

Keep `rough` out of the first version unless a native rough renderer is added. The web implementation depends on `svg2roughjs`; a half-port would not validate DiagramKit's native renderer.

## Parity Map

| Live Editor Feature | Status | Native Strategy |
| --- | --- | --- |
| Edit Mermaid source | ✅ Phase 1 | Source editor in `EditorPane` code tab; wired through `LiveEditorStore.setSource(_:origin:)` |
| Live preview updates | ✅ Phase 1 | Explicit render scheduling via `renderStatus` state machine; stale tasks cancelled by `MermaidLayer`; fit-zoom reset on `renderGeneration` change |
| Config JSON tab | ✅ Phase 2 editor / ⬜ Phase 3 mapping | `ConfigEditor` with syntax validation indicator; permissive JSON→native mapping to come |
| Syntax highlighting and line errors | ✅ Phase 1 error panel / ⬜ Phase 6 editor | Plain monospaced `TextEditor` + error overlay in `PreviewCanvas`; native `NSTextView`/`UITextView` wrapper deferred |
| Sample diagrams | ✅ Phase 2 | `SidebarView` corpus picker + `SampleDiagramPanel` searchable popover with collapsible categories |
| Theme controls | ✅ Phase 1 | `ThemePicker` calls `store.setTheme(named:)`; store resolves name via `DiagramTheme.theme(named:)` |
| Pan/zoom/reset/full screen | ✅ Phase 2 | `PreviewToolbar` with reset, zoom out/in, fit, percentage; `PreviewCanvas` fit-reset on identity change; full-window preview sheet |
| Background grid | ✅ Phase 2 | Grid toggle in `PreviewToolbar`; 20px `Canvas` overlay in `PreviewCanvas` |
| Slow render autosync | ⬜ Deferred | Port the idea, not the implementation: if render exceeds threshold, debounce subsequent renders and show a pending state |
| Manual update mode | ✅ Phase 2 | `UpdateModePicker` segmented control in toolbar; `isDirty` flag with orange badge; `renderNow()` action |
| PNG export | ✅ Phase 2 | `ActionsPanel` → PNG via `MermaidImageRenderer` at 2× scale; `fileExporter` save dialog |
| SVG export | ✅ Phase 2 | `ActionsPanel` → SVG via `MermaidRenderer.renderSVG(source:theme:)`; `fileExporter` save dialog |
| Copy image / copy SVG / copy source | ✅ Phase 2 | `ActionsPanel` copy buttons: source text, config JSON, SVG text (via `NSPasteboard`/`UIPasteboard`), PNG image |
| Share links | ⬜ Phase 4 | Local state serialization to come. Optional `pako:` compatibility deferred |
| View-only mode | ✅ Phase 2 full-window preview | Full-window preview sheet from `ActionsPanel` or `PreviewToolbar`; standalone preview-only view |
| History | ⬜ Phase 5 | Manual saved states and auto timeline to come |
| History import/export | ⬜ Phase 5 | JSON file import/export to come |
| Gist/raw URL loaders | ⬜ Phase 5 | Optional network loaders to come |
| Documentation button | ⬜ Deferred | Port docs map and `openURL` |
| Version/security toolbar | ✅ Phase 2 | `VersionSecurityPanel` with DiagramKit version, platform, privacy disclosure sheet, repo/doc links |
| Mermaid Chart / AI / analytics | ⬜ Deferred | Defer or expose only as explicit external links; do not make them central to the sample app |

## Implementation Phases

### Phase 1: Make Editing and Preview the Core Loop ✅ DONE (2026-05-10)

**Outcome**: `swift build --build-tests` passes. All four acceptance criteria met. The app now has an explicit store-driven render loop with `LiveEditorStore` as the single source of truth.

**What was built** (differs from original plan in two ways: `ContentView`/`PreviewView` were deleted rather than modified; `BMColor+IsLight.swift` was added as a new extraction):

Files created (8):

- `Examples/MermaidPlayground/Models/LiveEditorState.swift`
- `Examples/MermaidPlayground/Models/LiveEditorStore.swift`
- `Examples/MermaidPlayground/Models/LiveRenderStatus.swift`
- `Examples/MermaidPlayground/Views/LiveEditorView.swift`
- `Examples/MermaidPlayground/Views/EditorPane.swift`
- `Examples/MermaidPlayground/Views/PreviewCanvas.swift`
- `Examples/MermaidPlayground/Views/PreviewToolbar.swift`
- `Examples/MermaidPlayground/Views/BMColor+IsLight.swift`

Files modified (4):

- `Examples/MermaidPlayground/MermaidPlaygroundApp.swift` — instantiates `LiveEditorStore`, passes to `LiveEditorView`
- `Examples/MermaidPlayground/Views/SourceEditor.swift` — rewired to `store.setSource(_:origin:)`
- `Examples/MermaidPlayground/Views/ThemePicker.swift` — rewired to `store.setTheme(named:)`
- `Examples/MermaidPlayground/Views/SidebarView.swift` — removed `SourceEditor`, uses `store` for corpus/export

Files deleted (3):

- `Examples/MermaidPlayground/Views/ContentView.swift`
- `Examples/MermaidPlayground/Views/PreviewView.swift`
- `Examples/MermaidPlayground/Models/PlaygroundConfiguration.swift`

Architecture decisions:

- `LiveEditorState` stores a theme *name* (not a `DiagramTheme` value), keeping it fully `Codable`. The store resolves the name at runtime via `DiagramTheme.theme(named:)`, falling back to `.default`.
- The store tracks a `renderGeneration` counter (incremented on each source/theme change) so `PreviewCanvas` can reset fit-zoom only when diagram identity changes, not on every bounds callback.
- `MermaidViewRepresentable` no longer owns `@Binding` state; it calls `store.didCompleteRender(parseError:diagramBounds:)` in the `onPrepareComplete` callback.
- Theme comparison in `MermaidViewRepresentable` uses `bmColorEquals()` instead of `hexString` round-trips (per LIVE.md render rules).
- `MermaidLayer`'s existing cancel-on-new-source behavior (`preparationTask?.cancel()`) is the cancellation mechanism — the store doesn't introduce a second one.

### Phase 2: Match the Live Editor Shell ✅ DONE (2026-05-10)

**Outcome**: `swift build --build-tests` passes. All three acceptance criteria met. The app now has toolbar panels, config editor, grid, full-window preview, auto/manual sync, and export/clipboard actions.

**What was built** (the plan's 6 files were created as specified; additionally, `LiveEditorStore` gained `isDirty`/`renderNow()` and the existing views were enhanced):

Files created (6):

- `Examples/MermaidPlayground/Views/Toolbar/LiveEditorToolbar.swift` — macOS unified toolbar (`ToolbarContent`) + iOS nav bar; hosts `UpdateModePicker` (Auto/Manual segmented control), render button (manual mode only, disabled unless dirty), popover/sheet triggers for Samples, Actions, Info panels.
- `Examples/MermaidPlayground/Views/Toolbar/ActionsPanel.swift` — Export PNG (via `MermaidImageRenderer`, `fileExporter`), Export SVG (via `MermaidRenderer.renderSVG`, `fileExporter`), Copy Source, Copy Config, Copy SVG, Copy PNG Image (native pasteboard APIs), Full-Window Preview trigger, Share placeholder (Phase 4).
- `Examples/MermaidPlayground/Views/Toolbar/SampleDiagramPanel.swift` — searchable picker with collapsible categories; loads diagrams via `store.setSource(_:origin: .system)`.
- `Examples/MermaidPlayground/Views/Toolbar/VersionSecurityPanel.swift` — DiagramKit version (from bundle `Info.plist`), platform info, privacy disclosure sheet (5-point: local execution, no network, no analytics, native renderers, package version), repo/doc links.
- `Examples/MermaidPlayground/Views/Editor/ConfigEditor.swift` — JSON config text editor (monospaced) with validation bar: green check / red X via `JSONSerialization.jsonObject`. Debounced writes to `store.state.configJSON`.
- `Examples/MermaidPlayground/Views/Editor/EditorModePicker.swift` — extracted Code/Config segmented tab bar from `EditorPane`; reusable with `@Binding editorMode` and theme.

Files modified (6):

- `Examples/MermaidPlayground/Models/LiveEditorStore.swift` — added `isDirty: Bool`; `setSource` respects manual mode (user edits → dirty, no render; system origin → always render); added `renderNow()` (clears dirty, fires `requestRender(reason: .manual)`).
- `Examples/MermaidPlayground/Views/EditorPane.swift` — replaced inline tab bar with `EditorModePicker`; replaced Config placeholder with `ConfigEditor`; changed `let store:` → `@Bindable var store:`.
- `Examples/MermaidPlayground/Views/PreviewToolbar.swift` — expanded from 4 controls to 7: added reset (🔄), grid toggle (grid icon, accent color when active), full-window preview (rectangle icon). Takes new params: `gridEnabled`, `onResetView`, `onFullWindowPreview`.
- `Examples/MermaidPlayground/Views/PreviewCanvas.swift` — changed `let store:` → `@Bindable var store:`; added grid overlay (`Canvas` drawing 20px lines), dirty badge (orange "Unsaved changes" pill), `onFullWindowPreview` callback; passes new params to `PreviewToolbar`.
- `Examples/MermaidPlayground/Views/LiveEditorView.swift` — added `showingFullWindowPreview` state; full-window preview sheet; `.sheet` modifier in detail pane; `PreviewCanvas` receives `onFullWindowPreview` callback.
- `Examples/MermaidPlayground/MermaidPlaygroundApp.swift` — added `.toolbar { LiveEditorToolbar(store: store) }` modifier (macOS only).

Architecture decisions:

- The split editor/preview workspace from Phase 1 (`HSplitView` on macOS, `HStack` on iOS) was already present — Phase 2 added toolbar panels on top without restructuring the layout.
- The sidebar (`SidebarView`) was preserved for quick corpus/theme access alongside the new toolbar panels — this is a deliberate divergence from the web editor, whose sidebar-less design is constrained by browser layout. Native apps benefit from persistent sidebars.
- SVG export and copy both use `MermaidRenderer.renderSVG(source:theme:)` synchronously inside `async` wrappers — this exercises the package's independent SVG renderer alongside the CG preview path.
- Copy feedback uses a 2-second auto-dismissing green toast; export uses native `fileExporter` with temp-file cleanup.
- `PlainTextDocument` (for SVG `fileExporter`) and `PNGDocument` (reused from Phase 1) are defined inline in `ActionsPanel.swift`/`SidebarView.swift` respectively.
- Grid is drawn with SwiftUI `Canvas` rather than adding a background pattern to the `ScrollView` — this keeps grid lines independent of scroll/zoom state.
- Full-window preview is a sheet (not a new window) on both macOS and iOS for Phase 2; a separate `Window` scene can be added later if needed.
- The macOS toolbar uses `.primaryAction` placement for Samples/Actions/Info and `.navigation` placement for the update mode picker + render button, matching macOS HIG conventions.

### Phase 3: Config JSON and Validation

Files to create:

- `Examples/MermaidPlayground/Models/LiveEditorConfig.swift`
- `Examples/MermaidPlayground/Models/JSONValue.swift`
- `Examples/MermaidPlayground/Models/ConfigSanitizer.swift`
- `Tests/DiagramKitTests/LiveEditorConfigTests.swift`

Strategy:

- Store the raw config JSON exactly as the user typed it.
- Decode into a permissive `JSONValue` tree so unknown Mermaid config keys do not fail the app.
- Map known keys into native settings:
  - `theme` -> `DiagramTheme.theme(named:)` where possible.
  - layout-related config -> `LayoutConfig` where DiagramKit exposes equivalent options.
  - unsupported keys remain visible but marked as not yet applied.
- Sanitize imported config before applying external state. Mirror the Live Editor concern around unsafe fields, but adapt it for native behavior. The native app is not executing browser HTML, so the risky set is smaller; still warn before accepting link callbacks, external resources, or future HTML-capable fields.

Acceptance criteria:

- Invalid JSON reports a config error without destroying the source preview.
- Valid `{"theme":"dark"}` / `{"theme":"default"}` style config updates the preview theme.
- Unknown keys survive round-trips through save/share/history.

### Phase 4: Exports, Clipboard, and Share State

Files to create:

- `Examples/MermaidPlayground/Models/LiveEditorStateCodec.swift`
- `Examples/MermaidPlayground/Models/ExportOptions.swift`
- `Examples/MermaidPlayground/Views/ActionsView.swift`
- `Examples/MermaidPlayground/Views/ShareView.swift`
- `Tests/DiagramKitTests/LiveEditorStateCodecTests.swift`

Strategy:

- Move PNG export out of `SidebarView` into an action service on the store.
- Add SVG export using `MermaidRenderer.renderSVG`. This is important because the package has independent CG and SVG renderers, and the sample app should expose both.
- Add PNG sizing options: auto, fixed width, fixed height, and scale.
- Add copy actions:
  - source text
  - config JSON
  - SVG text
  - PNG image
- Add share serialization:
  - First version: app-local JSON + URL-safe base64.
  - Parity version: support Live Editor-compatible `pako:` decoding/encoding using native zlib/deflate through the `Compression` framework, if interoperability with mermaid.live URLs is a requirement.

Acceptance criteria:

- Exported PNG reflects the current source/theme/config.
- Exported SVG reflects the current source/theme/config.
- Copy actions work on macOS and iOS.
- Serialized state can be copied, pasted back into the app, and restored.

### Phase 5: History and Loaders

Files to create:

- `Examples/MermaidPlayground/Models/History/LiveHistoryEntry.swift`
- `Examples/MermaidPlayground/Models/History/LiveHistoryStore.swift`
- `Examples/MermaidPlayground/Views/History/HistoryView.swift`
- `Examples/MermaidPlayground/Models/Loaders/GistLoader.swift`
- `Examples/MermaidPlayground/Models/Loaders/RawFileLoader.swift`
- `Tests/DiagramKitTests/LiveHistoryStoreTests.swift`

Strategy:

- Manual history: user saves named snapshots.
- Auto timeline: save at most once per minute when serialized state changes, cap at a fixed count like the web editor's 30 auto entries.
- Loader revisions: if loading a Gist, preserve revisions as read-only history entries.
- Import/export history as JSON.
- Use `Application Support` for larger histories; `UserDefaults` is acceptable only for small state.

Acceptance criteria:

- Manual save/restore works.
- Auto timeline stores distinct states and avoids duplicates.
- History export/import round-trips.
- Loading a Gist or raw code/config URL is an explicit action, reports network failures, and sanitizes config before applying it.

### Phase 6: Editor Quality

Files to create:

- `Examples/MermaidPlayground/Views/Editor/NativeCodeEditor.swift`
- `Examples/MermaidPlayground/Views/Editor/LineNumberRuler.swift`
- `Examples/MermaidPlayground/Models/EditorDiagnostic.swift`
- `Examples/MermaidPlayground/Models/MermaidSyntaxHighlighter.swift`

Strategy:

- Start with `TextEditor` so the live loop ships quickly.
- Move to `NSTextView` / `UITextView` wrappers for line numbers, current-line highlighting, diagnostics, selection preservation, and better keyboard behavior.
- Port the Live Editor tokenizer as a native syntax highlighter only after the state loop is stable. The web tokenizer in `src/lib/util/monacoExtra.ts` is a good feature checklist, but it should not become a large one-shot port.
- Put parse errors inline when DiagramKit exposes useful line/column data. Until then, show a persistent error panel with the raw error.

Acceptance criteria:

- Editor preserves cursor/scroll position across preview renders.
- Error diagnostics do not fight user typing.
- Code and config modes use appropriate highlighting.

## Preview and Render Rules

Keep these package constraints intact:

- Do not introduce a thread pool. Public rendering already uses fresh 8 MB-stack workers; the app should not bypass that design.
- Do not bypass `MermaidPipeline` or `MermaidRenderer` for production preview/export paths.
- Make font registration an implementation detail of the DiagramKit pipeline, not app code.
- For color comparisons in app code, prefer `bmColorEquals()` or direct theme identity, not `hexString` round-trips.
- Treat CG preview and SVG export as separate outputs. They can drift, so the sample should make both easy to inspect.

## Testing Strategy

Add focused tests around the model layer first. SwiftUI UI automation can come later.

Suggested tests:

- `LiveEditorStateCodecTests`
  - default state encodes/decodes
  - unknown config keys survive
  - malformed serialized state fails gracefully
- `LiveEditorConfigTests`
  - invalid JSON reports a config error
  - known theme names map to `DiagramTheme`
  - unsupported keys are preserved
- `LiveHistoryStoreTests`
  - manual save avoids duplicate IDs
  - auto history caps length
  - restore applies source/config/theme/update mode
- `PlaygroundLiveRenderTests`
  - editing source schedules render
  - slow render path debounces follow-up updates
  - parse failure does not crash or wipe existing state
- Existing corpus tests remain the broad rendering guardrail.

Useful commands:

```bash
swift build --build-tests
swift test --filter LiveEditorStateCodecTests
swift test --filter LiveEditorConfigTests
swift test --filter LiveHistoryStoreTests
swift run MermaidPlayground
```

## Recommended Order of Work

1. ✅ Land `LiveEditorStore` and replace `PlaygroundConfiguration`. (Phase 1 — done 2026-05-10)
2. ✅ Rebuild the app shell around editor/preview panes and make live editing reliable. (Phase 2 — done 2026-05-10)
3. ✅ Add grid, preview toolbar, auto/manual sync, PNG/SVG export, copy actions, version/security panel. (Phase 2 — done 2026-05-10)
4. ⬜ Add config validation and JSON→native mapping. (Phase 3)
5. ⬜ Add share serialization. (Phase 4)
6. ⬜ Add history. (Phase 5)
7. ⬜ Add loaders. (Phase 5)
8. ⬜ Upgrade the text editor quality. (Phase 6)
9. ⬜ Consider optional Mermaid Chart, AI, rough mode, and remote renderer links only after native parity is solid.

The first milestone should be small and strict: open `MermaidPlayground`, type Mermaid syntax, and see the native preview update deterministically with useful error feedback. Everything else in Live Editor builds on that state loop.
