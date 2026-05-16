import Foundation
import DiagramKitCommon

public func renderRequirementSvg(
    _ diagram: PositionedRequirementDiagram,
    _ colors: DiagramColors,
    _ font: String = DiagramFontResolver.shared.svgFontFamily,
    _ transparent: Bool = false,
    diagramId: String? = nil,
    look: String? = nil,
    theme: RequirementThemeVariables? = nil,
    htmlLabels: Bool? = nil
) throws -> String {
    var parts: [String] = []
    let config = diagram.config
    let resolvedLook = config.look ?? look ?? "classic"
    let resolvedHtmlLabels = config.htmlLabels ?? htmlLabels ?? true

    let builder = SVGDocumentBuilder(
        width: diagram.width,
        height: diagram.height,
        colors: colors,
        transparent: transparent,
        fontFamily: font,
        includeHtmlLabelCSS: false,
        accessibilityTitle: diagram.accTitle,
        accessibilityDescription: diagram.accDescr,
        useMaxWidth: config.useMaxWidth
    )
    parts.append(builder.open())
    if let accTitle = diagram.accTitle, !accTitle.isEmpty {
        parts.append("<title>\(SVG.escapeText(accTitle))</title>")
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        parts.append("<desc>\(SVG.escapeText(accDescr))</desc>")
    }
    parts.append(_renderReqStyleBlock(font, theme: theme, look: resolvedLook))
    parts.append("<defs>")
    parts.append(_renderReqMarkerDefs(diagramId: diagramId, look: resolvedLook, theme: theme))
    parts.append("</defs>")

    // Title
    if let title = diagram.diagramTitle, !title.isEmpty {
        let styled = original_src_multiline_utils.normalizeBrTags(title)
        parts.append(
            "<text x=\"\(diagram.width / 2)\" y=\"25\" text-anchor=\"middle\" " +
            "font-size=\"16\" font-weight=\"700\" fill=\"var(--fg)\">\(original_src_multiline_utils.renderLineContent(styled))</text>"
        )
    }

    // Edges
    for edge in diagram.edges {
        parts.append(_renderReqEdge(edge, diagramId: diagramId, look: resolvedLook, theme: theme))
    }

    // Nodes
    for node in diagram.nodes {
        parts.append(_renderReqNode(node, look: resolvedLook, useHtmlLabels: resolvedHtmlLabels))
    }

    // Edge labels (drawn after edges)
    for edge in diagram.edges {
        parts.append(_renderReqEdgeLabel(edge))
    }

    parts.append(builder.close())
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

// MARK: - Style Block

private func _renderReqStyleBlock(_ font: String, theme: RequirementThemeVariables?, look: String) -> String {
    let tv = theme ?? RequirementThemeVariables()
    let fontFamily = "\(font), system-ui, sans-serif"

    var lines: [String] = []
    lines.append("<style>")

    // Font imports (reuse theme builder)
    let baseBlock = original_src_theme.buildStyleBlock(font, false)
    // Extract @import and font-family lines
    for bline in baseBlock.components(separatedBy: "\n") {
        let t = bline.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("@import") || t.hasPrefix("text {") || t.hasPrefix(".mono") {
            lines.append(t)
        }
    }

    // Requirement-specific CSS
    let reqBg = tv.requirementBackground ?? "var(--_node-fill)"
    let reqBorder = tv.requirementBorderColor ?? "var(--_node-stroke)"
    let reqBorderSize = tv.requirementBorderSize ?? "1"
    let reqText = tv.requirementTextColor ?? "var(--_text)"
    let relColor = tv.relationColor ?? "var(--_line)"
    let relLabelBg = tv.relationLabelBackground ?? tv.edgeLabelBackground ?? "var(--_surface)"
    let relLabelColor = tv.relationLabelColor ?? "var(--_text-muted)"
    let reqEdgeLabelBg = tv.requirementEdgeLabelBackground ?? tv.edgeLabelBackground ?? "var(--_surface)"
    let nodeBorder = tv.nodeBorder ?? "var(--_inner-stroke)"
    let nodeText = tv.nodeTextColor ?? tv.textColor ?? "var(--_text)"
    let edgeLabelBg = tv.edgeLabelBackground ?? "var(--_surface)"
    let strokeW = tv.strokeWidth ?? (look == "neo" ? "2.5" : "1")

    let ruleStrokeW = look == "neo" ? strokeW : "1px"

    lines.append("  marker { fill: \(relColor); stroke: \(relColor); }")
    lines.append("  marker.cross { stroke: \(relColor); }")
    lines.append("  svg { font-family: \(fontFamily); }")
    lines.append("  .reqBox { fill: \(reqBg); fill-opacity: 1.0; stroke: \(reqBorder); stroke-width: \(reqBorderSize); }")
    lines.append("  .reqTitle, .reqLabel { fill: \(reqText); }")
    lines.append("  .reqLabelBox { fill: \(relLabelBg); fill-opacity: 1.0; }")
    lines.append("  .req-title-line { stroke: \(reqBorder); stroke-width: \(reqBorderSize); }")
    lines.append("  .relationshipLine { stroke: \(relColor); stroke-width: \(ruleStrokeW); }")
    lines.append("  .relationshipLabel { fill: \(relLabelColor); }")
    lines.append("  .edgeLabel { background-color: \(edgeLabelBg); }")
    lines.append("  .edgeLabel .label rect { fill: \(edgeLabelBg); }")
    lines.append("  .edgeLabel .label text { fill: \(relLabelColor); }")
    lines.append("  .divider { stroke: \(nodeBorder); stroke-width: 1; }")
    lines.append("  .label { font-family: \(fontFamily); color: \(nodeText); }")
    lines.append("  .label text,span { fill: \(nodeText); color: \(nodeText); }")
    lines.append("  .labelBkg { background-color: \(reqEdgeLabelBg); }")

    // Color-indexed selectors
    if let bkgArr = tv.bkgColorArray, let borderArr = tv.borderColorArray, !bkgArr.isEmpty {
        let limit = min(bkgArr.count, borderArr.count)
        for i in 0..<limit {
            lines.append("  [data-look=\"\(look)\"][data-color-id=\"color-\(i)\"].node path { stroke: \(borderArr[i]); fill: \(bkgArr[i]); }")
            lines.append("  [data-look=\"\(look)\"][data-color-id=\"color-\(i)\"].node rect { stroke: \(borderArr[i]); fill: \(bkgArr[i]); }")
        }
    }

    // Derived variables override
    lines.append("  svg {")
    lines.append("    --_node-fill: \(reqBg);")
    lines.append("    --_node-stroke: \(reqBorder);")
    lines.append("  }")

    lines.append("</style>")
    return lines.joined(separator: "\n")
}

// MARK: - Marker Definitions

private func _renderReqMarkerDefs(diagramId: String?, look: String, theme: RequirementThemeVariables?) -> String {
    let baseId = diagramId ?? "requirement"
    let strokeWidth = theme?.strokeWidth ?? "2.5"
    let isNeo = look == "neo"

    var parts: [String] = []

    if isNeo {
        // Neo contains: circle+cross with markerUnits="userSpaceOnUse"
        let mid = "\(baseId)_requirement-containsStart"
        parts.append("""
        <marker id="\(mid)" refX="0" refY="10" markerWidth="20" markerHeight="20" orient="auto" markerUnits="userSpaceOnUse" stroke-width="\(strokeWidth)">
          <g>
            <circle cx="10" cy="10" r="9" fill="none" />
            <line x1="1" x2="19" y1="10" y2="10" />
            <line y1="1" y2="19" x1="10" x2="10" />
          </g>
        </marker>
        """)
        // Neo arrow: open-V with markerUnits="userSpaceOnUse"
        let arrowId = "\(baseId)_requirement-arrowEnd"
        parts.append("""
        <marker id="\(arrowId)" refX="20" refY="10" markerWidth="20" markerHeight="20" orient="auto" markerUnits="userSpaceOnUse" stroke-width="\(strokeWidth)" viewBox="0 0 25 20">
          <path d="M0,0 L20,10 M20,10 L0,20" stroke-linejoin="miter" />
        </marker>
        """)
    } else {
        // Classic contains: circle+cross
        let mid = "\(baseId)_requirement-containsStart"
        parts.append("""
        <marker id="\(mid)" refX="0" refY="10" markerWidth="20" markerHeight="20" orient="auto">
          <g>
            <circle cx="10" cy="10" r="9" fill="none" />
            <line x1="1" x2="19" y1="10" y2="10" />
            <line y1="1" y2="19" x1="10" x2="10" />
          </g>
        </marker>
        """)
        // Classic arrow: open-V
        let arrowId = "\(baseId)_requirement-arrowEnd"
        parts.append("""
        <marker id="\(arrowId)" refX="20" refY="10" markerWidth="20" markerHeight="20" orient="auto">
          <path d="M0,0 L20,10 M20,10 L0,20" />
        </marker>
        """)
    }

    return parts.joined(separator: "\n")
}

// MARK: - Node Rendering (requirementBox shape)

private func _renderReqNode(_ node: PositionedRequirementNode, look: String, useHtmlLabels: Bool) -> String {
    let x = node.x
    let y = node.y
    let w = node.width
    let h = node.height
    let cx = x + w / 2

    let classes = node.classes.joined(separator: " ")
    let styleAttr = node.cssStyles.isEmpty ? "" : " style=\"\(_escapeReqAttr(node.cssStyles.joined(separator: "; ")))\""

    var parts: [String] = []
    parts.append("<g class=\"node \(_escapeReqAttr(classes))\" id=\"node-\(_escapeReqAttr(node.id))\" data-color-id=\"color-\(node.colorIndex)\" data-look=\"\(_escapeReqAttr(look))\"\(styleAttr)>")

    // Background rect
    parts.append(
        "  <rect class=\"basic label-container outer-path\" x=\"\(x)\" y=\"\(y)\" width=\"\(w)\" height=\"\(h)\" " +
        "rx=\"4\" ry=\"4\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\" />"
    )

    // Stereotype row
    let stereotypeText: String
    if node.isRequirement {
        stereotypeText = "&lt;&lt;\(node.requirementType?.rawValue ?? "Requirement")&gt;&gt;"
    } else {
        stereotypeText = "&lt;&lt;Element&gt;&gt;"
    }
    let stereotypeY = y + 14
    parts.append(
        "  <g class=\"label\" transform=\"translate(\(cx), \(stereotypeY))\">" +
        "<text text-anchor=\"middle\" font-size=\"11\" fill=\"var(--_text-muted)\">\(stereotypeText)</text></g>"
    )

    // Name row (bold) — use markdown-normalized text
    let styledName = original_src_multiline_utils.normalizeBrTags(node.id)
    let nameY = stereotypeY + 20
    parts.append(
        "  <g class=\"label\" transform=\"translate(\(cx), \(nameY))\">" +
        "<text text-anchor=\"middle\" font-size=\"13\" font-weight=\"bold\" fill=\"var(--_text)\">\(original_src_multiline_utils.renderLineContent(styledName))</text></g>"
    )

    // Determine body content
    let bodyLines = _reqBodyLines(node)
    let hasBody = !bodyLines.isEmpty

    if hasBody {
        let dividerY = nameY + 12
        if look == "neo" {
            // Neo: render divider as polygon
            let thickness = 0.5
            parts.append(
                "  <polygon class=\"divider\" points=\"\(x),\(dividerY) \(x + w),\(dividerY) \(x + w),\(dividerY + thickness) \(x),\(dividerY + thickness)\" " +
                "fill=\"var(--_inner-stroke)\" />"
            )
        } else {
            parts.append(
                "  <line class=\"divider\" x1=\"\(x + 4)\" y1=\"\(dividerY)\" x2=\"\(x + w - 4)\" y2=\"\(dividerY)\" " +
                "stroke=\"var(--_inner-stroke)\" stroke-width=\"1\" />"
            )
        }

        let bodyStartY = dividerY + 16
        for (idx, bodyLine) in bodyLines.enumerated() {
            let rowY = bodyStartY + Double(idx) * 18
            let styledBody = original_src_multiline_utils.normalizeBrTags(bodyLine)
            parts.append(
                "  <g class=\"label\" transform=\"translate(\(cx), \(rowY))\">" +
                "<text text-anchor=\"middle\" font-size=\"11\" fill=\"var(--_text-sec)\">\(original_src_multiline_utils.renderLineContent(styledBody))</text></g>"
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

private func _renderReqEdge(_ edge: PositionedRequirementEdge, diagramId: String?, look: String, theme: RequirementThemeVariables?) -> String {
    guard edge.path.count >= 2 else { return "" }
    let baseId = diagramId ?? "requirement"
    let pathData = edge.path.map { "\($0.x),\($0.y)" }.joined(separator: " ")
    let dashArray = edge.isDashed ? " stroke-dasharray=\"10,7\"" : ""
    let strokeW = theme?.strokeWidth ?? (look == "neo" ? "2.5" : "1")
    let markerStart: String
    let markerEnd: String
    if edge.startMarker != nil {
        markerStart = " marker-start=\"url(#\(baseId)_requirement-containsStart)\""
    } else {
        markerStart = ""
    }
    if edge.endMarker != nil {
        markerEnd = " marker-end=\"url(#\(baseId)_requirement-arrowEnd)\""
    } else {
        markerEnd = ""
    }

    return "<g class=\"relationshipLine\">" +
    "<polyline class=\"relationshipLine\" points=\"\(pathData)\" fill=\"none\" stroke=\"var(--_line)\" stroke-width=\"\(strokeW)\"\(dashArray)\(markerStart)\(markerEnd) />" +
    "</g>"
}

private func _renderReqEdgeLabel(_ edge: PositionedRequirementEdge) -> String {
    guard let lp = edge.labelPosition, !edge.labelText.isEmpty else { return "" }

    let styledLabel = original_src_multiline_utils.normalizeBrTags(edge.labelText)
    let metrics = original_src_text_metrics.measureMultilineText(
        styledLabel,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )
    let bgW = metrics.width + 8
    let bgH = metrics.height + 6

    return "<g class=\"edgeLabel\">" +
    "<rect class=\"labelBkg\" x=\"\(lp.x - bgW / 2)\" y=\"\(lp.y - bgH / 2)\" width=\"\(bgW)\" height=\"\(bgH)\" rx=\"2\" ry=\"2\" fill=\"var(--_surface)\" stroke=\"var(--_inner-stroke)\" stroke-width=\"0.5\" />" +
    original_src_multiline_utils.renderMultilineText(
        styledLabel, cx: lp.x, cy: lp.y,
        fontSize: original_src_styles.FONT_SIZES.edgeLabel,
        attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
    ) +
    "</g>"
}

private func _escapeReqAttr(_ value: String) -> String {
    SVG.escapeAttribute(value)
}
