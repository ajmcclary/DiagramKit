import Foundation
import DiagramKitCommon

// MARK: - SVG Escape

public func _gitGraphEscapeXml(_ text: String) -> String {
    SVG.escapeText(text)
}

private let _gitGraphFallbackBranchColors = [
    "#2f80ed", "#27ae60", "#f2994a", "#eb5757",
    "#9b51e0", "#00acc1", "#8d6e63", "#607d8b",
]

private func _gitGraphResolved(_ value: String, fallback: String) -> String {
    value.isEmpty ? fallback : value
}

private func _gitGraphThemeValue(_ theme: GitGraphThemeConfig, prefix: String, index: Int, fallback: String) -> String {
    switch (prefix, index % _GITGRAPH_THEME_COLOR_LIMIT) {
    case ("git", 0): return _gitGraphResolved(theme.git0, fallback: fallback)
    case ("git", 1): return _gitGraphResolved(theme.git1, fallback: fallback)
    case ("git", 2): return _gitGraphResolved(theme.git2, fallback: fallback)
    case ("git", 3): return _gitGraphResolved(theme.git3, fallback: fallback)
    case ("git", 4): return _gitGraphResolved(theme.git4, fallback: fallback)
    case ("git", 5): return _gitGraphResolved(theme.git5, fallback: fallback)
    case ("git", 6): return _gitGraphResolved(theme.git6, fallback: fallback)
    case ("git", 7): return _gitGraphResolved(theme.git7, fallback: fallback)
    case ("gitInv", 0): return _gitGraphResolved(theme.gitInv0, fallback: fallback)
    case ("gitInv", 1): return _gitGraphResolved(theme.gitInv1, fallback: fallback)
    case ("gitInv", 2): return _gitGraphResolved(theme.gitInv2, fallback: fallback)
    case ("gitInv", 3): return _gitGraphResolved(theme.gitInv3, fallback: fallback)
    case ("gitInv", 4): return _gitGraphResolved(theme.gitInv4, fallback: fallback)
    case ("gitInv", 5): return _gitGraphResolved(theme.gitInv5, fallback: fallback)
    case ("gitInv", 6): return _gitGraphResolved(theme.gitInv6, fallback: fallback)
    case ("gitInv", 7): return _gitGraphResolved(theme.gitInv7, fallback: fallback)
    case ("gitBranchLabel", 0): return _gitGraphResolved(theme.gitBranchLabel0, fallback: fallback)
    case ("gitBranchLabel", 1): return _gitGraphResolved(theme.gitBranchLabel1, fallback: fallback)
    case ("gitBranchLabel", 2): return _gitGraphResolved(theme.gitBranchLabel2, fallback: fallback)
    case ("gitBranchLabel", 3): return _gitGraphResolved(theme.gitBranchLabel3, fallback: fallback)
    case ("gitBranchLabel", 4): return _gitGraphResolved(theme.gitBranchLabel4, fallback: fallback)
    case ("gitBranchLabel", 5): return _gitGraphResolved(theme.gitBranchLabel5, fallback: fallback)
    case ("gitBranchLabel", 6): return _gitGraphResolved(theme.gitBranchLabel6, fallback: fallback)
    case ("gitBranchLabel", 7): return _gitGraphResolved(theme.gitBranchLabel7, fallback: fallback)
    default: return fallback
    }
}

private func _gitGraphBranchColor(_ theme: GitGraphThemeConfig, _ index: Int) -> String {
    _gitGraphThemeValue(theme, prefix: "git", index: index, fallback: _gitGraphFallbackBranchColors[index % _gitGraphFallbackBranchColors.count])
}

private func _gitGraphInverseColor(_ theme: GitGraphThemeConfig, _ index: Int) -> String {
    _gitGraphThemeValue(theme, prefix: "gitInv", index: index, fallback: "#ffffff")
}

private func _gitGraphBranchLabelColor(_ theme: GitGraphThemeConfig, _ index: Int) -> String {
    _gitGraphThemeValue(theme, prefix: "gitBranchLabel", index: index, fallback: _gitGraphBranchColor(theme, index))
}

// MARK: - CSS Style Block Generation (mirrors styles.js)

private func _gitGraphGenerateStyles(_ options: GitGraphThemeConfig, positioned: PositionedGitGraphDiagram) -> String {
    let themeName = positioned.themeName
    let useNeoColorGen = _gitGraphIsNeoColorGen(themeName)
    let useReduxGeometry = _gitGraphIsReduxGeometry(themeName)
    let strokeWidth = _gitGraphResolved(options.strokeWidth, fallback: "2")
    let commitLineColor = _gitGraphResolved(options.lineColor, fallback: "#888888")
    let nodeBorder = _gitGraphResolved(options.nodeBorder, fallback: "#000000")
    let mainBkg = _gitGraphResolved(options.mainBkg, fallback: "#ffffff")
    let textColor = _gitGraphResolved(options.textColor, fallback: "#333333")
    let primaryColor = _gitGraphResolved(options.primaryColor, fallback: "#333333")
    let commitLabelColor = _gitGraphResolved(options.commitLabelColor, fallback: "#333333")
    let commitLabelBkg = _gitGraphResolved(options.commitLabelBackground, fallback: "#f2f2f2")
    let tagLabelColor = _gitGraphResolved(options.tagLabelColor, fallback: "#333333")
    let tagLabelBkg = _gitGraphResolved(options.tagLabelBackground, fallback: "#eeeeee")
    let tagLabelBorder = _gitGraphResolved(options.tagLabelBorder, fallback: "#777777")
    let commitLabelFontSize = _gitGraphResolved(options.commitLabelFontSize, fallback: "12px")
    let tagLabelFontSize = _gitGraphResolved(options.tagLabelFontSize, fallback: "10px")
    let dropShadow = options.dropShadow ?? ""
    let noteFontWeight = _gitGraphResolved(options.noteFontWeight, fallback: "")
    let fontWeightCSS = useReduxGeometry && !noteFontWeight.isEmpty ? "font-weight:\(noteFontWeight);" : ""

    var css = ""

    // Branch colors - per-index
    for i in 0..<_GITGRAPH_THEME_COLOR_LIMIT {
        let ci = i % 8
        if useNeoColorGen {
            if i == 0 {
                css += """
.branch-label\(i) { fill: \(nodeBorder);}
.commit\(i) { stroke: \(nodeBorder); }
.commit-highlight\(i) { stroke: \(nodeBorder); fill: \(nodeBorder); }
.arrow\(i) { stroke: \(nodeBorder); }
.commit-bullets { fill: \(nodeBorder); }
.commit-cherry-pick\(i) { stroke: \(nodeBorder); }

"""
            } else {
                let git = _gitGraphThemeValue(options, prefix: "git", index: ci, fallback: "#333")
                let gitInv = _gitGraphThemeValue(options, prefix: "gitInv", index: ci, fallback: "#fff")
                let branchLabel = _gitGraphThemeValue(options, prefix: "gitBranchLabel", index: ci, fallback: git)
                css += """
.branch-label\(i) { fill: \(branchLabel); }
.commit\(i) { stroke: \(git); fill: \(git); }
.commit-highlight\(i) { stroke: \(gitInv); fill: \(gitInv); }
.arrow\(i) { stroke: \(git); }

"""
            }
        } else {
            let git = _gitGraphThemeValue(options, prefix: "git", index: ci, fallback: "#333")
            let gitInv = _gitGraphThemeValue(options, prefix: "gitInv", index: ci, fallback: "#fff")
            let branchLabel = _gitGraphThemeValue(options, prefix: "gitBranchLabel", index: ci, fallback: git)
            css += """
.branch-label\(i) { fill: \(branchLabel);\(fontWeightCSS) }
.commit\(i) { stroke: \(git); fill: \(git); }
.commit-highlight\(i) { stroke: \(gitInv); fill: \(gitInv); }
.label\(i) { fill: \(git); }
.arrow\(i) { stroke: \(git); }

"""
        }
    }

    let neoDashArray = useNeoColorGen ? "4 2" : "2"

    css += """
.commit-id,
.commit-msg,
.branch-label {
  fill: lightgrey;
  color: lightgrey;
  font-family: var(--mermaid-font-family);
}

.branch {
  stroke-width: \(strokeWidth);
  stroke: \(commitLineColor);
  stroke-dasharray: \(neoDashArray);
}
.commit-label { font-size: \(commitLabelFontSize); fill: \(useNeoColorGen ? nodeBorder : commitLabelColor);\(useNeoColorGen && !noteFontWeight.isEmpty ? " font-weight:\(noteFontWeight);" : "") }
.commit-label-bkg { font-size: \(commitLabelFontSize); fill: \(useNeoColorGen ? "transparent" : commitLabelBkg);\(useNeoColorGen ? "" : " opacity: 0.5;") }
.tag-label { font-size: \(tagLabelFontSize); fill: \(tagLabelColor); }
.tag-label-bkg { fill: \(useNeoColorGen ? mainBkg : tagLabelBkg); stroke: \(useNeoColorGen ? nodeBorder : tagLabelBorder);\(useNeoColorGen ? " filter:\(dropShadow);" : "") }
.tag-hole { fill: \(textColor); }
.commit-merge {
  stroke: \(useNeoColorGen ? mainBkg : primaryColor);
  fill: \(useNeoColorGen ? mainBkg : primaryColor);
}
.commit-reverse {
  stroke: \(useNeoColorGen ? mainBkg : primaryColor);
  fill: \(useNeoColorGen ? mainBkg : primaryColor);
  stroke-width: \(useNeoColorGen ? strokeWidth : "3");
}
.commit-highlight-outer {}
.commit-highlight-inner {
  stroke: \(useNeoColorGen ? mainBkg : primaryColor);
  fill: \(useNeoColorGen ? mainBkg : primaryColor);
}
.arrow {
  stroke-width: \(useReduxGeometry ? strokeWidth : "8");
  stroke-linecap: round;
  fill: none;
}
.gitTitleText {
  text-anchor: middle;
  font-size: 18px;
  fill: \(textColor);
}
"""

    return css
}

// MARK: - SVG Rendering

public func renderGitGraphSvg(_ positioned: PositionedGitGraphDiagram, diagramId: String? = nil, theme _: GitGraphThemeConfig? = nil) -> String {
    var svg = ""

    func tag(_ name: String, _ attrs: [String: String], close: Bool = false) -> String {
        var s = "<\(name)"
        for (k, v) in attrs.sorted(by: { $0.key < $1.key }) {
            s += " \(k)=\"\(v)\""
        }
        s += close ? "/>" : ">"
        return s
    }

    let svgId = diagramId ?? UUID().uuidString
    let vb = "0 0 \(Int(positioned.width)) \(Int(positioned.height))"
    svg += "<svg id=\"gitgraph-\(svgId)\" viewBox=\"\(vb)\" width=\"\(Int(positioned.width))\" height=\"\(Int(positioned.height))\" xmlns=\"http://www.w3.org/2000/svg\">\n"

    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "  <title>\(_gitGraphEscapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "  <desc>\(_gitGraphEscapeXml(accDescr))</desc>\n"
    }

    // CSS style block
    let themeConfig = positioned.theme
    let styleCSS = _gitGraphGenerateStyles(themeConfig, positioned: positioned)
    svg += "  <style>\n\(styleCSS)  </style>\n"

    let isNeo = _gitGraphIsNeo(positioned.themeName)
    let isLookNeo = positioned.look == "neo" || isNeo
    let useReduxGeometry = _gitGraphIsReduxGeometry(positioned.themeName)
    let isDark = _gitGraphIsDark(positioned.themeName)
    let useNeoColorGen = _gitGraphIsNeoColorGen(positioned.themeName)

    // Gradient defs for neo look
    if themeConfig.useGradient && useNeoColorGen {
        let gradStart = _gitGraphEscapeXml(themeConfig.gradientStart ?? "#ffffff")
        let gradStop = _gitGraphEscapeXml(themeConfig.gradientStop ?? "#000000")
        svg += "  <defs>\n"
        svg += "    <linearGradient id=\"\(svgId)-gradient\" gradientUnits=\"objectBoundingBox\" x1=\"0%\" y1=\"0%\" x2=\"100%\" y2=\"0%\">\n"
        svg += "      <stop offset=\"0%\" stop-color=\"\(gradStart)\" stop-opacity=\"1\" />\n"
        svg += "      <stop offset=\"100%\" stop-color=\"\(gradStop)\" stop-opacity=\"1\" />\n"
        svg += "    </linearGradient>\n"
        svg += "  </defs>\n"
    }

    // Drop-shadow filter for neo+redux
    let hasDropShadow = isNeo && useReduxGeometry
    if hasDropShadow {
        let filterColor = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.filterColor ?? "", fallback: "#000000"))
        svg += "  <defs>\n"
        svg += "    <filter id=\"\(svgId)-drop-shadow\" height=\"130%\" width=\"130%\">\n"
        svg += "      <feDropShadow dx=\"4\" dy=\"4\" stdDeviation=\"0\" flood-opacity=\"0.06\" flood-color=\"\(filterColor)\" />\n"
        svg += "    </filter>\n"
        svg += "  </defs>\n"
    }

    // Arrow marker
    svg += "  <defs>\n"
    svg += "    <marker id=\"arrowhead-\(svgId)\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"6\" markerHeight=\"6\" orient=\"auto\">\n"
    svg += "      <path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#666\" />\n"
    svg += "    </marker>\n"
    svg += "  </defs>\n"

    let reduxRadius: Double = useReduxGeometry ? 7 : 10
    let reduxInnerRadius: Double = useReduxGeometry ? 5 : 6
    let reduxCross: Double = useReduxGeometry ? 4 : 5
    let reduxRStr = "\(Int(reduxRadius))"
    let reduxInnerRStr = "\(Int(reduxInnerRadius))"
    let reduxCrossD = reduxCross

    // Commit bullets
    let bulletsContent = tagged("g", ["class": "commit-bullets"], {
        var lines: [String] = []
        for commit in positioned.commits {
            let cx = commit.x
            let cy = commit.y
            let colorClass = "commit \(commit.id) commit\(commit.colorIndex)"
            let branchColor = _gitGraphEscapeXml(_gitGraphBranchColor(themeConfig, commit.colorIndex))
            let inverseColor = isDark ? "#000000" : (_gitGraphEscapeXml(_gitGraphInverseColor(themeConfig, commit.colorIndex)))
            let borderColor = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.nodeBorder, fallback: branchColor))
            let effectiveType = commit.customType ?? commit.type
            let typeClass: String
            switch commit.type {
            case .normal: typeClass = "commit-normal"
            case .reverse: typeClass = "commit-reverse"
            case .highlight: typeClass = "commit-highlight"
            case .merge: typeClass = "commit-merge"
            case .cherryPick: typeClass = "commit-cherry-pick"
            }

            switch effectiveType {
            case .highlight:
                let outerSize = reduxRadius * 2
                let innerSize = useReduxGeometry ? 8.0 : 12.0
                let outerOffset: Double = useReduxGeometry ? 3 : 0
                let innerOffset: Double = useReduxGeometry ? 2 : 0
                lines.append("<rect x=\"\(cx - 10 + outerOffset)\" y=\"\(cy - 10 + outerOffset)\" width=\"\(outerSize)\" height=\"\(outerSize)\" class=\"\(colorClass) commit-highlight\(commit.colorIndex) \(typeClass)-outer\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
                lines.append("<rect x=\"\(cx - 6 + innerOffset)\" y=\"\(cy - 6 + innerOffset)\" width=\"\(innerSize)\" height=\"\(innerSize)\" class=\"commit \(commit.id) commit\(commit.colorIndex) \(typeClass)-inner\" fill=\"\(inverseColor)\" />")
            case .cherryPick:
                let dotRadius: Double = useReduxGeometry ? 2.5 : 2.75
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(reduxRStr)\" class=\"\(colorClass) \(typeClass)\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
                lines.append("<circle cx=\"\(cx - 3)\" cy=\"\(cy + 2)\" r=\"\(dotRadius)\" fill=\"\(inverseColor)\" class=\"commit \(commit.id) \(typeClass)\" />")
                lines.append("<circle cx=\"\(cx + 3)\" cy=\"\(cy + 2)\" r=\"\(dotRadius)\" fill=\"\(inverseColor)\" class=\"commit \(commit.id) \(typeClass)\" />")
                lines.append("<line x1=\"\(cx + 3)\" y1=\"\(cy + 1)\" x2=\"\(cx)\" y2=\"\(cy - 5)\" stroke=\"\(inverseColor)\" class=\"commit \(commit.id) \(typeClass)\" />")
                lines.append("<line x1=\"\(cx - 3)\" y1=\"\(cy + 1)\" x2=\"\(cx)\" y2=\"\(cy - 5)\" stroke=\"\(inverseColor)\" class=\"commit \(commit.id) \(typeClass)\" />")
            case .merge:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(reduxRStr)\" class=\"\(colorClass) \(typeClass)\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(reduxInnerRStr)\" class=\"commit \(typeClass) \(commit.id) commit\(commit.colorIndex)\" fill=\"\(inverseColor)\" />")
            case .reverse:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(reduxRStr)\" class=\"\(colorClass) \(typeClass)\" fill=\"\(inverseColor)\" stroke=\"\(branchColor)\" />")
                lines.append("<path d=\"M \(cx - reduxCrossD) \(cy - reduxCrossD) L \(cx + reduxCrossD) \(cy + reduxCrossD) M \(cx + reduxCrossD) \(cy - reduxCrossD) L \(cx - reduxCrossD) \(cy + reduxCrossD)\" stroke=\"\(branchColor)\" class=\"commit \(typeClass) \(commit.id) commit\(commit.colorIndex)\" />")
            default:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"\(reduxRStr)\" class=\"\(colorClass) \(typeClass)\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
            }
        }
        return lines
    })

    svg += bulletsContent

    // Commit labels + tags
    if positioned.config.showCommitLabel || positioned.commits.contains(where: { !$0.tags.isEmpty }) {
        let labels = tagged("g", ["class": "commit-labels"], {
            var lines: [String] = []
            let isVertical = positioned.direction == .TB || positioned.direction == .BT
            let showLabelConfig = positioned.config.showCommitLabel
            for commit in positioned.commits {
                if showLabelConfig && commit.showLabel {
                    let labelText = _gitGraphEscapeXml(commit.id)
                    let labelLen = Double(labelText.count) * 4
                    let textColor = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.commitLabelColor, fallback: "#333333"))
                    let background = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.commitLabelBackground, fallback: "#f2f2f2"))
                    let fontSize = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.commitLabelFontSize, fallback: "12"))
                    if isVertical {
                        let lx = commit.x - labelLen * 2 - 20
                        let ly = commit.y
                        lines.append("<g>")
                        lines.append("  <rect x=\"\(lx - 4)\" y=\"\(ly - 8)\" width=\"\(labelLen * 4 + 8)\" height=\"16\" class=\"commit-label-bkg\" rx=\"3\" fill=\"\(background)\" />")
                        lines.append("  <text x=\"\(lx)\" y=\"\(ly + 3)\" class=\"commit-label\" font-size=\"\(fontSize)\" fill=\"\(textColor)\">\(labelText)</text>")
                        lines.append("</g>")
                    } else {
                        let lx = commit.x - labelLen
                        let ly = commit.y + 20
                        let transform = positioned.config.rotateCommitLabel ? " transform=\"rotate(-45 \(commit.x) \(commit.y))\"" : ""
                        lines.append("<g\(transform)>")
                        lines.append("  <rect x=\"\(lx - 4)\" y=\"\(ly - 4)\" width=\"\(labelLen * 2 + 8)\" height=\"18\" class=\"commit-label-bkg\" rx=\"3\" fill=\"\(background)\" />")
                        lines.append("  <text x=\"\(lx + 4)\" y=\"\(ly + 10)\" class=\"commit-label\" font-size=\"\(fontSize)\" fill=\"\(textColor)\">\(labelText)</text>")
                        lines.append("</g>")
                    }
                }

                guard !commit.tags.isEmpty else { continue }
                let tagTextColor = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.tagLabelColor, fallback: "#333333"))
                let tagBackground = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.tagLabelBackground, fallback: "#eeeeee"))
                let tagBorder = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.tagLabelBorder, fallback: "#777777"))
                let tagFontSize = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.tagLabelFontSize, fallback: "10"))
                for (tagIndex, rawTag) in commit.tags.reversed().enumerated() {
                    let tagText = _gitGraphEscapeXml(rawTag)
                    let tagWidth = Double(max(rawTag.count, 1)) * 7 + 22
                    let tagHeight: Double = 16
                    if isVertical {
                        let yOrigin = commit.y - 16 - Double(tagIndex) * 20
                        let xOrigin = commit.x + 20
                        lines.append("<polygon points=\"\(xOrigin),\(yOrigin + 2) \(xOrigin),\(yOrigin - 2) \(xOrigin + 10),\(yOrigin - tagHeight/2 - 2) \(xOrigin + 10 + tagWidth),\(yOrigin - tagHeight/2 - 2) \(xOrigin + 10 + tagWidth),\(yOrigin + tagHeight/2 + 2) \(xOrigin + 10),\(yOrigin + tagHeight/2 + 2)\" class=\"tag-label-bkg\" fill=\"\(tagBackground)\" stroke=\"\(tagBorder)\" transform=\"translate(12,12) rotate(45 \(commit.x) \(yOrigin))\" />")
                        lines.append("<circle cx=\"\(xOrigin + 2)\" cy=\"\(yOrigin)\" r=\"1.5\" class=\"tag-hole\" fill=\"\(tagBorder)\" transform=\"translate(12,12) rotate(45 \(commit.x) \(yOrigin))\" />")
                        lines.append("<text x=\"\(xOrigin + 5)\" y=\"\(yOrigin + 3)\" class=\"tag-label\" font-size=\"\(tagFontSize)\" fill=\"\(tagTextColor)\" transform=\"translate(14,14) rotate(45 \(commit.x) \(yOrigin))\">\(tagText)</text>")
                    } else {
                        let x = commit.x - tagWidth / 2
                        let y = commit.y - 34 - Double(tagIndex) * 20
                        let points = "\(x),\(y + tagHeight / 2) \(x + 8),\(y) \(x + tagWidth),\(y) \(x + tagWidth),\(y + tagHeight) \(x + 8),\(y + tagHeight)"
                        lines.append("<polygon points=\"\(points)\" class=\"tag-label-bkg\" fill=\"\(tagBackground)\" stroke=\"\(tagBorder)\" />")
                        lines.append("<circle cx=\"\(x + 7)\" cy=\"\(y + tagHeight / 2)\" r=\"1.5\" class=\"tag-hole\" fill=\"\(tagBorder)\" />")
                        lines.append("<text x=\"\(x + 14)\" y=\"\(y + 11)\" class=\"tag-label\" font-size=\"\(tagFontSize)\" fill=\"\(tagTextColor)\">\(tagText)</text>")
                    }
                }
            }
            return lines
        })
        svg += labels
    }

    // Arrows
    let arrowsBlock = tagged("g", ["class": "commit-arrows"], {
        var lines: [String] = []
        for arrow in positioned.arrows {
            var pathStr = ""
            for (i, segment) in arrow.segments.enumerated() {
                switch segment {
                case .line(let from, let to):
                    pathStr += i == 0 ? "M \(from.x) \(from.y) L \(to.x) \(to.y)" : " L \(to.x) \(to.y)"
                case .cubic(let from, let c1, let c2, let to):
                    pathStr += i == 0 ? "M \(from.x) \(from.y) C \(c1.x) \(c1.y) \(c2.x) \(c2.y) \(to.x) \(to.y)" : " C \(c1.x) \(c1.y) \(c2.x) \(c2.y) \(to.x) \(to.y)"
                case .arc(let from, let to, let rx, let ry, let xRot, let large, let sweep):
                    pathStr += i == 0 ? "M \(from.x) \(from.y) A \(rx) \(ry) \(xRot) \(large ? 1 : 0) \(sweep ? 1 : 0) \(to.x) \(to.y)" : " A \(rx) \(ry) \(xRot) \(large ? 1 : 0) \(sweep ? 1 : 0) \(to.x) \(to.y)"
                }
            }
            let stroke = _gitGraphEscapeXml(_gitGraphBranchColor(themeConfig, arrow.colorIndex))
            lines.append("<path d=\"\(pathStr)\" class=\"arrow \(arrow.arrowClass) branch\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"2\" marker-end=\"url(#arrowhead-\(svgId))\" />")
        }
        return lines
    })
    svg += arrowsBlock

    // Branch lines
    if positioned.config.showBranches {
        var branchLinesStr = ""
        for bl in positioned.branchLines {
            let stroke = _gitGraphEscapeXml(_gitGraphBranchColor(themeConfig, bl.colorIndex))
            branchLinesStr += "<line x1=\"\(bl.x1)\" y1=\"\(bl.y1)\" x2=\"\(bl.x2)\" y2=\"\(bl.y2)\" class=\"branch branch\(bl.colorIndex)\" stroke=\"\(stroke)\" stroke-width=\"1\" stroke-dasharray=\"\(useNeoColorGen ? "4,2" : "2")\" />\n"
        }
        svg += branchLinesStr

        // Branch labels
        var branchLabelsStr = ""
        for bl in positioned.branchLabels {
            let lines = bl.lines
            var textContent = ""
            for (j, line) in lines.enumerated() {
                let dy: String
                if lines.count == 1 {
                    dy = "0"
                } else if j == 0 {
                    dy = "\(-0.55 * Double(lines.count - 1))em"
                } else {
                    dy = "1.1em"
                }
                textContent += "<tspan x=\"0\" dy=\"\(dy)\">\(_gitGraphEscapeXml(line))</tspan>"
            }
            let labelFill = _gitGraphEscapeXml(_gitGraphBranchLabelColor(themeConfig, bl.colorIndex))
            let textFill = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.labelTextColor, fallback: "#ffffff"))
            let useRedux = useReduxGeometry
            let filterStyle: String
            if isLookNeo {
                filterStyle = useRedux ? " filter:url(#\(svgId)-drop-shadow)" : " filter:\(themeConfig.dropShadow ?? "")"
            } else {
                filterStyle = ""
            }
            branchLabelsStr += "<g transform=\"translate(\(bl.x) \(bl.y))\" class=\"branchLabel label\">\n"
            branchLabelsStr += "  <rect x=\"\(bl.bkgX)\" y=\"\(bl.bkgY)\" width=\"\(bl.bkgWidth)\" height=\"\(bl.bkgHeight)\" rx=\"\(bl.borderRadius)\" ry=\"\(bl.borderRadius)\" class=\"branchLabelBkg label\(bl.colorIndex)\" fill=\"\(labelFill)\"\(isLookNeo ? " data-look=\"neo\"" : "") style=\"\(filterStyle)\" />\n"
            branchLabelsStr += "  <text class=\"branch-label branch-label\(bl.colorIndex)\" fill=\"\(textFill)\" text-anchor=\"middle\" dominant-baseline=\"middle\">\(textContent)</text>\n"
            branchLabelsStr += "</g>\n"
        }
        svg += branchLabelsStr
    }

    // Title
    if let title = positioned.title {
        let escText = _gitGraphEscapeXml(title.text)
        let titleColor = _gitGraphEscapeXml(_gitGraphResolved(themeConfig.textColor, fallback: "#333333"))
        svg += "<text x=\"\(title.x)\" y=\"\(title.y)\" class=\"gitTitleText\" text-anchor=\"middle\" font-size=\"18\" fill=\"\(titleColor)\">\(escText)</text>\n"
    }

    svg += "</svg>\n"

    return svg
}

// MARK: - SVG Tag Helper

private func tagged(_ name: String, _ attrs: [String: String], _ fn: () -> [String]) -> String {
    var result = "  <\(name)"
    for (k, v) in attrs.sorted(by: { $0.key < $1.key }) {
        result += " \(k)=\"\(v)\""
    }
    result += ">\n"
    for line in fn() {
        result += "    \(line)\n"
    }
    result += "  </\(name)>\n"
    return result
}
