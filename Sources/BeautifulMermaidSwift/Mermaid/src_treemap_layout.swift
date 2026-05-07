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
            if i < scale.count {
                scale[i] = val
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

    children.forEach { _ in
    }

    let sortedChildren = children.sorted { ($0.aggregateValue) > ($1.aggregateValue) }
    let totalValue = sortedChildren.reduce(0.0) { $0 + $1.aggregateValue }

    guard totalValue > 0 else {
        let chunkW = (x1 - x0) / Double(max(1, sortedChildren.count))
        var cx = x0
        for child in sortedChildren {
            _layoutSquarified(
                node: child,
                x0: cx, y0: y0, x1: cx + chunkW, y1: y1,
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
            cx += chunkW
        }
        return
    }

    var remaining = sortedChildren.map { ($0, $0.aggregateValue) }
    var currentX = x0, currentY = y0
    let rectWidth = x1 - x0
    let rectHeight = y1 - y0
    let isHorizontal = rectWidth > rectHeight

    while !remaining.isEmpty {
        let (rowItems, rowValue) = _selectRow(remaining, remainingWidth: isHorizontal ? rectWidth : rectHeight, totalValue: remaining.reduce(0) { $0 + $1.1 })
        let fraction = rowValue / remaining.reduce(0) { $0 + $1.1 }

        if isHorizontal {
            let rowW = fraction.isNaN ? rectWidth : rectWidth * fraction
            let (_, newRemaining) = (Array(remaining.dropFirst(rowItems.count)), Array(remaining.dropFirst(rowItems.count)))
            var childX = currentX
            for (child, val) in rowItems {
                let childW = rowValue > 0 ? rowW * (val / rowValue) : rowW / Double(rowItems.count)
                _layoutSquarified(
                    node: child,
                    x0: childX, y0: currentY, x1: childX + childW, y1: currentY + rectHeight,
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
                childX += childW
            }
            currentX += rowW
        } else {
            let rowH = fraction.isNaN ? rectHeight : rectHeight * fraction
            var childY = currentY
            for (child, val) in rowItems {
                let childH = rowValue > 0 ? rowH * (val / rowValue) : rowH / Double(rowItems.count)
                _layoutSquarified(
                    node: child,
                    x0: currentX, y0: childY, x1: currentX + rectWidth, y1: childY + childH,
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
                childY += childH
            }
            currentY += rowH
        }

        remaining = Array(remaining.dropFirst(rowItems.count))
    }

    if depth > 0 && !node.name.isEmpty {
        let sectionW = round(x1 - x0)
        let sectionH = round(y1 - y0)
        let aggregateVal = node.aggregateValue
        let formattedAgg = formatTreemapValue(aggregateVal, format: config.valueFormat)
        let section = PositionedTreemapSection(
            index: sectionIndex,
            name: node.name,
            depth: depth,
            x0: round(x0), y0: round(y0), x1: round(x1), y1: round(y1),
            fillColor: myFill, strokeColor: myStroke, labelColor: myLabelColor,
            cssCompiledStyles: node.cssCompiledStyles,
            classSelector: node.classSelector,
            label: _makeSectionLabel(name: node.name, width: sectionW, labelColor: myLabelColor),
            value: config.showValues ? _makeSectionValue(value: formattedAgg, width: sectionW, labelColor: myLabelColor) : nil,
            clipId: "clip-section-\(diagramId)-\(sectionIndex)",
            aggregateValue: aggregateVal,
            formattedValue: formattedAgg
        )
        sections.append(section)
        sectionIndex += 1
    }
}

private func _selectRow(_ items: [(TreemapNode, Double)], remainingWidth: Double, totalValue: Double) -> ([(TreemapNode, Double)], Double) {
    guard items.count > 1 else { return (items, items.first?.1 ?? 0) }
    return (items, items.reduce(0) { $0 + $1.1 })
}

private func _makeSectionLabel(name: String, width: Double, labelColor: String) -> PositionedTreemapText {
    PositionedTreemapText(
        text: name,
        x: 6, y: SECTION_HEADER_HEIGHT / 2,
        fontSize: 12,
        fontWeight: "bold",
        textAnchor: "start",
        dominantBaseline: "middle",
        fillColor: labelColor
    )
}

private func _makeSectionValue(value: String, width: Double, labelColor: String) -> PositionedTreemapText {
    PositionedTreemapText(
        text: value,
        x: width - 10, y: SECTION_HEADER_HEIGHT / 2,
        fontSize: 10,
        fontStyle: "italic",
        textAnchor: "end",
        dominantBaseline: "middle",
        fillColor: labelColor
    )
}

private func _fitLeafText(
    name: String, value: Double, formattedValue: String?,
    width: Double, height: Double,
    config: TreemapDiagramConfig,
    labelColor: String, showValues: Bool,
    cssCompiledStyles: [String]?
) -> (label: PositionedTreemapText?, valueText: PositionedTreemapText?) {

    let minW: Double = 10
    let minH: Double = 10
    if width < minW || height < minH {
        let hiddenLabel = PositionedTreemapText(
            text: name, x: width / 2, y: height / 2, fontSize: 8,
            textAnchor: "middle", dominantBaseline: "middle",
            fillColor: labelColor, hidden: true
        )
        return (hiddenLabel, nil)
    }

    let maxFontSize: Double = 38
    let minFontSize: Double = 8

    var fontSize = maxFontSize
    let charWEstimate: Double = 0.6
    while fontSize > minFontSize {
        let textWidth = Double(name.count) * charWEstimate * fontSize
        if textWidth <= width - 4 { break }
        fontSize -= 1
    }
    fontSize = max(minFontSize, fontSize)

    var labelText = PositionedTreemapText(
        text: name, x: width / 2, y: height / 2, fontSize: fontSize,
        textAnchor: "middle", dominantBaseline: "middle",
        fillColor: labelColor, hidden: false
    )

    let labelHidden = fontSize < minFontSize || width < minW || height < minH
    if labelHidden {
        labelText.hidden = true
        labelText = PositionedTreemapText(
            text: name, x: width / 2, y: height / 2, fontSize: 8,
            textAnchor: "middle", dominantBaseline: "middle",
            fillColor: labelColor, hidden: true
        )
        return (labelText, nil)
    }

    if !showValues || formattedValue == nil || formattedValue!.isEmpty {
        return (labelText, nil)
    }

    let valueFontSize = max(6.0, min(28.0, round(fontSize * 0.6)))
    let combinedHeight = fontSize + 2 + valueFontSize
    let valueY = height / 2 + fontSize / 2 + 2

    let valueHidden = combinedHeight > height || valueY + valueFontSize > height
    let valueText = PositionedTreemapText(
        text: formattedValue!, x: width / 2, y: valueY,
        fontSize: valueFontSize,
        textAnchor: "middle", dominantBaseline: "hanging",
        fillColor: labelColor, hidden: valueHidden
    )

    return (labelText, valueText)
}

func formatTreemapValue(_ value: Double, format: String) -> String {
    let fmt = format.trimmingCharacters(in: .whitespaces)

    if fmt == "$" {
        return "$\(Int(value.rounded()))"
    }
    if fmt.hasPrefix("$") {
        let sub = String(fmt.dropFirst())
        if sub.hasPrefix(",") || sub.hasPrefix("0") {
            let numberStr = _commaFormat(value)
            return "$\(numberStr)"
        }
        if sub.hasPrefix(".") {
            let rest = String(sub.dropFirst())
            if rest.hasSuffix("f") {
                let digits = Int(String(rest.dropLast())) ?? 2
                return "$\(String(format: "%.\(digits)f", value))"
            }
            if rest.hasSuffix("%") {
                return "$\(String(format: "%.1f%%", value * 100))"
            }
            return "$\(String(format: "%.2f", value))"
        }
        return "$\(_commaFormat(value))"
    }
    if fmt == "," {
        return _commaFormat(value)
    }
    if fmt.hasPrefix(",.") {
        let rest = String(fmt.dropFirst(2))
        if rest.hasSuffix("f") {
            let digits = Int(String(rest.dropLast())) ?? 2
            return _commaFormat(value, decimals: digits)
        }
    }
    if fmt.hasPrefix(".") {
        let rest = String(fmt.dropFirst())
        if rest.hasSuffix("f") {
            let digits = Int(String(rest.dropLast())) ?? 2
            return String(format: "%.\(digits)f", value)
        }
        if rest.hasSuffix("%") {
            return String(format: "%.1f%%", value * 100)
        }
        if rest.hasSuffix("e") {
            let digits = Int(String(rest.dropLast())) ?? 2
            return String(format: "%.\(digits)e", value)
        }
        return String(format: "%.2f", value)
    }
    if fmt == "0" {
        return "\(Int(value.rounded()))"
    }

    return _commaFormat(value)
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
