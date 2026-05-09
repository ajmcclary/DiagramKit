// Ported from original/src/class/renderer.ts
// Expanded with notes, namespaces, lollipop, two-ended markers, styling, accessibility.
import Foundation

private enum _ClassFont {
    static let memberSize: Double = 11
    static let memberWeight: Int = 400
    static let annotationSize: Double = 10
    static let annotationWeight: Int = 500
}

public func renderClassSvg(
    _ diagram: PositionedClassDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false,
    securityLevel: String? = nil
) throws -> String {
    try _renderClassSvgEntry(diagram, colors, font, transparent, securityLevel: securityLevel)
}

private func _renderClassSvgEntry(
    _ diagram: PositionedClassDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool,
    securityLevel: String? = nil
) throws -> String {
    var parts: [String] = []

    let themedColors = original_src_theme.DiagramColors(
        bg: colors.bg,
        fg: colors.fg,
        line: colors.line,
        accent: colors.accent,
        muted: colors.muted,
        surface: colors.surface,
        border: colors.border,
        noteBkg: colors.noteBkg,
        noteBorder: colors.noteBorder
    )

    parts.append(original_src_theme.svgOpenTag(diagram.width, diagram.height, themedColors, transparent))

    // Accessibility metadata
    if let title = diagram.accTitle, !title.isEmpty {
        parts.append("  <title>\(SVG.escapeText(title))</title>")
    }
    if let descr = diagram.accDescription, !descr.isEmpty {
        parts.append("  <desc>\(SVG.escapeText(descr))</desc>")
    }
    if let diagramTitle = diagram.diagramTitle, !diagramTitle.isEmpty {
        parts.append("  <text x=\"\(diagram.width / 2)\" y=\"24\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"700\" fill=\"var(--_text)\">\(SVG.escapeText(diagramTitle))</text>")
    }

    parts.append(original_src_theme.buildStyleBlock(font, true))
    parts.append("<defs>")
    parts.append(_relationshipMarkerDefs())
    parts.append("</defs>")

    // Render namespace boxes first (behind everything)
    for ns in diagram.namespaces {
        parts.append(_renderNamespace(ns))
    }

    // Render notes
    for note in diagram.notes {
        parts.append(_renderNote(note))
    }

    // Render relationships
    for rel in diagram.relationships {
        let rendered = _renderRelationship(rel)
        if !rendered.isEmpty { parts.append(rendered) }
    }

    // Render class boxes
    for cls in diagram.classes {
        parts.append(_renderClassBox(cls, securityLevel: securityLevel))
    }

    // Render relationship labels on top
    for rel in diagram.relationships {
        let rendered = _renderRelationshipLabels(rel)
        if !rendered.isEmpty { parts.append(rendered) }
    }

    parts.append("</svg>")
    return parts.joined(separator: "\n")
}

private func _relationshipMarkerDefs() -> String {
    "  <marker id=\"extension\" markerWidth=\"12\" markerHeight=\"10\" refX=\"12\" refY=\"5\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"0 0, 12 5, 0 10\" fill=\"var(--bg)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"composition\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"6 0, 12 5, 6 10, 0 5\" fill=\"var(--_arrow)\" stroke=\"var(--_arrow)\" stroke-width=\"1\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"aggregation\" markerWidth=\"12\" markerHeight=\"10\" refX=\"0\" refY=\"5\" orient=\"auto-start-reverse\">\n" +
        "    <polygon points=\"6 0, 12 5, 6 10, 0 5\" fill=\"var(--bg)\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"dependency\" markerWidth=\"8\" markerHeight=\"6\" refX=\"8\" refY=\"3\" orient=\"auto-start-reverse\">\n" +
        "    <polyline points=\"0 0, 8 3, 0 6\" fill=\"none\" stroke=\"var(--_arrow)\" stroke-width=\"1.5\" />\n" +
        "  </marker>\n" +
        "  <marker id=\"lollipop\" markerWidth=\"10\" markerHeight=\"10\" refX=\"5\" refY=\"5\">\n" +
        "    <circle cx=\"5\" cy=\"5\" r=\"5\" fill=\"var(--bg)\" stroke=\"var(--_line)\" stroke-width=\"1.5\" />\n" +
        "  </marker>"
}

private struct _ClassSvgStyle {
    var fill: String?
    var stroke: String?
    var strokeWidth: String?
    var strokeDasharray: String?
    var color: String?
}

private func _parseClassSvgStyle(_ styles: [String]?) -> _ClassSvgStyle {
    var parsed = _ClassSvgStyle()
    for rawStyle in styles ?? [] {
        for rawToken in rawStyle.split(separator: ",", omittingEmptySubsequences: true) {
            let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let colon = token.firstIndex(of: ":") else { continue }
            let key = token[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = token[token.index(after: colon)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
            guard !value.isEmpty else { continue }

            switch key {
            case "fill":
                parsed.fill = value
            case "stroke":
                parsed.stroke = value
            case "stroke-width":
                parsed.strokeWidth = value
            case "stroke-dasharray":
                parsed.strokeDasharray = value
            case "color":
                parsed.color = value
            default:
                continue
            }
        }
    }
    return parsed
}

private func _renderClassBox(_ cls: PositionedClassNode, securityLevel: String? = nil) -> String {
    let x = cls.x
    let y = cls.y
    let width = cls.width
    let height = cls.height
    let headerHeight = cls.headerHeight
    let attrHeight = cls.attrHeight
    let hasAnnotations = !cls.annotations.isEmpty
    let hasAttrs = !cls.attributes.isEmpty
    let hasMethods = !cls.methods.isEmpty

    var parts: [String] = []

    let cssClasses = cls.cssClasses.map { " \($0)" } ?? ""
    let styleAttr = cls.styles.map { " style=\"\($0.joined(separator: ";"))\"" } ?? ""
    let parsedStyle = _parseClassSvgStyle(cls.styles)
    let boxFill = parsedStyle.fill.map(_escapeAttr) ?? "var(--_node-fill)"
    let headerFill = parsedStyle.fill.map(_escapeAttr) ?? "var(--_group-hdr)"
    let boxStroke = parsedStyle.stroke.map(_escapeAttr) ?? "var(--_node-stroke)"
    let boxStrokeWidth = parsedStyle.strokeWidth.map(_escapeAttr) ?? "\(original_src_styles.STROKE_WIDTHS.outerBox)"
    let dividerStrokeWidth = parsedStyle.strokeWidth.map(_escapeAttr) ?? "\(original_src_styles.STROKE_WIDTHS.innerBox)"
    let dashAttr = parsedStyle.strokeDasharray.map { " stroke-dasharray=\"\(_escapeAttr($0))\"" } ?? ""
    let textFill = parsedStyle.color.map(_escapeAttr) ?? "var(--_text)"

    let isSandbox = securityLevel?.lowercased() == "sandbox" || securityLevel?.lowercased() == "strict"
    let linkAttr = (!isSandbox && cls.link != nil) ? " data-link=\"\(_escapeAttr(cls.link!))\"" : ""
    let linkTargetAttr = (!isSandbox && cls.linkTarget != nil) ? " data-link-target=\"\(_escapeAttr(cls.linkTarget!))\"" : ""
    let tooltipAttr = (!isSandbox && cls.tooltip != nil) ? " data-tooltip=\"\(_escapeAttr(cls.tooltip!))\"" : ""

    parts.append(
        "<g class=\"class-node\(cssClasses)\" data-id=\"\(_escapeAttr(cls.id))\" data-label=\"\(_escapeAttr(cls.label))\"\(linkAttr)\(linkTargetAttr)\(tooltipAttr)\(styleAttr)>"
    )

    // Full box
    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" " +
            "rx=\"0\" ry=\"0\" fill=\"\(boxFill)\" stroke=\"\(boxStroke)\" stroke-width=\"\(boxStrokeWidth)\"\(dashAttr) />"
    )

    // Header
    parts.append(
        "  <rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(headerHeight)\" " +
            "rx=\"0\" ry=\"0\" fill=\"\(headerFill)\" stroke=\"\(boxStroke)\" stroke-width=\"\(boxStrokeWidth)\"\(dashAttr) />"
    )

    var nameY = y + headerHeight / 2
    if hasAnnotations {
        var annotY = y + 12
        for annotation in cls.annotations {
            parts.append(
                "  <text x=\"\(x + width / 2)\" y=\"\(annotY)\" text-anchor=\"middle\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
                    "font-size=\"\(_ClassFont.annotationSize)\" font-weight=\"\(_ClassFont.annotationWeight)\" " +
                    "font-style=\"italic\" fill=\"var(--_text-muted)\">&lt;&lt;\(SVG.escapeText(annotation))&gt;&gt;</text>"
            )
            annotY += _ClassFont.annotationSize + 2
        }
        nameY = y + headerHeight / 2 + 4 + Double(cls.annotations.count) * 6
    }

    parts.append(
        "  " + original_src_multiline_utils.renderMultilineText(
            cls.text.isEmpty ? cls.label : cls.text,
            cx: x + width / 2,
            cy: nameY,
            fontSize: original_src_styles.FONT_SIZES.nodeLabel,
            attrs: "text-anchor=\"middle\" font-size=\"\(original_src_styles.FONT_SIZES.nodeLabel)\" font-weight=\"700\" fill=\"\(textFill)\""
        )
    )

    if hasAttrs {
        let attrTop = y + headerHeight
        parts.append(
            "  <line x1=\"\(x)\" y1=\"\(attrTop)\" x2=\"\(x + width)\" y2=\"\(attrTop)\" " +
                "stroke=\"\(boxStroke)\" stroke-width=\"\(dividerStrokeWidth)\"\(dashAttr) />"
        )

        let memberRowH = 20.0
        for (i, member) in cls.attributes.enumerated() {
            let memberY = attrTop + 4 + Double(i) * memberRowH + memberRowH / 2
            parts.append("  " + _renderMember(member, x + CLS.boxPadX, memberY))
        }
    }

    if hasMethods {
        let methodTop = y + headerHeight + attrHeight
        parts.append(
            "  <line x1=\"\(x)\" y1=\"\(methodTop)\" x2=\"\(x + width)\" y2=\"\(methodTop)\" " +
                "stroke=\"\(boxStroke)\" stroke-width=\"\(dividerStrokeWidth)\"\(dashAttr) />"
        )

        let memberRowH = 20.0
        for (i, member) in cls.methods.enumerated() {
            let memberY = methodTop + 4 + Double(i) * memberRowH + memberRowH / 2
            parts.append("  " + _renderMember(member, x + CLS.boxPadX, memberY))
        }
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

private func _renderMember(_ member: ClassMember, _ x: Double, _ y: Double) -> String {
    let fontStyle = member.cssStyle.contains("italic") ? " font-style=\"italic\"" : ""
    let decoration = member.cssStyle.contains("underline") ? " text-decoration=\"underline\"" : ""

    var spans: [String] = []
    if !member.visibility.isEmpty {
        spans.append("<tspan fill=\"var(--_text-faint)\">\(SVG.escapeText(member.visibility)) </tspan>")
    }

    let genId = parseGenericTypes(member.id)
    let genParams = parseGenericTypes(member.parameters)
    let genReturn = parseGenericTypes(member.returnType)

    let displayName: String
    if member.memberType == .method {
        displayName = "\(genId)(\(genParams))"
    } else {
        displayName = genId
    }
    spans.append("<tspan fill=\"var(--_text-sec)\">\(SVG.escapeText(displayName))</tspan>")

    if !member.returnType.isEmpty {
        spans.append("<tspan fill=\"var(--_text-faint)\"> : </tspan>")
        spans.append("<tspan fill=\"var(--_text-muted)\">\(SVG.escapeText(genReturn))</tspan>")
    }

    return "<text x=\"\(x)\" y=\"\(y)\" class=\"mono\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
        "font-size=\"\(_ClassFont.memberSize)\" font-weight=\"\(_ClassFont.memberWeight)\"\(fontStyle)\(decoration)>\(spans.joined())</text>"
}

// MARK: - Two-ended relationship rendering

private func _renderRelationship(_ rel: PositionedClassRelationship) -> String {
    if rel.points.count < 2 { return "" }

    let pathData = rel.points.map { "\($0.x),\($0.y)" }.joined(separator: " ")
    let isDashed = rel.relation.lineType == ClassLineType.dotted.rawValue
    let dashArray = isDashed ? " stroke-dasharray=\"6 4\"" : ""

    var markerStart = ""
    var markerEnd = ""
    if let mid = _getMarkerDefId(forRelationType: rel.relation.type1) {
        markerStart = " marker-start=\"url(#\(mid))\""
    }
    if let mid = _getMarkerDefId(forRelationType: rel.relation.type2) {
        markerEnd = " marker-end=\"url(#\(mid))\""
    }

    var dataAttrs: [String] = [
        "class=\"class-relationship\"",
        "data-from=\"\(_escapeAttr(rel.from))\"",
        "data-to=\"\(_escapeAttr(rel.to))\"",
    ]
    if let title = rel.title, !title.isEmpty {
        dataAttrs.append("data-label=\"\(_escapeAttr(title))\"")
    }
    if let rt1 = rel.relationTitle1, !rt1.isEmpty {
        dataAttrs.append("data-title1=\"\(_escapeAttr(rt1))\"")
    }
    if let rt2 = rel.relationTitle2, !rt2.isEmpty {
        dataAttrs.append("data-title2=\"\(_escapeAttr(rt2))\"")
    }

    return "<polyline \(dataAttrs.joined(separator: " ")) points=\"\(pathData)\" fill=\"none\" stroke=\"var(--_line)\" " +
        "stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray)\(markerStart)\(markerEnd) />"
}

private func _getMarkerDefId(forRelationType type: Int) -> String? {
    switch type {
    case ClassRelationType.inheritance.rawValue: return "extension"
    case ClassRelationType.composition.rawValue: return "composition"
    case ClassRelationType.aggregation.rawValue: return "aggregation"
    case ClassRelationType.dependency.rawValue: return "dependency"
    case ClassRelationType.lollipop.rawValue: return "lollipop"
    default: return nil
    }
}

private func _renderRelationshipLabels(_ rel: PositionedClassRelationship) -> String {
    let hasTitle = rel.title.map { !$0.isEmpty } ?? false
    let hasTitle1 = rel.relationTitle1.map { !$0.isEmpty } ?? false
    let hasTitle2 = rel.relationTitle2.map { !$0.isEmpty } ?? false
    if !(hasTitle || hasTitle1 || hasTitle2) || rel.points.count < 2 { return "" }

    var parts: [String] = []

    if let title = rel.title, !title.isEmpty {
        let pos = rel.labelPosition ?? _midpoint(rel.points)
        parts.append(
            original_src_multiline_utils.renderMultilineText(
                title,
                cx: pos.x,
                cy: pos.y - 8,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    if let title1 = rel.relationTitle1, !title1.isEmpty {
        let p = rel.points[0]
        let next = rel.points[1]
        let offset = _cardinalityOffset(from: p, to: next)
        parts.append(
            original_src_multiline_utils.renderMultilineText(
                title1,
                cx: p.x + offset.x,
                cy: p.y + offset.y,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    if let title2 = rel.relationTitle2, !title2.isEmpty {
        let p = rel.points[rel.points.count - 1]
        let prev = rel.points[rel.points.count - 2]
        let offset = _cardinalityOffset(from: p, to: prev)
        parts.append(
            original_src_multiline_utils.renderMultilineText(
                title2,
                cx: p.x + offset.x,
                cy: p.y + offset.y,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text-muted)\""
            )
        )
    }

    return parts.joined(separator: "\n")
}

// MARK: - Namespace rendering

private func _renderNamespace(_ ns: PositionedClassNamespace) -> String {
    var parts: [String] = []

    parts.append("<g class=\"class-namespace\" data-id=\"\(_escapeAttr(ns.id))\">")

    // Background rect with dashed border
    parts.append(
        "  <rect x=\"\(ns.x)\" y=\"\(ns.y)\" width=\"\(ns.width)\" height=\"\(ns.height)\" " +
            "rx=\"4\" ry=\"4\" fill=\"none\" stroke=\"var(--_line)\" stroke-width=\"1.5\" stroke-dasharray=\"6 4\" />"
    )

    // Label in top-left
    if ns.height > 20 {
        let labelMetrics = original_src_text_metrics.measureMultilineText(
            ns.label,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
        )
        let labelW = labelMetrics.width + 16
        let labelH = labelMetrics.height + 8
        parts.append(
            "  <rect x=\"\(ns.x + CLS.boxPadX)\" y=\"\(ns.y - labelH / 2)\" width=\"\(labelW)\" height=\"\(labelH)\" " +
                "rx=\"2\" ry=\"2\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\" />"
        )
        parts.append(
            "  <text x=\"\(ns.x + CLS.boxPadX + 8)\" y=\"\(ns.y)\" dy=\"\(original_src_styles.TEXT_BASELINE_SHIFT)\" " +
                "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" " +
                "fill=\"var(--_text)\">\(SVG.escapeText(ns.label))</text>"
        )
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Note rendering

private func _renderNote(_ note: PositionedClassNote) -> String {
    var parts: [String] = []

    parts.append("<g class=\"class-note\" data-id=\"\(_escapeAttr(note.id))\" data-class=\"\(_escapeAttr(note.classId ?? ""))\">")

    // UML note shape: rectangle with folded corner
    let foldSize = 12.0
    let x = note.x, y = note.y, w = note.width, h = note.height
    let r = 4.0

    let pathParts: [String] = [
        "M \(x + r) \(y)",
        "L \(x + w - foldSize) \(y)",
        "L \(x + w - foldSize) \(y + foldSize)",
        "L \(x + w) \(y + foldSize)",
        "L \(x + w) \(y + h - r)",
        "Q \(x + w) \(y + h) \(x + w - r) \(y + h)",
        "L \(x + r) \(y + h)",
        "Q \(x) \(y + h) \(x) \(y + h - r)",
        "L \(x) \(y + r)",
        "Q \(x) \(y) \(x + r) \(y)",
        "Z",
    ]

    parts.append(
        "  <path d=\"\(pathParts.joined(separator: " "))\" " +
            "fill=\"var(--_note-bkg)\" stroke=\"var(--_note-border)\" stroke-width=\"1.5\" />"
    )

    // Folded corner line
    parts.append(
        "  <line x1=\"\(x + w - foldSize)\" y1=\"\(y)\" x2=\"\(x + w - foldSize)\" y2=\"\(y + foldSize)\" " +
            "stroke=\"var(--_line)\" stroke-width=\"1\" />"
    )
    parts.append(
        "  <line x1=\"\(x + w - foldSize)\" y1=\"\(y + foldSize)\" x2=\"\(x + w)\" y2=\"\(y + foldSize)\" " +
            "stroke=\"var(--_line)\" stroke-width=\"1\" />"
    )

    // Text
    parts.append(
        original_src_multiline_utils.renderMultilineText(
            note.text,
            cx: x + w / 2,
            cy: y + h / 2,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            attrs: "font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"middle\" font-weight=\"\(original_src_styles.FONT_WEIGHTS.edgeLabel)\" fill=\"var(--_text)\""
        )
    )

    // Dotted edge to class if attached
    if let edgePts = note.edgePoints, edgePts.count >= 2 {
        let pathData = edgePts.map { "\($0.x),\($0.y)" }.joined(separator: " ")
        parts.append(
            "<polyline points=\"\(pathData)\" fill=\"none\" stroke=\"var(--_line)\" " +
                "stroke-width=\"1\" stroke-dasharray=\"4 4\" />"
        )
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Helpers

private func _midpoint(_ points: [ClassPoint]) -> ClassPoint {
    if points.isEmpty { return ClassPoint(x: 0, y: 0) }
    let mid = points.count / 2
    return points[mid]
}

private func _cardinalityOffset(from: ClassPoint, to: ClassPoint) -> ClassPoint {
    let dx = to.x - from.x
    let dy = to.y - from.y
    if abs(dx) > abs(dy) {
        return ClassPoint(x: dx > 0 ? 14 : -14, y: -10)
    }
    return ClassPoint(x: -14, y: dy > 0 ? 14 : -14)
}

private func _escapeAttr(_ value: String) -> String {
    SVG.escapeAttribute(value)
}

open class original_src_class_renderer {
    public init() {}

    public static func renderClassSvg(
        _ diagram: PositionedClassDiagram,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderClassSvgEntry(diagram, colors, font, transparent)
    }
}
