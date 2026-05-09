import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Parsed model

public struct RadarDiagram: Sendable, Equatable {
    public var axes: [RadarAxis]
    public var curves: [RadarCurve]
    public var options: RadarOptions
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: RadarDiagramConfig
    public var theme: RadarThemeConfig

    public init(
        axes: [RadarAxis] = [],
        curves: [RadarCurve] = [],
        options: RadarOptions = RadarOptions(),
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: RadarDiagramConfig = .default,
        theme: RadarThemeConfig = .default
    ) {
        self.axes = axes
        self.curves = curves
        self.options = options
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }
}

public struct RadarAxis: Sendable, Equatable {
    public var name: String
    public var label: String

    public init(name: String, label: String? = nil) {
        self.name = name
        self.label = label ?? name
    }
}

public struct RadarCurve: Sendable, Equatable {
    public var name: String
    public var label: String
    public var entries: [Double]

    public init(name: String, label: String? = nil, entries: [Double] = []) {
        self.name = name
        self.label = label ?? name
        self.entries = entries
    }
}

public struct RadarOptions: Sendable, Equatable {
    public var showLegend: Bool
    public var ticks: Int
    public var max: Double?
    public var min: Double
    public var graticule: RadarGraticule

    public init(
        showLegend: Bool = true,
        ticks: Int = 5,
        max: Double? = nil,
        min: Double = 0,
        graticule: RadarGraticule = .circle
    ) {
        self.showLegend = showLegend
        self.ticks = ticks
        self.max = max
        self.min = min
        self.graticule = graticule
    }
}

public enum RadarGraticule: String, Sendable, Equatable, CaseIterable {
    case circle
    case polygon
}

// MARK: - Config model

public struct RadarDiagramConfig: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public var marginTop: Double
    public var marginRight: Double
    public var marginBottom: Double
    public var marginLeft: Double
    public var axisScaleFactor: Double
    public var axisLabelFactor: Double
    public var curveTension: Double
    public var useMaxWidth: Bool

    public static let `default` = RadarDiagramConfig()

    public init(
        width: Double = 600,
        height: Double = 600,
        marginTop: Double = 50,
        marginRight: Double = 50,
        marginBottom: Double = 50,
        marginLeft: Double = 50,
        axisScaleFactor: Double = 1,
        axisLabelFactor: Double = 1.05,
        curveTension: Double = 0.17,
        useMaxWidth: Bool = true
    ) {
        self.width = width
        self.height = height
        self.marginTop = marginTop
        self.marginRight = marginRight
        self.marginBottom = marginBottom
        self.marginLeft = marginLeft
        self.axisScaleFactor = axisScaleFactor
        self.axisLabelFactor = axisLabelFactor
        self.curveTension = curveTension
        self.useMaxWidth = useMaxWidth
    }
}

// MARK: - Theme config model

public struct RadarThemeConfig: Sendable, Equatable {
    public var fontSize: Double
    public var titleColor: String
    public var cScale: [String]
    public var themeColorLimit: Int

    public var axisColor: String
    public var axisStrokeWidth: Double
    public var axisLabelFontSize: Double
    public var curveOpacity: Double
    public var curveStrokeWidth: Double
    public var graticuleColor: String
    public var graticuleOpacity: Double
    public var graticuleStrokeWidth: Double
    public var legendBoxSize: Double
    public var legendFontSize: Double

    public static let `default` = RadarThemeConfig()

    public init(
        fontSize: Double = 16,
        titleColor: String = "#27272A",
        cScale: [String] = [
            "#0052CC", "#0065FF", "#2684FF", "#4C9AFF",
            "#84B9FF", "#A5CCFF", "#C6DFFF", "#0052CC",
            "#0065FF", "#2684FF", "#4C9AFF", "#84B9FF"
        ],
        themeColorLimit: Int = 12,
        axisColor: String = "#27272A",
        axisStrokeWidth: Double = 2,
        axisLabelFontSize: Double = 12,
        curveOpacity: Double = 0.5,
        curveStrokeWidth: Double = 2,
        graticuleColor: String = "#DEDEDE",
        graticuleOpacity: Double = 0.3,
        graticuleStrokeWidth: Double = 1,
        legendBoxSize: Double = 12,
        legendFontSize: Double = 12
    ) {
        self.fontSize = fontSize
        self.titleColor = titleColor
        self.cScale = cScale
        self.themeColorLimit = themeColorLimit
        self.axisColor = axisColor
        self.axisStrokeWidth = axisStrokeWidth
        self.axisLabelFontSize = axisLabelFontSize
        self.curveOpacity = curveOpacity
        self.curveStrokeWidth = curveStrokeWidth
        self.graticuleColor = graticuleColor
        self.graticuleOpacity = graticuleOpacity
        self.graticuleStrokeWidth = graticuleStrokeWidth
        self.legendBoxSize = legendBoxSize
        self.legendFontSize = legendFontSize
    }

    public func curveColor(at index: Int) -> String {
        let limit = max(1, min(themeColorLimit, cScale.count))
        return cScale[index % limit]
    }

    public func withGlobalColors(fg: String, line: String?) -> RadarThemeConfig {
        var copy = self
        if copy.titleColor == Self.default.titleColor {
            copy.titleColor = fg
        }
        if let ln = line, copy.axisColor == Self.default.axisColor {
            copy.axisColor = ln
        }
        return copy
    }
}

// MARK: - Positioned model

public struct PositionedRadarDiagram: Sendable {
    public var width: Double
    public var height: Double
    public var centerX: Double
    public var centerY: Double
    public var radius: Double
    public var title: PositionedRadarTitle?
    public var graticules: [PositionedRadarGraticule]
    public var axisLines: [PositionedRadarAxisLine]
    public var axisLabels: [PositionedRadarText]
    public var curves: [PositionedRadarCurve]
    public var legendItems: [PositionedRadarLegendItem]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: RadarDiagramConfig
    public var theme: RadarThemeConfig
    public var showLegend: Bool

    public init(
        width: Double = 0,
        height: Double = 0,
        centerX: Double = 0,
        centerY: Double = 0,
        radius: Double = 0,
        title: PositionedRadarTitle? = nil,
        graticules: [PositionedRadarGraticule] = [],
        axisLines: [PositionedRadarAxisLine] = [],
        axisLabels: [PositionedRadarText] = [],
        curves: [PositionedRadarCurve] = [],
        legendItems: [PositionedRadarLegendItem] = [],
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: RadarDiagramConfig = .default,
        theme: RadarThemeConfig = .default,
        showLegend: Bool = true
    ) {
        self.width = width
        self.height = height
        self.centerX = centerX
        self.centerY = centerY
        self.radius = radius
        self.title = title
        self.graticules = graticules
        self.axisLines = axisLines
        self.axisLabels = axisLabels
        self.curves = curves
        self.legendItems = legendItems
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
        self.showLegend = showLegend
    }

    public static var empty: PositionedRadarDiagram {
        PositionedRadarDiagram()
    }
}

public struct PositionedRadarGraticule: Sendable, Equatable {
    public var type: RadarGraticule
    public var radius: Double?
    public var points: [CGPoint]?
    public var classAttr: String

    public init(type: RadarGraticule, radius: Double? = nil, points: [CGPoint]? = nil, classAttr: String = "radarGraticule") {
        self.type = type
        self.radius = radius
        self.points = points
        self.classAttr = classAttr
    }
}

public struct PositionedRadarAxisLine: Sendable, Equatable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    public var classAttr: String

    public init(x1: Double, y1: Double, x2: Double, y2: Double, classAttr: String = "radarAxisLine") {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.classAttr = classAttr
    }
}

public struct PositionedRadarText: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var classAttr: String
    public var fontSize: Double

    public init(text: String, x: Double, y: Double, classAttr: String, fontSize: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.classAttr = classAttr
        self.fontSize = fontSize
    }
}

public struct PositionedRadarCurve: Sendable, Equatable {
    public var index: Int
    public var label: String
    public var points: [CGPoint]
    public var cubicSegments: [RadarCubicSegment]
    public var polygonPoints: [CGPoint]?
    public var type: RadarGraticule

    public init(index: Int, label: String, points: [CGPoint], cubicSegments: [RadarCubicSegment] = [], polygonPoints: [CGPoint]? = nil, type: RadarGraticule = .circle) {
        self.index = index
        self.label = label
        self.points = points
        self.cubicSegments = cubicSegments
        self.polygonPoints = polygonPoints
        self.type = type
    }
}

public struct RadarCubicSegment: Sendable, Equatable {
    public var cp1: CGPoint
    public var cp2: CGPoint
    public var end: CGPoint

    public init(cp1: CGPoint, cp2: CGPoint, end: CGPoint) {
        self.cp1 = cp1
        self.cp2 = cp2
        self.end = end
    }
}

public struct PositionedRadarLegendItem: Sendable, Equatable {
    public var index: Int
    public var label: String
    public var x: Double
    public var y: Double
    public var boxSize: Double

    public init(index: Int, label: String, x: Double, y: Double, boxSize: Double = 12) {
        self.index = index
        self.label = label
        self.x = x
        self.y = y
        self.boxSize = boxSize
    }
}

public struct PositionedRadarTitle: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var fontSize: Double

    public init(text: String, x: Double, y: Double, fontSize: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.fontSize = fontSize
    }
}

// MARK: - Parser errors

public enum RadarParserError: Error, LocalizedError {
    case invalidHeader(String, line: Int)
    case emptyAxisDeclaration(line: Int)
    case nonCommaSeparatedAxes(String, line: Int)
    case emptyCurveDeclaration(line: Int)
    case curveWithoutEntries(String, line: Int)
    case mixedEntryModes(String, line: Int)
    case nonCommaSeparatedEntries(String, line: Int)
    case detailedEntriesWithoutDeclaredAxes(String, line: Int)
    case missingEntryForDeclaredAxis(String, String, line: Int)
    case invalidOption(String, line: Int)
    case invalidTicksValue(String, line: Int)
    case invalidGraticuleValue(String, line: Int)

    public var line: Int {
        switch self {
        case .invalidHeader(_, let line): return line
        case .emptyAxisDeclaration(let line): return line
        case .nonCommaSeparatedAxes(_, let line): return line
        case .emptyCurveDeclaration(let line): return line
        case .curveWithoutEntries(_, let line): return line
        case .mixedEntryModes(_, let line): return line
        case .nonCommaSeparatedEntries(_, let line): return line
        case .detailedEntriesWithoutDeclaredAxes(_, let line): return line
        case .missingEntryForDeclaredAxis(_, _, let line): return line
        case .invalidOption(_, let line): return line
        case .invalidTicksValue(_, let line): return line
        case .invalidGraticuleValue(_, let line): return line
        }
    }

    private var briefDescription: String {
        switch self {
        case .invalidHeader(let msg, _): return msg
        case .emptyAxisDeclaration: return "Empty axis declaration."
        case .nonCommaSeparatedAxes(let msg, _): return msg
        case .emptyCurveDeclaration: return "Empty curve declaration."
        case .curveWithoutEntries(let msg, _): return msg
        case .mixedEntryModes(let msg, _): return msg
        case .nonCommaSeparatedEntries(let msg, _): return msg
        case .detailedEntriesWithoutDeclaredAxes(let name, _): return "Axes must be populated before curves for reference entries (curve: \(name))."
        case .missingEntryForDeclaredAxis(let curve, let axis, _): return "Missing entry for axis \(axis) in curve \(curve)."
        case .invalidOption(let msg, _): return msg
        case .invalidTicksValue(let msg, _): return msg
        case .invalidGraticuleValue(let msg, _): return msg
        }
    }

    public var errorDescription: String? {
        "Parse error on line \(line), column ?: \(briefDescription)"
    }
}
