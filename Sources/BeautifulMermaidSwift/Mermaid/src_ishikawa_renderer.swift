import Foundation

public func renderIshikawaSvg(
    _ positioned: PositionedIshikawaDiagram,
    diagramId: String,
    colors: DiagramColors,
    fontFamily: String,
    transparent: Bool
) -> String {
    let bg = transparent ? "none" : colors.bg
    let fg = colors.fg
    let lineColor = colors.line ?? "#333"
    let mainBkg = colors.surface ?? colors.bg
    let textColor = fg
    let fontSize = 14.0
    let viewBox = positioned.viewBox
    let vbx = viewBox.origin.x
    let vby = viewBox.origin.y
    let vbw = viewBox.size.width
    let vbh = viewBox.size.height

    var svg = ""
    var attrs = [
        "xmlns=\"http://www.w3.org/2000/svg\"",
        "viewBox=\"\(vbx) \(vby) \(vbw) \(vbh)\""
    ]
    var styles: [String] = []
    if positioned.config.useMaxWidth {
        attrs.append("width=\"100%\"")
        styles.append("max-width: \(vbw)px")
    } else {
        attrs.append("width=\"\(vbw)\"")
        attrs.append("height=\"\(vbh)\"")
    }
    if !fontFamily.isEmpty {
        styles.append("font-family:\(fontFamily)")
    }
    if !styles.isEmpty {
        attrs.append("style=\"\(styles.joined(separator: "; "))\"")
    }
    svg += "<svg \(attrs.joined(separator: " "))"
    svg += ">"
    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(bg)\"/>"
    }

    let markerId = "ishikawa-arrow-\(diagramId)"

    svg += "<g class=\"ishikawa\">"

    svg += "<defs>"
    svg += "<marker id=\"\(markerId)\" viewBox=\"0 0 10 10\" refX=\"0\" refY=\"5\" markerWidth=\"6\" markerHeight=\"6\" orient=\"auto\">"
    svg += "<path d=\"M 10 0 L 0 5 L 10 10 Z\" class=\"ishikawa-arrow\" fill=\"\(lineColor)\"/>"
    svg += "</marker>"
    svg += "</defs>"

    if let head = positioned.head {
        svg += "<g class=\"ishikawa-head-group\" transform=\"translate(\(head.x),\(head.y))\">"
        svg += "<path class=\"ishikawa-head\" d=\"\(head.path)\" fill=\"\(mainBkg)\" stroke=\"\(lineColor)\"/>"
        svg += "<text class=\"ishikawa-head-label\" text-anchor=\"start\" transform=\"translate(\(head.labelX),\(head.labelY))\" fill=\"\(textColor)\" font-size=\"\(fontSize)\" font-weight=\"600\">"
        for (i, line) in head.lines.enumerated() {
            let dy = i == 0 ? 0 : fontSize * 1.05
            svg += "<tspan x=\"0.0\" dy=\"\(dy)\">\(_ishikawaSvgEscape(line))</tspan>"
        }
        svg += "</text>"
        svg += "</g>"
    }

    let sortedBones = positioned.bones.sorted(by: { $0.id < $1.id })
    let branchBones = sortedBones.filter { $0.kind == .branch }
    let subBranchBones = sortedBones.filter { $0.kind == .subBranch }

    for bone in sortedBones where bone.kind == .spine {
        svg += _ishikawaLineSvg(bone, lineColor: lineColor, markerId: markerId)
    }

    for pairStart in stride(from: 0, to: branchBones.count, by: 2) {
        svg += "<g class=\"ishikawa-pair\">"
        let pairEnd = min(pairStart + 2, branchBones.count)
        for branchIndex in pairStart..<pairEnd {
            let branch = branchBones[branchIndex]
            let nextBranchId = branchIndex + 1 < branchBones.count ? branchBones[branchIndex + 1].id : Int.max

            svg += _ishikawaLineSvg(branch, lineColor: lineColor, markerId: markerId)
            for label in positioned.labels where label.labelClass == .cause && label.parentBoneId == branch.id {
                svg += _ishikawaCauseLabelSvg(label, mainBkg: mainBkg, textColor: textColor, fontSize: fontSize)
            }

            for subBranch in subBranchBones where subBranch.id > branch.id && subBranch.id < nextBranchId {
                svg += "<g class=\"ishikawa-sub-group\">"
                svg += _ishikawaLineSvg(subBranch, lineColor: lineColor, markerId: markerId)
                for label in positioned.labels where label.labelClass != .cause && label.parentBoneId == subBranch.id {
                    svg += _ishikawaSubLabelSvg(label, textColor: textColor, fontSize: fontSize)
                }
                svg += "</g>"
            }
        }
        svg += "</g>"
    }

    svg += "</g>"
    svg += "</svg>"
    return svg
}

private func _ishikawaLineSvg(_ bone: PositionedIshikawaBone, lineColor: String, markerId: String) -> String {
    let markerAttr = bone.marker == .normalArrowAtStart ? " marker-start=\"url(#\(markerId))\"" : ""
    let cls: String
    switch bone.kind {
    case .spine: cls = "ishikawa-spine"
    case .branch: cls = "ishikawa-branch"
    case .subBranch: cls = "ishikawa-sub-branch"
    }
    return "<line class=\"\(cls)\" x1=\"\(bone.x1)\" y1=\"\(bone.y1)\" x2=\"\(bone.x2)\" y2=\"\(bone.y2)\" stroke=\"\(lineColor)\"\(markerAttr)/>"
}

private func _ishikawaCauseLabelSvg(
    _ label: PositionedIshikawaLabel,
    mainBkg: String,
    textColor: String,
    fontSize: Double
) -> String {
    var svg = "<g class=\"ishikawa-label-group\">"
    if let box = label.box {
        svg += "<rect class=\"ishikawa-label-box\" x=\"\(box.x)\" y=\"\(box.y)\" width=\"\(box.width)\" height=\"\(box.height)\" fill=\"\(mainBkg)\" stroke=\"\(mainBkg)\"/>"
    }
    svg += "<text class=\"ishikawa-label cause\" text-anchor=\"middle\" x=\"\(label.x)\" y=\"\(label.y)\" fill=\"\(textColor)\" font-size=\"\(fontSize)\">"
    svg += _ishikawaTspans(label.lines, x: label.x, fontSize: fontSize)
    svg += "</text>"
    svg += "</g>"
    return svg
}

private func _ishikawaSubLabelSvg(
    _ label: PositionedIshikawaLabel,
    textColor: String,
    fontSize: Double
) -> String {
    let anchor = label.anchor == .start ? "start" : (label.anchor == .end ? "end" : "middle")
    let cls: String
    switch label.labelClass {
    case .align: cls = "ishikawa-label align"
    case .up: cls = "ishikawa-label up"
    case .down: cls = "ishikawa-label down"
    default: cls = "ishikawa-label"
    }

    var svg = "<text class=\"\(cls)\" text-anchor=\"\(anchor)\" x=\"\(label.x)\" y=\"\(label.y)\" fill=\"\(textColor)\" font-size=\"\(fontSize)\">"
    svg += _ishikawaTspans(label.lines, x: label.x, fontSize: fontSize)
    svg += "</text>"
    return svg
}

private func _ishikawaTspans(_ lines: [String], x: Double, fontSize: Double) -> String {
    var svg = ""
    for (i, line) in lines.enumerated() {
        let dy = i == 0 ? 0 : fontSize * 1.05
        svg += "<tspan x=\"\(x)\" dy=\"\(dy)\">\(_ishikawaSvgEscape(line))</tspan>"
    }
    return svg
}

private func _ishikawaSvgEscape(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}
