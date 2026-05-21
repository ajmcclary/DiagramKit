import Foundation

/// AST produced by `PlantUMLWBSParser`. Hierarchical tree of
/// `PlantUMLWBSNode` plus diagram-level metadata (title) and the list of
/// unsupported lines collected during parse.
///
/// Distinct from `PlantUMLMindmapTree` because WBS targets `TreeViewDiagram`
/// (not `MindmapDiagram`) and carries WBS-specific shape/color slots that
/// surface as `.slotUnsupported` diagnostics in the mapper.
public struct PlantUMLWBSTree: Sendable {
    public var root: PlantUMLWBSNode?
    public var title: String?
    public var unsupportedLines: [String]

    public init(
        root: PlantUMLWBSNode? = nil,
        title: String? = nil,
        unsupportedLines: [String] = []
    ) {
        self.root = root
        self.title = title
        self.unsupportedLines = unsupportedLines
    }
}

public struct PlantUMLWBSNode: Sendable {
    public var label: String
    public var depth: Int
    /// WBS `<<…>>` shape token if present, stripped from `label`.
    /// Mapper surfaces as `.featureDropped(.slotUnsupported, …)`.
    public var shape: String?
    /// WBS `#…` color suffix if present, stripped from `label`.
    /// Mapper surfaces as `.featureDropped(.slotUnsupported, …)`.
    public var color: String?
    public var children: [PlantUMLWBSNode]

    public init(
        label: String,
        depth: Int,
        shape: String? = nil,
        color: String? = nil,
        children: [PlantUMLWBSNode] = []
    ) {
        self.label = label
        self.depth = depth
        self.shape = shape
        self.color = color
        self.children = children
    }
}
