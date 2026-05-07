import Foundation

// MARK: - Core Model Types

public struct VennDiagram: Sendable, Equatable {
    public var areas: [VennArea]
    public var textNodes: [VennTextNode]
    public var styleEntries: [VennStyleEntry]
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: VennDiagramConfig
    public var themeName: String?
    public var themeVariables: [String: String]?

    public init(
        areas: [VennArea] = [],
        textNodes: [VennTextNode] = [],
        styleEntries: [VennStyleEntry] = [],
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: VennDiagramConfig = .default,
        themeName: String? = nil,
        themeVariables: [String: String]? = nil
    ) {
        self.areas = areas
        self.textNodes = textNodes
        self.styleEntries = styleEntries
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.themeName = themeName
        self.themeVariables = themeVariables
    }
}

public struct VennArea: Sendable, Equatable {
    public var sets: [String]
    public var size: Double
    public var label: String?

    public init(sets: [String], size: Double, label: String? = nil) {
        self.sets = sets.sorted()
        self.size = size
        self.label = label
    }

    public var setsKey: String {
        sets.joined(separator: "|")
    }

    public var isSingleSet: Bool {
        sets.count == 1
    }

    public static func defaultSize(forSetCount count: Int) -> Double {
        switch count {
        case 1: return 10
        case 2: return 2.5
        default: return 10.0 / Double(count * count)
        }
    }
}

public struct VennTextNode: Sendable, Equatable {
    public var sets: [String]
    public var id: String
    public var label: String?

    public init(sets: [String], id: String, label: String? = nil) {
        self.sets = sets.sorted()
        self.id = id
        self.label = label
    }
}

public struct VennStyleEntry: Sendable, Equatable {
    public var targets: [String]
    public var styles: [String: String]

    public init(targets: [String], styles: [String: String] = [:]) {
        self.targets = targets.sorted()
        self.styles = styles
    }

    public var targetsKey: String {
        targets.sorted().joined(separator: "|")
    }
}

// MARK: - Config

public struct VennDiagramConfig: Sendable, Equatable {
    public var useMaxWidth: Bool
    public var width: Double
    public var height: Double
    public var padding: Double
    public var useDebugLayout: Bool

    public static let `default` = VennDiagramConfig()

    public init(
        useMaxWidth: Bool = true,
        width: Double = 800,
        height: Double = 450,
        padding: Double = 8,
        useDebugLayout: Bool = false
    ) {
        self.useMaxWidth = useMaxWidth
        self.width = width
        self.height = height
        self.padding = padding
        self.useDebugLayout = useDebugLayout
    }
}

// MARK: - Positioned Model

public struct VennPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct VennCircle: Sendable, Equatable {
    public var center: VennPoint
    public var radius: Double

    public init(center: VennPoint, radius: Double) {
        self.center = center
        self.radius = radius
    }
}

public struct PositionedVennDiagram: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var titleHeight: Double
    public var title: PositionedVennTitle?
    public var areas: [PositionedVennArea]
    public var textNodes: [PositionedVennTextNode]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: VennDiagramConfig
    public var themeName: String?
    public var themeVariables: [String: String]?
    public var useDebugLayout: Bool

    public static var empty: PositionedVennDiagram {
        PositionedVennDiagram(
            width: 800, height: 450, titleHeight: 0, title: nil,
            areas: [], textNodes: [], accTitle: nil, accDescr: nil,
            diagramTitle: nil, config: .default
        )
    }

    public init(
        width: Double, height: Double, titleHeight: Double,
        title: PositionedVennTitle?, areas: [PositionedVennArea],
        textNodes: [PositionedVennTextNode],
        accTitle: String?, accDescr: String?, diagramTitle: String?,
        config: VennDiagramConfig,
        themeName: String? = nil,
        themeVariables: [String: String]? = nil,
        useDebugLayout: Bool = false
    ) {
        self.width = width
        self.height = height
        self.titleHeight = titleHeight
        self.title = title
        self.areas = areas
        self.textNodes = textNodes
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.themeName = themeName
        self.themeVariables = themeVariables
        self.useDebugLayout = useDebugLayout
    }

    public var scale: Double {
        width / 1600.0
    }
}

public struct PositionedVennTitle: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var fontSize: Double
    public var fillColor: String

    public init(text: String, x: Double, y: Double, fontSize: Double, fillColor: String) {
        self.text = text
        self.x = x
        self.y = y
        self.fontSize = fontSize
        self.fillColor = fillColor
    }
}

public struct PositionedVennArea: Sendable, Equatable {
    public var setsKey: String
    public var sets: [String]
    public var label: String?
    public var size: Double
    public var circles: [VennCircle]
    public var pathSpec: String?
    public var textPoint: VennPoint
    public var fillColor: String
    public var fillOpacity: Double
    public var strokeColor: String
    public var strokeWidth: Double
    public var textColor: String
    public var textFontSize: Double
    public var colorClass: String
    public var debugFlags: Bool

    public var isSingleSet: Bool { sets.count == 1 }

    public init(
        setsKey: String, sets: [String], label: String?, size: Double,
        circles: [VennCircle], pathSpec: String?, textPoint: VennPoint,
        fillColor: String, fillOpacity: Double, strokeColor: String,
        strokeWidth: Double, textColor: String, textFontSize: Double,
        colorClass: String, debugFlags: Bool = false
    ) {
        self.setsKey = setsKey
        self.sets = sets
        self.label = label
        self.size = size
        self.circles = circles
        self.pathSpec = pathSpec
        self.textPoint = textPoint
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.textColor = textColor
        self.textFontSize = textFontSize
        self.colorClass = colorClass
        self.debugFlags = debugFlags
    }
}

public struct PositionedVennTextNode: Sendable, Equatable {
    public var areaKey: String
    public var id: String
    public var label: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var textColor: String
    public var debugCell: Bool

    public init(
        areaKey: String, id: String, label: String?,
        x: Double, y: Double, width: Double, height: Double,
        textColor: String, debugCell: Bool = false
    ) {
        self.areaKey = areaKey
        self.id = id
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.textColor = textColor
        self.debugCell = debugCell
    }
}

// MARK: - Parser Errors

public enum VennParserError: Error, LocalizedError {
    case invalidHeader
    case invalidSetStatement(String)
    case invalidUnionStatement(String)
    case unionRequiresMultipleIdentifiers
    case unknownSetIdentifier([String])
    case textRequiresSet
    case invalidTextStatement(String)
    case invalidStyleStatement(String)
    case emptySource

    public var errorDescription: String? {
        switch self {
        case .invalidHeader: return "Venn diagram must start with 'venn-beta'"
        case .invalidSetStatement(let s): return "Invalid set statement: \(s)"
        case .invalidUnionStatement(let s): return "Invalid union statement: \(s)"
        case .unionRequiresMultipleIdentifiers: return "Union requires at least two identifiers"
        case .unknownSetIdentifier(let ids): return "Unknown set identifier(s): \(ids.joined(separator: ", "))"
        case .textRequiresSet: return "Text requires a prior set or union"
        case .invalidTextStatement(let s): return "Invalid text statement: \(s)"
        case .invalidStyleStatement(let s): return "Invalid style statement: \(s)"
        case .emptySource: return "Venn diagram source is empty"
        }
    }
}

// MARK: - Default theme colors

public enum VennThemeDefaults {
    public static let defaultColors: [String] = [
        "#ff6b6b", "#4ecdc4", "#45b7d1", "#96ceb4",
        "#ffeaa7", "#dfe6e9", "#a29bfe", "#fd79a8"
    ]

    public static let defaultTitleTextColor = "#333333"
    public static let defaultSetTextColor = "#333333"
}
