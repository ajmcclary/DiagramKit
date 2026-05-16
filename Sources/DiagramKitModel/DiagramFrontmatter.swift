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
}
