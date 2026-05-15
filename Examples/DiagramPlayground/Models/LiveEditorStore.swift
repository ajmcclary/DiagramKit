//
//  LiveEditorStore.swift
//  DiagramPlayground
//
//  Central @MainActor @Observable store that owns the serializable
//  LiveEditorState, tracks render lifecycle, and exposes actions for
//  every UI interaction (source edits, theme changes, render requests,
//  exports, clipboard operations, and state sharing).
//

import SwiftUI
import DiagramKit
import DiagramKitExport
import DiagramKitImport
import DiagramKitInteractive
import DiagramKitModel
import IssueReporting

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - LiveEditorStore

/// Single source of truth for the live editor.
///
/// Instantiated once in `DiagramPlaygroundApp` and passed through the
/// view hierarchy via the environment or direct binding. Replaces the
/// former `PlaygroundConfiguration` singleton.
@MainActor
@Observable
@available(iOS 26.0, macOS 26.0, macCatalyst 26.0, *)
public final class LiveEditorStore {

    // MARK: - Serialized state

    /// The full user-facing state (source, theme name, config, view prefs).
    public var state: LiveEditorState

    // MARK: - Runtime render state

    /// Where the current render is in its lifecycle.
    public var renderStatus: LiveRenderStatus = .idle

    /// The last parse/layout error (nil when the latest render succeeded).
    public var parseError: Error?

    /// The bounds of the most recently rendered diagram.
    public var diagramBounds: CGRect = .zero

    /// Source text currently committed to the preview surface.
    ///
    /// In automatic update mode this tracks ``state/source`` immediately. In
    /// manual mode it stays pinned to the last rendered source until
    /// ``renderNow()`` commits the pending editor state.
    public private(set) var previewSource: String

    /// Theme name currently committed to the preview surface.
    public private(set) var previewThemeName: String

    /// Layout configuration currently committed to the preview surface.
    public private(set) var previewLayoutConfig: LayoutConfig

    /// Full editor state from the last completed render. Used by
    /// `didCompleteRender(...)` to decide what to auto-save.
    private var previewState: LiveEditorState

    /// Snapshot of `state` taken at the most recent `requestRender(...)`.
    /// Promoted into `previewState` by `didCompleteRender(...)` on success
    /// so the auto-saved snapshot reflects the source/theme/config that
    /// was actually rendered, not whatever the user has typed since. The
    /// race against late layer events (uncancelled in-flight renders) is
    /// out of scope here — this only narrows the interim-keystroke race.
    private var pendingRenderState: LiveEditorState?

    /// Origin of the most recent `setSource(...)` call. Used by
    /// `didCompleteRender(...)` to decide whether to re-seed the
    /// persistent `DiagramEditor` from the new source — a structural
    /// mutation already produced the new source, so re-seeding would
    /// throw away the editor's undo history.
    private var lastSourceOrigin: SourceOrigin = .system

    // MARK: - Config (Phase 3)

    /// Parsed representation of the current `state.configJSON`.
    /// Nil when the JSON is invalid or empty.
    public private(set) var parsedConfig: LiveEditorConfig?

    /// Layout parameters extracted from config JSON.
    public private(set) var layoutConfig: LayoutConfig = LayoutConfig()

    /// Sanitizer warnings from the current config (empty = clean).
    public private(set) var configWarnings: [ConfigSanitizer.Warning] = []

    // MARK: - Diagnostics (Phase 6)

    /// Unified diagnostics from parse errors and config warnings.
    ///
    /// Computed on access from the current ``parseError`` (extracting
    /// line/column where possible) and ``configWarnings``. Empty when
    /// the last render succeeded and config is clean.
    public var diagnostics: [EditorDiagnostic] {
        var result: [EditorDiagnostic] = []

        if let error = parseError {
            result.append(contentsOf: EditorDiagnostic.from(error: error, source: .parse))
        }

        for warning in configWarnings {
            result.append(EditorDiagnostic.from(warning: warning))
        }

        return result
    }

    // MARK: - Export options (Phase 4)

    /// PNG export parameters. Mutable by the export UI.
    public var exportOptions: ExportOptions = ExportOptions()

    // MARK: - History (Phase 5)

    /// History store for manual saves, auto timeline, and loader entries.
    public let historyStore: LiveHistoryStore

    // MARK: - Interactive editor (Phase 7)

    /// Persistent DiagramEditor. Re-seeded from `state.source` on every
    /// successful parse; nil until at least one render has succeeded.
    ///
    /// Undo/redo state is Observation-tracked on `DiagramEditor` directly
    /// (`editor?.canUndo`, `editor?.canRedo`, `editor?.undoActionName`,
    /// `editor?.redoActionName`). View modifiers should read those rather
    /// than going through the store.
    public private(set) var editor: DiagramEditor?

    /// Mirrors what `DiagramView` publishes for the current preview source.
    /// Used by the canvas tap dispatch and the selection overlay.
    public var boundsLookup: DiagramBoundsLookup?

    // MARK: - Derived

    /// Resolved theme from ``LiveEditorState/selectedThemeName``.
    /// Falls back to `.default` when the name is unrecognized.
    public var theme: DiagramTheme {
        DiagramTheme.theme(named: state.selectedThemeName) ?? .default
    }

    /// Resolved theme for the committed preview snapshot.
    public var previewTheme: DiagramTheme {
        DiagramTheme.theme(named: previewThemeName) ?? .default
    }

    /// Incremented every time source or theme changes.
    /// Used by the preview to decide when to reset fit-to-view zoom.
    public private(set) var renderGeneration: Int = 0

    /// Whether the source has unsaved changes in manual update mode.
    /// Resets to `false` when the user clicks Render.
    public var isDirty: Bool = false

    // MARK: - Init

    public init(state: LiveEditorState = LiveEditorState()) {
        self.state = state
        self.previewSource = state.source
        self.previewThemeName = state.selectedThemeName
        self.previewLayoutConfig = LayoutConfig()
        self.previewState = state
        self.historyStore = LiveHistoryStore()
        parseConfig()
        commitCurrentStateToPreview()
    }

    // MARK: - Config parsing

    /// Parse the current `state.configJSON`, extract known settings,
    /// and apply them to the store's runtime state.
    @discardableResult
    private func parseConfig() -> Bool {
        let previousThemeName = state.selectedThemeName
        let previousLayoutConfig = layoutConfig

        let config = LiveEditorConfig.parse(state.configJSON)
        var applied = config
        applied.warnings = ConfigSanitizer.audit(config.jsonTree)
        parsedConfig = config.parseError == nil ? applied : nil
        configWarnings = applied.warnings
        layoutConfig = applied.layoutConfig

        // Apply config-driven theme to the editable state without requesting
        // a render. The caller decides whether this is an automatic render or
        // a dirty manual edit.
        if let themeName = applied.themeName, themeName != state.selectedThemeName {
            state.selectedThemeName = themeName
        }

        return previousThemeName != state.selectedThemeName || previousLayoutConfig != layoutConfig
    }

    // MARK: - Source / Theme / Config actions

    /// Update the diagram source and schedule a render.
    ///
    /// - Parameters:
    ///   - source: New diagram source text.
    ///   - origin: Where the change came from (user typing, system, history, loader).
    public func setSource(_ source: String, origin: SourceOrigin) {
        guard state.source != source else { return }
        state.source = source
        lastSourceOrigin = origin

        // Non-user sources (sample picker, remote loader) drop a fresh diagram in;
        // reset preview transform so it auto-fits instead of inheriting the previous
        // diagram's zoom and pan. Mutation-origin changes preserve the existing
        // zoom/pan because the user is mid-edit on the same diagram.
        if origin == .system || origin == .loader {
            state.zoomScale = nil
            state.panOffset = nil
        }

        // The user is editing a fresh document — drop any stale corpus
        // metadata from a previous sample-picker load so "expected
        // diagnostics" hints don't follow them across diagrams.
        if origin == .user || origin == .loader {
            loadedCorpusMetadata = nil
        }

        if state.updateMode == .manual && origin == .user {
            // In manual mode, mark dirty but don't render automatically.
            // System-origin changes (corpus, history) always trigger a render.
            isDirty = true
            return
        }

        requestRender(reason: .sourceChanged)
    }

    /// Update the active source format and schedule a render.
    ///
    /// Used by the format picker. The source text is unchanged — callers
    /// that want to swap source and format atomically should use
    /// ``setSource(_:format:origin:)``.
    public func setSourceFormat(_ format: SourceFormat) {
        guard state.sourceFormat != format else { return }
        state.sourceFormat = format
        // Re-render: the same text is now parsed through the selected format.
        requestRender(reason: .sourceChanged)
    }

    /// Update the source text and format together.
    ///
    /// - Parameters:
    ///   - source: New diagram source text.
    ///   - format: Format of the new source.
    ///   - origin: Where the change came from.
    public func setSource(_ source: String, format: SourceFormat, origin: SourceOrigin) {
        let formatChanged = state.sourceFormat != format
        let sourceChanged = state.source != source
        guard formatChanged || sourceChanged else { return }

        state.source = source
        state.sourceFormat = format
        lastSourceOrigin = origin

        if origin == .system || origin == .loader {
            state.zoomScale = nil
            state.panOffset = nil
        }

        if origin == .user || origin == .loader {
            loadedCorpusMetadata = nil
        }

        if state.updateMode == .manual && origin == .user {
            isDirty = true
            return
        }

        requestRender(reason: .sourceChanged)
    }

    /// Update the theme by display name.
    ///
    /// The name is resolved via `DiagramTheme.theme(named:)` when the
    /// computed ``theme`` property is read. Unknown names are silently
    /// stored and fall back to `.default` at render time.
    public func setTheme(named name: String) {
        guard state.selectedThemeName != name else { return }
        state.selectedThemeName = name

        if state.updateMode == .manual {
            isDirty = true
            return
        }

        requestRender(reason: .themeChanged)
    }

    /// Update the config JSON and re-parse.
    ///
    /// Called by ``ConfigEditor`` on debounced changes.
    public func setConfigJSON(_ json: String) {
        guard state.configJSON != json else { return }
        state.configJSON = json
        parseConfig()

        if state.updateMode == .auto {
            requestRender(reason: .sourceChanged)
        } else {
            isDirty = true
        }
    }

    /// Explicitly request a render (e.g. from manual update mode).
    public func requestRender(reason: RenderReason) {
        commitCurrentStateToPreview()
        // Snapshot the state we're requesting a render for; the eventual
        // `didCompleteRender(...)` promotes this into `previewState` so the
        // auto-save reflects what was actually rendered, not what the user
        // has typed since the request was issued.
        pendingRenderState = state
        renderGeneration &+= 1
        renderStatus = .rendering
        // Clear any stale parseError — leaving it set would draw the
        // overlay atop a fresh render until completion. The eventual
        // `didCompleteRender(...)` reassigns from the layer's actual
        // post-parse state.
        parseError = nil
    }

    /// Trigger a render in manual update mode.
    /// Clears the dirty flag and schedules a render.
    public func renderNow() {
        guard state.updateMode == .manual, isDirty else { return }
        isDirty = false
        requestRender(reason: .manual)
    }

    /// Forwarded from `DiagramView`'s `parseError` and `diagramBounds`
    /// bindings when the underlying layer finishes preparing (parse +
    /// layout complete, success or failure). The store mirrors the
    /// values and updates `renderStatus` accordingly.
    public func didCompleteRender(parseError: Error?, diagramBounds: CGRect) {
        self.parseError = parseError
        self.diagramBounds = diagramBounds

        if parseError != nil {
            // Keep the last valid preview visible alongside the error.
            renderStatus = .failed
            // Discard the snapshot — a failed render shouldn't seed the
            // auto-save state next time around.
            pendingRenderState = nil
        } else if state.source.isEmpty {
            renderStatus = .idle
            editor = nil
            pendingRenderState = nil
        } else {
            renderStatus = .rendered
            // Skip re-seeding when the source change originated from a
            // structural mutation — `performMutation` already updated the
            // editor's document in-place, and replacing the editor would
            // discard its `UndoManager` stack.
            if lastSourceOrigin != .mutation {
                seedEditorFromSource()
            }
            // Promote the snapshot taken at requestRender time into
            // previewState so the auto-save reflects what was actually
            // rendered, not whatever has been typed since.
            if let snapshot = pendingRenderState {
                previewState = snapshot
                pendingRenderState = nil
            }
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
                let document = try await DiagramEngine.parse(
                    self.state.source,
                    as: self.state.sourceFormat.formatID
                )
                await self.applySeededEditor(document: document)
            } catch {
                // Parse failures are already surfaced via parseError; leave
                // the existing editor in place so structural undo state isn't
                // destroyed by a transient text-edit-in-progress.
            }
        }
    }

    /// Apply a freshly-parsed document to the persistent editor.
    private func applySeededEditor(document: DiagramDocument) async {
        let previousSelection = editor?.selection
        let formatID = state.sourceFormat.formatID

        let newEditor = DiagramEditor(
            document: document,
            preferredExportFormat: formatID,
            exportRegistry: DiagramPipeline.defaultExportRegistry
        )
        try? await newEditor.syncSource()

        // Best-effort selection restore. If a lookup is current, validate the
        // element still exists. Otherwise, preserve the same DiagramSelection
        // verbatim when the document type still matches — a later tap or
        // render cycle will clear stale selection if the element was removed.
        if let previousSelection {
            if let lookup = boundsLookup,
               let restored = lookup.selection(for: previousSelection.elementID) {
                newEditor.selection = restored
            } else if previousSelection.diagramType == document.type {
                newEditor.selection = previousSelection
            } else {
                newEditor.selection = nil
            }
        }

        editor = newEditor
    }

    // MARK: - Preview transform

    /// Persist the current preview zoom scale in serializable editor state.
    public func setPreviewZoomScale(_ scale: CGFloat?) {
        state.zoomScale = scale
    }

    /// Persist the current preview pan offset in serializable editor state.
    public func setPreviewPanOffset(_ offset: CGSize?) {
        state.panOffset = offset
    }

    // MARK: - Export (Phase 4)

    /// Export the current diagram as a PNG image to a temporary file.
    ///
    /// - Parameter options: Sizing and scale parameters.
    /// - Throws: Rendering or file I/O errors.
    /// - Returns: The URL of the temporary PNG file (caller cleans up).
    public func exportPNG(options: ExportOptions) async throws -> URL {
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.layoutConfig = layoutConfig
        renderer.sourceFormat = state.sourceFormat.formatID

        let image: BMImage?
        switch options.sizing {
        case .auto:
            image = try await renderer.renderImage(from: state.source, scale: options.scale)
        case .fixed(let size):
            image = try await renderer.renderImage(from: state.source, size: size)
        }

        guard let image else {
            throw ExportError.renderFailed
        }

        guard let pngData = platformPNGData(from: image) else {
            throw ExportError.pngConversionFailed
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "diagram-\(Int(Date().timeIntervalSince1970)).png"
        let tempURL = tempDir.appendingPathComponent(fileName)
        try pngData.write(to: tempURL)

        return tempURL
    }

    /// Export the current diagram as an SVG string.
    ///
    /// - Throws: Rendering errors.
    /// - Returns: The SVG markup string.
    public func exportSVG() async throws -> String {
        try await DiagramEngine.renderSVG(
            source: state.source,
            theme: theme,
            layoutConfig: layoutConfig,
            sourceFormat: state.sourceFormat.formatID
        )
    }

    /// Export the current diagram as an ASCII / Unicode string.
    ///
    /// Mermaid sources render directly; supported imported formats are
    /// normalized through Mermaid export before ASCII rendering.
    public func exportASCII() async throws -> String {
        try await DiagramEngine.renderASCII(
            source: state.source,
            theme: theme,
            sourceFormat: state.sourceFormat.formatID
        ).text
    }

    /// Convert the current source to another format via parse → export.
    ///
    /// Parses through the selected source format, then dispatches to the
    /// target exporter through
    /// `DiagramPipeline.defaultExportRegistry`. All five formats have
    /// registered exporters; an exporter may still emit a `.unsupported`
    /// diagnostic when the parsed document's diagram family is outside
    /// its `supportedDiagramTypes`.
    ///
    /// - Parameter target: Destination format.
    /// - Throws: Parse errors from the source side, or fatal export errors.
    /// - Returns: The exporter's `DiagramExportResult` with `source` and
    ///   `diagnostics`.
    public func exportSource(to target: SourceFormat) async throws -> DiagramExportResult {
        let document = try await DiagramEngine.parse(
            state.source,
            as: state.sourceFormat.formatID
        )
        return try DiagramExportLoader.export(
            document,
            to: target.formatID,
            registry: DiagramPipeline.defaultExportRegistry
        )
    }

    // MARK: - Copy to clipboard (Phase 4)

    /// Copy the diagram source text to the system pasteboard.
    /// - Returns: `true` if the copy succeeded.
    @discardableResult
    public func copySource() -> Bool {
        writeToPasteboard(state.source)
    }

    /// Copy the config JSON text to the system pasteboard.
    /// - Returns: `true` if the copy succeeded.
    @discardableResult
    public func copyConfig() -> Bool {
        writeToPasteboard(state.configJSON)
    }

    /// Render and copy the SVG markup to the system pasteboard.
    /// - Throws: Rendering errors.
    public func copySVG() async throws {
        let svg = try await exportSVG()
        _ = writeToPasteboard(svg)
    }

    /// Render and copy the PNG image to the system pasteboard.
    /// - Parameter options: Sizing and scale parameters.
    /// - Throws: Rendering errors.
    public func copyPNGImage(options: ExportOptions) async throws {
        let renderer = DiagramImageRenderer(theme: theme)
        renderer.layoutConfig = layoutConfig
        renderer.sourceFormat = state.sourceFormat.formatID

        let image: BMImage?
        switch options.sizing {
        case .auto:
            image = try await renderer.renderImage(from: state.source, scale: options.scale)
        case .fixed(let size):
            image = try await renderer.renderImage(from: state.source, size: size)
        }

        guard let image else {
            throw ExportError.renderFailed
        }

        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
        #elseif os(iOS)
        UIPasteboard.general.image = image
        #endif
    }

    // MARK: - Share state (Phase 4)

    /// Serialize the current editor state to a shareable base64url string.
    ///
    /// The encoded string can be copied, pasted into another instance,
    /// or stored as a URL query parameter.
    public func serializedState() -> String {
        LiveEditorStateCodec.encode(state)
    }

    /// Restore editor state from a serialized base64url string.
    ///
    /// Applies source, theme, config, and view settings. Uses
    /// `origin: .system` so manual mode doesn't block the restore.
    ///
    /// - Parameter string: A string produced by ``serializedState()``.
    /// - Throws: `LiveEditorStateCodec.CodecError` if the string is malformed.
    public func restoreFromSerializedState(_ string: String) throws {
        let restored = try LiveEditorStateCodec.decode(string)

        // Apply all fields, using .system origin to bypass manual-mode guard
        var applied = false

        if restored.source != state.source {
            state.source = restored.source
            applied = true
        }
        if restored.sourceFormat != state.sourceFormat {
            state.sourceFormat = restored.sourceFormat
            applied = true
        }
        if restored.selectedThemeName != state.selectedThemeName {
            state.selectedThemeName = restored.selectedThemeName
            applied = true
        }
        if restored.configJSON != state.configJSON {
            state.configJSON = restored.configJSON
            parseConfig()
            applied = true
        }

        state.editorMode = restored.editorMode
        state.gridEnabled = restored.gridEnabled
        state.panZoomEnabled = restored.panZoomEnabled
        state.zoomScale = restored.zoomScale
        state.panOffset = restored.panOffset
        state.updateMode = restored.updateMode

        isDirty = false

        if applied {
            requestRender(reason: .sourceChanged)
        }
    }

    // MARK: - History actions (Phase 5)

    /// Save the current state as a manually-named history entry.
    ///
    /// - Parameter label: A user-provided name for this snapshot.
    @discardableResult
    public func saveHistoryEntry(label: String) -> LiveHistoryEntry {
        historyStore.save(state: state, label: label)
    }

    /// Restore all editor state from a history entry.
    ///
    /// Applies source, theme, config, and view settings. Uses
    /// `origin: .history` so manual mode doesn't block the restore.
    ///
    /// - Parameter entry: The history entry to restore from.
    public func restoreFromHistory(_ entry: LiveHistoryEntry) {
        let restored = historyStore.restore(entry)

        var applied = false

        if restored.source != state.source {
            state.source = restored.source
            applied = true
        }
        if restored.sourceFormat != state.sourceFormat {
            state.sourceFormat = restored.sourceFormat
            applied = true
        }
        if restored.selectedThemeName != state.selectedThemeName {
            state.selectedThemeName = restored.selectedThemeName
            applied = true
        }
        if restored.configJSON != state.configJSON {
            state.configJSON = restored.configJSON
            parseConfig()
            applied = true
        }

        state.editorMode = restored.editorMode
        state.gridEnabled = restored.gridEnabled
        state.panZoomEnabled = restored.panZoomEnabled
        state.zoomScale = restored.zoomScale
        state.panOffset = restored.panOffset
        state.updateMode = restored.updateMode

        isDirty = false

        if applied {
            requestRender(reason: .sourceChanged)
        }
    }

    // MARK: - Loader actions (Phase 5)

    /// Load diagram source and config from a GitHub Gist URL.
    ///
    /// Fetches the Gist via the public API, extracts a recognized
    /// diagram source file (Mermaid/D2/DOT/Structurizr/PlantUML by
    /// extension), and reads config from `config.json`. Config is
    /// sanitized before application. A loader history entry is saved
    /// automatically.
    ///
    /// - Parameter url: A GitHub Gist URL.
    /// - Throws: ``GistLoader.LoadError`` on failure.
    public func loadFromGist(url: URL) async throws {
        let result = try await GistLoader.load(from: url)

        state.source = result.source
        if let sniffed = result.sourceFormat {
            state.sourceFormat = sniffed
        }

        if let configJSON = result.configJSON {
            state.configJSON = configJSON
            parseConfig()
        }

        // Save loader history entry
        historyStore.saveLoaderEntry(
            state: state,
            label: result.label,
            sourceURL: result.sourceURL
        )

        isDirty = false
        requestRender(reason: .sourceChanged)
    }

    /// Load diagram source and/or config from raw HTTP(S) URLs.
    ///
    /// The source URL's path extension is sniffed for a `SourceFormat`;
    /// when no extension is present, the current `state.sourceFormat`
    /// is left untouched.
    ///
    /// - Parameters:
    ///   - codeURL: URL to load source from (optional).
    ///   - configURL: URL to load config JSON from (optional).
    /// - Throws: ``RawFileLoader.LoadError`` on failure.
    public func loadFromRawURL(codeURL: URL?, configURL: URL?) async throws {
        let result = try await RawFileLoader.load(codeURL: codeURL, configURL: configURL)

        if !result.source.isEmpty {
            state.source = result.source
            if let sniffed = result.sourceFormat {
                state.sourceFormat = sniffed
            }
        }

        if let configJSON = result.configJSON {
            state.configJSON = configJSON
            parseConfig()
        }

        // Save loader history entry
        historyStore.saveLoaderEntry(
            state: state,
            label: result.label,
            sourceURL: result.sourceURL
        )

        isDirty = false
        requestRender(reason: .sourceChanged)
    }

    // MARK: - Private helpers

    /// Convert a platform image to PNG data.
    private func platformPNGData(from image: BMImage) -> Data? {
        #if targetEnvironment(macCatalyst) || canImport(UIKit)
        return image.pngData()
        #elseif canImport(AppKit)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
        #endif
    }

    /// Write a string to the system pasteboard.
    /// - Returns: `true` if the write succeeded.
    @discardableResult
    private func writeToPasteboard(_ string: String) -> Bool {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(string, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = string
        return true
        #endif
    }

    /// Commit the editable state/config to the preview snapshot.
    ///
    /// `previewState` is intentionally NOT updated here — it's promoted
    /// from `pendingRenderState` in `didCompleteRender(...)` so the
    /// auto-saved state matches what was actually rendered, not whatever
    /// the user has typed between request and completion.
    private func commitCurrentStateToPreview() {
        previewSource = state.source
        previewThemeName = state.selectedThemeName
        previewLayoutConfig = layoutConfig
    }

    // MARK: - Selection (Phase 7)

    /// Write `selection` into the persistent editor. Used by both the canvas
    /// tap dispatch and any keyboard-driven picker.
    public func setSelection(_ selection: DiagramSelection?) {
        editor?.selection = selection
    }

    // MARK: - Mutations (Phase 7)

    /// Corpus metadata for the most recently loaded sample, populated by
    /// `SampleDiagramPanel.loadDiagram`. Cleared when the user types or
    /// when a non-corpus source replaces the current diagram, so stale
    /// "expected diagnostics" annotations don't follow the user as they
    /// edit.
    public private(set) var loadedCorpusMetadata: CorpusMetadata?

    /// Surface the corpus metadata for a sample being loaded into the
    /// editor. Called by the sample-picker right before `setSource`.
    public func setLoadedCorpusMetadata(_ metadata: CorpusMetadata?) {
        loadedCorpusMetadata = metadata
    }

    /// Most recent mutation error, surfaced inline by the editor pane.
    /// Cleared automatically on the next successful mutation.
    public private(set) var lastMutationError: String?

    /// Apply a core mutation through the persistent editor, then push the
    /// exported source back into `state.source` (origin: `.mutation` so the
    /// post-render seed step skips re-creating the editor and preserves
    /// the undo stack).
    ///
    /// No-ops silently when `editor` is nil — the pane gates buttons on
    /// `store.editor != nil`, so this only protects against races.
    public func performMutation(_ mutation: DiagramMutation) async throws {
        guard let editor else { return }
        do {
            try await editor.perform(mutation)
            lastMutationError = nil
            if let source = editor.source, source != state.source {
                setSource(source, origin: .mutation)
            }
        } catch {
            lastMutationError = error.localizedDescription
            throw error
        }
    }

    /// Apply a flowchart-specific mutation through the persistent editor.
    ///
    /// No-ops silently when `editor` is nil.
    public func performFlowchartMutation(_ mutation: FlowchartMutation) async throws {
        guard let editor else { return }
        do {
            try await editor.performFlowchart(mutation)
            lastMutationError = nil
            if let source = editor.source, source != state.source {
                setSource(source, origin: .mutation)
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

    /// Force-opens the inspector regardless of prior state. Used by
    /// UI tests that need a deterministic starting state.
    public func openInspector() {
        state.inspectorOpen = true
    }

    /// Delegate to `editor.undoManager.undo()`. Observation updates flow
    /// through `DiagramEditor.canUndo` / `canRedo` via the editor's
    /// NotificationCenter wiring — no manual tickle needed.
    public func undoStructural() {
        editor?.undoManager.undo()
    }

    /// Delegate to `editor.undoManager.redo()`.
    public func redoStructural() {
        editor?.undoManager.redo()
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
}

// MARK: - Supporting types

/// Annotations from `test-diagrams.json` that follow a sample into the
/// editor so the user can compare expected vs actual diagnostics or see
/// the unsupported-note explaining why an entry is partially supported.
public struct CorpusMetadata: Sendable {
    public let expectedDiagnostics: [TestExpectedDiagnostic]?
    public let unsupportedNote: String?

    public init(
        expectedDiagnostics: [TestExpectedDiagnostic]? = nil,
        unsupportedNote: String? = nil
    ) {
        self.expectedDiagnostics = expectedDiagnostics
        self.unsupportedNote = unsupportedNote
    }
}

/// Tracks where a source change originated.
public enum SourceOrigin: Sendable {
    /// The user typed or pasted into the editor.
    case user
    /// A corpus sample picker or other programmatic source swap that
    /// replaces the document wholesale; the persistent editor must be
    /// re-seeded from the new source.
    case system
    /// A structural mutation performed through `DiagramEditor`. The
    /// editor's document is already in sync with the new source, so
    /// `didCompleteRender` must NOT re-seed the editor — doing so would
    /// throw away the editor's `UndoManager` stack.
    case mutation
    /// Restored from history.
    case history
    /// Loaded from a remote URL or Gist.
    case loader
}

/// Why a render was requested.
public enum RenderReason: Sendable {
    case sourceChanged
    case themeChanged
    case manual
}

// MARK: - Export errors

/// Errors that can occur during export operations.
public enum ExportError: Swift.Error, Sendable, LocalizedError {
    /// The diagram rendered but produced no image.
    case renderFailed
    /// The rendered image could not be converted to PNG data.
    case pngConversionFailed

    public var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render diagram — no image produced."
        case .pngConversionFailed:
            return "Failed to convert rendered image to PNG data."
        }
    }
}
