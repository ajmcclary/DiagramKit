import Foundation

public func renderArchitectureSvg(
    _ positioned: PositionedArchitectureDiagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    let bgColor = colors.bg
    let fgColor = colors.fg
    let theme = positioned.theme
    let defaultTheme = ArchitectureThemeConfig.default
    let edgeColor = theme?.archEdgeColor ?? colors.line ?? defaultTheme.archEdgeColor
    let arrowColor = theme?.archEdgeArrowColor ?? colors.line ?? defaultTheme.archEdgeArrowColor
    let edgeWidth = theme?.archEdgeWidth ?? defaultTheme.archEdgeWidth
    let groupBorderColor = theme?.archGroupBorderColor ?? defaultTheme.archGroupBorderColor
    let groupBorderWidth = theme?.archGroupBorderWidth ?? defaultTheme.archGroupBorderWidth
    let fontSize = positioned.config.fontSize
    let iconSize = positioned.config.iconSize
    let arrowSize = iconSize / 6

    let w = Int(ceil(positioned.width))
    let h = Int(ceil(positioned.height))

    var svg = ""
    svg += "<svg id=\"\(SVG.escapeAttribute(diagramId))\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\""
    if positioned.config.useMaxWidth {
        svg += " width=\"100%\" style=\"max-width: \(w)px;\" viewBox=\"0 0 \(w) \(h)\""
    } else {
        svg += " width=\"\(w)\" height=\"\(h)\" viewBox=\"0 0 \(w) \(h)\""
    }
    svg += ">\n"

    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "<title>\(_escapeXml(accTitle))</title>\n"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "<desc>\(_escapeXml(accDescr))</desc>\n"
    }

    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(bgColor)\"/>\n"
    }

    svg += "<style>\n"
    svg += ".edge { stroke-width: \(edgeWidth); stroke: \(edgeColor); fill: none; }\n"
    svg += ".arrow { fill: \(arrowColor); }\n"
    svg += ".node-bkg { fill: none; stroke: \(groupBorderColor); stroke-width: \(groupBorderWidth); stroke-dasharray: 8; }\n"
    svg += ".arch-service-label { font-family: \(font); font-size: \(Int(fontSize))px; fill: \(fgColor); text-anchor: middle; }\n"
    svg += ".arch-group-label { font-family: \(font); font-size: \(Int(fontSize))px; fill: \(fgColor); }\n"
    svg += ".arch-edge-label { font-family: \(font); font-size: \(Int(fontSize))px; fill: \(fgColor); text-anchor: middle; }\n"
    svg += "</style>\n"

    svg += "<g class=\"architecture-groups\">\n"
    for group in positioned.groups {
        svg += "<g id=\"\(SVG.escapeAttribute(diagramId))-group-\(SVG.escapeAttribute(group.id))\" class=\"node-bkg\">\n"
        svg += "<rect x=\"\(_fmt(group.x))\" y=\"\(_fmt(group.y))\" width=\"\(_fmt(group.width))\" height=\"\(_fmt(group.height))\" class=\"node-bkg\"/>\n"
        var groupLabelX = group.x + 4
        if let icon = group.icon, !icon.isEmpty {
            let groupIconSize = positioned.config.padding * 0.75
            svg += "<g class=\"arch-group-icon\" style=\"color: \(fgColor)\">\n"
            svg += _iconSvg(
                for: icon,
                iconText: nil,
                cx: group.x + groupIconSize / 2 + 1,
                cy: group.y + groupIconSize / 2 + 1,
                size: groupIconSize,
                iconSize: iconSize
            )
            svg += "</g>\n"
            groupLabelX += groupIconSize
        }
        if let title = group.title, !title.isEmpty {
            svg += "<text x=\"\(_fmt(groupLabelX))\" y=\"\(_fmt(group.y + fontSize))\" class=\"arch-group-label\">\(_escapeXml(title))</text>\n"
        }
        svg += "</g>\n"
    }
    svg += "</g>\n"

    svg += "<g class=\"architecture-edges\">\n"
    for edge in positioned.edges {
        let d = "M \(_fmt(edge.startX)),\(_fmt(edge.startY)) L \(_fmt(edge.midX)),\(_fmt(edge.midY)) L \(_fmt(edge.endX)),\(_fmt(edge.endY))"
        svg += "<path id=\"\(SVG.escapeAttribute(diagramId))-\(SVG.escapeAttribute(edge.id))\" class=\"edge\" d=\"\(d)\"/>\n"

        if edge.sourceArrow {
            let (polygonPoints, xShift, yShift) = _directionArrowTransform(
                direction: edge.lhsDirection,
                anchorX: edge.startX,
                anchorY: edge.startY,
                arrowSize: arrowSize,
                midpointX: edge.midX,
                midpointY: edge.midY
            )
            svg += "<polygon class=\"arrow\" points=\"\(polygonPoints)\" transform=\"translate(\(_fmt(xShift)),\(_fmt(yShift)))\"/>\n"
        }
        if edge.targetArrow {
            let (polygonPoints, xShift, yShift) = _directionArrowTransform(
                direction: edge.rhsDirection,
                anchorX: edge.endX,
                anchorY: edge.endY,
                arrowSize: arrowSize,
                midpointX: edge.midX,
                midpointY: edge.midY
            )
            svg += "<polygon class=\"arrow\" points=\"\(polygonPoints)\" transform=\"translate(\(_fmt(xShift)),\(_fmt(yShift)))\"/>\n"
        }

        if let label = edge.label, !label.isEmpty {
            let isXY = _isXY(lhsDir: edge.lhsDirection, rhsDir: edge.rhsDirection)
            if isXY {
                let (rotation, rotOriginX, rotOriginY) = _xyLabelRotation(
                    lhsDir: edge.lhsDirection,
                    rhsDir: edge.rhsDirection,
                    midX: edge.midX,
                    midY: edge.midY
                )
                svg += "<text x=\"\(_fmt(edge.midX))\" y=\"\(_fmt(edge.midY - 4))\" class=\"arch-edge-label\" transform=\"rotate(\(_fmt(rotation)),\(_fmt(rotOriginX)),\(_fmt(rotOriginY)))\">\(_escapeXml(label))</text>\n"
            } else {
                let isVertical = (edge.lhsDirection == .T || edge.lhsDirection == .B) && (edge.rhsDirection == .T || edge.rhsDirection == .B)
                if isVertical {
                    svg += "<text x=\"\(_fmt(edge.midX))\" y=\"\(_fmt(edge.midY - 4))\" class=\"arch-edge-label\" transform=\"rotate(-90,\(_fmt(edge.midX)),\(_fmt(edge.midY)))\">\(_escapeXml(label))</text>\n"
                } else {
                    svg += "<text x=\"\(_fmt(edge.midX))\" y=\"\(_fmt(edge.midY - 4))\" class=\"arch-edge-label\">\(_escapeXml(label))</text>\n"
                }
            }
        }
    }
    svg += "</g>\n"

    svg += "<g class=\"architecture-services\">\n"
    for service in positioned.services {
        let serviceId = "\(diagramId)-service-\(service.id)"
        let nodeId = "\(diagramId)-node-\(service.id)"
        svg += "<g id=\"\(SVG.escapeAttribute(serviceId))\" class=\"architecture-service\">\n"
        svg += "<g id=\"\(SVG.escapeAttribute(nodeId))\" style=\"color: \(fgColor)\">\n"
        svg += "<rect x=\"\(_fmt(service.x - service.width / 2))\" y=\"\(_fmt(service.y - service.height / 2))\" width=\"\(_fmt(service.width))\" height=\"\(_fmt(service.height))\" fill=\"none\" stroke=\"\(fgColor)\" stroke-width=\"1\"/>\n"
        svg += _iconSvg(for: service.icon, iconText: service.iconText, cx: service.x, cy: service.y, size: positioned.config.iconSize, iconSize: iconSize)
        svg += "</g>\n"
        if let title = service.title, !title.isEmpty {
            svg += "<text x=\"\(_fmt(service.x))\" y=\"\(_fmt(service.y + service.height / 2 + fontSize + 4))\" class=\"arch-service-label\">\(_escapeXml(title))</text>\n"
        }
        svg += "</g>\n"
    }
    for junction in positioned.junctions {
        let nodeId = "\(diagramId)-node-\(junction.id)"
        svg += "<g id=\"\(SVG.escapeAttribute(nodeId))\" class=\"architecture-junction\">\n"
        let jw = junction.width > 0 ? junction.width : positioned.config.iconSize
        let jh = junction.height > 0 ? junction.height : positioned.config.iconSize
        svg += "<rect x=\"\(_fmt(junction.x - jw / 2))\" y=\"\(_fmt(junction.y - jh / 2))\" width=\"\(_fmt(jw))\" height=\"\(_fmt(jh))\" fill-opacity=\"0\"/>\n"
        svg += "</g>\n"
    }
    svg += "</g>\n"

    svg += "</svg>\n"
    return svg
}

private func _iconSvg(for iconName: String?, iconText: String?, cx: Double, cy: Double, size: Double, iconSize: Double) -> String {
    let iconDisplaySize = size * 0.6
    let halfIcon = iconDisplaySize / 2
    let x = cx - halfIcon
    let y = cy - halfIcon

    if let iconText = iconText, !iconText.isEmpty {
        return "<text x=\"\(_fmt(cx))\" y=\"\(_fmt(cy + 4))\" font-size=\"\(Int(size * 0.3))\" text-anchor=\"middle\" fill=\"currentColor\">\(_escapeXml(iconText))</text>\n"
    }

    if let iconName = iconName?.trimmingCharacters(in: .whitespaces), !iconName.isEmpty {
        let registry = ArchitectureIconRegistry.shared

        if registry.hasBuiltInIcon(iconName) {
            if let body = registry.builtInBody(for: iconName) {
                return _renderExternalIconBody(body, iconDisplaySize: iconDisplaySize, x: x, y: y)
            }
            let path = _builtinIconPath(for: iconName)
            if let path = path {
                return "<path d=\"\(path)\" transform=\"translate(\(_fmt(x)),\(_fmt(y))) scale(\(_fmt(iconDisplaySize / 48)))\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>\n"
            }
        }

        if registry.isExternalIcon(iconName) {
            if let externalSVG = registry.iconSVG(for: iconName) {
                return _renderExternalIconBody(externalSVG, iconDisplaySize: iconDisplaySize, x: x, y: y)
            }
        }

        let path = _builtinIconPath(for: iconName) ?? _unknownPath
        return "<path d=\"\(path)\" transform=\"translate(\(_fmt(x)),\(_fmt(y))) scale(\(_fmt(iconDisplaySize / 48)))\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"/>\n"
    }

    return ""
}

private func _renderExternalIconBody(_ body: String, iconDisplaySize: Double, x: Double, y: Double) -> String {
    return "<g transform=\"translate(\(_fmt(x)),\(_fmt(y))) scale(\(_fmt(iconDisplaySize / 80)))\">\(body)</g>\n"
}

private func _builtinIconPath(for iconName: String?) -> String? {
    guard let iconName = iconName?.lowercased().trimmingCharacters(in: .whitespaces) else { return nil }
    switch iconName {
    case "cloud":
        return _cloudPath
    case "database":
        return _databasePath
    case "disk":
        return _diskPath
    case "internet":
        return _internetPath
    case "server":
        return _serverPath
    default:
        return _unknownPath
    }
}

private func _directionArrowPolygon(direction: ArchitectureDirection, arrowSize: Double) -> String {
    let s = arrowSize
    switch direction {
    case .L:
        return "\(_fmt(s)),\(_fmt(s / 2)) \(_fmt(0)),\(_fmt(s)) \(_fmt(0)),\(_fmt(0))"
    case .R:
        return "\(_fmt(0)),\(_fmt(s / 2)) \(_fmt(s)),\(_fmt(0)) \(_fmt(s)),\(_fmt(s))"
    case .T:
        return "\(_fmt(0)),\(_fmt(0)) \(_fmt(s)),\(_fmt(0)) \(_fmt(s / 2)),\(_fmt(s))"
    case .B:
        return "\(_fmt(s / 2)),\(_fmt(0)) \(_fmt(s)),\(_fmt(s)) \(_fmt(0)),\(_fmt(s))"
    }
}

private func _directionArrowShift(direction: ArchitectureDirection, coord: Double, arrowSize: Double) -> Double {
    switch direction {
    case .L, .T:
        return coord - arrowSize + 2
    case .R, .B:
        return coord - 2
    }
}

private func _directionArrowTransform(
    direction: ArchitectureDirection,
    anchorX: Double,
    anchorY: Double,
    arrowSize: Double,
    midpointX: Double,
    midpointY: Double
) -> (polygonPoints: String, xShift: Double, yShift: Double) {
    let halfArrowSize = arrowSize / 2
    let xIsDir: Bool
    switch direction {
    case .L, .R: xIsDir = true
    case .T, .B: xIsDir = false
    }

    let xShift: Double
    let yShift: Double
    if xIsDir {
        xShift = _directionArrowShift(direction: direction, coord: anchorX, arrowSize: arrowSize)
        yShift = anchorY - halfArrowSize
    } else {
        xShift = anchorX - halfArrowSize
        yShift = _directionArrowShift(direction: direction, coord: anchorY, arrowSize: arrowSize)
    }

    let polygonPoints = _directionArrowPolygon(direction: direction, arrowSize: arrowSize)
    return (polygonPoints, xShift, yShift)
}

private func _xyLabelRotation(
    lhsDir: ArchitectureDirection,
    rhsDir: ArchitectureDirection,
    midX: Double,
    midY: Double
) -> (rotation: Double, rotOriginX: Double, rotOriginY: Double) {
    let factor = _xyFactor(lhsDir: lhsDir, rhsDir: rhsDir)
    let rotation = -1.0 * factor.0 * factor.1 * 45.0
    return (rotation, midX, midY)
}

private func _xyFactor(lhsDir: ArchitectureDirection, rhsDir: ArchitectureDirection) -> (Double, Double) {
    switch (lhsDir, rhsDir) {
    case (.L, .T), (.T, .L): return (1, 1)
    case (.B, .L), (.L, .B): return (1, -1)
    case (.B, .R), (.R, .B): return (-1, -1)
    case (.T, .R), (.R, .T): return (-1, 1)
    default: return (1, 1)
    }
}

private func _isXY(lhsDir: ArchitectureDirection, rhsDir: ArchitectureDirection) -> Bool {
    let h: Set<ArchitectureDirection> = [.L, .R]
    let v: Set<ArchitectureDirection> = [.T, .B]
    return (h.contains(lhsDir) && v.contains(rhsDir)) || (v.contains(lhsDir) && h.contains(rhsDir))
}

private func _arrowPoints(cx: Double, cy: Double, angle: Double) -> String {
    let size: Double = 8
    let p1x: Double = 0
    let p1y: Double = 0
    let p2x: Double = -size
    let p2y: Double = -size / 2
    let p3x: Double = -size
    let p3y: Double = size / 2
    return "\(_fmt(cx + p1x)),\(_fmt(cy + p1y)) \(_fmt(cx + p2x)),\(_fmt(cy + p2y)) \(_fmt(cx + p3x)),\(_fmt(cy + p3y))"
}

private func _fmt(_ d: Double) -> String {
    let r = round(d * 10) / 10
    return (r == floor(r)) ? String(Int(r)) : String(r)
}

private func _escapeXml(_ text: String) -> String {
    SVG.escapeText(text)
}

private let _cloudPath = "M24 12c0-4.4-3.6-8-8-8-3 0-5.6 1.7-7 4.2C7 7.5 5.3 7 3.6 7.6 1.3 8.5 0 10.9 0 13.5 0 17.1 2.9 20 6.5 20H30c3.3 0 6-2.7 6-6 0-3.3-2.7-6-6-6h-.5c-.5-2.4-2.6-4-4.9-4-1.5 0-2.8.6-3.7 1.7C20.3 12.3 20 12 20 12h-4z"
private let _databasePath = "M24 8c0-2.2-5.4-4-12-4S0 5.8 0 8v8c0 2.2 5.4 4 12 4s12-1.8 12-4V8zm0 0c0 2.2-5.4 4-12 4S0 10.2 0 8m24 12c0 2.2-5.4 4-12 4S0 22.2 0 20m24-6c0 2.2-5.4 4-12 4S0 16.2 0 14"
private let _diskPath = "M24 4H8c-2.2 0-4 1.8-4 4v16c0 2.2 1.8 4 4 4h16c2.2 0 4-1.8 4-4V8c0-2.2-1.8-4-4-4zm0 18H8V6h16v16zM16 12c-2.2 0-4 1.8-4 4s1.8 4 4 4 4-1.8 4-4-1.8-4-4-4zm0 6c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2z"
private let _internetPath = "M24 4C13 4 4 13 4 24s9 20 20 20 20-9 20-20S35 4 24 4zm0 3.6c2.1 0 4 .4 5.8 1.1v4.1c-1.1-.4-2.3-.6-3.5-.7-1.3-.1-2.7-.1-4 0 .2-1.7.5-3.3 1-4.7h.7zM13.2 8.7c1.8-.7 3.7-1.1 5.8-1.1v4.7c-.5.8-.9 1.7-1.2 2.6H15c-1.1 0-2.2.2-3.3.5-.3-1.2-.5-2.4-.5-3.7 0-1.1.2-2.1.5-3zm-6.6 2.1c1.3-1.1 2.7-2 4.3-2.6.4 1 .6 2.1.8 3.2-1.7.5-3.3 1.2-4.8 2.2-.5-1.3-.7-2.6-.3-2.8zM8 21.7c1.5-.9 3.1-1.7 4.8-2.2.2 1.2.4 2.2.8 3.3-1.6.6-3 1.5-4.3 2.6.2-1.2.7-2.5 1.3-3.7zm-1-.7c-1.2.8-2.2 1.8-3.1 2.9-.7-1.2-1.1-2.5-1.2-3.9.7 0 1.5-.2 2.3-.4zm-2.4 4.6c.9-1.2 1.9-2.2 3.1-3 .2 1.1.4 2.3.4 3.5 0 .8-.1 1.7-.2 2.5-1.4-.6-2.6-1.5-3.6-2.7zM21.2 37c-1.8-.7-3.7-1.1-5.8-1.1.2-1.7.5-3.3 1-4.7h.7c-.2 1.3-.4 2.6-.4 4 0 1.4.1 2.7.4 3.9h-1c-.5-1.3-.9-2.6-1.2-4-1.1-.1-2.2-.2-3.3-.5h.3c1.6 0 3.2-.2 4.7-.5.2-1.3.5-2.5 1-3.7"
private let _serverPath = "M4 4h40v12H4V4zm4 4h4V6H8v2zm8 0h4V6h-4v2zm-8 8h32V6H8v10zm-4 0h40v12H4V16zm4 4h4v-2H8v2zm8 0h4v-2h-4v2zm-8 8h32V18H8v10zm-4 4h40v12H4V32zm4 4h4v-2H8v2zm8 0h4v-2h-4v2z"
private let _unknownPath = "M24 4C13 4 4 13 4 24s9 20 20 20 20-9 20-20S35 4 24 4zm2 30h-4v-4h4v4zm-4-8v-2c3.3 0 6-2.7 6-6s-2.7-6-6-6c-2.3 0-4.3 1.3-5.3 3.2l-3.4-2c1.6-3.1 4.9-5.2 8.7-5.2 5.5 0 10 4.5 10 10s-4.5 10-10 10v-2z"
