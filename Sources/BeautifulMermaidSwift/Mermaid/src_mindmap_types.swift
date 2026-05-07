import Foundation

public enum MindmapNodeType: Int, Sendable, Equatable, CaseIterable {
    case `default` = 0
    case roundedRect = 1
    case rect = 2
    case circle = 3
    case cloud = 4
    case bang = 5
    case hexagon = 6

    public var type2Str: String {
        switch self {
        case .default: return "no-border"
        case .roundedRect: return "rounded-rect"
        case .rect: return "rect"
        case .circle: return "circle"
        case .cloud: return "cloud"
        case .bang: return "bang"
        case .hexagon: return "hexagon"
        }
    }

    public var rendererShapeName: String {
        switch self {
        case .default: return "defaultMindmapNode"
        case .roundedRect: return "rounded"
        case .rect: return "rect"
        case .circle: return "mindmapCircle"
        case .cloud: return "cloud"
        case .bang: return "bang"
        case .hexagon: return "hexagon"
        }
    }
}

public struct MindmapNode: Sendable, Equatable, Identifiable {
    public var id: Int
    public var nodeId: String
    public var level: Int
    public var descr: String
    public var type: MindmapNodeType
    public var children: [MindmapNode]
    public var width: Double
    public var padding: Double
    public var section: Int?
    public var cssClass: String?
    public var icon: String?
    public var isRoot: Bool

    public init(
        id: Int = 0,
        nodeId: String = "",
        level: Int = 0,
        descr: String = "",
        type: MindmapNodeType = .default,
        children: [MindmapNode] = [],
        width: Double = 200,
        padding: Double = 10,
        section: Int? = nil,
        cssClass: String? = nil,
        icon: String? = nil,
        isRoot: Bool = false
    ) {
        self.id = id
        self.nodeId = nodeId
        self.level = level
        self.descr = descr
        self.type = type
        self.children = children
        self.width = width
        self.padding = padding
        self.section = section
        self.cssClass = cssClass
        self.icon = icon
        self.isRoot = isRoot
    }
}

public struct MindmapDiagram: Sendable, Equatable {
    public var root: MindmapNode?
    public var nodes: [MindmapNode]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: MindmapConfig
    public var theme: MindmapThemeConfig

    public static var empty: MindmapDiagram {
        MindmapDiagram(config: MindmapConfig())
    }

    public init(
        root: MindmapNode? = nil,
        nodes: [MindmapNode] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: MindmapConfig = MindmapConfig(),
        theme: MindmapThemeConfig = .default
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

public struct MindmapConfig: Sendable, Equatable {
    public var padding: Double
    public var maxNodeWidth: Double
    public var useMaxWidth: Bool
    public var layoutAlgorithm: String
    public var layout: String?
    public var look: String?
    public var theme: String?
    public var htmlLabels: Bool?
    public var fontSize: Double?
    public var securityLevel: String?

    public init(
        padding: Double = 10,
        maxNodeWidth: Double = 200,
        useMaxWidth: Bool = true,
        layoutAlgorithm: String = "tidy-tree",
        layout: String? = nil,
        look: String? = nil,
        theme: String? = nil,
        htmlLabels: Bool? = nil,
        fontSize: Double? = nil,
        securityLevel: String? = nil
    ) {
        self.padding = padding
        self.maxNodeWidth = maxNodeWidth
        self.useMaxWidth = useMaxWidth
        self.layoutAlgorithm = layoutAlgorithm
        self.layout = layout
        self.look = look
        self.theme = theme
        self.htmlLabels = htmlLabels
        self.fontSize = fontSize
        self.securityLevel = securityLevel
    }

    public var resolvedLayout: String {
        layout ?? layoutAlgorithm
    }

    public static let `default` = MindmapConfig()
}

public struct MindmapThemeConfig: Sendable, Equatable {
    public var cScale0: String
    public var cScale1: String
    public var cScale2: String
    public var cScale3: String
    public var cScale4: String
    public var cScale5: String
    public var cScale6: String
    public var cScale7: String
    public var cScale8: String
    public var cScale9: String
    public var cScale10: String
    public var cScale11: String

    public var cScaleLabel0: String
    public var cScaleLabel1: String
    public var cScaleLabel2: String
    public var cScaleLabel3: String
    public var cScaleLabel4: String
    public var cScaleLabel5: String
    public var cScaleLabel6: String
    public var cScaleLabel7: String
    public var cScaleLabel8: String
    public var cScaleLabel9: String
    public var cScaleLabel10: String
    public var cScaleLabel11: String

    public var cScaleInv0: String
    public var cScaleInv1: String
    public var cScaleInv2: String
    public var cScaleInv3: String
    public var cScaleInv4: String
    public var cScaleInv5: String
    public var cScaleInv6: String
    public var cScaleInv7: String
    public var cScaleInv8: String
    public var cScaleInv9: String
    public var cScaleInv10: String
    public var cScaleInv11: String

    public var git0: String
    public var gitBranchLabel0: String

    public var mainBkg: String
    public var nodeBorder: String
    public var strokeWidth: Double
    public var useGradient: Bool
    public var gradientStart: String
    public var gradientStop: String
    public var dropShadow: Bool
    public var fontSize: Double

    public var fontFamily: String

    public static let `default` = MindmapThemeConfig()

    public init(
        cScale0: String = "#0052CC",
        cScale1: String = "#0065FF",
        cScale2: String = "#2684FF",
        cScale3: String = "#4C9AFF",
        cScale4: String = "#84B9FF",
        cScale5: String = "#A5CCFF",
        cScale6: String = "#C6DFFF",
        cScale7: String = "#0052CC",
        cScale8: String = "#0065FF",
        cScale9: String = "#2684FF",
        cScale10: String = "#4C9AFF",
        cScale11: String = "#84B9FF",
        cScaleLabel0: String = "#ffffff",
        cScaleLabel1: String = "#ffffff",
        cScaleLabel2: String = "#ffffff",
        cScaleLabel3: String = "#ffffff",
        cScaleLabel4: String = "#172B4D",
        cScaleLabel5: String = "#172B4D",
        cScaleLabel6: String = "#172B4D",
        cScaleLabel7: String = "#ffffff",
        cScaleLabel8: String = "#ffffff",
        cScaleLabel9: String = "#ffffff",
        cScaleLabel10: String = "#ffffff",
        cScaleLabel11: String = "#172B4D",
        cScaleInv0: String = "#003380",
        cScaleInv1: String = "#003D99",
        cScaleInv2: String = "#1750B3",
        cScaleInv3: String = "#3063B3",
        cScaleInv4: String = "#537399",
        cScaleInv5: String = "#6B8099",
        cScaleInv6: String = "#8099B3",
        cScaleInv7: String = "#003380",
        cScaleInv8: String = "#003D99",
        cScaleInv9: String = "#1750B3",
        cScaleInv10: String = "#3063B3",
        cScaleInv11: String = "#537399",
        git0: String = "#1f2020",
        gitBranchLabel0: String = "#ffffff",
        mainBkg: String = "#f4f4f4",
        nodeBorder: String = "#1f2020",
        strokeWidth: Double = 1,
        useGradient: Bool = false,
        gradientStart: String = "#ffffff",
        gradientStop: String = "#f4f4f4",
        dropShadow: Bool = false,
        fontSize: Double = 16,
        fontFamily: String = "Inter"
    ) {
        self.cScale0 = cScale0
        self.cScale1 = cScale1
        self.cScale2 = cScale2
        self.cScale3 = cScale3
        self.cScale4 = cScale4
        self.cScale5 = cScale5
        self.cScale6 = cScale6
        self.cScale7 = cScale7
        self.cScale8 = cScale8
        self.cScale9 = cScale9
        self.cScale10 = cScale10
        self.cScale11 = cScale11
        self.cScaleLabel0 = cScaleLabel0
        self.cScaleLabel1 = cScaleLabel1
        self.cScaleLabel2 = cScaleLabel2
        self.cScaleLabel3 = cScaleLabel3
        self.cScaleLabel4 = cScaleLabel4
        self.cScaleLabel5 = cScaleLabel5
        self.cScaleLabel6 = cScaleLabel6
        self.cScaleLabel7 = cScaleLabel7
        self.cScaleLabel8 = cScaleLabel8
        self.cScaleLabel9 = cScaleLabel9
        self.cScaleLabel10 = cScaleLabel10
        self.cScaleLabel11 = cScaleLabel11
        self.cScaleInv0 = cScaleInv0
        self.cScaleInv1 = cScaleInv1
        self.cScaleInv2 = cScaleInv2
        self.cScaleInv3 = cScaleInv3
        self.cScaleInv4 = cScaleInv4
        self.cScaleInv5 = cScaleInv5
        self.cScaleInv6 = cScaleInv6
        self.cScaleInv7 = cScaleInv7
        self.cScaleInv8 = cScaleInv8
        self.cScaleInv9 = cScaleInv9
        self.cScaleInv10 = cScaleInv10
        self.cScaleInv11 = cScaleInv11
        self.git0 = git0
        self.gitBranchLabel0 = gitBranchLabel0
        self.mainBkg = mainBkg
        self.nodeBorder = nodeBorder
        self.strokeWidth = strokeWidth
        self.useGradient = useGradient
        self.gradientStart = gradientStart
        self.gradientStop = gradientStop
        self.dropShadow = dropShadow
        self.fontSize = fontSize
        self.fontFamily = fontFamily
    }

    public func cScale(for section: Int) -> String {
        let s = section >= 0 ? section : 0
        switch s {
        case 0: return cScale0
        case 1: return cScale1
        case 2: return cScale2
        case 3: return cScale3
        case 4: return cScale4
        case 5: return cScale5
        case 6: return cScale6
        case 7: return cScale7
        case 8: return cScale8
        case 9: return cScale9
        case 10: return cScale10
        default: return cScale11
        }
    }

    public func cScaleLabel(for section: Int) -> String {
        let s = section >= 0 ? section : 0
        switch s {
        case 0: return cScaleLabel0
        case 1: return cScaleLabel1
        case 2: return cScaleLabel2
        case 3: return cScaleLabel3
        case 4: return cScaleLabel4
        case 5: return cScaleLabel5
        case 6: return cScaleLabel6
        case 7: return cScaleLabel7
        case 8: return cScaleLabel8
        case 9: return cScaleLabel9
        case 10: return cScaleLabel10
        default: return cScaleLabel11
        }
    }

    public func cScaleInv(for section: Int) -> String {
        let s = section >= 0 ? section : 0
        switch s {
        case 0: return cScaleInv0
        case 1: return cScaleInv1
        case 2: return cScaleInv2
        case 3: return cScaleInv3
        case 4: return cScaleInv4
        case 5: return cScaleInv5
        case 6: return cScaleInv6
        case 7: return cScaleInv7
        case 8: return cScaleInv8
        case 9: return cScaleInv9
        case 10: return cScaleInv10
        default: return cScaleInv11
        }
    }
}

public struct PositionedMindmapNode: Sendable, Equatable {
    public let id: Int
    public let nodeId: String
    public let descr: String
    public let type: MindmapNodeType
    public let level: Int
    public let section: Int?
    public let cssClass: String?
    public let icon: String?
    public let isRoot: Bool
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public let shapeName: String

    public init(
        id: Int,
        nodeId: String,
        descr: String,
        type: MindmapNodeType,
        level: Int,
        section: Int?,
        cssClass: String?,
        icon: String?,
        isRoot: Bool,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        shapeName: String = ""
    ) {
        self.id = id
        self.nodeId = nodeId
        self.descr = descr
        self.type = type
        self.level = level
        self.section = section
        self.cssClass = cssClass
        self.icon = icon
        self.isRoot = isRoot
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.shapeName = shapeName
    }

    public var fullCssClass: String {
        var parts: [String] = ["mindmap-node"]
        if let section = section {
            parts.append("section-\(section)")
        } else {
            parts.append("section-root")
            parts.append("section--1")
        }
        if let c = cssClass, !c.isEmpty {
            parts.append(c)
        }
        return parts.joined(separator: " ")
    }
}

public struct PositionedMindmapEdge: Sendable, Equatable {
    public let id: String
    public let parentId: Int
    public let childId: Int
    public let section: Int?
    public let depth: Int
    public var path: String?
    public var points: [CGPoint]

    public init(
        id: String,
        parentId: Int,
        childId: Int,
        section: Int?,
        depth: Int,
        path: String? = nil,
        points: [CGPoint] = []
    ) {
        self.id = id
        self.parentId = parentId
        self.childId = childId
        self.section = section
        self.depth = depth
        self.path = path
        self.points = points
    }

    public var edgeCssClass: String {
        var parts: [String] = ["edge"]
        if let s = section {
            parts.append("section-edge-\(s)")
        }
        parts.append("edge-depth-\(depth)")
        return parts.joined(separator: " ")
    }
}

public struct PositionedMindmapDiagram: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var nodes: [PositionedMindmapNode]
    public var edges: [PositionedMindmapEdge]
    public var rootNode: PositionedMindmapNode?
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: MindmapConfig
    public var theme: MindmapThemeConfig

    public static var empty: PositionedMindmapDiagram {
        PositionedMindmapDiagram(width: 0, height: 0, nodes: [], edges: [], config: MindmapConfig(), theme: .default)
    }

    public init(
        width: Double = 0,
        height: Double = 0,
        nodes: [PositionedMindmapNode] = [],
        edges: [PositionedMindmapEdge] = [],
        rootNode: PositionedMindmapNode? = nil,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: MindmapConfig = MindmapConfig(),
        theme: MindmapThemeConfig = .default
    ) {
        self.width = width
        self.height = height
        self.nodes = nodes
        self.edges = edges
        self.rootNode = rootNode
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }
}

public enum MindmapParserError: Error, LocalizedError {
    case missingHeader
    case multipleRoots(nodeDescription: String)
    case invalidShapeSyntax(String)
    case emptyDocument

    public var errorDescription: String? {
        switch self {
        case .missingHeader:
            return "Mindmap diagram must start with 'mindmap'."
        case .multipleRoots(let nodeDescription):
            return "There can be only one root. No parent could be found for (\"\(nodeDescription)\")."
        case .invalidShapeSyntax(let detail):
            return "Invalid mindmap node shape syntax: \(detail)"
        case .emptyDocument:
            return "Mindmap diagram must contain at least a root node."
        }
    }
}
