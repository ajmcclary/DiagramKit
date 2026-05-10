//
//  LiveEditorStore.swift
//  MermaidPlayground
//
//  Central @MainActor @Observable store that owns the serializable
//  LiveEditorState, tracks render lifecycle, and exposes actions for
//  every UI interaction (source edits, theme changes, render requests).
//

import SwiftUI
import DiagramKit
import DiagramKitModel
import IssueReporting

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

    // MARK: - Config (Phase 3)

    /// Parsed representation of the current `state.configJSON`.
    /// Nil when the JSON is invalid or empty.
    public private(set) var parsedConfig: LiveEditorConfig?

    /// Layout parameters extracted from config JSON.
    public private(set) var layoutConfig: LayoutConfig = LayoutConfig()

    /// Sanitizer warnings from the current config (empty = clean).
    public private(set) var configWarnings: [ConfigSanitizer.Warning] = []

    // MARK: - Derived

    /// Resolved theme from ``LiveEditorState/selectedThemeName``.
    /// Falls back to `.default` when the name is unrecognized.
    public var theme: DiagramTheme {
        DiagramTheme.theme(named: state.selectedThemeName) ?? .default
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
        parseConfig()
    }

    // MARK: - Config parsing

    /// Parse the current `state.configJSON`, extract known settings,
    /// and apply them to the store's runtime state.
    private func parseConfig() {
        let config = LiveEditorConfig.parse(state.configJSON)
        var applied = config
        applied.warnings = ConfigSanitizer.audit(config.jsonTree)
        parsedConfig = config.parseError == nil ? applied : nil
        configWarnings = applied.warnings
        layoutConfig = applied.layoutConfig

        // Apply theme if found and different from current
        if let themeName = applied.themeName, themeName != state.selectedThemeName {
            setTheme(named: themeName)
        }
    }

    // MARK: - Actions

    /// Update the diagram source and schedule a render.
    ///
    /// - Parameters:
    ///   - source: New Mermaid source text.
    ///   - origin: Where the change came from (user typing, system, history, loader).
    public func setSource(_ source: String, origin: SourceOrigin) {
        guard state.source != source else { return }
        state.source = source

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

    /// Callback from `MermaidViewRepresentable` when the layer finishes
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
        }
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