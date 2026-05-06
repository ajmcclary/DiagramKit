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

    var pathStack: [(depth: Int, key: String)] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

        let indent = line.prefix(while: { $0 == " " }).count
        let bare = trimmed

        let commentStripped: String
        if let hashIdx = bare.firstIndex(of: "#") {
            if let quoteIdx = bare.firstIndex(of: "\""), quoteIdx < hashIdx,
               let closeIdx = bare[bare.index(after: quoteIdx)...].firstIndex(of: "\""), closeIdx > hashIdx {
                commentStripped = bare
            } else {
                commentStripped = String(bare[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            }
        } else {
            commentStripped = bare
        }

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

        // Global config.layout (for dagre/elk selection)
        if fullPath == "config.layout" {
            hasErSection = true
            erConfig.layout = value
            continue
        }

        // Global config.look
        if fullPath == "config.look" {
            hasErSection = true
            erConfig.look = value
            continue
        }

        // Global config.htmlLabels
        if fullPath == "config.htmlLabels" {
            hasErSection = true
            erConfig.htmlLabels = (value.lowercased() == "true")
            continue
        }
    }

    if hasFlowchartSection { frontmatter.flowchartConfig = flowchartConfig }
    if hasClassSection { frontmatter.classConfig = classConfig }
    if hasErSection { frontmatter.erConfig = erConfig }
    if hasXYChartConfig { frontmatter.xyChartConfig = xyChartConfig }
    if hasXYChartTheme { frontmatter.xyChartTheme = xyChartTheme }

    return hasAnyContent ? frontmatter : nil
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
