import Foundation

// MARK: - ZenUML SVG Renderer

/// Render a positioned ZenUML diagram to SVG.
/// Skeleton implementation that produces basic SVG output.
public func renderZenUMLSvg(
    _ diagram: PositionedZenUMLDiagram,
    colors: DiagramColors = DiagramColors(bg: "#FFFFFF", fg: "#27272A"),
    font: String = "Helvetica",
    transparent: Bool = false
) -> String {
    let padding: Double = 10
    let frameHeaderHeight: Double = 28
    let frameBorderRadius: Double = 4

    let contentLeftMargin: Double = 1 + padding + diagram.frameBorderLeft
    let viewWidth: Double = max(diagram.width + contentLeftMargin + padding + diagram.frameBorderRight + 1, 100)
    let viewHeight: Double = max(diagram.height + padding * 2 + frameHeaderHeight - 1, 100)

    var parts: [String] = []

    // Groups — behind everything
    for group in diagram.groups {
        parts.append(renderGroup(group))
    }

    // Lifelines — behind participants
    for lifeline in diagram.lifelines {
        parts.append(renderLifeline(lifeline))
    }

    // Occurrences — activation boxes
    for occurrence in diagram.occurrences {
        parts.append(renderOccurrence(occurrence))
    }

    // Participants
    for participant in diagram.participants {
        parts.append(renderParticipant(participant))
    }

    // Messages
    for message in diagram.messages {
        parts.append(renderMessage(message))
    }

    // Self-calls
    for selfCall in diagram.selfCalls {
        parts.append(renderSelfCall(selfCall))
    }

    // Creations
    for creation in diagram.creations {
        parts.append(renderCreation(creation))
    }

    // Fragments — on top of messages
    for fragment in diagram.fragments {
        parts.append(renderFragment(fragment))
    }

    // Returns
    for ret in diagram.returns {
        parts.append(renderReturn(ret))
    }

    // Dividers
    for divider in diagram.dividers {
        parts.append(renderDivider(divider))
    }

    // Comments
    for comment in diagram.comments {
        parts.append(renderComment(comment))
    }

    // Frame
    let r = frameBorderRadius
    let frameSvg = [
        "<rect class=\"frame-border-outer\" x=\"0\" y=\"0\" width=\"\(viewWidth)\" height=\"\(viewHeight)\" rx=\"\(r)\" fill=\"#666\"/>",
        "<rect class=\"frame-border-inner\" x=\"1\" y=\"1\" width=\"\(viewWidth - 2)\" height=\"\(viewHeight - 2)\" rx=\"\(max(0, r - 1))\" fill=\"#fff\"/>",
    ].joined(separator: "\n")

    let headerLineY: Double = frameHeaderHeight + 6
    let headerLineSvg = "<line class=\"frame-header-line\" x1=\"1\" y1=\"\(headerLineY - 0.5)\" x2=\"\(viewWidth - 1)\" y2=\"\(headerLineY - 0.5)\"/>"

    let titleSvg: String
    if let title = diagram.title, !title.isEmpty {
        titleSvg = "<text x=\"5\" y=\"\(headerLineY / 2)\" dominant-baseline=\"central\" class=\"frame-title\">\(escXml(title))</text>"
    } else {
        titleSvg = ""
    }

    let viewBox = "0 0 \(viewWidth) \(viewHeight)"

    let style = """
    <defs>
      <style>
        .frame-border-outer { fill: #666; }
        .frame-border-inner { fill: #ffffff; }
        .frame-header-line { stroke: #666; stroke-width: 1; shape-rendering: crispEdges; }
        .frame-title { font-family: Helvetica, Verdana, serif; font-size: 16px; font-weight: 600; fill: #222; }
        .participant-box { fill: #ffffff; stroke: #666; stroke-width: 2; }
        .participant-label { font-family: Helvetica, Verdana, serif; font-size: 16px; fill: #222; }
        .lifeline { stroke: #666; stroke-width: 1; stroke-dasharray: 5,5; }
        .message-line { stroke: #000; stroke-width: 2; shape-rendering: crispEdges; }
        .message-label { font-family: Helvetica, Verdana, serif; font-size: 14px; fill: #222; }
        .arrow-head { fill: #000; stroke: #000; stroke-width: 2; }
        .arrow-open { fill: none; stroke: #000; stroke-width: 2; }
        .fragment-border { fill: none; stroke: #666; stroke-width: 1; shape-rendering: crispEdges; }
        .fragment-header { fill: #dedede; fill-opacity: 0.498; stroke: none; shape-rendering: crispEdges; }
        .fragment-label { font-family: Helvetica, Verdana, serif; font-size: 14px; font-weight: 600; fill: #000; }
        .return-line { stroke: #000; stroke-width: 2; stroke-dasharray: 6,4; shape-rendering: crispEdges; }
        .return-label { font-family: Helvetica, Verdana, serif; font-size: 14px; fill: #222; }
        .divider-bg { fill: #fff5ad; stroke: #aaaa33; stroke-width: 1; }
        .divider-label { font-family: Helvetica, Verdana, serif; font-size: 14px; fill: #333; }
        .group-outline { fill: none; stroke: #666; stroke-dasharray: 5,5; stroke-width: 1; }
        .group-title-text { font-family: Helvetica, Verdana, serif; font-size: 13px; font-weight: 400; fill: #222; }
      </style>
    </defs>
    """

    let frame = "\(frameSvg)\n\(headerLineSvg)\n\(titleSvg)"
    let content = "<g transform=\"translate(\(contentLeftMargin), \(headerLineY))\">\n\(parts.joined(separator: "\n"))\n</g>"
    let innerSvg = "\(style)\n\(frame)\n\(content)"

    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(viewWidth)\" height=\"\(viewHeight)\" viewBox=\"\(viewBox)\">\n\(innerSvg)\n</svg>"

    return svg
}

// MARK: - SVG Element Renderers

private func renderLifeline(_ lifeline: PositionedZenUMLLifeline) -> String {
    let dashArray = lifeline.dashed ? "stroke-dasharray=\"5,5\"" : "stroke-dasharray=\"none\""
    return "<line class=\"lifeline\" x1=\"\(lifeline.x)\" y1=\"\(lifeline.topY)\" x2=\"\(lifeline.x)\" y2=\"\(lifeline.bottomY)\" \(dashArray)/>"
}

private func renderParticipant(_ participant: PositionedZenUMLParticipant) -> String {
    var parts: [String] = []

    let boxX = participant.x - participant.width / 2
    let boxY = participant.y
    let boxW = participant.width
    let boxH = participant.height

    // Participant box
    parts.append("<rect class=\"participant-box\" x=\"\(boxX)\" y=\"\(boxY)\" width=\"\(boxW)\" height=\"\(boxH)\" rx=\"4\"/>")

    // Label
    let labelX = participant.x
    let labelY = boxY + boxH / 2
    parts.append("<text class=\"participant-label\" x=\"\(labelX)\" y=\"\(labelY)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(participant.label))</text>")

    return parts.joined(separator: "\n")
}

private func renderMessage(_ message: PositionedZenUMLMessage) -> String {
    var parts: [String] = []

    let arrowHeadSize: Double = 8
    let isSelf = message.isSelf
    let isReverse = message.isReverse

    if isSelf {
        // Self-call: U-shape
        let ux = max(0, message.fromX) - 20
        let uw: Double = 40
        let uh: Double = 25
        let uy = message.y
        parts.append("<polyline class=\"message-line\" points=\"\(ux),\(uy) \(ux),\(uy + uh) \(ux + uw),\(uy + uh) \(ux + uw),\(uy)\" fill=\"none\"/>")

        // Arrow head at the return point
        if isReverse {
            parts.append("<polygon class=\"arrow-head\" points=\"\(ux),\(uy) \(ux - arrowHeadSize),\(uy - arrowHeadSize/2) \(ux - arrowHeadSize),\(uy + arrowHeadSize/2)\"/>")
        } else {
            parts.append("<polygon class=\"arrow-head\" points=\"\(ux + uw),\(uy) \(ux + uw + arrowHeadSize),\(uy - arrowHeadSize/2) \(ux + uw + arrowHeadSize),\(uy + arrowHeadSize/2)\"/>")
        }

        // Label on self-call
        parts.append("<text class=\"message-label\" x=\"\(ux + uw / 2)\" y=\"\(uy + uh / 2)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(message.label))</text>")
    } else {
        // Regular message line
        let fromX = message.fromX + (isReverse ? -10 : 10)
        let toX = message.toX + (isReverse ? 10 : -10)

        parts.append("<line class=\"message-line\" x1=\"\(fromX)\" y1=\"\(message.y)\" x2=\"\(toX)\" y2=\"\(message.y)\"/>")

        // Arrow head
        if message.arrowStyle == .open {
            let ax = isReverse ? toX + arrowHeadSize : toX - arrowHeadSize
            parts.append("<line class=\"arrow-open\" x1=\"\(toX)\" y1=\"\(message.y)\" x2=\"\(ax)\" y2=\"\(message.y - arrowHeadSize / 2)\"/>")
            parts.append("<line class=\"arrow-open\" x1=\"\(toX)\" y1=\"\(message.y)\" x2=\"\(ax)\" y2=\"\(message.y + arrowHeadSize / 2)\"/>")
        } else {
            let ax = isReverse ? toX + arrowHeadSize : toX - arrowHeadSize
            parts.append("<polygon class=\"arrow-head\" points=\"\(toX),\(message.y) \(ax),\(message.y - arrowHeadSize / 2) \(ax),\(message.y + arrowHeadSize / 2)\"/>")
        }

        // Label
        let midX = (fromX + toX) / 2
        parts.append("<text class=\"message-label\" x=\"\(midX)\" y=\"\(message.y - 8)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(message.label))</text>")
    }

    return parts.joined(separator: "\n")
}

private func renderFragment(_ fragment: PositionedZenUMLFragment) -> String {
    var parts: [String] = []

    let headerHeight: Double = 25

    // Fragment border
    parts.append("<rect class=\"fragment-border\" x=\"\(fragment.x)\" y=\"\(fragment.y)\" width=\"\(fragment.width)\" height=\"\(fragment.height)\" rx=\"2\"/>")

    // Fragment header
    parts.append("<rect class=\"fragment-header\" x=\"\(fragment.x)\" y=\"\(fragment.y)\" width=\"\(fragment.width)\" height=\"\(headerHeight)\"/>")

    // Fragment label
    let labelX = fragment.x + 10
    let labelY = fragment.y + headerHeight / 2
    let fragmentLabel = "\(fragment.kind.rawValue) [\(escXml(fragment.label))]"
    parts.append("<text class=\"fragment-label\" x=\"\(labelX)\" y=\"\(labelY)\" dominant-baseline=\"central\">\(fragmentLabel)</text>")

    // Section separators
    for section in fragment.sections.dropFirst() {
        parts.append("<line class=\"fragment-border\" x1=\"\(fragment.x)\" y1=\"\(section.y)\" x2=\"\(fragment.x + fragment.width)\" y2=\"\(section.y)\" stroke-dasharray=\"4,4\"/>")
    }

    return parts.joined(separator: "\n")
}

private func renderReturn(_ ret: PositionedZenUMLReturn) -> String {
    var parts: [String] = []

    let arrowHeadSize: Double = 8
    let fromX = ret.fromX + (ret.isReverse ? -10 : 10)
    let toX = ret.toX + (ret.isReverse ? 10 : -10)

    // Dashed return line
    parts.append("<line class=\"return-line\" x1=\"\(fromX)\" y1=\"\(ret.y)\" x2=\"\(toX)\" y2=\"\(ret.y)\"/>")

    // Open arrow head
    let ax = ret.isReverse ? toX + arrowHeadSize : toX - arrowHeadSize
    parts.append("<line class=\"arrow-open\" x1=\"\(toX)\" y1=\"\(ret.y)\" x2=\"\(ax)\" y2=\"\(ret.y - arrowHeadSize / 2)\"/>")
    parts.append("<line class=\"arrow-open\" x1=\"\(toX)\" y1=\"\(ret.y)\" x2=\"\(ax)\" y2=\"\(ret.y + arrowHeadSize / 2)\"/>")

    // Label
    if !ret.label.isEmpty {
        let midX = (fromX + toX) / 2
        parts.append("<text class=\"return-label\" x=\"\(midX)\" y=\"\(ret.y - 8)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(ret.label))</text>")
    }

    return parts.joined(separator: "\n")
}

private func renderDivider(_ divider: PositionedZenUMLDivider) -> String {
    var parts: [String] = []

    let bgHeight: Double = 24
    parts.append("<rect class=\"divider-bg\" x=\"0\" y=\"\(divider.y - bgHeight / 2)\" width=\"\(divider.width)\" height=\"\(bgHeight)\" rx=\"2\"/>")

    if !divider.label.isEmpty {
        parts.append("<text class=\"divider-label\" x=\"\(divider.width / 2)\" y=\"\(divider.y)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(divider.label))</text>")
    }

    return parts.joined(separator: "\n")
}

private func renderGroup(_ group: PositionedZenUMLGroup) -> String {
    """
    <rect class="group-outline" x="\(group.x)" y="\(group.y)" width="\(group.width)" height="\(group.height)"/>
    <text class="group-title-text" x="\(group.x + 5)" y="\(group.y - 5)">\(escXml(group.name))</text>
    """
}

private func renderOccurrence(_ occ: PositionedZenUMLOccurrence) -> String {
    "<rect class=\"occurrence\" x=\"\(occ.x)\" y=\"\(occ.y)\" width=\"\(occ.width)\" height=\"\(occ.height)\" rx=\"2\"/>"
}

private func renderSelfCall(_ sc: PositionedZenUMLSelfCall) -> String {
    var parts: [String] = []
    let ux = sc.x; let uy = sc.y; let uw = sc.width; let uh = sc.height
    parts.append("<polyline class=\"message-line\" points=\"\(ux),\(uy) \(ux),\(uy + uh) \(ux + uw),\(uy + uh) \(ux + uw),\(uy)\" fill=\"none\"/>")
    let arrowSize: Double = 8
    parts.append("<polygon class=\"arrow-head\" points=\"\(ux + uw),\(uy) \(ux + uw + arrowSize),\(uy - arrowSize/2) \(ux + uw + arrowSize),\(uy + arrowSize/2)\"/>")
    parts.append("<text class=\"message-label\" x=\"\(ux + uw / 2)\" y=\"\(uy + uh / 2)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(sc.label))</text>")
    return parts.joined(separator: "\n")
}

private func renderCreation(_ creation: PositionedZenUMLCreation) -> String {
    var parts: [String] = []
    let p = creation.participant
    let m = creation.message
    let boxX = p.x - p.width / 2
    parts.append("<rect class=\"participant-box\" x=\"\(boxX)\" y=\"\(p.y)\" width=\"\(p.width)\" height=\"\(p.height)\" rx=\"4\"/>")
    parts.append("<text class=\"participant-label\" x=\"\(p.x)\" y=\"\(p.y + p.height / 2)\" text-anchor=\"middle\" dominant-baseline=\"central\">\(escXml(p.label))</text>")
    // Dashed creation arrow
    parts.append("<line class=\"return-line\" x1=\"\(m.fromX)\" y1=\"\(m.y)\" x2=\"\(m.toX)\" y2=\"\(m.y)\"/>")
    let ax = m.toX - 8
    parts.append("<line class=\"arrow-open\" x1=\"\(m.toX)\" y1=\"\(m.y)\" x2=\"\(ax)\" y2=\"\(m.y - 4)\"/>")
    parts.append("<line class=\"arrow-open\" x1=\"\(m.toX)\" y1=\"\(m.y)\" x2=\"\(ax)\" y2=\"\(m.y + 4)\"/>")
    parts.append("<text class=\"message-label\" x=\"\((m.fromX + m.toX) / 2)\" y=\"\(m.y - 8)\" text-anchor=\"middle\">\(escXml(m.label))</text>")
    return parts.joined(separator: "\n")
}

private func renderComment(_ comment: PositionedZenUMLComment) -> String {
    "<text class=\"comment-text\" x=\"\(comment.x)\" y=\"\(comment.y)\">\(escXml(comment.text))</text>"
}

// MARK: - XML Escaping

private func escXml(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
}
