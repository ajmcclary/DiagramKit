// Ported from original/src/xychart/types.ts
import Foundation

// MARK: - XYText model (Mermaid parity)

public enum XYTextType: String, Sendable {
    case text
    case markdown
}

public struct XYText: Sendable, Equatable {
    public var text: String
    public var kind: XYTextType

    public init(text: String, kind: XYTextType = .text) {
        self.text = text
        self.kind = kind
    }
}

// MARK: - Axis kind

public enum XYAxisKind: String, Sendable {
    case band
    case linear
}

// MARK: - Parsed types

public enum XYSeriesType: String, Sendable {
    case bar
    case line
}

public struct XYAxis: Sendable {
    public var title: String?
    public var titleText: XYText?
    public var categories: [String]?
    public var categoryTexts: [XYText]?
    public var range: (min: Double, max: Double)?
    public var kind: XYAxisKind = .band
    public var hasSetAxis: Bool = false

    public init(title: String? = nil, titleText: XYText? = nil, categories: [String]? = nil, categoryTexts: [XYText]? = nil, range: (min: Double, max: Double)? = nil, kind: XYAxisKind = .band, hasSetAxis: Bool = false) {
        self.title = title ?? titleText?.text
        self.titleText = titleText ?? title.map { XYText(text: $0) }
        self.categories = categories ?? categoryTexts?.map(\.text)
        self.categoryTexts = categoryTexts ?? categories?.map { XYText(text: $0) }
        self.range = range
        self.kind = kind
        self.hasSetAxis = hasSetAxis
    }
}

public struct XYChartSeries: Sendable {
    public var type: XYSeriesType
    public var title: XYText
    public var data: [Double]

    public init(type: XYSeriesType, title: XYText = XYText(text: ""), data: [Double]) {
        self.type = type
        self.title = title
        self.data = data
    }
}

public struct XYChart: Sendable {
    public var title: String?
    public var titleText: XYText?
    public var horizontal: Bool
    public var explicitHorizontal: Bool = false
    public var explicitVertical: Bool = false
    public var xAxis: XYAxis
    public var yAxis: XYAxis
    public var series: [XYChartSeries]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: XYChartConfig?
    public var theme: XYChartThemeConfig?

    public init(title: String? = nil, titleText: XYText? = nil, horizontal: Bool = false, explicitHorizontal: Bool = false, explicitVertical: Bool = false, xAxis: XYAxis = XYAxis(), yAxis: XYAxis = XYAxis(), series: [XYChartSeries] = [], accTitle: String? = nil, accDescr: String? = nil, diagramTitle: String? = nil, config: XYChartConfig? = nil, theme: XYChartThemeConfig? = nil) {
        self.title = title ?? titleText?.text
        self.titleText = titleText ?? title.map { XYText(text: $0) }
        self.horizontal = horizontal
        self.explicitHorizontal = explicitHorizontal
        self.explicitVertical = explicitVertical
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.series = series
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
    }
}

// MARK: - Mermaid parser error type

public enum XYChartParserError: Error, LocalizedError {
    case invalidHeader(String)
    case invalidOrientation(String)
    case unbalancedBrackets(String)
    case malformedComma(String)
    case nonNumericData(String, String)
    case categoricalYAxis(String)
    case missingData(String)
    case emptyData(String)
    case noPlotData

    public var errorDescription: String? {
        switch self {
        case .invalidHeader(let msg): return "Invalid XYChart header: \(msg)"
        case .invalidOrientation(let msg): return "Invalid orientation: \(msg)"
        case .unbalancedBrackets(let msg): return "Unbalanced brackets: \(msg)"
        case .malformedComma(let msg): return "Malformed comma: \(msg)"
        case .nonNumericData(let value, let context): return "Non-numeric data '\(value)' in \(context)"
        case .categoricalYAxis(let msg): return "Y-axis does not support categorical data: \(msg)"
        case .missingData(let msg): return "Missing data for series: \(msg)"
        case .emptyData(let msg): return "Empty data for series: \(msg)"
        case .noPlotData: return "No Plot to render, please provide a plot with some data"
        }
    }
}

// MARK: - XY Chart Config

public struct XYChartAxisConfig: Sendable {
    public var showLabel: Bool = true
    public var labelFontSize: Double = 14
    public var labelPadding: Double = 5
    public var showTitle: Bool = true
    public var titleFontSize: Double = 16
    public var titlePadding: Double = 5
    public var showTick: Bool = true
    public var tickLength: Double = 5
    public var tickWidth: Double = 2
    public var showAxisLine: Bool = true
    public var axisLineWidth: Double = 2

    public init(
        showLabel: Bool = true, labelFontSize: Double = 14, labelPadding: Double = 5,
        showTitle: Bool = true, titleFontSize: Double = 16, titlePadding: Double = 5,
        showTick: Bool = true, tickLength: Double = 5, tickWidth: Double = 2,
        showAxisLine: Bool = true, axisLineWidth: Double = 2
    ) {
        self.showLabel = showLabel
        self.labelFontSize = labelFontSize
        self.labelPadding = labelPadding
        self.showTitle = showTitle
        self.titleFontSize = titleFontSize
        self.titlePadding = titlePadding
        self.showTick = showTick
        self.tickLength = tickLength
        self.tickWidth = tickWidth
        self.showAxisLine = showAxisLine
        self.axisLineWidth = axisLineWidth
    }
}

public struct XYChartConfig: Sendable {
    public var width: Double = 700
    public var height: Double = 500
    public var titleFontSize: Double = 20
    public var titlePadding: Double = 10
    public var showTitle: Bool = true
    public var showDataLabel: Bool = false
    public var showDataLabelOutsideBar: Bool = false
    public var chartOrientation: String = "vertical"
    public var plotReservedSpacePercent: Double = 50
    public var xAxis: XYChartAxisConfig = XYChartAxisConfig()
    public var yAxis: XYChartAxisConfig = XYChartAxisConfig()

    public init(
        width: Double = 700, height: Double = 500,
        titleFontSize: Double = 20, titlePadding: Double = 10,
        showTitle: Bool = true,
        showDataLabel: Bool = false, showDataLabelOutsideBar: Bool = false,
        chartOrientation: String = "vertical",
        plotReservedSpacePercent: Double = 50,
        xAxis: XYChartAxisConfig = XYChartAxisConfig(),
        yAxis: XYChartAxisConfig = XYChartAxisConfig()
    ) {
        self.width = width
        self.height = height
        self.titleFontSize = titleFontSize
        self.titlePadding = titlePadding
        self.showTitle = showTitle
        self.showDataLabel = showDataLabel
        self.showDataLabelOutsideBar = showDataLabelOutsideBar
        self.chartOrientation = chartOrientation
        self.plotReservedSpacePercent = plotReservedSpacePercent
        self.xAxis = xAxis
        self.yAxis = yAxis
    }
}

// MARK: - XY Chart Theme Config

public struct XYChartThemeConfig: Sendable {
    public var backgroundColor: String?
    public var titleColor: String?
    public var dataLabelColor: String?
    public var xAxisLabelColor: String?
    public var xAxisTitleColor: String?
    public var xAxisTickColor: String?
    public var xAxisLineColor: String?
    public var yAxisLabelColor: String?
    public var yAxisTitleColor: String?
    public var yAxisTickColor: String?
    public var yAxisLineColor: String?
    public var plotColorPalette: String?

    public init(
        backgroundColor: String? = nil, titleColor: String? = nil,
        dataLabelColor: String? = nil,
        xAxisLabelColor: String? = nil, xAxisTitleColor: String? = nil,
        xAxisTickColor: String? = nil, xAxisLineColor: String? = nil,
        yAxisLabelColor: String? = nil, yAxisTitleColor: String? = nil,
        yAxisTickColor: String? = nil, yAxisLineColor: String? = nil,
        plotColorPalette: String? = nil
    ) {
        self.backgroundColor = backgroundColor
        self.titleColor = titleColor
        self.dataLabelColor = dataLabelColor
        self.xAxisLabelColor = xAxisLabelColor
        self.xAxisTitleColor = xAxisTitleColor
        self.xAxisTickColor = xAxisTickColor
        self.xAxisLineColor = xAxisLineColor
        self.yAxisLabelColor = yAxisLabelColor
        self.yAxisTitleColor = yAxisTitleColor
        self.yAxisTickColor = yAxisTickColor
        self.yAxisLineColor = yAxisLineColor
        self.plotColorPalette = plotColorPalette
    }
}

// MARK: - Positioned types (ready for SVG rendering)

public struct PositionedXYChart: Sendable {
    public var width: Double
    public var height: Double
    public var horizontal: Bool
    public var title: PositionedTitle?
    public var xAxis: PositionedXYAxis
    public var yAxis: PositionedXYAxis
    public var plotArea: XYPlotArea
    public var bars: [PositionedBar]
    public var lines: [PositionedLine]
    public var gridLines: [XYGridLine]
    public var legend: [XYLegendItem]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: XYChartConfig
    public var theme: XYChartThemeConfig
    public var nativeEnhancements: Bool = false

    public init(
        width: Double, height: Double, horizontal: Bool = false,
        title: PositionedTitle? = nil,
        xAxis: PositionedXYAxis, yAxis: PositionedXYAxis,
        plotArea: XYPlotArea,
        bars: [PositionedBar], lines: [PositionedLine],
        gridLines: [XYGridLine], legend: [XYLegendItem],
        accTitle: String? = nil, accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: XYChartConfig = XYChartConfig(),
        theme: XYChartThemeConfig = XYChartThemeConfig(),
        nativeEnhancements: Bool = false
    ) {
        self.width = width
        self.height = height
        self.horizontal = horizontal
        self.title = title
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.plotArea = plotArea
        self.bars = bars
        self.lines = lines
        self.gridLines = gridLines
        self.legend = legend
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
        self.nativeEnhancements = nativeEnhancements
    }

    public static let empty = PositionedXYChart(
        width: 0, height: 0,
        xAxis: PositionedXYAxis(ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)),
        yAxis: PositionedXYAxis(ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)),
        plotArea: XYPlotArea(x: 0, y: 0, width: 0, height: 0),
        bars: [], lines: [], gridLines: [], legend: []
    )
}

public struct PositionedTitle: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var textKind: XYTextType?
}

public struct PositionedXYAxis: Sendable {
    public var title: AxisTitle?
    public var ticks: [XYAxisTick]
    public var tickLines: [PositionedTick] = []
    public var line: AxisLine

    public init(title: AxisTitle? = nil, ticks: [XYAxisTick], tickLines: [PositionedTick] = [], line: AxisLine) {
        self.title = title
        self.ticks = ticks
        self.tickLines = tickLines
        self.line = line
    }
}

public struct AxisTitle: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var rotate: Double?
    public var textKind: XYTextType?
}

public struct AxisLine: Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
}

public struct PositionedTick: Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
}

public struct XYAxisTick: Sendable {
    public var label: String
    public var x: Double
    public var y: Double
    public var tx: Double
    public var ty: Double
    public var labelX: Double
    public var labelY: Double
    public var textAnchor: String // "start", "middle", "end"
}

public struct XYPlotArea: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
}

public struct PositionedDataLabel: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var textAnchor: String
    public var fontSize: Double
    public var textKind: XYTextType?
}

public struct PositionedBar: Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var value: Double
    public var label: String?
    public var seriesIndex: Int
    public var colorIndex: Int
    public var dataLabel: PositionedDataLabel?
}

public struct PositionedLine: Sendable {
    public var points: [LinePoint]
    public var seriesIndex: Int
    public var colorIndex: Int
}

public struct LinePoint: Sendable {
    public var x: Double
    public var y: Double
    public var value: Double
    public var label: String?
}

public struct XYGridLine: Sendable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
}

public struct XYLegendItem: Sendable {
    public var label: String
    public var x: Double
    public var y: Double
    public var type: XYSeriesType
    public var seriesIndex: Int
    public var colorIndex: Int
}
