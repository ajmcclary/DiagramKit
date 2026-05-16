import Foundation

// MARK: - PerDiagramFrontmatter

/// Per-diagram-family configs and themes. Each family lives in one
/// typed `DiagramFamilyFrontmatter<Config, Theme>` slot; fields are
/// `nil` unless the frontmatter actually committed a value. The 13
/// families that have no theme parameterize on `Theme = Never`, so
/// their `theme` is permanently nil.
public struct PerDiagramFrontmatter: Sendable {

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
}
