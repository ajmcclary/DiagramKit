// Ported from original/src/sequence/renderer.ts
import Foundation
import DiagramKitCommon

public func renderSequenceSvg(
    _ diagram: PositionedSequenceDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false
) throws -> String {
    try _renderSequenceSvgEntry(diagram, colors, font, transparent)
}

private func _renderSequenceSvgEntry(
    _ diagram: PositionedSequenceDiagram,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var parts: [String] = []

    let svgBuilder = SVGDocumentBuilder(
        width: diagram.width,
        height: diagram.height,
        colors: colors,
        transparent: transparent,
        fontFamily: font,
        accessibilityTitle: diagram.accTitle,
        accessibilityDescription: diagram.accDescr
    )
    parts.append(svgBuilder.open())
    parts.append(svgBuilder.style())
    parts.append("<defs>")
    parts.append(_arrowMarkerDefs())
    parts.append("</defs>")

    // Title
    if let title = diagram.title {
        parts.append(_renderTitle(title, width: diagram.width))
    }

    // Accessibility
    parts.append(svgBuilder.accessibility())

    // Z-order: rect highlights behind everything
    for rect in diagram.rectHighlights {
        parts.append(_renderRectHighlight(rect))
    }

    // Boxes (actor groups)
    for box in diagram.boxes {
        parts.append(_renderBox(box))
    }

    // Blocks
    for block in diagram.blocks {
        if !block.isHighlight {
            parts.append(_renderBlock(block))
        }
    }

    // Lifelines
    for lifeline in diagram.lifelines {
        parts.append(_renderLifeline(lifeline))
    }

    // Activations
    for (idx, activation) in diagram.activations.enumerated() {
        let altClass = " activation\(idx % 3)"
        parts.append(_renderActivation(activation, altClass: altClass))
    }

    // Messages
    for (idx, message) in diagram.messages.enumerated() {
        parts.append(_renderMessage(message, index: idx))
    }

    // Notes
    for note in diagram.notes {
        parts.append(_renderNote(note))
    }

    // Actor boxes (on top)
    for (idx, actor) in diagram.actors.enumerated() {
        parts.append(_renderActor(actor, index: idx))
    }

    // Popup menus (hidden unless forceMenus)
    for (idx, actor) in diagram.actors.enumerated() {
        if !actor.links.isEmpty {
            parts.append(_renderPopup(actor, index: idx, forceMenus: false))
        }
    }

    // Mirror actors at bottom
    for (idx, actor) in diagram.bottomActors.enumerated() {
        let bottomIdx = diagram.actors.count + idx
        parts.append(_renderActor(actor, index: bottomIdx))
        if !actor.links.isEmpty {
            parts.append(_renderPopup(actor, index: bottomIdx, forceMenus: false))
        }
    }

    // Popup menu toggle script
    parts.append("""
    <script type="text/javascript">
    function popupMenuToggle(popId) {
      var pop = document.getElementById(popId);
      if (!pop) return;
      var vis = pop.getAttribute('visibility') === 'visible' ? 'hidden' : 'visible';
      pop.setAttribute('visibility', vis);
    }
    </script>
    """)

    parts.append(svgBuilder.close())
    return parts.joined(separator: "\n")
}

// MARK: - SVG Defs

private func _arrowMarkerDefs() -> String {
    let w: Double = 8
    let h: Double = 5
    var defs: [String] = []

    // filled triangle
    defs.append("""
      <marker id="seq-arrow-filled" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 0, \(w) \(h / 2), 0 \(h)" fill="var(--_arrow)" />
      </marker>
    """)

    // open V
    defs.append("""
      <marker id="seq-arrow-open" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polyline points="0 0, \(w) \(h / 2), 0 \(h)" fill="none" stroke="var(--_arrow)" stroke-width="1" />
      </marker>
    """)

    // cross (X)
    defs.append("""
      <marker id="seq-arrow-cross" markerWidth="\(w * 2)" markerHeight="\(h * 2)" refX="\(w * 2)" refY="\(h)" orient="auto-start-reverse">
        <line x1="\(w)" y1="-\(h)" x2="0" y2="\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="\(h)" x2="0" y2="-\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    // async open arc
    defs.append("""
      <marker id="seq-arrow-async" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <path d="M 1 \(h / 2) Q \(w / 2) -1, \(w - 1) \(h / 2)" fill="none" stroke="var(--_arrow)" stroke-width="1" />
      </marker>
    """)

    // Half arrow top
    defs.append("""
      <marker id="seq-arrow-half-top" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 0, \(w) \(h / 2), 0 \(h / 2)" fill="var(--_arrow)" />
      </marker>
    """)

    // Half arrow bottom
    defs.append("""
      <marker id="seq-arrow-half-bottom" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 \(h / 2), \(w) \(h / 2), 0 \(h)" fill="var(--_arrow)" />
      </marker>
    """)

    // Stick top
    defs.append("""
      <marker id="seq-arrow-stick-top" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <line x1="0" y1="0" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="0" x2="0" y2="0" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    // Stick bottom
    defs.append("""
      <marker id="seq-arrow-stick-bottom" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <line x1="0" y1="\(h / 2)" x2="0" y2="\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="\(h / 2)" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    // Reverse: Half arrow top (mirrored)
    defs.append("""
      <marker id="seq-arrow-half-top-rev" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 \(h / 2), \(w) 0, 0 0" fill="var(--_arrow)" />
      </marker>
    """)

    // Reverse: Half arrow bottom (mirrored)
    defs.append("""
      <marker id="seq-arrow-half-bottom-rev" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 \(h / 2), \(w) \(h), 0 \(h)" fill="var(--_arrow)" />
      </marker>
    """)

    // Reverse: Stick top (mirrored)
    defs.append("""
      <marker id="seq-arrow-stick-top-rev" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <line x1="0" y1="0" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="\(h / 2)" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    // Reverse: Stick bottom (mirrored)
    defs.append("""
      <marker id="seq-arrow-stick-bottom-rev" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <line x1="0" y1="\(h / 2)" x2="0" y2="\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="0" x2="0" y2="0" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    // Dotted reverse variants use same geometry, marker ID suffices for identification
    // Reverse dotted: Half arrow top
    defs.append("""
      <marker id="seq-arrow-half-top-rev-dot" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 \(h / 2), \(w) 0, 0 0" fill="var(--_arrow)" />
      </marker>
    """)

    // Reverse dotted: Half arrow bottom
    defs.append("""
      <marker id="seq-arrow-half-bottom-rev-dot" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <polygon points="0 \(h / 2), \(w) \(h), 0 \(h)" fill="var(--_arrow)" />
      </marker>
    """)

    // Reverse dotted: Stick top
    defs.append("""
      <marker id="seq-arrow-stick-top-rev-dot" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <line x1="0" y1="0" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="\(h / 2)" x2="0" y2="\(h / 2)" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    // Reverse dotted: Stick bottom
    defs.append("""
      <marker id="seq-arrow-stick-bottom-rev-dot" markerWidth="\(w)" markerHeight="\(h)" refX="\(w)" refY="\(h / 2)" orient="auto-start-reverse">
        <line x1="0" y1="\(h / 2)" x2="0" y2="\(h)" stroke="var(--_arrow)" stroke-width="1.5" />
        <line x1="\(w)" y1="0" x2="0" y2="0" stroke="var(--_arrow)" stroke-width="1.5" />
      </marker>
    """)

    return defs.joined(separator: "\n")
}

// MARK: - Marker ID by arrow type

private func _markerId(for arrowType: SequenceArrowType) -> String? {
    let style = SequenceArrowStyle(type: arrowType)
    if style.isCross { return "seq-arrow-cross" }
    if style.isOpenArrow { return "seq-arrow-async" }
    if !style.hasArrowEnd { return nil }
    if style.isHalfArrow {
        let suffix = style.isReversed ? "-rev" : ""
        let dotSuffix = style.isDotted ? "-dot" : ""
        let dir = style.halfArrowDirection == .top ? "top" : "bottom"
        let kind = style.halfArrowStyle == .stick ? "stick" : "half"
        return "seq-arrow-\(kind)-\(dir)\(suffix)\(dotSuffix)"
    }
    return "seq-arrow-filled"
}

// MARK: - Title

private func _renderTitle(_ title: String, width: Double) -> String {
    "<text x=\"\(width / 2)\" y=\"18\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"600\" fill=\"var(--_text)\">\(escapeXml(title))</text>"
}

// MARK: - Rect Highlight

private func _renderRectHighlight(_ rect: PositionedRectHighlight) -> String {
    "<rect class=\"rect-highlight\" x=\"\(rect.x)\" y=\"\(rect.y)\" width=\"\(max(rect.width, 0))\" height=\"\(max(rect.height, 0))\" fill=\"\(escapeAttr(rect.fill))\" stroke=\"none\" />"
}

// MARK: - Box

private func _renderBox(_ box: PositionedSequenceBox) -> String {
    var parts: [String] = []
    parts.append("<g class=\"box\" data-id=\"\(escapeAttr(box.id))\">")
    parts.append("  <rect x=\"\(box.x)\" y=\"\(box.y)\" width=\"\(box.width)\" height=\"\(box.height)\" fill=\"\(escapeAttr(box.fill))\" fill-opacity=\"0.1\" stroke=\"\(escapeAttr(box.fill))\" stroke-width=\"1\" stroke-dasharray=\"6 4\" rx=\"4\" ry=\"4\" />")
    if let name = box.name, !name.isEmpty {
        parts.append("  <text x=\"\(box.x + 6)\" y=\"\(box.y + 14)\" font-size=\"12\" font-weight=\"500\" fill=\"var(--_text-muted)\">\(escapeXml(name))</text>")
    }
    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Popup Menu

private func _renderPopup(_ actor: PositionedSequenceActor, index: Int, forceMenus: Bool) -> String {
    let links = actor.links
    guard !links.isEmpty else { return "" }
    var parts: [String] = []
    let popId = "actor\(index)_popup"
    let vis = forceMenus ? "visible" : "hidden"

    // Measure text widths for menu sizing
    let labelWidths = links.keys.map { original_src_styles.estimateTextWidth($0, 10, 400) + 20 }
    let menuWidth = max(100, (labelWidths.max() ?? 100) + 24)
    let lineHeight = 16.0
    let menuHeight = lineHeight * Double(links.count) + 16

    let menuX = actor.x - menuWidth / 2
    let menuY = actor.y + actor.height + 6

    parts.append("<g class=\"popup\" id=\"\(popId)\" visibility=\"\(vis)\" data-actors=\"\(escapeAttr(actor.id))\">")
    parts.append("  <rect x=\"\(menuX)\" y=\"\(menuY)\" width=\"\(menuWidth)\" height=\"\(menuHeight)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"1\" rx=\"4\" ry=\"4\" />")

    var linkY = menuY + 14
    for (label, url) in links {
        parts.append("  <a xlink:href=\"\(escapeAttr(url))\" target=\"_blank\">")
        parts.append("    <text x=\"\(menuX + 12)\" y=\"\(linkY)\" font-size=\"10\" fill=\"var(--_text-muted)\">\(escapeXml(label))</text>")
        parts.append("  </a>")
        linkY += lineHeight
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Actor

private func _renderActor(_ actor: PositionedSequenceActor, index: Int) -> String {
    let x = actor.x
    let y = actor.y
    let width = actor.width
    let height = actor.height
    let label = actor.label
    let pType = actor.participantType
    let hasLinks = !actor.links.isEmpty

    var parts: [String] = []
    var dataAttrs = "data-id=\"\(escapeAttr(actor.id))\" data-label=\"\(escapeAttr(label))\" data-type=\"\(escapeAttr(pType.rawValue))\""
    for (key, url) in actor.links {
        dataAttrs += " data-link-\(escapeAttr(key))=\"\(escapeAttr(url))\""
    }
    for (key, value) in actor.properties {
        dataAttrs += " data-prop-\(escapeAttr(key))=\"\(escapeAttr(value))\""
    }
    if let detailsId = actor.detailsElementId {
        dataAttrs += " data-details=\"\(escapeAttr(detailsId))\""
    }
    let interactive = hasLinks ? " onclick=\"popupMenuToggle('actor\(index)_popup')\" cursor=\"pointer\"" : ""
    parts.append("<g class=\"actor\"\(dataAttrs)\(interactive)>")

    switch pType {
    case .actor:
        let s = (height / 24) * 0.9
        let tx = x - 12 * s
        let ty = y + (height - 24 * s) / 2
        let sw = max(1.0, original_src_styles.STROKE_WIDTHS.outerBox / s)
        let iconStroke = "var(--_line)"
        parts.append("""
          <g transform="translate(\(tx),\(ty)) scale(\(s))">
            <path d="M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" fill="none" stroke="\(iconStroke)" stroke-width="\(sw)" />
            <path d="M15 10C15 11.6569 13.6569 13 12 13C10.3431 13 9 11.6569 9 10C9 8.34315 10.3431 7 12 7C13.6569 7 15 8.34315 15 10Z" fill="none" stroke="\(iconStroke)" stroke-width="\(sw)" />
            <path d="M5.62842 18.3563C7.08963 17.0398 9.39997 16 12 16C14.6 16 16.9104 17.0398 18.3716 18.3563" fill="none" stroke="\(iconStroke)" stroke-width="\(sw)" />
          </g>
        """)
        parts.append(_textEl(label, cx: x, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .participant:
        let boxX = x - width / 2
        parts.append("<rect x=\"\(boxX)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" rx=\"4\" ry=\"4\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        parts.append(_textEl(label, cx: x, cy: y + height / 2, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .boundary:
        let r = min(width, height) / 2 - 2
        let cy = y + height / 2
        parts.append("<circle cx=\"\(x)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        parts.append("<line x1=\"\(x)\" y1=\"\(cy - r)\" x2=\"\(x)\" y2=\"\(cy + r)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />")
        parts.append(_textEl(label, cx: x, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .control:
        let r = min(width, height) / 2 - 2
        let cy = y + height / 2
        parts.append("<circle cx=\"\(x)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        // Arrow at top of circle
        let arTop = cy - r
        parts.append("<polygon points=\"\(x),\(arTop - 6) \(x - 5),\(arTop) \(x + 5),\(arTop)\" fill=\"var(--_node-stroke)\" />")
        parts.append(_textEl(label, cx: x, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .entity:
        let r = min(width, height) / 2 - 2
        let cy = y + height / 2
        parts.append("<circle cx=\"\(x)\" cy=\"\(cy)\" r=\"\(r)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        // Horizontal line at bottom
        parts.append("<line x1=\"\(x - r)\" y1=\"\(cy + r * 0.6)\" x2=\"\(x + r)\" y2=\"\(cy + r * 0.6)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />")
        parts.append(_textEl(label, cx: x, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .database:
        let boxX = x - width / 2
        let ellH = 6.0
        parts.append("<path d=\"M\(boxX) \(y + ellH) L\(boxX) \(y + height - ellH) A\(width / 2) \(ellH) 0 0 0 \(boxX + width) \(y + height - ellH) L\(boxX + width) \(y + ellH) A\(width / 2) \(ellH) 0 1 1 \(boxX) \(y + ellH)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        parts.append("<ellipse cx=\"\(x)\" cy=\"\(y + ellH)\" rx=\"\(width / 2)\" ry=\"\(ellH)\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        parts.append(_textEl(label, cx: x, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .collections:
        let boxX = x - width / 2
        let offsetX = 3.0
        let offsetY = -3.0
        parts.append("<rect x=\"\(boxX + offsetX)\" y=\"\(y + offsetY)\" width=\"\(width)\" height=\"\(height)\" rx=\"3\" ry=\"3\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />")
        parts.append("<rect x=\"\(boxX)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" rx=\"3\" ry=\"3\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        parts.append(_textEl(label, cx: x + offsetX / 2, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))

    case .queue:
        let boxX = x - width / 2
        let ellH = 3.0
        parts.append("<path d=\"M\(boxX) \(y) L\(boxX) \(y + height) L\(boxX + width) \(y + height) A\(width / 2) \(ellH) 0 0 0 \(boxX + width) \(y) Z\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
        parts.append(_textEl(label, cx: x, cy: y + height + 14, fontSize: original_src_styles.FONT_SIZES.nodeLabel, anchor: "middle", cls: "actor-label"))
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Lifeline

private func _renderLifeline(_ lifeline: SequenceLifeline) -> String {
    "<line class=\"lifeline actor-line\" data-actor=\"\(escapeAttr(lifeline.actorId))\" x1=\"\(lifeline.x)\" y1=\"\(lifeline.topY)\" x2=\"\(lifeline.x)\" y2=\"\(lifeline.bottomY)\" stroke=\"var(--_line)\" stroke-width=\"0.75\" stroke-dasharray=\"6 4\" />"
}

// MARK: - Activation

private func _renderActivation(_ activation: SequenceActivation, altClass: String = "") -> String {
    "<rect class=\"activation\(altClass)\" data-actor=\"\(escapeAttr(activation.actorId))\" x=\"\(activation.x)\" y=\"\(activation.topY)\" width=\"\(activation.width)\" height=\"\(max(0, activation.bottomY - activation.topY))\" fill=\"var(--_node-fill)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
}

// MARK: - Message

private func _renderMessage(_ msg: PositionedSequenceMessage, index: Int = 0) -> String {
    var parts: [String] = []
    let dashArray = msg.lineStyle == "dashed" ? " stroke-dasharray=\"6 4\"" : ""
    let markerId = _markerId(for: msg.arrowType)
    let markerEnd = markerId.map { " marker-end=\"url(#\($0))\"" } ?? ""

    let style = SequenceArrowStyle(type: msg.arrowType)
    _ = style.isBidirectional
    let lineClass = "messageLine\(index % 2)"

    parts.append("<g class=\"message\" data-from=\"\(escapeAttr(msg.from))\" data-to=\"\(escapeAttr(msg.to))\" data-label=\"\(escapeAttr(msg.label))\" data-arrow-type=\"\(escapeAttr(String(msg.arrowType.rawValue)))\" data-self=\"\(msg.isSelf)\">")

    // Sequence number
    if msg.sequenceVisible, let num = msg.sequenceNumber {
        let numX = msg.isSelf ? msg.x1 - 18 : min(msg.x1, msg.x2) - 18
        parts.append("<text class=\"sequenceNumber\" x=\"\(numX)\" y=\"\(msg.y - 2)\" font-size=\"\(original_src_styles.FONT_SIZES.edgeLabel)\" text-anchor=\"end\" fill=\"var(--_text-muted)\">\(Int(num))</text>")
    }

    // Central connection circle at source
    if let cc = msg.centralConnection, (cc == .source || cc == .both) {
        let cx = msg.isSelf ? msg.x1 : msg.x1
        parts.append("<circle cx=\"\(cx)\" cy=\"\(msg.y)\" r=\"5\" fill=\"var(--_bg)\" stroke=\"var(--_line)\" stroke-width=\"1\" />")
    }
    // Central connection circle at dest
    if let cc = msg.centralConnection, (cc == .dest || cc == .both) {
        let cx = msg.isSelf ? msg.x2 : msg.x2
        parts.append("<circle cx=\"\(cx)\" cy=\"\(msg.y)\" r=\"5\" fill=\"var(--_bg)\" stroke=\"var(--_line)\" stroke-width=\"1\" />")
    }

    if msg.isSelf {
        let loopW = 30.0
        let loopH = 20.0
        let labelPadding = 8.0
        parts.append("<polyline class=\"\(lineClass)\" points=\"\(msg.x1),\(msg.y) \(msg.x1 + loopW),\(msg.y) \(msg.x1 + loopW),\(msg.y + loopH) \(msg.x2),\(msg.y + loopH)\" fill=\"none\" stroke=\"var(--_line)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray)\(markerEnd) />")
        parts.append(_textEl(msg.label, cx: msg.x1 + loopW + labelPadding, cy: msg.y + loopH / 2, fontSize: original_src_styles.FONT_SIZES.edgeLabel, anchor: "start", cls: "messageText"))
    } else {
        // Bidirectional uses marker-start too
        let mStart = style.isBidirectional && markerId != nil ? " marker-start=\"url(#\(markerId!))\"" : ""
        parts.append("<line class=\"\(lineClass)\" x1=\"\(msg.x1)\" y1=\"\(msg.y)\" x2=\"\(msg.x2)\" y2=\"\(msg.y)\" stroke=\"var(--_line)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.connector)\"\(dashArray)\(markerEnd)\(mStart) />")
        let midX = (msg.x1 + msg.x2) / 2
        parts.append(_textEl(msg.label, cx: midX, cy: msg.y - 6, fontSize: original_src_styles.FONT_SIZES.edgeLabel, anchor: "middle", cls: "messageText"))
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Block

private func _renderBlock(_ block: PositionedSequenceBlock) -> String {
    var parts: [String] = []
    let labelAttr = block.label.isEmpty ? "" : " data-label=\"\(escapeAttr(block.label))\""
    parts.append("<g class=\"block\" data-type=\"\(escapeAttr(block.type))\"\(labelAttr)>")
    parts.append("<rect class=\"loopLine\" x=\"\(block.x)\" y=\"\(block.y)\" width=\"\(block.width)\" height=\"\(block.height)\" rx=\"0\" ry=\"0\" fill=\"none\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")

    let labelText = block.label.isEmpty ? block.type : "\(block.type) [\(block.label)]"
    let firstLine = labelText.components(separatedBy: "\n").first ?? labelText
    let tabWidth = original_src_styles.estimateTextWidth(firstLine, original_src_styles.FONT_SIZES.edgeLabel, original_src_styles.FONT_WEIGHTS.groupHeader) + 16
    let tabHeight = 18.0

    parts.append("<rect class=\"labelBox\" x=\"\(block.x)\" y=\"\(block.y)\" width=\"\(tabWidth)\" height=\"\(tabHeight)\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.outerBox)\" />")
    parts.append(_textEl(labelText, cx: block.x + 6, cy: block.y + tabHeight / 2, fontSize: original_src_styles.FONT_SIZES.edgeLabel, anchor: "start", cls: "labelText loopText", weight: original_src_styles.FONT_WEIGHTS.groupHeader))

    for divider in block.dividers {
        parts.append("<line x1=\"\(block.x)\" y1=\"\(divider.y)\" x2=\"\(block.x + block.width)\" y2=\"\(divider.y)\" stroke=\"var(--_line)\" stroke-width=\"0.75\" stroke-dasharray=\"6 4\" />")
        if !divider.label.isEmpty {
            parts.append(_textEl("[\(divider.label)]", cx: block.x + 8, cy: divider.y + 14, fontSize: original_src_styles.FONT_SIZES.edgeLabel, anchor: "start", cls: "divider-label"))
        }
    }

    parts.append("</g>")
    return parts.joined(separator: "\n")
}

// MARK: - Note

private func _renderNote(_ note: PositionedSequenceNote) -> String {
    let foldSize = 6.0
    let actorsAttr = note.actors.isEmpty ? "" : " data-actors=\"\(note.actors.map(escapeAttr).joined(separator: ","))\""
    let positionAttr = note.position.isEmpty ? "" : " data-position=\"\(escapeAttr(note.position))\""

    let noteText = _textEl(note.text, cx: note.x + note.width / 2, cy: note.y + note.height / 2, fontSize: original_src_styles.FONT_SIZES.edgeLabel, anchor: "middle", cls: "noteText")

    return "<g class=\"note\"\(positionAttr)\(actorsAttr)>"
        + "\n  <rect class=\"note\" x=\"\(note.x)\" y=\"\(note.y)\" width=\"\(note.width)\" height=\"\(note.height)\" fill=\"var(--_group-hdr)\" stroke=\"var(--_node-stroke)\" stroke-width=\"\(original_src_styles.STROKE_WIDTHS.innerBox)\" />"
        + "\n  <polygon points=\"\(note.x + note.width - foldSize),\(note.y) \(note.x + note.width),\(note.y + foldSize) \(note.x + note.width - foldSize),\(note.y + foldSize)\" fill=\"var(--_inner-stroke)\" />"
        + "\n  \(noteText)"
        + "\n</g>"
}

// MARK: - Text Helper

private func _textEl(_ text: String, cx: Double, cy: Double, fontSize: Double, anchor: String, cls: String, weight: Int? = nil) -> String {
    let w = weight.map { " font-weight=\"\($0)\"" } ?? ""
    return "<text class=\"\(cls)\" x=\"\(cx)\" y=\"\(cy)\" font-size=\"\(fontSize)\" text-anchor=\"\(anchor)\" fill=\"var(--_text-muted)\"\(w)>\(escapeXml(text))</text>"
}

// MARK: - XML helpers

private func escapeXml(_ value: String) -> String {
    SVG.escapeText(value)
}

private func escapeAttr(_ value: String) -> String {
    SVG.escapeAttribute(value)
}

// MARK: - Legacy class

open class original_src_sequence_renderer {
    public init() {}

    public static func renderSequenceSvg(
        _ diagram: PositionedSequenceDiagram,
        _ colors: DiagramColors,
        _ font: String = "Inter",
        _ transparent: Bool = false
    ) throws -> String {
        try _renderSequenceSvgEntry(diagram, colors, font, transparent)
    }
}
