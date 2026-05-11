import Foundation
import DiagramKitCommon

public func renderWardleyMapSvg(
    _ diagram: PositionedWardleyMapDiagram,
    colors: DiagramColors,
    font: String,
    transparent: Bool
) -> String {
    let theme = diagram.theme ?? .default
    let width = diagram.width
    let height = diagram.height
    let padding = diagram.padding
    let config = diagram.config

    let bgColor = transparent ? "transparent" : theme.backgroundColor
    let axisColor = theme.axisColor
    let axisTextColor = theme.axisTextColor
    let linkStroke = theme.linkStroke
    let evolutionStroke = theme.evolutionStroke
    let componentStroke = theme.componentStroke
    let componentFill = theme.componentFill
    let componentLabelColor = theme.componentLabelColor
    let annotationStroke = theme.annotationStroke
    let annotationTextColor = theme.annotationTextColor
    let annotationFill = theme.annotationFill
    let gridColor = theme.gridColor

    let diagramId = "wardley"

    let builder = SVGDocumentBuilder(
        width: width,
        height: height,
        colors: colors,
        transparent: transparent,
        fontFamily: font,
        accessibilityTitle: diagram.accTitle,
        accessibilityDescription: diagram.accDescr
    )
    var svg = builder.open(className: "wardley-map", extraAttributes: "id=\"\(diagramId)\" role=\"graphics-document document\"") + "\n\n"

    // Accessibility metadata
    if let accTitle = diagram.accTitle {
        svg += "<title>\(escapingXml(accTitle))</title>\n"
    }
    if let accDescr = diagram.accDescr {
        svg += "<desc>\(escapingXml(accDescr))</desc>\n"
    }

    // Style block
    svg += """
    <style>
    .wardley-background { fill: \(bgColor); }
    .wardley-axes { stroke: \(axisColor); stroke-width: 1.5; }
    .wardley-axis-label { font-family: "\(font)", sans-serif; font-size: \(Int(config.axisFontSize))px; fill: \(axisTextColor); }
    .wardley-axis-label-x { text-anchor: middle; }
    .wardley-axis-label-y { text-anchor: middle; }
    .wardley-stage-label { font-family: "\(font)", sans-serif; font-size: \(Int(config.axisFontSize - 2))px; fill: \(axisTextColor); text-anchor: middle; }
    .wardley-grid { stroke: \(gridColor); stroke-dasharray: 2 6; stroke-width: 1; }
    .wardley-node { font-family: "\(font)", sans-serif; }
    .wardley-node--anchor { font-weight: bold; }
    .wardley-node--component { font-weight: normal; }
    .wardley-node--pipeline-component { font-weight: normal; }
    .wardley-node-label { fill: \(componentLabelColor); font-size: \(Int(config.labelFontSize))px; }
    .wardley-link { stroke: \(linkStroke); stroke-width: 1; fill: none; }
    .wardley-link--dashed { stroke-dasharray: 6 6; }
    .wardley-link-label { font-family: "\(font)", sans-serif; font-size: \(Int(config.labelFontSize - 2))px; fill: \(componentLabelColor); text-anchor: start; }
    .wardley-trend { stroke: \(evolutionStroke); stroke-dasharray: 4 4; stroke-width: 1; fill: none; }
    .wardley-annotation-line { stroke: \(annotationStroke); stroke-dasharray: 4 4; stroke-width: 1; fill: none; }
    .wardley-annotation { fill: \(annotationFill); stroke: \(annotationStroke); stroke-width: 1; }
    .wardley-annotation-text { font-family: "\(font)", sans-serif; font-size: \(Int(config.labelFontSize))px; fill: \(annotationTextColor); text-anchor: middle; dominant-baseline: central; }
    .wardley-annotations-box { fill: \(annotationFill); stroke: \(annotationStroke); stroke-width: 1; }
    .wardley-annotations-box-text { font-family: "\(font)", sans-serif; font-size: \(Int(config.labelFontSize - 2))px; fill: \(annotationTextColor); text-anchor: start; }
    .wardley-notes { font-family: "\(font)", sans-serif; font-size: \(Int(config.labelFontSize))px; fill: \(axisTextColor); font-weight: bold; text-anchor: start; }
    .wardley-accelerators { fill: \(componentFill); stroke: \(componentStroke); stroke-width: 1; }
    .wardley-accelerator-label { font-family: "\(font)", sans-serif; font-size: \(Int(config.labelFontSize))px; fill: \(componentLabelColor); font-weight: bold; text-anchor: middle; }
    .wardley-deaccelerators { fill: \(componentFill); stroke: \(componentStroke); stroke-width: 1; }
    .wardley-deaccelerator-label { font-family: "\(font)", sans-serif; font-size: \(Int(config.labelFontSize))px; fill: \(componentLabelColor); font-weight: bold; text-anchor: middle; }
    .wardley-pipelines { }
    .wardley-pipeline-box { fill: none; stroke: \(componentStroke); stroke-width: 1.5; }
    .wardley-pipeline-evolution-link { fill: none; stroke: \(componentStroke); stroke-dasharray: 4 4; stroke-width: 1; }
    .wardley-market-overlay { fill: white; stroke: \(componentStroke); stroke-width: 1; }
    .wardley-market-line { stroke: \(componentStroke); stroke-width: 1; fill: none; }
    .wardley-market-dot { fill: white; stroke: \(componentStroke); stroke-width: 1; }
    .wardley-outsource-overlay { fill: #666; }
    .wardley-buy-overlay { fill: #ccc; }
    .wardley-build-overlay { fill: #eee; stroke: #000; stroke-width: 1; }
    .wardley-inertia { stroke: \(componentStroke); stroke-width: 6; stroke-linecap: round; }
    .wardley-title { font-family: "\(font)", sans-serif; font-size: \(Int(config.axisFontSize * 1.05))px; fill: \(axisTextColor); font-weight: bold; text-anchor: middle; }
    </style>

    """

    // Defs with arrow markers
    svg += """
    <defs>
    <marker id="arrow-\(diagramId)" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="\(evolutionStroke)" />
    </marker>
    <marker id="link-arrow-end-\(diagramId)" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
      <path d="M 0 0 L 10 5 L 0 10 z" fill="\(linkStroke)" />
    </marker>
    <marker id="link-arrow-start-\(diagramId)" viewBox="0 0 10 10" refX="1" refY="5" markerWidth="5" markerHeight="5" orient="auto-start-reverse">
      <path d="M 10 0 L 0 5 L 10 10 z" fill="\(linkStroke)" />
    </marker>
    </defs>

    """

    // Background
    if !transparent {
        svg += "<rect class=\"wardley-background\" x=\"0\" y=\"0\" width=\"\(Int(width))\" height=\"\(Int(height))\" />\n"
    }

    // Title
    if let title = diagram.diagramTitle {
        svg += "<text class=\"wardley-title\" x=\"\(Int(width / 2))\" y=\"\(Int(config.padding / 2))\">\(escapingXml(title))</text>\n"
    }

    // Axis group
    let axisX1 = Int(padding)
    let axisY1 = Int(height - padding)
    let axisX2 = Int(width - padding)
    let axisY2 = Int(padding)

    svg += """
    <g class="wardley-axes">
    <line x1="\(axisX1)" y1="\(axisY1)" x2="\(axisX2)" y2="\(axisY1)" />
    <line x1="\(axisX1)" y1="\(axisY1)" x2="\(axisX1)" y2="\(axisY2)" />
    <text class="wardley-axis-label wardley-axis-label-x" x="\(Int(width / 2))" y="\(Int(height - padding / 4))">\(escapingXml(diagram.axes.xLabel ?? "Evolution"))</text>
    <text class="wardley-axis-label wardley-axis-label-y" x="\(Int(padding / 4))" y="\(Int(height / 2))" transform="rotate(-90, \(Int(padding / 4)), \(Int(height / 2)))">\(escapingXml(diagram.axes.yLabel ?? "Visibility"))</text>
    </g>

    """

    // Stage group
    svg += "<g class=\"wardley-stages\">\n"
    for stage in diagram.stages {
        svg += "<line class=\"wardley-stage-divider\" x1=\"\(Int(stage.startX))\" y1=\"\(Int(padding))\" x2=\"\(Int(stage.startX))\" y2=\"\(Int(height - padding))\" stroke=\"\(axisColor)\" stroke-dasharray=\"5 5\" opacity=\"0.8\" />\n"
        svg += "<text class=\"wardley-stage-label\" x=\"\(Int(stage.centerX))\" y=\"\(Int(stage.labelY))\">\(escapingXml(stage.name))</text>\n"
    }
    svg += "</g>\n"

    // Grid group
    if diagram.showGrid && !diagram.gridLines.isEmpty {
        svg += "<g class=\"wardley-grid\">\n"
        for grid in diagram.gridLines {
            svg += "<line x1=\"\(Int(grid.x1))\" y1=\"\(Int(grid.y1))\" x2=\"\(Int(grid.x2))\" y2=\"\(Int(grid.y2))\" />\n"
        }
        svg += "</g>\n"
    }

    // Pipeline group
    if !diagram.pipelineBoxes.isEmpty {
        svg += "<g class=\"wardley-pipelines\">\n"
        for box in diagram.pipelineBoxes {
            svg += "<rect class=\"wardley-pipeline-box\" x=\"\(Int(box.x))\" y=\"\(Int(box.y))\" width=\"\(Int(box.width))\" height=\"\(Int(box.height))\" rx=\"4\" ry=\"4\" />\n"
            for childLink in box.childLinks {
                svg += "<line class=\"wardley-pipeline-evolution-link\" x1=\"\(Int(childLink.x1))\" y1=\"\(Int(childLink.y1))\" x2=\"\(Int(childLink.x2))\" y2=\"\(Int(childLink.y2))\" />\n"
            }
        }
        svg += "</g>\n"
    }

    // Links group
    if !diagram.validLinks.isEmpty {
        svg += "<g class=\"wardley-links\">\n"
        for link in diagram.validLinks {
            var classAttr = "wardley-link"
            if link.dashed { classAttr += " wardley-link--dashed" }

            var markerEnd = ""
            var markerStart = ""
            if link.flow == .forward || link.flow == .bidirectional {
                markerEnd = " marker-end=\"url(#link-arrow-end-\(diagramId))\""
            }
            if link.flow == .backward || link.flow == .bidirectional {
                markerStart = " marker-start=\"url(#link-arrow-start-\(diagramId))\""
            }

            svg += "<line class=\"\(classAttr)\" x1=\"\(Int(link.sourceX))\" y1=\"\(Int(link.sourceY))\" x2=\"\(Int(link.targetX))\" y2=\"\(Int(link.targetY))\"\(markerEnd)\(markerStart) />\n"

            if let label = link.label, let lx = link.labelX, let ly = link.labelY {
                let angle = link.labelAngle ?? 0
                svg += "<text class=\"wardley-link-label\" x=\"\(Int(lx))\" y=\"\(Int(ly))\" transform=\"rotate(\(Int(angle)), \(Int(lx)), \(Int(ly)))\">\(escapingXml(label))</text>\n"
            }
        }
        svg += "</g>\n"
    }

    // Trends group
    if !diagram.trends.isEmpty {
        svg += "<g class=\"wardley-trends\">\n"
        for trend in diagram.trends {
            svg += "<line class=\"wardley-trend\" x1=\"\(Int(trend.originX))\" y1=\"\(Int(trend.originY))\" x2=\"\(Int(trend.targetX))\" y2=\"\(Int(trend.targetY))\" marker-end=\"url(#arrow-\(diagramId))\" />\n"
        }
        svg += "</g>\n"
    }

    // Nodes group
    svg += "<g class=\"wardley-nodes\">\n"
    let nodeRadius = config.nodeRadius
    for node in diagram.nodes {
        var groupClass = "wardley-node"
        if let className = node.className {
            groupClass += " wardley-node--\(className.rawValue)"
        } else {
            groupClass += " wardley-node--component"
        }

        svg += "<g class=\"\(groupClass)\">\n"

        // Source strategy overlays (rendered behind main node)
        switch node.sourceStrategy {
        case .outsource:
            svg += "<circle class=\"wardley-outsource-overlay\" cx=\"\(Int(node.x))\" cy=\"\(Int(node.y))\" r=\"\(Int(nodeRadius * 2))\" />\n"
        case .buy:
            svg += "<circle class=\"wardley-buy-overlay\" cx=\"\(Int(node.x))\" cy=\"\(Int(node.y))\" r=\"\(Int(nodeRadius * 2))\" />\n"
        case .build:
            svg += "<circle class=\"wardley-build-overlay\" cx=\"\(Int(node.x))\" cy=\"\(Int(node.y))\" r=\"\(Int(nodeRadius * 2))\" />\n"
        case .market:
            svg += "<circle class=\"wardley-market-overlay\" cx=\"\(Int(node.x))\" cy=\"\(Int(node.y))\" r=\"\(Int(nodeRadius * 2))\" />\n"
            // Three small circles in triangle
            let mc = Int(nodeRadius * 2)
            let mdx = Int(Double(mc) * cos(.pi / 6))
            let mdy = Int(Double(mc) * sin(.pi / 6))
            svg += "<circle class=\"wardley-market-dot\" cx=\"\(Int(node.x))\" cy=\"\(Int(node.y) - mc)\" r=\"2\" />\n"
            svg += "<circle class=\"wardley-market-dot\" cx=\"\(Int(node.x) - mdx)\" cy=\"\(Int(node.y) + mdy)\" r=\"2\" />\n"
            svg += "<circle class=\"wardley-market-dot\" cx=\"\(Int(node.x) + mdx)\" cy=\"\(Int(node.y) + mdy)\" r=\"2\" />\n"
            svg += "<line class=\"wardley-market-line\" x1=\"\(Int(node.x))\" y1=\"\(Int(node.y) - mc)\" x2=\"\(Int(node.x) - mdx)\" y2=\"\(Int(node.y) + mdy)\" />\n"
            svg += "<line class=\"wardley-market-line\" x1=\"\(Int(node.x) - mdx)\" y1=\"\(Int(node.y) + mdy)\" x2=\"\(Int(node.x) + mdx)\" y2=\"\(Int(node.y) + mdy)\" />\n"
            svg += "<line class=\"wardley-market-line\" x1=\"\(Int(node.x) + mdx)\" y1=\"\(Int(node.y) + mdy)\" x2=\"\(Int(node.x))\" y2=\"\(Int(node.y) - mc)\" />\n"
        case .none:
            break
        }

        // Main node shape
        if node.isPipelineParent {
            let sqSize = nodeRadius * 1.6
            svg += "<rect class=\"wardley-node-shape\" x=\"\(Int(node.x - sqSize / 2))\" y=\"\(Int(node.y - sqSize / 2))\" width=\"\(Int(sqSize))\" height=\"\(Int(sqSize))\" fill=\"\(componentFill)\" stroke=\"\(componentStroke)\" stroke-width=\"1\" />\n"
        } else if node.className == .anchor {
            // Anchors don't have a circle, just bold centered label
        } else {
            svg += "<circle class=\"wardley-node-shape\" cx=\"\(Int(node.x))\" cy=\"\(Int(node.y))\" r=\"\(Int(nodeRadius))\" fill=\"\(componentFill)\" stroke=\"\(componentStroke)\" stroke-width=\"1\" />\n"
        }

        // Inertia line
        if node.inertia {
            var inertiaOffset = nodeRadius + 6
            // Additional offset if source strategy overlay exists
            if node.sourceStrategy != nil {
                inertiaOffset = nodeRadius * 2 + 10
            }
            svg += "<line class=\"wardley-inertia\" x1=\"\(Int(node.x + inertiaOffset))\" y1=\"\(Int(node.y - 8))\" x2=\"\(Int(node.x + inertiaOffset))\" y2=\"\(Int(node.y + 8))\" />\n"
        }

        // Node label
        let labelOffsetX = node.labelOffsetX ?? config.nodeLabelOffset
        let labelOffsetY = node.labelOffsetY ?? 0

        if node.className == .anchor {
            svg += "<text class=\"wardley-node-label\" x=\"\(Int(node.x))\" y=\"\(Int(node.y - nodeRadius - 3))\" text-anchor=\"middle\" font-weight=\"bold\">\(escapingXml(node.label))</text>\n"
        } else {
            svg += "<text class=\"wardley-node-label\" x=\"\(Int(node.x + labelOffsetX))\" y=\"\(Int(node.y + labelOffsetY + 4))\" text-anchor=\"start\">\(escapingXml(node.label))</text>\n"
        }

        svg += "</g>\n"
    }
    svg += "</g>\n"

    // Annotations group
    if !diagram.annotationPoints.isEmpty || diagram.annotationBox != nil {
        svg += "<g class=\"wardley-annotations\">\n"
        for point in diagram.annotationPoints {
            for line in point.connectingLines {
                svg += "<line class=\"wardley-annotation-line\" x1=\"\(Int(line.x1))\" y1=\"\(Int(line.y1))\" x2=\"\(Int(line.x2))\" y2=\"\(Int(line.y2))\" />\n"
            }
            svg += "<circle class=\"wardley-annotation\" cx=\"\(Int(point.x))\" cy=\"\(Int(point.y))\" r=\"10\" />\n"
            svg += "<text class=\"wardley-annotation-text\" x=\"\(Int(point.x))\" y=\"\(Int(point.y))\">\(point.number)</text>\n"
        }

        if let box = diagram.annotationBox {
            svg += "<rect class=\"wardley-annotations-box\" x=\"\(Int(box.x))\" y=\"\(Int(box.y))\" width=\"\(Int(box.width))\" height=\"\(Int(box.height))\" rx=\"4\" ry=\"4\" />\n"
            for entry in box.entries {
                svg += "<text class=\"wardley-annotations-box-text\" x=\"\(Int(entry.x))\" y=\"\(Int(entry.y))\">\(escapingXml(entry.text))</text>\n"
            }
        }
        svg += "</g>\n"
    }

    // Notes group
    if !diagram.notes.isEmpty {
        svg += "<g class=\"wardley-notes\">\n"
        for note in diagram.notes {
            svg += "<text class=\"wardley-notes\" x=\"\(Int(note.x))\" y=\"\(Int(note.y))\">\(escapingXml(note.text))</text>\n"
        }
        svg += "</g>\n"
    }

    // Accelerators group
    if !diagram.accelerators.isEmpty {
        svg += "<g class=\"wardley-accelerators\">\n"
        for acc in diagram.accelerators {
            let aw: Double = 60
            let ah: Double = 30
            let ahw: Double = 20
            let ax = acc.x - aw / 2
            let ay = acc.y - ah / 2
            // Right-pointing arrow: shaft + arrowhead
            svg += "<path class=\"wardley-accelerators\" d=\"M \(Int(ax)) \(Int(ay)) L \(Int(ax + aw - ahw)) \(Int(ay)) L \(Int(ax + aw - ahw)) \(Int(ay - ah / 2)) L \(Int(ax + aw)) \(Int(acc.y)) L \(Int(ax + aw - ahw)) \(Int(ay + ah + ah / 2)) L \(Int(ax + aw - ahw)) \(Int(ay + ah)) L \(Int(ax)) \(Int(ay + ah)) Z\" />\n"
            svg += "<text class=\"wardley-accelerator-label\" x=\"\(Int(acc.x))\" y=\"\(Int(acc.y + ah + 12))\">\(escapingXml(acc.name))</text>\n"
        }
        svg += "</g>\n"
    }

    // Deaccelerators group
    if !diagram.deaccelerators.isEmpty {
        svg += "<g class=\"wardley-deaccelerators\">\n"
        for dec in diagram.deaccelerators {
            let dw: Double = 60
            let dh: Double = 30
            let dhw: Double = 20
            let dx = dec.x - dw / 2
            let dy = dec.y - dh / 2
            // Left-pointing arrow: shaft + arrowhead
            svg += "<path class=\"wardley-deaccelerators\" d=\"M \(Int(dx + dw)) \(Int(dy)) L \(Int(dx + dhw)) \(Int(dy)) L \(Int(dx + dhw)) \(Int(dy - dh / 2)) L \(Int(dx)) \(Int(dec.y)) L \(Int(dx + dhw)) \(Int(dy + dh + dh / 2)) L \(Int(dx + dhw)) \(Int(dy + dh)) L \(Int(dx + dw)) \(Int(dy + dh)) Z\" />\n"
            svg += "<text class=\"wardley-deaccelerator-label\" x=\"\(Int(dec.x))\" y=\"\(Int(dec.y + dh + 12))\">\(escapingXml(dec.name))</text>\n"
        }
        svg += "</g>\n"
    }

    svg += builder.close()
    return svg
}

private func escapingXml(_ text: String) -> String {
    SVG.escapeText(text)
}
