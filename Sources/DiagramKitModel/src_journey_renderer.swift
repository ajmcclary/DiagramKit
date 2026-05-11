import Foundation
import DiagramKitCommon

public func renderJourneySvg(
    _ diagram: PositionedJourneyDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false,
    diagramId: String = "mermaid-0"
) throws -> String {
    try _renderJourneySvgEntry(diagram, colors, font, transparent, diagramId: diagramId)
}

private func _renderJourneySvgEntry(
    _ diagram: PositionedJourneyDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool,
    diagramId: String
) throws -> String {
    var parts: [String] = []

    let conf = diagram.config ?? .default

    let _builder = SVGDocumentBuilder(
        width: diagram.width, height: diagram.height,
        colors: colors, transparent: transparent,
        fontFamily: font,
        useMaxWidth: conf.useMaxWidth
    )
    parts.append(_builder.open(extraAttributes: "id=\"\(diagramId)\"") + ">")

    // Accessibility
    if let accTitle = diagram.accTitle, !accTitle.isEmpty {
        parts.append("<title>\(SVG.escapeText(accTitle))</title>")
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        parts.append("<desc>\(SVG.escapeText(accDescr))</desc>")
    }

    parts.append(original_src_theme.buildStyleBlock(font, true))

    // Journey-specific CSS classes (matching Mermaid styles.js)
    let journeyCSS = _journeyCSSBlock(conf: conf, colors: colors)
    if !journeyCSS.isEmpty {
        parts.append(journeyCSS)
    }

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
        let escapedName = SVG.escapeText(actor.name)

        parts.append("""
        <circle class="actor-\(actor.index)" cx="\(cx)" cy="\(cy)" r="7" fill="\(actor.color)" stroke="var(--line, #666)"><title>\(escapedName)</title></circle>
        """)
        for (lineIndex, line) in actor.lines.enumerated() {
            let lineY = _fmt(actor.labelOrigin.y + Double(lineIndex) * 20)
            let escapedLine = SVG.escapeText(line)
            parts.append("""
            <text class="legend" x="\(lx)" y="\(lineY)" fill="var(--fg, #666)" font-size="\(_fmt(conf.taskFontSize))">\(escapedLine)</text>
            """)
        }
    }
    parts.append("</g>")

    // Section rectangles
    for section in diagram.sections {
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
        let textPlacement = conf.textPlacement
        let rawLabel = section.name
        let escapedRawLabel = SVG.escapeText(rawLabel)
        let brLines = original_src_multiline_utils.normalizeBrTags(rawLabel).components(separatedBy: "\n")

        if textPlacement == "old" || textPlacement == "fo" {
            // old + fo: render raw text without <br> splitting (matching Mermaid svgDraw)
            if textPlacement == "fo" {
                let labelH = conf.taskFontSize * 1.5
                let foY = _fmt(section.y + (section.height - labelH) / 2)
                parts.append("""
                <switch><foreignObject x="\(sx)" y="\(foY)" width="\(sw)" height="\(_fmt(labelH))"><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml" style="display:table;width:100%;height:100%;text-align:center;color:\(section.colour);font-size:\(_fmt(conf.taskFontSize))px"><xhtml:span style="display:table-cell;vertical-align:middle">\(escapedRawLabel)</xhtml:span></xhtml:div></foreignObject><text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedRawLabel)</tspan></text></switch>
                """)
            } else {
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))">\(escapedRawLabel)</text>
                """)
            }
        } else {
            // tspan: split on <br> (Mermaid's byTspan behavior)
            if brLines.count == 1 {
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedRawLabel)</tspan></text>
                """)
            } else {
                let tspanLines = brLines.map { "<tspan x=\"\(textX)\">\(SVG.escapeText($0))</tspan>" }.joined(separator: "\n")
                parts.append("""
                <text x="\(textX)" y="\(textY)" text-anchor="middle" dominant-baseline="central" fill="\(section.colour)" font-size="\(_fmt(conf.taskFontSize))">\(tspanLines)</text>
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

        parts.append("""
        <g class="task task-type-\(task.num)">
        <rect x="\(tx)" y="\(ty)" width="\(trw)" height="\(trh)" fill="\(task.fill)" rx="3" ry="3"/>
        """)

        let taskRawLabel = task.task
        let escapedTaskLabel = SVG.escapeText(taskRawLabel)
        let taskBrLines = original_src_multiline_utils.normalizeBrTags(taskRawLabel).components(separatedBy: "\n")

        // Task label
        let taskTextX = _fmt(task.x + task.rectWidth / 2)
        let taskTextY = _fmt(task.y + task.rectHeight / 2)

        if conf.textPlacement == "old" || conf.textPlacement == "fo" {
            // old + fo: render raw text without <br> splitting
            if conf.textPlacement == "fo" {
                let labelH = conf.taskFontSize * 1.5
                let foY = _fmt(task.y + (task.rectHeight - labelH) / 2)
                parts.append("""
                <switch><foreignObject x="\(tx)" y="\(foY)" width="\(trw)" height="\(_fmt(labelH))"><xhtml:div xmlns:xhtml="http://www.w3.org/1999/xhtml" style="display:table;width:100%;height:100%;text-align:center;color:\(task.colour);font-size:\(_fmt(conf.taskFontSize))px"><xhtml:span style="display:table-cell;vertical-align:middle">\(escapedTaskLabel)</xhtml:span></xhtml:div></foreignObject><text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedTaskLabel)</tspan></text></switch>
                """)
            } else {
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))">\(escapedTaskLabel)</text>
                """)
            }
        } else {
            // tspan: split on <br>
            if taskBrLines.count == 1 {
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))"><tspan>\(escapedTaskLabel)</tspan></text>
                """)
            } else {
                let tspanLines = taskBrLines.map { "<tspan x=\"\(taskTextX)\">\(SVG.escapeText($0))</tspan>" }.joined(separator: "\n")
                parts.append("""
                <text x="\(taskTextX)" y="\(taskTextY)" text-anchor="middle" dominant-baseline="central" fill="\(task.colour)" font-size="\(_fmt(conf.taskFontSize))">\(tspanLines)</text>
                """)
            }
        }

        // Actor dots along top edge
        let dotCount = task.people.count
        if dotCount > 0 {
            let dotXs = _journeyActorDotXPositions(taskX: task.x, taskWidth: task.rectWidth, dotCount: dotCount)
            for (di, person) in task.people.enumerated() {
                if let actorIdx = diagram.actors.firstIndex(where: { $0.name == person }) {
                    let dotX = dotXs[di]
                    let actorColor = _journeySvgPaletteValue(conf.actorColours, index: actorIdx, fallback: "#8FBC8F")
                    let escapedPerson = SVG.escapeText(person)
                    parts.append("""
                    <circle class="actor-\(actorIdx)" cx="\(_fmt(dotX))" cy="\(ty)" r="7" fill="\(actorColor)"><title>\(escapedPerson)</title></circle>
                    """)
                }
            }
        }

        // Dashed vertical guide line
        let lineX = _fmt(task.x + task.rectWidth / 2)
        let lineY1 = _fmt(task.y + task.rectHeight)
        parts.append("""
        <line id="\(diagramId)-task\(task.taskIndex)" x1="\(lineX)" y1="\(lineY1)" x2="\(lineX)" y2="450" class="task-line" stroke="var(--line, #666)" stroke-dasharray="4 2" stroke-width="1"/>
        """)

        // Score face
        let faceCX = task.x + task.rectWidth / 2
        let faceCY = task.faceY
        let clampedScore = Swift.max(1, Swift.min(5, task.score))
        parts.append("""
        <g class="face">
        <circle cx="\(_fmt(faceCX))" cy="\(_fmt(faceCY))" r="15" class="face" fill="\(conf.faceColor)" stroke="var(--line, #999)" stroke-width="2"/>
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
        let escapedTitle = SVG.escapeText(title)
        let titleColor = conf.titleColor.isEmpty ? "var(--fg, #000)" : conf.titleColor
        parts.append("""
        <text x="\(_fmt(leftMargin))" y="25" font-size="\(conf.titleFontSize)" font-weight="bold" fill="\(titleColor)" font-family="\(conf.titleFontFamily)">\(escapedTitle)</text>
        """)
    }

    // Activity line
    let lineX1 = leftMargin
    let lineX2 = max(lineX1, diagram.width - 10)
    let lineY = diagram.activityLineY
    parts.append("""
    <line x1="\(_fmt(lineX1))" y1="\(_fmt(lineY))" x2="\(_fmt(lineX2))" y2="\(_fmt(lineY))" stroke="var(--line, #000)" stroke-width="4" marker-end="url(#\(diagramId)-arrowhead)"/>
    """)

    parts.append(_builder.close())

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

private func _journeyCSSBlock(conf: JourneyDiagramConfig, colors: DiagramColors) -> String {
    var rules: [String] = []

    rules.append("<style>")
    rules.append(".label { font-family: \(conf.taskFontFamily); color: var(--fg, #333); }")
    rules.append(".mouth { stroke: var(--fg, #666); }")
    rules.append("line { stroke: var(--fg, #666); }")
    rules.append(".legend { fill: var(--fg, #666); font-family: \(conf.taskFontFamily); }")
    rules.append(".face { fill: \(conf.faceColor); stroke: #999; }")
    rules.append(".arrowheadPath { fill: var(--line, #666); }")

    // Task and section type fills (0-7)
    for i in 0..<8 {
        let fillVar = "--fill-type-\(i): \(i < conf.sectionFills.count ? conf.sectionFills[i] : "#191970")"
        rules.append(".task-type-\(i), .section-type-\(i) { fill: var(\(fillVar)); }")
    }

    // Actor colors (0-5)
    for i in 0..<6 {
        let actorColor = i < conf.actorColours.count ? conf.actorColours[i] : "#8FBC8F"
        rules.append(".actor-\(i) { fill: \(actorColor); }")
    }

    rules.append("</style>")
    return rules.joined(separator: "\n")
}
