// Ported from original/src/xychart/layout.ts
import Foundation

// MARK: - Layout constants (defaults, overridden by config)

private enum XY {
    static let plotWidth: Double = 600
    static let plotHeight: Double = 340
    static let padding: Double = 22
    static let titleFontSize: Double = 18
    static let titleFontWeight: Int = 600
    static let titleHeight: Double = 42
    static let axisLabelFontSize: Double = 14
    static let axisLabelFontWeight: Int = 400
    static let axisTitleFontSize: Double = 15
    static let axisTitleFontWeight: Int = 500
    static let xLabelHeight: Double = 38
    static let yLabelWidth: Double = 58
    static let yLabelGap: Double = 18
    static let axisTitlePad: Double = 30
    static let tickLength: Double = 4
    static let barPadRatio: Double = 0.2
    static let barGroupGap: Double = 0
    static let maxBarWidth: Double = 40
    static let legendFontSize: Double = 12
    static let legendFontWeight: Int = 400
    static let legendHeight: Double = 24
    static let legendSwatchW: Double = 12
    static let legendSwatchH: Double = 10
    static let legendGap: Double = 5
    static let legendItemGap: Double = 14
    static let headerBottomPad: Double = 10
}

// MARK: - Public entry point

public func layoutXYChart(_ chart: XYChart, _ options: RenderOptions = RenderOptions()) -> PositionedXYChart {
    let config = chart.config ?? XYChartConfig()
    let theme = chart.theme ?? XYChartThemeConfig()
    let horizontal = config.chartOrientation == "horizontal" || chart.horizontal

    if horizontal { return _layoutHorizontal(chart, config, theme) }
    return _layoutVertical(chart, config, theme)
}

// MARK: - Vertical layout

private func _layoutVertical(_ chart: XYChart, _ config: XYChartConfig, _ theme: XYChartThemeConfig) -> PositionedXYChart {
    let resolvedTitle = chart.title ?? chart.diagramTitle
    let hasTitle = resolvedTitle != nil && config.showTitle
    let hasXTitle = chart.xAxis.title != nil && config.xAxis.showTitle
    let hasYTitle = chart.yAxis.title != nil && config.yAxis.showTitle
    let hasLegend = false

    guard let yRange = chart.yAxis.range else {
        return PositionedXYChart(width: 0, height: 0, title: nil, xAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), yAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), plotArea: XYPlotArea(x: 0, y: 0, width: 0, height: 0), bars: [], lines: [], gridLines: [], legend: [])
    }
    let yTicks = _niceTickValues(yRange.min, yRange.max)
    let maxYLabelWidth = max(
        yTicks.map({ original_src_styles.estimateTextWidth(_formatTickValue($0), config.yAxis.labelFontSize, Int(config.yAxis.labelFontSize > 14 ? 600 : 400)) }).max() ?? 0,
        XY.yLabelWidth
    )

    let titleFontSize = config.titleFontSize
    let titleHeight = config.showTitle ? titleFontSize * 2 + config.titlePadding : 0
    let axisLabelFontSize = config.xAxis.labelFontSize
    let tickLen = config.xAxis.tickLength
    let xLabelHeight = config.xAxis.showLabel ? axisLabelFontSize * 2 + config.xAxis.labelPadding : 0
    let yLabelWidth = config.yAxis.showLabel ? maxYLabelWidth : 0
    let yTitleHeight = config.yAxis.showTitle ? config.yAxis.titleFontSize + config.yAxis.titlePadding : 0

    let totalW = config.width
    let totalH = config.height
    let insets = _adjustInsetsForReservedPlotSpace(
        totalW: totalW,
        totalH: totalH,
        left: XY.padding + yLabelWidth + XY.yLabelGap + yTitleHeight,
        right: XY.padding,
        top: XY.padding + (hasTitle ? titleHeight : 0) + (hasLegend ? XY.legendHeight : 0) + (hasTitle || hasLegend ? XY.headerBottomPad : 0),
        bottom: XY.padding + xLabelHeight + (hasXTitle ? XY.axisTitlePad : 0) + (config.xAxis.showTick ? config.xAxis.tickLength : 0),
        config: config
    )
    let top = insets.top
    let bottom = insets.bottom
    let left = insets.left
    let right = insets.right

    let plotArea = XYPlotArea(
        x: left,
        y: top,
        width: totalW - left - right,
        height: totalH - top - bottom
    )

    let plotW = plotArea.width
    let plotH = plotArea.height

    let dataCount = _getDataCount(chart)
    let bandWidth = plotW / Double(dataCount)
    let xScale: (Int) -> Double = { i in left + (Double(i) + 0.5) * bandWidth }
    let yScale: (Double) -> Double = { v in
        let t = (v - yRange.min) / (yRange.max - yRange.min == 0 ? 1 : yRange.max - yRange.min)
        return top + plotH - t * plotH
    }

    let catLabels = _getCategoryLabels(chart, dataCount)
    let xTicks = _buildXTicks(chart, config, xScale, top + plotH, bandWidth)

    let yAxisTicks: [XYAxisTick] = yTicks.map { v in
        XYAxisTick(
            label: _formatTickValue(v),
            x: left, y: yScale(v),
            tx: left - tickLen, ty: yScale(v),
            labelX: left - XY.yLabelGap, labelY: yScale(v),
            textAnchor: "end"
        )
    }

    let gridLines: [XYGridLine] = yTicks.map { v in
        XYGridLine(x1: left, y1: yScale(v), x2: left + plotW, y2: yScale(v))
    }

    let colorMap = chart.series.indices.map { $0 }

    let bars = _layoutBars(chart, config, xScale, yScale, bandWidth, yRange.min, catLabels, colorMap)
    let lines = _layoutLines(chart, xScale, yScale, catLabels, colorMap)

    let legendY = XY.padding + (hasTitle ? titleHeight : 0) + XY.legendHeight / 2
    let legend = hasLegend ? _buildLegendItems(chart, config, totalW / 2, legendY, colorMap) : []

    let xAxisLine = AxisLine(x1: left, y1: top + plotH, x2: left + plotW, y2: top + plotH)
    let yAxisLine = AxisLine(x1: left, y1: top, x2: left, y2: top + plotH)

    // Tick lines
    var yTickLines: [PositionedTick] = []
    if config.yAxis.showTick {
        yTickLines = yAxisTicks.map { tick in
            PositionedTick(x1: tick.tx, y1: tick.ty, x2: tick.x, y2: tick.y)
        }
    }
    var xTickLines: [PositionedTick] = []
    if config.xAxis.showTick {
        xTickLines = xTicks.map { tick in
            PositionedTick(x1: tick.tx, y1: tick.ty, x2: tick.x, y2: tick.y)
        }
    }

    let xAxisTitle = hasXTitle ? AxisTitle(text: chart.xAxis.title ?? "", x: left + plotW / 2, y: totalH - XY.padding) : nil
    let yAxisTitle = hasYTitle ? AxisTitle(text: chart.yAxis.title ?? "", x: XY.padding + 4, y: top + plotH / 2, rotate: -90) : nil

    let xAxisObj = PositionedXYAxis(title: xAxisTitle, ticks: xTicks, tickLines: xTickLines, line: xAxisLine)
    let yAxisObj = PositionedXYAxis(title: yAxisTitle, ticks: yAxisTicks, tickLines: yTickLines, line: yAxisLine)

    let titleObj = resolvedTitle.map { PositionedTitle(text: $0, x: totalW / 2, y: XY.padding + titleFontSize) }

    return PositionedXYChart(
        width: totalW, height: totalH, title: titleObj,
        xAxis: xAxisObj, yAxis: yAxisObj, plotArea: plotArea,
        bars: bars, lines: lines, gridLines: gridLines, legend: legend,
        accTitle: chart.accTitle, accDescr: chart.accDescr,
        diagramTitle: chart.diagramTitle,
        config: config, theme: theme
    )
}

// MARK: - Horizontal layout

private func _layoutHorizontal(_ chart: XYChart, _ config: XYChartConfig, _ theme: XYChartThemeConfig) -> PositionedXYChart {
    let resolvedTitle = chart.title ?? chart.diagramTitle
    let hasTitle = resolvedTitle != nil && config.showTitle
    let hasXTitle = chart.xAxis.title != nil && config.xAxis.showTitle
    let hasYTitle = chart.yAxis.title != nil && config.yAxis.showTitle
    let hasLegend = false

    guard let yRange = chart.yAxis.range else {
        return PositionedXYChart(width: 0, height: 0, title: nil, xAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), yAxis: PositionedXYAxis(title: nil, ticks: [], line: AxisLine(x1: 0, y1: 0, x2: 0, y2: 0)), plotArea: XYPlotArea(x: 0, y: 0, width: 0, height: 0), bars: [], lines: [], gridLines: [], legend: [])
    }
    let valueTicks = _niceTickValues(yRange.min, yRange.max)

    let dataCount = _getDataCount(chart)
    let catLabels = _getCategoryLabels(chart, dataCount)
    let axisLabelFontSize = config.xAxis.labelFontSize
    let maxCatLabelWidth = max(
        catLabels.map({ original_src_styles.estimateTextWidth($0, axisLabelFontSize, 400) }).max() ?? 0,
        40
    )

    let titleFontSize = config.titleFontSize
    let titleHeight = config.showTitle ? titleFontSize * 2 + config.titlePadding : 0
    let xLabelHeight = config.xAxis.showLabel ? config.xAxis.labelFontSize * 2 + config.xAxis.labelPadding : 0
    let yLabelWidth = config.yAxis.showLabel ? maxCatLabelWidth : 0
    let xTitleHeight = config.xAxis.showTitle ? config.xAxis.titleFontSize + config.xAxis.titlePadding : 0
    let tickLen = config.xAxis.tickLength

    let totalW = config.width
    let totalH = config.height
    let insets = _adjustInsetsForReservedPlotSpace(
        totalW: totalW,
        totalH: totalH,
        left: XY.padding + yLabelWidth + XY.yLabelGap + xTitleHeight,
        right: XY.padding,
        top: XY.padding + (hasTitle ? titleHeight : 0) + (hasLegend ? XY.legendHeight : 0) + (hasTitle || hasLegend ? XY.headerBottomPad : 0),
        bottom: XY.padding + xLabelHeight + (hasYTitle ? XY.axisTitlePad : 0) + (config.yAxis.showTick ? tickLen : 0),
        config: config
    )
    let top = insets.top
    let bottom = insets.bottom
    let left = insets.left
    let right = insets.right

    let plotArea = XYPlotArea(
        x: left,
        y: top,
        width: totalW - left - right,
        height: totalH - top - bottom
    )

    let plotW = plotArea.width
    let plotH = plotArea.height

    let valueScale: (Double) -> Double = { v in
        let t = (v - yRange.min) / (yRange.max - yRange.min == 0 ? 1 : yRange.max - yRange.min)
        return left + t * plotW
    }
    let bandHeight = plotH / Double(dataCount)
    let catScale: (Int) -> Double = { i in top + (Double(i) + 0.5) * bandHeight }

    let xTicks: [XYAxisTick] = valueTicks.map { v in
        XYAxisTick(
            label: _formatTickValue(v), x: valueScale(v), y: top + plotH,
            tx: valueScale(v), ty: top + plotH + tickLen,
            labelX: valueScale(v), labelY: top + plotH + 18,
            textAnchor: "middle"
        )
    }

    let yTicks: [XYAxisTick] = catLabels.enumerated().map { i, label in
        XYAxisTick(
            label: label, x: left, y: catScale(i),
            tx: left - tickLen, ty: catScale(i),
            labelX: left - XY.yLabelGap, labelY: catScale(i),
            textAnchor: "end"
        )
    }

    let gridLines: [XYGridLine] = valueTicks.map { v in
        XYGridLine(x1: valueScale(v), y1: top, x2: valueScale(v), y2: top + plotH)
    }

    let colorMap = chart.series.indices.map { $0 }

    // Bars (horizontal)
    let barSeries = chart.series.enumerated().filter { $0.element.type == .bar }
    let barCount = barSeries.count
    var bars: [PositionedBar] = []
    if barCount > 0 {
        let usable = bandHeight * (1 - XY.barPadRatio)
        let rawBarH = barCount > 1 ? (usable - Double(barCount - 1) * XY.barGroupGap) / Double(barCount) : usable
        let singleBarH = min(rawBarH, XY.maxBarWidth)
        let groupH = barCount > 1 ? singleBarH * Double(barCount) + XY.barGroupGap * Double(barCount - 1) : singleBarH

        var bIdx = 0
        for (seriesArrayIdx, s) in chart.series.enumerated() {
            guard s.type == .bar else { continue }
            for i in 0..<min(s.data.count, catLabels.count) {
                let cy = catScale(i)
                let groupTop = cy - groupH / 2
                let by = groupTop + Double(bIdx) * (singleBarH + XY.barGroupGap)
                let valX = valueScale(max(s.data[i], yRange.min))
                let baseX = valueScale(max(0, yRange.min))
                var bar = PositionedBar(
                    x: min(baseX, valX), y: by,
                    width: abs(valX - baseX), height: singleBarH,
                    value: s.data[i], label: catLabels[i],
                    seriesIndex: bIdx, colorIndex: colorMap[seriesArrayIdx]
                )

                if config.showDataLabel && bar.width > 0 && bar.height > 0 {
                    let valStr = _formatTickValue(s.data[i])
                    let outside = config.showDataLabelOutsideBar
                    bar.dataLabel = PositionedDataLabel(
                        text: valStr,
                        x: outside ? bar.x + bar.width + 10 : bar.x + bar.width - 10,
                        y: bar.y + bar.height / 2,
                        textAnchor: outside ? "start" : "end",
                        fontSize: max(1, min(config.yAxis.labelFontSize, bar.height * 0.7))
                    )
                }

                bars.append(bar)
            }
            bIdx += 1
        }
    }

    // Lines (horizontal)
    var lines: [PositionedLine] = []
    var lineIdx = 0
    for (seriesIdx, s) in chart.series.enumerated() {
        guard s.type == .line else { continue }
        let points = (0..<min(s.data.count, catLabels.count)).map { i -> LinePoint in
            let v = s.data[i]
            return LinePoint(x: valueScale(v), y: catScale(i), value: v, label: catLabels[i])
        }
        lines.append(PositionedLine(points: points, seriesIndex: lineIdx, colorIndex: colorMap[seriesIdx]))
        lineIdx += 1
    }

    let xAxisLine = AxisLine(x1: left, y1: top + plotH, x2: left + plotW, y2: top + plotH)
    let yAxisLine = AxisLine(x1: left, y1: top, x2: left, y2: top + plotH)

    var xTickLines: [PositionedTick] = []
    if config.xAxis.showTick {
        xTickLines = xTicks.map { tick in
            PositionedTick(x1: tick.tx, y1: tick.ty, x2: tick.x, y2: tick.y)
        }
    }
    var yTickLines: [PositionedTick] = []
    if config.yAxis.showTick {
        yTickLines = yTicks.map { tick in
            PositionedTick(x1: tick.tx, y1: tick.ty, x2: tick.x, y2: tick.y)
        }
    }

    let xAxisTitle = hasYTitle ? AxisTitle(text: chart.yAxis.title ?? "", x: left + plotW / 2, y: totalH - XY.padding) : nil
    let yAxisTitle = hasXTitle ? AxisTitle(text: chart.xAxis.title ?? "", x: XY.padding + 4, y: top + plotH / 2, rotate: -90) : nil

    let xAxisObj = PositionedXYAxis(title: xAxisTitle, ticks: xTicks, tickLines: xTickLines, line: xAxisLine)
    let yAxisObj = PositionedXYAxis(title: yAxisTitle, ticks: yTicks, tickLines: yTickLines, line: yAxisLine)

    let titleObj = resolvedTitle.map { PositionedTitle(text: $0, x: totalW / 2, y: XY.padding + titleFontSize) }

    let legendY = XY.padding + (hasTitle ? titleHeight : 0) + XY.legendHeight / 2
    let legend = hasLegend ? _buildLegendItems(chart, config, totalW / 2, legendY, colorMap) : []

    return PositionedXYChart(
        width: totalW, height: totalH, horizontal: true, title: titleObj,
        xAxis: xAxisObj, yAxis: yAxisObj, plotArea: plotArea,
        bars: bars, lines: lines, gridLines: gridLines, legend: legend,
        accTitle: chart.accTitle, accDescr: chart.accDescr,
        diagramTitle: chart.diagramTitle,
        config: config, theme: theme
    )
}

// MARK: - Shared helpers (also used by ASCII renderer)

func _getDataCount(_ chart: XYChart) -> Int {
    if let cats = chart.xAxis.categories { return cats.count }
    for s in chart.series {
        if !s.data.isEmpty { return s.data.count }
    }
    return 1
}

func _getCategoryLabels(_ chart: XYChart, _ count: Int) -> [String] {
    if let cats = chart.xAxis.categories { return cats }
    if let range = chart.xAxis.range {
        let step = count > 1 ? (range.max - range.min) / Double(count - 1) : 0
        return (0..<count).map { _formatTickValue(range.min + step * Double($0)) }
    }
    return (0..<count).map { String($0 + 1) }
}

func _niceTickValues(_ min: Double, _ max: Double) -> [Double] {
    let range = max - min
    if range <= 0 { return [min] }

    let rawInterval = range / 6.0
    let magnitude = pow(10, floor(log10(rawInterval)))
    let residual = rawInterval / magnitude
    let niceInterval: Double
    if residual <= 1.5 { niceInterval = magnitude }
    else if residual <= 3 { niceInterval = 2 * magnitude }
    else if residual <= 7 { niceInterval = 5 * magnitude }
    else { niceInterval = 10 * magnitude }

    let start = ceil(min / niceInterval) * niceInterval
    var ticks: [Double] = []
    var v = start
    while v <= max + niceInterval * 0.001 {
        ticks.append((v * 1e10).rounded() / 1e10)
        v += niceInterval
    }
    return ticks
}

func _formatTickValue(_ v: Double) -> String {
    if v == v.rounded() && abs(v) < 1e15 { return String(Int(v)) }
    return abs(v) < 10 ? String(format: "%.1f", v) : String(format: "%.0f", v)
}

// MARK: - Private helpers

private func _buildXTicks(_ chart: XYChart, _ config: XYChartConfig, _ xScale: (Int) -> Double, _ axisY: Double, _ bandWidth: Double) -> [XYAxisTick] {
    let count = _getDataCount(chart)
    let labels = _getCategoryLabels(chart, count)
    return labels.enumerated().map { i, label in
        XYAxisTick(
            label: label, x: xScale(i), y: axisY,
            tx: xScale(i), ty: axisY + config.xAxis.tickLength,
            labelX: xScale(i), labelY: axisY + 18,
            textAnchor: "middle"
        )
    }
}

private func _adjustInsetsForReservedPlotSpace(
    totalW: Double,
    totalH: Double,
    left: Double,
    right: Double,
    top: Double,
    bottom: Double,
    config: XYChartConfig
) -> (left: Double, right: Double, top: Double, bottom: Double) {
    var left = left
    var right = right
    var top = top
    var bottom = bottom
    let reserved = min(max(config.plotReservedSpacePercent, 0), 100) / 100
    let minPlotW = floor(totalW * reserved)
    let minPlotH = floor(totalH * reserved)

    let currentPlotW = totalW - left - right
    if currentPlotW < minPlotW {
        var overflow = minPlotW - currentPlotW
        let reduceLeft = min(overflow, left)
        left -= reduceLeft
        overflow -= reduceLeft
        if overflow > 0 {
            right = max(0, right - overflow)
        }
    }

    let currentPlotH = totalH - top - bottom
    if currentPlotH < minPlotH {
        var overflow = minPlotH - currentPlotH
        let reduceBottom = min(overflow, bottom)
        bottom -= reduceBottom
        overflow -= reduceBottom
        if overflow > 0 {
            top = max(0, top - overflow)
        }
    }

    return (left, right, top, bottom)
}

private func _layoutBars(
    _ chart: XYChart, _ config: XYChartConfig, _ xScale: (Int) -> Double, _ yScale: (Double) -> Double,
    _ bandWidth: Double, _ yMin: Double, _ catLabels: [String], _ colorMap: [Int]
) -> [PositionedBar] {
    let barSeries = chart.series.filter { $0.type == .bar }
    let barCount = barSeries.count
    if barCount == 0 { return [] }

    let usable = bandWidth * (1 - XY.barPadRatio)
    let rawBarW = barCount > 1 ? (usable - Double(barCount - 1) * XY.barGroupGap) / Double(barCount) : usable
    let singleBarW = min(rawBarW, XY.maxBarWidth)
    let groupW = barCount > 1 ? singleBarW * Double(barCount) + XY.barGroupGap * Double(barCount - 1) : singleBarW

    var bars: [PositionedBar] = []
    var bIdx = 0
    for (seriesArrayIdx, s) in chart.series.enumerated() {
        guard s.type == .bar else { continue }
        for i in 0..<min(s.data.count, catLabels.count) {
            let cx = xScale(i)
            let groupLeft = cx - groupW / 2
            let bx = groupLeft + Double(bIdx) * (singleBarW + XY.barGroupGap)
            let valY = yScale(s.data[i])
            let baseY = yScale(max(0, yMin))
            let barX = bx
            let barY = min(valY, baseY)
            let barW = singleBarW
            let barH = abs(baseY - valY)

            var bar = PositionedBar(
                x: barX, y: barY,
                width: barW, height: barH,
                value: s.data[i], label: catLabels[i],
                seriesIndex: bIdx, colorIndex: colorMap[seriesArrayIdx]
            )

            // Data labels
            if config.showDataLabel && barH > 0 && barW > 0 {
                let valStr = _formatTickValue(s.data[i])
                let outside = config.showDataLabelOutsideBar
                let labelFontSize = min(config.xAxis.labelFontSize, barW * 0.35)

                if outside {
                    let outsideY = valY <= baseY ? barY - 4 : barY + barH + 4
                    bar.dataLabel = PositionedDataLabel(
                        text: valStr,
                        x: barX + barW / 2,
                        y: outsideY,
                        textAnchor: "middle",
                        fontSize: labelFontSize
                    )
                } else {
                    bar.dataLabel = PositionedDataLabel(
                        text: valStr,
                        x: barX + barW / 2,
                        y: barY + barH / 2,
                        textAnchor: "middle",
                        fontSize: labelFontSize
                    )
                }
            }

            bars.append(bar)
        }
        bIdx += 1
    }
    return bars
}

private func _layoutLines(
    _ chart: XYChart, _ xScale: (Int) -> Double, _ yScale: (Double) -> Double,
    _ catLabels: [String], _ colorMap: [Int]
) -> [PositionedLine] {
    var lines: [PositionedLine] = []
    var lineIdx = 0
    for (seriesArrayIdx, s) in chart.series.enumerated() {
        guard s.type == .line else { continue }
        let points = (0..<min(s.data.count, catLabels.count)).map { i -> LinePoint in
            let v = s.data[i]
            return LinePoint(x: xScale(i), y: yScale(v), value: v, label: catLabels[i])
        }
        lines.append(PositionedLine(points: points, seriesIndex: lineIdx, colorIndex: colorMap[seriesArrayIdx]))
        lineIdx += 1
    }
    return lines
}

private func _buildLegendItems(_ chart: XYChart, _ config: XYChartConfig, _ centerX: Double, _ y: Double, _ colorMap: [Int]) -> [XYLegendItem] {
    var items: [XYLegendItem] = []
    var barIdx = 0, lineIdx = 0
    for si in 0..<chart.series.count {
        let s = chart.series[si]
        let label = s.type == .bar ? "Bar \(barIdx + 1)" : "Line \(lineIdx + 1)"
        items.append(XYLegendItem(label: label, x: 0, y: y, type: s.type, seriesIndex: s.type == .bar ? barIdx : lineIdx, colorIndex: colorMap[si]))
        if s.type == .bar { barIdx += 1 }
        else { lineIdx += 1 }
    }

    let itemWidths = items.map { item in
        original_src_styles.estimateTextWidth(item.label, XY.legendFontSize, XY.legendFontWeight) + XY.legendSwatchW + XY.legendGap
    }
    let totalWidth = itemWidths.reduce(0, +) + Double(items.count - 1) * XY.legendItemGap
    var x = centerX - totalWidth / 2

    for i in 0..<items.count {
        items[i].x = x
        x += itemWidths[i] + XY.legendItemGap
    }

    return items
}
