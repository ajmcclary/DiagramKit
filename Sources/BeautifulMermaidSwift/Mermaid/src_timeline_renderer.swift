import Foundation

public func renderTimelineSvg(
    _ diagram: PositionedTimelineDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderTimelineSvg(diagram, diagramId: "mermaid-0", colors, font, transparent)
}

public func renderTimelineSvg(
    _ diagram: PositionedTimelineDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderTimelineSvg(diagram, diagramId: diagramId, colors, font, transparent)
}

private func _renderTimelineSvg(
    _ diagram: PositionedTimelineDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []

    let conf = diagram.config

    let widthStr = _tfmt(diagram.width)
    let heightStr = _tfmt(diagram.height)

    var svgAttrs: [String] = [
        "id=\"\(diagramId)\"",
        "xmlns=\"http://www.w3.org/2000/svg\"",
        "xmlns:xlink=\"http://www.w3.org/1999/xlink\"",
    ]

    if conf.useMaxWidth {
        svgAttrs.append("width=\"100%\"")
        svgAttrs.append("viewBox=\"0 0 \(widthStr) \(heightStr)\"")
        svgAttrs.append("preserveAspectRatio=\"xMinYMin meet\"")
    } else {
        svgAttrs.append("width=\"\(widthStr)\"")
        svgAttrs.append("height=\"\(heightStr)\"")
        svgAttrs.append("viewBox=\"0 0 \(widthStr) \(heightStr)\"")
    }

    let styleVars = [
        "--bg:\(colors.bg)",
        "--fg:\(colors.fg)",
        colors.line.map { "--line:\($0)" } ?? "",
        colors.accent.map { "--accent:\($0)" } ?? "",
        colors.muted.map { "--muted:\($0)" } ?? "",
        colors.surface.map { "--surface:\($0)" } ?? "",
        colors.border.map { "--border:\($0)" } ?? "",
    ].filter { !$0.isEmpty }.joined(separator: ";")

    var rootStyles: [String] = []
    if conf.useMaxWidth {
        rootStyles.append("max-width: \(widthStr)px")
    }
    if !styleVars.isEmpty {
        rootStyles.append(styleVars)
    }
    if !transparent {
        rootStyles.append("background:var(--bg)")
    }
    if !rootStyles.isEmpty {
        svgAttrs.append("style=\"\(rootStyles.joined(separator: ";"))\"")
    }

    parts.append("<svg \(svgAttrs.joined(separator: " "))>")

    // Accessibility
    if let accTitle = diagram.accTitle, !accTitle.isEmpty {
        parts.append("<title>\(_tescapeXml(accTitle))</title>")
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        parts.append("<desc>\(_tescapeXml(accDescr))</desc>")
    }

    // Defs with arrowhead marker, gradient, and drop-shadow
    let theme = diagram.theme
    let isNeo = diagram.look == "neo"
    let themeName = diagram.themeName ?? ""
    let isRedux = themeName.contains("redux")
    let isNeutral = themeName == "neutral"

    parts.append("<defs>")
    let arrowheadId = "\(diagramId)-arrowhead"
    parts.append("<marker id=\"\(arrowheadId)\" refX=\"5\" refY=\"2\" markerWidth=\"6\" markerHeight=\"4\" orient=\"auto\">")
    parts.append("<path d=\"M 0,0 V 4 L6,2 Z\" class=\"arrowheadPath\" fill=\"var(--line, #666)\"/>")
    parts.append("</marker>")

    if isNeo && theme.useGradient && !isNeutral {
        parts.append("""
        <linearGradient id="\(diagramId)-gradient" gradientUnits="objectBoundingBox" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="\(theme.gradientStart)" stop-opacity="1"/>
        <stop offset="100%" stop-color="\(theme.gradientStop)" stop-opacity="1"/>
        </linearGradient>
        """)
    }

    if isNeo && isRedux {
        let isDark = themeName.contains("dark")
        let floodColor = isDark ? "#FFFFFF" : "#000000"
        let floodOpacity = isDark ? "0.2" : "0.06"
        parts.append("""
        <filter id="\(diagramId)-drop-shadow" height="130%" width="130%">
        <feDropShadow dx="4" dy="4" stdDeviation="0" flood-opacity="\(floodOpacity)" flood-color="\(floodColor)"/>
        </filter>
        """)
    }
    parts.append("</defs>")

    let taskFontSize = conf.taskFontSize
    let strokeWidth: Double = isNeo ? 2 : 1
    let borderRadius: Double = isRedux ? 0 : 3
    let borderRadiusStr = _tfmt(borderRadius)
    let neoAttrs = isNeo ? " data-look=\"neo\"" : ""
    let filterAttr = (isNeo && isRedux) ? " filter=\"url(#\(diagramId)-drop-shadow)\"" : ""

    // Section nodes
    for section in diagram.sections {
        let sx = _tfmt(section.x)
        let sy = _tfmt(section.y)
        let sw = _tfmt(section.width)
        let sh = _tfmt(section.height)
        let colorIdx = section.colorIndex % max(1, theme.cScale.count)
        let fill = isNeo ? theme.mainBkg : theme.cScale[colorIdx]
        let textFill = isNeo ? theme.nodeBorder : theme.cScaleLabel[colorIdx]
        let stroke = isNeo && theme.useGradient && !isNeutral
            ? "url(#\(diagramId)-gradient)"
            : theme.cScale[colorIdx]

        let label = _trenderTimelineLabel(
            section.text,
            x: section.x,
            y: section.y,
            width: section.width,
            height: section.height,
            fill: textFill,
            fontSize: taskFontSize,
            fontFamily: conf.taskFontFamily,
            placement: conf.textPlacement
        )

        parts.append("""
        <g class="timeline-node section-\(section.sectionIndex)"\(neoAttrs)>
        <rect x="\(sx)" y="\(sy)" width="\(sw)" height="\(sh)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(_tfmt(strokeWidth))" rx="\(borderRadiusStr)" ry="\(borderRadiusStr)"\(filterAttr)/>
        \(label)
        </g>
        """)
    }

    // Task nodes
    for task in diagram.tasks {
        let tx = _tfmt(task.x)
        let ty = _tfmt(task.y)
        let tw = _tfmt(task.width)
        let th = _tfmt(task.height)
        let colorIdx = task.colorIndex % max(1, theme.cScale.count)
        let fill = isNeo ? theme.mainBkg : theme.cScale[colorIdx]
        let textFill = isNeo ? theme.nodeBorder : theme.cScaleLabel[colorIdx]
        let lineColor = theme.cScaleInv[colorIdx]
        let stroke = isNeo && theme.useGradient && !isNeutral
            ? "url(#\(diagramId)-gradient)"
            : theme.cScale[colorIdx]

        let label = _trenderTimelineLabel(
            task.text,
            x: task.x,
            y: task.y,
            width: task.width,
            height: task.height,
            fill: textFill,
            fontSize: taskFontSize,
            fontFamily: conf.taskFontFamily,
            placement: conf.textPlacement
        )

        var taskParts: [String] = []
        taskParts.append("<g class=\"taskWrapper\"\(neoAttrs)>")
        taskParts.append("<rect class=\"node-bkg node-\(task.colorIndex)\" x=\"\(tx)\" y=\"\(ty)\" width=\"\(tw)\" height=\"\(th)\" fill=\"\(fill)\" stroke=\"\(stroke)\" stroke-width=\"\(_tfmt(strokeWidth))\" rx=\"\(borderRadiusStr)\" ry=\"\(borderRadiusStr)\"\(filterAttr)/>")
        if !isRedux {
            taskParts.append("<line class=\"node-line-\(task.colorIndex)\" x1=\"\(tx)\" y1=\"\(_tfmt(task.y + task.height))\" x2=\"\(_tfmt(task.x + task.width))\" y2=\"\(_tfmt(task.y + task.height))\" stroke=\"\(lineColor)\" stroke-width=\"3\"/>")
        }
        taskParts.append("\(label)")
        taskParts.append("</g>")
        parts.append(taskParts.joined(separator: "\n"))
    }

    // Event nodes
    for event in diagram.events {
        let ex = _tfmt(event.x)
        let ey = _tfmt(event.y)
        let ew = _tfmt(event.width)
        let eh = _tfmt(event.height)
        let colorIdx = event.colorIndex % max(1, theme.cScale.count)
        let fill = isNeo ? theme.mainBkg : theme.cScale[colorIdx]
        let stroke = isNeo && theme.useGradient && !isNeutral
            ? "url(#\(diagramId)-gradient)"
            : theme.cScale[colorIdx]

        let label = _trenderTimelineLabel(
            event.text,
            x: event.x,
            y: event.y,
            width: event.width,
            height: event.height,
            fill: "var(--fg, #27272A)",
            fontSize: taskFontSize,
            fontFamily: conf.taskFontFamily,
            placement: conf.textPlacement
        )

        parts.append("""
        <g class="eventWrapper"\(neoAttrs) filter="brightness(120%)">
        <rect class="node-bkg" x="\(ex)" y="\(ey)" width="\(ew)" height="\(eh)" fill="\(fill)" stroke="\(stroke)" stroke-width="\(_tfmt(strokeWidth))" rx="\(borderRadiusStr)" ry="\(borderRadiusStr)"\(filterAttr)/>
        \(label)
        </g>
        """)
    }

    // Connectors
    parts.append("<g class=\"lineWrapper\">")
    for connector in diagram.connectors {
        switch connector.kind {
        case .verticalLR(let x1, let y1, let x2, let y2):
            parts.append("""
            <line x1="\(_tfmt(x1))" y1="\(_tfmt(y1))" x2="\(_tfmt(x2))" y2="\(_tfmt(y2))" stroke="var(--line, #666)" stroke-dasharray="5,5" stroke-width="2" marker-end="url(#\(arrowheadId))"/>
            """)
        case .horizontalTD(let x1, let y1, let x2, let y2):
            parts.append("""
            <line x1="\(_tfmt(x1))" y1="\(_tfmt(y1))" x2="\(_tfmt(x2))" y2="\(_tfmt(y2))" stroke="var(--line, #666)" stroke-dasharray="5,5" stroke-width="2" marker-end="url(#\(arrowheadId))"/>
            """)
        }
    }
    parts.append("</g>")

    // Title
    if let title = diagram.title, !title.text.isEmpty {
        let escapedTitle = _tescapeXml(title.text)
        parts.append("""
        <text x="\(_tfmt(title.x))" y="\(_tfmt(title.y))" font-size="4ex" font-weight="bold" fill="var(--fg, #000)">\(escapedTitle)</text>
        """)
    }

    // Activity line
    parts.append("""
    <line x1="\(_tfmt(diagram.activityLine.x1))" y1="\(_tfmt(diagram.activityLine.y1))" x2="\(_tfmt(diagram.activityLine.x2))" y2="\(_tfmt(diagram.activityLine.y2))" stroke="var(--line, #666)" stroke-width="4" marker-end="url(#\(arrowheadId))"/>
    """)

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

// MARK: - SVG helpers

private func _tfmt(_ value: Double) -> String {
    let rounded = value.rounded()
    if rounded == value && rounded.isFinite {
        let intVal = Int(rounded)
        return String(intVal)
    }
    return String(format: "%.1f", value)
}

private func _tescapeXml(_ text: String) -> String {
    SVG.escapeAttribute(text)
}

private func _trenderTimelineLabel(
    _ text: String,
    x: Double,
    y: Double,
    width: Double,
    height: Double,
    fill: String,
    fontSize: Double,
    fontFamily: String,
    placement: String
) -> String {
    let lines = _twrappedTimelineLines(text, maxWidth: max(1, width - 8), fontSize: fontSize)
    let normalizedPlacement = placement.lowercased()
    if normalizedPlacement == "old" {
        let joined = lines.joined(separator: " ")
        return """
        <text x="\(_tfmt(x + width / 2))" y="\(_tfmt(y + height / 2))" text-anchor="middle" dominant-baseline="central" fill="\(_tescapeXml(fill))" font-size="\(_tfmt(fontSize))" font-family="\(_tescapeXml(fontFamily))">\(_tescapeXml(joined))</text>
        """
    }

    let fallback = _trenderTimelineTspans(
        lines,
        centerX: x + width / 2,
        centerY: y + height / 2,
        fill: fill,
        fontSize: fontSize,
        fontFamily: fontFamily
    )

    guard normalizedPlacement == "fo" else {
        return fallback
    }

    let html = lines.map(_tescapeXml).joined(separator: "<br/>")
    return """
    <switch>
    <foreignObject x="\(_tfmt(x))" y="\(_tfmt(y))" width="\(_tfmt(width))" height="\(_tfmt(height))" position="fixed"><div xmlns="http://www.w3.org/1999/xhtml" class="label" style="display:table;width:100%;height:100%;text-align:center;font-size:\(_tfmt(fontSize))px;font-family:\(_tescapeXml(fontFamily));color:\(_tescapeXml(fill))"><div style="display:table-cell;vertical-align:middle">\(html)</div></div></foreignObject>
    \(fallback)
    </switch>
    """
}

private func _trenderTimelineTspans(
    _ lines: [String],
    centerX: Double,
    centerY: Double,
    fill: String,
    fontSize: Double,
    fontFamily: String
) -> String {
    let lineHeight = max(1, fontSize * 1.2)
    let startY = centerY - (Double(lines.count - 1) * lineHeight / 2)
    let tspanText = lines.enumerated().map { index, line in
        "<tspan x=\"\(_tfmt(centerX))\" y=\"\(_tfmt(startY + Double(index) * lineHeight))\">\(_tescapeXml(line))</tspan>"
    }.joined()
    return """
    <text text-anchor="middle" dominant-baseline="central" fill="\(_tescapeXml(fill))" font-size="\(_tfmt(fontSize))" font-family="\(_tescapeXml(fontFamily))">\(tspanText)</text>
    """
}

private func _twrappedTimelineLines(_ text: String, maxWidth: Double, fontSize: Double) -> [String] {
    let normalized = original_src_multiline_utils.normalizeBrTags(text)
    let wrapped = normalized.components(separatedBy: "\n").flatMap {
        _twrapTimelineSingleLine($0, maxWidth: maxWidth, fontSize: fontSize)
    }
    return wrapped.isEmpty ? [""] : wrapped
}

private func _twrapTimelineSingleLine(_ line: String, maxWidth: Double, fontSize: Double) -> [String] {
    guard !line.isEmpty else { return [""] }
    if original_src_text_metrics.measureTextWidth(line, fontSize: fontSize, fontWeight: 400) <= maxWidth {
        return [line]
    }

    let words = line.split(separator: " ").map(String.init)
    guard !words.isEmpty else { return [line] }

    var lines: [String] = []
    var current = ""

    for word in words {
        let candidate = current.isEmpty ? word : "\(current) \(word)"
        let candidateWidth = original_src_text_metrics.measureTextWidth(candidate, fontSize: fontSize, fontWeight: 400)
        if candidateWidth <= maxWidth {
            current = candidate
        } else {
            if !current.isEmpty {
                lines.append(current)
            }
            current = word
        }
    }

    if !current.isEmpty {
        lines.append(current)
    }
    return lines.isEmpty ? [line] : lines
}
