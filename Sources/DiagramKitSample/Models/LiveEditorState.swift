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

    /// Last user-set zoom scale for the visual editor canvas (nil = fit-to-view).
    /// Independent from `zoomScale`, which drives the preview canvas.
    public var visualZoomScale: CGFloat?

    /// Last user-set pan offset for the visual editor canvas. Independent
    /// from `panOffset`, which drives the preview canvas.
    public var visualPanOffset: CGSize?

    // MARK: - Update behavior (Phase 2)

    /// Auto (render on every change) or manual (render only on command).
    public var updateMode: UpdateMode

    // MARK: - Inspector pane

    /// Whether the floating Inspector drawer is currently open.
    public var inspectorOpen: Bool

    // MARK: - v2 Workspace shell

    /// Active workspace mode (Code / Visual / Split). Drives the
    /// Titlebar picker and the body layout in `PlaygroundShell`.
    public var workspaceMode: WorkspaceMode

    /// Whether per-screen citation pins overlay the active surface.
    public var showCitations: Bool

    /// Free-text filter applied to the v2 Sidebar's sample tree.
    public var sidebarSearch: String

    /// Optional format chip selection in the v2 Sidebar (nil = all).
    public var sidebarFormatFilter: SourceFormat?

    /// Active render backend (SVG / Image / ASCII) chosen in the
    /// Inspector. Phase 2 routes PreviewCanvas through this.
    public var renderBackend: RenderBackend

    /// Ordered list of open editor tabs (by sample id). Phase 2 wires
    /// the EditorTabBar; tab activation drives `state.source` via
    /// `LiveEditorStore.activateTab(_:)`.
    public var openTabs: [String]

    /// Currently focused tab id. Always a member of `openTabs` when
    /// `openTabs` is non-empty.
    public var activeTabId: String?

    /// Whether the editor minimap overlay is visible.
    public var showMinimap: Bool

    /// Source line index currently hovered in the editor or pointed at
    /// from a preview node (bidirectional selection). `nil` when no
    /// hover is active.
    public var biSelLine: Int?

    /// Preview node id currently hovered or paired with `biSelLine`.
    public var biSelNode: String?

    // MARK: - Visual mode (Phase 3)

    /// Stage of the FlowchartEditCanvas state machine.
    public var visualStage: VisualEditorState.Stage

    /// Active tool palette selection in the VisualPane.
    public var visualTool: VisualEditorState.Tool

    /// Marquee multi-selection. Empty when no marquee selection is active.
    public var marqueeSelection: Set<String>

    /// When true, StateStepper is rendered above the canvas. Off in
    /// production UI; UITests flip this on to walk the seven stages.
    public var demoStepperVisible: Bool

    /// Bottom diagnostics drawer state (open/close + four facet
    /// filters). See DiagnosticsDrawerState.
    public var diagDrawer: DiagnosticsDrawerState

    /// Export sheet state (open/close + target + round-trip toggle).
    public var exportSheet: ExportSheetState

    /// Convert sheet state (open/close + target).
    public var convertSheet: ConvertSheetState

    /// Body-replacing full-window surface (Coverage / Corpus / etc.).
    /// `.none` shows the standard workspace body.
    public var fullScreen: FullScreenSurface

    /// Theme override map used by the Inspector ThemeBuilder card.
    public var themeBuilder: ThemeBuilderState

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
        visualZoomScale: CGFloat? = nil,
        visualPanOffset: CGSize? = nil,
        updateMode: UpdateMode = .auto,
        inspectorOpen: Bool = false,
        workspaceMode: WorkspaceMode = .default,
        showCitations: Bool = false,
        sidebarSearch: String = "",
        sidebarFormatFilter: SourceFormat? = nil,
        renderBackend: RenderBackend = .svg,
        openTabs: [String] = Self.defaultOpenTabs,
        activeTabId: String? = nil,
        showMinimap: Bool = true,
        biSelLine: Int? = nil,
        biSelNode: String? = nil,
        visualStage: VisualEditorState.Stage = .idle,
        visualTool: VisualEditorState.Tool = .select,
        marqueeSelection: Set<String> = [],
        demoStepperVisible: Bool = false,
        diagDrawer: DiagnosticsDrawerState = .default,
        exportSheet: ExportSheetState = .default,
        convertSheet: ConvertSheetState = .default,
        fullScreen: FullScreenSurface = .none,
        themeBuilder: ThemeBuilderState = .default
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
        self.visualZoomScale = visualZoomScale
        self.visualPanOffset = visualPanOffset
        self.updateMode = updateMode
        self.inspectorOpen = inspectorOpen
        self.workspaceMode = workspaceMode
        self.showCitations = showCitations
        self.sidebarSearch = sidebarSearch
        self.sidebarFormatFilter = sidebarFormatFilter
        self.renderBackend = renderBackend
        self.openTabs = openTabs
        self.activeTabId = activeTabId ?? openTabs.first
        self.showMinimap = showMinimap
        self.biSelLine = biSelLine
        self.biSelNode = biSelNode
        self.visualStage = visualStage
        self.visualTool = visualTool
        self.marqueeSelection = marqueeSelection
        self.demoStepperVisible = demoStepperVisible
        self.diagDrawer = diagDrawer
        self.exportSheet = exportSheet
        self.convertSheet = convertSheet
        self.fullScreen = fullScreen
        self.themeBuilder = themeBuilder
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
        case visualZoomScale
        case visualPanOffset
        case updateMode
        case inspectorOpen
        case workspaceMode
        case showCitations
        case sidebarSearch
        case sidebarFormatFilter
        case renderBackend
        case openTabs
        case activeTabId
        case showMinimap
        case visualStage
        case visualTool
        case marqueeSelection
        case demoStepperVisible
        case diagDrawer
        case exportSheet
        case convertSheet
        case fullScreen
        case themeBuilder
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
        self.visualZoomScale = try c.decodeIfPresent(CGFloat.self, forKey: .visualZoomScale)
        self.visualPanOffset = try c.decodeIfPresent(CGSize.self, forKey: .visualPanOffset)
        self.updateMode = try c.decodeIfPresent(UpdateMode.self, forKey: .updateMode) ?? .auto
        self.inspectorOpen = try c.decodeIfPresent(Bool.self, forKey: .inspectorOpen) ?? false
        self.workspaceMode = try c.decodeIfPresent(WorkspaceMode.self, forKey: .workspaceMode) ?? .default
        self.showCitations = try c.decodeIfPresent(Bool.self, forKey: .showCitations) ?? false
        self.sidebarSearch = try c.decodeIfPresent(String.self, forKey: .sidebarSearch) ?? ""
        self.sidebarFormatFilter = try c.decodeIfPresent(SourceFormat.self, forKey: .sidebarFormatFilter)
        self.renderBackend = try c.decodeIfPresent(RenderBackend.self, forKey: .renderBackend) ?? .svg
        let decodedTabs = try c.decodeIfPresent([String].self, forKey: .openTabs) ?? Self.defaultOpenTabs
        self.openTabs = decodedTabs
        let decodedActive = try c.decodeIfPresent(String.self, forKey: .activeTabId)
        self.activeTabId = decodedActive ?? decodedTabs.first
        self.showMinimap = try c.decodeIfPresent(Bool.self, forKey: .showMinimap) ?? true
        self.visualStage = try c.decodeIfPresent(VisualEditorState.Stage.self, forKey: .visualStage) ?? .idle
        self.visualTool = try c.decodeIfPresent(VisualEditorState.Tool.self, forKey: .visualTool) ?? .select
        self.marqueeSelection = try c.decodeIfPresent(Set<String>.self, forKey: .marqueeSelection) ?? []
        self.demoStepperVisible = try c.decodeIfPresent(Bool.self, forKey: .demoStepperVisible) ?? false
        self.diagDrawer = try c.decodeIfPresent(DiagnosticsDrawerState.self, forKey: .diagDrawer) ?? .default
        self.exportSheet = try c.decodeIfPresent(ExportSheetState.self, forKey: .exportSheet) ?? .default
        self.convertSheet = try c.decodeIfPresent(ConvertSheetState.self, forKey: .convertSheet) ?? .default
        self.fullScreen = try c.decodeIfPresent(FullScreenSurface.self, forKey: .fullScreen) ?? .none
        self.themeBuilder = try c.decodeIfPresent(ThemeBuilderState.self, forKey: .themeBuilder) ?? .default
    }

    // MARK: - Defaults

    public static let defaultSource = """
    graph TD
      A[Start] --> B[Process] --> C[End]
    """

    public static let defaultThemeName = "Zinc Light"

    /// Initial tab set surfaced by the v2 PlaygroundShell. Picks one
    /// each from the flowchart / timeline / gantt families so the
    /// design's three-tab default has real samples behind it.
    public static let defaultOpenTabs: [String] = [
        "flow-1-simple",
        "timeline-1-basic",
        "gantt-1-basic"
    ]
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
