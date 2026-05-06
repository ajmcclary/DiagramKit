import Foundation

// MARK: - Public API

public func layoutQuadrantChart(_ chart: QuadrantChart) -> PositionedQuadrantChart {
    let config = chart.config
    let theme = chart.theme

    let hasPoints = !chart.points.isEmpty

    let showXAxis = config.showXAxis
        && ((chart.xAxisLeftText.map { !$0.isEmpty } ?? false) || (chart.xAxisRightText.map { !$0.isEmpty } ?? false))
    let showYAxis = config.showYAxis
        && ((chart.yAxisTopText.map { !$0.isEmpty } ?? false) || (chart.yAxisBottomText.map { !$0.isEmpty } ?? false))
    let showTitle = config.showTitle && (chart.titleText.map { !$0.isEmpty } ?? false)

    let xAxisPosition = hasPoints ? "bottom" : config.xAxisPosition
    let effectiveYAxisPosition = config.yAxisPosition

    let space = calculateSpace(
        config: config,
        xAxisPosition: xAxisPosition,
        showXAxis: showXAxis,
        showYAxis: showYAxis,
        showTitle: showTitle,
        yAxisPosition: effectiveYAxisPosition
    )

    let quadrants = getQuadrants(chart: chart, theme: theme, config: config, space: space)
    let axisLabels = getAxisLabels(
        chart: chart, theme: theme, config: config,
        space: space, xAxisPosition: xAxisPosition,
        showXAxis: showXAxis, showYAxis: showYAxis,
        yAxisPosition: effectiveYAxisPosition
    )
    let positionedPoints = getPoints(chart: chart, theme: theme, config: config, space: space)
    let borderLines = getBorders(theme: theme, config: config, space: space)
    let title = getTitle(chart: chart, theme: theme, config: config, showTitle: showTitle)

    return PositionedQuadrantChart(
        width: config.chartWidth,
        height: config.chartHeight,
        quadrants: quadrants,
        axisLabels: axisLabels,
        points: positionedPoints,
        borderLines: borderLines,
        title: title,
        accTitle: chart.accTitle,
        accDescr: chart.accDescr,
        diagramTitle: chart.diagramTitle,
        config: config,
        theme: theme
    )
}

// MARK: - Space calculation

private struct QuadrantSpace {
    var xAxisSpace: (top: Double, bottom: Double)
    var yAxisSpace: (left: Double, right: Double)
    var titleSpaceTop: Double
    var quadrantLeft: Double
    var quadrantTop: Double
    var quadrantWidth: Double
    var quadrantHalfWidth: Double
    var quadrantHeight: Double
    var quadrantHalfHeight: Double
}

private func calculateSpace(
    config: QuadrantChartConfig,
    xAxisPosition: String,
    showXAxis: Bool,
    showYAxis: Bool,
    showTitle: Bool,
    yAxisPosition: String
) -> QuadrantSpace {
    let xAxisSpaceCalculation = config.xAxisLabelPadding * 2 + config.xAxisLabelFontSize
    let xAxisSpaceTop = xAxisPosition == "top" && showXAxis ? xAxisSpaceCalculation : 0.0
    let xAxisSpaceBottom = xAxisPosition == "bottom" && showXAxis ? xAxisSpaceCalculation : 0.0

    let yAxisSpaceCalculation = config.yAxisLabelPadding * 2 + config.yAxisLabelFontSize
    let yAxisSpaceLeft = yAxisPosition == "left" && showYAxis ? yAxisSpaceCalculation : 0.0
    let yAxisSpaceRight = yAxisPosition == "right" && showYAxis ? yAxisSpaceCalculation : 0.0

    let titleSpaceCalculation = config.titleFontSize + config.titlePadding * 2
    let titleSpaceTop = showTitle ? titleSpaceCalculation : 0.0

    let quadrantLeft = config.quadrantPadding + yAxisSpaceLeft
    let quadrantTop = config.quadrantPadding + xAxisSpaceTop + titleSpaceTop
    let quadrantWidth = config.chartWidth - config.quadrantPadding * 2 - yAxisSpaceLeft - yAxisSpaceRight
    let quadrantHeight = config.chartHeight - config.quadrantPadding * 2 - xAxisSpaceTop - xAxisSpaceBottom - titleSpaceTop

    let quadrantHalfWidth = quadrantWidth / 2
    let quadrantHalfHeight = quadrantHeight / 2

    return QuadrantSpace(
        xAxisSpace: (top: xAxisSpaceTop, bottom: xAxisSpaceBottom),
        yAxisSpace: (left: yAxisSpaceLeft, right: yAxisSpaceRight),
        titleSpaceTop: titleSpaceTop,
        quadrantLeft: quadrantLeft,
        quadrantTop: quadrantTop,
        quadrantWidth: quadrantWidth,
        quadrantHalfWidth: quadrantHalfWidth,
        quadrantHeight: quadrantHeight,
        quadrantHalfHeight: quadrantHalfHeight
    )
}

// MARK: - Quadrants (clockwise from top-right: 1=TR, 2=TL, 3=BL, 4=BR)

private func getQuadrants(
    chart: QuadrantChart,
    theme: QuadrantChartThemeConfig,
    config: QuadrantChartConfig,
    space: QuadrantSpace
) -> [PositionedQuadrant] {
    let qL = space.quadrantLeft
    let qT = space.quadrantTop
    let qHW = space.quadrantHalfWidth
    let qHH = space.quadrantHalfHeight
    let hasPoints = !chart.points.isEmpty

    var quadrants: [PositionedQuadrant] = []

    let quadrantDefs: [(fill: String, textFill: String, text: String?, x: Double, y: Double, num: Int)] = [
        (fill: theme.quadrant1Fill, textFill: theme.quadrant1TextFill, text: chart.quadrant1Text, x: qL + qHW, y: qT, num: 1),
        (fill: theme.quadrant2Fill, textFill: theme.quadrant2TextFill, text: chart.quadrant2Text, x: qL, y: qT, num: 2),
        (fill: theme.quadrant3Fill, textFill: theme.quadrant3TextFill, text: chart.quadrant3Text, x: qL, y: qT + qHH, num: 3),
        (fill: theme.quadrant4Fill, textFill: theme.quadrant4TextFill, text: chart.quadrant4Text, x: qL + qHW, y: qT + qHH, num: 4),
    ]

    for def in quadrantDefs {
        let textX = def.x + qHW / 2
        let textY: Double
        let horizontalPos: String
        if hasPoints {
            textY = def.y + config.quadrantTextTopPadding
            horizontalPos = "top"
        } else {
            textY = def.y + qHH / 2
            horizontalPos = "middle"
        }

        let text = PositionedQuadrantText(
            text: def.text ?? "",
            fill: def.textFill,
            x: textX,
            y: textY,
            fontSize: config.quadrantLabelFontSize,
            horizontalPos: horizontalPos,
            verticalPos: "center",
            rotation: 0
        )

        quadrants.append(PositionedQuadrant(
            x: def.x,
            y: def.y,
            width: qHW,
            height: qHH,
            fill: def.fill,
            text: text
        ))
    }

    return quadrants
}

// MARK: - Axis labels

private func getAxisLabels(
    chart: QuadrantChart,
    theme: QuadrantChartThemeConfig,
    config: QuadrantChartConfig,
    space: QuadrantSpace,
    xAxisPosition: String,
    showXAxis: Bool,
    showYAxis: Bool,
    yAxisPosition: String
) -> [PositionedQuadrantText] {
    let qL = space.quadrantLeft
    let qT = space.quadrantTop
    let qHW = space.quadrantHalfWidth
    let qHH = space.quadrantHalfHeight
    let qW = space.quadrantWidth
    let qH = space.quadrantHeight
    let hasRightLabel = (chart.xAxisRightText.map { !$0.isEmpty } ?? false)
    let hasTopLabel = (chart.yAxisTopText.map { !$0.isEmpty } ?? false)

    var labels: [PositionedQuadrantText] = []

    if let leftText = chart.xAxisLeftText, !leftText.isEmpty, showXAxis {
        let drawInMiddle = hasRightLabel
        labels.append(PositionedQuadrantText(
            text: leftText,
            fill: theme.quadrantXAxisTextFill,
            x: qL + (drawInMiddle ? qHW / 2 : 0),
            y: xAxisPosition == "top"
                ? config.xAxisLabelPadding + space.titleSpaceTop
                : config.xAxisLabelPadding + qT + qH + config.quadrantPadding,
            fontSize: config.xAxisLabelFontSize,
            horizontalPos: "top",
            verticalPos: drawInMiddle ? "center" : "left",
            rotation: 0
        ))
    }

    if let rightText = chart.xAxisRightText, !rightText.isEmpty, showXAxis {
        let drawInMiddle = hasRightLabel
        labels.append(PositionedQuadrantText(
            text: rightText,
            fill: theme.quadrantXAxisTextFill,
            x: qL + qHW + (drawInMiddle ? qHW / 2 : 0),
            y: xAxisPosition == "top"
                ? config.xAxisLabelPadding + space.titleSpaceTop
                : config.xAxisLabelPadding + qT + qH + config.quadrantPadding,
            fontSize: config.xAxisLabelFontSize,
            horizontalPos: "top",
            verticalPos: drawInMiddle ? "center" : "left",
            rotation: 0
        ))
    }

    if let bottomText = chart.yAxisBottomText, !bottomText.isEmpty, showYAxis {
        let drawInMiddle = hasTopLabel
        labels.append(PositionedQuadrantText(
            text: bottomText,
            fill: theme.quadrantYAxisTextFill,
            x: yAxisPosition == "left"
                ? config.yAxisLabelPadding
                : config.yAxisLabelPadding + qL + qW + config.quadrantPadding,
            y: qT + qH - (drawInMiddle ? qHH / 2 : 0),
            fontSize: config.yAxisLabelFontSize,
            horizontalPos: "top",
            verticalPos: drawInMiddle ? "center" : "left",
            rotation: -90
        ))
    }

    if let topText = chart.yAxisTopText, !topText.isEmpty, showYAxis {
        let drawInMiddle = hasTopLabel
        labels.append(PositionedQuadrantText(
            text: topText,
            fill: theme.quadrantYAxisTextFill,
            x: yAxisPosition == "left"
                ? config.yAxisLabelPadding
                : config.yAxisLabelPadding + qL + qW + config.quadrantPadding,
            y: qT + qHH - (drawInMiddle ? qHH / 2 : 0),
            fontSize: config.yAxisLabelFontSize,
            horizontalPos: "top",
            verticalPos: drawInMiddle ? "center" : "left",
            rotation: -90
        ))
    }

    return labels
}

// MARK: - Points

private func getPoints(
    chart: QuadrantChart,
    theme: QuadrantChartThemeConfig,
    config: QuadrantChartConfig,
    space: QuadrantSpace
) -> [PositionedQuadrantPoint] {
    let qL = space.quadrantLeft
    let qT = space.quadrantTop
    let qW = space.quadrantWidth
    let qH = space.quadrantHeight

    var positioned: [PositionedQuadrantPoint] = []
    for point in chart.points {
        var effectivePoint = point

        if let className = point.className, let classStyles = chart.classes[className] {
            if effectivePoint.radius == nil { effectivePoint.radius = classStyles.radius }
            if effectivePoint.color == nil { effectivePoint.color = classStyles.color }
            if effectivePoint.strokeColor == nil { effectivePoint.strokeColor = classStyles.strokeColor }
            if effectivePoint.strokeWidth == nil { effectivePoint.strokeWidth = classStyles.strokeWidth }
        }

        let px = qL + effectivePoint.x * qW
        let py = qT + qH - effectivePoint.y * qH

        let fill = effectivePoint.color ?? theme.quadrantPointFill
        let radius = effectivePoint.radius.map { Double($0) } ?? config.pointRadius
        let strokeColor = effectivePoint.strokeColor ?? theme.quadrantPointFill
        let strokeWidth = effectivePoint.strokeWidth ?? "0px"

        let textY = py + config.pointTextPadding

        let text = PositionedQuadrantText(
            text: effectivePoint.text,
            fill: theme.quadrantPointTextFill,
            x: px,
            y: textY,
            fontSize: config.pointLabelFontSize,
            horizontalPos: "top",
            verticalPos: "center",
            rotation: 0
        )

        positioned.append(PositionedQuadrantPoint(
            x: px,
            y: py,
            fill: fill,
            radius: radius,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            text: text
        ))
    }

    return positioned
}

// MARK: - Border lines

private func getBorders(
    theme: QuadrantChartThemeConfig,
    config: QuadrantChartConfig,
    space: QuadrantSpace
) -> [PositionedQuadrantLine] {
    let halfExternal = config.quadrantExternalBorderStrokeWidth / 2

    let qL = space.quadrantLeft
    let qT = space.quadrantTop
    let qW = space.quadrantWidth
    let qH = space.quadrantHeight
    let qHW = space.quadrantHalfWidth
    let qHH = space.quadrantHalfHeight

    return [
        PositionedQuadrantLine(
            x1: qL - halfExternal, y1: qT,
            x2: qL + qW + halfExternal, y2: qT,
            strokeFill: theme.quadrantExternalBorderStrokeFill,
            strokeWidth: config.quadrantExternalBorderStrokeWidth
        ),
        PositionedQuadrantLine(
            x1: qL + qW, y1: qT + halfExternal,
            x2: qL + qW, y2: qT + qH - halfExternal,
            strokeFill: theme.quadrantExternalBorderStrokeFill,
            strokeWidth: config.quadrantExternalBorderStrokeWidth
        ),
        PositionedQuadrantLine(
            x1: qL - halfExternal, y1: qT + qH,
            x2: qL + qW + halfExternal, y2: qT + qH,
            strokeFill: theme.quadrantExternalBorderStrokeFill,
            strokeWidth: config.quadrantExternalBorderStrokeWidth
        ),
        PositionedQuadrantLine(
            x1: qL, y1: qT + halfExternal,
            x2: qL, y2: qT + qH - halfExternal,
            strokeFill: theme.quadrantExternalBorderStrokeFill,
            strokeWidth: config.quadrantExternalBorderStrokeWidth
        ),
        PositionedQuadrantLine(
            x1: qL + qHW, y1: qT + halfExternal,
            x2: qL + qHW, y2: qT + qH - halfExternal,
            strokeFill: theme.quadrantInternalBorderStrokeFill,
            strokeWidth: config.quadrantInternalBorderStrokeWidth
        ),
        PositionedQuadrantLine(
            x1: qL + halfExternal, y1: qT + qHH,
            x2: qL + qW - halfExternal, y2: qT + qHH,
            strokeFill: theme.quadrantInternalBorderStrokeFill,
            strokeWidth: config.quadrantInternalBorderStrokeWidth
        ),
    ]
}

// MARK: - Title

private func getTitle(
    chart: QuadrantChart,
    theme: QuadrantChartThemeConfig,
    config: QuadrantChartConfig,
    showTitle: Bool
) -> PositionedQuadrantTitle? {
    guard showTitle, let text = chart.titleText, !text.isEmpty else { return nil }

    return PositionedQuadrantTitle(
        text: text,
        fill: theme.quadrantTitleFill,
        fontSize: config.titleFontSize,
        x: config.chartWidth / 2,
        y: config.titlePadding,
        horizontalPos: "top",
        verticalPos: "center",
        rotation: 0
    )
}
