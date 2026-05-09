import Foundation

private final class _SankeyUidGenerator: @unchecked Sendable {
    private var counter = 0
    private let scope: String

    init(scope: String) {
        self.scope = scope
    }

    func next(_ prefix: String) -> String {
        counter += 1
        return "\(prefix)\(scope)-\(counter)"
    }

    func reset() {
        counter = 0
    }
}

private final class _SankeyRenderScopeCounter: @unchecked Sendable {
    static let shared = _SankeyRenderScopeCounter()

    private let lock = NSLock()
    private var counter = 0

    func next() -> String {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        return "sankey-\(counter)"
    }
}

public func renderSankeySvg(
    _ positioned: PositionedSankeyDiagram,
    _ colors: DiagramColors,
    _ font: String = "Inter",
    _ transparent: Bool = false,
    diagramId: String? = nil
) -> String {
    let uid = _SankeyUidGenerator(scope: diagramId ?? _SankeyRenderScopeCounter.shared.next())

    let themeColors = original_src_theme.DiagramColors(
        bg: colors.bg, fg: colors.fg, line: colors.line,
        accent: colors.accent, muted: colors.muted,
        surface: colors.surface, border: colors.border
    )

    let nodeColorMap = _buildNodeColorMap(positioned)

    var parts: [String] = []

    let viewBoxX = positioned.config.useMaxWidth ? 0.0 : -10.0
    let viewBoxY = positioned.config.useMaxWidth ? 0.0 : -10.0
    let vbWidth = positioned.config.useMaxWidth ? positioned.width : positioned.width + 20
    let vbHeight = positioned.config.useMaxWidth ? positioned.height : positioned.height + 20

    var svgTag = original_src_theme.svgOpenTag(
        vbWidth, vbHeight, themeColors, transparent,
        viewBoxX: viewBoxX, viewBoxY: viewBoxY
    )
    var rootAttributes = [
        #"role="graphics-document document""#,
        #"aria-roledescription="sankey""#,
    ]
    if let label = positioned.accTitle ?? positioned.diagramTitle, !label.isEmpty {
        rootAttributes.append(#"aria-label="\#(_sankeyEscapeXml(label))""#)
    }
    svgTag = _sankeyInjectSvgAttributes(svgTag, rootAttributes)
    parts.append(svgTag)

    if let accTitle = positioned.accTitle {
        parts.append("<title>\(_sankeyEscapeXml(accTitle))</title>")
    }
    if let accDescr = positioned.accDescr {
        parts.append("<desc>\(_sankeyEscapeXml(accDescr))</desc>")
    }

    parts.append("<style>")
    parts.append("""
    .node rect { shape-rendering: crispEdges; }
    .node-labels { font-family: \(_sankeyEscapeXml(font)), sans-serif; font-size: 14px; fill: \(_sankeyEscapeXml(colors.fg)); }
    .sankey-label-bg {
        stroke: \(_sankeyEscapeXml(colors.bg));
        stroke-width: 4px;
        stroke-linejoin: round;
        paint-order: stroke;
    }
    .sankey-label-fg { fill: \(_sankeyEscapeXml(colors.fg)); }
    .link { fill: none; stroke-opacity: 0.5; mix-blend-mode: multiply; }
    """)
    parts.append("</style>")

    parts.append(#"<g class="sankey sankey-diagram">"#)

    if !positioned.links.isEmpty {
        parts.append(#"<g class="links">"#)
        for link in positioned.links {
            let sourceColor = nodeColorMap[link.sourceID] ?? _defaultSankeyColor(for: link.sourceID, allNodes: positioned.nodes)
            let targetColor = nodeColorMap[link.targetID] ?? _defaultSankeyColor(for: link.targetID, allNodes: positioned.nodes)
            let gradientId = uid.next("linearGradient-")
            let strokeWidth = max(1, link.width)

            var strokeValue: String
            switch positioned.config.linkColor {
            case .gradient:
                parts.append("<defs>")
                parts.append(#"<linearGradient id="\#(gradientId)" gradientUnits="userSpaceOnUse" x1="\#(_sankeyFmt(positioned.nodes.first(where: { $0.id == link.sourceID })?.x1 ?? link.path.sourceX))" x2="\#(_sankeyFmt(positioned.nodes.first(where: { $0.id == link.targetID })?.x0 ?? link.path.targetX))">"#)
                parts.append(#"<stop offset="0%" stop-color="\#(_sankeyEscapeXml(sourceColor))"/>"#)
                parts.append(#"<stop offset="100%" stop-color="\#(_sankeyEscapeXml(targetColor))"/>"#)
                parts.append("</linearGradient>")
                parts.append("</defs>")
                strokeValue = "url(#\(gradientId))"
            case .source:
                strokeValue = sourceColor
            case .target:
                strokeValue = targetColor
            case .fixed(let color):
                strokeValue = color
            }

            parts.append(#"<g class="link" style="mix-blend-mode: multiply;">"#)
            parts.append(#"<path d="\#(link.path.svgD)" fill="none" stroke="\#(_sankeyEscapeXml(strokeValue))" stroke-width="\#(_sankeyFmt(strokeWidth))" stroke-opacity="0.5"/>"#)
            parts.append("</g>")
        }
        parts.append("</g>")
    }

    if !positioned.nodes.isEmpty {
        parts.append(#"<g class="nodes">"#)

        let halfWidth = positioned.width / 2
        let centerLayer = _centralNodeLayer(positioned)

        for node in positioned.nodes {
            let nodeId = uid.next("node-")
            let nodeColor = nodeColorMap[node.id] ?? _defaultSankeyColor(for: node.id, allNodes: positioned.nodes)
            let nodeHeight = node.y1 - node.y0
            let nodeWidth = node.x1 - node.x0

            parts.append(#"<g class="node" id="\#(nodeId)" transform="translate(\#(_sankeyFmt(node.x0)),\#(_sankeyFmt(node.y0)))" x="\#(_sankeyFmt(node.x0))" y="\#(_sankeyFmt(node.y0)))">"#)
            parts.append(#"<rect x="0" y="0" width="\#(_sankeyFmt(nodeWidth))" height="\#(_sankeyFmt(nodeHeight))" fill="\#(_sankeyEscapeXml(nodeColor))" shape-rendering="crispEdges"/>"#)
            parts.append("</g>")
        }
        parts.append("</g>")

        parts.append(#"<g class="node-labels">"#)
        for node in positioned.nodes {
            _ = nodeColorMap[node.id] ?? _defaultSankeyColor(for: node.id, allNodes: positioned.nodes)

            let labelText: String
            if positioned.config.showValues {
                let prefix = positioned.config.prefix
                let suffix = positioned.config.suffix
                let formatted = _sankeyFormatValue(max(0, node.value))
                labelText = "\(node.id)\n\(prefix)\(formatted)\(suffix)"
            } else {
                labelText = node.id
            }

            switch positioned.config.labelStyle {
            case .legacy:
                if node.x0 < halfWidth {
                    let labelX = node.x1 + 6
                    let labelY = node.y0 + (node.y1 - node.y0) / 2
                    let dy = positioned.config.showValues ? "0" : "0.35em"
                    parts.append(#"<text x="\#(_sankeyFmt(labelX))" y="\#(_sankeyFmt(labelY))" dy="\#(dy)" text-anchor="start" fill="\#(_sankeyEscapeXml(colors.fg))">\#(_sankeyEscapeXml(labelText))</text>"#)
                } else {
                    let labelX = node.x0 - 6
                    let labelY = node.y0 + (node.y1 - node.y0) / 2
                    let dy = positioned.config.showValues ? "0" : "0.35em"
                    parts.append(#"<text x="\#(_sankeyFmt(labelX))" y="\#(_sankeyFmt(labelY))" dy="\#(dy)" text-anchor="end" fill="\#(_sankeyEscapeXml(colors.fg))">\#(_sankeyEscapeXml(labelText))</text>"#)
                }
            case .outlined:
                let isLeftOfCenter = node.layer < centerLayer
                if isLeftOfCenter {
                    let labelX = node.x0 - 6
                    let labelY = node.y0 + (node.y1 - node.y0) / 2
                    let dy = positioned.config.showValues ? "0" : "0.35em"
                    parts.append(#"<text class="sankey-label-bg" x="\#(_sankeyFmt(labelX))" y="\#(_sankeyFmt(labelY))" dy="\#(dy)" text-anchor="end">\#(_sankeyEscapeXml(labelText))</text>"#)
                    parts.append(#"<text class="sankey-label-fg" x="\#(_sankeyFmt(labelX))" y="\#(_sankeyFmt(labelY))" dy="\#(dy)" text-anchor="end">\#(_sankeyEscapeXml(labelText))</text>"#)
                } else {
                    let labelX = node.x1 + 6
                    let labelY = node.y0 + (node.y1 - node.y0) / 2
                    let dy = positioned.config.showValues ? "0" : "0.35em"
                    parts.append(#"<text class="sankey-label-bg" x="\#(_sankeyFmt(labelX))" y="\#(_sankeyFmt(labelY))" dy="\#(dy)" text-anchor="start">\#(_sankeyEscapeXml(labelText))</text>"#)
                    parts.append(#"<text class="sankey-label-fg" x="\#(_sankeyFmt(labelX))" y="\#(_sankeyFmt(labelY))" dy="\#(dy)" text-anchor="start">\#(_sankeyEscapeXml(labelText))</text>"#)
                }
            }
        }
        parts.append("</g>")
    }

    parts.append("</g>")
    parts.append("</svg>")

    return parts.joined(separator: "\n")
}

private func _sankeyFmt(_ n: Double) -> String {
    let rounded = (n * 10).rounded() / 10
    if rounded.isFinite && abs(rounded) < 1e15 && rounded == rounded.rounded() {
        return String(Int(rounded))
    }
    if !rounded.isFinite { return "0" }
    return String(format: "%.1f", rounded)
}

private func _sankeyEscapeXml(_ text: String) -> String {
    SVG.escapeText(text)
}

private func _sankeyInjectSvgAttributes(_ svgTag: String, _ attributes: [String]) -> String {
    guard let close = svgTag.lastIndex(of: ">"), !attributes.isEmpty else { return svgTag }
    var tag = svgTag
    tag.insert(contentsOf: " " + attributes.joined(separator: " "), at: close)
    return tag
}

private func _buildNodeColorMap(_ positioned: PositionedSankeyDiagram) -> [String: String] {
    var map: [String: String] = [:]
    for node in positioned.nodes {
        if let custom = positioned.config.nodeColors[node.id] {
            map[node.id] = custom
        }
    }
    return map
}

private func _defaultSankeyColor(for id: String, allNodes: [PositionedSankeyNode]) -> String {
    if let idx = allNodes.firstIndex(where: { $0.id == id }) {
        return sankeyTableau10[idx % sankeyTableau10.count]
    }
    return sankeyTableau10[0]
}

private func _centralNodeLayer(_ positioned: PositionedSankeyDiagram) -> Int {
    let maxNode = positioned.nodes.max(by: { $0.value < $1.value })
    return maxNode?.layer ?? 0
}

private func _sankeyFormatValue(_ v: Double) -> String {
    let rounded = (v * 100).rounded() / 100
    if !rounded.isFinite { return "0" }
    if rounded == rounded.rounded() { return String(Int(rounded)) }
    let str = String(format: "%.2f", rounded)
    if str.hasSuffix("0") {
        return String(format: "%.1f", rounded)
    }
    return str
}
