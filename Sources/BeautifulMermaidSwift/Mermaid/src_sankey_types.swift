import Foundation
import CoreGraphics

public struct SankeyDiagram: Sendable {
    public var nodes: [SankeyNode]
    public var links: [SankeyLink]
    public var config: SankeyDiagramConfig
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?

    public init(
        nodes: [SankeyNode] = [],
        links: [SankeyLink] = [],
        config: SankeyDiagramConfig = .default,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil
    ) {
        self.nodes = nodes
        self.links = links
        self.config = config
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
    }

    public static var empty: SankeyDiagram {
        SankeyDiagram()
    }

    public func graphProjection() -> SankeyGraphProjection {
        SankeyGraphProjection(
            nodes: nodes.map { SankeyProjectedNode(id: $0.id) },
            links: links.map { SankeyProjectedLink(source: $0.source.id, target: $0.target.id, value: $0.value) }
        )
    }
}

public struct SankeyNode: Sendable, Identifiable {
    public let id: String
    public let rawID: String

    public init(id: String, rawID: String? = nil) {
        self.id = id
        self.rawID = rawID ?? id
    }
}

public struct SankeyLink: Sendable {
    public let source: SankeyNode
    public let target: SankeyNode
    public let value: Double

    public init(source: SankeyNode, target: SankeyNode, value: Double) {
        self.source = source
        self.target = target
        self.value = value
    }
}

public struct SankeyGraphProjection: Sendable {
    public var nodes: [SankeyProjectedNode]
    public var links: [SankeyProjectedLink]

    public init(nodes: [SankeyProjectedNode], links: [SankeyProjectedLink]) {
        self.nodes = nodes
        self.links = links
    }
}

public struct SankeyProjectedNode: Sendable {
    public var id: String

    public init(id: String) {
        self.id = id
    }
}

public struct SankeyProjectedLink: Sendable {
    public var source: String
    public var target: String
    public var value: Double

    public init(source: String, target: String, value: Double) {
        self.source = source
        self.target = target
        self.value = value
    }
}

public struct PositionedSankeyDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var nodes: [PositionedSankeyNode]
    public var links: [PositionedSankeyLink]
    public var config: SankeyDiagramConfig
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?

    public init(
        width: Double = 600,
        height: Double = 400,
        nodes: [PositionedSankeyNode] = [],
        links: [PositionedSankeyLink] = [],
        config: SankeyDiagramConfig = .default,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil
    ) {
        self.width = width
        self.height = height
        self.nodes = nodes
        self.links = links
        self.config = config
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
    }

    public static var empty: PositionedSankeyDiagram {
        PositionedSankeyDiagram()
    }
}

public struct PositionedSankeyNode: Sendable, Identifiable {
    public let id: String
    public var x0: Double
    public var x1: Double
    public var y0: Double
    public var y1: Double
    public var value: Double
    public var layer: Int

    public init(id: String, x0: Double, x1: Double, y0: Double, y1: Double, value: Double, layer: Int) {
        self.id = id
        self.x0 = x0
        self.x1 = x1
        self.y0 = y0
        self.y1 = y1
        self.value = value
        self.layer = layer
    }
}

public struct PositionedSankeyLink: Sendable {
    public let sourceID: String
    public let targetID: String
    public let value: Double
    public var width: Double
    public var y0: Double
    public var y1: Double
    public var path: SankeyLinkPath

    public init(sourceID: String, targetID: String, value: Double, width: Double, y0: Double, y1: Double, path: SankeyLinkPath) {
        self.sourceID = sourceID
        self.targetID = targetID
        self.value = value
        self.width = width
        self.y0 = y0
        self.y1 = y1
        self.path = path
    }
}

public struct SankeyLinkPath: Sendable {
    public var sourceX: Double
    public var sourceY: Double
    public var targetX: Double
    public var targetY: Double
    public var controlPoints: [CGPoint]

    public init(sourceX: Double, sourceY: Double, targetX: Double, targetY: Double, controlPoints: [CGPoint]) {
        self.sourceX = sourceX
        self.sourceY = sourceY
        self.targetX = targetX
        self.targetY = targetY
        self.controlPoints = controlPoints
    }

    public var svgD: String {
        let cp1 = controlPoints[0]
        let cp2 = controlPoints[1]
        return "M \(_fmt(sourceX)),\(_fmt(sourceY)) C \(_fmt(cp1.x)),\(_fmt(cp1.y)),\(_fmt(cp2.x)),\(_fmt(cp2.y)),\(_fmt(targetX)),\(_fmt(targetY))"
    }

    public var cgPath: CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: sourceX, y: sourceY))
        p.addCurve(to: CGPoint(x: targetX, y: targetY),
                    control1: CGPoint(x: controlPoints[0].x, y: controlPoints[0].y),
                    control2: CGPoint(x: controlPoints[1].x, y: controlPoints[1].y))
        return p
    }
}

private func _fmt(_ v: Double) -> String {
    let rounded = (v * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

public struct SankeyDiagramConfig: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var linkColor: SankeyLinkColor
    public var nodeAlignment: SankeyNodeAlignment
    public var useMaxWidth: Bool
    public var showValues: Bool
    public var prefix: String
    public var suffix: String
    public var nodeWidth: Double
    public var nodePadding: Double
    public var labelStyle: SankeyLabelStyle
    public var nodeColors: [String: String]

    public init(
        width: Double = 600,
        height: Double = 400,
        linkColor: SankeyLinkColor = .gradient,
        nodeAlignment: SankeyNodeAlignment = .justify,
        useMaxWidth: Bool = false,
        showValues: Bool = true,
        prefix: String = "",
        suffix: String = "",
        nodeWidth: Double = 10,
        nodePadding: Double = 12,
        labelStyle: SankeyLabelStyle = .legacy,
        nodeColors: [String: String] = [:]
    ) {
        self.width = width
        self.height = height
        self.linkColor = linkColor
        self.nodeAlignment = nodeAlignment
        self.useMaxWidth = useMaxWidth
        self.showValues = showValues
        self.prefix = prefix
        self.suffix = suffix
        self.nodeWidth = nodeWidth
        self.nodePadding = nodePadding
        self.labelStyle = labelStyle
        self.nodeColors = nodeColors
    }

    public static let `default` = SankeyDiagramConfig()
}

public enum SankeyLinkColor: Sendable, Equatable {
    case source
    case target
    case gradient
    case fixed(String)
}

public enum SankeyNodeAlignment: String, Sendable, Equatable {
    case left
    case right
    case center
    case justify
}

public enum SankeyLabelStyle: String, Sendable, Equatable {
    case legacy
    case outlined
}

public let sankeyTableau10: [String] = [
    "#4e79a7", "#f28e2c", "#e15759", "#76b7b2", "#59a14f",
    "#edc949", "#af7aa1", "#ff9da7", "#9c755f", "#bab0ab",
]
