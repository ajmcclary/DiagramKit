import Foundation
import DiagramKitCommon

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
    let _builder = SVGDocumentBuilder(
        width: vbw, height: vbh,
        colors: colors, transparent: transparent,
        fontFamily: fontFamily,
        useMaxWidth: positioned.config.useMaxWidth,
        viewBoxX: vbx, viewBoxY: vby
    )
    svg += _builder.open() + ">"
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

    let cssBlock = _ishikawaCssBlock(lineColor: lineColor, mainBkg: mainBkg, textColor: textColor, fontFamily: fontFamily, fontSize: fontSize)
    svg += "<style>\n"
    svg += cssBlock
    svg += "\n</style>"

    if let head = positioned.head {
        svg += "<g class=\"ishikawa-head-group\" transform=\"translate(\(head.x),\(head.y))\">"
        svg += "<path class=\"ishikawa-head\" d=\"\(head.path)\" fill=\"\(mainBkg)\" stroke=\"\(lineColor)\" stroke-width=\"2\"/>"
        svg += "<text class=\"ishikawa-head-label\" text-anchor=\"middle\" dominant-baseline=\"middle\" transform=\"translate(\(head.labelX),\(head.labelY))\" fill=\"\(textColor)\" font-size=\"\(fontSize)\" font-weight=\"600\">"
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
                svg += _ishikawaCauseLabelSvg(label, mainBkg: mainBkg, lineColor: lineColor, textColor: textColor, fontSize: fontSize)
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
    svg += _builder.close()
    return svg
}

private func _ishikawaLineSvg(_ bone: PositionedIshikawaBone, lineColor: String, markerId: String) -> String {
    let markerAttr = bone.marker == .normalArrowAtStart ? " marker-start=\"url(#\(markerId))\"" : ""
    let cls: String
    let strokeWidth: Int
    switch bone.kind {
    case .spine:
        cls = "ishikawa-spine"
        strokeWidth = 2
    case .branch:
        cls = "ishikawa-branch"
        strokeWidth = 2
    case .subBranch:
        cls = "ishikawa-sub-branch"
        strokeWidth = 1
    }
    return "<line class=\"\(cls)\" x1=\"\(bone.x1)\" y1=\"\(bone.y1)\" x2=\"\(bone.x2)\" y2=\"\(bone.y2)\" stroke=\"\(lineColor)\" stroke-width=\"\(strokeWidth)\"\(markerAttr)/>"
}

private func _ishikawaCauseLabelSvg(
    _ label: PositionedIshikawaLabel,
    mainBkg: String,
    lineColor: String,
    textColor: String,
    fontSize: Double
) -> String {
    var svg = "<g class=\"ishikawa-label-group\">"
    if let box = label.box {
        svg += "<rect class=\"ishikawa-label-box\" x=\"\(box.x)\" y=\"\(box.y)\" width=\"\(box.width)\" height=\"\(box.height)\" fill=\"\(mainBkg)\" stroke=\"\(lineColor)\" stroke-width=\"2\"/>"
    }
    svg += "<text class=\"ishikawa-label cause\" text-anchor=\"middle\" dominant-baseline=\"middle\" x=\"\(label.x)\" y=\"\(label.y)\" fill=\"\(textColor)\" font-size=\"\(fontSize)\">"
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
    let baseline: String
    switch label.labelClass {
    case .align:
        cls = "ishikawa-label align"
        baseline = "middle"
    case .up:
        cls = "ishikawa-label up"
        baseline = "baseline"
    case .down:
        cls = "ishikawa-label down"
        baseline = "hanging"
    default:
        cls = "ishikawa-label"
        baseline = "baseline"
    }

    var svg = "<text class=\"\(cls)\" text-anchor=\"\(anchor)\" dominant-baseline=\"\(baseline)\" x=\"\(label.x)\" y=\"\(label.y)\" fill=\"\(textColor)\" font-size=\"\(fontSize)\">"
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
    SVG.escapeText(text)
}

private func _ishikawaCssBlock(lineColor: String, mainBkg: String, textColor: String, fontFamily: String, fontSize: Double) -> String {
    let ff = fontFamily.isEmpty ? "sans-serif" : fontFamily
    return """
.ishikawa .ishikawa-spine,
.ishikawa .ishikawa-branch,
.ishikawa .ishikawa-sub-branch {
  stroke: \(lineColor);
  fill: none;
}
.ishikawa .ishikawa-spine,
.ishikawa .ishikawa-branch {
  stroke-width: 2;
}
.ishikawa .ishikawa-sub-branch {
  stroke-width: 1;
}
.ishikawa .ishikawa-arrow {
  fill: \(lineColor);
}
.ishikawa .ishikawa-head {
  fill: \(mainBkg);
  stroke: \(lineColor);
  stroke-width: 2;
}
.ishikawa .ishikawa-label-box {
  fill: \(mainBkg);
  stroke: \(lineColor);
  stroke-width: 2;
}
.ishikawa text {
  font-family: \(ff);
  font-size: \(formatIshikawaCssFontSize(fontSize));
  fill: \(textColor);
}
.ishikawa .ishikawa-head-label {
  font-weight: 600;
  text-anchor: middle;
  dominant-baseline: middle;
  font-size: 14px;
}
.ishikawa .ishikawa-label {
  text-anchor: end;
}
.ishikawa .ishikawa-label.cause {
  text-anchor: middle;
  dominant-baseline: middle;
}
.ishikawa .ishikawa-label.align {
  text-anchor: end;
  dominant-baseline: middle;
}
.ishikawa .ishikawa-label.up {
  dominant-baseline: baseline;
}
.ishikawa .ishikawa-label.down {
  dominant-baseline: hanging;
}
"""
}

private func formatIshikawaCssFontSize(_ size: Double) -> String {
    let rounded = round(size * 10) / 10
    return "\(rounded)px"
}
