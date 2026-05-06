import Foundation

// MARK: - SVG Escape

func _gitGraphEscapeXml(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
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

// MARK: - SVG Rendering

public func renderGitGraphSvg(_ positioned: PositionedGitGraphDiagram, theme _: GitGraphThemeConfig? = nil) -> String {
    var svg = ""

    func tag(_ name: String, _ attrs: [String: String], close: Bool = false) -> String {
        var s = "<\(name)"
        for (k, v) in attrs.sorted(by: { $0.key < $1.key }) {
            s += " \(k)=\"\(v)\""
        }
        s += close ? "/>" : ">"
        return s
    }

    func openTag(_ name: String, _ attrs: [String: String]) -> String {
        tag(name, attrs)
    }

    func closeTag(_ name: String) -> String {
        "</\(name)>"
    }

    let svgId = UUID().uuidString
    let vb = "0 0 \(Int(positioned.width)) \(Int(positioned.height))"
    svg += "<svg id=\"gitgraph-\(svgId)\" viewBox=\"\(vb)\" width=\"\(Int(positioned.width))\" height=\"\(Int(positioned.height))\" xmlns=\"http://www.w3.org/2000/svg\">\n"

    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "  <title>\(_gitGraphEscapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "  <desc>\(_gitGraphEscapeXml(accDescr))</desc>\n"
    }

    func drawArrowMarker() -> String {
        var m = ""
        m += "  <defs>\n"
        m += "    <marker id=\"arrowhead-\(svgId)\" viewBox=\"0 0 10 10\" refX=\"9\" refY=\"5\" markerWidth=\"6\" markerHeight=\"6\" orient=\"auto\">\n"
        m += "      <path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#666\" />\n"
        m += "    </marker>\n"
        m += "  </defs>\n"
        return m
    }

    svg += drawArrowMarker()

    let PX = tagged("g", ["class": "commit-bullets"], {
        var lines: [String] = []
        for commit in positioned.commits {
            let cx = commit.x
            let cy = commit.y
            let colorClass = "commit commit\(commit.colorIndex)"
            let branchColor = _gitGraphEscapeXml(_gitGraphBranchColor(positioned.theme, commit.colorIndex))
            let inverseColor = _gitGraphEscapeXml(_gitGraphInverseColor(positioned.theme, commit.colorIndex))
            let borderColor = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.nodeBorder, fallback: branchColor))
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
                lines.append("<rect x=\"\(cx - 10)\" y=\"\(cy - 10)\" width=\"20\" height=\"20\" class=\"\(colorClass) commit-highlight\(commit.colorIndex) \(typeClass)-outer\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
                lines.append("<rect x=\"\(cx - 6)\" y=\"\(cy - 6)\" width=\"12\" height=\"12\" class=\"\(colorClass) \(typeClass)-inner\" fill=\"\(inverseColor)\" />")
            case .cherryPick:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"10\" class=\"\(colorClass) \(typeClass)\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
                lines.append("<circle cx=\"\(cx - 3)\" cy=\"\(cy + 2)\" r=\"3\" fill=\"\(inverseColor)\" class=\"\(colorClass) \(typeClass)\" />")
                lines.append("<circle cx=\"\(cx + 3)\" cy=\"\(cy + 2)\" r=\"3\" fill=\"\(inverseColor)\" class=\"\(colorClass) \(typeClass)\" />")
                lines.append("<line x1=\"\(cx + 3)\" y1=\"\(cy + 1)\" x2=\"\(cx)\" y2=\"\(cy - 5)\" stroke=\"\(inverseColor)\" class=\"\(colorClass) \(typeClass)\" />")
                lines.append("<line x1=\"\(cx - 3)\" y1=\"\(cy + 1)\" x2=\"\(cx)\" y2=\"\(cy - 5)\" stroke=\"\(inverseColor)\" class=\"\(colorClass) \(typeClass)\" />")
            case .merge:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"10\" class=\"\(colorClass) \(typeClass)\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"6\" class=\"\(colorClass) \(typeClass)\" fill=\"\(inverseColor)\" />")
            case .reverse:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"10\" class=\"\(colorClass) \(typeClass)\" fill=\"\(inverseColor)\" stroke=\"\(branchColor)\" />")
                lines.append("<path d=\"M \(cx - 4) \(cy - 4) L \(cx + 4) \(cy + 4) M \(cx + 4) \(cy - 4) L \(cx - 4) \(cy + 4)\" stroke=\"\(branchColor)\" class=\"\(colorClass) \(typeClass)\" />")
            default:
                lines.append("<circle cx=\"\(cx)\" cy=\"\(cy)\" r=\"10\" class=\"\(colorClass) \(typeClass)\" fill=\"\(branchColor)\" stroke=\"\(borderColor)\" />")
            }
        }
        return lines
    })

    svg += PX

    if positioned.config.showCommitLabel || positioned.commits.contains(where: { !$0.tags.isEmpty }) {
        let labels = tagged("g", ["class": "commit-labels"], {
            var lines: [String] = []
            for commit in positioned.commits {
                if positioned.config.showCommitLabel && commit.showLabel {
                    let labelText = _gitGraphEscapeXml(commit.id)
                    let lx = commit.x - Double(labelText.count) * 4
                    let ly = commit.y + 20
                    let textColor = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.commitLabelColor, fallback: "#333333"))
                    let background = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.commitLabelBackground, fallback: "#f2f2f2"))
                    let fontSize = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.commitLabelFontSize, fallback: "12"))
                    let transform = positioned.config.rotateCommitLabel ? " transform=\"rotate(-45 \(commit.x) \(commit.y))\"" : ""
                    lines.append("<g\(transform)>")
                    lines.append("  <rect x=\"\(lx - 4)\" y=\"\(ly - 4)\" width=\"\(Double(labelText.count) * 8 + 8)\" height=\"18\" class=\"commit-label-bkg\" rx=\"3\" fill=\"\(background)\" />")
                    lines.append("  <text x=\"\(lx + 4)\" y=\"\(ly + 10)\" class=\"commit-label\" font-size=\"\(fontSize)\" fill=\"\(textColor)\">\(labelText)</text>")
                    lines.append("</g>")
                }

                guard !commit.tags.isEmpty else { continue }
                let tagTextColor = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.tagLabelColor, fallback: "#333333"))
                let tagBackground = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.tagLabelBackground, fallback: "#eeeeee"))
                let tagBorder = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.tagLabelBorder, fallback: "#777777"))
                let tagFontSize = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.tagLabelFontSize, fallback: "10"))
                for (tagIndex, rawTag) in commit.tags.enumerated() {
                    let tagText = _gitGraphEscapeXml(rawTag)
                    let tagWidth = Double(max(rawTag.count, 1)) * 7 + 22
                    let tagHeight: Double = 16
                    let x = commit.x - tagWidth / 2
                    let y = commit.y - 34 - Double(tagIndex) * 20
                    let points = "\(x),\(y + tagHeight / 2) \(x + 8),\(y) \(x + tagWidth),\(y) \(x + tagWidth),\(y + tagHeight) \(x + 8),\(y + tagHeight)"
                    lines.append("<polygon points=\"\(points)\" class=\"tag-label-bkg\" fill=\"\(tagBackground)\" stroke=\"\(tagBorder)\" />")
                    lines.append("<circle cx=\"\(x + 7)\" cy=\"\(y + tagHeight / 2)\" r=\"1.5\" class=\"tag-hole\" fill=\"\(tagBorder)\" />")
                    lines.append("<text x=\"\(x + 14)\" y=\"\(y + 11)\" class=\"tag-label\" font-size=\"\(tagFontSize)\" fill=\"\(tagTextColor)\">\(tagText)</text>")
                }
            }
            return lines
        })
        svg += labels
    }

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
            let stroke = _gitGraphEscapeXml(_gitGraphBranchColor(positioned.theme, arrow.colorIndex))
            lines.append("<path d=\"\(pathStr)\" class=\"arrow \(arrow.arrowClass) branch\" fill=\"none\" stroke=\"\(stroke)\" stroke-width=\"2\" marker-end=\"url(#arrowhead-\(svgId))\" />")
        }
        return lines
    })
    svg += arrowsBlock

    if positioned.config.showBranches {
        var branchLinesStr = ""
        for bl in positioned.branchLines {
            let stroke = _gitGraphEscapeXml(_gitGraphBranchColor(positioned.theme, bl.colorIndex))
            branchLinesStr += "<line x1=\"\(bl.x1)\" y1=\"\(bl.y1)\" x2=\"\(bl.x2)\" y2=\"\(bl.y2)\" class=\"branch branch\(bl.colorIndex)\" stroke=\"\(stroke)\" stroke-width=\"1\" stroke-dasharray=\"4,2\" />\n"
        }
        svg += branchLinesStr

        var branchLabelsStr = ""
        for bl in positioned.branchLabels {
            let lines = bl.lines
            var textContent = ""
            var dy: Double = 0
            for line in lines {
                textContent += "<tspan x=\"0\" dy=\"\(dy == 0 ? "1em" : "1em")\">\(_gitGraphEscapeXml(line))</tspan>"
                dy += 1
            }
            let labelFill = _gitGraphEscapeXml(_gitGraphBranchLabelColor(positioned.theme, bl.colorIndex))
            let textFill = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.labelTextColor, fallback: "#ffffff"))
            branchLabelsStr += "<g transform=\"translate(\(bl.x) \(bl.y))\" class=\"branchLabel label\">\n"
            branchLabelsStr += "  <rect x=\"\(bl.bkgX)\" y=\"\(bl.bkgY)\" width=\"\(bl.bkgWidth)\" height=\"\(bl.bkgHeight)\" rx=\"\(bl.borderRadius)\" class=\"branchLabelBkg label\(bl.colorIndex)\" fill=\"\(labelFill)\" />\n"
            branchLabelsStr += "  <text class=\"branch-label branch-label\(bl.colorIndex)\" fill=\"\(textFill)\">\(textContent)</text>\n"
            branchLabelsStr += "</g>\n"
        }
        svg += branchLabelsStr
    }

    if let title = positioned.title {
        let escText = _gitGraphEscapeXml(title.text)
        let titleColor = _gitGraphEscapeXml(_gitGraphResolved(positioned.theme.textColor, fallback: "#333333"))
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
