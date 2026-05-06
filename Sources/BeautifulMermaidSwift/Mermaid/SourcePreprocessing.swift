import Foundation

/// Result of preprocessing: the stripped diagram source and any parsed frontmatter.
typealias _PreprocessResult = (source: String, frontmatter: DiagramFrontmatter?)

func _preprocessMermaidSource(_ source: String) -> _PreprocessResult {
    _parseFrontMatterAndStripped(source)
}

func _mermaidSourceLines(
    from source: String,
    separatedBy separators: CharacterSet = CharacterSet(charactersIn: "\n;")
) -> [String] {
    let processed = _preprocessMermaidSource(source)
    let joined = _joinMultiLineBlocks(processed.source)
    return _splitMermaidStatements(joined, separatedBy: separators)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("%%") }
}

private func _splitMermaidStatements(_ source: String, separatedBy separators: CharacterSet) -> [String] {
    var parts: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in source {
        if inQuote {
            current.append(ch)
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }

        if _isMermaidStatementSeparator(ch, separators) {
            parts.append(current)
            current = ""
        } else {
            current.append(ch)
        }
    }

    parts.append(current)
    return parts
}

private func _isMermaidStatementSeparator(_ ch: Character, _ separators: CharacterSet) -> Bool {
    guard ch.unicodeScalars.count == 1, let scalar = ch.unicodeScalars.first else {
        return false
    }
    return separators.contains(scalar)
}

/// Parse YAML-like frontmatter from a source string.
/// Returns the stripped diagram source and any parsed DiagramFrontmatter.
func _parseFrontMatterAndStripped(_ source: String) -> _PreprocessResult {
    let normalized = source
        .replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

    guard let startIdx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
          lines[startIdx].trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    else {
        return (source, nil)
    }

    guard let endIdx = lines[(startIdx + 1)...].firstIndex(where: {
        $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
    }) else {
        return (source, nil)
    }

    let fmLines = Array(lines[(startIdx + 1)..<endIdx])
    let stripped = lines[(endIdx + 1)...].joined(separator: "\n")
    let frontmatter = _parseYamlFrontmatter(fmLines)
    return (stripped, frontmatter)
}

/// Extended YAML parser for Mermaid frontmatter.
/// Handles: title, class.*, config.class.*, config.flowchart.*, config.er.*, config.layout, config.look, config.htmlLabels
private func _parseYamlFrontmatter(_ lines: [String]) -> DiagramFrontmatter? {
    var frontmatter = DiagramFrontmatter()
    var flowchartConfig = original_src_types.FlowchartConfig()
    var hasFlowchartSection = false
    var classConfig = ClassConfig()
    var hasClassSection = false
    var erConfig = ErDiagramConfig()
    var hasErSection = false
    var hasAnyContent = false

    var xyChartConfig = XYChartConfig()
    var xyChartTheme = XYChartThemeConfig()
    var hasXYChartConfig = false
    var hasXYChartTheme = false

    var pieConfig = PieChartConfig()
    var pieTheme = PieChartThemeConfig()
    var hasPieConfig = false
    var hasPieTheme = false

    var sequenceConfig = SequenceDiagramConfig()
    var hasSequenceSection = false

    var stateConfig = original_src_types.StateConfig()
    var hasStateSection = false

    var journeyConfig = JourneyDiagramConfig()
    var hasJourneySection = false

    var ganttConfig = GanttDiagramConfig()
    var hasGanttSection = false

    var quadrantChartConfig = QuadrantChartConfig()
    var quadrantChartTheme = QuadrantChartThemeConfig()
    var hasQuadrantChartConfig = false
    var hasQuadrantChartTheme = false

    var requirementConfig = RequirementDiagramConfig()
    var hasRequirementSection = false

    var gitGraphConfig = GitGraphConfig()
    var gitGraphTheme = GitGraphThemeConfig()
    var hasGitGraphSection = false
    var hasGitGraphTheme = false

    var mindmapConfig = MindmapConfig()
    var hasMindmapSection = false

    var timelineConfig = TimelineDiagramConfig()
    var timelineTheme = TimelineThemeConfig.default
    var hasTimelineSection = false
    var hasTimelineTheme = false

    var pathStack: [(depth: Int, key: String)] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        let indent = line.prefix(while: { $0 == " " }).count
        let bare = trimmed

        let commentStripped = _stripYamlComment(bare)

        guard let colonIdx = commentStripped.firstIndex(of: ":") else { continue }
        let key = String(commentStripped[..<colonIdx]).trimmingCharacters(in: .whitespaces)
        let rawValue = String(commentStripped[commentStripped.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
        let value = _unquote(rawValue)

        let depth = indent / 2
        while let last = pathStack.last, last.depth >= depth {
            pathStack.removeLast()
        }
        pathStack.append((depth: depth, key: key))

        let fullPath = pathStack.map(\.key).joined(separator: ".")

        hasAnyContent = true

        if fullPath == "title" && !value.isEmpty {
            frontmatter.title = value
            frontmatter.diagramTitle = value
            continue
        }

        // class.* config
        if fullPath.hasPrefix("class.") {
            hasClassSection = true
            let subKey = fullPath.replacingOccurrences(of: "class.", with: "")
            switch subKey {
            case "hideEmptyMembersBox":
                classConfig.hideEmptyMembersBox = (value.lowercased() == "true")
            case "hierarchicalNamespaces":
                classConfig.hierarchicalNamespaces = (value.lowercased() == "true")
            case "padding":
                classConfig.padding = Double(value)
            default: break
            }
            continue
        }

        if fullPath.hasPrefix("config.class.") {
            hasClassSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.class.", with: "")
            switch subKey {
            case "hideEmptyMembersBox":
                classConfig.hideEmptyMembersBox = (value.lowercased() == "true")
            case "hierarchicalNamespaces":
                classConfig.hierarchicalNamespaces = (value.lowercased() == "true")
            case "padding":
                classConfig.padding = Double(value)
            default: break
            }
            continue
        }

        // flowchart config
        if fullPath.hasPrefix("config.flowchart.") || (fullPath == "flowchart" && value.isEmpty) {
            hasFlowchartSection = true
            if !value.isEmpty {
                let subKey = fullPath.replacingOccurrences(of: "config.flowchart.", with: "")
                switch subKey {
                case "curve": flowchartConfig.curve = value
                case "htmlLabels": flowchartConfig.htmlLabels = (value.lowercased() == "true")
                case "markdownAutoWrap": flowchartConfig.markdownAutoWrap = (value.lowercased() == "true")
                case "width": flowchartConfig.width = Int(value)
                case "inheritDir": flowchartConfig.inheritDir = (value.lowercased() == "true")
                default: break
                }
            }
            continue
        } else if fullPath == "flowchart" && !value.isEmpty {
            hasFlowchartSection = true
            flowchartConfig.curve = value.isEmpty ? nil : value
        }

        // ER config — config.er.*
        if fullPath.hasPrefix("config.er.") {
            hasErSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.er.", with: "")
            switch subKey {
            case "titleTopMargin": erConfig.titleTopMargin = Double(value)
            case "diagramPadding": erConfig.diagramPadding = Double(value)
            case "layoutDirection":
                erConfig.layoutDirection = ErDirection(rawValue: value.uppercased())
            case "minEntityWidth": erConfig.minEntityWidth = Double(value)
            case "minEntityHeight": erConfig.minEntityHeight = Double(value)
            case "entityPadding": erConfig.entityPadding = Double(value)
            case "nodeSpacing": erConfig.nodeSpacing = Double(value)
            case "rankSpacing": erConfig.rankSpacing = Double(value)
            case "stroke": erConfig.stroke = value
            case "fill": erConfig.fill = value
            case "fontSize": erConfig.fontSize = Double(value)
            case "useMaxWidth": erConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            continue
        }

        // XY Chart config — config.xyChart.*
        if fullPath.hasPrefix("config.xyChart.") {
            hasXYChartConfig = true
            let subKey = fullPath.replacingOccurrences(of: "config.xyChart.", with: "")
            switch subKey {
            case "width": xyChartConfig.width = Double(value) ?? xyChartConfig.width
            case "height": xyChartConfig.height = Double(value) ?? xyChartConfig.height
            case "titleFontSize": xyChartConfig.titleFontSize = Double(value) ?? xyChartConfig.titleFontSize
            case "titlePadding": xyChartConfig.titlePadding = Double(value) ?? xyChartConfig.titlePadding
            case "showTitle": xyChartConfig.showTitle = (value.lowercased() == "true")
            case "showDataLabel": xyChartConfig.showDataLabel = (value.lowercased() == "true")
            case "showDataLabelOutsideBar": xyChartConfig.showDataLabelOutsideBar = (value.lowercased() == "true")
            case "chartOrientation": xyChartConfig.chartOrientation = value
            case "plotReservedSpacePercent": xyChartConfig.plotReservedSpacePercent = Double(value) ?? xyChartConfig.plotReservedSpacePercent
            case let s where s.hasPrefix("xAxis."):
                let axisKey = s.replacingOccurrences(of: "xAxis.", with: "")
                switch axisKey {
                case "showLabel": xyChartConfig.xAxis.showLabel = (value.lowercased() == "true")
                case "labelFontSize": xyChartConfig.xAxis.labelFontSize = Double(value) ?? xyChartConfig.xAxis.labelFontSize
                case "labelPadding": xyChartConfig.xAxis.labelPadding = Double(value) ?? xyChartConfig.xAxis.labelPadding
                case "showTitle": xyChartConfig.xAxis.showTitle = (value.lowercased() == "true")
                case "titleFontSize": xyChartConfig.xAxis.titleFontSize = Double(value) ?? xyChartConfig.xAxis.titleFontSize
                case "titlePadding": xyChartConfig.xAxis.titlePadding = Double(value) ?? xyChartConfig.xAxis.titlePadding
                case "showTick": xyChartConfig.xAxis.showTick = (value.lowercased() == "true")
                case "tickLength": xyChartConfig.xAxis.tickLength = Double(value) ?? xyChartConfig.xAxis.tickLength
                case "tickWidth": xyChartConfig.xAxis.tickWidth = Double(value) ?? xyChartConfig.xAxis.tickWidth
                case "showAxisLine": xyChartConfig.xAxis.showAxisLine = (value.lowercased() == "true")
                case "axisLineWidth": xyChartConfig.xAxis.axisLineWidth = Double(value) ?? xyChartConfig.xAxis.axisLineWidth
                default: break
                }
            case let s where s.hasPrefix("yAxis."):
                let axisKey = s.replacingOccurrences(of: "yAxis.", with: "")
                switch axisKey {
                case "showLabel": xyChartConfig.yAxis.showLabel = (value.lowercased() == "true")
                case "labelFontSize": xyChartConfig.yAxis.labelFontSize = Double(value) ?? xyChartConfig.yAxis.labelFontSize
                case "labelPadding": xyChartConfig.yAxis.labelPadding = Double(value) ?? xyChartConfig.yAxis.labelPadding
                case "showTitle": xyChartConfig.yAxis.showTitle = (value.lowercased() == "true")
                case "titleFontSize": xyChartConfig.yAxis.titleFontSize = Double(value) ?? xyChartConfig.yAxis.titleFontSize
                case "titlePadding": xyChartConfig.yAxis.titlePadding = Double(value) ?? xyChartConfig.yAxis.titlePadding
                case "showTick": xyChartConfig.yAxis.showTick = (value.lowercased() == "true")
                case "tickLength": xyChartConfig.yAxis.tickLength = Double(value) ?? xyChartConfig.yAxis.tickLength
                case "tickWidth": xyChartConfig.yAxis.tickWidth = Double(value) ?? xyChartConfig.yAxis.tickWidth
                case "showAxisLine": xyChartConfig.yAxis.showAxisLine = (value.lowercased() == "true")
                case "axisLineWidth": xyChartConfig.yAxis.axisLineWidth = Double(value) ?? xyChartConfig.yAxis.axisLineWidth
                default: break
                }
            default: break
            }
            continue
        }

        // XY Chart theme — config.themeVariables.xyChart.*
        if fullPath.hasPrefix("config.themeVariables.xyChart.") {
            hasXYChartTheme = true
            let subKey = fullPath.replacingOccurrences(of: "config.themeVariables.xyChart.", with: "")
            switch subKey {
            case "backgroundColor": xyChartTheme.backgroundColor = value
            case "titleColor": xyChartTheme.titleColor = value
            case "dataLabelColor": xyChartTheme.dataLabelColor = value
            case "xAxisLabelColor": xyChartTheme.xAxisLabelColor = value
            case "xAxisTitleColor": xyChartTheme.xAxisTitleColor = value
            case "xAxisTickColor": xyChartTheme.xAxisTickColor = value
            case "xAxisLineColor": xyChartTheme.xAxisLineColor = value
            case "yAxisLabelColor": xyChartTheme.yAxisLabelColor = value
            case "yAxisTitleColor": xyChartTheme.yAxisTitleColor = value
            case "yAxisTickColor": xyChartTheme.yAxisTickColor = value
            case "yAxisLineColor": xyChartTheme.yAxisLineColor = value
            case "plotColorPalette": xyChartTheme.plotColorPalette = value
            default: break
            }
            continue
        }

        // Pie Chart config — config.pie.*
        if fullPath.hasPrefix("config.pie.") {
            hasPieConfig = true
            let subKey = fullPath.replacingOccurrences(of: "config.pie.", with: "")
            switch subKey {
            case "textPosition": pieConfig.textPosition = Double(value) ?? pieConfig.textPosition
            case "useWidth": pieConfig.useWidth = Double(value) ?? pieConfig.useWidth
            case "useMaxWidth": pieConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            continue
        }

        // Pie Chart theme — Mermaid supports flat themeVariables.pie1 and nested themeVariables.pie.pie1.
        if let subKey = _pieThemeSubKey(from: fullPath) {
            if _applyPieThemeValue(subKey, value: value, theme: &pieTheme) {
                hasPieTheme = true
            }
            continue
        }

        // Sequence config — config.sequence.*
        if fullPath.hasPrefix("config.sequence.") {
            hasSequenceSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.sequence.", with: "")
            switch subKey {
            case "diagramMarginX": sequenceConfig.diagramMarginX = Double(value) ?? sequenceConfig.diagramMarginX
            case "diagramMarginY": sequenceConfig.diagramMarginY = Double(value) ?? sequenceConfig.diagramMarginY
            case "actorMargin": sequenceConfig.actorMargin = Double(value) ?? sequenceConfig.actorMargin
            case "width": sequenceConfig.width = Double(value) ?? sequenceConfig.width
            case "height": sequenceConfig.height = Double(value) ?? sequenceConfig.height
            case "boxMargin": sequenceConfig.boxMargin = Double(value) ?? sequenceConfig.boxMargin
            case "boxTextMargin": sequenceConfig.boxTextMargin = Double(value) ?? sequenceConfig.boxTextMargin
            case "noteMargin": sequenceConfig.noteMargin = Double(value) ?? sequenceConfig.noteMargin
            case "messageMargin": sequenceConfig.messageMargin = Double(value) ?? sequenceConfig.messageMargin
            case "activationWidth": sequenceConfig.activationWidth = Double(value) ?? sequenceConfig.activationWidth
            case "messageAlign":
                if let align = SequenceDiagramConfig.TextAlign(rawValue: value.lowercased()) {
                    sequenceConfig.messageAlign = align
                }
            case "noteAlign":
                if let align = SequenceDiagramConfig.TextAlign(rawValue: value.lowercased()) {
                    sequenceConfig.noteAlign = align
                }
            case "bottomMarginAdj": sequenceConfig.bottomMarginAdj = Double(value) ?? sequenceConfig.bottomMarginAdj
            case "useMaxWidth": sequenceConfig.useMaxWidth = (value.lowercased() == "true")
            case "mirrorActors": sequenceConfig.mirrorActors = (value.lowercased() == "true")
            case "hideUnusedParticipants": sequenceConfig.hideUnusedParticipants = (value.lowercased() == "true")
            case "rightAngles": sequenceConfig.rightAngles = (value.lowercased() == "true")
            case "showSequenceNumbers": sequenceConfig.showSequenceNumbers = (value.lowercased() == "true")
            case "forceMenus": sequenceConfig.forceMenus = (value.lowercased() == "true")
            case "arrowMarkerAbsolute": sequenceConfig.arrowMarkerAbsolute = (value.lowercased() == "true")
            case "wrap": sequenceConfig.wrap = (value.lowercased() == "true")
            case "wrapPadding": sequenceConfig.wrapPadding = Double(value) ?? sequenceConfig.wrapPadding
            case "labelBoxWidth": sequenceConfig.labelBoxWidth = Double(value) ?? sequenceConfig.labelBoxWidth
            case "labelBoxHeight": sequenceConfig.labelBoxHeight = Double(value) ?? sequenceConfig.labelBoxHeight
            case "actorFontFamily": sequenceConfig.actorFontFamily = value
            case "actorFontSize": sequenceConfig.actorFontSize = Double(value)
            case "actorFontWeight": sequenceConfig.actorFontWeight = value
            case "messageFontFamily": sequenceConfig.messageFontFamily = value
            case "messageFontSize": sequenceConfig.messageFontSize = Double(value)
            case "messageFontWeight": sequenceConfig.messageFontWeight = value
            case "noteFontFamily": sequenceConfig.noteFontFamily = value
            case "noteFontSize": sequenceConfig.noteFontSize = Double(value)
            case "noteFontWeight": sequenceConfig.noteFontWeight = value
            default: break
            }
            continue
        }

        // State Diagram config — config.state.*
        if fullPath.hasPrefix("config.state.") {
            hasStateSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.state.", with: "")
            switch subKey {
            case "titleTopMargin": stateConfig.titleTopMargin = Double(value) ?? stateConfig.titleTopMargin
            case "useMaxWidth": stateConfig.useMaxWidth = (value.lowercased() == "true")
            case "defaultRenderer": stateConfig.defaultRenderer = value
            case "arrowMarkerAbsolute": stateConfig.arrowMarkerAbsolute = (value.lowercased() == "true")
            case "dividerMargin": stateConfig.dividerMargin = Double(value) ?? stateConfig.dividerMargin
            case "sizeUnit": stateConfig.sizeUnit = Double(value) ?? stateConfig.sizeUnit
            case "padding": stateConfig.padding = Double(value) ?? stateConfig.padding
            case "textHeight": stateConfig.textHeight = Double(value) ?? stateConfig.textHeight
            case "titleShift": stateConfig.titleShift = Double(value) ?? stateConfig.titleShift
            case "noteMargin": stateConfig.noteMargin = Double(value) ?? stateConfig.noteMargin
            case "nodeSpacing": stateConfig.nodeSpacing = Int(value) ?? stateConfig.nodeSpacing
            case "rankSpacing": stateConfig.rankSpacing = Int(value) ?? stateConfig.rankSpacing
            case "forkWidth": stateConfig.forkWidth = Double(value) ?? stateConfig.forkWidth
            case "forkHeight": stateConfig.forkHeight = Double(value) ?? stateConfig.forkHeight
            case "miniPadding": stateConfig.miniPadding = Double(value) ?? stateConfig.miniPadding
            case "fontSizeFactor": stateConfig.fontSizeFactor = Double(value) ?? stateConfig.fontSizeFactor
            case "fontSize": stateConfig.fontSize = Double(value) ?? stateConfig.fontSize
            case "labelHeight": stateConfig.labelHeight = Double(value) ?? stateConfig.labelHeight
            case "edgeLengthFactor": stateConfig.edgeLengthFactor = value
            case "compositTitleSize": stateConfig.compositTitleSize = Double(value) ?? stateConfig.compositTitleSize
            case "radius": stateConfig.radius = Double(value) ?? stateConfig.radius
            case "scaleWidth": stateConfig.scaleWidth = Int(value)
            case "hideEmptyDescription": stateConfig.hideEmptyDescription = (value.lowercased() == "true")
            default: break
            }
            continue
        }

        // Journey config — config.journey.*
        if fullPath.hasPrefix("config.journey.") {
            hasJourneySection = true
            let subKey = fullPath.replacingOccurrences(of: "config.journey.", with: "")
            switch subKey {
            case "diagramMarginX": journeyConfig.diagramMarginX = Double(value) ?? journeyConfig.diagramMarginX
            case "diagramMarginY": journeyConfig.diagramMarginY = Double(value) ?? journeyConfig.diagramMarginY
            case "leftMargin": journeyConfig.leftMargin = Double(value) ?? journeyConfig.leftMargin
            case "maxLabelWidth": journeyConfig.maxLabelWidth = Double(value) ?? journeyConfig.maxLabelWidth
            case "width": journeyConfig.width = Double(value) ?? journeyConfig.width
            case "height": journeyConfig.height = Double(value) ?? journeyConfig.height
            case "boxMargin": journeyConfig.boxMargin = Double(value) ?? journeyConfig.boxMargin
            case "boxTextMargin": journeyConfig.boxTextMargin = Double(value) ?? journeyConfig.boxTextMargin
            case "noteMargin": journeyConfig.noteMargin = Double(value) ?? journeyConfig.noteMargin
            case "messageMargin": journeyConfig.messageMargin = Double(value) ?? journeyConfig.messageMargin
            case "messageAlign": journeyConfig.messageAlign = value
            case "bottomMarginAdj": journeyConfig.bottomMarginAdj = Double(value) ?? journeyConfig.bottomMarginAdj
            case "useMaxWidth": journeyConfig.useMaxWidth = (value.lowercased() == "true")
            case "rightAngles": journeyConfig.rightAngles = (value.lowercased() == "true")
            case "taskFontSize": journeyConfig.taskFontSize = Double(value) ?? journeyConfig.taskFontSize
            case "taskFontFamily": journeyConfig.taskFontFamily = value
            case "taskMargin": journeyConfig.taskMargin = Double(value) ?? journeyConfig.taskMargin
            case "activationWidth": journeyConfig.activationWidth = Double(value) ?? journeyConfig.activationWidth
            case "textPlacement": journeyConfig.textPlacement = value
            case "actorColours":
                if let values = _parseYamlStringArray(value) {
                    journeyConfig.actorColours = values
                }
            case "sectionFills":
                if let values = _parseYamlStringArray(value) {
                    journeyConfig.sectionFills = values
                }
            case "sectionColours":
                if let values = _parseYamlStringArray(value) {
                    journeyConfig.sectionColours = values
                }
            case "titleColor": journeyConfig.titleColor = value
            case "titleFontFamily": journeyConfig.titleFontFamily = value
            case "titleFontSize": journeyConfig.titleFontSize = value
            default: break
            }
            continue
        }

        // Gantt config — config.gantt.*
        if fullPath.hasPrefix("config.gantt.") {
            hasGanttSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.gantt.", with: "")
            switch subKey {
            case "titleTopMargin": ganttConfig.titleTopMargin = Double(value) ?? ganttConfig.titleTopMargin
            case "barHeight": ganttConfig.barHeight = Double(value) ?? ganttConfig.barHeight
            case "barGap": ganttConfig.barGap = Double(value) ?? ganttConfig.barGap
            case "topPadding": ganttConfig.topPadding = Double(value) ?? ganttConfig.topPadding
            case "rightPadding": ganttConfig.rightPadding = Double(value) ?? ganttConfig.rightPadding
            case "leftPadding": ganttConfig.leftPadding = Double(value) ?? ganttConfig.leftPadding
            case "gridLineStartPadding": ganttConfig.gridLineStartPadding = Double(value) ?? ganttConfig.gridLineStartPadding
            case "fontSize": ganttConfig.fontSize = Double(value) ?? ganttConfig.fontSize
            case "sectionFontSize": ganttConfig.sectionFontSize = Double(value) ?? ganttConfig.sectionFontSize
            case "numberSectionStyles": ganttConfig.numberSectionStyles = Int(value) ?? ganttConfig.numberSectionStyles
            case "axisFormat": ganttConfig.axisFormat = value
            case "tickInterval": ganttConfig.tickInterval = value
            case "topAxis": ganttConfig.topAxis = (value.lowercased() == "true")
            case "displayMode": ganttConfig.displayMode = value
            case "weekday": ganttConfig.weekday = value
            case "useMaxWidth": ganttConfig.useMaxWidth = (value.lowercased() == "true")
            case "useWidth": ganttConfig.useWidth = Double(value)
            default: break
            }
            continue
        }

        // Requirement config — config.requirement.*
        if fullPath.hasPrefix("config.requirement.") {
            hasRequirementSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.requirement.", with: "")
            switch subKey {
            case "useMaxWidth": requirementConfig.useMaxWidth = (value.lowercased() == "true")
            case "useWidth": requirementConfig.useWidth = Double(value)
            case "rect_fill": requirementConfig.rect_fill = value
            case "text_color": requirementConfig.text_color = value
            case "rect_border_size": requirementConfig.rect_border_size = value
            case "rect_border_color": requirementConfig.rect_border_color = value
            case "rect_min_width": requirementConfig.rect_min_width = Double(value)
            case "rect_min_height": requirementConfig.rect_min_height = Double(value)
            case "fontSize": requirementConfig.fontSize = Double(value)
            case "rect_padding": requirementConfig.rect_padding = Double(value)
            case "line_height": requirementConfig.line_height = Double(value)
            case "nodeSpacing": requirementConfig.nodeSpacing = Double(value) ?? 50
            case "rankSpacing": requirementConfig.rankSpacing = Double(value) ?? 50
            default: break
            }
            continue
        }

        // Quadrant Chart config — config.quadrantChart.*
        if fullPath.hasPrefix("config.quadrantChart.") {
            hasQuadrantChartConfig = true
            let subKey = fullPath.replacingOccurrences(of: "config.quadrantChart.", with: "")
            switch subKey {
            case "chartWidth": quadrantChartConfig.chartWidth = Double(value) ?? quadrantChartConfig.chartWidth
            case "chartHeight": quadrantChartConfig.chartHeight = Double(value) ?? quadrantChartConfig.chartHeight
            case "titlePadding": quadrantChartConfig.titlePadding = Double(value) ?? quadrantChartConfig.titlePadding
            case "titleFontSize": quadrantChartConfig.titleFontSize = Double(value) ?? quadrantChartConfig.titleFontSize
            case "quadrantPadding": quadrantChartConfig.quadrantPadding = Double(value) ?? quadrantChartConfig.quadrantPadding
            case "quadrantTextTopPadding": quadrantChartConfig.quadrantTextTopPadding = Double(value) ?? quadrantChartConfig.quadrantTextTopPadding
            case "quadrantLabelFontSize": quadrantChartConfig.quadrantLabelFontSize = Double(value) ?? quadrantChartConfig.quadrantLabelFontSize
            case "quadrantInternalBorderStrokeWidth": quadrantChartConfig.quadrantInternalBorderStrokeWidth = Double(value) ?? quadrantChartConfig.quadrantInternalBorderStrokeWidth
            case "quadrantExternalBorderStrokeWidth": quadrantChartConfig.quadrantExternalBorderStrokeWidth = Double(value) ?? quadrantChartConfig.quadrantExternalBorderStrokeWidth
            case "xAxisLabelPadding": quadrantChartConfig.xAxisLabelPadding = Double(value) ?? quadrantChartConfig.xAxisLabelPadding
            case "xAxisLabelFontSize": quadrantChartConfig.xAxisLabelFontSize = Double(value) ?? quadrantChartConfig.xAxisLabelFontSize
            case "xAxisPosition": quadrantChartConfig.xAxisPosition = value
            case "yAxisLabelPadding": quadrantChartConfig.yAxisLabelPadding = Double(value) ?? quadrantChartConfig.yAxisLabelPadding
            case "yAxisLabelFontSize": quadrantChartConfig.yAxisLabelFontSize = Double(value) ?? quadrantChartConfig.yAxisLabelFontSize
            case "yAxisPosition": quadrantChartConfig.yAxisPosition = value
            case "pointTextPadding": quadrantChartConfig.pointTextPadding = Double(value) ?? quadrantChartConfig.pointTextPadding
            case "pointLabelFontSize": quadrantChartConfig.pointLabelFontSize = Double(value) ?? quadrantChartConfig.pointLabelFontSize
            case "pointRadius": quadrantChartConfig.pointRadius = Double(value) ?? quadrantChartConfig.pointRadius
            case "useMaxWidth": quadrantChartConfig.useMaxWidth = (value.lowercased() == "true")
            default: break
            }
            continue
        }

        // Timeline theme variables (before GitGraph to avoid shared key conflicts)
        if let subKey = _timelineThemeSubKey(from: fullPath) {
            if _applyTimelineThemeValue(subKey, value: value, theme: &timelineTheme) {
                hasTimelineTheme = true
            }
            continue
        }

        // GitGraph theme — config.themeVariables.git* and themeVariables.git*
        if let subKey = _gitGraphThemeSubKey(from: fullPath) {
            if _applyGitGraphThemeValue(subKey, value: value, theme: &gitGraphTheme) {
                hasGitGraphTheme = true
            }
            continue
        }

        // Quadrant Chart theme — config.themeVariables.quadrant*
        if fullPath.hasPrefix("config.themeVariables.") || fullPath.hasPrefix("themeVariables.") {
            let prefix: String
            if fullPath.hasPrefix("config.themeVariables.") {
                prefix = "config.themeVariables."
            } else {
                prefix = "themeVariables."
            }
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isQuadrantThemeKey(subKey) {
                hasQuadrantChartTheme = true
                _ = _applyQuadrantThemeValue(subKey, value: value, theme: &quadrantChartTheme)
                continue
            }
        }

        // Top-level displayMode routing for Gantt compact mode
        if fullPath == "displayMode" && value.lowercased() == "compact" {
            hasGanttSection = true
            ganttConfig.displayMode = "compact"
            continue
        }

        // GitGraph config — config.gitGraph.*
        if fullPath.hasPrefix("config.gitGraph.") {
            hasGitGraphSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.gitGraph.", with: "")
            switch subKey {
            case "titleTopMargin": gitGraphConfig.titleTopMargin = Double(value) ?? gitGraphConfig.titleTopMargin
            case "diagramPadding": gitGraphConfig.diagramPadding = Double(value) ?? gitGraphConfig.diagramPadding
            case "mainBranchName": gitGraphConfig.mainBranchName = value
            case "mainBranchOrder": gitGraphConfig.mainBranchOrder = Int(value) ?? gitGraphConfig.mainBranchOrder
            case "showCommitLabel": gitGraphConfig.showCommitLabel = (value.lowercased() == "true")
            case "showBranches": gitGraphConfig.showBranches = (value.lowercased() == "true")
            case "rotateCommitLabel": gitGraphConfig.rotateCommitLabel = (value.lowercased() == "true")
            case "parallelCommits": gitGraphConfig.parallelCommits = (value.lowercased() == "true")
            case "arrowMarkerAbsolute": gitGraphConfig.arrowMarkerAbsolute = (value.lowercased() == "true")
            case "useMaxWidth": gitGraphConfig.useMaxWidth = (value.lowercased() == "true")
            case "useWidth": gitGraphConfig.useWidth = Double(value)
            case let s where s.hasPrefix("nodeLabel."):
                let nodeKey = s.replacingOccurrences(of: "nodeLabel.", with: "")
                switch nodeKey {
                case "width": gitGraphConfig.nodeLabel.width = Double(value) ?? gitGraphConfig.nodeLabel.width
                case "height": gitGraphConfig.nodeLabel.height = Double(value) ?? gitGraphConfig.nodeLabel.height
                case "x": gitGraphConfig.nodeLabel.x = Double(value) ?? gitGraphConfig.nodeLabel.x
                case "y": gitGraphConfig.nodeLabel.y = Double(value) ?? gitGraphConfig.nodeLabel.y
                default: break
                }
            default: break
            }
            continue
        }

        // Mindmap config — config.mindmap.*
        if fullPath.hasPrefix("config.mindmap.") {
            hasMindmapSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.mindmap.", with: "")
            switch subKey {
            case "padding": mindmapConfig.padding = Double(value) ?? mindmapConfig.padding
            case "maxNodeWidth": mindmapConfig.maxNodeWidth = Double(value) ?? mindmapConfig.maxNodeWidth
            case "useMaxWidth": mindmapConfig.useMaxWidth = (value.lowercased() == "true")
            case "layoutAlgorithm": mindmapConfig.layoutAlgorithm = value
            default: break
            }
            continue
        }

        // Timeline config — config.timeline.*
        if fullPath.hasPrefix("config.timeline.") {
            hasTimelineSection = true
            let subKey = fullPath.replacingOccurrences(of: "config.timeline.", with: "")
            switch subKey {
            case "disableMulticolor": timelineConfig.disableMulticolor = (value.lowercased() == "true")
            case "leftMargin": timelineConfig.leftMargin = Double(value) ?? timelineConfig.leftMargin
            case "padding": timelineConfig.padding = Double(value) ?? timelineConfig.padding
            case "useMaxWidth": timelineConfig.useMaxWidth = (value.lowercased() == "true")
            case "useWidth": timelineConfig.useWidth = Double(value)
            case "taskFontSize": timelineConfig.taskFontSize = Double(value) ?? timelineConfig.taskFontSize
            case "taskFontFamily": timelineConfig.taskFontFamily = value
            case "textPlacement": timelineConfig.textPlacement = value
            case "width": timelineConfig.width = Double(value) ?? timelineConfig.width
            case "height": timelineConfig.height = Double(value) ?? timelineConfig.height
            default: break
            }
            continue
        }

        // Global config.layout (shared across all diagram families)
        if fullPath == "config.layout" {
            hasErSection = true
            erConfig.layout = value
            frontmatter.layout = value
            continue
        }

        // Global config.look
        if fullPath == "config.look" {
            hasErSection = true
            erConfig.look = value
            frontmatter.look = value
            continue
        }

        // Global config.htmlLabels
        if fullPath == "config.htmlLabels" {
            hasErSection = true
            erConfig.htmlLabels = (value.lowercased() == "true")
            frontmatter.htmlLabels = (value.lowercased() == "true")
            continue
        }

        // Global config.theme
        if fullPath == "config.theme" {
            frontmatter.theme = value
            continue
        }

        // Global config.fontSize
        if fullPath == "config.fontSize" {
            frontmatter.fontSize = Double(value)
            continue
        }

        // Global config.securityLevel
        if fullPath == "config.securityLevel" {
            frontmatter.securityLevel = value
            continue
        }
    }

    if hasFlowchartSection { frontmatter.flowchartConfig = flowchartConfig }
    if hasClassSection { frontmatter.classConfig = classConfig }
    if hasErSection { frontmatter.erConfig = erConfig }
    if hasXYChartConfig { frontmatter.xyChartConfig = xyChartConfig }
    if hasXYChartTheme { frontmatter.xyChartTheme = xyChartTheme }
    if hasPieConfig { frontmatter.pieConfig = pieConfig }
    if hasPieTheme { frontmatter.pieTheme = pieTheme }
    if hasSequenceSection { frontmatter.sequenceConfig = sequenceConfig }
    if hasStateSection { frontmatter.stateConfig = stateConfig }
    if hasJourneySection { frontmatter.journeyConfig = journeyConfig }
    if hasGanttSection { frontmatter.ganttConfig = ganttConfig }
    if hasQuadrantChartConfig { frontmatter.quadrantChartConfig = quadrantChartConfig }
    if hasQuadrantChartTheme { frontmatter.quadrantChartTheme = quadrantChartTheme }
    if hasRequirementSection { frontmatter.requirementConfig = requirementConfig }
    if hasGitGraphSection { frontmatter.gitGraphConfig = gitGraphConfig }
    if hasGitGraphTheme { frontmatter.gitGraphTheme = gitGraphTheme }
    if hasMindmapSection { frontmatter.mindmapConfig = mindmapConfig }
    if hasTimelineSection { frontmatter.timelineConfig = timelineConfig }
    if hasTimelineTheme { frontmatter.timelineTheme = timelineTheme }

    return hasAnyContent ? frontmatter : nil
}

private func _gitGraphThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.gitGraph.", "themeVariables.gitGraph."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isGitGraphThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

private func _isGitGraphThemeKey(_ key: String) -> Bool {
    switch key {
    case "git0", "git1", "git2", "git3", "git4", "git5", "git6", "git7",
         "gitInv0", "gitInv1", "gitInv2", "gitInv3", "gitInv4", "gitInv5", "gitInv6", "gitInv7",
         "gitBranchLabel0", "gitBranchLabel1", "gitBranchLabel2", "gitBranchLabel3",
         "gitBranchLabel4", "gitBranchLabel5", "gitBranchLabel6", "gitBranchLabel7",
         "commitLabelColor", "commitLabelBackground", "commitLabelFontSize",
         "tagLabelColor", "tagLabelBackground", "tagLabelBorder", "tagLabelFontSize",
         "nodeBorder", "mainBkg", "strokeWidth", "useGradient", "gradientStart",
         "gradientStop", "dropShadow", "filterColor", "fontFamily", "textColor",
         "primaryColor", "secondaryColor", "tertiaryColor", "primaryTextColor",
         "labelTextColor", "lineColor", "noteFontWeight":
        return true
    default:
        return false
    }
}

private func _applyGitGraphThemeValue(_ key: String, value: String, theme: inout GitGraphThemeConfig) -> Bool {
    switch key {
    case "git0": theme.git0 = value
    case "git1": theme.git1 = value
    case "git2": theme.git2 = value
    case "git3": theme.git3 = value
    case "git4": theme.git4 = value
    case "git5": theme.git5 = value
    case "git6": theme.git6 = value
    case "git7": theme.git7 = value
    case "gitInv0": theme.gitInv0 = value
    case "gitInv1": theme.gitInv1 = value
    case "gitInv2": theme.gitInv2 = value
    case "gitInv3": theme.gitInv3 = value
    case "gitInv4": theme.gitInv4 = value
    case "gitInv5": theme.gitInv5 = value
    case "gitInv6": theme.gitInv6 = value
    case "gitInv7": theme.gitInv7 = value
    case "gitBranchLabel0": theme.gitBranchLabel0 = value
    case "gitBranchLabel1": theme.gitBranchLabel1 = value
    case "gitBranchLabel2": theme.gitBranchLabel2 = value
    case "gitBranchLabel3": theme.gitBranchLabel3 = value
    case "gitBranchLabel4": theme.gitBranchLabel4 = value
    case "gitBranchLabel5": theme.gitBranchLabel5 = value
    case "gitBranchLabel6": theme.gitBranchLabel6 = value
    case "gitBranchLabel7": theme.gitBranchLabel7 = value
    case "commitLabelColor": theme.commitLabelColor = value
    case "commitLabelBackground": theme.commitLabelBackground = value
    case "commitLabelFontSize": theme.commitLabelFontSize = value
    case "tagLabelColor": theme.tagLabelColor = value
    case "tagLabelBackground": theme.tagLabelBackground = value
    case "tagLabelBorder": theme.tagLabelBorder = value
    case "tagLabelFontSize": theme.tagLabelFontSize = value
    case "nodeBorder": theme.nodeBorder = value
    case "mainBkg": theme.mainBkg = value
    case "strokeWidth": theme.strokeWidth = value
    case "useGradient": theme.useGradient = (value.lowercased() == "true")
    case "gradientStart": theme.gradientStart = value
    case "gradientStop": theme.gradientStop = value
    case "dropShadow": theme.dropShadow = value
    case "filterColor": theme.filterColor = value
    case "fontFamily": theme.fontFamily = value
    case "textColor": theme.textColor = value
    case "primaryColor": theme.primaryColor = value
    case "secondaryColor": theme.secondaryColor = value
    case "tertiaryColor": theme.tertiaryColor = value
    case "primaryTextColor": theme.primaryTextColor = value
    case "labelTextColor": theme.labelTextColor = value
    case "lineColor": theme.lineColor = value
    case "noteFontWeight": theme.noteFontWeight = value
    default: return false
    }
    return true
}

private func _pieThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.pie.", "themeVariables.pie."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isPieThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

private func _isPieThemeKey(_ key: String) -> Bool {
    switch key {
    case "pie1", "pie2", "pie3", "pie4", "pie5", "pie6",
         "pie7", "pie8", "pie9", "pie10", "pie11", "pie12",
         "pieTitleTextSize", "pieTitleTextColor",
         "pieSectionTextSize", "pieSectionTextColor",
         "pieLegendTextSize", "pieLegendTextColor",
         "pieStrokeColor", "pieStrokeWidth",
         "pieOuterStrokeWidth", "pieOuterStrokeColor",
         "pieOpacity", "fontFamily":
        return true
    default:
        return false
    }
}

private func _applyPieThemeValue(_ key: String, value: String, theme: inout PieChartThemeConfig) -> Bool {
    switch key {
    case "pie1": theme.pie1 = value
    case "pie2": theme.pie2 = value
    case "pie3": theme.pie3 = value
    case "pie4": theme.pie4 = value
    case "pie5": theme.pie5 = value
    case "pie6": theme.pie6 = value
    case "pie7": theme.pie7 = value
    case "pie8": theme.pie8 = value
    case "pie9": theme.pie9 = value
    case "pie10": theme.pie10 = value
    case "pie11": theme.pie11 = value
    case "pie12": theme.pie12 = value
    case "pieTitleTextSize": theme.pieTitleTextSize = value
    case "pieTitleTextColor": theme.pieTitleTextColor = value
    case "pieSectionTextSize": theme.pieSectionTextSize = value
    case "pieSectionTextColor": theme.pieSectionTextColor = value
    case "pieLegendTextSize": theme.pieLegendTextSize = value
    case "pieLegendTextColor": theme.pieLegendTextColor = value
    case "pieStrokeColor": theme.pieStrokeColor = value
    case "pieStrokeWidth": theme.pieStrokeWidth = value
    case "pieOuterStrokeWidth": theme.pieOuterStrokeWidth = value
    case "pieOuterStrokeColor": theme.pieOuterStrokeColor = value
    case "pieOpacity": theme.pieOpacity = value
    case "fontFamily": theme.fontFamily = value
    default: return false
    }
    return true
}

// MARK: - Quadrant Chart theme helpers

private func _isQuadrantThemeKey(_ key: String) -> Bool {
    switch key {
    case "quadrant1Fill", "quadrant2Fill", "quadrant3Fill", "quadrant4Fill",
         "quadrant1TextFill", "quadrant2TextFill", "quadrant3TextFill", "quadrant4TextFill",
         "quadrantPointFill", "quadrantPointTextFill",
         "quadrantXAxisTextFill", "quadrantYAxisTextFill",
         "quadrantInternalBorderStrokeFill", "quadrantExternalBorderStrokeFill",
         "quadrantTitleFill":
        return true
    default:
        return false
    }
}

private func _applyQuadrantThemeValue(_ key: String, value: String, theme: inout QuadrantChartThemeConfig) -> Bool {
    switch key {
    case "quadrant1Fill": theme.quadrant1Fill = value
    case "quadrant2Fill": theme.quadrant2Fill = value
    case "quadrant3Fill": theme.quadrant3Fill = value
    case "quadrant4Fill": theme.quadrant4Fill = value
    case "quadrant1TextFill": theme.quadrant1TextFill = value
    case "quadrant2TextFill": theme.quadrant2TextFill = value
    case "quadrant3TextFill": theme.quadrant3TextFill = value
    case "quadrant4TextFill": theme.quadrant4TextFill = value
    case "quadrantPointFill": theme.quadrantPointFill = value
    case "quadrantPointTextFill": theme.quadrantPointTextFill = value
    case "quadrantXAxisTextFill": theme.quadrantXAxisTextFill = value
    case "quadrantYAxisTextFill": theme.quadrantYAxisTextFill = value
    case "quadrantInternalBorderStrokeFill": theme.quadrantInternalBorderStrokeFill = value
    case "quadrantExternalBorderStrokeFill": theme.quadrantExternalBorderStrokeFill = value
    case "quadrantTitleFill": theme.quadrantTitleFill = value
    default: return false
    }
    return true
}

/// Strip surrounding quotes from a string.
private func _unquote(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespaces)
    if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
       (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
        let start = trimmed.index(after: trimmed.startIndex)
        let end = trimmed.index(before: trimmed.endIndex)
        return String(trimmed[start..<end])
    }
    return trimmed
}

private func _stripYamlComment(_ line: String) -> String {
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for idx in line.indices {
        let ch = line[idx]
        if inQuote {
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" && quoteChar == "\"" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            continue
        }

        if ch == "#" {
            return String(line[..<idx]).trimmingCharacters(in: .whitespaces)
        }
    }

    return line
}

private func _parseYamlStringArray(_ value: String) -> [String]? {
    let trimmed = value.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { return nil }

    let innerStart = trimmed.index(after: trimmed.startIndex)
    let innerEnd = trimmed.index(before: trimmed.endIndex)
    let inner = String(trimmed[innerStart..<innerEnd])
    if inner.trimmingCharacters(in: .whitespaces).isEmpty {
        return []
    }

    var items: [String] = []
    var current = ""
    var inQuote = false
    var quoteChar: Character?
    var isEscaped = false

    for ch in inner {
        if inQuote {
            current.append(ch)
            if isEscaped {
                isEscaped = false
                continue
            }
            if ch == "\\" && quoteChar == "\"" {
                isEscaped = true
                continue
            }
            if ch == quoteChar {
                inQuote = false
                quoteChar = nil
            }
            continue
        }

        if ch == "\"" || ch == "'" {
            inQuote = true
            quoteChar = ch
            current.append(ch)
            continue
        }

        if ch == "," {
            items.append(_unquote(current))
            current = ""
        } else {
            current.append(ch)
        }
    }

    items.append(_unquote(current))
    return items
}

// MARK: - Timeline Theme helpers

private func _timelineThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isTimelineThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

private func _isTimelineThemeKey(_ key: String) -> Bool {
    switch key {
    case "cScale0", "cScale1", "cScale2", "cScale3", "cScale4", "cScale5",
         "cScale6", "cScale7", "cScale8", "cScale9", "cScale10", "cScale11",
         "cScaleLabel0", "cScaleLabel1", "cScaleLabel2", "cScaleLabel3",
         "cScaleLabel4", "cScaleLabel5", "cScaleLabel6", "cScaleLabel7",
         "cScaleLabel8", "cScaleLabel9", "cScaleLabel10", "cScaleLabel11",
         "cScaleInv0", "cScaleInv1", "cScaleInv2", "cScaleInv3",
         "cScaleInv4", "cScaleInv5", "cScaleInv6", "cScaleInv7",
         "cScaleInv8", "cScaleInv9", "cScaleInv10", "cScaleInv11",
         "THEME_COLOR_LIMIT", "fontFamily", "fontSize",
         "mainBkg", "nodeBorder", "borderColorArray",
         "useGradient", "gradientStart", "gradientStop", "dropShadow":
        return true
    default:
        return false
    }
}

private func _applyTimelineThemeValue(_ key: String, value: String, theme: inout TimelineThemeConfig) -> Bool {
    switch key {
    case "cScale0": theme.cScale[0] = value
    case "cScale1": theme.cScale[1] = value
    case "cScale2": theme.cScale[2] = value
    case "cScale3": theme.cScale[3] = value
    case "cScale4": theme.cScale[4] = value
    case "cScale5": theme.cScale[5] = value
    case "cScale6": theme.cScale[6] = value
    case "cScale7": theme.cScale[7] = value
    case "cScale8": theme.cScale[8] = value
    case "cScale9": theme.cScale[9] = value
    case "cScale10": theme.cScale[10] = value
    case "cScale11": theme.cScale[11] = value
    case "cScaleLabel0": theme.cScaleLabel[0] = value
    case "cScaleLabel1": theme.cScaleLabel[1] = value
    case "cScaleLabel2": theme.cScaleLabel[2] = value
    case "cScaleLabel3": theme.cScaleLabel[3] = value
    case "cScaleLabel4": theme.cScaleLabel[4] = value
    case "cScaleLabel5": theme.cScaleLabel[5] = value
    case "cScaleLabel6": theme.cScaleLabel[6] = value
    case "cScaleLabel7": theme.cScaleLabel[7] = value
    case "cScaleLabel8": theme.cScaleLabel[8] = value
    case "cScaleLabel9": theme.cScaleLabel[9] = value
    case "cScaleLabel10": theme.cScaleLabel[10] = value
    case "cScaleLabel11": theme.cScaleLabel[11] = value
    case "cScaleInv0": theme.cScaleInv[0] = value
    case "cScaleInv1": theme.cScaleInv[1] = value
    case "cScaleInv2": theme.cScaleInv[2] = value
    case "cScaleInv3": theme.cScaleInv[3] = value
    case "cScaleInv4": theme.cScaleInv[4] = value
    case "cScaleInv5": theme.cScaleInv[5] = value
    case "cScaleInv6": theme.cScaleInv[6] = value
    case "cScaleInv7": theme.cScaleInv[7] = value
    case "cScaleInv8": theme.cScaleInv[8] = value
    case "cScaleInv9": theme.cScaleInv[9] = value
    case "cScaleInv10": theme.cScaleInv[10] = value
    case "cScaleInv11": theme.cScaleInv[11] = value
    case "THEME_COLOR_LIMIT": theme.themeColorLimit = Int(value) ?? theme.themeColorLimit
    case "fontFamily": theme.fontFamily = value
    case "fontSize": theme.fontSize = Double(value) ?? theme.fontSize
    case "mainBkg": theme.mainBkg = value
    case "nodeBorder": theme.nodeBorder = value
    case "useGradient": theme.useGradient = (value.lowercased() == "true")
    case "gradientStart": theme.gradientStart = value
    case "gradientStop": theme.gradientStop = value
    case "dropShadow": theme.dropShadow = value
    default: return false
    }
    return true
}
