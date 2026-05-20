import Foundation

public enum ArchitectureDirection: String, Sendable, Equatable, CaseIterable {
    case L, R, T, B
}

/// Discriminates how an `ArchitectureService` should render. Defaults to
/// `.service` for back-compat with sources that don't carry a shape token.
/// `.component` / `.interface` come from PlantUML's component dialect.
/// The remaining cases come from PlantUML's deployment dialect.
public enum ArchitectureServiceKind: String, Sendable, Equatable, CaseIterable {
    case service
    case component
    case interface
    case node
    case artifact
    case database
    case cloud
    case frame
    case folder
    case package
    case card
    case queue
    case stack
    case storage
    case agent
    case actor
    case boundary
}

public struct ArchitectureService: Sendable, Equatable {
    public var id: String
    public var icon: String?
    public var iconText: String?
    public var title: String?
    public var parentGroupId: String?
    public var kind: ArchitectureServiceKind
    public var width: Double = 0
    public var height: Double = 0

    public init(
        id: String,
        icon: String? = nil,
        iconText: String? = nil,
        title: String? = nil,
        parentGroupId: String? = nil,
        kind: ArchitectureServiceKind = .service
    ) {
        self.id = id
        self.icon = icon
        self.iconText = iconText
        self.title = title
        self.parentGroupId = parentGroupId
        self.kind = kind
    }
}

public struct ArchitectureJunction: Sendable, Equatable {
    public var id: String
    public var parentGroupId: String?
    public var width: Double = 0
    public var height: Double = 0

    public init(id: String, parentGroupId: String? = nil) {
        self.id = id
        self.parentGroupId = parentGroupId
    }
}

public struct ArchitectureGroup: Sendable, Equatable {
    public var id: String
    public var icon: String?
    public var title: String?
    public var parentGroupId: String?

    public init(id: String, icon: String? = nil, title: String? = nil, parentGroupId: String? = nil) {
        self.id = id
        self.icon = icon
        self.title = title
        self.parentGroupId = parentGroupId
    }
}

public struct ArchitectureEdge: Sendable, Equatable {
    public var lhsId: String
    public var rhsId: String
    public var lhsDirection: ArchitectureDirection
    public var rhsDirection: ArchitectureDirection
    public var sourceArrow: Bool
    public var targetArrow: Bool
    public var lhsGroupBoundary: Bool
    public var rhsGroupBoundary: Bool
    public var label: String?

    public init(
        lhsId: String,
        rhsId: String,
        lhsDirection: ArchitectureDirection,
        rhsDirection: ArchitectureDirection,
        sourceArrow: Bool = false,
        targetArrow: Bool = false,
        lhsGroupBoundary: Bool = false,
        rhsGroupBoundary: Bool = false,
        label: String? = nil
    ) {
        self.lhsId = lhsId
        self.rhsId = rhsId
        self.lhsDirection = lhsDirection
        self.rhsDirection = rhsDirection
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.lhsGroupBoundary = lhsGroupBoundary
        self.rhsGroupBoundary = rhsGroupBoundary
        self.label = label
    }
}

public struct ArchitectureDiagram: Sendable, Equatable {
    public var groups: [ArchitectureGroup]
    public var services: [ArchitectureService]
    public var junctions: [ArchitectureJunction]
    public var edges: [ArchitectureEdge]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: ArchitectureDiagramConfig
    public var theme: ArchitectureThemeConfig?

    public init(
        groups: [ArchitectureGroup] = [],
        services: [ArchitectureService] = [],
        junctions: [ArchitectureJunction] = [],
        edges: [ArchitectureEdge] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: ArchitectureDiagramConfig = .default,
        theme: ArchitectureThemeConfig? = nil
    ) {
        self.groups = groups
        self.services = services
        self.junctions = junctions
        self.edges = edges
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }

    public static let empty = ArchitectureDiagram()
}

public struct ArchitectureDiagramConfig: Sendable, Equatable {
    public var padding: Double
    public var iconSize: Double
    public var fontSize: Double
    public var randomize: Bool
    public var useMaxWidth: Bool

    public init(
        padding: Double = 40,
        iconSize: Double = 80,
        fontSize: Double = 16,
        randomize: Bool = false,
        useMaxWidth: Bool = true
    ) {
        self.padding = padding
        self.iconSize = iconSize
        self.fontSize = fontSize
        self.randomize = randomize
        self.useMaxWidth = useMaxWidth
    }

    public static let `default` = ArchitectureDiagramConfig()
}

public struct ArchitectureThemeConfig: Sendable, Equatable {
    public var archEdgeColor: String
    public var archEdgeArrowColor: String
    public var archEdgeWidth: String
    public var archGroupBorderColor: String
    public var archGroupBorderWidth: String

    public init(
        archEdgeColor: String = "#777",
        archEdgeArrowColor: String = "#777",
        archEdgeWidth: String = "3",
        archGroupBorderColor: String = "#000000",
        archGroupBorderWidth: String = "2px"
    ) {
        self.archEdgeColor = archEdgeColor
        self.archEdgeArrowColor = archEdgeArrowColor
        self.archEdgeWidth = archEdgeWidth
        self.archGroupBorderColor = archGroupBorderColor
        self.archGroupBorderWidth = archGroupBorderWidth
    }

    public static let `default` = ArchitectureThemeConfig()
}

public struct PositionedArchitectureService: Sendable {
    public var id: String
    public var icon: String?
    public var iconText: String?
    public var title: String?
    public var parentGroupId: String?
    public var kind: ArchitectureServiceKind
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(
        id: String,
        icon: String? = nil,
        iconText: String? = nil,
        title: String? = nil,
        parentGroupId: String? = nil,
        kind: ArchitectureServiceKind = .service,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0
    ) {
        self.id = id
        self.icon = icon
        self.iconText = iconText
        self.title = title
        self.parentGroupId = parentGroupId
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PositionedArchitectureJunction: Sendable {
    public var id: String
    public var parentGroupId: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: String, parentGroupId: String? = nil, x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.id = id
        self.parentGroupId = parentGroupId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PositionedArchitectureGroup: Sendable {
    public var id: String
    public var icon: String?
    public var title: String?
    public var parentGroupId: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(id: String, icon: String? = nil, title: String? = nil, parentGroupId: String? = nil, x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.id = id
        self.icon = icon
        self.title = title
        self.parentGroupId = parentGroupId
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PositionedArchitectureEdge: Sendable {
    public var id: String
    public var lhsId: String
    public var rhsId: String
    public var lhsDirection: ArchitectureDirection
    public var rhsDirection: ArchitectureDirection
    public var sourceArrow: Bool
    public var targetArrow: Bool
    public var lhsGroupBoundary: Bool
    public var rhsGroupBoundary: Bool
    public var label: String?
    public var startX: Double
    public var startY: Double
    public var midX: Double
    public var midY: Double
    public var endX: Double
    public var endY: Double

    public init(
        id: String,
        lhsId: String,
        rhsId: String,
        lhsDirection: ArchitectureDirection,
        rhsDirection: ArchitectureDirection,
        sourceArrow: Bool = false,
        targetArrow: Bool = false,
        lhsGroupBoundary: Bool = false,
        rhsGroupBoundary: Bool = false,
        label: String? = nil,
        startX: Double = 0,
        startY: Double = 0,
        midX: Double = 0,
        midY: Double = 0,
        endX: Double = 0,
        endY: Double = 0
    ) {
        self.id = id
        self.lhsId = lhsId
        self.rhsId = rhsId
        self.lhsDirection = lhsDirection
        self.rhsDirection = rhsDirection
        self.sourceArrow = sourceArrow
        self.targetArrow = targetArrow
        self.lhsGroupBoundary = lhsGroupBoundary
        self.rhsGroupBoundary = rhsGroupBoundary
        self.label = label
        self.startX = startX
        self.startY = startY
        self.midX = midX
        self.midY = midY
        self.endX = endX
        self.endY = endY
    }
}

public struct PositionedArchitectureDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var services: [PositionedArchitectureService]
    public var junctions: [PositionedArchitectureJunction]
    public var groups: [PositionedArchitectureGroup]
    public var edges: [PositionedArchitectureEdge]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: ArchitectureDiagramConfig
    public var theme: ArchitectureThemeConfig?

    public init(
        width: Double = 0,
        height: Double = 0,
        services: [PositionedArchitectureService] = [],
        junctions: [PositionedArchitectureJunction] = [],
        groups: [PositionedArchitectureGroup] = [],
        edges: [PositionedArchitectureEdge] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: ArchitectureDiagramConfig = .default,
        theme: ArchitectureThemeConfig? = nil
    ) {
        self.width = width
        self.height = height
        self.services = services
        self.junctions = junctions
        self.groups = groups
        self.edges = edges
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }

    public static let empty = PositionedArchitectureDiagram()
}
