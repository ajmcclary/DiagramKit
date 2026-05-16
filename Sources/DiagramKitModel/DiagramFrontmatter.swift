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

    // MARK: - Typed family sections
    //
    // Canonical storage (audit A4). Each family lives in one slot;
    // config-only families parameterize on `Theme = Never`.

    // Config + theme pairs (14)
    public var xyChart       = DiagramFamilyFrontmatter<XYChartConfig,            XYChartThemeConfig>()
    public var pie           = DiagramFamilyFrontmatter<PieChartConfig,           PieChartThemeConfig>()
    public var quadrant      = DiagramFamilyFrontmatter<QuadrantChartConfig,      QuadrantChartThemeConfig>()
    public var requirement   = DiagramFamilyFrontmatter<RequirementDiagramConfig, RequirementThemeVariables>()
    public var gitGraph      = DiagramFamilyFrontmatter<GitGraphConfig,           GitGraphThemeConfig>()
    public var timeline      = DiagramFamilyFrontmatter<TimelineDiagramConfig,    TimelineThemeConfig>()
    public var packet        = DiagramFamilyFrontmatter<PacketDiagramConfig,      PacketThemeConfig>()
    public var architecture  = DiagramFamilyFrontmatter<ArchitectureDiagramConfig, ArchitectureThemeConfig>()
    public var radar         = DiagramFamilyFrontmatter<RadarDiagramConfig,       RadarThemeConfig>()
    public var treemap       = DiagramFamilyFrontmatter<TreemapDiagramConfig,     [String: String]>()
    public var venn          = DiagramFamilyFrontmatter<VennDiagramConfig,        [String: String]>()
    public var treeView      = DiagramFamilyFrontmatter<TreeViewDiagramConfig,    TreeViewThemeVariables>()
    public var eventModeling = DiagramFamilyFrontmatter<EventModelingDiagramConfig, EventModelingThemeVariables>()
    public var wardley       = DiagramFamilyFrontmatter<WardleyDiagramConfig,     WardleyThemeVariables>()

    // Config only (13) — `Theme = Never`
    public var classDiagram  = DiagramFamilyFrontmatter<ClassConfig,                       Never>()
    public var flowchart     = DiagramFamilyFrontmatter<original_src_types.FlowchartConfig, Never>()
    public var er            = DiagramFamilyFrontmatter<ErDiagramConfig,                   Never>()
    public var sequence      = DiagramFamilyFrontmatter<SequenceDiagramConfig,             Never>()
    public var state         = DiagramFamilyFrontmatter<original_src_types.StateConfig,    Never>()
    public var journey       = DiagramFamilyFrontmatter<JourneyDiagramConfig,              Never>()
    public var gantt         = DiagramFamilyFrontmatter<GanttDiagramConfig,                Never>()
    public var mindmap       = DiagramFamilyFrontmatter<MindmapConfig,                     Never>()
    public var sankey        = DiagramFamilyFrontmatter<SankeyDiagramConfig,               Never>()
    public var block         = DiagramFamilyFrontmatter<BlockDiagramConfig,                Never>()
    public var kanban        = DiagramFamilyFrontmatter<KanbanDiagramConfig,               Never>()
    public var ishikawa      = DiagramFamilyFrontmatter<IshikawaDiagramConfig,             Never>()
    public var c4            = DiagramFamilyFrontmatter<C4DiagramConfig,                   Never>()

    public init() {}

    // MARK: - Legacy flat-name proxies
    //
    // Forwarding shims kept until callers and the 49-arg DiagramFrontmatter
    // init migrate to typed-section paths. Each pair reads/writes a single
    // typed section above; no separate Storage is involved.

    public var classConfig: ClassConfig? {
        get { classDiagram.config }
        set { classDiagram.config = newValue }
    }
    public var flowchartConfig: original_src_types.FlowchartConfig? {
        get { flowchart.config }
        set { flowchart.config = newValue }
    }
    public var erConfig: ErDiagramConfig? {
        get { er.config }
        set { er.config = newValue }
    }
    public var xyChartConfig: XYChartConfig? {
        get { xyChart.config }
        set { xyChart.config = newValue }
    }
    public var xyChartTheme: XYChartThemeConfig? {
        get { xyChart.theme }
        set { xyChart.theme = newValue }
    }
    public var pieConfig: PieChartConfig? {
        get { pie.config }
        set { pie.config = newValue }
    }
    public var pieTheme: PieChartThemeConfig? {
        get { pie.theme }
        set { pie.theme = newValue }
    }
    public var sequenceConfig: SequenceDiagramConfig? {
        get { sequence.config }
        set { sequence.config = newValue }
    }
    public var stateConfig: original_src_types.StateConfig? {
        get { state.config }
        set { state.config = newValue }
    }
    public var journeyConfig: JourneyDiagramConfig? {
        get { journey.config }
        set { journey.config = newValue }
    }
    public var ganttConfig: GanttDiagramConfig? {
        get { gantt.config }
        set { gantt.config = newValue }
    }
    public var quadrantChartConfig: QuadrantChartConfig? {
        get { quadrant.config }
        set { quadrant.config = newValue }
    }
    public var quadrantChartTheme: QuadrantChartThemeConfig? {
        get { quadrant.theme }
        set { quadrant.theme = newValue }
    }
    public var requirementConfig: RequirementDiagramConfig? {
        get { requirement.config }
        set { requirement.config = newValue }
    }
    public var requirementTheme: RequirementThemeVariables? {
        get { requirement.theme }
        set { requirement.theme = newValue }
    }
    public var gitGraphConfig: GitGraphConfig? {
        get { gitGraph.config }
        set { gitGraph.config = newValue }
    }
    public var gitGraphTheme: GitGraphThemeConfig? {
        get { gitGraph.theme }
        set { gitGraph.theme = newValue }
    }
    public var mindmapConfig: MindmapConfig? {
        get { mindmap.config }
        set { mindmap.config = newValue }
    }
    public var timelineConfig: TimelineDiagramConfig? {
        get { timeline.config }
        set { timeline.config = newValue }
    }
    public var timelineTheme: TimelineThemeConfig? {
        get { timeline.theme }
        set { timeline.theme = newValue }
    }
    public var sankeyConfig: SankeyDiagramConfig? {
        get { sankey.config }
        set { sankey.config = newValue }
    }
    public var blockConfig: BlockDiagramConfig? {
        get { block.config }
        set { block.config = newValue }
    }
    public var packetConfig: PacketDiagramConfig? {
        get { packet.config }
        set { packet.config = newValue }
    }
    public var packetTheme: PacketThemeConfig? {
        get { packet.theme }
        set { packet.theme = newValue }
    }
    public var kanbanConfig: KanbanDiagramConfig? {
        get { kanban.config }
        set { kanban.config = newValue }
    }
    public var archConfig: ArchitectureDiagramConfig? {
        get { architecture.config }
        set { architecture.config = newValue }
    }
    public var archTheme: ArchitectureThemeConfig? {
        get { architecture.theme }
        set { architecture.theme = newValue }
    }
    public var radarConfig: RadarDiagramConfig? {
        get { radar.config }
        set { radar.config = newValue }
    }
    public var radarTheme: RadarThemeConfig? {
        get { radar.theme }
        set { radar.theme = newValue }
    }
    public var treemapConfig: TreemapDiagramConfig? {
        get { treemap.config }
        set { treemap.config = newValue }
    }
    public var treemapThemeVariables: [String: String]? {
        get { treemap.theme }
        set { treemap.theme = newValue }
    }
    public var vennConfig: VennDiagramConfig? {
        get { venn.config }
        set { venn.config = newValue }
    }
    public var vennThemeVariables: [String: String]? {
        get { venn.theme }
        set { venn.theme = newValue }
    }
    public var ishikawaConfig: IshikawaDiagramConfig? {
        get { ishikawa.config }
        set { ishikawa.config = newValue }
    }
    public var treeViewConfig: TreeViewDiagramConfig? {
        get { treeView.config }
        set { treeView.config = newValue }
    }
    public var treeViewTheme: TreeViewThemeVariables? {
        get { treeView.theme }
        set { treeView.theme = newValue }
    }
    public var eventmodelingConfig: EventModelingDiagramConfig? {
        get { eventModeling.config }
        set { eventModeling.config = newValue }
    }
    public var eventmodelingThemeVariables: EventModelingThemeVariables? {
        get { eventModeling.theme }
        set { eventModeling.theme = newValue }
    }
    public var wardleyBetaConfig: WardleyDiagramConfig? {
        get { wardley.config }
        set { wardley.config = newValue }
    }
    public var wardleyTheme: WardleyThemeVariables? {
        get { wardley.theme }
        set { wardley.theme = newValue }
    }
    public var c4Config: C4DiagramConfig? {
        get { c4.config }
        set { c4.config = newValue }
    }
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
