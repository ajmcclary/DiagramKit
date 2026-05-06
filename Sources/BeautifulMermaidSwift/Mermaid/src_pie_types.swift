import Foundation

// MARK: - Parsed model

public struct PieSection: Sendable, Equatable {
    public var label: String
    public var value: Double

    public init(label: String, value: Double) {
        self.label = label
        self.value = value
    }
}

public struct PieChart: Sendable, Equatable {
    public var sections: [PieSection]
    public var showData: Bool
    public var diagramTitle: String?
    public var accTitle: String?
    public var accDescr: String?
    public var config: PieChartConfig
    public var theme: PieChartThemeConfig

    public init(
        sections: [PieSection] = [],
        showData: Bool = false,
        diagramTitle: String? = nil,
        accTitle: String? = nil,
        accDescr: String? = nil,
        config: PieChartConfig = PieChartConfig(),
        theme: PieChartThemeConfig = PieChartThemeConfig()
    ) {
        self.sections = sections
        self.showData = showData
        self.diagramTitle = diagramTitle
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.config = config
        self.theme = theme
    }
}

// MARK: - Config

public struct PieChartConfig: Sendable, Equatable {
    public var textPosition: Double
    public var useWidth: Double
    public var useMaxWidth: Bool

    public init(
        textPosition: Double = 0.75,
        useWidth: Double = 984,
        useMaxWidth: Bool = true
    ) {
        self.textPosition = textPosition
        self.useWidth = useWidth
        self.useMaxWidth = useMaxWidth
    }
}

public struct PieChartThemeConfig: Sendable, Equatable {
    private static let fallbackPieColors = [
        "#ECECFF", "#C4E3FF", "#FFF2CC", "#D6E6FF",
        "#B8D6FF", "#E6D6FF", "#FFD6E8", "#D6E8FF",
        "#E8FFD6", "#FFD6B8", "#FFD6D6", "#D6FFE8",
    ]

    public var pie1: String
    public var pie2: String
    public var pie3: String
    public var pie4: String
    public var pie5: String
    public var pie6: String
    public var pie7: String
    public var pie8: String
    public var pie9: String
    public var pie10: String
    public var pie11: String
    public var pie12: String
    public var pieTitleTextSize: String
    public var pieTitleTextColor: String
    public var pieSectionTextSize: String
    public var pieSectionTextColor: String
    public var pieLegendTextSize: String
    public var pieLegendTextColor: String
    public var pieStrokeColor: String
    public var pieStrokeWidth: String
    public var pieOuterStrokeWidth: String
    public var pieOuterStrokeColor: String
    public var pieOpacity: String
    public var fontFamily: String

    public init(
        pie1: String = "",
        pie2: String = "",
        pie3: String = "",
        pie4: String = "",
        pie5: String = "",
        pie6: String = "",
        pie7: String = "",
        pie8: String = "",
        pie9: String = "",
        pie10: String = "",
        pie11: String = "",
        pie12: String = "",
        pieTitleTextSize: String = "25px",
        pieTitleTextColor: String = "",
        pieSectionTextSize: String = "17px",
        pieSectionTextColor: String = "",
        pieLegendTextSize: String = "17px",
        pieLegendTextColor: String = "",
        pieStrokeColor: String = "black",
        pieStrokeWidth: String = "2px",
        pieOuterStrokeWidth: String = "2px",
        pieOuterStrokeColor: String = "black",
        pieOpacity: String = "0.7",
        fontFamily: String = ""
    ) {
        self.pie1 = pie1
        self.pie2 = pie2
        self.pie3 = pie3
        self.pie4 = pie4
        self.pie5 = pie5
        self.pie6 = pie6
        self.pie7 = pie7
        self.pie8 = pie8
        self.pie9 = pie9
        self.pie10 = pie10
        self.pie11 = pie11
        self.pie12 = pie12
        self.pieTitleTextSize = pieTitleTextSize
        self.pieTitleTextColor = pieTitleTextColor
        self.pieSectionTextSize = pieSectionTextSize
        self.pieSectionTextColor = pieSectionTextColor
        self.pieLegendTextSize = pieLegendTextSize
        self.pieLegendTextColor = pieLegendTextColor
        self.pieStrokeColor = pieStrokeColor
        self.pieStrokeWidth = pieStrokeWidth
        self.pieOuterStrokeWidth = pieOuterStrokeWidth
        self.pieOuterStrokeColor = pieOuterStrokeColor
        self.pieOpacity = pieOpacity
        self.fontFamily = fontFamily
    }

    public var pieColors: [String] {
        [pie1, pie2, pie3, pie4, pie5, pie6, pie7, pie8, pie9, pie10, pie11, pie12]
    }

    public func pieColor(at index: Int) -> String {
        guard index >= 0 else { return pie1.isEmpty ? Self.fallbackPieColors[0] : pie1 }
        let wrapped = index % 12
        let color = pieColors[wrapped]
        return color.isEmpty ? Self.fallbackPieColors[wrapped] : color
    }

    public var resolvedPieTitleTextColor: String { pieTitleTextColor.isEmpty ? "black" : pieTitleTextColor }
    public var resolvedPieSectionTextColor: String { pieSectionTextColor.isEmpty ? "black" : pieSectionTextColor }
    public var resolvedPieLegendTextColor: String { pieLegendTextColor.isEmpty ? "black" : pieLegendTextColor }
    public var resolvedFontFamily: String {
        fontFamily.isEmpty ? "trebuchet ms, verdana, arial, sans-serif" : fontFamily
    }
}

// MARK: - Positioned model

public struct PositionedPieChart: Sendable {
    public var viewBoxX: Double
    public var width: Double
    public var height: Double
    public var outerCircle: PieOuterCircle
    public var arcs: [PieArc]
    public var sliceLabels: [PieSliceLabel]
    public var title: PieTitle?
    public var legend: [PieLegendEntry]
    public var accTitle: String?
    public var accDescr: String?
    public var diagramTitle: String?
    public var config: PieChartConfig
    public var theme: PieChartThemeConfig

    public init(
        viewBoxX: Double = 0,
        width: Double,
        height: Double,
        outerCircle: PieOuterCircle,
        arcs: [PieArc] = [],
        sliceLabels: [PieSliceLabel] = [],
        title: PieTitle? = nil,
        legend: [PieLegendEntry] = [],
        accTitle: String? = nil,
        accDescr: String? = nil,
        diagramTitle: String? = nil,
        config: PieChartConfig = PieChartConfig(),
        theme: PieChartThemeConfig = PieChartThemeConfig()
    ) {
        self.viewBoxX = viewBoxX
        self.width = width
        self.height = height
        self.outerCircle = outerCircle
        self.arcs = arcs
        self.sliceLabels = sliceLabels
        self.title = title
        self.legend = legend
        self.accTitle = accTitle
        self.accDescr = accDescr
        self.diagramTitle = diagramTitle
        self.config = config
        self.theme = theme
    }

    public static var empty: PositionedPieChart {
        PositionedPieChart(
            width: 450,
            height: 450,
            outerCircle: PieOuterCircle(cx: 0, cy: 0, r: 185)
        )
    }
}

public struct PieOuterCircle: Sendable, Equatable {
    public var cx: Double
    public var cy: Double
    public var r: Double

    public init(cx: Double, cy: Double, r: Double) {
        self.cx = cx
        self.cy = cy
        self.r = r
    }
}

public struct PieArc: Sendable, Equatable {
    public var path: String
    public var label: String
    public var fillColorIndex: Int
    public var startAngle: Double
    public var endAngle: Double

    public init(path: String, label: String, fillColorIndex: Int, startAngle: Double, endAngle: Double) {
        self.path = path
        self.label = label
        self.fillColorIndex = fillColorIndex
        self.startAngle = startAngle
        self.endAngle = endAngle
    }
}

public struct PieSliceLabel: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double

    public init(text: String, x: Double, y: Double) {
        self.text = text
        self.x = x
        self.y = y
    }
}

public struct PieTitle: Sendable, Equatable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double

    public init(text: String, x: Double, y: Double, width: Double) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
    }
}

public struct PieLegendEntry: Sendable, Equatable {
    public var label: String
    public var displayText: String
    public var x: Double
    public var y: Double
    public var swatchX: Double
    public var swatchY: Double
    public var colorIndex: Int

    public init(
        label: String,
        displayText: String,
        x: Double,
        y: Double,
        swatchX: Double,
        swatchY: Double,
        colorIndex: Int
    ) {
        self.label = label
        self.displayText = displayText
        self.x = x
        self.y = y
        self.swatchX = swatchX
        self.swatchY = swatchY
        self.colorIndex = colorIndex
    }
}
