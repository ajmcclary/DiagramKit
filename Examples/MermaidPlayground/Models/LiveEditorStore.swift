//
//  LiveEditorStore.swift
//  MermaidPlayground
//
//  Central @MainActor @Observable store that owns the serializable
//  LiveEditorState, tracks render lifecycle, and exposes actions for
//  every UI interaction (source edits, theme changes, render requests,
//  exports, clipboard operations, and state sharing).
//

import SwiftUI
import DiagramKit
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
/// Instantiated once in `MermaidPlaygroundApp` and passed through the
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

    /// Full editor state from the last render request.
    private var previewState: LiveEditorState

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
    ///   - source: New Mermaid source text.
    ///   - origin: Where the change came from (user typing, system, history, loader).
    public func setSource(_ source: String, origin: SourceOrigin) {
        guard state.source != source else { return }
        state.source = source

        // Non-user sources (sample picker, remote loader) drop a fresh diagram in;
        // reset preview transform so it auto-fits instead of inheriting the previous
        // diagram's zoom and pan.
        if origin == .system || origin == .loader {
            state.zoomScale = nil
            state.panOffset = nil
        }

        if state.updateMode == .manual && origin == .user {
            // In manual mode, mark dirty but don't render automatically.
            // System-origin changes (corpus, history) always trigger a render.
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
        renderGeneration &+= 1
        renderStatus = .rendering
    }

    /// Trigger a render in manual update mode.
    /// Clears the dirty flag and schedules a render.
    public func renderNow() {
        guard state.updateMode == .manual, isDirty else { return }
        isDirty = false
        requestRender(reason: .manual)
    }

    /// Callback from `DiagramNativeViewRepresentable` when the layer finishes
    /// preparing (parse + layout complete, success or failure).
    ///
    /// The store reads `parseError` and `diagramBounds` from the view
    /// and updates its runtime state accordingly.
    public func didCompleteRender(parseError: Error?, diagramBounds: CGRect) {
        self.parseError = parseError
        self.diagramBounds = diagramBounds

        if let parseError {
            _ = parseError  // keep the last valid preview visible
            renderStatus = .failed
        } else if state.source.isEmpty {
            renderStatus = .idle
        } else {
            renderStatus = .rendered
            // Auto-save history after successful renders
            historyStore.autoSaveIfNeeded(state: previewState)
        }
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
        let fileName = "mermaid-diagram-\(Int(Date().timeIntervalSince1970)).png"
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
            layoutConfig: layoutConfig
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
    /// Fetches the Gist via the public API, extracts source from
    /// `code.mmd` (or a `.mmd` fallback), and config from `config.json`.
    /// Config is sanitized before application. A loader history entry
    /// is saved automatically.
    ///
    /// - Parameter url: A GitHub Gist URL.
    /// - Throws: ``GistLoader.LoadError`` on failure.
    public func loadFromGist(url: URL) async throws {
        let result = try await GistLoader.load(from: url)

        state.source = result.source

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
    /// - Parameters:
    ///   - codeURL: URL to load Mermaid source from (optional).
    ///   - configURL: URL to load config JSON from (optional).
    /// - Throws: ``RawFileLoader.LoadError`` on failure.
    public func loadFromRawURL(codeURL: URL?, configURL: URL?) async throws {
        let result = try await RawFileLoader.load(codeURL: codeURL, configURL: configURL)

        if !result.source.isEmpty {
            state.source = result.source
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
    private func commitCurrentStateToPreview() {
        previewSource = state.source
        previewThemeName = state.selectedThemeName
        previewLayoutConfig = layoutConfig
        previewState = state
    }
}

// MARK: - Supporting types

/// Tracks where a source change originated.
public enum SourceOrigin: Sendable {
    /// The user typed or pasted into the editor.
    case user
    /// A corpus sample, history restore, or other programmatic change.
    case system
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
