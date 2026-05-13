//
//  LiveEditorState.swift
//  DiagramPlayground
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

    /// The diagram source text. May be Mermaid, D2, Graphviz DOT, Structurizr,
    /// or PlantUML — `sourceFormat` carries the active format hint.
    public var source: String

    /// Source format of `source`. Drives sample loading, the export menu,
    /// and the format chip in the toolbar.
    public var sourceFormat: SourceFormat

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

    // MARK: - Inspector pane

    /// Whether the floating Inspector drawer is currently open.
    public var inspectorOpen: Bool

    // MARK: - Init

    public init(
        source: String = Self.defaultSource,
        sourceFormat: SourceFormat = .mermaid,
        selectedThemeName: String = Self.defaultThemeName,
        configJSON: String = "{}",
        editorMode: EditorMode = .code,
        gridEnabled: Bool = false,
        panZoomEnabled: Bool = true,
        zoomScale: CGFloat? = nil,
        panOffset: CGSize? = nil,
        updateMode: UpdateMode = .auto,
        inspectorOpen: Bool = false
    ) {
        self.source = source
        self.sourceFormat = sourceFormat
        self.selectedThemeName = selectedThemeName
        self.configJSON = configJSON
        self.editorMode = editorMode
        self.gridEnabled = gridEnabled
        self.panZoomEnabled = panZoomEnabled
        self.zoomScale = zoomScale
        self.panOffset = panOffset
        self.updateMode = updateMode
        self.inspectorOpen = inspectorOpen
    }

    // MARK: - Codable (handle legacy snapshots without sourceFormat)

    private enum CodingKeys: String, CodingKey {
        case source
        case sourceFormat
        case selectedThemeName
        case configJSON
        case editorMode
        case gridEnabled
        case panZoomEnabled
        case zoomScale
        case panOffset
        case updateMode
        case inspectorOpen
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.source = try c.decodeIfPresent(String.self, forKey: .source) ?? Self.defaultSource
        self.sourceFormat = try c.decodeIfPresent(SourceFormat.self, forKey: .sourceFormat) ?? .mermaid
        self.selectedThemeName = try c.decodeIfPresent(String.self, forKey: .selectedThemeName) ?? Self.defaultThemeName
        self.configJSON = try c.decodeIfPresent(String.self, forKey: .configJSON) ?? "{}"
        self.editorMode = try c.decodeIfPresent(EditorMode.self, forKey: .editorMode) ?? .code
        self.gridEnabled = try c.decodeIfPresent(Bool.self, forKey: .gridEnabled) ?? false
        self.panZoomEnabled = try c.decodeIfPresent(Bool.self, forKey: .panZoomEnabled) ?? true
        self.zoomScale = try c.decodeIfPresent(CGFloat.self, forKey: .zoomScale)
        self.panOffset = try c.decodeIfPresent(CGSize.self, forKey: .panOffset)
        self.updateMode = try c.decodeIfPresent(UpdateMode.self, forKey: .updateMode) ?? .auto
        self.inspectorOpen = try c.decodeIfPresent(Bool.self, forKey: .inspectorOpen) ?? false
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
