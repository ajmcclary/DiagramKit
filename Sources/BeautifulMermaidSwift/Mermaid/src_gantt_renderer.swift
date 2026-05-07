import Foundation

// MARK: - Theme Variables

public struct GanttThemeVariables: Sendable {
    public var sectionBkgColor: String = "rgba(102, 102, 255, 0.49)"
    public var altSectionBkgColor: String = "white"
    public var sectionBkgColor2: String = "#fff400"
    public var excludeBkgColor: String = "#eeeeee"
    public var taskBorderColor: String = "#534fbc"
    public var taskBkgColor: String = "#8a90dd"
    public var taskTextLightColor: String = "white"
    public var taskTextColor: String = "white"
    public var taskTextDarkColor: String = "black"
    public var taskTextOutsideColor: String = "black"
    public var taskTextClickableColor: String = "#003163"
    public var activeTaskBorderColor: String = "#534fbc"
    public var activeTaskBkgColor: String = "#bfc7ff"
    public var gridColor: String = "lightgrey"
    public var doneTaskBkgColor: String = "lightgrey"
    public var doneTaskBorderColor: String = "grey"
    public var critBorderColor: String = "#ff8888"
    public var critBkgColor: String = "red"
    public var todayLineColor: String = "red"
    public var vertLineColor: String = "navy"

    public static let `default` = GanttThemeVariables()
}

// MARK: - Entry Point

public func renderGanttSvg(
    _ positioned: PositionedGanttDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    let theme = GanttThemeVariables.default
    let w = positioned.width
    let h = positioned.height
    let config = positioned.config

    var svg = ""
    svg += #"<svg id="\#(diagramId)" class="mermaid" width="100%" height="100%" viewBox="0 0 \#(Int(w)) \#(Int(h))" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">"#
    svg += "\n"

    // CSS styles
    svg += "<style>\n"
    svg += ".mermaid-main-font { font-family: \(font); }\n"
    svg += ".exclude-range { fill: \(theme.excludeBkgColor); }\n"
    svg += ".section { stroke: none; opacity: 0.2; }\n"
    svg += ".section0 { fill: \(theme.sectionBkgColor); }\n"
    svg += ".section1, .section3 { fill: \(theme.altSectionBkgColor); opacity: 0.2; }\n"
    svg += ".section2 { fill: \(theme.sectionBkgColor2); }\n"
    svg += ".task { stroke-width: 2; stroke: \(theme.taskBorderColor); fill: \(theme.taskBkgColor); }\n"
    svg += ".task0, .task1, .task2, .task3 { stroke: \(theme.taskBorderColor); fill: \(theme.taskBkgColor); }\n"
    svg += ".active0, .active1, .active2, .active3 { stroke: \(theme.activeTaskBorderColor); fill: \(theme.activeTaskBkgColor); }\n"
    svg += ".done0, .done1, .done2, .done3 { stroke: \(theme.doneTaskBorderColor); fill: \(theme.doneTaskBkgColor); }\n"
    svg += ".crit0, .crit1, .crit2, .crit3 { stroke: \(theme.critBorderColor); fill: \(theme.critBkgColor); }\n"
    svg += ".activeCrit0, .activeCrit1, .activeCrit2, .activeCrit3 { stroke: \(theme.critBorderColor); fill: \(theme.activeTaskBkgColor); }\n"
    svg += ".doneCrit0, .doneCrit1, .doneCrit2, .doneCrit3 { stroke: \(theme.critBorderColor); fill: \(theme.doneTaskBkgColor); }\n"
    svg += ".task.milestone { transform: rotate(45deg); }\n"
    svg += ".task.vert { stroke: \(theme.vertLineColor); fill: \(theme.vertLineColor); }\n"
    svg += ".taskText { fill: \(theme.taskTextColor); text-anchor: middle; font-size: \(config.fontSize)px; }\n"
    svg += ".taskTextOutsideLeft { fill: \(theme.taskTextOutsideColor); text-anchor: end; font-size: \(config.fontSize)px; }\n"
    svg += ".taskTextOutsideRight { fill: \(theme.taskTextOutsideColor); text-anchor: start; font-size: \(config.fontSize)px; }\n"
    svg += ".taskText0, .taskText1, .taskText2, .taskText3 { fill: \(theme.taskTextColor); }\n"
    svg += ".taskTextOutside0, .taskTextOutside1, .taskTextOutside2, .taskTextOutside3 { fill: \(theme.taskTextOutsideColor); }\n"
    svg += ".activeText0, .activeText1, .activeText2, .activeText3, .doneText0, .doneText1, .doneText2, .doneText3, .activeCritText0, .activeCritText1, .activeCritText2, .activeCritText3, .doneCritText0, .doneCritText1, .doneCritText2, .doneCritText3 { fill: \(theme.taskTextDarkColor) !important; }\n"
    svg += ".milestoneText { font-style: italic; }\n"
    svg += ".vertText { font-size: 15px; text-anchor: middle; fill: \(theme.vertLineColor) !important; }\n"
    svg += ".task.clickable { cursor: pointer; }\n"
    svg += ".taskText.clickable, .taskTextOutsideLeft.clickable, .taskTextOutsideRight.clickable { cursor: pointer; fill: \(theme.taskTextClickableColor) !important; font-weight: bold; }\n"
    svg += ".grid line { stroke: \(theme.gridColor); stroke-dasharray: 4, 2; }\n"
    svg += ".grid .tick text { font-size: 10px; }\n"
    svg += ".sectionTitle { font-size: \(config.sectionFontSize)px; fill: black; font-weight: bold; }\n"
    svg += ".titleText { text-anchor: middle; font-size: 18px; fill: \(colors.fg); }\n"
    svg += ".today { stroke: \(theme.todayLineColor); }\n"
    svg += "</style>\n"

    // Accessibility
    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "<title>\(_escapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "<desc>\(_escapeXml(accDescr))</desc>\n"
    }

    // 1. Excluded ranges
    for range in positioned.excludedRanges {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withFullDate]
        let dateStr = isoFmt.string(from: range.start)
        svg += #"<rect id="\#(diagramId)-exclude-\#(dateStr)" class="exclude-range" x="\#(range.backgroundRect.origin.x)" y="\#(range.backgroundRect.origin.y)" width="\#(range.backgroundRect.width)" height="\#(range.backgroundRect.height)"/>"#
        svg += "\n"
    }

    // 2. Grid / axis
    let gridY = h - config.gridLineStartPadding
    let gridLineHeight = positioned.gridLineHeight > 0 ? positioned.gridLineHeight : config.gridLineStartPadding
    svg += "<g class=\"grid\" transform=\"translate(\(config.leftPadding), \(gridY))\">\n"
    for tick in positioned.axisTicks {
        let relX = tick.x - config.leftPadding
        svg += "<line x1=\"\(relX)\" x2=\"\(relX)\" y1=\"0\" y2=\"\(gridLineHeight)\"/>\n"
        svg += "<text x=\"\(relX)\" y=\"15\" dy=\"1em\" text-anchor=\"middle\" fill=\"#000\" stroke=\"none\" font-size=\"10\">\(_escapeXml(tick.label))</text>\n"
    }
    svg += "</g>\n"

    // Top axis
    if let topTicks = positioned.topAxisTicks, !topTicks.isEmpty {
        let topGridLineHeight = gridLineHeight - config.topPadding + config.gridLineStartPadding
        svg += "<g class=\"grid top-grid\" transform=\"translate(\(config.leftPadding), \(config.topPadding))\">\n"
        for tick in topTicks {
            let relX = tick.x - config.leftPadding
            svg += "<line x1=\"\(relX)\" x2=\"\(relX)\" y1=\"0\" y2=\"\(topGridLineHeight)\"/>\n"
            svg += "<text x=\"\(relX)\" y=\"15\" dy=\"1em\" text-anchor=\"middle\" fill=\"#000\" stroke=\"none\" font-size=\"10\">\(_escapeXml(tick.label))</text>\n"
        }
        svg += "</g>\n"
    }

    // 3. Section backgrounds
    for section in positioned.sections {
        let cls = "section section\(section.styleIndex)"
        svg += #"<rect class="\#(cls)" x="\#(section.backgroundRect.origin.x)" y="\#(section.backgroundRect.origin.y)" width="\#(section.backgroundRect.width)" height="\#(section.backgroundRect.height)"/>"#
        svg += "\n"
    }

    // 4. Task bars
    for ptask in positioned.tasks {
        let rect = ptask.barRect
        let isMilestone = ptask.task.tags.contains(.milestone)
        let interactionAttrs = _interactionAttributes(for: ptask.task)

        let rectMarkup: String
        if isMilestone {
            let cx = rect.midX
            let cy = rect.midY
            rectMarkup = #"<rect id="\#(diagramId)-\#(ptask.task.id)" class="\#(ptask.svgClass)" x="\#(rect.origin.x)" y="\#(rect.origin.y)" width="\#(rect.width)" height="\#(rect.height)" transform="rotate(45, \#(cx), \#(cy)) scale(0.8, 0.8)"\#(interactionAttrs)/>"#
        } else {
            rectMarkup = #"<rect id="\#(diagramId)-\#(ptask.task.id)" class="\#(ptask.svgClass)" x="\#(rect.origin.x)" y="\#(rect.origin.y)" width="\#(rect.width)" height="\#(rect.height)" rx="3" ry="3"\#(interactionAttrs)/>"#
        }

        // 5. Task labels
        let textMarkup = #"<text id="\#(diagramId)-\#(ptask.task.id)-text" class="\#(ptask.labelClass)" x="\#(ptask.labelPoint.x)" y="\#(ptask.labelPoint.y)"\#(interactionAttrs)>\#(_escapeXml(ptask.task.task))</text>"#

        let taskMarkup = rectMarkup + "\n" + textMarkup + "\n"
        if let link = ptask.task.link {
            svg += #"<a xlink:href="\#(_escapeXml(link))" target="_self">"#
            svg += "\n"
            svg += taskMarkup
            svg += "</a>\n"
        } else {
            svg += taskMarkup
        }
    }

    // 6. Section labels
    for section in positioned.sections {
        let cls = "sectionTitle sectionTitle\(section.styleIndex)"
        let lines = original_src_multiline_utils.normalizeBrTags(section.name).components(separatedBy: "\n")
        let lineHeight = config.sectionFontSize * 1.3
        let totalHeight = Double(lines.count) * lineHeight
        let startY = section.labelPoint.y - totalHeight / 2 + config.sectionFontSize

        for (li, line) in lines.enumerated() {
            let y = startY + Double(li) * lineHeight
            svg += #"<text class="\#(cls)" x="\#(section.labelPoint.x)" y="\#(y)">\#(_escapeXml(line))</text>"#
            svg += "\n"
        }
    }

    // 7. Today marker
    if let todayX = positioned.todayLineX {
        let style = positioned.todayMarkerStyle ?? ""
        svg += #"<g class="today">"#
        svg += "\n"
        svg += #"<line class="today" x1="\#(todayX)" x2="\#(todayX)" y1="\#(config.titleTopMargin)" y2="\#(h - config.titleTopMargin)" style="\#(_escapeXml(style))"/>"#
        svg += "\n"
        svg += "</g>\n"
    }

    // 8. Title
    if let title = positioned.title, !title.isEmpty {
        svg += #"<text class="titleText" x="\#(w / 2)" y="\#(config.titleTopMargin)">\#(_escapeXml(title))</text>"#
        svg += "\n"
    }

    svg += "</svg>"
    return svg
}

// MARK: - Helpers

private func _escapeXml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private func _interactionAttributes(for task: GanttTask) -> String {
    var attrs: [String] = []
    if let callbackName = task.callbackName, !callbackName.isEmpty {
        attrs.append(#"data-callback="\#(_escapeXml(callbackName))""#)
    }
    if let callbackArgs = task.callbackArgs, !callbackArgs.isEmpty {
        attrs.append(#"data-callback-args="\#(_escapeXml(callbackArgs.joined(separator: ",")))""#)
    }
    return attrs.isEmpty ? "" : " " + attrs.joined(separator: " ")
}
