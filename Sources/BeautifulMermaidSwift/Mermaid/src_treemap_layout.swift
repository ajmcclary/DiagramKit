import Foundation

let SECTION_HEADER_HEIGHT: Double = 25
let SECTION_INNER_PADDING: Double = 10

func layoutTreemapDiagram(_ diagram: TreemapDiagram) -> PositionedTreemapDiagram {
    let config = diagram.config
    let titleHeight = diagram.diagramTitle != nil ? 30.0 : 0.0

    let width: Double = config.nodeWidth * 10
    let height: Double = config.nodeHeight * 10
    let svgWidth = width
    let svgHeight = height + titleHeight

    let title: PositionedTreemapTitle?
    if let t = diagram.diagramTitle {
        title = PositionedTreemapTitle(text: t, x: svgWidth / 2, y: titleHeight / 2)
    } else {
        title = nil
    }

    let themeVars = diagram.themeVariables ?? [:]
    let cScale = _getColorScale(prefix: "cScale", from: themeVars, defaults: TreemapThemeDefaults.defaultCScale)
    let cScalePeer = _getColorScale(prefix: "cScalePeer", from: themeVars, defaults: TreemapThemeDefaults.defaultCScalePeer)
    let cScaleLabel = _getColorScale(prefix: "cScaleLabel", from: themeVars, defaults: TreemapThemeDefaults.defaultCScaleLabel)

    let hierarchy = diagram.nodes
    let root = TreemapNode(name: "", children: hierarchy.isEmpty ? [] : hierarchy, value: nil)

    var sections: [PositionedTreemapSection] = []
    var leaves: [PositionedTreemapLeaf] = []
    var colorIndex: [String: Int] = [:]
    var nextColorIndex = 1
    var sectionIndex = 0
    var leafIndex = 0

    let diagramId = UUID().uuidString

    _collectColorIndices(root, &colorIndex, &nextColorIndex)

    _layoutSquarified(
        node: root,
        x0: 0, y0: 0, x1: width, y1: height,
        depth: 0,
        parentFill: "transparent",
        parentStroke: "transparent",
        parentLabelColor: "#ffffff",
        cScale: cScale, cScalePeer: cScalePeer, cScaleLabel: cScaleLabel,
        colorIndex: colorIndex,
        config: config,
        sections: &sections,
        leaves: &leaves,
        sectionIndex: &sectionIndex,
        leafIndex: &leafIndex,
        diagramId: diagramId
    )

    return PositionedTreemapDiagram(
        width: width, height: height,
        svgWidth: svgWidth, svgHeight: svgHeight,
        titleHeight: titleHeight, title: title,
        sections: sections, leaves: leaves,
        diagramPadding: config.diagramPadding,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: config,
        themeName: diagram.themeName,
        themeVariables: diagram.themeVariables
    )
}

private func _getColorScale(prefix: String, from vars: [String: String], defaults: [String]) -> [String] {
    var scale = defaults
    for i in 0..<12 {
        let key = "\(prefix)\(i)"
        if let val = vars[key], !val.isEmpty {
            let targetIndex = scale.first == "transparent" ? i + 1 : i
            if targetIndex < scale.count {
                scale[targetIndex] = val
            } else {
                scale.append(val)
            }
        }
    }
    return scale
}

private func _collectColorIndices(_ node: TreemapNode, _ colorIndex: inout [String: Int], _ next: inout Int) {
    if !node.name.isEmpty && colorIndex[node.name] == nil {
        colorIndex[node.name] = next
        next += 1
    }
    for child in node.children ?? [] {
        _collectColorIndices(child, &colorIndex, &next)
    }
}

private func _layoutSquarified(
    node: TreemapNode,
    x0: Double, y0: Double, x1: Double, y1: Double,
    depth: Int,
    parentFill: String, parentStroke: String, parentLabelColor: String,
    cScale: [String], cScalePeer: [String], cScaleLabel: [String],
    colorIndex: [String: Int],
    config: TreemapDiagramConfig,
    sections: inout [PositionedTreemapSection],
    leaves: inout [PositionedTreemapLeaf],
    sectionIndex: inout Int,
    leafIndex: inout Int,
    diagramId: String
) {
    let children = node.children ?? []

    if children.isEmpty {
        if let val = node.value, !node.name.isEmpty {
            let ci = (colorIndex[node.name] ?? 1) % cScale.count
            let fill = parentFill == "transparent" ? cScale[max(1, ci % cScale.count)] : parentFill
            let stroke = parentStroke == "transparent" ? cScalePeer[max(1, ci % cScalePeer.count)] : parentStroke
            let labelColor = cScaleLabel[max(0, ci % cScaleLabel.count)]

            let w = x1 - x0
            let h = y1 - y0

            let formattedValue = formatTreemapValue(val, format: config.valueFormat)
            let text = _fitLeafText(
                name: node.name, value: val, formattedValue: formattedValue,
                width: w, height: h, config: config, labelColor: labelColor,
                showValues: config.showValues,
                cssCompiledStyles: node.cssCompiledStyles
            )

            let leaf = PositionedTreemapLeaf(
                index: leafIndex,
                name: node.name,
                x0: round(x0), y0: round(y0), x1: round(x1), y1: round(y1),
                fillColor: fill, strokeColor: stroke, labelColor: labelColor,
                value: val, formattedValue: formattedValue,
                cssCompiledStyles: node.cssCompiledStyles,
                classSelector: node.classSelector,
                label: text.label,
                valueText: text.valueText,
                clipId: "clip-\(diagramId)-\(leafIndex)"
            )
            leaves.append(leaf)
            leafIndex += 1
        }
        return
    }

    let myFill: String
    let myStroke: String
    let myLabelColor: String

    if depth == 0 {
        myFill = "transparent"
        myStroke = "transparent"
        myLabelColor = "#ffffff"
    } else {
        let ci = (colorIndex[node.name] ?? depth) % cScale.count
        myFill = cScale[max(1, ci % cScale.count)]
        myStroke = cScalePeer[max(1, ci % cScalePeer.count)]
        myLabelColor = cScaleLabel[max(0, ci % cScaleLabel.count)]
    }

    let sortedChildren = children.sorted { ($0.aggregateValue) > ($1.aggregateValue) }
    let totalValue = sortedChildren.reduce(0.0) { $0 + $1.aggregateValue }

    if depth > 0 && !node.name.isEmpty {
        let sectionW = round(x1 - x0)
        let aggregateVal = node.aggregateValue
        let formattedAgg = formatTreemapValue(aggregateVal, format: config.valueFormat)
        let sectionLabel = _makeSectionLabel(
            name: node.name, width: sectionW, labelColor: myLabelColor,
            showValues: config.showValues, valueText: config.showValues ? formattedAgg : nil
        )
        let sectionValue: PositionedTreemapText? = config.showValues
            ? _makeSectionValue(value: formattedAgg, width: sectionW, labelColor: myLabelColor, sectionLabelText: sectionLabel.text)
            : nil
        let section = PositionedTreemapSection(
            index: sectionIndex,
            name: node.name,
            depth: depth,
            x0: round(x0), y0: round(y0), x1: round(x1), y1: round(y1),
            fillColor: myFill, strokeColor: myStroke, labelColor: myLabelColor,
            cssCompiledStyles: node.cssCompiledStyles,
            classSelector: node.classSelector,
            label: sectionLabel,
            value: sectionValue,
            clipId: "clip-section-\(diagramId)-\(sectionIndex)",
            aggregateValue: aggregateVal,
            formattedValue: formattedAgg
        )
        sections.append(section)
        sectionIndex += 1
    }

    let contentRect = _treemapChildContentRect(x0: x0, y0: y0, x1: x1, y1: y1)

    guard totalValue > 0 else {
        let fallbackRects = _treemapEqualSplit(sortedChildren, in: contentRect, innerPadding: config.padding)
        for (child, rect) in fallbackRects {
            _layoutSquarified(
                node: child,
                x0: rect.x0, y0: rect.y0, x1: rect.x1, y1: rect.y1,
                depth: depth + 1,
                parentFill: myFill, parentStroke: myStroke, parentLabelColor: myLabelColor,
                cScale: cScale, cScalePeer: cScalePeer, cScaleLabel: cScaleLabel,
                colorIndex: colorIndex,
                config: config,
                sections: &sections,
                leaves: &leaves,
                sectionIndex: &sectionIndex,
                leafIndex: &leafIndex,
                diagramId: diagramId
            )
        }
        return
    }

    let childRects = _treemapSquarify(sortedChildren, in: contentRect, innerPadding: config.padding)
    for (child, rect) in childRects {
        _layoutSquarified(
            node: child,
            x0: rect.x0, y0: rect.y0, x1: rect.x1, y1: rect.y1,
            depth: depth + 1,
            parentFill: myFill, parentStroke: myStroke, parentLabelColor: myLabelColor,
            cScale: cScale, cScalePeer: cScalePeer, cScaleLabel: cScaleLabel,
            colorIndex: colorIndex,
            config: config,
            sections: &sections,
            leaves: &leaves,
            sectionIndex: &sectionIndex,
            leafIndex: &leafIndex,
            diagramId: diagramId
        )
    }
}

private struct _TreemapRect {
    var x0: Double
    var y0: Double
    var x1: Double
    var y1: Double

    var width: Double { max(0, x1 - x0) }
    var height: Double { max(0, y1 - y0) }
    var area: Double { width * height }

    func inset(_ amount: Double) -> _TreemapRect {
        guard amount > 0, width > amount * 2, height > amount * 2 else { return self }
        return _TreemapRect(x0: x0 + amount, y0: y0 + amount, x1: x1 - amount, y1: y1 - amount)
    }
}

private struct _TreemapWeightedNode {
    var node: TreemapNode
    var value: Double
    var area: Double
}

private func _treemapChildContentRect(x0: Double, y0: Double, x1: Double, y1: Double) -> _TreemapRect {
    let content = _TreemapRect(
        x0: x0 + SECTION_INNER_PADDING,
        y0: y0 + SECTION_HEADER_HEIGHT + SECTION_INNER_PADDING,
        x1: x1 - SECTION_INNER_PADDING,
        y1: y1 - SECTION_INNER_PADDING
    )
    if content.width <= 0 || content.height <= 0 {
        return _TreemapRect(x0: x0, y0: y0, x1: x1, y1: y1)
    }
    return content
}

private func _treemapEqualSplit(_ nodes: [TreemapNode], in rect: _TreemapRect, innerPadding: Double) -> [(TreemapNode, _TreemapRect)] {
    guard !nodes.isEmpty else { return [] }
    if nodes.count == 1 { return [(nodes[0], rect)] }

    var results: [(TreemapNode, _TreemapRect)] = []
    if rect.width >= rect.height {
        let chunk = rect.width / Double(nodes.count)
        for (index, node) in nodes.enumerated() {
            let r = _TreemapRect(
                x0: rect.x0 + Double(index) * chunk,
                y0: rect.y0,
                x1: index == nodes.count - 1 ? rect.x1 : rect.x0 + Double(index + 1) * chunk,
                y1: rect.y1
            )
            results.append((node, _treemapApplyInnerPadding(r, count: nodes.count, innerPadding: innerPadding)))
        }
    } else {
        let chunk = rect.height / Double(nodes.count)
        for (index, node) in nodes.enumerated() {
            let r = _TreemapRect(
                x0: rect.x0,
                y0: rect.y0 + Double(index) * chunk,
                x1: rect.x1,
                y1: index == nodes.count - 1 ? rect.y1 : rect.y0 + Double(index + 1) * chunk
            )
            results.append((node, _treemapApplyInnerPadding(r, count: nodes.count, innerPadding: innerPadding)))
        }
    }
    return results
}

private func _treemapSquarify(_ nodes: [TreemapNode], in rect: _TreemapRect, innerPadding: Double) -> [(TreemapNode, _TreemapRect)] {
    guard !nodes.isEmpty, rect.area > 0 else { return [] }
    if nodes.count == 1 { return [(nodes[0], rect)] }

    let total = nodes.reduce(0.0) { $0 + max(0, $1.aggregateValue) }
    guard total > 0 else { return _treemapEqualSplit(nodes, in: rect, innerPadding: innerPadding) }

    var remaining = nodes.map {
        _TreemapWeightedNode(node: $0, value: max(0, $0.aggregateValue), area: max(0, $0.aggregateValue) * rect.area / total)
    }
    var layoutRect = rect
    var row: [_TreemapWeightedNode] = []
    var results: [(TreemapNode, _TreemapRect)] = []

    while !remaining.isEmpty {
        let candidate = remaining.removeFirst()
        let side = min(layoutRect.width, layoutRect.height)
        if row.isEmpty || _treemapWorst(row + [candidate], side: side) <= _treemapWorst(row, side: side) {
            row.append(candidate)
        } else {
            _treemapLayoutRow(row, in: &layoutRect, totalCount: nodes.count, innerPadding: innerPadding, results: &results)
            row = [candidate]
        }
    }

    if !row.isEmpty {
        _treemapLayoutRow(row, in: &layoutRect, totalCount: nodes.count, innerPadding: innerPadding, results: &results)
    }

    return results
}

private func _treemapWorst(_ row: [_TreemapWeightedNode], side: Double) -> Double {
    guard !row.isEmpty, side > 0 else { return Double.infinity }
    let areas = row.map { max(0.000_001, $0.area) }
    let sum = areas.reduce(0, +)
    guard sum > 0 else { return Double.infinity }
    let maxArea = areas.max() ?? 0
    let minArea = areas.min() ?? 0.000_001
    let sideSquared = side * side
    return max((sideSquared * maxArea) / (sum * sum), (sum * sum) / (sideSquared * minArea))
}

private func _treemapLayoutRow(
    _ row: [_TreemapWeightedNode],
    in rect: inout _TreemapRect,
    totalCount: Int,
    innerPadding: Double,
    results: inout [(TreemapNode, _TreemapRect)]
) {
    guard !row.isEmpty else { return }
    let rowArea = row.reduce(0.0) { $0 + $1.area }
    guard rowArea > 0, rect.width > 0, rect.height > 0 else { return }

    if rect.width >= rect.height {
        let rowHeight = min(rect.height, rowArea / rect.width)
        var x = rect.x0
        for (index, item) in row.enumerated() {
            let itemWidth = index == row.count - 1 ? rect.x1 - x : item.area / max(rowHeight, 0.000_001)
            let raw = _TreemapRect(x0: x, y0: rect.y0, x1: x + itemWidth, y1: rect.y0 + rowHeight)
            results.append((item.node, _treemapApplyInnerPadding(raw, count: totalCount, innerPadding: innerPadding)))
            x += itemWidth
        }
        rect.y0 += rowHeight
    } else {
        let rowWidth = min(rect.width, rowArea / rect.height)
        var y = rect.y0
        for (index, item) in row.enumerated() {
            let itemHeight = index == row.count - 1 ? rect.y1 - y : item.area / max(rowWidth, 0.000_001)
            let raw = _TreemapRect(x0: rect.x0, y0: y, x1: rect.x0 + rowWidth, y1: y + itemHeight)
            results.append((item.node, _treemapApplyInnerPadding(raw, count: totalCount, innerPadding: innerPadding)))
            y += itemHeight
        }
        rect.x0 += rowWidth
    }
}

private func _treemapApplyInnerPadding(_ rect: _TreemapRect, count: Int, innerPadding: Double) -> _TreemapRect {
    guard count > 1 else { return rect }
    return rect.inset(max(0, innerPadding) / 2)
}

private func _makeSectionLabel(name: String, width: Double, labelColor: String, showValues: Bool = false, valueText: String? = nil) -> PositionedTreemapText {
    let labelFontSize: Double = 12
    let labelX: Double = 6
    let labelRightPadding: Double = 6

    var availableWidth = width - labelX - labelRightPadding

    if showValues, let valueStr = valueText, !valueStr.isEmpty {
        let valueEndsAtX = width - 10
        let estimatedValueWidth = Double(valueStr.count) * 0.6 * 10
        let gap = 10.0
        let labelMustEndBefore = valueEndsAtX - estimatedValueWidth - gap
        availableWidth = max(15, labelMustEndBefore - labelX)
    }

    let text = _truncateTreemapLabel(name, fontSize: labelFontSize, availableWidth: availableWidth)

    return PositionedTreemapText(
        text: text,
        x: labelX, y: SECTION_HEADER_HEIGHT / 2,
        fontSize: labelFontSize,
        fontWeight: "bold",
        textAnchor: "start",
        dominantBaseline: "middle",
        fillColor: labelColor
    )
}

private func _makeSectionValue(value: String, width: Double, labelColor: String, sectionLabelText: String? = nil) -> PositionedTreemapText {
    let valueFontSize: Double = 10
    let valueX = width - 10

    var availableWidth = width - 10
    if let labelText = sectionLabelText, !labelText.isEmpty {
        let estimatedLabelWidth = Double(labelText.count) * 0.6 * 12 + 6
        availableWidth = max(0, valueX - estimatedLabelWidth - 6)
    }

    let estimatedValueWidth = Double(value.count) * 0.6 * valueFontSize
    let hidden = estimatedValueWidth > availableWidth

    return PositionedTreemapText(
        text: value,
        x: valueX, y: SECTION_HEADER_HEIGHT / 2,
        fontSize: valueFontSize,
        fontStyle: "italic",
        textAnchor: "end",
        dominantBaseline: "middle",
        fillColor: labelColor,
        hidden: hidden
    )
}

private func _truncateTreemapLabel(_ text: String, fontSize: Double, availableWidth: Double) -> String {
    let estimatedWidth = Double(text.count) * 0.6 * fontSize
    if estimatedWidth <= availableWidth { return text }

    let ellipsis = "..."
    var truncated = text
    while !truncated.isEmpty {
        truncated = String(text.prefix(truncated.count - 1))
        let candidate = truncated + ellipsis
        if Double(candidate.count) * 0.6 * fontSize <= availableWidth {
            return candidate
        }
    }
    let finalEllipsisWidth = Double(ellipsis.count) * 0.6 * fontSize
    return finalEllipsisWidth <= availableWidth ? ellipsis : ""
}

private func _fitLeafText(
    name: String, value: Double, formattedValue: String?,
    width: Double, height: Double,
    config: TreemapDiagramConfig,
    labelColor: String, showValues: Bool,
    cssCompiledStyles: [String]?
) -> (label: PositionedTreemapText?, valueText: PositionedTreemapText?) {

    let padding: Double = 4
    let availableWidth = width - 2 * padding
    let availableHeight = height - 2 * padding

    let minW: Double = 10
    let minH: Double = 10
    if width < minW || height < minH || availableWidth < minW || availableHeight < minH {
        return (
            PositionedTreemapText(
                text: name, x: width / 2, y: height / 2, fontSize: 8,
                textAnchor: "middle", dominantBaseline: "middle",
                fillColor: labelColor, hidden: true
            ),
            nil
        )
    }

    let maxLabelFontSize: Double = 38
    let minLabelFontSize: Double = 8
    let originalValueRelFontSize: Double = 28
    let valueScaleFactor: Double = 0.6
    let minValueFontSize: Double = 6
    let spacingBetweenLabelAndValue: Double = 2

    var currentLabelFontSize = maxLabelFontSize

    while Double(name.count) * 0.6 * currentLabelFontSize > availableWidth && currentLabelFontSize > minLabelFontSize {
        currentLabelFontSize -= 1
    }

    let textWidthEstimate = Double(name.count) * 0.6 * currentLabelFontSize
    if currentLabelFontSize < minLabelFontSize || textWidthEstimate > availableWidth || availableHeight < currentLabelFontSize {
        return (
            PositionedTreemapText(
                text: name, x: width / 2, y: height / 2, fontSize: max(minLabelFontSize, currentLabelFontSize),
                textAnchor: "middle", dominantBaseline: "middle",
                fillColor: labelColor, hidden: true
            ),
            nil
        )
    }

    if !showValues || formattedValue == nil || formattedValue!.isEmpty {
        return (
            PositionedTreemapText(
                text: name, x: width / 2, y: height / 2, fontSize: currentLabelFontSize,
                textAnchor: "middle", dominantBaseline: "middle",
                fillColor: labelColor, hidden: false
            ),
            nil
        )
    }

    var prospectiveValueFontSize = max(minValueFontSize, min(originalValueRelFontSize, round(currentLabelFontSize * valueScaleFactor)))
    var combinedHeight = currentLabelFontSize + spacingBetweenLabelAndValue + prospectiveValueFontSize

    while combinedHeight > availableHeight && currentLabelFontSize > minLabelFontSize {
        currentLabelFontSize -= 1
        prospectiveValueFontSize = max(minValueFontSize, min(originalValueRelFontSize, round(currentLabelFontSize * valueScaleFactor)))
        combinedHeight = currentLabelFontSize + spacingBetweenLabelAndValue + prospectiveValueFontSize
    }

    if currentLabelFontSize < minLabelFontSize || availableHeight < currentLabelFontSize || textWidthEstimate > availableWidth {
        return (
            PositionedTreemapText(
                text: name, x: width / 2, y: height / 2, fontSize: max(minLabelFontSize, currentLabelFontSize),
                textAnchor: "middle", dominantBaseline: "middle",
                fillColor: labelColor, hidden: true
            ),
            nil
        )
    }

    let labelCenterY = height / 2
    let valueY = labelCenterY + currentLabelFontSize / 2 + spacingBetweenLabelAndValue

    let valueWidthEstimate = Double(formattedValue!.count) * 0.6 * prospectiveValueFontSize
    let valueMaxY = height - padding
    let valueHidden = valueWidthEstimate > availableWidth
        || valueY + prospectiveValueFontSize > valueMaxY
        || prospectiveValueFontSize < minValueFontSize

    return (
        PositionedTreemapText(
            text: name, x: width / 2, y: labelCenterY, fontSize: currentLabelFontSize,
            textAnchor: "middle", dominantBaseline: "middle",
            fillColor: labelColor, hidden: false
        ),
        valueHidden ? nil : PositionedTreemapText(
            text: formattedValue!, x: width / 2, y: valueY,
            fontSize: prospectiveValueFontSize,
            textAnchor: "middle", dominantBaseline: "hanging",
            fillColor: labelColor, hidden: false
        )
    )
}

func formatTreemapValue(_ value: Double, format: String) -> String {
    let fmt = format.trimmingCharacters(in: .whitespaces)
    let positiveSign = fmt.hasPrefix("+")

    if fmt == "$" {
        return _pos("$\(Int(value.rounded()))", positiveSign)
    }
    if fmt.hasPrefix("$") {
        let sub = String(fmt.dropFirst())
        if sub.contains(",") {
            let numberStr: String
            if let digits = _fixedDecimalDigits(in: sub) {
                numberStr = _commaFormat(value, decimals: digits)
            } else {
                numberStr = _commaFormat(value)
            }
            return _pos("$\(numberStr)", positiveSign)
        }
        if sub.hasPrefix("0") {
            return _pos("$\(_commaFormat(value))", positiveSign)
        }
        if sub.hasPrefix(".") {
            let rest = String(sub.dropFirst())
            if rest.hasSuffix("f") {
                let digits = Int(String(rest.dropLast())) ?? 2
                return _pos("$\(String(format: "%.\(digits)f", value))", positiveSign)
            }
            if rest.hasSuffix("%") {
                let pctDigits = _percentDigits(from: rest) ?? 1
                return _pos("$\(String(format: "%.\(pctDigits)f%%", value * 100))", positiveSign)
            }
            if rest.hasSuffix("s") {
                let siDigits = Int(String(rest.dropLast())) ?? 2
                return _pos("$\(_siFormat(value, digits: siDigits))", positiveSign)
            }
            return _pos("$\(String(format: "%.2f", value))", positiveSign)
        }
        return _pos("$\(_commaFormat(value))", positiveSign)
    }
    if fmt == "," {
        return _pos(_commaFormat(value), positiveSign)
    }
    if fmt.hasPrefix(",.") {
        let rest = String(fmt.dropFirst(2))
        if rest.hasSuffix("f") {
            let digits = Int(String(rest.dropLast())) ?? 2
            return _pos(_commaFormat(value, decimals: digits), positiveSign)
        }
        if rest.hasSuffix("s") {
            let siDigits = Int(String(rest.dropLast())) ?? 2
            return _pos(_siFormat(value, digits: siDigits), positiveSign)
        }
    }
    if fmt.hasPrefix(".") {
        let rest = String(fmt.dropFirst())
        if rest.hasSuffix("f") {
            let digits = Int(String(rest.dropLast())) ?? 2
            return _pos(String(format: "%.\(digits)f", value), positiveSign)
        }
        if rest.hasSuffix("%") {
            let pctDigits = _percentDigits(from: rest) ?? 1
            return _pos(String(format: "%.\(pctDigits)f%%", value * 100), positiveSign)
        }
        if rest.hasSuffix("e") {
            let digits = Int(String(rest.dropLast())) ?? 2
            return _pos(String(format: "%.\(digits)e", value), positiveSign)
        }
        if rest.hasSuffix("s") {
            let siDigits = Int(String(rest.dropLast())) ?? 2
            return _pos(_siFormat(value, digits: siDigits), positiveSign)
        }
        return _pos(String(format: "%.2f", value), positiveSign)
    }
    if fmt == "0" {
        return _pos("\(Int(value.rounded()))", positiveSign)
    }

    return _pos(_commaFormat(value), positiveSign)
}

private func _pos(_ s: String, _ positiveSign: Bool) -> String {
    guard positiveSign else { return s }
    if s.hasPrefix("-") { return s }
    return "+\(s)"
}

private func _percentDigits(from rest: String) -> Int? {
    let numPart = rest.prefix(while: { $0.isNumber })
    guard !numPart.isEmpty, rest.dropFirst(numPart.count).hasPrefix("%") else { return nil }
    return Int(numPart)
}

private func _siFormat(_ value: Double, digits: Int) -> String {
    let absVal = abs(value)
    let sign = value < 0 ? "-" : ""
    switch absVal {
    case 1e24...:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e24))Y"
    case 1e21..<1e24:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e21))Z"
    case 1e18..<1e21:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e18))E"
    case 1e15..<1e18:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e15))P"
    case 1e12..<1e15:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e12))T"
    case 1e9..<1e12:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e9))G"
    case 1e6..<1e9:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e6))M"
    case 1e3..<1e6:
        return "\(sign)\(String(format: "%.\(digits)f", value / 1e3))k"
    default:
        return "\(sign)\(String(format: "%.\(digits)f", value))"
    }
}

private func _fixedDecimalDigits(in format: String) -> Int? {
    guard let dotIndex = format.firstIndex(of: ".") else { return nil }
    let afterDot = format[format.index(after: dotIndex)...]
    let digits = afterDot.prefix(while: { $0.isNumber })
    guard !digits.isEmpty, afterDot.dropFirst(digits.count).first == "f" else { return nil }
    return Int(digits)
}

private func _commaFormat(_ value: Double, decimals: Int? = nil) -> String {
    let number: Double
    if let d = decimals {
        let factor = pow(10.0, Double(d))
        number = round(value * factor) / factor
    } else {
        number = value.rounded()
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    formatter.usesGroupingSeparator = true
    if let d = decimals {
        formatter.minimumFractionDigits = d
        formatter.maximumFractionDigits = d
    } else {
        let intPart = Int64(number.rounded())
        if Double(intPart) == number {
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 0
        } else {
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
        }
    }

    return formatter.string(from: NSNumber(value: number)) ?? "\(Int(value.rounded()))"
}
