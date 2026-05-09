import Foundation

func renderVennSvg(
    _ positioned: PositionedVennDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) -> String {
    var svg = ""
    let isHandDrawn = positioned.isHandDrawn

    svg += "<svg id=\"\(diagramId)\" viewBox=\"0 0 \(Int(positioned.width)) \(Int(positioned.height))\" xmlns=\"http://www.w3.org/2000/svg\">\n"

    if let accTitle = positioned.accTitle {
        svg += "<title>\(_escapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr {
        svg += "<desc>\(_escapeXml(accDescr))</desc>\n"
    }

    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(colors.bg)\" />\n"
    }

    let titleColor = positioned.themeVariables?["vennTitleTextColor"] ?? colors.fg

    if let title = positioned.title {
        svg += "<text class=\"venn-title\" x=\"50%\" y=\"\(Int(title.y))\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\" font-size=\"\(Int(title.fontSize))px\" fill=\"\(titleColor)\">\(_escapeXml(title.text))</text>\n"
    }

    svg += "<g transform=\"translate(0, \(Int(positioned.titleHeight)))\">\n"

    for area in positioned.areas {
        svg += renderVennAreaSvg(area, font: font, isHandDrawn: isHandDrawn, handDrawnSeed: positioned.handDrawnSeed)
    }

    if !positioned.textNodes.isEmpty {
        svg += "<g class=\"venn-text-nodes\">\n"
        for node in positioned.textNodes {
            svg += renderVennTextNodeSvg(node, font: font, scale: positioned.scale, debugLayout: positioned.useDebugLayout)
        }
        svg += "</g>\n"
    }

    svg += "</g>\n"

    if positioned.config.useMaxWidth {
        svg += "<style>#\(diagramId) { max-width: 100%; }</style>\n"
    }

    svg += "</svg>"

    return svg
}

private func renderVennAreaSvg(_ area: PositionedVennArea, font: String, isHandDrawn: Bool, handDrawnSeed: Int) -> String {
    if area.isSingleSet {
        return renderVennCircleSvg(area, font: font, isHandDrawn: isHandDrawn, handDrawnSeed: handDrawnSeed)
    } else {
        return renderVennIntersectionSvg(area, font: font, isHandDrawn: isHandDrawn, handDrawnSeed: handDrawnSeed)
    }
}

private func renderVennCircleSvg(_ area: PositionedVennArea, font: String, isHandDrawn: Bool, handDrawnSeed: Int) -> String {
    var result = ""
    let fmt: (Double) -> String = { String(format: "%.2f", $0) }

    for (i, circle) in area.circles.enumerated() {
        result += "<g class=\"venn-circle \(area.colorClass)\">\n"

        let fillOpacity = area.fillOpacity
        let strokeOpacity = 0.95

        if area.debugFlags {
            result += "<circle cx=\"\(fmt(circle.center.x))\" cy=\"\(fmt(circle.center.y))\" r=\"\(fmt(circle.radius))\" fill=\"none\" stroke=\"purple\" stroke-width=\"1\" stroke-dasharray=\"4 2\" />\n"
        }

        if isHandDrawn {
            let seed = handDrawnSeed + i * 137
            let sketchPath = handDrawnCirclePath(cx: circle.center.x, cy: circle.center.y, r: circle.radius, seed: seed, segments: 36)
            result += "<path d=\"\(sketchPath)\" fill=\"\(area.fillColor)\" fill-opacity=\"\(String(format: "%.3f", fillOpacity))\" stroke=\"\(area.strokeColor)\" stroke-width=\"\(fmt(area.strokeWidth))\" stroke-opacity=\"\(String(format: "%.3f", strokeOpacity))\" />\n"

            // Hachure fill lines
            let hachureAngle = -41.0 + Double(i) * 60.0
            let hachureLines = handDrawnHachureLines(cx: circle.center.x, cy: circle.center.y, r: circle.radius, seed: seed, angle: hachureAngle, gap: 8, strokeColor: area.fillColor)
            for line in hachureLines {
                result += "<line x1=\"\(fmt(line.x1))\" y1=\"\(fmt(line.y1))\" x2=\"\(fmt(line.x2))\" y2=\"\(fmt(line.y2))\" stroke=\"\(area.fillColor)\" stroke-width=\"1.5\" stroke-opacity=\"0.4\" />\n"
            }
        } else {
            result += "<circle cx=\"\(fmt(circle.center.x))\" cy=\"\(fmt(circle.center.y))\" r=\"\(fmt(circle.radius))\" fill=\"\(area.fillColor)\" fill-opacity=\"\(String(format: "%.3f", fillOpacity))\" stroke=\"\(area.strokeColor)\" stroke-width=\"\(fmt(area.strokeWidth))\" stroke-opacity=\"\(String(format: "%.3f", strokeOpacity))\" />\n"
        }

        let labelText = area.label ?? area.sets.first ?? ""
        if !labelText.isEmpty {
            result += "<text x=\"\(fmt(circle.center.x))\" y=\"\(fmt(circle.center.y))\" font-size=\"\(Int(area.textFontSize))px\" fill=\"\(area.textColor)\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\">\(_escapeXml(labelText))</text>\n"
        }

        result += "</g>\n"
    }

    return result
}

private func renderVennIntersectionSvg(_ area: PositionedVennArea, font: String, isHandDrawn: Bool, handDrawnSeed: Int) -> String {
    var result = ""
    let fmt: (Double) -> String = { String(format: "%.2f", $0) }

    result += "<g class=\"venn-intersection\">\n"

    if let pathSpec = area.pathSpec {
        let fill = area.fillColor
        let fillOpacity = area.fillOpacity

        if isHandDrawn && fillOpacity > 0 && fill != "transparent" {
            // Cross-hatch fill via two sets of hachure lines
            let lines1 = handDrawnHachureForPath(pathSpec, angle: 45, gap: 6, seed: handDrawnSeed, strokeColor: fill)
            let lines2 = handDrawnHachureForPath(pathSpec, angle: -45, gap: 6, seed: handDrawnSeed + 100, strokeColor: fill)
            for line in lines1 {
                result += "<line x1=\"\(fmt(line.x1))\" y1=\"\(fmt(line.y1))\" x2=\"\(fmt(line.x2))\" y2=\"\(fmt(line.y2))\" stroke=\"\(fill)\" stroke-width=\"1.5\" stroke-opacity=\"0.6\" />\n"
            }
            for line in lines2 {
                result += "<line x1=\"\(fmt(line.x1))\" y1=\"\(fmt(line.y1))\" x2=\"\(fmt(line.x2))\" y2=\"\(fmt(line.y2))\" stroke=\"\(fill)\" stroke-width=\"1.5\" stroke-opacity=\"0.4\" />\n"
            }
        } else {
            result += "<path d=\"\(pathSpec)\" fill=\"\(fill)\" fill-opacity=\"\(String(format: "%.3f", fillOpacity))\" stroke=\"\(area.strokeColor)\" stroke-width=\"\(fmt(area.strokeWidth))\" />\n"
        }
    }

    let labelText = area.label ?? area.sets.joined(separator: " & ")
    if !labelText.isEmpty {
        result += "<text x=\"\(fmt(area.textPoint.x))\" y=\"\(fmt(area.textPoint.y))\" font-size=\"\(Int(area.textFontSize))px\" fill=\"\(area.textColor)\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\(font)\">\(_escapeXml(labelText))</text>\n"
    }

    result += "</g>\n"

    return result
}

private func renderVennTextNodeSvg(_ node: PositionedVennTextNode, font: String, scale: Double, debugLayout: Bool) -> String {
    var result = ""
    let fmt: (Double) -> String = { String(format: "%.2f", $0) }

    result += "<g class=\"venn-text-area\">\n"

    let displayText = node.label ?? node.id
    let fontSize = Int(node.fontSize)

    result += "<foreignObject class=\"venn-text-node-fo\" width=\"\(fmt(node.width))\" height=\"\(fmt(node.height))\" x=\"\(fmt(node.x))\" y=\"\(fmt(node.y))\" overflow=\"visible\">\n"
    result += "<span xmlns=\"http://www.w3.org/1999/xhtml\" class=\"venn-text-node\" style=\"display:flex;width:100%;height:100%;align-items:center;justify-content:center;text-align:center;color:\(node.textColor);font-family:\(font);font-size:\(fontSize)px;word-wrap:break-word;overflow-wrap:break-word;\">\(_escapeXml(displayText))</span>\n"
    result += "</foreignObject>\n"

    if debugLayout {
        result += "<circle class=\"venn-text-debug-circle\" cx=\"\(fmt(node.x + node.width / 2))\" cy=\"\(fmt(node.y + node.height / 2))\" r=\"5\" fill=\"none\" stroke=\"purple\" stroke-width=\"1\" stroke-dasharray=\"3 2\" />\n"
        result += "<rect class=\"venn-text-debug-cell\" x=\"\(fmt(node.x))\" y=\"\(fmt(node.y))\" width=\"\(fmt(node.width))\" height=\"\(fmt(node.height))\" fill=\"none\" stroke=\"teal\" stroke-width=\"1\" stroke-dasharray=\"3 2\" />\n"
    }

    result += "</g>\n"

    return result
}

// MARK: - Hand-Drawn Path Generation

private func prng(_ seed: Int) -> Double {
    var s = UInt64(bitPattern: Int64(seed))
    s ^= s >> 12
    s ^= s << 25
    s ^= s >> 27
    return Double((s &* 2685821657736338717) & 0x7FFFFFFF) / Double(0x7FFFFFFF)
}

private func handDrawnCirclePath(cx: Double, cy: Double, r: Double, seed: Int, segments: Int) -> String {
    var s = seed
    func nextJitter() -> Double {
        s += 1
        return (prng(s) - 0.5) * r * 0.06
    }

    let fmt: (Double) -> String = { String(format: "%.3f", $0) }
    var commands: [String] = []
    for i in 0..<segments {
        let angle = 2.0 * .pi * Double(i) / Double(segments)
        let jx = cos(angle) * (r + nextJitter())
        let jy = sin(angle) * (r + nextJitter())
        if i == 0 {
            commands.append("M \(fmt(cx + jx)) \(fmt(cy + jy))")
        } else {
            commands.append("L \(fmt(cx + jx)) \(fmt(cy + jy))")
        }
    }
    commands.append("Z")
    return commands.joined(separator: " ")
}

private struct LineSegment {
    let x1: Double
    let y1: Double
    let x2: Double
    let y2: Double
}

private func handDrawnHachureLines(cx: Double, cy: Double, r: Double, seed: Int, angle: Double, gap: Double, strokeColor: String) -> [LineSegment] {
    let rad = angle * .pi / 180.0
    let cosA = cos(rad)
    let sinA = sin(rad)
    let spacing = max(gap, 2)

    var lines: [LineSegment] = []
    // Offset by seed
    var s = seed

    // Bounding square for the circle
    let step = spacing
    for offset in stride(from: -r * 1.5, through: r * 1.5, by: step) {
        s += 1
        let jitter = (prng(s) - 0.5) * spacing * 0.3

        // Line perpendicular to hachure direction, offset by `offset`
        let px = cx - r * 1.5 * cosA + (offset + jitter) * cosA
        let py = cy - r * 1.5 * sinA + (offset + jitter) * sinA

        // Intersect line from (px, py) along (sinA, -cosA) with the circle
        // Parametric: (px + t*sinA, py - t*cosA)
        // Distance from center: solve for t where point is on circle
        // |(px-cx) + t*sinA|^2 + |(py-cy) - t*cosA|^2 = r^2
        let dx0 = px - cx
        let dy0 = py - cy

        let a = sinA * sinA + cosA * cosA  // = 1
        let b = 2 * (dx0 * sinA - dy0 * cosA)
        let c = dx0 * dx0 + dy0 * dy0 - r * r

        let discriminant = b * b - 4 * a * c
        if discriminant <= 0 { continue }

        let sqrtD = sqrt(discriminant)
        let t1 = (-b - sqrtD) / (2 * a)
        let t2 = (-b + sqrtD) / (2 * a)

        let x1 = px + t1 * sinA
        let y1 = py - t1 * cosA
        let x2 = px + t2 * sinA
        let y2 = py - t2 * cosA

        // Jitter endpoints
        s += 1
        let jx1 = x1 + (prng(s) - 0.5) * 1.5
        let jy1 = y1 + (prng(s) - 0.5) * 1.5
        s += 1
        let jx2 = x2 + (prng(s) - 0.5) * 1.5
        let jy2 = y2 + (prng(s) - 0.5) * 1.5

        lines.append(LineSegment(x1: jx1, y1: jy1, x2: jx2, y2: jy2))
    }
    return lines
}

private func handDrawnHachureForPath(_ pathSpec: String, angle: Double, gap: Double, seed: Int, strokeColor: String) -> [LineSegment] {
    // Parse the path to get bounding box and centroid
    let tokens = pathSpec.split(separator: " ")
    var minX = Double.infinity, maxX = -Double.infinity
    var minY = Double.infinity, maxY = -Double.infinity

    for token in tokens {
        let t = String(token)
        if Double(t) != nil {
            // Collect alternating x,y values
            continue
        }
    }

    // Simple approach: extract numeric values and compute bounds
    var coords: [Double] = []
    for token in tokens {
        let t = String(token)
        if let v = Double(t) {
            coords.append(v)
        }
    }

    for i in stride(from: 0, to: coords.count - 1, by: 2) {
        let x = coords[i]
        let y = coords[i + 1]
        minX = min(minX, x)
        maxX = max(maxX, x)
        minY = min(minY, y)
        maxY = max(maxY, y)
    }

    guard minX.isFinite && maxX.isFinite else { return [] }

    let cx = (minX + maxX) / 2
    let cy = (minY + maxY) / 2
    let r = max(maxX - minX, maxY - minY) / 2

    return handDrawnHachureLines(cx: cx, cy: cy, r: r * 0.9, seed: seed, angle: angle, gap: gap, strokeColor: strokeColor)
}

private func _escapeXml(_ s: String) -> String {
    SVG.escapeText(s)
}
