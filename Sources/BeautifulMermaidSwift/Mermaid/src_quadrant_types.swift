import Foundation

// MARK: - Parsed model

public struct QuadrantPoint: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var className: String?
    public var radius: Int?
    public var color: String?
    public var strokeColor: String?
    public var strokeWidth: String?

    public init(
        text: String,
        x: Double,
        y: Double,
        className: String? = nil,
        radius: Int? = nil,
        color: String? = nil,
        strokeColor: String? = nil,
        strokeWidth: String? = nil
    ) {
        self.text = text
        self.x = x
        self.y = y
        self.className = className
        self.radius = radius
        self.color = color
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }
}

public struct QuadrantChart: Sendable, Equatable {
    public var titleText: String?
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var xAxisLeftText: String?
    public var xAxisRightText: String?
    public var yAxisBottomText: String?
    public var yAxisTopText: String?
    public var quadrant1Text: String?
    public var quadrant2Text: String?
    public var quadrant3Text: String?
    public var quadrant4Text: String?
    public var points: [QuadrantPoint]
    public var classes: [String: QuadrantPointStyles]
    public var config: QuadrantChartConfig
    public var theme: QuadrantChartThemeConfig

    public init(
        titleText: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        xAxisLeftText: String? = nil,
        xAxisRightText: String? = nil,
        yAxisBottomText: String? = nil,
        yAxisTopText: String? = nil,
        quadrant1Text: String? = nil,
        quadrant2Text: String? = nil,
        quadrant3Text: String? = nil,
        quadrant4Text: String? = nil,
        points: [QuadrantPoint] = [],
        classes: [String: QuadrantPointStyles] = [:],
        config: QuadrantChartConfig = QuadrantChartConfig(),
        theme: QuadrantChartThemeConfig = QuadrantChartThemeConfig()
    ) {
        self.titleText = titleText
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.xAxisLeftText = xAxisLeftText
        self.xAxisRightText = xAxisRightText
        self.yAxisBottomText = yAxisBottomText
        self.yAxisTopText = yAxisTopText
        self.quadrant1Text = quadrant1Text
        self.quadrant2Text = quadrant2Text
        self.quadrant3Text = quadrant3Text
        self.quadrant4Text = quadrant4Text
        self.points = points
        self.classes = classes
        self.config = config
        self.theme = theme
    }
}

// MARK: - Style model

public struct QuadrantPointStyles: Sendable, Equatable {
    public var radius: Int?
    public var color: String?
    public var strokeColor: String?
    public var strokeWidth: String?

    public init(
        radius: Int? = nil,
        color: String? = nil,
        strokeColor: String? = nil,
        strokeWidth: String? = nil
    ) {
        self.radius = radius
        self.color = color
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
    }
}

// MARK: - Config model

public struct QuadrantChartConfig: Sendable, Equatable {
    public var chartWidth: Double
    public var chartHeight: Double
    public var titlePadding: Double
    public var titleFontSize: Double
    public var quadrantPadding: Double
    public var quadrantTextTopPadding: Double
    public var quadrantLabelFontSize: Double
    public var quadrantInternalBorderStrokeWidth: Double
    public var quadrantExternalBorderStrokeWidth: Double
    public var xAxisLabelPadding: Double
    public var xAxisLabelFontSize: Double
    public var xAxisPosition: String
    public var yAxisLabelPadding: Double
    public var yAxisLabelFontSize: Double
    public var yAxisPosition: String
    public var pointTextPadding: Double
    public var pointLabelFontSize: Double
    public var pointRadius: Double
    public var useMaxWidth: Bool

    public var showXAxis: Bool
    public var showYAxis: Bool
    public var showTitle: Bool

    public init(
        chartWidth: Double = 500,
        chartHeight: Double = 500,
        titlePadding: Double = 10,
        titleFontSize: Double = 20,
        quadrantPadding: Double = 5,
        quadrantTextTopPadding: Double = 5,
        quadrantLabelFontSize: Double = 16,
        quadrantInternalBorderStrokeWidth: Double = 1,
        quadrantExternalBorderStrokeWidth: Double = 2,
        xAxisLabelPadding: Double = 5,
        xAxisLabelFontSize: Double = 16,
        xAxisPosition: String = "top",
        yAxisLabelPadding: Double = 5,
        yAxisLabelFontSize: Double = 16,
        yAxisPosition: String = "left",
        pointTextPadding: Double = 5,
        pointLabelFontSize: Double = 12,
        pointRadius: Double = 5,
        useMaxWidth: Bool = true,
        showXAxis: Bool = true,
        showYAxis: Bool = true,
        showTitle: Bool = true
    ) {
        self.chartWidth = chartWidth
        self.chartHeight = chartHeight
        self.titlePadding = titlePadding
        self.titleFontSize = titleFontSize
        self.quadrantPadding = quadrantPadding
        self.quadrantTextTopPadding = quadrantTextTopPadding
        self.quadrantLabelFontSize = quadrantLabelFontSize
        self.quadrantInternalBorderStrokeWidth = quadrantInternalBorderStrokeWidth
        self.quadrantExternalBorderStrokeWidth = quadrantExternalBorderStrokeWidth
        self.xAxisLabelPadding = xAxisLabelPadding
        self.xAxisLabelFontSize = xAxisLabelFontSize
        self.xAxisPosition = xAxisPosition
        self.yAxisLabelPadding = yAxisLabelPadding
        self.yAxisLabelFontSize = yAxisLabelFontSize
        self.yAxisPosition = yAxisPosition
        self.pointTextPadding = pointTextPadding
        self.pointLabelFontSize = pointLabelFontSize
        self.pointRadius = pointRadius
        self.useMaxWidth = useMaxWidth
        self.showXAxis = showXAxis
        self.showYAxis = showYAxis
        self.showTitle = showTitle
    }
}

// MARK: - Theme config model

public struct QuadrantChartThemeConfig: Sendable, Equatable {
    public var quadrant1Fill: String
    public var quadrant2Fill: String
    public var quadrant3Fill: String
    public var quadrant4Fill: String
    public var quadrant1TextFill: String
    public var quadrant2TextFill: String
    public var quadrant3TextFill: String
    public var quadrant4TextFill: String
    public var quadrantPointFill: String
    public var quadrantPointTextFill: String
    public var quadrantXAxisTextFill: String
    public var quadrantYAxisTextFill: String
    public var quadrantInternalBorderStrokeFill: String
    public var quadrantExternalBorderStrokeFill: String
    public var quadrantTitleFill: String

    public init(
        quadrant1Fill: String = "#ECECFF",
        quadrant2Fill: String = "#D6D6FF",
        quadrant3Fill: String = "#C0C0FF",
        quadrant4Fill: String = "#AAAAFF",
        quadrant1TextFill: String = "#27272A",
        quadrant2TextFill: String = "#343436",
        quadrant3TextFill: String = "#3F3F42",
        quadrant4TextFill: String = "#4A4A4E",
        quadrantPointFill: String = "#C0C0FF",
        quadrantPointTextFill: String = "#27272A",
        quadrantXAxisTextFill: String = "#27272A",
        quadrantYAxisTextFill: String = "#27272A",
        quadrantInternalBorderStrokeFill: String = "#A1A1AA",
        quadrantExternalBorderStrokeFill: String = "#A1A1AA",
        quadrantTitleFill: String = "#27272A"
    ) {
        self.quadrant1Fill = quadrant1Fill
        self.quadrant2Fill = quadrant2Fill
        self.quadrant3Fill = quadrant3Fill
        self.quadrant4Fill = quadrant4Fill
        self.quadrant1TextFill = quadrant1TextFill
        self.quadrant2TextFill = quadrant2TextFill
        self.quadrant3TextFill = quadrant3TextFill
        self.quadrant4TextFill = quadrant4TextFill
        self.quadrantPointFill = quadrantPointFill
        self.quadrantPointTextFill = quadrantPointTextFill
        self.quadrantXAxisTextFill = quadrantXAxisTextFill
        self.quadrantYAxisTextFill = quadrantYAxisTextFill
        self.quadrantInternalBorderStrokeFill = quadrantInternalBorderStrokeFill
        self.quadrantExternalBorderStrokeFill = quadrantExternalBorderStrokeFill
        self.quadrantTitleFill = quadrantTitleFill
    }
}

// MARK: - Positioned model

public struct PositionedQuadrantChart: Sendable {
    public var width: Double
    public var height: Double
    public var quadrants: [PositionedQuadrant]
    public var axisLabels: [PositionedQuadrantText]
    public var points: [PositionedQuadrantPoint]
    public var borderLines: [PositionedQuadrantLine]
    public var title: PositionedQuadrantTitle?
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: QuadrantChartConfig
    public var theme: QuadrantChartThemeConfig

    public init(
        width: Double = 500,
        height: Double = 500,
        quadrants: [PositionedQuadrant] = [],
        axisLabels: [PositionedQuadrantText] = [],
        points: [PositionedQuadrantPoint] = [],
        borderLines: [PositionedQuadrantLine] = [],
        title: PositionedQuadrantTitle? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: QuadrantChartConfig = QuadrantChartConfig(),
        theme: QuadrantChartThemeConfig = QuadrantChartThemeConfig()
    ) {
        self.width = width
        self.height = height
        self.quadrants = quadrants
        self.axisLabels = axisLabels
        self.points = points
        self.borderLines = borderLines
        self.title = title
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
    }

    public static var empty: PositionedQuadrantChart {
        PositionedQuadrantChart()
    }
}

public struct PositionedQuadrant: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var fill: String
    public var text: PositionedQuadrantText

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        fill: String,
        text: PositionedQuadrantText
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.fill = fill
        self.text = text
    }
}

public struct PositionedQuadrantText: Sendable, Equatable {
    public var text: String
    public var fill: String
    public var x: Double
    public var y: Double
    public var fontSize: Double
    public var horizontalPos: String
    public var verticalPos: String
    public var rotation: Double

    public init(
        text: String,
        fill: String,
        x: Double,
        y: Double,
        fontSize: Double,
        horizontalPos: String = "middle",
        verticalPos: String = "center",
        rotation: Double = 0
    ) {
        self.text = text
        self.fill = fill
        self.x = x
        self.y = y
        self.fontSize = fontSize
        self.horizontalPos = horizontalPos
        self.verticalPos = verticalPos
        self.rotation = rotation
    }
}

public struct PositionedQuadrantPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var fill: String
    public var radius: Double
    public var strokeColor: String
    public var strokeWidth: String
    public var text: PositionedQuadrantText

    public init(
        x: Double,
        y: Double,
        fill: String,
        radius: Double,
        strokeColor: String,
        strokeWidth: String,
        text: PositionedQuadrantText
    ) {
        self.x = x
        self.y = y
        self.fill = fill
        self.radius = radius
        self.strokeColor = strokeColor
        self.strokeWidth = strokeWidth
        self.text = text
    }
}

public struct PositionedQuadrantLine: Sendable, Equatable {
    public var x1: Double
    public var y1: Double
    public var x2: Double
    public var y2: Double
    public var strokeFill: String
    public var strokeWidth: Double

    public init(
        x1: Double,
        y1: Double,
        x2: Double,
        y2: Double,
        strokeFill: String,
        strokeWidth: Double
    ) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.strokeFill = strokeFill
        self.strokeWidth = strokeWidth
    }
}

public struct PositionedQuadrantTitle: Sendable, Equatable {
    public var text: String
    public var fill: String
    public var fontSize: Double
    public var x: Double
    public var y: Double
    public var horizontalPos: String
    public var verticalPos: String
    public var rotation: Double

    public init(
        text: String,
        fill: String,
        fontSize: Double,
        x: Double,
        y: Double,
        horizontalPos: String = "top",
        verticalPos: String = "center",
        rotation: Double = 0
    ) {
        self.text = text
        self.fill = fill
        self.fontSize = fontSize
        self.x = x
        self.y = y
        self.horizontalPos = horizontalPos
        self.verticalPos = verticalPos
        self.rotation = rotation
    }
}
