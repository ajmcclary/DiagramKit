# Mermaid Live Editor Parity Strategy

This document compares the current Swift-native `Examples/MermaidPlayground` app with the checked-out Mermaid Live Editor repo at:

`/Users/ajmcclary/Dev/Research/DiagramKit/mermaid-live-editor`

The goal is not to embed the JavaScript editor. The playground should remain a native validation surface for DiagramKit, using `MermaidView`, `MermaidPipeline`, `MermaidRenderer.renderSVG`, and `MermaidImageRenderer` so it exercises the same Swift parse/layout/render paths as the package.

## Current State

The Swift app already has a useful base:

- `ContentView.swift`: `NavigationSplitView` layout with sidebar and preview.
- `PlaygroundConfiguration.swift`: singleton `@Observable` state with `source` and `theme`.
- `SourceEditor.swift`: debounced `TextEditor` bound to `config.source`.
- `PreviewView.swift`: native preview, fit-to-view zoom, error overlay, `MermaidViewRepresentable`.
- `SidebarView.swift`: corpus picker, theme picker, PNG export.
- `SampleDiagrams.swift`: bundled corpus loader for `Resources/test-diagrams.json`.

The missing piece is not just another text field. Mermaid Live Editor has a single state system that drives editor text, config JSON, validation, preview rendering, URL serialization, history, exports, pan/zoom, samples, and loaders. The Swift app should move from `PlaygroundConfiguration` as a tiny settings object to a first-class playground store with an explicit render loop.

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

| Live Editor Feature | Current Swift App | Native Strategy |
| --- | --- | --- |
| Edit Mermaid source | Basic `TextEditor` exists | Promote to code tab in an editor pane; wire through `LiveEditorStore.updateSource` |
| Live preview updates | Present but informal | Make render scheduling explicit; cancel stale tasks; reset fit zoom on source/config changes |
| Config JSON tab | Missing | Add config editor with permissive JSON validation and mapping into `DiagramTheme` / `LayoutConfig` / future render config |
| Syntax highlighting and line errors | Missing | Phase 1: plain monospaced editor + error panel. Phase 2: native `NSTextView` / `UITextView` wrapper with line numbers, highlights, and diagnostics |
| Sample diagrams | Corpus picker exists | Keep corpus source of truth; add compact sample buttons/search matching Live Editor ergonomics |
| Theme controls | Theme picker exists | Reconcile Live Editor `theme` JSON with `DiagramTheme.theme(named:)`; keep native theme picker as direct control |
| Pan/zoom/reset/full screen | Partial zoom exists | Add preview toolbar for reset, zoom in/out, fit, natural size, pan enable, full-window preview |
| Background grid | Missing | Add grid toggle in preview canvas background |
| Slow render autosync | Missing | Port the idea, not the implementation: if render exceeds threshold, debounce subsequent renders and show a pending state |
| Manual update mode | Missing | Add auto/manual segmented control; manual mode sets dirty flag and renders only on command |
| PNG export | Basic PNG export exists | Move to `LiveEditorStore.exportPNG`, add size mode: auto, width, height, scale |
| SVG export | Missing | Use `MermaidRenderer.renderSVG(from:theme:)` so SVG parity is exercised |
| Copy image / copy SVG / copy source | Missing | Use native pasteboard APIs (`NSPasteboard` / `UIPasteboard`) |
| Share links | Missing | Add local state serialization. Optional: make the codec compatible with Mermaid Live Editor `pako:` URLs |
| View-only mode | Missing | Add a preview-only window/sheet/scene that loads serialized state |
| History | Missing | Add manual saved states and auto timeline using `Application Support` or `UserDefaults` for small payloads |
| History import/export | Missing | Import/export JSON files through native file dialogs |
| Gist/raw URL loaders | Missing | Add as optional network loaders with explicit user action and config sanitization |
| Documentation button | Missing | Port the docs map and open URLs via `openURL` |
| Version/security toolbar | Missing | Show DiagramKit version and a local privacy/security sheet describing native/offline behavior |
| Mermaid Chart / AI / analytics | Missing | Defer or expose only as explicit external links; do not make them central to the sample app |

## Implementation Phases

### Phase 1: Make Editing and Preview the Core Loop

Files to create:

- `Examples/MermaidPlayground/Models/LiveEditorState.swift`
- `Examples/MermaidPlayground/Models/LiveEditorStore.swift`
- `Examples/MermaidPlayground/Models/LiveRenderStatus.swift`
- `Examples/MermaidPlayground/Views/LiveEditorView.swift`
- `Examples/MermaidPlayground/Views/EditorPane.swift`
- `Examples/MermaidPlayground/Views/PreviewCanvas.swift`
- `Examples/MermaidPlayground/Views/PreviewToolbar.swift`

Files to modify:

- `Examples/MermaidPlayground/MermaidPlaygroundApp.swift`
- `Examples/MermaidPlayground/Views/ContentView.swift`
- `Examples/MermaidPlayground/Views/SourceEditor.swift`
- `Examples/MermaidPlayground/Views/PreviewView.swift`
- `Examples/MermaidPlayground/Views/MermaidViewRepresentable.swift`
- `Examples/MermaidPlayground/Models/PlaygroundConfiguration.swift`

Strategy:

- Replace `PlaygroundConfiguration.shared` as the root app object with `LiveEditorStore`.
- Keep `PlaygroundConfiguration` only as a compatibility shim during migration, or delete it once the new store owns `source` and `theme`.
- Move source updates through methods such as `setSource(_:origin:)`, `setTheme(_:)`, and `requestRender(reason:)`.
- Track render status: idle, pending, rendering, rendered, failed.
- Cancel stale preview work when source/config changes.
- Reset fit zoom only when diagram identity changes, not on every bounds callback.
- Keep using `MermaidViewRepresentable`/`MermaidDiagramView` rather than reimplementing drawing in SwiftUI.

Acceptance criteria:

- Typing in the editor updates the preview after a short debounce.
- Loading a corpus sample replaces editor text and rerenders.
- A syntax error leaves the last valid preview dimmed or unchanged and shows a clear error panel.
- Clearing the editor clears the preview without crashing.
- `swift build --build-tests` succeeds.

### Phase 2: Match the Live Editor Shell

Files to create:

- `Examples/MermaidPlayground/Views/Toolbar/LiveEditorToolbar.swift`
- `Examples/MermaidPlayground/Views/Toolbar/ActionsPanel.swift`
- `Examples/MermaidPlayground/Views/Toolbar/SampleDiagramPanel.swift`
- `Examples/MermaidPlayground/Views/Toolbar/VersionSecurityPanel.swift`
- `Examples/MermaidPlayground/Views/Editor/ConfigEditor.swift`
- `Examples/MermaidPlayground/Views/Editor/EditorModePicker.swift`

Strategy:

- Replace the sidebar-first layout with a split editor/preview workspace on macOS and iPad.
- Use tabs or a segmented control for `Code` and `Config`.
- Preserve the compact iPhone flow: edit/view toggle with preview as a first-class screen, not a controls sheet only.
- Add a preview toolbar: reset view, zoom out, zoom in, fit, full-window preview, grid toggle.
- Add an auto/manual update control. Manual mode should show dirty state and an explicit render button.

Acceptance criteria:

- The default screen is an editor plus preview workspace on regular width.
- The compact screen can both edit and preview without burying editing in a control sheet.
- Config tab edits are validated independently from Mermaid source edits.

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

1. Land `LiveEditorStore` and replace `PlaygroundConfiguration`.
2. Rebuild the app shell around editor/preview panes and make live editing reliable.
3. Add config tab and validation.
4. Move existing PNG export into the new action model; add SVG export.
5. Add grid, preview toolbar, and auto/manual sync.
6. Add share serialization.
7. Add history.
8. Add loaders.
9. Upgrade the text editor quality.
10. Consider optional Mermaid Chart, AI, rough mode, and remote renderer links only after native parity is solid.

The first milestone should be small and strict: open `MermaidPlayground`, type Mermaid syntax, and see the native preview update deterministically with useful error feedback. Everything else in Live Editor builds on that state loop.
