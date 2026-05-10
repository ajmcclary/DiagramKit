import Foundation

// MARK: - DiagramFrontmatter
//
// Parsed YAML frontmatter values for any diagram family.
//
// Storage is split into two nested structs:
//
//   - `shared`     — diagram-agnostic config (title, theme name, font size,
//                    layout, look, htmlLabels, securityLevel)
//   - `perDiagram` — per-family config + theme overrides; each field is
//                    `nil` unless the frontmatter actually committed a value
//
// The flat field names callers already use (`fm.flowchartConfig`,
// `fm.diagramTitle`, etc.) are surfaced as computed properties forwarding
// to the appropriate nested struct, so existing call sites continue to work
// without modification. The flat init signature is also preserved.
//
// Was previously embedded inside `src_class_parser.swift`, which made the
// type effectively owned by one diagram family even though it crosses
// every family. Move per audit section A3.

public struct DiagramFrontmatter: Sendable {

    public var shared: SharedFrontmatter
    public var perDiagram: PerDiagramFrontmatter

    public init(
        shared: SharedFrontmatter = SharedFrontmatter(),
        perDiagram: PerDiagramFrontmatter = PerDiagramFrontmatter()
    ) {
        self.shared = shared
        self.perDiagram = perDiagram
    }

    /// Source-compatible flat initializer. Mirrors the original 45-argument
    /// init so existing call sites keep compiling. New code should prefer
    /// `DiagramFrontmatter(shared:perDiagram:)` or mutate the nested structs
    /// directly.
    public init(
        title: String? = nil,
        diagramTitle: String? = nil,
        classConfig: ClassConfig? = nil,
        flowchartConfig: original_src_types.FlowchartConfig? = nil,
        erConfig: ErDiagramConfig? = nil,
        xyChartConfig: XYChartConfig? = nil,
        xyChartTheme: XYChartThemeConfig? = nil,
        pieConfig: PieChartConfig? = nil,
        pieTheme: PieChartThemeConfig? = nil,
        sequenceConfig: SequenceDiagramConfig? = nil,
        stateConfig: original_src_types.StateConfig? = nil,
        journeyConfig: JourneyDiagramConfig? = nil,
        ganttConfig: GanttDiagramConfig? = nil,
        quadrantChartConfig: QuadrantChartConfig? = nil,
        quadrantChartTheme: QuadrantChartThemeConfig? = nil,
        requirementConfig: RequirementDiagramConfig? = nil,
        requirementTheme: RequirementThemeVariables? = nil,
        gitGraphConfig: GitGraphConfig? = nil,
        gitGraphTheme: GitGraphThemeConfig? = nil,
        mindmapConfig: MindmapConfig? = nil,
        timelineConfig: TimelineDiagramConfig? = nil,
        timelineTheme: TimelineThemeConfig? = nil,
        sankeyConfig: SankeyDiagramConfig? = nil,
        blockConfig: BlockDiagramConfig? = nil,
        packetConfig: PacketDiagramConfig? = nil,
        packetTheme: PacketThemeConfig? = nil,
        kanbanConfig: KanbanDiagramConfig? = nil,
        archConfig: ArchitectureDiagramConfig? = nil,
        archTheme: ArchitectureThemeConfig? = nil,
        radarConfig: RadarDiagramConfig? = nil,
        radarTheme: RadarThemeConfig? = nil,
        treemapConfig: TreemapDiagramConfig? = nil,
        treemapThemeVariables: [String: String]? = nil,
        vennConfig: VennDiagramConfig? = nil,
        vennThemeVariables: [String: String]? = nil,
        ishikawaConfig: IshikawaDiagramConfig? = nil,
        treeViewConfig: TreeViewDiagramConfig? = nil,
        treeViewTheme: TreeViewThemeVariables? = nil,
        eventmodelingConfig: EventModelingDiagramConfig? = nil,
        eventmodelingThemeVariables: EventModelingThemeVariables? = nil,
        wardleyBetaConfig: WardleyDiagramConfig? = nil,
        wardleyTheme: WardleyThemeVariables? = nil,
        c4Config: C4DiagramConfig? = nil,
        layout: String? = nil,
        look: String? = nil,
        theme: String? = nil,
        htmlLabels: Bool? = nil,
        fontSize: Double? = nil,
        securityLevel: String? = nil
    ) {
        var shared = SharedFrontmatter()
        shared.title = title
        shared.diagramTitle = diagramTitle ?? title
        shared.layout = layout
        shared.look = look
        shared.theme = theme
        shared.htmlLabels = htmlLabels
        shared.fontSize = fontSize
        shared.securityLevel = securityLevel

        var perDiagram = PerDiagramFrontmatter()
        perDiagram.classConfig = classConfig
        perDiagram.flowchartConfig = flowchartConfig
        perDiagram.erConfig = erConfig
        perDiagram.xyChartConfig = xyChartConfig
        perDiagram.xyChartTheme = xyChartTheme
        perDiagram.pieConfig = pieConfig
        perDiagram.pieTheme = pieTheme
        perDiagram.sequenceConfig = sequenceConfig
        perDiagram.stateConfig = stateConfig
        perDiagram.journeyConfig = journeyConfig
        perDiagram.ganttConfig = ganttConfig
        perDiagram.quadrantChartConfig = quadrantChartConfig
        perDiagram.quadrantChartTheme = quadrantChartTheme
        perDiagram.requirementConfig = requirementConfig
        perDiagram.requirementTheme = requirementTheme
        perDiagram.gitGraphConfig = gitGraphConfig
        perDiagram.gitGraphTheme = gitGraphTheme
        perDiagram.mindmapConfig = mindmapConfig
        perDiagram.timelineConfig = timelineConfig
        perDiagram.timelineTheme = timelineTheme
        perDiagram.sankeyConfig = sankeyConfig
        perDiagram.blockConfig = blockConfig
        perDiagram.packetConfig = packetConfig
        perDiagram.packetTheme = packetTheme
        perDiagram.kanbanConfig = kanbanConfig
        perDiagram.archConfig = archConfig
        perDiagram.archTheme = archTheme
        perDiagram.radarConfig = radarConfig
        perDiagram.radarTheme = radarTheme
        perDiagram.treemapConfig = treemapConfig
        perDiagram.treemapThemeVariables = treemapThemeVariables
        perDiagram.vennConfig = vennConfig
        perDiagram.vennThemeVariables = vennThemeVariables
        perDiagram.ishikawaConfig = ishikawaConfig
        perDiagram.treeViewConfig = treeViewConfig
        perDiagram.treeViewTheme = treeViewTheme
        perDiagram.eventmodelingConfig = eventmodelingConfig
        perDiagram.eventmodelingThemeVariables = eventmodelingThemeVariables
        perDiagram.wardleyBetaConfig = wardleyBetaConfig
        perDiagram.wardleyTheme = wardleyTheme
        perDiagram.c4Config = c4Config

        self.shared = shared
        self.perDiagram = perDiagram
    }
}

// MARK: - SharedFrontmatter

/// Frontmatter values that apply across all diagram families.
public struct SharedFrontmatter: Sendable {
    public var title: String?
    public var diagramTitle: String?
    public var layout: String?
    public var look: String?
    public var theme: String?
    public var htmlLabels: Bool?
    public var fontSize: Double?
    public var securityLevel: String?

    public init() {}
}

// MARK: - PerDiagramFrontmatter

/// Per-diagram-family configs and themes. Each field is `nil` unless the
/// frontmatter actually committed at least one value for that family.
public struct PerDiagramFrontmatter: Sendable {
    public var classConfig: ClassConfig?
    public var flowchartConfig: original_src_types.FlowchartConfig?
    public var erConfig: ErDiagramConfig?
    public var xyChartConfig: XYChartConfig?
    public var xyChartTheme: XYChartThemeConfig?
    public var pieConfig: PieChartConfig?
    public var pieTheme: PieChartThemeConfig?
    public var sequenceConfig: SequenceDiagramConfig?
    public var stateConfig: original_src_types.StateConfig?
    public var journeyConfig: JourneyDiagramConfig?
    public var ganttConfig: GanttDiagramConfig?
    public var quadrantChartConfig: QuadrantChartConfig?
    public var quadrantChartTheme: QuadrantChartThemeConfig?
    public var requirementConfig: RequirementDiagramConfig?
    public var requirementTheme: RequirementThemeVariables?
    public var gitGraphConfig: GitGraphConfig?
    public var gitGraphTheme: GitGraphThemeConfig?
    public var mindmapConfig: MindmapConfig?
    public var timelineConfig: TimelineDiagramConfig?
    public var timelineTheme: TimelineThemeConfig?
    public var sankeyConfig: SankeyDiagramConfig?
    public var blockConfig: BlockDiagramConfig?
    public var packetConfig: PacketDiagramConfig?
    public var packetTheme: PacketThemeConfig?
    public var kanbanConfig: KanbanDiagramConfig?
    public var archConfig: ArchitectureDiagramConfig?
    public var archTheme: ArchitectureThemeConfig?
    public var radarConfig: RadarDiagramConfig?
    public var radarTheme: RadarThemeConfig?
    public var treemapConfig: TreemapDiagramConfig?
    public var treemapThemeVariables: [String: String]?
    public var vennConfig: VennDiagramConfig?
    public var vennThemeVariables: [String: String]?
    public var ishikawaConfig: IshikawaDiagramConfig?
    public var treeViewConfig: TreeViewDiagramConfig?
    public var treeViewTheme: TreeViewThemeVariables?
    public var eventmodelingConfig: EventModelingDiagramConfig?
    public var eventmodelingThemeVariables: EventModelingThemeVariables?
    public var wardleyBetaConfig: WardleyDiagramConfig?
    public var wardleyTheme: WardleyThemeVariables?
    public var c4Config: C4DiagramConfig?

    public init() {}
}

// MARK: - Flat-field source-compatibility shims
//
// Existing call sites read and write `fm.flowchartConfig`,
// `fm.diagramTitle`, etc. directly. The properties below forward those
// reads/writes to the nested storage so we don't have to touch every
// caller in the same change. The "Why" is purely staged migration —
// once consumers migrate to `fm.shared.*` / `fm.perDiagram.*`, these
// shims can be deprecated and removed.

public extension DiagramFrontmatter {

    // -- Shared --
    var title: String? {
        get { shared.title }
        set { shared.title = newValue }
    }
    var diagramTitle: String? {
        get { shared.diagramTitle }
        set { shared.diagramTitle = newValue }
    }
    var layout: String? {
        get { shared.layout }
        set { shared.layout = newValue }
    }
    var look: String? {
        get { shared.look }
        set { shared.look = newValue }
    }
    var theme: String? {
        get { shared.theme }
        set { shared.theme = newValue }
    }
    var htmlLabels: Bool? {
        get { shared.htmlLabels }
        set { shared.htmlLabels = newValue }
    }
    var fontSize: Double? {
        get { shared.fontSize }
        set { shared.fontSize = newValue }
    }
    var securityLevel: String? {
        get { shared.securityLevel }
        set { shared.securityLevel = newValue }
    }

    // -- Per-diagram --
    var classConfig: ClassConfig? {
        get { perDiagram.classConfig }
        set { perDiagram.classConfig = newValue }
    }
    var flowchartConfig: original_src_types.FlowchartConfig? {
        get { perDiagram.flowchartConfig }
        set { perDiagram.flowchartConfig = newValue }
    }
    var erConfig: ErDiagramConfig? {
        get { perDiagram.erConfig }
        set { perDiagram.erConfig = newValue }
    }
    var xyChartConfig: XYChartConfig? {
        get { perDiagram.xyChartConfig }
        set { perDiagram.xyChartConfig = newValue }
    }
    var xyChartTheme: XYChartThemeConfig? {
        get { perDiagram.xyChartTheme }
        set { perDiagram.xyChartTheme = newValue }
    }
    var pieConfig: PieChartConfig? {
        get { perDiagram.pieConfig }
        set { perDiagram.pieConfig = newValue }
    }
    var pieTheme: PieChartThemeConfig? {
        get { perDiagram.pieTheme }
        set { perDiagram.pieTheme = newValue }
    }
    var sequenceConfig: SequenceDiagramConfig? {
        get { perDiagram.sequenceConfig }
        set { perDiagram.sequenceConfig = newValue }
    }
    var stateConfig: original_src_types.StateConfig? {
        get { perDiagram.stateConfig }
        set { perDiagram.stateConfig = newValue }
    }
    var journeyConfig: JourneyDiagramConfig? {
        get { perDiagram.journeyConfig }
        set { perDiagram.journeyConfig = newValue }
    }
    var ganttConfig: GanttDiagramConfig? {
        get { perDiagram.ganttConfig }
        set { perDiagram.ganttConfig = newValue }
    }
    var quadrantChartConfig: QuadrantChartConfig? {
        get { perDiagram.quadrantChartConfig }
        set { perDiagram.quadrantChartConfig = newValue }
    }
    var quadrantChartTheme: QuadrantChartThemeConfig? {
        get { perDiagram.quadrantChartTheme }
        set { perDiagram.quadrantChartTheme = newValue }
    }
    var requirementConfig: RequirementDiagramConfig? {
        get { perDiagram.requirementConfig }
        set { perDiagram.requirementConfig = newValue }
    }
    var requirementTheme: RequirementThemeVariables? {
        get { perDiagram.requirementTheme }
        set { perDiagram.requirementTheme = newValue }
    }
    var gitGraphConfig: GitGraphConfig? {
        get { perDiagram.gitGraphConfig }
        set { perDiagram.gitGraphConfig = newValue }
    }
    var gitGraphTheme: GitGraphThemeConfig? {
        get { perDiagram.gitGraphTheme }
        set { perDiagram.gitGraphTheme = newValue }
    }
    var mindmapConfig: MindmapConfig? {
        get { perDiagram.mindmapConfig }
        set { perDiagram.mindmapConfig = newValue }
    }
    var timelineConfig: TimelineDiagramConfig? {
        get { perDiagram.timelineConfig }
        set { perDiagram.timelineConfig = newValue }
    }
    var timelineTheme: TimelineThemeConfig? {
        get { perDiagram.timelineTheme }
        set { perDiagram.timelineTheme = newValue }
    }
    var sankeyConfig: SankeyDiagramConfig? {
        get { perDiagram.sankeyConfig }
        set { perDiagram.sankeyConfig = newValue }
    }
    var blockConfig: BlockDiagramConfig? {
        get { perDiagram.blockConfig }
        set { perDiagram.blockConfig = newValue }
    }
    var packetConfig: PacketDiagramConfig? {
        get { perDiagram.packetConfig }
        set { perDiagram.packetConfig = newValue }
    }
    var packetTheme: PacketThemeConfig? {
        get { perDiagram.packetTheme }
        set { perDiagram.packetTheme = newValue }
    }
    var kanbanConfig: KanbanDiagramConfig? {
        get { perDiagram.kanbanConfig }
        set { perDiagram.kanbanConfig = newValue }
    }
    var archConfig: ArchitectureDiagramConfig? {
        get { perDiagram.archConfig }
        set { perDiagram.archConfig = newValue }
    }
    var archTheme: ArchitectureThemeConfig? {
        get { perDiagram.archTheme }
        set { perDiagram.archTheme = newValue }
    }
    var radarConfig: RadarDiagramConfig? {
        get { perDiagram.radarConfig }
        set { perDiagram.radarConfig = newValue }
    }
    var radarTheme: RadarThemeConfig? {
        get { perDiagram.radarTheme }
        set { perDiagram.radarTheme = newValue }
    }
    var treemapConfig: TreemapDiagramConfig? {
        get { perDiagram.treemapConfig }
        set { perDiagram.treemapConfig = newValue }
    }
    var treemapThemeVariables: [String: String]? {
        get { perDiagram.treemapThemeVariables }
        set { perDiagram.treemapThemeVariables = newValue }
    }
    var vennConfig: VennDiagramConfig? {
        get { perDiagram.vennConfig }
        set { perDiagram.vennConfig = newValue }
    }
    var vennThemeVariables: [String: String]? {
        get { perDiagram.vennThemeVariables }
        set { perDiagram.vennThemeVariables = newValue }
    }
    var ishikawaConfig: IshikawaDiagramConfig? {
        get { perDiagram.ishikawaConfig }
        set { perDiagram.ishikawaConfig = newValue }
    }
    var treeViewConfig: TreeViewDiagramConfig? {
        get { perDiagram.treeViewConfig }
        set { perDiagram.treeViewConfig = newValue }
    }
    var treeViewTheme: TreeViewThemeVariables? {
        get { perDiagram.treeViewTheme }
        set { perDiagram.treeViewTheme = newValue }
    }
    var eventmodelingConfig: EventModelingDiagramConfig? {
        get { perDiagram.eventmodelingConfig }
        set { perDiagram.eventmodelingConfig = newValue }
    }
    var eventmodelingThemeVariables: EventModelingThemeVariables? {
        get { perDiagram.eventmodelingThemeVariables }
        set { perDiagram.eventmodelingThemeVariables = newValue }
    }
    var wardleyBetaConfig: WardleyDiagramConfig? {
        get { perDiagram.wardleyBetaConfig }
        set { perDiagram.wardleyBetaConfig = newValue }
    }
    var wardleyTheme: WardleyThemeVariables? {
        get { perDiagram.wardleyTheme }
        set { perDiagram.wardleyTheme = newValue }
    }
    var c4Config: C4DiagramConfig? {
        get { perDiagram.c4Config }
        set { perDiagram.c4Config = newValue }
    }
}
