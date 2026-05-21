import Foundation

// MARK: - Core Model Types

public enum TreeViewNodeType: String, Sendable, Equatable {
    case file
    case directory
}

/// One node in a `TreeViewDiagram`.
///
/// `level` is the depth at which the node appears: real user-visible nodes
/// start at `0` and increment with nesting. The single exception is the
/// **synthetic-root sentinel** described on `TreeViewDiagram` — a
/// `TreeViewNode` with `name == "/"` AND `level == -1` is the Mermaid
/// parser's multi-root container and has no source counterpart.
public struct TreeViewNode: Sendable, Equatable {
    public var id: Int
    public var level: Int
    public var name: String
    public var nodeType: TreeViewNodeType
    public var iconId: String?
    public var cssClass: String?
    public var description: String?
    public var children: [TreeViewNode]
    public var bbox: TreeViewBBox?

    public init(
        id: Int,
        level: Int,
        name: String,
        nodeType: TreeViewNodeType,
        iconId: String? = nil,
        cssClass: String? = nil,
        description: String? = nil,
        children: [TreeViewNode] = [],
        bbox: TreeViewBBox? = nil
    ) {
        self.id = id
        self.level = level
        self.name = name
        self.nodeType = nodeType
        self.iconId = iconId
        self.cssClass = cssClass
        self.description = description
        self.children = children
        self.bbox = bbox
    }
}

public struct TreeViewBBox: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Canonical payload for treeView diagrams across every importer.
///
/// `root` represents the user-visible root structure with one sentinel:
///
/// > A `root` whose `name == "/"` AND `level == -1` is a **synthetic
/// > multi-root container** introduced by the Mermaid treeView parser to
/// > host two or more sibling roots declared at level 0. Its children are
/// > the user-visible roots; the container itself has no source counterpart.
///
/// All other importers (D2, DOT, PlantUML) produce a `TreeViewDiagram`
/// whose `root` is the actual user-visible root at level 0 — no synthetic
/// container.
///
/// Exporters detect the convention on entry and adapt:
/// - `MermaidTreeViewExport` accepts both shapes.
/// - `D2TreeViewExport` / `DOTTreeViewExport` strip the synthetic root and
///   emit children as a top-level forest (lossless).
/// - `PlantUMLTreeViewExporter` emits the first child as the WBS `*` root
///   and drops additional siblings with `.featureDropped(.slotUnsupported,
///   …)` per drop.
public struct TreeViewDiagram: Sendable, Equatable {
    public var root: TreeViewNode
    public var nodes: [TreeViewNode]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: TreeViewDiagramConfig
    public var theme: TreeViewThemeVariables?

    public static let empty = TreeViewDiagram(
        root: TreeViewNode(id: 0, level: -1, name: "/", nodeType: .directory, children: []),
        nodes: [TreeViewNode(id: 0, level: -1, name: "/", nodeType: .directory, children: [])],
        config: .default
    )

    public init(
        root: TreeViewNode,
        nodes: [TreeViewNode],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: TreeViewDiagramConfig = .default,
        theme: TreeViewThemeVariables? = nil
    ) {
        self.root = root
        self.nodes = nodes
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }
}

// MARK: - Config

public struct TreeViewDiagramConfig: Sendable, Equatable {
    public var rowIndent: Double
    public var paddingX: Double
    public var paddingY: Double
    public var lineThickness: Double
    public var showIcons: Bool
    public var useMaxWidth: Bool

    public static let `default` = TreeViewDiagramConfig()

    public init(
        rowIndent: Double = 10,
        paddingX: Double = 5,
        paddingY: Double = 5,
        lineThickness: Double = 1,
        showIcons: Bool = true,
        useMaxWidth: Bool = false
    ) {
        self.rowIndent = max(0, rowIndent)
        self.paddingX = max(0, paddingX)
        self.paddingY = max(0, paddingY)
        self.lineThickness = max(0, lineThickness)
        self.showIcons = showIcons
        self.useMaxWidth = useMaxWidth
    }
}

// MARK: - Theme Variables

public struct TreeViewThemeVariables: Sendable, Equatable {
    public var labelFontSize: String
    public var labelColor: String
    public var lineColor: String
    public var iconColor: String
    public var descriptionColor: String
    public var highlightBg: String
    public var highlightStroke: String

    public static let `default` = TreeViewThemeVariables()

    public init(
        labelFontSize: String = "16px",
        labelColor: String = "black",
        lineColor: String = "black",
        iconColor: String = "#546e7a",
        descriptionColor: String = "#6a9955",
        highlightBg: String = "rgba(255, 193, 7, 0.15)",
        highlightStroke: String = "#ffc107"
    ) {
        self.labelFontSize = labelFontSize
        self.labelColor = labelColor
        self.lineColor = lineColor
        self.iconColor = iconColor
        self.descriptionColor = descriptionColor
        self.highlightBg = highlightBg
        self.highlightStroke = highlightStroke
    }
}

// MARK: - Positioned Model

public struct PositionedTreeViewNode: Sendable {
    public var id: Int
    public var name: String
    public var nodeType: TreeViewNodeType
    public var iconId: String?
    public var cssClass: String?
    public var description: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var depth: Int
    public var labelRightEdge: Double
    public var centerY: Double
    public var labelX: Double
    public var labelY: Double
    public var iconX: Double?
    public var iconY: Double?
    public var descriptionX: Double?
    public var descriptionY: Double?

    public init(
        id: Int, name: String, nodeType: TreeViewNodeType,
        iconId: String?, cssClass: String?, description: String?,
        x: Double, y: Double, width: Double, height: Double,
        depth: Int, labelRightEdge: Double, centerY: Double,
        labelX: Double, labelY: Double,
        iconX: Double?, iconY: Double?,
        descriptionX: Double?, descriptionY: Double?
    ) {
        self.id = id
        self.name = name
        self.nodeType = nodeType
        self.iconId = iconId
        self.cssClass = cssClass
        self.description = description
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.depth = depth
        self.labelRightEdge = labelRightEdge
        self.centerY = centerY
        self.labelX = labelX
        self.labelY = labelY
        self.iconX = iconX
        self.iconY = iconY
        self.descriptionX = descriptionX
        self.descriptionY = descriptionY
    }
}

public struct TreeViewConnectorLine: Sendable, Equatable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public struct TreeViewHighlightRect: Sendable, Equatable {
    public var nodeId: Int
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rx: Double

    public init(nodeId: Int, x: Double, y: Double, width: Double, height: Double, rx: Double = 3) {
        self.nodeId = nodeId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rx = rx
    }
}

public struct PositionedTreeViewDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var nodes: [PositionedTreeViewNode]
    public var connectorLines: [TreeViewConnectorLine]
    public var highlightRects: [TreeViewHighlightRect]
    public var descriptionX: Double?
    public var viewBoxX: Double
    public var viewBoxY: Double
    public var viewBoxWidth: Double
    public var viewBoxHeight: Double
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: TreeViewDiagramConfig
    public var theme: TreeViewThemeVariables?
    public var iconDefs: [String]

    public static let empty = PositionedTreeViewDiagram(
        width: 0, height: 0,
        nodes: [], connectorLines: [], highlightRects: [],
        viewBoxX: 0, viewBoxY: 0, viewBoxWidth: 0, viewBoxHeight: 0,
        config: .default, iconDefs: []
    )

    public init(
        width: Double, height: Double,
        nodes: [PositionedTreeViewNode],
        connectorLines: [TreeViewConnectorLine],
        highlightRects: [TreeViewHighlightRect],
        descriptionX: Double? = nil,
        viewBoxX: Double, viewBoxY: Double,
        viewBoxWidth: Double, viewBoxHeight: Double,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: TreeViewDiagramConfig = .default,
        theme: TreeViewThemeVariables? = nil,
        iconDefs: [String] = []
    ) {
        self.width = width
        self.height = height
        self.nodes = nodes
        self.connectorLines = connectorLines
        self.highlightRects = highlightRects
        self.descriptionX = descriptionX
        self.viewBoxX = viewBoxX
        self.viewBoxY = viewBoxY
        self.viewBoxWidth = viewBoxWidth
        self.viewBoxHeight = viewBoxHeight
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
        self.iconDefs = iconDefs
    }
}

// MARK: - Parser Errors

public enum TreeViewParserError: Error, LocalizedError {
    case invalidHeader(String)
    case emptySource
    case invalidLine(String)
    case missingLabel(String)

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let h): return "Invalid treeView header: \(h)"
        case .emptySource: return "TreeView source is empty"
        case .invalidLine(let s): return "Invalid treeView line: \(s)"
        case .missingLabel(let s): return "Missing label in treeView line: \(s)"
        }
    }
}
