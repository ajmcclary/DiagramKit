import Foundation

// MARK: - YAML Frontmatter Theme Helpers
// Extracted from SourcePreprocessing.swift

public func _gitGraphThemeSubKey(from fullPath: String) -> String? {
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

public func _isGitGraphThemeKey(_ key: String) -> Bool {
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

public func _applyGitGraphThemeValue(_ key: String, value: String, theme: inout GitGraphThemeConfig) -> Bool {
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

public func _pieThemeSubKey(from fullPath: String) -> String? {
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

public func _isPieThemeKey(_ key: String) -> Bool {
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

public func _applyPieThemeValue(_ key: String, value: String, theme: inout PieChartThemeConfig) -> Bool {
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

public func _isQuadrantThemeKey(_ key: String) -> Bool {
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

public func _applyQuadrantThemeValue(_ key: String, value: String, theme: inout QuadrantChartThemeConfig) -> Bool {
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

public func _stripYamlComment(_ line: String) -> String {
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

public func _parseYamlStringArray(_ value: String) -> [String]? {
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

public func _timelineThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isTimelineThemeKey(subKey) ? subKey : nil
        }
    }
    return nil
}

public func _isTimelineThemeKey(_ key: String) -> Bool {
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

public func _applyTimelineThemeValue(_ key: String, value: String, theme: inout TimelineThemeConfig) -> Bool {
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

// MARK: - Packet Theme helpers

public func _packetThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.packet.", "themeVariables.packet."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    return nil
}

public func _applyPacketThemeValue(_ key: String, value: String, theme: inout PacketThemeConfig) -> Bool {
    switch key {
    case "byteFontSize": theme.byteFontSize = value
    case "startByteColor": theme.startByteColor = value
    case "endByteColor": theme.endByteColor = value
    case "labelColor": theme.labelColor = value
    case "labelFontSize": theme.labelFontSize = value
    case "titleColor": theme.titleColor = value
    case "titleFontSize": theme.titleFontSize = value
    case "blockStrokeColor": theme.blockStrokeColor = value
    case "blockStrokeWidth": theme.blockStrokeWidth = value
    case "blockFillColor": theme.blockFillColor = value
    default: return false
    }
    return true
}

// MARK: - Architecture Theme helpers

public func _archThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isArchThemeKey(subKey) {
                return subKey
            }
        }
    }
    return nil
}

public func _isArchThemeKey(_ key: String) -> Bool {
    switch key {
    case "archEdgeColor", "archEdgeArrowColor", "archEdgeWidth",
         "archGroupBorderColor", "archGroupBorderWidth":
        return true
    default:
        return false
    }
}

public func _applyArchThemeValue(_ key: String, value: String, theme: inout ArchitectureThemeConfig) -> Bool {
    switch key {
    case "archEdgeColor": theme.archEdgeColor = value
    case "archEdgeArrowColor": theme.archEdgeArrowColor = value
    case "archEdgeWidth": theme.archEdgeWidth = value
    case "archGroupBorderColor": theme.archGroupBorderColor = value
    case "archGroupBorderWidth": theme.archGroupBorderWidth = value
    default: return false
    }
    return true
}

// MARK: - Radar Theme helpers

public func _radarThemeSubKey(from fullPath: String) -> String? {
    for prefix in ["config.themeVariables.radar.", "themeVariables.radar."] {
        if fullPath.hasPrefix(prefix) {
            return String(fullPath.dropFirst(prefix.count))
        }
    }
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isRadarThemeKey(subKey) {
                return subKey
            }
        }
    }
    return nil
}

public func _isRadarThemeKey(_ key: String) -> Bool {
    switch key {
    case "axisColor", "axisStrokeWidth", "axisLabelFontSize",
         "curveOpacity", "curveStrokeWidth",
         "graticuleColor", "graticuleOpacity", "graticuleStrokeWidth",
         "legendBoxSize", "legendFontSize",
         "fontSize", "titleColor",
         "cScale0", "cScale1", "cScale2", "cScale3", "cScale4", "cScale5",
         "cScale6", "cScale7", "cScale8", "cScale9", "cScale10", "cScale11",
         "THEME_COLOR_LIMIT":
        return true
    default:
        return false
    }
}

public func _applyRadarThemeValue(_ key: String, value: String, theme: inout RadarThemeConfig) -> Bool {
    switch key {
    case "axisColor": theme.axisColor = value
    case "axisStrokeWidth": theme.axisStrokeWidth = Double(value) ?? theme.axisStrokeWidth
    case "axisLabelFontSize": theme.axisLabelFontSize = Double(value) ?? theme.axisLabelFontSize
    case "curveOpacity": theme.curveOpacity = Double(value) ?? theme.curveOpacity
    case "curveStrokeWidth": theme.curveStrokeWidth = Double(value) ?? theme.curveStrokeWidth
    case "graticuleColor": theme.graticuleColor = value
    case "graticuleOpacity": theme.graticuleOpacity = Double(value) ?? theme.graticuleOpacity
    case "graticuleStrokeWidth": theme.graticuleStrokeWidth = Double(value) ?? theme.graticuleStrokeWidth
    case "legendBoxSize": theme.legendBoxSize = Double(value) ?? theme.legendBoxSize
    case "legendFontSize": theme.legendFontSize = Double(value) ?? theme.legendFontSize
    case "fontSize": theme.fontSize = Double(value) ?? theme.fontSize
    case "titleColor": theme.titleColor = value
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
    case "THEME_COLOR_LIMIT": theme.themeColorLimit = Int(value) ?? theme.themeColorLimit
    default: return false
    }
    return true
}

public func _treemapThemeSubKey(from fullPath: String) -> String? {
    let prefixes = ["config.themeVariables.", "themeVariables."]
    for prefix in prefixes {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isTreemapThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("treemap.") {
                let inner = String(subKey.dropFirst(8))
                if _isTreemapThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

public func _isTreemapThemeKey(_ key: String) -> Bool {
    if key.hasPrefix("cScale") {
        let num = String(key.dropFirst(6))
        if let n = Int(num), n >= 0, n <= 11 {
            return true
        }
    }
    if key.hasPrefix("cScalePeer") {
        let num = String(key.dropFirst(10))
        if let n = Int(num), n >= 0, n <= 11 {
            return true
        }
    }
    if key.hasPrefix("cScaleLabel") {
        let num = String(key.dropFirst(11))
        if let n = Int(num), n >= 0, n <= 11 {
            return true
        }
    }
    switch key {
    case "titleColor", "textColor": return true
    default: return false
    }
}

public func _vennThemeSubKey(from fullPath: String) -> String? {
    let prefixes = ["config.themeVariables.", "themeVariables."]
    for prefix in prefixes {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isVennThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("venn.") {
                let inner = String(subKey.dropFirst(5))
                if _isVennThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

public func _isVennThemeKey(_ key: String) -> Bool {
    if key.hasPrefix("venn"), key.count >= 5 {
        let numStr = String(key.dropFirst(4))
        if let n = Int(numStr), n >= 1, n <= 8 {
            return true
        }
    }
    switch key {
    case "vennTitleTextColor", "vennSetTextColor": return true
    default: return false
    }
}

// MARK: - TreeView Theme Helpers

public func _treeViewThemeSubKey(from fullPath: String) -> String? {
    let prefixes = ["config.themeVariables.", "themeVariables."]
    for prefix in prefixes {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            if _isTreeViewThemeKey(subKey) {
                return subKey
            }
            if subKey.hasPrefix("treeView.") {
                let inner = String(subKey.dropFirst(9))
                if _isTreeViewThemeKey(inner) {
                    return inner
                }
            }
        }
    }
    return nil
}

public func _isTreeViewThemeKey(_ key: String) -> Bool {
    switch key {
    case "labelFontSize", "labelColor", "lineColor", "iconColor",
         "descriptionColor", "highlightBg", "highlightStroke":
        return true
    default:
        return false
    }
}

public func _applyTreeViewThemeValue(_ key: String, value: String, theme: inout TreeViewThemeVariables) {
    switch key {
    case "labelFontSize": theme.labelFontSize = value
    case "labelColor": theme.labelColor = value
    case "lineColor": theme.lineColor = value
    case "iconColor": theme.iconColor = value
    case "descriptionColor": theme.descriptionColor = value
    case "highlightBg": theme.highlightBg = value
    case "highlightStroke": theme.highlightStroke = value
    default: break
    }
}

// MARK: - EventModeling theme helpers

public func _isEMThemePath(_ fullPath: String) -> Bool {
    for prefix in ["config.themeVariables.", "themeVariables."] {
        if fullPath.hasPrefix(prefix) {
            let subKey = String(fullPath.dropFirst(prefix.count))
            return _isEMThemeKey(subKey)
        }
    }
    return false
}

public func _isEMThemeKey(_ key: String) -> Bool {
    switch key {
    case "emUiFill", "emUiStroke",
         "emProcessorFill", "emProcessorStroke",
         "emReadModelFill", "emReadModelStroke",
         "emCommandFill", "emCommandStroke",
         "emEventFill", "emEventStroke",
         "emSwimlaneBackgroundOdd", "emSwimlaneBackgroundStroke",
         "emRelationStroke", "emArrowhead":
        return true
    default:
        return false
    }
}
