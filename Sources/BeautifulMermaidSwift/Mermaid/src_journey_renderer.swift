import Foundation

public func renderJourneySvg(
    _ diagram: PositionedJourneyDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderJourneySvgEntry(diagram, colors, font, transparent)
}

private func _renderJourneySvgEntry(
    _ diagram: PositionedJourneyDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []

    let conf = diagram.config ?? .default
    let diagramId = "mermaid-0"

    let widthStr = _formatNum(diagram.width)
    let heightStr = _formatNum(diagram.height)

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
        parts.append("<title>\(original_src_multiline_utils.escapeXml(accTitle))</title>")
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        parts.append("<desc>\(original_src_multiline_utils.escapeXml(accDescr))</desc>")
    }

    parts.append(original_src_theme.buildStyleBlock(font, true))

    // Arrowhead marker definition
    parts.append("<defs>")
    parts.append("<marker id=\"\(diagramId)-arrowhead\" refX=\"5\" refY=\"2\" markerWidth=\"6\" markerHeight=\"4\" orient=\"auto\">")
    parts.append("<path d=\"M 0,0 V 4 L6,2 Z\" class=\"arrowheadPath\" fill=\"var(--line, #666)\"/>")
    parts.append("</marker>")
    parts.append("</defs>")

    let leftMargin = diagram.effectiveLeftMargin

    // Actor legend
    parts.append("<g class=\"legend\">")
    for actor in diagram.actors {
        let cx = _fmt(actor.circleCenter.x)
        let cy = _fmt(actor.circleCenter.y)
        let lx = _fmt(actor.labelOrigin.x)
        let escapedName = original_src_multiline_utils.escapeXml(actor.name)

        parts.append("""
        <circle class="actor-\(actor.index)" cx="\(cx)" cy="\(cy)" r="7" fill="\(actor.color)" stroke="var(--line, #666)"><title>\(escapedName)</title></circle>
        """)
        for (lineIndex, line) in actor.lines.enumerated() {
            let lineY = _fmt(actor.labelOrigin.y + Double(lineIndex) * 20)
            let escapedLine = original_src_multiline_utils.escapeXml(line)
            parts.append("""
            <text class="legend" x="\(lx)" y="\(lineY)" fill="var(--fg, #666)" font-size="\(_fmt(conf.taskFontSize))">\(escapedLine)</text>
            """)
        }
    }
    parts.append("</g>")

    // Section rectangles
    for section in diagram.sections {
        let escapedLabel = original_src_multiline_utils.escapeXml(section.name)
        let sx = _fmt(section.x)
        let sy = _fmt(section.y)
        let sw = _fmt(section.width)
        let sh = _fmt(section.height)

        parts.append("""
        <g class="journey-section section-type-\(section.num)">
        <rect x="\(sx)" y="\(sy)" width="\(sw)" height="\(sh)" fill="\(section.fill)" rx="3" ry="3"/>
        """)

        // Section label
        let textX = _fmt(section.x + section.width / 2)
        let textY = _fmt(section.y + section.height / 2)
        let labelLines = original_src_multiline_utils.normalizeBrTags(section.name).components(separatedBy: "\n")
        let textPlacement = conf.textPlacement

        if labelLines.count == 1 {
            switch textPlacement {
            case "old":
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))">\(escapedLabel)</text>
                """)
            case "tspan":
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedLabel)</tspan></text>
                """)
            default: // "fo"
                let labelH = conf.taskFontSize * 1.5
                let foY = _fmt(section.y + (section.height - labelH) / 2)
                parts.append("""
                <switch><foreignObject x="\(sx)" y="\(foY)" width="\(sw)" height="\(_fmt(labelH))"><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml" style="display:table;width:100%;height:100%;text-align:center;color:\(section.colour);font-size:\(_fmt(conf.taskFontSize))px"><xhtml:span style="display:table-cell;vertical-align:middle">\(escapedLabel)</xhtml:span></xhtml:div></foreignObject><text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedLabel)</tspan></text></switch>
                """)
            }
        } else {
            switch textPlacement {
            case "old":
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))">\(escapedLabel)</text>
                """)
            case "tspan":
                let tspanLines = labelLines.map { "<tspan x=\"\(textX)\">\(original_src_multiline_utils.escapeXml($0))</tspan>" }.joined(separator: "\n")
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))">\(tspanLines)</text>
                """)
            default:
                let labelH = conf.taskFontSize * 1.5 * Double(labelLines.count)
                let foY = _fmt(section.y + (section.height - labelH) / 2)
                let divContent = labelLines.map { "<xhtml:div>\(original_src_multiline_utils.escapeXml($0))</xhtml:div>" }.joined()
                parts.append("""
                <switch><foreignObject x="\(sx)" y="\(foY)" width="\(sw)" height="\(_fmt(labelH))"><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml" style="display:table;width:100%;height:100%;text-align:center;color:\(section.colour);font-size:\(_fmt(conf.taskFontSize))px"><xhtml:span style="display:table-cell;vertical-align:middle">\(divContent)</xhtml:span></xhtml:div></foreignObject><text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedLabel)</tspan></text></switch>
                """)
            }
        }

        parts.append("</g>")
    }

    // Tasks
    for task in diagram.tasks {
        let tx = _fmt(task.x)
        let ty = _fmt(task.y)
        let trw = _fmt(task.rectWidth)
        let trh = _fmt(task.rectHeight)
        let escapedLabel = original_src_multiline_utils.escapeXml(task.task)

        parts.append("""
        <g class="task task-type-\(task.num)">
        <rect x="\(tx)" y="\(ty)" width="\(trw)" height="\(trh)" fill="\(task.fill)" rx="3" ry="3"/>
        """)

        // Task label
        let taskTextX = _fmt(task.x + task.rectWidth / 2)
        let taskTextY = _fmt(task.y + task.rectHeight / 2)
        let taskLabelLines = original_src_multiline_utils.normalizeBrTags(task.task).components(separatedBy: "\n")

        if taskLabelLines.count == 1 {
            switch conf.textPlacement {
            case "old":
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))">\(escapedLabel)</text>
                """)
            case "tspan":
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedLabel)</tspan></text>
                """)
            default:
                let labelH = conf.taskFontSize * 1.5
                let foY = _fmt(task.y + (task.rectHeight - labelH) / 2)
                parts.append("""
                <switch><foreignObject x="\(tx)" y="\(foY)" width="\(trw)" height="\(_fmt(labelH))"><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml" style="display:table;width:100%;height:100%;text-align:center;color:\(task.colour);font-size:\(_fmt(conf.taskFontSize))px"><xhtml:span style="display:table-cell;vertical-align:middle">\(escapedLabel)</xhtml:span></xhtml:div></foreignObject><text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedLabel)</tspan></text></switch>
                """)
            }
        } else {
            switch conf.textPlacement {
            case "old":
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))">\(escapedLabel)</text>
                """)
            case "tspan":
                let tspanLines = taskLabelLines.map { "<tspan x=\"\(taskTextX)\">\(original_src_multiline_utils.escapeXml($0))</tspan>" }.joined(separator: "\n")
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))">\(tspanLines)</text>
                """)
            default:
                let labelH = conf.taskFontSize * 1.5 * Double(taskLabelLines.count)
                let foY = _fmt(task.y + (task.rectHeight - labelH) / 2)
                let divContent = taskLabelLines.map { "<xhtml:div>\(original_src_multiline_utils.escapeXml($0))</xhtml:div>" }.joined()
                parts.append("""
                <switch><foreignObject x="\(tx)" y="\(foY)" width="\(trw)" height="\(_fmt(labelH))"><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml" style="display:table;width:100%;height:100%;text-align:center;color:\(task.colour);font-size:\(_fmt(conf.taskFontSize))px"><xhtml:span style="display:table-cell;vertical-align:middle">\(divContent)</xhtml:span></xhtml:div></foreignObject><text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedLabel)</tspan></text></switch>
                """)
            }
        }

        // Actor dots along top edge
        let dotCount = task.people.count
        if dotCount > 0 {
            let spacing: Double = Swift.min(10, task.rectWidth / Double(dotCount + 1))
            let startX = task.x + spacing
            for (di, person) in task.people.enumerated() {
                if let actorIdx = diagram.actors.firstIndex(where: { $0.name == person }) {
                    let dotX = startX + Double(di) * spacing
                    let actorColor = _journeySvgPaletteValue(conf.actorColours, index: actorIdx, fallback: "#8FBC8F")
                    let escapedPerson = original_src_multiline_utils.escapeXml(person)
                    parts.append("""
                    <circle class="actor-\(actorIdx)" cx="\(_fmt(dotX))" cy="\(ty)" r="5" fill="\(actorColor)"><title>\(escapedPerson)</title></circle>
                    """)
                }
            }
        }

        // Dashed vertical guide line
        let lineX = _fmt(task.x + task.rectWidth / 2)
        parts.append("""
        <line id="\(diagramId)-task\(task.taskIndex)" x1="\(lineX)" y1="\(ty)" x2="\(lineX)" y2="450" class="task-line" stroke="var(--line, #666)" stroke-dasharray="4 2" stroke-width="1"/>
        """)

        // Score face
        let faceCX = task.x + task.rectWidth / 2
        let faceCY = task.faceY
        let clampedScore = Swift.max(1, Swift.min(5, task.score))
        parts.append("""
        <g class="face">
        <circle cx="\(_fmt(faceCX))" cy="\(_fmt(faceCY))" r="15" class="face" fill="#FFF8DC" stroke="var(--line, #999)" stroke-width="2"/>
        <circle cx="\(_fmt(faceCX - 5))" cy="\(_fmt(faceCY - 5))" r="1.5" fill="var(--fg, #666)" stroke="var(--fg, #666)" stroke-width="2"/>
        <circle cx="\(_fmt(faceCX + 5))" cy="\(_fmt(faceCY - 5))" r="1.5" fill="var(--fg, #666)" stroke="var(--fg, #666)" stroke-width="2"/>
        """)
        if clampedScore > 3 {
            parts.append("""
            <path class="mouth" d="M \(_fmt(faceCX - 7.5)) \(_fmt(faceCY + 2)) A 7.15 6.82 0 0 0 \(_fmt(faceCX + 7.5)) \(_fmt(faceCY + 2))" fill="none" stroke="var(--fg, #666)" stroke-width="2"/>
            """)
        } else if clampedScore < 3 {
            parts.append("""
            <path class="mouth" d="M \(_fmt(faceCX - 7.5)) \(_fmt(faceCY + 7)) A 7.15 6.82 0 0 1 \(_fmt(faceCX + 7.5)) \(_fmt(faceCY + 7))" fill="none" stroke="var(--fg, #666)" stroke-width="2"/>
            """)
        } else {
            parts.append("""
            <line x1="\(_fmt(faceCX - 5))" y1="\(_fmt(faceCY + 7))" x2="\(_fmt(faceCX + 5))" y2="\(_fmt(faceCY + 7))" class="mouth" stroke="var(--fg, #666)" stroke-width="1"/>
            """)
        }
        parts.append("</g>")
        parts.append("</g>")
    }

    // Title
    if let title = diagram.title, !title.isEmpty {
        let escapedTitle = original_src_multiline_utils.escapeXml(title)
        let titleColor = conf.titleColor.isEmpty ? "var(--fg, #000)" : conf.titleColor
        parts.append("""
        <text x="\(_fmt(leftMargin))" y="25" font-size="\(conf.titleFontSize)" font-weight="bold" fill="\(titleColor)" font-family="\(conf.titleFontFamily)">\(escapedTitle)</text>
        """)
    }

    // Activity line
    let lineX1 = leftMargin
    let lineX2 = diagram.width - 4
    let lineY = diagram.activityLineY
    parts.append("""
    <line x1="\(_fmt(lineX1))" y1="\(_fmt(lineY))" x2="\(_fmt(lineX2))" y2="\(_fmt(lineY))" stroke="var(--line, #000)" stroke-width="2" marker-end="url(#\(diagramId)-arrowhead)"/>
    """)

    parts.append("</svg>")

    return parts.joined(separator: "\n")
}

// MARK: - Helpers

private func _fmt(_ value: Double) -> String {
    let rounded = value.rounded()
    if rounded == value && rounded.isFinite {
        let intVal = Int(rounded)
        return String(intVal)
    }
    return String(format: "%.1f", value)
}

private func _formatNum(_ value: Double) -> String {
    _fmt(value)
}

private func _journeySvgPaletteValue(_ palette: [String], index: Int, fallback: String) -> String {
    guard !palette.isEmpty else { return fallback }
    return palette[index % palette.count]
}
