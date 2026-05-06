import Foundation

public func renderRequirementSvg(
    _ diagram: PositionedRequirementDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    var parts: [String] = []
    let themeColors = _toReqThemeColors(colors)
    let config = diagram.config

    parts.append(_reqSvgOpenTag(diagram.width, diagram.height, themeColors, transparent, config))
    if let accTitle = diagram.accTitle, !accTitle.isEmpty {
        parts.append("<title>\(original_src_multiline_utils.escapeXml(accTitle))</title>")
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        parts.append("<desc>\(original_src_multiline_utils.escapeXml(accDescr))</desc>")
    }
    parts.append(original_src_theme.buildStyleBlock(font, false))
    parts.append("<defs>")
    parts.append(_renderReqMarkerDefs())
    parts.append("</defs>")

    // Title
    if let title = diagram.diagramTitle, !title.isEmpty {
        parts.append(
            "<text x=\"\(diagram.width / 2)\" y=\"25\" text-anchor=\"middle\" " +
            "font-size=\"16\" font-weight=\"700\" fill=\"var(--_text)\">\(original_src_multiline_utils.escapeXml(title))</text>"
        )
    }

    // Edges
    for edge in diagram.edges {
        parts.append(_renderReqEdge(edge))
    }

    // Nodes
    for node in diagram.nodes {
        parts.append(_renderReqNode(node))
    }

    // Edge labels (drawn after edges)
    for edge in diagram.edges {
        parts.append(_renderReqEdgeLabel(edge))
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _toReqThemeColors(_ colors: DiagramColors) -> original_src_theme.DiagramColors {
    original_src_theme.DiagramColors(
        bg: colors.bg, fg: colors.fg, line: colors.line,
        accent: colors.accent, muted: colors.muted,
        surface: colors.surface, border: colors.border
    )
}

private func _reqSvgOpenTag(
    _ width: Double, _ height: Double,
    _ colors: original_src_theme.DiagramColors,
    _ transparent: Bool,
    _ config: RequirementDiagramConfig
) -> String {
    var tag = original_src_theme.svgOpenTag(width, height, colors, transparent)
    if config.useMaxWidth {
        tag = tag.replacingOccurrences(of: "width=\"\(Int(width))\"", with: "width=\"100%\"")
    }
    return tag
}

// MARK: - Marker Definitions

private func _renderReqMarkerDefs() -> String {
    var parts: [String] = []
    // Contains marker (filled circle at start)
    parts.append("""
    <marker id="requirement_contains" viewBox="0 -4 8 8" refX="0" refY="0" markerWidth="8" markerHeight="8" orient="auto">
      <circle cx="4" cy="0" r="3" fill="var(--_line)" stroke="var(--_line)" stroke-width="1" />
    </marker>
    """)
    // Arrow marker for non-contains
    parts.append("""
    <marker id="requirement_arrow" viewBox="0 -5 10 10" refX="10" refY="0" markerWidth="10" markerHeight="10" orient="auto">
      <path d="M 0 -5 L 10 0 L 0 5 Z" fill="var(--_line)" stroke="var(--_line)" stroke-width="1" />
    </marker>
    """)
    return parts.joined(separator: "\n")
}

// MARK: - Node Rendering (requirementBox shape)

private func _renderReqNode(_ node: PositionedRequirementNode) -> String {
    let x = node.x
    let y = node.y
    let w = node.width
    let h = node.height
    let cx = x + w / 2

    let classes = node.classes.joined(separator: " ")
    let styleAttr = node.cssStyles.isEmpty ? "" : " style=\"\(_escapeReqAttr(node.cssStyles.joined(separator: "; ")))\""

    var parts: [String] = []
    parts.append("<g class=\"node \(_escapeReqAttr(classes))\" id=\"node-\(_escapeReqAttr(node.id))\" data-color-id=\"color-\(node.colorIndex)\" data-look=\"classic\"\(styleAttr)>")

    // Background rect
    parts.append(
        "  <rect class=\"basic label-container outer-path\" x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" " +
        "rx=\"4\" ry=\"4\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\" />"
    )

    // Stereotype row
    let stereotypeText: String
    if node.isRequirement {
        stereotypeText = "<<\(node.requirementType?.rawValue ?? "Requirement")>>"
    } else {
        stereotypeText = "<<Element>>"
    }
    let stereotypeY = y + 14
    parts.append(
        "  <g class=\"label\" transform=\"translate(\(cx), \(stereotypeY))\">" +
        "<text text-anchor=\"middle\" font-size=\"11\" fill=\"var(--_text-muted)\">\(original_src_multiline_utils.escapeXml(stereotypeText))</text></g>"
    )

    // Name row (bold)
    let nameY = stereotypeY + 20
    parts.append(
        "  <g class=\"label\" transform=\"translate(\(cx), \(nameY))\">" +
        "<text text-anchor=\"middle\" font-size=\"13\" font-weight=\"bold\" fill=\"var(--_text)\">\(original_src_multiline_utils.escapeXml(node.id))</text></g>"
    )

    // Determine body content
    let bodyLines = _reqBodyLines(node)
    let hasBody = !bodyLines.isEmpty

    if hasBody {
        let dividerY = nameY + 12
        parts.append(
            "  <line class=\"divider\" x1=\"\(x + 4)\" y1=\"\(dividerY)\" x2=\"\(x + w - 4)\" y2=\"\(dividerY)\" " +
            "stroke=\"var(--_inner-stroke)\" stroke-width=\"1\" />"
        )

        let bodyStartY = dividerY + 16
        for (idx, line) in bodyLines.enumerated() {
            let rowY = bodyStartY + Double(idx) * 18
            parts.append(
                "  <g class=\"label\" transform=\"translate(\(cx), \(rowY))\">" +
                "<text text-anchor=\"middle\" font-size=\"11\" fill=\"var(--_text-sec)\">\(original_src_multiline_utils.escapeXml(line))</text></g>"
            )
        }
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _reqBodyLines(_ node: PositionedRequirementNode) -> [String] {
    var lines: [String] = []
    if node.isRequirement {
        if let rid = node.requirementId, !rid.isEmpty { lines.append("ID: \(rid)") }
        if let t = node.text, !t.isEmpty { lines.append("Text: \(t)") }
        if let r = node.risk { lines.append("Risk: \(r.rawValue)") }
        if let v = node.verifyMethod { lines.append("Verification: \(v.rawValue)") }
    } else {
        if let et = node.elementType, !et.isEmpty { lines.append("Type: \(et)") }
        if let dr = node.docRef, !dr.isEmpty { lines.append("Doc Ref: \(dr)") }
    }
    return lines
}

// MARK: - Edge Rendering

private func _renderReqEdge(_ edge: PositionedRequirementEdge) -> String {
    guard edge.path.count >= 2 else { return "" }
    let pathData = edge.path.map { "\($0.x),\($0.y)" }.joined(separator: " ")
    let dashArray = edge.isDashed ? " stroke-dasharray=\"10,7\"" : ""
    let markerStart = edge.startMarker.map { " marker-start=\"url(#\($0))\"" } ?? ""
    let markerEnd = edge.endMarker.map { " marker-end=\"url(#\($0))\"" } ?? ""

    return "<g class=\"relationshipLine\">" +
    "<polyline class=\"relationshipLine\" points=\"\(pathData)\" fill=\"none\" stroke=\"var(--_line)\" stroke-width=\"1\"\(dashArray)\(markerStart)\(markerEnd) />" +
    "</g>"
}

private func _renderReqEdgeLabel(_ edge: PositionedRequirementEdge) -> String {
    guard let lp = edge.labelPosition, !edge.labelText.isEmpty else { return "" }

    let metrics = original_src_text_metrics.measureMultilineText(
        edge.labelText,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )
    let bgW = metrics.width + 8
    let bgH = metrics.height + 6

    return "<g class=\"edgeLabel\">" +
    "<rect class=\"labelBkg\" x=\"\(lp.x - bgW / 2)\" y=\"\(lp.y - bgH / 2)\" width=\"\(bgW)\" height=\"\(bgH)\" rx=\"2\" ry=\"2\" fill=\"var(--bg)\" stroke=\"var(--_inner-stroke)\" stroke-width=\"0.5\" />" +
    original_src_multiline_utils.renderMultilineText(
        edge.labelText, cx: lp.x, cy: lp.y,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
    ) +
    "</g>"
}

private func _escapeReqAttr(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
}
