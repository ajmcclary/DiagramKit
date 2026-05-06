import Foundation

public enum BlockNodeType: String, Sendable, CaseIterable {
    case na
    case columnSetting = "column-setting"
    case edge
    case square
    case round
    case circle
    case doublecircle
    case diamond
    case hexagon
    case stadium
    case subroutine
    case cylinder
    case leanRight = "lean_right"
    case leanLeft = "lean_left"
    case trapezoid
    case invTrapezoid = "inv_trapezoid"
    case rectLeftInvArrow = "rect_left_inv_arrow"
    case blockArrow = "block_arrow"
    case space
    case composite
    case classDef
    case applyClass
    case applyStyles
}

public enum BlockDirection: String, Sendable, CaseIterable {
    case up, down, left, right, x, y
}

public struct BlockSize: Sendable {
    public var width: Double
    public var height: Double
    public var x: Double
    public var y: Double

    public init(width: Double = 0, height: Double = 0, x: Double = 0, y: Double = 0) {
        self.width = width
        self.height = height
        self.x = x
        self.y = y
    }
}

public struct BlockNode: Sendable {
    public var id: String
    public var label: String
    public var type: BlockNodeType
    public var children: [String]
    public var columns: Int?
    public var widthInColumns: Int?
    public var classes: [String]?
    public var styles: [String]?
    public var styleClass: String?
    public var stylesStr: String?
    public var directions: [BlockDirection]?
    public var size: BlockSize?
    public var start: String?
    public var end: String?
    public var arrowTypeEnd: String?
    public var arrowTypeStart: String?
    public var thickness: String?
    public var pattern: String?
    public var csstext: String?

    public init(
        id: String,
        label: String = "",
        type: BlockNodeType = .na,
        children: [String] = [],
        columns: Int? = nil,
        widthInColumns: Int? = nil,
        classes: [String]? = nil,
        styles: [String]? = nil,
        styleClass: String? = nil,
        stylesStr: String? = nil,
        directions: [BlockDirection]? = nil,
        size: BlockSize? = nil,
        start: String? = nil,
        end: String? = nil,
        arrowTypeEnd: String? = nil,
        arrowTypeStart: String? = nil,
        thickness: String? = nil,
        pattern: String? = nil,
        csstext: String? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.children = children
        self.columns = columns
        self.widthInColumns = widthInColumns
        self.classes = classes
        self.styles = styles
        self.styleClass = styleClass
        self.stylesStr = stylesStr
        self.directions = directions
        self.size = size
        self.start = start
        self.end = end
        self.arrowTypeEnd = arrowTypeEnd
        self.arrowTypeStart = arrowTypeStart
        self.thickness = thickness
        self.pattern = pattern
        self.csstext = csstext
    }
}

public struct BlockEdge: Sendable {
    public var id: String
    public var start: String
    public var end: String
    public var label: String?
    public var thickness: String
    public var pattern: String
    public var arrowTypeEnd: String
    public var arrowTypeStart: String

    public init(
        id: String,
        start: String,
        end: String,
        label: String? = nil,
        thickness: String = "normal",
        pattern: String = "solid",
        arrowTypeEnd: String = "",
        arrowTypeStart: String = "arrow_open"
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.label = label
        self.thickness = thickness
        self.pattern = pattern
        self.arrowTypeEnd = arrowTypeEnd
        self.arrowTypeStart = arrowTypeStart
    }
}

public struct BlockClassDef: Sendable {
    public var id: String
    public var styles: [String]
    public var textStyles: [String]

    public init(id: String, styles: [String] = [], textStyles: [String] = []) {
        self.id = id
        self.styles = styles
        self.textStyles = textStyles
    }
}

public struct BlockDiagramConfig: Sendable, Equatable {
    public var padding: Double
    public var useMaxWidth: Bool

    public init(padding: Double = 8, useMaxWidth: Bool = true) {
        self.padding = padding
        self.useMaxWidth = useMaxWidth
    }

    public static let `default` = BlockDiagramConfig()
}

public struct BlockDiagram: Sendable {
    public var rootId: String
    public var rootChildren: [String]
    public var blockDatabase: [String: BlockNode]
    public var edges: [BlockEdge]
    public var classes: [String: BlockClassDef]
    public var config: BlockDiagramConfig
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?

    public init(
        rootId: String = "root",
        rootChildren: [String] = [],
        blockDatabase: [String: BlockNode] = ["root": BlockNode(id: "root", type: .composite, children: [], columns: -1)],
        edges: [BlockEdge] = [],
        classes: [String: BlockClassDef] = [:],
        config: BlockDiagramConfig = .default,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil
    ) {
        self.rootId = rootId
        self.rootChildren = rootChildren
        self.blockDatabase = blockDatabase
        self.edges = edges
        self.classes = classes
        self.config = config
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
    }

    public static let empty = BlockDiagram()
}

public struct BlockBounds: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct PositionedBlockNode: Sendable {
    public var id: String
    public var label: String
    public var type: BlockNodeType
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var children: [PositionedBlockNode]
    public var classes: [String]
    public var styles: [String]
    public var labelStyle: String?
    public var directions: [BlockDirection]?
    public var rx: Double?
    public var ry: Double?
    public var domId: String?

    public init(
        id: String,
        label: String = "",
        type: BlockNodeType = .na,
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        children: [PositionedBlockNode] = [],
        classes: [String] = [],
        styles: [String] = [],
        labelStyle: String? = nil,
        directions: [BlockDirection]? = nil,
        rx: Double? = nil,
        ry: Double? = nil,
        domId: String? = nil
    ) {
        self.id = id
        self.label = label
        self.type = type
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.children = children
        self.classes = classes
        self.styles = styles
        self.labelStyle = labelStyle
        self.directions = directions
        self.rx = rx
        self.ry = ry
        self.domId = domId
    }
}

public struct PositionedBlockEdge: Sendable {
    public var id: String
    public var startId: String
    public var endId: String
    public var label: String?
    public var points: [CGPoint]
    public var thickness: String
    public var pattern: String
    public var arrowTypeEnd: String
    public var arrowTypeStart: String

    public init(
        id: String,
        startId: String,
        endId: String,
        label: String? = nil,
        points: [CGPoint] = [],
        thickness: String = "normal",
        pattern: String = "solid",
        arrowTypeEnd: String = "",
        arrowTypeStart: String = "arrow_open"
    ) {
        self.id = id
        self.startId = startId
        self.endId = endId
        self.label = label
        self.points = points
        self.thickness = thickness
        self.pattern = pattern
        self.arrowTypeEnd = arrowTypeEnd
        self.arrowTypeStart = arrowTypeStart
    }
}

public struct PositionedBlockDiagram: Sendable {
    public var blocks: [PositionedBlockNode]
    public var edges: [PositionedBlockEdge]
    public var width: Double
    public var height: Double
    public var bounds: BlockBounds
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?

    public init(
        blocks: [PositionedBlockNode] = [],
        edges: [PositionedBlockEdge] = [],
        width: Double = 0,
        height: Double = 0,
        bounds: BlockBounds = BlockBounds(),
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil
    ) {
        self.blocks = blocks
        self.edges = edges
        self.width = width
        self.height = height
        self.bounds = bounds
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
    }

    public static let empty = PositionedBlockDiagram()
}

private let blockIdCounter = AtomicInt()

func generateBlockId() -> String {
    let count = blockIdCounter.increment()
    let uuidStr = UUID().uuidString
    let prefix = String(uuidStr.prefix(12))
    return "id-" + prefix + "-" + String(count)
}

private final class AtomicInt: @unchecked Sendable {
    private var value: Int = 0
    private let lock = NSLock()
    init() {}
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

func typeStr2BlockType(_ typeStr: String) -> BlockNodeType {
    switch typeStr {
    case "[]": return .square
    case "()": return .round
    case "(())": return .circle
    case ">]": return .rectLeftInvArrow
    case "{}": return .diamond
    case "{{}}": return .hexagon
    case "([])": return .stadium
    case "[[]]": return .subroutine
    case "[()]": return .cylinder
    case "((()))": return .doublecircle
    case "[//]": return .leanRight
    case "[\\\\]": return .leanLeft
    case "[/\\\\]": return .trapezoid
    case "[\\\\/]": return .invTrapezoid
    case "<[]>": return .blockArrow
    default: return .na
    }
}

func edgeTypeStrToThickness(_ typeStr: String) -> String {
    typeStr.contains("==") ? "thick" : "normal"
}

func edgeStrToEdgeData(_ typeStr: String) -> String {
    let lastChar = typeStr.trimmingCharacters(in: .whitespaces).last
    switch lastChar {
    case "x": return "arrow_cross"
    case "o": return "arrow_circle"
    case ">": return "arrow_point"
    default: return ""
    }
}

func edgeStrToEdgeStartData(_ typeStr: String) -> String {
    let firstChar = typeStr.trimmingCharacters(in: .whitespaces).first
    switch firstChar {
    case "x": return "arrow_cross"
    case "o": return "arrow_circle"
    case "<": return "arrow_point"
    default: return "arrow_open"
    }
}

func edgeStrToPattern(_ typeStr: String) -> String {
    typeStr.contains(".-") ? "dotted" : "solid"
}

func expandAndDeduplicateDirections(_ directions: [BlockDirection]) -> Set<BlockDirection> {
    var result = Set<BlockDirection>()
    for dir in directions {
        switch dir {
        case .x:
            result.insert(.right)
            result.insert(.left)
        case .y:
            result.insert(.up)
            result.insert(.down)
        default:
            result.insert(dir)
        }
    }
    return result
}

func getBlockArrowPoints(
    directions duplicatedDirections: [BlockDirection],
    width: Double,
    height: Double,
    padding: Double,
    totalWidth: Double? = nil
) -> [CGPoint] {
    let dirs = expandAndDeduplicateDirections(duplicatedDirections)
    let f = 2.0
    let h = height + 2 * padding
    let midpoint = h / f
    let w = totalWidth ?? (width + 2 * midpoint + padding)
    let p = padding / 2

    let hasRight = dirs.contains(.right)
    let hasLeft = dirs.contains(.left)
    let hasUp = dirs.contains(.up)
    let hasDown = dirs.contains(.down)

    let pt: (Double, Double) -> CGPoint = { x, y in CGPoint(x: x, y: y) }

    if hasRight && hasLeft && hasUp && hasDown {
        return [
            pt(0, 0), pt(midpoint, 0), pt(w / 2, 2 * p), pt(w - midpoint, 0), pt(w, 0),
            pt(w, -h / 3), pt(w + 2 * p, -h / 2), pt(w, (-2 * h) / 3), pt(w, -h),
            pt(w - midpoint, -h), pt(w / 2, -h - 2 * p), pt(midpoint, -h),
            pt(0, -h), pt(0, (-2 * h) / 3), pt(-2 * p, -h / 2), pt(0, -h / 3),
        ]
    }
    if hasRight && hasLeft && hasUp {
        return [
            pt(midpoint, 0), pt(w - midpoint, 0), pt(w, -h / 2),
            pt(w - midpoint, -h), pt(midpoint, -h), pt(0, -h / 2),
        ]
    }
    if hasRight && hasLeft && hasDown {
        return [
            pt(0, 0), pt(midpoint, -h), pt(w - midpoint, -h), pt(w, 0),
        ]
    }
    if hasRight && hasUp && hasDown {
        return [
            pt(0, 0), pt(w, -midpoint), pt(w, -h + midpoint), pt(0, -h),
        ]
    }
    if hasLeft && hasUp && hasDown {
        return [
            pt(w, 0), pt(0, -midpoint), pt(0, -h + midpoint), pt(w, -h),
        ]
    }
    if hasRight && hasLeft {
        return [
            pt(midpoint, 0), pt(midpoint, -p), pt(w - midpoint, -p), pt(w - midpoint, 0),
            pt(w, -h / 2), pt(w - midpoint, -h), pt(w - midpoint, -h + p),
            pt(midpoint, -h + p), pt(midpoint, -h), pt(0, -h / 2),
        ]
    }
    if hasUp && hasDown {
        return [
            pt(w / 2, 0), pt(0, -p), pt(midpoint, -p),
            pt(midpoint, -h + p), pt(0, -h + p), pt(w / 2, -h),
            pt(w, -h + p), pt(w - midpoint, -h + p),
            pt(w - midpoint, -p), pt(w, -p),
        ]
    }
    if hasRight && hasUp {
        return [pt(0, 0), pt(w, -midpoint), pt(0, -h)]
    }
    if hasRight && hasDown {
        return [pt(0, 0), pt(w, 0), pt(0, -h)]
    }
    if hasLeft && hasUp {
        return [pt(w, 0), pt(0, -midpoint), pt(w, -h)]
    }
    if hasLeft && hasDown {
        return [pt(w, 0), pt(0, 0), pt(w, -h)]
    }
    if hasRight {
        return [
            pt(midpoint, -p), pt(midpoint, -p), pt(w - midpoint, -p),
            pt(w - midpoint, 0), pt(w, -h / 2), pt(w - midpoint, -h),
            pt(w - midpoint, -h + p), pt(midpoint, -h + p), pt(midpoint, -h + p),
        ]
    }
    if hasLeft {
        return [
            pt(midpoint, 0), pt(midpoint, -p), pt(w - midpoint, -p),
            pt(w - midpoint, -h + p), pt(midpoint, -h + p),
            pt(midpoint, -h), pt(0, -h / 2),
        ]
    }
    if hasUp {
        return [
            pt(midpoint, -p), pt(midpoint, -h + p), pt(0, -h + p),
            pt(w / 2, -h), pt(w, -h + p), pt(w - midpoint, -h + p),
            pt(w - midpoint, -p),
        ]
    }
    if hasDown {
        return [
            pt(w / 2, 0), pt(0, -p), pt(midpoint, -p),
            pt(midpoint, -h + p), pt(w - midpoint, -h + p),
            pt(w - midpoint, -p), pt(w, -p),
        ]
    }
    return [pt(0, 0)]
}

func sanitizeBlockText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
