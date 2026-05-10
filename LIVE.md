# Mermaid Live Editor Parity Strategy

This document compares the current Swift-native `Examples/MermaidPlayground` app with the checked-out Mermaid Live Editor repo at:

`/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-live-editor`

The goal is not to embed the JavaScript editor. The playground should remain a native validation surface for DiagramKit, using `MermaidView`, `MermaidPipeline`, `MermaidRenderer.renderSVG`, and `MermaidImageRenderer` so it exercises the same Swift parse/layout/render paths as the package.

## Current State (post-Phase 4)

Phase 1 replaced the ad-hoc `PlaygroundConfiguration` singleton with a first-class store architecture. Phase 2 added the toolbar shell, config editor, grid/pan controls, auto/manual sync, and export/clipboard actions. Phase 3 added config JSON parsing, theme/layout extraction, sanitization, and warnings overlay. Phase 4 centralized export/copy/share into the store, added PNG sizing options, state serialization (base64url), and a share/restore UI. The app now has:

### Models (8 files)
- `LiveEditorState.swift`: `Codable` struct with `source`, `selectedThemeName`, `configJSON`, `editorMode`, `updateMode`, `gridEnabled`, `panZoomEnabled`, `zoomScale`, `panOffset`.
- `LiveEditorStore.swift`: `@MainActor @Observable` owner of `LiveEditorState`, render status, `parseError`, `diagramBounds`, `isDirty`, `parsedConfig`, `layoutConfig`, `configWarnings`, `exportOptions`. Actions: `setSource(_:origin:)`, `setTheme(named:)`, `setConfigJSON(_:)`, `requestRender(reason:)`, `renderNow()`, `didCompleteRender(parseError:diagramBounds:)`, `exportPNG(options:)`, `exportSVG()`, `copySource()`, `copyConfig()`, `copySVG()`, `copyPNGImage(options:)`, `serializedState()`, `restoreFromSerializedState(_:)`. Config parsing on init and on `setConfigJSON`; theme/layout extracted automatically.
- `LiveRenderStatus.swift`: enum `idle | pending | rendering | rendered | failed`.
- `LiveEditorConfig.swift`: parses raw config JSON into `JSONValue` tree; extracts `themeName` (fuzzy-matched to DiagramKit themes), `layoutConfig` (padding/nodeSpacing/layerSpacing/componentSpacing), and `unknownKeys` for round-trip preservation; exposes `recognizedKeyCount`/`unknownKeyCount`.
- `ConfigSanitizer.swift`: audits config tree for unsafe/unsupported keys (`securityLevel`, `htmlLabels`, prototype pollution via `__` prefix, XSS vectors via angle brackets in strings); produces `Warning` values with severity levels (unsupported/caution/info) and icon/color helpers for UI display.
- `ExportOptions.swift` (Phase 4): PNG sizing model (`auto` at scale or `fixed` CGSize); stored on the store, mutable by the export UI.
- `LiveEditorStateCodec.swift` (Phase 4): serializes `LiveEditorState` to/from a URL-safe base64-encoded JSON string using `Base64URL` from `DiagramKitModel`.
- `JSONValue.swift` (in `DiagramKitModel`): recursive `Codable` enum (`string|number|bool|null|object|array`) with key-path access, flattened representation, and round-trip fidelity — used by both the playground config parser and the package at large.
- `Base64URL.swift` (in `DiagramKitModel`, Phase 4): RFC 4648 §5 URL-safe base64 encoding/decoding; used by `LiveEditorStateCodec` and testable from `DiagramKitTests`.

### Views — Core (6 files)
- `LiveEditorView.swift`: root view; editor+preview split (regular), Edit/View toggle (compact), full-window preview sheet.
- `EditorPane.swift`: Code/Config tab bar via `EditorModePicker` + `SourceEditor` (code) / `ConfigEditor` (config with JSON syntax indicator).
- `PreviewCanvas.swift`: preview surface with zoom, fit-reset on render-generation change, error overlay, config warnings overlay, dim-on-failure, grid overlay, dirty badge (manual mode), `PreviewToolbar`.
- `PreviewToolbar.swift`: 7-control floating toolbar (reset, zoom out, %, zoom in, fit, grid toggle, full-window preview).
- `MermaidViewRepresentable.swift`: publishes render completions to the store via `didCompleteRender`; passes `store.layoutConfig` to `MermaidView.layoutConfig`; theme comparison uses `bmColorEquals()`.
- `SidebarView.swift`: corpus picker, theme picker. (PNG export moved to store/actions panel in Phase 4.)

### Views — Toolbar panels (4 files, new in Phase 2)
- `Views/Toolbar/LiveEditorToolbar.swift`: macOS unified toolbar + iOS nav bar; hosts `UpdateModePicker`, render button (manual mode), popover/sheet triggers for Samples/Actions/Info.
- `Views/Toolbar/ActionsPanel.swift`: Thin shell around `ActionsView`; owns file-exporter triggers, error alerts, and ShareView sheet. Export/copy logic delegated to store methods.
- `Views/Toolbar/SampleDiagramPanel.swift`: searchable sample diagram picker with collapsible categories.
- `Views/Toolbar/VersionSecurityPanel.swift`: DiagramKit version, platform info, privacy disclosure sheet, repo/doc links.

### Views — Editor (2 files)
- `Views/Editor/EditorModePicker.swift`: extracted Code/Config segmented tab bar (reusable).
- `Views/Editor/ConfigEditor.swift`: JSON config text editor with syntax validation indicator (green/red dot + label) and mapping summary bar (recognized/unknown key counts, theme chip).

### Views — Phase 4 (2 files)
- `Views/ActionsView.swift`: Export/copy/share button groups with PNG sizing picker (Auto/Fixed + scale/width-height controls). Delegates copy actions to store methods; export triggers to parent callbacks.
- `Views/ShareView.swift`: Displays serialized share string (selectable, copyable); paste-to-restore with error/success feedback.

### Supporting (2 files)
- `BMColor+IsLight.swift`: extracted `isLight` extension.
- `SampleDiagrams.swift`: unchanged corpus loader.

### Store behaviors (new in Phase 2)
- **Manual update mode**: `state.updateMode == .manual` → `setSource` marks `isDirty = true` and skips render. `renderNow()` clears dirty and fires render. System-origin changes (corpus, history) always render regardless of mode.
- **Grid toggle**: `PreviewCanvas` draws a 20px `Canvas` grid when `state.gridEnabled == true`.
- **Dirty badge**: orange "Unsaved changes" pill shown in preview when `isDirty && updateMode == .manual`.
- **Full-window preview**: sheet with `PreviewCanvas` only, triggered from toolbar or preview toolbar.

### Store behaviors (new in Phase 3)
- **Config parsing**: `setConfigJSON(_:)` parses the JSON through `LiveEditorConfig.parse()`, runs `ConfigSanitizer.audit()`, extracts theme name → `selectedThemeName` and layout keys → `layoutConfig`, then triggers render (auto mode) or marks dirty (manual mode).
- **Config→theme mapping**: `{"theme":"dark"}` resolves to `"Zinc Dark"`, `{"theme":"default"}` → `"Zinc Light"`, with fuzzy matching against all 17 DiagramKit built-in themes. Unknown names are preserved but don't override the theme.
- **Config→layout mapping**: top-level keys (`padding`, `nodeSpacing`, `layerSpacing`, `componentSpacing`) and nested keys (`flowchart.padding`, `config.padding`) are extracted into `LayoutConfig` and passed to `MermaidView.layoutConfig`.
- **Config warnings**: unsupported keys (`securityLevel`, `htmlLabels`), prototype-pollution patterns (`__` prefix), and XSS-like strings (`<`, `>`, `url(data:`) produce warnings displayed as a floating overlay in `PreviewCanvas`.
- **Unknown key preservation**: keys not recognized by the native mapping survive verbatim in `configJSON` and `LiveEditorConfig.unknownKeys`, ensuring round-trips through save/share/history.

### Store behaviors (new in Phase 4)
- **Export centralization**: `exportPNG(options:)` and `exportSVG()` are store methods that use `MermaidImageRenderer` (with `layoutConfig` and `ExportOptions` sizing) and `MermaidRenderer.renderSVG`. Views call these and handle file-exporter dialogs.
- **Copy centralization**: `copySource()`, `copyConfig()`, `copySVG()`, and `copyPNGImage(options:)` are store methods that write directly to `NSPasteboard`/`UIPasteboard`. Copy feedback (2-second green toast) is managed by `ActionsView`.
- **PNG sizing**: `ExportOptions` with `.auto` (diagram natural bounds × scale) or `.fixed(CGSize)`. The `ActionsView` sizing picker mutates `store.exportOptions` directly.
- **State serialization**: `LiveEditorStateCodec` encodes `LiveEditorState` to JSON + base64url (via `Base64URL` in `DiagramKitModel`). `serializedState()` and `restoreFromSerializedState(_:)` on the store wrap the codec. `restoreFromSerializedState` applies all 9 state fields and triggers a render (using `.system` origin to bypass manual-mode guard).
- **Share UI**: `ShareView` displays the serialized string (selectable text, copy button, character count) and provides a paste-to-restore input with `TextEditor` and error/success feedback.

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
| Config JSON tab | ✅ Phase 3 | `ConfigEditor` with syntax validation + mapping summary; `LiveEditorConfig` extracts theme/layout; `ConfigSanitizer` audits unsafe keys; unknown keys preserved for round-trips |
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
| Share links | ✅ Phase 4 | `LiveEditorStateCodec` → JSON + base64url; `ShareView` with copy/paste-to-restore; `pako:` deflate interop deferred to Phase 4.1 |
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

### Phase 3: Config JSON and Validation ✅ DONE (2026-05-10)

**Outcome**: `swift build --build-tests` passes. 20 new tests (13 JSONValue + 7 config extraction), all passing. Config JSON now drives theme selection and layout parameters; unknown keys survive round-trips; sanitizer audits unsafe config keys and displays warnings in the preview.

**What was built** (`JSONValue` was moved from the playground to `DiagramKitModel` so it's testable from `DiagramKitTests`; the playground types import it from there):

Files created (3 + 1 moved):

- `Sources/DiagramKitModel/JSONValue.swift` — recursive `Codable` enum (`string|number|bool|null|object|array`) with key-path subscript, `flattened()`, and round-trip fidelity. Public in `DiagramKitModel` so tests and future package code can use it.
- `Examples/MermaidPlayground/Models/LiveEditorConfig.swift` — static `parse(_:)` that decodes `JSONValue`, extracts `themeName` (with fuzzy matching: `"dark"`→`"Zinc Dark"`, `"default"`/`"light"`→`"Zinc Light"`, plus substring matching against all 17 built-in DiagramKit themes), `layoutConfig` (top-level and `flowchart.`/`config.` nested padding), and `unknownKeys` for preservation. Exposes `recognizedKeyCount`, `unknownKeyCount`, `parseError`.
- `Examples/MermaidPlayground/Models/ConfigSanitizer.swift` — `audit(_:)` checks `securityLevel` (warns on loose/antiscript), `htmlLabels` (native renderers don't support HTML labels), `__`-prefixed keys (prototype pollution, informational), and string values with `<`, `>`, or `url(data:` patterns (XSS vector, caution). `stripUnsafe(from:)` for Phase 5 imported state. `Warning.Level` enum with SF Symbol `iconName` and SwiftUI `Color` helpers.
- `Tests/DiagramKitTests/LiveEditorConfigTests.swift` — 20 tests across 2 suites: `JSONValueTests` (13 tests: decode object/array/null/bool/nested, round-trip key preservation, key-path lookup, flattened, empty/edge cases, special characters) and `LiveEditorConfigExtractionTests` (7 tests: layout defaults, top-level extraction, partial-key defaults, nested flowchart padding, unknown key preservation, theme extraction for `"dark"` and `"default"`).

Files modified (5):

- `Examples/MermaidPlayground/Models/LiveEditorStore.swift` — added `parsedConfig: LiveEditorConfig?`, `layoutConfig: LayoutConfig`, `configWarnings: [ConfigSanitizer.Warning]`; `parseConfig()` on init; `setConfigJSON(_:)` action (called by `ConfigEditor` debounced writes) that parses, sanitizes, extracts theme/layout, and triggers render or marks dirty.
- `Examples/MermaidPlayground/Views/MermaidViewRepresentable.swift` — added `layoutConfig` parameter (both `UIViewRepresentable` and `NSViewRepresentable` paths); sets `view.layoutConfig` on make and update.
- `Examples/MermaidPlayground/Views/Editor/ConfigEditor.swift` — `debounceConfigUpdate` now calls `store.setConfigJSON(newValue)` instead of writing `store.state.configJSON` directly; validation bar shows `mappingSummary` below syntax indicator with recognized/unknown key counts and theme chip.
- `Examples/MermaidPlayground/Views/PreviewCanvas.swift` — passes `layoutConfig: store.layoutConfig` to `MermaidViewRepresentable`; displays `configWarningsOverlay` (bottom-left floating panel) when `store.configWarnings` is non-empty.

Architecture decisions:

- `JSONValue` lives in `DiagramKitModel` (not the playground) because it's a general-purpose type usable beyond the sample app. The playground's `LiveEditorConfig` and `ConfigSanitizer` import it from there. Tests in `DiagramKitTests` import `DiagramKitModel` to exercise `JSONValue` directly.
- `LiveEditorConfig` keeps the raw `configJSON` string, the decoded `jsonTree`, extracted known values, and diagnostics all in one struct — the store calls `parse()` and reads the fields it needs.
- The sanitizer is read-only by default (produces warnings for UI display). The `stripUnsafe(from:)` mutation path is reserved for Phase 5 imported state (network-loaded config).
- Config→theme mapping uses a two-tier resolution: direct `DiagramTheme.theme(named:)` lookup first, then common aliases (`"dark"`, `"default"`, `"light"`), then fuzzy substring matching against all built-in theme display names.
- Config changes in manual update mode set `isDirty = true` but don't auto-render — consistent with source-editing behavior from Phase 2.
- Layout config is passed through `MermaidViewRepresentable` → `MermaidView.layoutConfig` → `MermaidLayer.layoutConfig`, exercising the full package rendering path with non-default layout parameters.

Acceptance criteria met:

- **Invalid JSON reports a config error without destroying the source preview**: `LiveEditorConfig.parse()` returns `parseError` without throwing; store sets `parsedConfig = nil`; last valid render persists.
- **Valid `{"theme":"dark"}` updates the preview theme**: `extractTheme` resolves `"dark"` → `"Zinc Dark"`; store calls `setTheme(named:)` which triggers render.
- **Unknown keys survive round-trips**: raw `configJSON` string is stored as-typed; `LiveEditorConfig.unknownKeys` preserves unrecognized keys; `ConfigSanitizer` audits but doesn't strip them.

### Phase 4: Exports, Clipboard, and Share State ✅ DONE (2026-05-10)

**Outcome**: `swift build --build-tests` passes clean (no warnings). 14 new tests (`Base64URLTests`), all passing. Export/copy/share logic centralized in the store; PNG sizing options added; state serialization with share/restore UI.

**What was built**:

Files created (4 playground + 1 DiagramKitModel + 1 test):

- `Sources/DiagramKitModel/Base64URL.swift` — RFC 4648 §5 URL-safe base64 codec. Lives in `DiagramKitModel` (like `JSONValue`) so it's testable from `DiagramKitTests` without playground dependencies.
- `Examples/MermaidPlayground/Models/LiveEditorStateCodec.swift` — wraps `Base64URL` with JSON encode/decode of `LiveEditorState`. Three `CodecError` cases: `invalidBase64`, `invalidJSON`, `invalidState`.
- `Examples/MermaidPlayground/Models/ExportOptions.swift` — PNG sizing model: `.auto` (diagram bounds × scale) or `.fixed(CGSize)`. Conforms to `Hashable` for `Picker` `.tag()`.
- `Examples/MermaidPlayground/Views/ActionsView.swift` — extracted export/copy/share UI from `ActionsPanel`. PNG sizing picker (Auto/Fixed + scale/width-height controls). Delegates copy actions to store methods; export triggers to parent callbacks.
- `Examples/MermaidPlayground/Views/ShareView.swift` — displays serialized share string (selectable, copyable, character count); paste-to-restore `TextEditor` with error/success feedback.
- `Tests/DiagramKitTests/LiveEditorStateCodecTests.swift` — 14 tests: round-trips (empty, simple, binary, 10 KB), URL-safe charset, padding edge cases, invalid input, standard base64 interop.

Files modified (3):

- `Examples/MermaidPlayground/Models/LiveEditorStore.swift` — added `exportOptions` property, 9 new methods: `exportPNG(options:)`, `exportSVG()`, `copySource()`, `copyConfig()`, `copySVG()`, `copyPNGImage(options:)`, `serializedState()`, `restoreFromSerializedState(_:)`; `ExportError` enum. Platform pasteboard/PNG conversion logic lives here.
- `Examples/MermaidPlayground/Views/Toolbar/ActionsPanel.swift` — collapsed from ~400 lines to ~170. Now a thin shell: hosts `ActionsView`, owns `fileExporter` modifiers, `Export Failed` alert, and `ShareView` sheet trigger.
- `Examples/MermaidPlayground/Views/SidebarView.swift` — removed duplicate PNG export button (~70 lines deleted, `IssueReporting` and file-exporter state removed). Keeps corpus picker and theme picker.

Architecture decisions:

- **Export/copy centralized in the store**: views call `store.exportPNG(options:)` / `store.copySource()` etc. The store owns rendering calls, pasteboard writes, and temp-file management. This keeps views thin and the store testable.
- **`Base64URL` in `DiagramKitModel`** follows the same pattern as `JSONValue` — usable beyond the playground and testable from `DiagramKitTests`.
- **`restoreFromSerializedState` applies all 9 state fields** (source, theme, config, editorMode, gridEnabled, panZoomEnabled, zoomScale, panOffset, updateMode) and triggers a render — but gates on `applied`, so restoring identical state is a no-op.
- **pako:/Compression.framework deferred** to Phase 4.1. The LIVE.md spec marks it optional ("if interoperability with mermaid.live URLs is a requirement"). Current format is app-local JSON+base64url.
- **PNG export routes through `MermaidImageRenderer` with `layoutConfig`**: exports reflect the config-driven layout parameters, not just the source+theme.

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

- `LiveEditorStateCodecTests` ✅ (14 tests, passing)
  - Base64URL round-trip: empty, simple, binary, 10 KB
  - URL-safe charset verification (no +/=/ in output)
  - Padding edge cases (1-char, 2-char, 3-char inputs)
  - Invalid base64 throws expected error
  - Standard base64 interop (accepts padded input)
- `LiveEditorConfigTests` ✅ (20 tests, passing)
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
4. ✅ Add config validation and JSON→native mapping. (Phase 3 — done 2026-05-10)
5. ✅ Add share serialization. (Phase 4 — done 2026-05-10)
6. ⬜ Add history. (Phase 5)
7. ⬜ Add loaders. (Phase 5)
8. ⬜ Upgrade the text editor quality. (Phase 6)
9. ⬜ Consider optional Mermaid Chart, AI, rough mode, and remote renderer links only after native parity is solid.

The first milestone should be small and strict: open `MermaidPlayground`, type Mermaid syntax, and see the native preview update deterministically with useful error feedback. Everything else in Live Editor builds on that state loop.