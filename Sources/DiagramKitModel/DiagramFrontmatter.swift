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
    /// Concurrency Contract:
    /// `Storage` is private, and public mutations go through copy-on-write
    /// setters before touching the reference. The reference exists only to keep
    /// this value type small enough for cooperative executor stacks.
    private final class Storage: @unchecked Sendable {
        var classConfig: ClassConfig?
        var flowchartConfig: original_src_types.FlowchartConfig?
        var erConfig: ErDiagramConfig?
        var xyChartConfig: XYChartConfig?
        var xyChartTheme: XYChartThemeConfig?
        var pieConfig: PieChartConfig?
        var pieTheme: PieChartThemeConfig?
        var sequenceConfig: SequenceDiagramConfig?
        var stateConfig: original_src_types.StateConfig?
        var journeyConfig: JourneyDiagramConfig?
        var ganttConfig: GanttDiagramConfig?
        var quadrantChartConfig: QuadrantChartConfig?
        var quadrantChartTheme: QuadrantChartThemeConfig?
        var requirementConfig: RequirementDiagramConfig?
        var requirementTheme: RequirementThemeVariables?
        var gitGraphConfig: GitGraphConfig?
        var gitGraphTheme: GitGraphThemeConfig?
        var mindmapConfig: MindmapConfig?
        var timelineConfig: TimelineDiagramConfig?
        var timelineTheme: TimelineThemeConfig?
        var sankeyConfig: SankeyDiagramConfig?
        var blockConfig: BlockDiagramConfig?
        var packetConfig: PacketDiagramConfig?
        var packetTheme: PacketThemeConfig?
        var kanbanConfig: KanbanDiagramConfig?
        var archConfig: ArchitectureDiagramConfig?
        var archTheme: ArchitectureThemeConfig?
        var radarConfig: RadarDiagramConfig?
        var radarTheme: RadarThemeConfig?
        var treemapConfig: TreemapDiagramConfig?
        var treemapThemeVariables: [String: String]?
        var vennConfig: VennDiagramConfig?
        var vennThemeVariables: [String: String]?
        var ishikawaConfig: IshikawaDiagramConfig?
        var treeViewConfig: TreeViewDiagramConfig?
        var treeViewTheme: TreeViewThemeVariables?
        var eventmodelingConfig: EventModelingDiagramConfig?
        var eventmodelingThemeVariables: EventModelingThemeVariables?
        var wardleyBetaConfig: WardleyDiagramConfig?
        var wardleyTheme: WardleyThemeVariables?
        var c4Config: C4DiagramConfig?

        init() {}

        init(copying other: Storage) {
            classConfig = other.classConfig
            flowchartConfig = other.flowchartConfig
            erConfig = other.erConfig
            xyChartConfig = other.xyChartConfig
            xyChartTheme = other.xyChartTheme
            pieConfig = other.pieConfig
            pieTheme = other.pieTheme
            sequenceConfig = other.sequenceConfig
            stateConfig = other.stateConfig
            journeyConfig = other.journeyConfig
            ganttConfig = other.ganttConfig
            quadrantChartConfig = other.quadrantChartConfig
            quadrantChartTheme = other.quadrantChartTheme
            requirementConfig = other.requirementConfig
            requirementTheme = other.requirementTheme
            gitGraphConfig = other.gitGraphConfig
            gitGraphTheme = other.gitGraphTheme
            mindmapConfig = other.mindmapConfig
            timelineConfig = other.timelineConfig
            timelineTheme = other.timelineTheme
            sankeyConfig = other.sankeyConfig
            blockConfig = other.blockConfig
            packetConfig = other.packetConfig
            packetTheme = other.packetTheme
            kanbanConfig = other.kanbanConfig
            archConfig = other.archConfig
            archTheme = other.archTheme
            radarConfig = other.radarConfig
            radarTheme = other.radarTheme
            treemapConfig = other.treemapConfig
            treemapThemeVariables = other.treemapThemeVariables
            vennConfig = other.vennConfig
            vennThemeVariables = other.vennThemeVariables
            ishikawaConfig = other.ishikawaConfig
            treeViewConfig = other.treeViewConfig
            treeViewTheme = other.treeViewTheme
            eventmodelingConfig = other.eventmodelingConfig
            eventmodelingThemeVariables = other.eventmodelingThemeVariables
            wardleyBetaConfig = other.wardleyBetaConfig
            wardleyTheme = other.wardleyTheme
            c4Config = other.c4Config
        }
    }

    private var storage: Storage

    public init() {
        storage = Storage()
    }

    private mutating func ensureUniqueStorage() {
        if !isKnownUniquelyReferenced(&storage) {
            storage = Storage(copying: storage)
        }
    }

    public var classConfig: ClassConfig? {
        get { storage.classConfig }
        set { ensureUniqueStorage(); storage.classConfig = newValue }
    }
    public var flowchartConfig: original_src_types.FlowchartConfig? {
        get { storage.flowchartConfig }
        set { ensureUniqueStorage(); storage.flowchartConfig = newValue }
    }
    public var erConfig: ErDiagramConfig? {
        get { storage.erConfig }
        set { ensureUniqueStorage(); storage.erConfig = newValue }
    }
    public var xyChartConfig: XYChartConfig? {
        get { storage.xyChartConfig }
        set { ensureUniqueStorage(); storage.xyChartConfig = newValue }
    }
    public var xyChartTheme: XYChartThemeConfig? {
        get { storage.xyChartTheme }
        set { ensureUniqueStorage(); storage.xyChartTheme = newValue }
    }
    public var pieConfig: PieChartConfig? {
        get { storage.pieConfig }
        set { ensureUniqueStorage(); storage.pieConfig = newValue }
    }
    public var pieTheme: PieChartThemeConfig? {
        get { storage.pieTheme }
        set { ensureUniqueStorage(); storage.pieTheme = newValue }
    }
    public var sequenceConfig: SequenceDiagramConfig? {
        get { storage.sequenceConfig }
        set { ensureUniqueStorage(); storage.sequenceConfig = newValue }
    }
    public var stateConfig: original_src_types.StateConfig? {
        get { storage.stateConfig }
        set { ensureUniqueStorage(); storage.stateConfig = newValue }
    }
    public var journeyConfig: JourneyDiagramConfig? {
        get { storage.journeyConfig }
        set { ensureUniqueStorage(); storage.journeyConfig = newValue }
    }
    public var ganttConfig: GanttDiagramConfig? {
        get { storage.ganttConfig }
        set { ensureUniqueStorage(); storage.ganttConfig = newValue }
    }
    public var quadrantChartConfig: QuadrantChartConfig? {
        get { storage.quadrantChartConfig }
        set { ensureUniqueStorage(); storage.quadrantChartConfig = newValue }
    }
    public var quadrantChartTheme: QuadrantChartThemeConfig? {
        get { storage.quadrantChartTheme }
        set { ensureUniqueStorage(); storage.quadrantChartTheme = newValue }
    }
    public var requirementConfig: RequirementDiagramConfig? {
        get { storage.requirementConfig }
        set { ensureUniqueStorage(); storage.requirementConfig = newValue }
    }
    public var requirementTheme: RequirementThemeVariables? {
        get { storage.requirementTheme }
        set { ensureUniqueStorage(); storage.requirementTheme = newValue }
    }
    public var gitGraphConfig: GitGraphConfig? {
        get { storage.gitGraphConfig }
        set { ensureUniqueStorage(); storage.gitGraphConfig = newValue }
    }
    public var gitGraphTheme: GitGraphThemeConfig? {
        get { storage.gitGraphTheme }
        set { ensureUniqueStorage(); storage.gitGraphTheme = newValue }
    }
    public var mindmapConfig: MindmapConfig? {
        get { storage.mindmapConfig }
        set { ensureUniqueStorage(); storage.mindmapConfig = newValue }
    }
    public var timelineConfig: TimelineDiagramConfig? {
        get { storage.timelineConfig }
        set { ensureUniqueStorage(); storage.timelineConfig = newValue }
    }
    public var timelineTheme: TimelineThemeConfig? {
        get { storage.timelineTheme }
        set { ensureUniqueStorage(); storage.timelineTheme = newValue }
    }
    public var sankeyConfig: SankeyDiagramConfig? {
        get { storage.sankeyConfig }
        set { ensureUniqueStorage(); storage.sankeyConfig = newValue }
    }
    public var blockConfig: BlockDiagramConfig? {
        get { storage.blockConfig }
        set { ensureUniqueStorage(); storage.blockConfig = newValue }
    }
    public var packetConfig: PacketDiagramConfig? {
        get { storage.packetConfig }
        set { ensureUniqueStorage(); storage.packetConfig = newValue }
    }
    public var packetTheme: PacketThemeConfig? {
        get { storage.packetTheme }
        set { ensureUniqueStorage(); storage.packetTheme = newValue }
    }
    public var kanbanConfig: KanbanDiagramConfig? {
        get { storage.kanbanConfig }
        set { ensureUniqueStorage(); storage.kanbanConfig = newValue }
    }
    public var archConfig: ArchitectureDiagramConfig? {
        get { storage.archConfig }
        set { ensureUniqueStorage(); storage.archConfig = newValue }
    }
    public var archTheme: ArchitectureThemeConfig? {
        get { storage.archTheme }
        set { ensureUniqueStorage(); storage.archTheme = newValue }
    }
    public var radarConfig: RadarDiagramConfig? {
        get { storage.radarConfig }
        set { ensureUniqueStorage(); storage.radarConfig = newValue }
    }
    public var radarTheme: RadarThemeConfig? {
        get { storage.radarTheme }
        set { ensureUniqueStorage(); storage.radarTheme = newValue }
    }
    public var treemapConfig: TreemapDiagramConfig? {
        get { storage.treemapConfig }
        set { ensureUniqueStorage(); storage.treemapConfig = newValue }
    }
    public var treemapThemeVariables: [String: String]? {
        get { storage.treemapThemeVariables }
        set { ensureUniqueStorage(); storage.treemapThemeVariables = newValue }
    }
    public var vennConfig: VennDiagramConfig? {
        get { storage.vennConfig }
        set { ensureUniqueStorage(); storage.vennConfig = newValue }
    }
    public var vennThemeVariables: [String: String]? {
        get { storage.vennThemeVariables }
        set { ensureUniqueStorage(); storage.vennThemeVariables = newValue }
    }
    public var ishikawaConfig: IshikawaDiagramConfig? {
        get { storage.ishikawaConfig }
        set { ensureUniqueStorage(); storage.ishikawaConfig = newValue }
    }
    public var treeViewConfig: TreeViewDiagramConfig? {
        get { storage.treeViewConfig }
        set { ensureUniqueStorage(); storage.treeViewConfig = newValue }
    }
    public var treeViewTheme: TreeViewThemeVariables? {
        get { storage.treeViewTheme }
        set { ensureUniqueStorage(); storage.treeViewTheme = newValue }
    }
    public var eventmodelingConfig: EventModelingDiagramConfig? {
        get { storage.eventmodelingConfig }
        set { ensureUniqueStorage(); storage.eventmodelingConfig = newValue }
    }
    public var eventmodelingThemeVariables: EventModelingThemeVariables? {
        get { storage.eventmodelingThemeVariables }
        set { ensureUniqueStorage(); storage.eventmodelingThemeVariables = newValue }
    }
    public var wardleyBetaConfig: WardleyDiagramConfig? {
        get { storage.wardleyBetaConfig }
        set { ensureUniqueStorage(); storage.wardleyBetaConfig = newValue }
    }
    public var wardleyTheme: WardleyThemeVariables? {
        get { storage.wardleyTheme }
        set { ensureUniqueStorage(); storage.wardleyTheme = newValue }
    }
    public var c4Config: C4DiagramConfig? {
        get { storage.c4Config }
        set { ensureUniqueStorage(); storage.c4Config = newValue }
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
