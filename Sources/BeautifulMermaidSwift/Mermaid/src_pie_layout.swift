import Foundation

// MARK: - Constants (matching pieRenderer.ts)

private let PIE_HEIGHT: Double = 450
private let PIE_WIDTH: Double = 450
private let MARGIN: Double = 40
private let LEGEND_RECT_SIZE: Double = 18
private let LEGEND_SPACING: Double = 4

// MARK: - Public API

public func layoutPieChart(_ chart: PieChart) -> PositionedPieChart {
    let config = chart.config
    let theme = chart.theme

    let radius = min(PIE_WIDTH, PIE_HEIGHT) / 2 - MARGIN
    let outerStrokeWidth = parsePieLength(theme.pieOuterStrokeWidth) ?? 2
    let outerR = radius + outerStrokeWidth / 2

    let outerCircle = PieOuterCircle(cx: 0, cy: 0, r: outerR)

    let sections = chart.sections
    let sum = sections.reduce(0.0) { $0 + $1.value }

    // Zero-sum guard: no arcs, no labels, but legend still present
    if sum <= 0 {
        let legendEntries = layoutLegend(
            sections: sections,
            showData: chart.showData,
            theme: theme
        )
        let title = layoutTitle(
            text: chart.diagramTitle,
            theme: theme,
            pieWidth: PIE_WIDTH
        )

        var positioned = PositionedPieChart(
            width: PIE_WIDTH,
            height: PIE_HEIGHT,
            outerCircle: outerCircle,
            arcs: [],
            sliceLabels: [],
            title: title,
            legend: legendEntries,
            accTitle: chart.accTitle,
            accDescr: chart.accDescr,
            diagramTitle: chart.diagramTitle,
            config: config,
            theme: theme
        )

        _applyViewBox(&positioned, config: config)
        return positioned
    }

    // Stage 1: filter < 1% and create arcs
    let d3Arcs = createPieArcs(sections: sections, sum: sum, radius: radius)

    // Stage 2: filter 0% round
    let filteredArcs = d3Arcs.filter { $0.isVisible }

    // Build positioned arcs
    let colorIndexes = assignColorIndexes(sections: sections)
    var positionedArcs: [PieArc] = []
    for arcData in filteredArcs {
        let path = arcPath(
            cx: 0, cy: 0,
            radius: radius,
            startAngle: arcData.startAngle,
            endAngle: arcData.endAngle
        )
        let ci = colorIndexes[arcData.label] ?? 0
        positionedArcs.append(
            PieArc(
                path: path,
                label: arcData.label,
                fillColorIndex: ci,
                startAngle: arcData.startAngle,
                endAngle: arcData.endAngle
            )
        )
    }

    // Slice labels (percentages)
    let textPosition = max(0.0, min(1.0, config.textPosition))
    var sliceLabels: [PieSliceLabel] = []
    let percentageFormatter = NumberFormatter()
    percentageFormatter.maximumFractionDigits = 0

    for arcData in filteredArcs {
        let pct = ((arcData.value / sum) * 100)
        let roundedPct = Int(pct.rounded())
        let pctText = "\(roundedPct)%"

        let midAngle = (arcData.startAngle + arcData.endAngle) / 2
        let labelRadius = radius * textPosition
        let lx = labelRadius * cos(midAngle)
        let ly = labelRadius * sin(midAngle)

        sliceLabels.append(PieSliceLabel(text: pctText, x: lx, y: ly))
    }

    // Title (group-local coordinates)
    let pieTitle = layoutTitle(text: chart.diagramTitle, theme: theme, pieWidth: PIE_WIDTH)

    // Legend
    let legendEntries = layoutLegend(
        sections: sections,
        showData: chart.showData,
        theme: theme
    )

    var positioned = PositionedPieChart(
        width: PIE_WIDTH,
        height: PIE_HEIGHT,
        outerCircle: outerCircle,
        arcs: positionedArcs,
        sliceLabels: sliceLabels,
        title: pieTitle,
        legend: legendEntries,
        accTitle: chart.accTitle,
        accDescr: chart.accDescr,
        diagramTitle: chart.diagramTitle,
        config: config,
        theme: theme
    )

    _applyViewBox(&positioned, config: config)
    return positioned
}

// MARK: - Arc creation

private struct ArcData {
    let label: String
    let value: Double
    let startAngle: Double
    let endAngle: Double
    let isVisible: Bool
}

private func createPieArcs(sections: [PieSection], sum: Double, radius: Double) -> [ArcData] {
    // Filter <1% (Stage 1)
    var visibleSections: [PieSection] = []
    var totalVisibleValue: Double = 0
    for section in sections {
        let pct = (section.value / sum) * 100
        if pct >= 1.0 {
            visibleSections.append(section)
            totalVisibleValue += section.value
        }
    }

    guard totalVisibleValue > 0 else { return [] }

    // Build arcs clockwise from 12 o'clock (-π/2), source order
    var arcs: [ArcData] = []
    var currentAngle: Double = -.pi / 2

    for section in visibleSections {
        let sweepAngle = (section.value / totalVisibleValue) * 2 * .pi
        let endAngle = currentAngle + sweepAngle

        // Determine visibility (0% round filter)
        let pct = (section.value / sum) * 100
        let roundedToZero = Int(pct.rounded()) == 0

        arcs.append(ArcData(
            label: section.label,
            value: section.value,
            startAngle: currentAngle,
            endAngle: endAngle,
            isVisible: !roundedToZero
        ))

        currentAngle = endAngle
    }

    return arcs
}

// MARK: - Arc path helper

private func arcPath(cx: Double, cy: Double, radius: Double, startAngle: Double, endAngle: Double) -> String {
    let x1 = cx + radius * cos(startAngle)
    let y1 = cy + radius * sin(startAngle)
    let x2 = cx + radius * cos(endAngle)
    let y2 = cy + radius * sin(endAngle)

    let largeArc = (endAngle - startAngle) > .pi ? 1 : 0

    return "M \(cx),\(cy) L \(x1),\(y1) A \(radius),\(radius) 0 \(largeArc),1 \(x2),\(y2) Z"
}

// MARK: - Color indexing

private func assignColorIndexes(sections: [PieSection]) -> [String: Int] {
    var result: [String: Int] = [:]
    for (index, section) in sections.enumerated() {
        result[section.label] = index
    }
    return result
}

// MARK: - Title layout

private func layoutTitle(text: String?, theme: PieChartThemeConfig, pieWidth: Double) -> PieTitle? {
    guard let text = text, !text.isEmpty else { return nil }

    // Title is at x=0 (group-local, group is centered at pieWidth/2), y = -(height - 50)/2
    let titleY = -(PIE_HEIGHT - 50) / 2

    let fontSize = parsePieLength(theme.pieTitleTextSize) ?? 25
    let estimatedWidth = Double(text.count) * fontSize * 0.6

    return PieTitle(text: text, x: 0, y: titleY, width: estimatedWidth)
}

// MARK: - Legend layout

private func layoutLegend(
    sections: [PieSection],
    showData: Bool,
    theme: PieChartThemeConfig
) -> [PieLegendEntry] {
    let colorIndexes = assignColorIndexes(sections: sections)
    var entries: [PieLegendEntry] = []

    let rowHeight = LEGEND_RECT_SIZE + LEGEND_SPACING
    let totalHeight = rowHeight * Double(sections.count)
    let offset = totalHeight / 2
    let horizontal = 12 * LEGEND_RECT_SIZE

    for (index, section) in sections.enumerated() {
        let vertical = Double(index) * rowHeight - offset
        let valueStr: String
        if section.value == section.value.rounded() {
            valueStr = String(Int(section.value))
        } else {
            valueStr = String(section.value)
        }
        let displayText = showData ? "\(section.label) [\(valueStr)]" : section.label

        entries.append(PieLegendEntry(
            label: section.label,
            displayText: displayText,
            x: horizontal,
            y: vertical,
            swatchX: 0,
            swatchY: 0,
            colorIndex: colorIndexes[section.label] ?? index
        ))
    }

    return entries
}

// MARK: - ViewBox expansion

private func _applyViewBox(_ positioned: inout PositionedPieChart, config: PieChartConfig) {
    let pieWidth = PIE_WIDTH

    var chartAndLegendWidth = pieWidth
    if !positioned.legend.isEmpty {
        let legendTextWidth = positioned.legend.reduce(0.0) { maxLen, entry in
            let charCount = Double(entry.displayText.count)
            let fontSize = parsePieLength(positioned.theme.pieLegendTextSize) ?? 17
            let estimated = charCount * fontSize * 0.7
            return max(maxLen, estimated)
        }

        let legendX = 12 * LEGEND_RECT_SIZE
        let legendTotalWidth = legendX + LEGEND_RECT_SIZE + LEGEND_SPACING + legendTextWidth
        chartAndLegendWidth = pieWidth + MARGIN + legendTotalWidth
    }

    // Estimate title width
    var titleLeft: Double = 0
    var titleRight: Double = pieWidth
    if let title = positioned.title {
        let titleWidth = title.width
        titleLeft = pieWidth / 2 - titleWidth / 2
        titleRight = pieWidth / 2 + titleWidth / 2
    }

    let viewBoxX = min(0, titleLeft)
    let viewBoxRight = max(chartAndLegendWidth, titleRight)
    let totalWidth = viewBoxRight - viewBoxX

    positioned.viewBoxX = viewBoxX
    positioned.width = totalWidth
}

// MARK: - Unit parsing

private func parsePieLength(_ s: String) -> Double? {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let numeric = trimmed
        .replacingOccurrences(of: "px", with: "")
        .replacingOccurrences(of: "em", with: "")
        .replacingOccurrences(of: "rem", with: "")
        .replacingOccurrences(of: "pt", with: "")
        .trimmingCharacters(in: .whitespaces)
    return Double(numeric)
}
