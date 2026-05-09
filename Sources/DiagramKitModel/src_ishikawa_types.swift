import Foundation
import DiagramKitCommon

// MARK: - Semantic Model

public struct IshikawaNode: Sendable, Equatable {
    public var text: String
    public var children: [IshikawaNode]

    public init(text: String, children: [IshikawaNode] = []) {
        self.text = text
        self.children = children
    }
}

public struct IshikawaDiagram: Sendable, Equatable {
    public var root: IshikawaNode?
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: IshikawaDiagramConfig
    public var themeName: String?
    public var look: String?

    public init(
        root: IshikawaNode? = nil,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: IshikawaDiagramConfig = .default,
        themeName: String? = nil,
        look: String? = nil
    ) {
        self.root = root
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.themeName = themeName
        self.look = look
    }

    public static let empty = IshikawaDiagram()
}

// MARK: - Config

public struct IshikawaDiagramConfig: Sendable, Equatable {
    public var diagramPadding: Double
    public var useMaxWidth: Bool

    public init(
        diagramPadding: Double = 20,
        useMaxWidth: Bool = false
    ) {
        self.diagramPadding = diagramPadding
        self.useMaxWidth = useMaxWidth
    }

    public static let `default` = IshikawaDiagramConfig()
}

// MARK: - Positioned Types

public enum IshikawaBoneKind: String, Sendable {
    case spine
    case branch
    case subBranch
}

public enum IshikawaBranchDirection: Int, Sendable {
    case upper = -1
    case lower = 1
}

public enum IshikawaTextAnchor: String, Sendable {
    case start
    case middle
    case end
}

public enum IshikawaLabelClass: String, Sendable {
    case head
    case cause
    case align
    case up
    case down
}

public enum IshikawaMarkerBehavior: String, Sendable {
    case none
    case normalArrowAtStart
    case handDrawnArrowAtStart
}

public struct PositionedIshikawaBone: Sendable, Equatable {
    public var id: Int
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    public var kind: IshikawaBoneKind
    public var direction: IshikawaBranchDirection?
    public var depth: Int
    public var parentBoneId: Int?
    public var marker: IshikawaMarkerBehavior

    public init(
        id: Int,
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double,
        kind: IshikawaBoneKind,
        direction: IshikawaBranchDirection? = nil,
        depth: Int,
        parentBoneId: Int? = nil,
        marker: IshikawaMarkerBehavior = .none
    ) {
        self.id = id
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.kind = kind
        self.direction = direction
        self.depth = depth
        self.parentBoneId = parentBoneId
        self.marker = marker
    }
}

public struct PositionedIshikawaLabelBox: Sendable, Equatable {
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

public struct PositionedIshikawaLabel: Sendable, Equatable {
    public var text: String
    public var lines: [String]
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var anchor: IshikawaTextAnchor
    public var labelClass: IshikawaLabelClass
    public var direction: IshikawaBranchDirection?
    public var depth: Int
    public var parentBoneId: Int?
    public var box: PositionedIshikawaLabelBox?

    public init(
        text: String,
        lines: [String] = [],
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        anchor: IshikawaTextAnchor,
        labelClass: IshikawaLabelClass,
        direction: IshikawaBranchDirection? = nil,
        depth: Int = 0,
        parentBoneId: Int? = nil,
        box: PositionedIshikawaLabelBox? = nil
    ) {
        self.text = text
        self.lines = lines
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.anchor = anchor
        self.labelClass = labelClass
        self.direction = direction
        self.depth = depth
        self.parentBoneId = parentBoneId
        self.box = box
    }
}

public struct PositionedIshikawaHead: Sendable, Equatable {
    public var path: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var labelX: Double
    public var labelY: Double
    public var lines: [String]

    public init(
        path: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        labelX: Double,
        labelY: Double,
        lines: [String]
    ) {
        self.path = path
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.labelX = labelX
        self.labelY = labelY
        self.lines = lines
    }
}

public struct PositionedIshikawaDiagram: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var viewBox: CGRect
    public var head: PositionedIshikawaHead?
    public var bones: [PositionedIshikawaBone]
    public var labels: [PositionedIshikawaLabel]
    public var usesMarkerDefinition: Bool
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: IshikawaDiagramConfig

    public init(
        width: Double = 0,
        height: Double = 0,
        viewBox: CGRect = .zero,
        head: PositionedIshikawaHead? = nil,
        bones: [PositionedIshikawaBone] = [],
        labels: [PositionedIshikawaLabel] = [],
        usesMarkerDefinition: Bool = true,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: IshikawaDiagramConfig = .default
    ) {
        self.width = width
        self.height = height
        self.viewBox = viewBox
        self.head = head
        self.bones = bones
        self.labels = labels
        self.usesMarkerDefinition = usesMarkerDefinition
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
    }

    public static let empty = PositionedIshikawaDiagram()
}

// MARK: - Parser Errors

public enum IshikawaParserError: Error, LocalizedError, _MermaidRecoverableError {
    case emptySource
    case missingHeader
    case missingRoot
    case unexpectedToken(String)

    public var errorDescription: String? {
        switch self {
        case .emptySource: return "Ishikawa diagram source is empty."
        case .missingHeader: return "Ishikawa diagram missing 'ishikawa' or 'ishikawa-beta' header."
        case .missingRoot: return "Ishikawa diagram is missing a root/effect line."
        case .unexpectedToken(let token): return "Unexpected token: \(token)"
        }
    }
}
