//
//  LiveEditorState.swift
//  MermaidPlayground
//
//  Serializable user-facing state for the live editor.
//  All fields declared here for forward compatibility; only source
//  and selectedThemeName are wired in Phase 1.
//

import Foundation

// MARK: - LiveEditorState

/// Fully serializable snapshot of the editor's user-visible state.
///
/// Storing a theme *name* (rather than a ``DiagramTheme`` value) keeps this
/// type `Codable` without dragging in platform color/font types. The store
/// resolves the name into a concrete theme at runtime via
/// `DiagramTheme.theme(named:)`.
public struct LiveEditorState: Codable, Equatable, Sendable {

    // MARK: - Core (Phase 1)

    /// The Mermaid diagram source text.
    public var source: String

    /// Display name of the active theme (e.g. `"Dracula"`, `"Zinc Light"`).
    /// Resolved to a ``DiagramTheme`` by ``LiveEditorStore``.
    public var selectedThemeName: String

    // MARK: - Config (Phase 3)

    /// Raw JSON config string as typed by the user.
    public var configJSON: String

    // MARK: - Editor mode (Phase 2)

    /// Whether the editor pane shows code or config.
    public var editorMode: EditorMode

    // MARK: - View controls (Phase 2)

    /// Whether a background grid is drawn behind the diagram.
    public var gridEnabled: Bool

    /// Whether pan/zoom gestures are active.
    public var panZoomEnabled: Bool

    /// Last user-set zoom scale (nil = use fit-to-view).
    public var zoomScale: CGFloat?

    /// Last user-set pan offset.
    public var panOffset: CGSize?

    // MARK: - Update behavior (Phase 2)

    /// Auto (render on every change) or manual (render only on command).
    public var updateMode: UpdateMode

    // MARK: - Init

    public init(
        source: String = Self.defaultSource,
        selectedThemeName: String = Self.defaultThemeName,
        configJSON: String = "{}",
        editorMode: EditorMode = .code,
        gridEnabled: Bool = false,
        panZoomEnabled: Bool = true,
        zoomScale: CGFloat? = nil,
        panOffset: CGSize? = nil,
        updateMode: UpdateMode = .auto
    ) {
        self.source = source
        self.selectedThemeName = selectedThemeName
        self.configJSON = configJSON
        self.editorMode = editorMode
        self.gridEnabled = gridEnabled
        self.panZoomEnabled = panZoomEnabled
        self.zoomScale = zoomScale
        self.panOffset = panOffset
        self.updateMode = updateMode
    }

    // MARK: - Defaults

    public static let defaultSource = """
    graph TD
      A[Start] --> B[Process] --> C[End]
    """

    public static let defaultThemeName = "Zinc Light"
}

// MARK: - Supporting enums

public enum EditorMode: String, Codable, Equatable, Sendable, CaseIterable {
    case code
    case config
}

public enum UpdateMode: String, Codable, Equatable, Sendable, CaseIterable {
    case auto
    case manual
}
