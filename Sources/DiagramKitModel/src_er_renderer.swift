// Ported from original/src/er/renderer.ts
import Foundation
import DiagramKitCommon

private enum ERFont {
    static let attrSize: Double = 11
    static let attrWeight: Int = 400
    static let keySize: Double = 9
    static let keyWeight: Int = 600
    static let commentSize: Double = 9
    static let commentWeight: Int = 400
}

public func renderErSvg(
    _ diagram: PositionedErDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderErSvgEntry(diagram, colors, font, transparent)
}

private func _renderErSvgEntry(
    _ diagram: PositionedErDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []
    let config = diagram.config

    let builder = SVGDocumentBuilder(
        width: diagram.width,
        height: diagram.height,
        colors: colors,
        transparent: transparent,
        fontFamily: font,
        includeHtmlLabelCSS: true,
        accessibilityTitle: diagram.accTitle,
        accessibilityDescription: diagram.accDescr,
        useMaxWidth: config?.useMaxWidth ?? false
    )
    parts.append(builder.open())
    if let accTitle = diagram.accTitle, !accTitle.isEmpty {
        parts.append("<title>\(SVG.escapeText(accTitle))</title>")
    }
    if let accDescr = diagram.accDescr, !accDescr.isEmpty {
        parts.append("<desc>\(SVG.escapeText(accDescr))</desc>")
    }
    parts.append(builder.style())
    parts.append("<defs>")
    parts.append(_renderErMarkerDefs(config))
    parts.append("</defs>")

    // Title
    if let title = diagram.diagramTitle, !title.isEmpty {
        let titleTopMargin = config?.titleTopMargin ?? 25
        parts.append(
            "<text x=\"\(diagram.width / 2)\" y=\"\(titleTopMargin)\" text-anchor=\"middle\" " +
                "font-size=\"\((config?.fontSize ?? 16))\" font-weight=\"700\" fill=\"var(--_text)\">\(SVG.escapeText(title))</text>"
        )
    }

    for rel in diagram.relationships {
        parts.append(_renderRelationshipLine(rel, config))
    }

    for entity in diagram.entities {
        parts.append(_renderEntityBox(entity, config))
    }

    for rel in diagram.relationships {
        parts.append(_renderCardinality(rel, config))
    }

    for rel in diagram.relationships {
        parts.append(_renderRelationshipLabel(rel, config))
    }

    parts.append(builder.close())
    return parts.joined(separator: "\n")
}

private func _toThemeColors(_ colors: DiagramColors) -> original_src_theme.DiagramColors {
    original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border
    )
}

// MARK: - Marker Definitions

private func _renderErMarkerDefs(_ config: ErDiagramConfig?) -> String {
    // Mermaid edgeMarker.ts paths (exact parity)
    let onlyOne    = "M 0,0 L 8.4,-4.2 L 8.4,4.2 Z"
    let zeroOrOne  = "M 8.4,0 A 4.2,4.2 0 1,0 8.4,0.01 Z"
    let oneOrMore  = "M 0,0 L 8.4,-4.2 L 0,0 L 8.4,4.2 Z M 8.4,-4.2 L 8.4,4.2"
    let zeroOrMore = "M 8.4,0 A 4.2,4.2 0 1,0 8.4,0.01 Z M 0,0 L 8.4,-4.2 L 0,0 L 8.4,4.2 Z M 8.4,-4.2 L 8.4,4.2"
    let look = config?.look ?? "default"
    let suffix = (look == "neo") ? "_neo" : ""

    var parts: [String] = []
    parts.append(_renderMarkerDef("er-onlyOne\(suffix)", onlyOne, config, look: look))
    parts.append(_renderMarkerDef("er-zeroOrOne\(suffix)", zeroOrOne, config, look: look))
    parts.append(_renderMarkerDef("er-oneOrMore\(suffix)", oneOrMore, config, look: look))
    parts.append(_renderMarkerDef("er-zeroOrMore\(suffix)", zeroOrMore, config, look: look))
    return parts.joined(separator: "\n")
}

private func _renderMarkerDef(_ id: String, _ path: String, _ config: ErDiagramConfig?, look: String = "default") -> String {
    let stroke = _escapeAttr(config?.stroke ?? "var(--_line)")
    let sw = (look == "neo") ? "2" : "1"
    return """
    <marker id="\(id)Start" viewBox="0 -7 17 14" refX="8.4" refY="0" markerWidth="17" markerHeight="14" orient="auto-start-reverse">
      <path d="\(path)" fill="\(stroke)" stroke="\(stroke)" stroke-width="\(sw)" />
    </marker>
    <marker id="\(id)End" viewBox="0 -7 17 14" refX="8.4" refY="0" markerWidth="17" markerHeight="14" orient="auto">
      <path d="\(path)" fill="\(stroke)" stroke="\(stroke)" stroke-width="\(sw)" />
    </marker>
    """
}

// MARK: - Entity Box Rendering

private func _renderEntityBox(_ entity: PositionedErEntity, _ config: ErDiagramConfig?) -> String {
    let x = entity.x
    let y = entity.y
    let width = entity.width
    let height = entity.height
    let headerHeight = entity.headerHeight
    let rowHeight = entity.rowHeight
    let label = entity.alias.isEmpty ? entity.label : entity.alias
    let attrs = entity.attributes
    let cssClasses = entity.cssClasses
    let effectiveStyles = _effectiveErStyles(entity)
    let cssStyles = effectiveStyles.joined(separator: "; ")
    let styleAttr = cssStyles.isEmpty ? "" : " style=\"\(_escapeAttr(cssStyles))\""
    let labelFontSize = config?.fontSize ?? original_src_styles.FONT_SIZES.nodeLabel

    var parts: [String] = []
    parts.append("<g class=\"entity \(_escapeAttr(cssClasses))\" data-id=\"\(_escapeAttr(entity.id))\" data-node-id=\"\(_escapeAttr(entity.nodeId))\" data-label=\"\(_escapeAttr(label))\"\(styleAttr)>")

    // Fill color from styles or default
    let fill = _extractCssValue(effectiveStyles, property: "fill") ?? config?.fill ?? "var(--_node-fill)"
    let stroke = _extractCssValue(effectiveStyles, property: "stroke") ?? config?.stroke ?? "var(--_node-stroke)"
    let strokeW = _extractCssValue(effectiveStyles, property: "stroke-width") ?? String(original_src_styles.STROKE_WIDTHS.outerBox)
    let textFill = _extractCssValue(effectiveStyles, property: "color") ?? "var(--_text)"

    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" " +
            "rx=\"0\" ry=\"0\" fill=\"\(_escapeAttr(fill))\" stroke=\"\(_escapeAttr(stroke))\" " +
            "stroke-width=\"\(_escapeAttr(strokeW))\" />"
    )

    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(headerHeight)\" " +
            "rx=\"0\" ry=\"0\" fill=\"var(--_group-hdr)\" stroke=\"\(_escapeAttr(stroke))\" " +
            "stroke-width=\"\(_escapeAttr(strokeW))\" />"
    )

    if entity.labelType == "text" {
        // Plain text label — no markdown formatting (htmlLabels: false behavior)
        parts.append(
            "<text x=\"\(x + width / 2)\" y=\"\(y + headerHeight / 2)\" text-anchor=\"middle\" " +
                "font-size=\"\(labelFontSize)\" font-weight=\"700\" fill=\"\(_escapeAttr(textFill))\" " +
                "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\">\(SVG.escapeText(label))</text>"
        )
    } else {
        parts.append(
            "  " + original_src_multiline_utils.renderMultilineText(
                label,
                cx: x + width / 2,
                cy: y + headerHeight / 2,
                fontSize: labelFontSize,
                attrs: "text-anchor=\"middle\" font-size=\"\(labelFontSize)\" " +
                    "font-weight=\"700\" fill=\"\(_escapeAttr(textFill))\""
            )
        )
    }

    if attrs.isEmpty {
        // Simple rectangle — no attribute section, no "(no attributes)" text
        parts.append("</g>")
        return parts.joined(separator: "\n")
    }

    let attrTop = y + headerHeight
    parts.append(
        "  <line x1=\"\(x)\" y1=\"\(attrTop)\" x2=\"\(x + width)\" y2=\"\(attrTop)\" " +
            "stroke=\"\(stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
    )

    // Column divider positions
    let keyColRight = _maxKeyWidth(attrs) > 0 ? x + 6 + _maxKeyWidth(attrs) + 14 : -1
    let commentColLeft = _maxCommentWidth(attrs) > 0 ? width - _maxCommentWidth(attrs) - 8 : -1

    // Vertical column dividers
    if keyColRight > 0 {
        let dividerX = keyColRight
        parts.append(
            "  <line x1=\"\(dividerX)\" y1=\"\(attrTop)\" x2=\"\(dividerX)\" y2=\"\(y + height)\" " +
                "stroke=\"var(--_inner-stroke)\" stroke-width=\"0.5\" />"
        )
    }

    if commentColLeft > 0 {
        let dividerX = x + commentColLeft
        parts.append(
            "  <line x1=\"\(dividerX)\" y1=\"\(attrTop)\" x2=\"\(dividerX)\" y2=\"\(y + height)\" " +
                "stroke=\"var(--_inner-stroke)\" stroke-width=\"0.5\" />"
        )
    }

    for (idx, attr) in attrs.enumerated() {
        let rowY = attrTop + Double(idx) * rowHeight + rowHeight / 2
        let isOdd = idx % 2 == 1
        let rowFill = isOdd ? "var(--_row-odd)" : "var(--_row-even)"

        // Row striping background
        parts.append(
            "  <rect x=\"\(x)\" y=\"\(attrTop + Double(idx) * rowHeight)\" width=\"\(width)\" height=\"\(rowHeight)\" " +
                "fill=\"\(rowFill)\" opacity=\"0.3\" />"
        )

        let rendered = _renderAttribute(attr, boxX: x, y: rowY, boxWidth: width, keyColRight: keyColRight, commentColLeft: commentColLeft)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "  " + $0 }
            .joined(separator: "\n")
        parts.append(rendered)
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _maxKeyWidth(_ attrs: [ErAttribute]) -> Double {
    var maxW = 0.0
    for attr in attrs {
        if !attr.keys.isEmpty {
            let keyText = attr.keys.joined(separator: ",")
            let w = original_src_styles.estimateTextWidth(keyText, ERFont.keySize, ERFont.keyWeight) + 8
            maxW = max(maxW, w)
        }
    }
    return maxW
}

private func _maxCommentWidth(_ attrs: [ErAttribute]) -> Double {
    var maxW = 0.0
    for attr in attrs {
        if !attr.comment.isEmpty {
            let w = original_src_styles.estimateMonoTextWidth(attr.comment, ERFont.commentSize)
            maxW = max(maxW, w + 12)
        }
    }
    return maxW
}

private func _extractCssValue(_ styles: [String], property: String) -> String? {
    for style in styles.reversed() {
        let parts = style.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count == 2, parts[0] == property {
            return parts[1]
        }
    }
    return nil
}

private func _effectiveErStyles(_ entity: PositionedErEntity) -> [String] {
    entity.cssCompiledStyles + entity.cssStyles
}

// MARK: - Attribute Rendering

private func _renderAttribute(
    _ attr: ErAttribute,
    boxX: Double,
    y: Double,
    boxWidth: Double,
    keyColRight: Double,
    commentColLeft: Double
) -> String {
    var parts: [String] = []

    // Key badge
    if !attr.keys.isEmpty {
        let keyText = attr.keys.joined(separator: ",")
        let keyWidth = original_src_styles.estimateTextWidth(keyText, ERFont.keySize, ERFont.keyWeight) + 8
        parts.append(
            "<rect x=\"\(boxX + 6)\" y=\"\(y - 7)\" width=\"\(keyWidth)\" height=\"14\" rx=\"2\" ry=\"2\" " +
                "fill=\"var(--_key-badge)\" />"
        )
        parts.append(
            "<text x=\"\(boxX + 6 + keyWidth / 2)\" y=\"\(y)\" text-anchor=\"middle\" " +
                "dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" font-size=\"\(ERFont.keySize)\" " +
                "font-weight=\"\(ERFont.keyWeight)\" fill=\"var(--_text-sec)\">\(keyText)</text>"
        )
    }

    // Type
    let typeX = keyColRight > 0 ? keyColRight + 6 : boxX + 8
    parts.append(
        "<text x=\"\(typeX)\" y=\"\(y)\" class=\"mono\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
            "font-size=\"\(ERFont.attrSize)\" font-weight=\"\(ERFont.attrWeight)\">" +
            "<tspan fill=\"var(--_text-muted)\">\(SVG.escapeText(attr.type))</tspan></text>"
    )

    // Name — rendered before comment column if present
    let nameEndX = commentColLeft > 0 ? boxX + commentColLeft - 8 : boxX + boxWidth - 8
    parts.append(
        "<text x=\"\(nameEndX)\" y=\"\(y)\" class=\"mono\" text-anchor=\"end\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
            "font-size=\"\(ERFont.attrSize)\" font-weight=\"\(ERFont.attrWeight)\">" +
            "<tspan fill=\"var(--_text-sec)\">\(SVG.escapeText(attr.name))</tspan></text>"
    )

    // Comment column
    if !attr.comment.isEmpty, commentColLeft > 0 {
        let commentX = boxX + commentColLeft + 4
        parts.append(
            "<text x=\"\(commentX)\" y=\"\(y)\" class=\"mono\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
                "font-size=\"\(ERFont.commentSize)\" font-weight=\"\(ERFont.commentWeight)\" fill=\"var(--_text-faint)\">" +
                "\(SVG.escapeText(attr.comment))</text>"
        )
    }

    return parts.joined(separator: "\n")
}

// MARK: - Relationship Rendering

private func _renderRelationshipLine(_ rel: PositionedErRelationship, _ config: ErDiagramConfig?) -> String {
    guard rel.points.count >= 2 else {
        return ""
    }
    let pathData = rel.points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
    let dashArray = rel.identifying ? "" : " stroke-dasharray=\"6 4\""
    let labelAttr = rel.label.isEmpty ? "" : " data-label=\"\(_escapeAttr(rel.label))\""
    let stroke = _escapeAttr(config?.stroke ?? "var(--_line)")
    let attrs = [
        "class=\"er-relationship\"",
        "data-entity1=\"\(_escapeAttr(rel.entity1))\"",
        "data-entity2=\"\(_escapeAttr(rel.entity2))\"",
        "data-entityAId=\"\(_escapeAttr(rel.entityAId))\"",
        "data-entityBId=\"\(_escapeAttr(rel.entityBId))\"",
        "data-cardinality1=\"\(rel.cardinality1)\"",
        "data-cardinality2=\"\(rel.cardinality2)\"",
        "data-identifying=\"\(rel.identifying)\"",
    ].joined(separator: " ")

    return "<polyline \(attrs)\(labelAttr) points=\"\(pathData)\" fill=\"none\" stroke=\"\(stroke)\" " +
        "stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray) />"
}

private func _renderRelationshipLabel(_ rel: PositionedErRelationship, _ config: ErDiagramConfig?) -> String {
    guard !rel.label.isEmpty, rel.points.count >= 2 else {
        return ""
    }

    let mid = _midpoint(rel.points)
    let labelFontSize = config?.fontSize ?? original_src_styles.FONT_SIZES.edgeLabel
    let metrics = original_src_text_metrics.measureMultilineText(
        rel.label,
        fontSize: labelFontSize,
        fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
    )
    let bgW = metrics.width + 8
    let bgH = metrics.height + 6

    let labelBgFill = config?.erEdgeLabelBackground ?? "var(--bg)"
    return "<rect x=\"\(mid.x - bgW / 2)\" y=\"\(mid.y - bgH / 2)\" width=\"\(bgW)\" height=\"\(bgH)\" rx=\"2\" ry=\"2\" " +
        "fill=\"\(_escapeAttr(labelBgFill))\" stroke=\"var(--_inner-stroke)\" stroke-width=\"0.5\" />\n" +
        original_src_multiline_utils.renderMultilineText(
            rel.label,
            cx: mid.x,
            cy: mid.y,
            fontSize: labelFontSize,
            attrs: "text-anchor=\"middle\" font-size=\"\(labelFontSize)\" " +
                "font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
        )
}

// MARK: - Cardinality Rendering

private func _renderCardinality(_ rel: PositionedErRelationship, _ config: ErDiagramConfig?) -> String {
    guard rel.points.count >= 2 else {
        return ""
    }
    var out: [String] = []

    let p1 = rel.points[0]
    let p2 = rel.points[1]
    out.append(_renderCrowsFoot(point: p1, toward: p2, cardinality: rel.cardinality1, config))

    let pN = rel.points[rel.points.count - 1]
    let pN1 = rel.points[rel.points.count - 2]
    out.append(_renderCrowsFoot(point: pN, toward: pN1, cardinality: rel.cardinality2, config))

    return out.filter { !$0.isEmpty }.joined(separator: "\n")
}

private func _renderCrowsFoot(point: ErPoint, toward: ErPoint, cardinality: String, _ config: ErDiagramConfig?) -> String {
    let sw = original_src_styles.STROKE_WIDTHS.connector + 0.25
    let stroke = _escapeAttr(config?.stroke ?? "var(--_line)")
    let dx = point.x - toward.x
    let dy = point.y - toward.y
    let len = sqrt(dx * dx + dy * dy)
    if len == 0 {
        return ""
    }
    let ux = dx / len
    let uy = dy / len
    let px = -uy
    let py = ux

    let tipX = point.x - ux * 4
    let tipY = point.y - uy * 4
    let backX = point.x - ux * 16
    let backY = point.y - uy * 16

    // Check using enum raw values
    let hasOneLine: Bool = {
        let upper = cardinality.uppercased()
        return upper == "ONLY_ONE" || upper == "ZERO_OR_ONE" || upper == "ONE" || upper == "ZERO-ONE"
    }()
    let hasCrowsFoot: Bool = {
        let upper = cardinality.uppercased()
        return upper == "ONE_OR_MORE" || upper == "ZERO_OR_MORE" || upper == "MANY" || upper == "ZERO-MANY"
    }()
    let hasCircle: Bool = {
        let upper = cardinality.uppercased()
        return upper == "ZERO_OR_ONE" || upper == "ZERO_OR_MORE" || upper == "ZERO-ONE" || upper == "ZERO-MANY"
    }()
    let isParent: Bool = cardinality.uppercased() == "MD_PARENT"

    var parts: [String] = []

    if isParent {
        // Diamond marker for parent
        let diamondSize = 6.0
        let offset = tipX - ux * 8
        let offsety = tipY - uy * 8
        parts.append(
            "<polygon points=\"\(offset),\(offsety - diamondSize) \(offset + diamondSize),\(offsety) \(offset),\(offsety + diamondSize) \(offset - diamondSize),\(offsety)\" " +
                "fill=\"\(stroke)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
    }

    if hasOneLine {
        let halfW = 6.0
        parts.append(
            "<line x1=\"\(tipX + px * halfW)\" y1=\"\(tipY + py * halfW)\" x2=\"\(tipX - px * halfW)\" y2=\"\(tipY - py * halfW)\" " +
                "stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
        let line2X = tipX - ux * 4
        let line2Y = tipY - uy * 4
        parts.append(
            "<line x1=\"\(line2X + px * halfW)\" y1=\"\(line2Y + py * halfW)\" x2=\"\(line2X - px * halfW)\" y2=\"\(line2Y - py * halfW)\" " +
                "stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
    }

    if hasCrowsFoot {
        let fanW = 7.0
        let cfTipX = tipX
        let cfTipY = tipY
        parts.append(
            "<line x1=\"\(cfTipX + px * fanW)\" y1=\"\(cfTipY + py * fanW)\" x2=\"\(backX)\" y2=\"\(backY)\" " +
                "stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
        parts.append(
            "<line x1=\"\(cfTipX)\" y1=\"\(cfTipY)\" x2=\"\(backX)\" y2=\"\(backY)\" " +
                "stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
        parts.append(
            "<line x1=\"\(cfTipX - px * fanW)\" y1=\"\(cfTipY - py * fanW)\" x2=\"\(backX)\" y2=\"\(backY)\" " +
                "stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
    }

    if hasCircle {
        let circleOffset = hasCrowsFoot ? 20.0 : 12.0
        let circleX = point.x - ux * circleOffset
        let circleY = point.y - uy * circleOffset
        parts.append(
            "<circle cx=\"\(circleX)\" cy=\"\(circleY)\" r=\"4\" fill=\"var(--bg)\" stroke=\"\(stroke)\" stroke-width=\"\(sw)\" />"
        )
    }

    return parts.joined(separator: "\n")
}

private func _midpoint(_ points: [ErPoint]) -> ErPoint {
    if points.isEmpty {
        return ErPoint(x: 0, y: 0)
    }
    if points.count == 1 {
        return points[0]
    }

    var totalLen = 0.0
    for i in 1 ..< points.count {
        let dx = points[i].x - points[i - 1].x
        let dy = points[i].y - points[i - 1].y
        totalLen += sqrt(dx * dx + dy * dy)
    }
    if totalLen == 0 {
        return points[0]
    }

    let halfLen = totalLen / 2
    var walked = 0.0
    for i in 1 ..< points.count {
        let dx = points[i].x - points[i - 1].x
        let dy = points[i].y - points[i - 1].y
        let segLen = sqrt(dx * dx + dy * dy)
        if walked + segLen >= halfLen {
            let t = segLen > 0 ? (halfLen - walked) / segLen : 0
            return ErPoint(
                x: points[i - 1].x + dx * t,
                y: points[i - 1].y + dy * t
            )
        }
        walked += segLen
    }

    return points[points.count - 1]
}

private func _escapeAttr(_ value: String) -> String {
    SVG.escapeAttribute(value)
}

final class original_src_er_renderer {
    public init() {}

    public static func renderErSvg(
        _ diagram: PositionedErDiagram,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderErSvgEntry(diagram, colors, font, transparent)
    }
}
