import Foundation

// MARK: - C4 SVG Renderer

/// Render a positioned C4 diagram to SVG string.
/// - Parameters:
///   - diagram: The positioned C4 diagram
///   - diagramId: Unique ID for scoping markers and defs
///   - colors: Diagram color palette
///   - font: Font family string
///   - transparent: Whether background is transparent
/// - Returns: SVG string
public func renderC4Svg(
    _ diagram: PositionedC4Diagram,
    diagramId: String,
    _ colors: DiagramColors,
    _ font: String,
    _ transparent: Bool
) throws -> String {
    var svg = ""

    let extraVertForTitle = (diagram.title != nil) ? 60.0 : 0.0
    let viewBoxX = -diagram.width * 0.1
    let viewBoxY = -(diagram.width * 0.05 + extraVertForTitle)
    let viewBoxW = diagram.width * 1.2
    let viewBoxH = diagram.height + extraVertForTitle + diagram.width * 0.1

    svg += "<svg id=\"\(xmlEscape(diagramId))\" viewBox=\"\(viewBoxX) \(viewBoxY) \(viewBoxW) \(viewBoxH)\" xmlns=\"http://www.w3.org/2000/svg\">\n"

    if !transparent {
        svg += "<rect width=\"100%\" height=\"100%\" fill=\"\(xmlEscape(colors.bg))\"/>\n"
    }

    // Icon defs
    svg += _c4DatabaseIconDef(diagramId: diagramId)
    svg += _c4ComputerIconDef(diagramId: diagramId)
    svg += _c4ClockIconDef(diagramId: diagramId)

    // Arrow marker defs
    svg += _c4ArrowHeadDef(diagramId: diagramId)
    svg += _c4ArrowEndDef(diagramId: diagramId)
    svg += _c4ArrowCrossHeadDef(diagramId: diagramId)
    svg += _c4ArrowFilledHeadDef(diagramId: diagramId)

    // Boundaries
    for boundary in diagram.boundaries where boundary.alias != "global" {
        svg += _renderC4BoundarySvg(boundary, diagramId: diagramId)
    }

    // Shapes
    for shape in diagram.shapes {
        svg += _renderC4ShapeSvg(shape, diagramId: diagramId)
    }

    // Relationships
    svg += _renderC4RelsSvg(diagram.relationships, diagramId: diagramId)

    // Title
    if let title = diagram.title {
        svg += "<text x=\"\(diagram.width / 2)\" y=\"\(diagram.height + 40)\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"bold\" fill=\"\(xmlEscape(colors.fg))\">\(xmlEscape(title))</text>\n"
    }

    // Accessibility
    if let accDescr = diagram.accDescr {
        svg += "<desc>\(xmlEscape(accDescr))</desc>\n"
    }
    if let accTitle = diagram.accTitle {
        svg += "<title>\(xmlEscape(accTitle))</title>\n"
    }

    svg += "</svg>"
    return svg
}

// MARK: - Shape Rendering

private func _renderC4ShapeSvg(_ shape: PositionedC4Shape, diagramId: String) -> String {
    let fillColor = shape.bgColor ?? "#1168BD"
    let strokeColor = shape.borderColor ?? "#3C7FC0"
    let fontColor = shape.fontColor ?? "#FFFFFF"
    var svg = ""

    svg += "<g class=\"c4-shape\">\n"

    // Draw shape
    switch shape.typeC4Shape {
    case .person, .external_person, .system, .external_system,
         .container, .external_container, .component, .external_component:
        svg += "<rect x=\"\(shape.x)\" y=\"\(shape.y)\" width=\"\(shape.width)\" height=\"\(shape.height)\" rx=\"2.5\" ry=\"2.5\" fill=\"\(xmlEscape(fillColor))\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"0.5\"/>\n"

    case .system_db, .external_system_db, .container_db, .external_container_db,
         .component_db, .external_component_db:
        let half = shape.width / 2
        svg += "<path d=\"M\(shape.x),\(shape.y)c0,-10 \(half),-10 \(half),-10c0,0 \(half),0 \(half),10l0,\(shape.height)c0,10 -\(half),10 -\(half),10c0,0 -\(half),0 -\(half),-10l0,-\(shape.height)\" fill=\"\(xmlEscape(fillColor))\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"0.5\"/>\n"
        svg += "<path d=\"M\(shape.x),\(shape.y)c0,10 \(half),10 \(half),10c0,0 \(half),0 \(half),-10\" fill=\"none\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"0.5\"/>\n"

    case .system_queue, .external_system_queue, .container_queue, .external_container_queue,
         .component_queue, .external_component_queue:
        let half = shape.height / 2
        svg += "<path d=\"M\(shape.x),\(shape.y)l\(shape.width),0c5,0 5,\(half) 5,\(half)c0,0 0,\(half) -5,\(half)l-\(shape.width),0c-5,0 -5,-\(half) -5,-\(half)c0,0 0,-\(half) 5,-\(half)\" fill=\"\(xmlEscape(fillColor))\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"0.5\"/>\n"
        svg += "<path d=\"M\(shape.x + shape.width),\(shape.y)c-5,0 -5,\(half) -5,\(half)c0,\(half) 5,\(half) 5,\(half)\" fill=\"none\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"0.5\"/>\n"
    }

    // Stereotype text
    let stereotypeText = "\u{00AB}\(shape.typeC4Shape.rawValue)\u{00BB}"
    let stereoX = shape.x + shape.width / 2
    let stereoY = shape.y + shape.stereotypeY + 10
    svg += "<text x=\"\(stereoX)\" y=\"\(stereoY)\" text-anchor=\"middle\" font-size=\"12\" font-style=\"italic\" fill=\"\(xmlEscape(fontColor))\">\(xmlEscape(stereotypeText))</text>\n"

    // Person image
    if shape.typeC4Shape == .person || shape.typeC4Shape == .external_person {
        let imgX = shape.x + shape.width / 2 - 24
        let imgY = shape.y + shape.imageY
        svg += "<image x=\"\(imgX)\" y=\"\(imgY)\" width=\"48\" height=\"48\" xlink:href=\"\(_personBase64(for: shape.typeC4Shape))\"/>\n"
    }

    // Label
    let labelX = shape.x + shape.width / 2
    let labelY = shape.y + shape.labelY + shape.labelHeight / 2 + 5
    svg += "<text x=\"\(labelX)\" y=\"\(labelY)\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"bold\" fill=\"\(xmlEscape(fontColor))\">\(xmlEscape(shape.label))</text>\n"

    // Technology
    if let techn = shape.technology, !techn.isEmpty, shape.technHeight > 0 {
        let technX = shape.x + shape.width / 2
        let technY = shape.y + shape.technY + shape.technHeight / 2 + 5
        svg += "<text x=\"\(technX)\" y=\"\(technY)\" text-anchor=\"middle\" font-size=\"14\" font-style=\"italic\" fill=\"\(xmlEscape(fontColor))\">[\(xmlEscape(techn))]</text>\n"
    }

    // Description
    if let descr = shape.description, !descr.isEmpty, shape.descrHeight > 0 {
        let descrX = shape.x + shape.width / 2
        let descrY = shape.y + shape.descrY + shape.descrHeight / 2 + 5
        svg += "<text x=\"\(descrX)\" y=\"\(descrY)\" text-anchor=\"middle\" font-size=\"14\" fill=\"\(xmlEscape(fontColor))\">\(xmlEscape(descr))</text>\n"
    }

    svg += "</g>\n"
    return svg
}

// MARK: - Boundary Rendering

private func _renderC4BoundarySvg(_ boundary: PositionedC4Boundary, diagramId: String) -> String {
    let fillColor = boundary.bgColor ?? "none"
    let strokeColor = boundary.borderColor ?? "#444444"
    let fontColor = boundary.fontColor ?? "#444444"
    var svg = ""

    svg += "<g class=\"c4-boundary\">\n"

    let attrs: String
    if boundary.nodeType != nil {
        attrs = "stroke-width=\"1.0\""
    } else {
        attrs = "stroke-width=\"1.0\" stroke-dasharray=\"7.0,7.0\""
    }

    svg += "<rect x=\"\(boundary.x)\" y=\"\(boundary.y)\" width=\"\(boundary.width)\" height=\"\(boundary.height)\" rx=\"2.5\" ry=\"2.5\" fill=\"\(xmlEscape(fillColor))\" stroke=\"\(xmlEscape(strokeColor))\" \(attrs)/>\n"

    // Label
    let labelX = boundary.x + boundary.width / 2
    let labelY = boundary.y + boundary.labelHeight / 2 + 5
    svg += "<text x=\"\(labelX)\" y=\"\(labelY)\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"bold\" fill=\"\(xmlEscape(fontColor))\">\(xmlEscape(boundary.label))</text>\n"

    // Type
    if let type = boundary.type, !type.isEmpty, boundary.typeHeight > 0 {
        let typeY = labelY + boundary.typeHeight + 5
        svg += "<text x=\"\(labelX)\" y=\"\(typeY)\" text-anchor=\"middle\" font-size=\"14\" fill=\"\(xmlEscape(fontColor))\">[\(xmlEscape(type))]</text>\n"
    }

    // Description
    if let descr = boundary.description, !descr.isEmpty, boundary.descrHeight > 0 {
        let descrY = boundary.y + boundary.labelHeight + boundary.typeHeight + boundary.descrHeight / 2 + 15
        svg += "<text x=\"\(labelX)\" y=\"\(descrY)\" text-anchor=\"middle\" font-size=\"12\" fill=\"\(xmlEscape(fontColor))\">\(xmlEscape(descr))</text>\n"
    }

    svg += "</g>\n"
    return svg
}

// MARK: - Relationship Rendering

private func _renderC4RelsSvg(_ rels: [PositionedC4Relationship], diagramId: String) -> String {
    guard !rels.isEmpty else { return "" }
    var svg = "<g class=\"c4-rels\">\n"

    for (i, rel) in rels.enumerated() {
        let textColor = rel.textColor ?? "#444444"
        let strokeColor = rel.lineColor ?? "#444444"
        let ox = Double(rel.offsetX ?? 0)
        let oy = Double(rel.offsetY ?? 0)

        if i == 0 {
            // First relationship: straight line
            svg += "<line x1=\"\(rel.startPoint.x)\" y1=\"\(rel.startPoint.y)\" x2=\"\(rel.endPoint.x)\" y2=\"\(rel.endPoint.y)\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"1\" fill=\"none\""
            if rel.kind != .rel_b {
                svg += " marker-end=\"url(#\(diagramId)-arrowhead)\""
            }
            if rel.kind == .birel || rel.kind == .rel_b {
                svg += " marker-start=\"url(#\(diagramId)-arrowend)\""
            }
            svg += "/>\n"
        } else {
            // Subsequent relationships: quadratic bezier
            let controlX = rel.startPoint.x + (rel.endPoint.x - rel.startPoint.x) / 2 - (rel.endPoint.x - rel.startPoint.x) / 4
            let controlY = rel.startPoint.y + (rel.endPoint.y - rel.startPoint.y) / 2
            svg += "<path d=\"M\(rel.startPoint.x),\(rel.startPoint.y) Q\(controlX),\(controlY) \(rel.endPoint.x),\(rel.endPoint.y)\" stroke=\"\(xmlEscape(strokeColor))\" stroke-width=\"1\" fill=\"none\""
            if rel.kind != .rel_b {
                svg += " marker-end=\"url(#\(diagramId)-arrowhead)\""
            }
            if rel.kind == .birel || rel.kind == .rel_b {
                svg += " marker-start=\"url(#\(diagramId)-arrowend)\""
            }
            svg += "/>\n"
        }

        // Label
        let lblX = (rel.startPoint.x + rel.endPoint.x) / 2 + ox
        let lblY = (rel.startPoint.y + rel.endPoint.y) / 2 + oy
        svg += "<text x=\"\(lblX)\" y=\"\(lblY)\" text-anchor=\"middle\" font-size=\"12\" fill=\"\(xmlEscape(textColor))\">\(xmlEscape(rel.label))</text>\n"

        // Technology label
        if let techn = rel.technology, !techn.isEmpty {
            let technY = lblY + 12 + 5
            svg += "<text x=\"\(lblX)\" y=\"\(technY)\" text-anchor=\"middle\" font-size=\"12\" font-style=\"italic\" fill=\"\(xmlEscape(textColor))\">[\(xmlEscape(techn))]</text>\n"
        }
    }

    svg += "</g>\n"
    return svg
}

// MARK: - Icon Defs

private func _c4DatabaseIconDef(diagramId: String) -> String {
    """
    <defs>
    <symbol id="\(diagramId)-database" fill-rule="evenodd" clip-rule="evenodd">
    <path transform="scale(.5)" d="M12.258.001l.256.004.255.005.253.008.251.01.249.012.247.015.246.016.242.019.241.02.239.023.236.024.233.027.231.028.229.031.225.032.223.034.22.036.217.038.214.04.211.041.208.043.205.045.201.046.198.048.194.05.191.051.187.053.183.054.18.056.175.057.172.059.168.06.163.061.16.063.155.064.15.066.074.033.073.033.071.034.07.034.069.035.068.035.067.035.066.035.064.036.064.036.062.036.06.036.06.037.058.037.058.037.055.038.055.038.053.038.052.038.051.039.05.039.048.039.047.039.045.04.044.04.043.04.041.04.04.041.039.041.037.041.036.041.034.041.033.042.032.042.03.042.029.042.027.042.026.043.024.043.023.043.021.043.02.043.018.044.017.043.015.044.013.044.012.044.011.045.009.044.007.045.006.045.004.045.002.045.001.045v17l-.001.045-.002.045-.004.045-.006.045-.007.045-.009.044-.011.045-.012.044-.013.044-.015.044-.017.043-.018.044-.02.043-.021.043-.023.043-.024.043-.026.043-.027.042-.029.042-.03.042-.032.042-.033.042-.034.041-.036.041-.037.041-.039.041-.04.041-.041.04-.043.04-.044.04-.045.04-.047.039-.048.039-.05.039-.051.039-.052.038-.053.038-.055.038-.055.038-.058.037-.058.037-.06.037-.06.036-.062.036-.064.036-.064.036-.066.035-.067.035-.068.035-.069.035-.07.034-.071.034-.073.033-.074.033-.15.066-.155.064-.16.063-.163.061-.168.06-.172.059-.175.057-.18.056-.183.054-.187.053-.191.051-.194.05-.198.048-.201.046-.205.045-.208.043-.211.041-.214.04-.217.038-.22.036-.223.034-.225.032-.229.031-.231.028-.233.027-.236.024-.239.023-.241.02-.242.019-.246.016-.247.015-.249.012-.251.01-.253.008-.255.005-.256.004-.258.001-.258-.001-.256-.004-.255-.005-.253-.008-.251-.01-.249-.012-.247-.015-.245-.016-.243-.019-.241-.02-.238-.023-.236-.024-.234-.027-.231-.028-.228-.031-.226-.032-.223-.034-.22-.036-.217-.038-.214-.04-.211-.041-.208-.043-.204-.045-.201-.046-.198-.048-.195-.05-.19-.051-.187-.053-.184-.054-.179-.056-.176-.057-.172-.059-.167-.06-.164-.061-.159-.063-.155-.064-.151-.066-.074-.033-.072-.033-.072-.034-.07-.034-.069-.035-.068-.035-.067-.035-.066-.035-.064-.036-.063-.036-.062-.036-.061-.036-.06-.037-.058-.037-.057-.037-.056-.038-.055-.038-.053-.038-.052-.038-.051-.039-.049-.039-.049-.039-.046-.039-.046-.04-.044-.04-.043-.04-.041-.04-.04-.041-.039-.041-.037-.041-.036-.041-.034-.041-.033-.042-.032-.042-.03-.042-.029-.042-.027-.042-.026-.043-.024-.043-.023-.043-.021-.043-.02-.043-.018-.044-.017-.043-.015-.044-.013-.044-.012-.044-.011-.045-.009-.044-.007-.045-.006-.045-.004-.045-.002-.045-.001-.045v-17l.001-.045.002-.045.004-.045.006-.045.007-.045.009-.044.011-.045.012-.044.013-.044.015-.044.017-.043.018-.044.02-.043.021-.043.023-.043.024-.043.026-.043.027-.042.029-.042.03-.042.032-.042.033-.042.034-.041.036-.041.037-.041.039-.041.04-.041.041-.04.043-.04.044-.04.046-.04.046-.039.049-.039.049-.039.051-.039.052-.038.053-.038.055-.038.056-.038.057-.037.058-.037.06-.037.061-.036.062-.036.063-.036.064-.036.066-.035.067-.035.068-.035.069-.035.07-.034.072-.034.072-.033.074-.033.151-.066.155-.064.159-.063.164-.061.167-.06.172-.059.176-.057.179-.056.184-.054.187-.053.19-.051.195-.05.198-.048.201-.046.204-.045.208-.043.211-.041.214-.04.217-.038.22-.036.223-.034.226-.032.228-.031.231-.028.234-.027.236-.024.238-.023.241-.02.243-.019.245-.016.247-.015.249-.012.251-.01.253-.008.255-.005.256-.004.258-.001.258.001z"/>
    </symbol>
    </defs>
    """
}

private func _c4ComputerIconDef(diagramId: String) -> String {
    """
    <defs>
    <symbol id="\(diagramId)-computer" width="24" height="24">
    <path transform="scale(.5)" d="M2 2v13h20v-13h-20zm18 11h-16v-9h16v9zm-10.228 6l.466-1h3.524l.467 1h-4.457zm14.228 3h-24l2-6h2.104l-1.33 4h18.45l-1.297-4h2.073l2 6zm-5-10h-14v-7h14v7z"/>
    </symbol>
    </defs>
    """
}

private func _c4ClockIconDef(diagramId: String) -> String {
    """
    <defs>
    <symbol id="\(diagramId)-clock" width="24" height="24">
    <path transform="scale(.5)" d="M12 2c5.514 0 10 4.486 10 10s-4.486 10-10 10-10-4.486-10-10 4.486-10 10-10zm0-2c-6.627 0-12 5.373-12 12s5.373 12 12 12 12-5.373 12-12-5.373-12-12-12zm5.848 12.459c.202.038.202.333.001.372-1.907.361-6.045 1.111-6.547 1.111-.719 0-1.301-.582-1.301-1.301 0-.512.77-5.447 1.125-7.445.034-.192.312-.181.343.014l.985 6.238 5.394 1.011z"/>
    </symbol>
    </defs>
    """
}

// MARK: - Arrow Marker Defs

private func _c4ArrowHeadDef(diagramId: String) -> String {
    """
    <defs>
    <marker id="\(diagramId)-arrowhead" refX="9" refY="5" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" orient="auto">
    <path d="M 0 0 L 10 5 L 0 10 z"/>
    </marker>
    </defs>
    """
}

private func _c4ArrowEndDef(diagramId: String) -> String {
    """
    <defs>
    <marker id="\(diagramId)-arrowend" refX="1" refY="5" markerUnits="userSpaceOnUse" markerWidth="12" markerHeight="12" orient="auto">
    <path d="M 10 0 L 0 5 L 10 10 z"/>
    </marker>
    </defs>
    """
}

private func _c4ArrowCrossHeadDef(diagramId: String) -> String {
    """
    <defs>
    <marker id="\(diagramId)-crosshead" markerWidth="15" markerHeight="8" orient="auto" refX="16" refY="4">
    <path fill="black" stroke="#000000" stroke-dasharray="0, 0" stroke-width="1px" d="M 9,2 V 6 L16,4 Z"/>
    <path fill="none" stroke="#000000" stroke-dasharray="0, 0" stroke-width="1px" d="M 0,1 L 6,7 M 6,1 L 0,7"/>
    </marker>
    </defs>
    """
}

private func _c4ArrowFilledHeadDef(diagramId: String) -> String {
    """
    <defs>
    <marker id="\(diagramId)-filled-head" refX="18" refY="7" markerWidth="20" markerHeight="28" orient="auto">
    <path d="M 18,7 L9,13 L14,7 L9,1 Z"/>
    </marker>
    </defs>
    """
}

// MARK: - Person Base64 Images

private func _personBase64(for type: C4ShapeType) -> String {
    switch type {
    case .external_person:
        return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAIAAADYYG7QAAAB6ElEQVR4Xu2YLY+EMBCG9+dWr0aj0Wg0Go1Go0+j8Xdv2uTCvv1gpt0ebHKPuhDaeW4605Z9mJvx4AdXUyTUdd08z+u6flmWZRnHsWkafk9DptAwDPu+f0eAYtu2PEaGWuj5fCIZrBAC2eLBAnRCsEkkxmeaJp7iDJ2QMDdHsLg8SxKFEJaAo8lAXnmuOFIhTMpxxKATebo4UiFknuNo4OniSIXQyRxEA3YsnjGCVEjVXD7yLUAqxBGUyPv/Y4W2beMgGuS7kVQIBycH0fD+oi5pezQETxdHKmQKGk1eQEYldK+jw5GxPfZ9z7Mk0Qnhf1W1m3w//EUn5BDmSZsbR44QQLBEqrBHqOrmSKaQAxdnLArCrxZcM7A7ZKs4ioRq8LFC+NpC3WCBJsvpVw5edm9iEXFuyNfxXAgSwfrFQ1c0iNda8AdejvUgnktOtJQQxmcfFzGglc5WVCj7oDgFqU18boeFSs52CUh8LE8BIVQDT1ABrB0HtgSEYlX5doJnCwv9TXocKCaKbnwhdDKPq4lf3SwU3HLq4V/+WYhHVMa/3b4IlfyikAduCkcBc7mQ3/z/Qq/cTuikhkzB12Ae/mcJC9U+Vo8Ej1gWAtgbeGgFsAMHr50BIWOLCbezvhpBFUdY6EJuJ/QDW0XoMX60zZ0AAAAASUVORK5CYII="
    default:
        return "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAwCAIAAADYYG7QAAACD0lEQVR4Xu2YoU4EMRCGT+4j8Ai8AhaH4QHgAUjQuFMECUgMIUgwJAgMhgQsAYUiJCiQIBBY+EITsjfTdme6V24v4c8vyGbb+ZjOtN0bNcvjQXmkH83WvYBWto6PLm6v7p7uH1/w2fXD+PBycX1Pv2l3IdDm/vn7x+dXQiAubRzoURa7gRZWd0iGRIiJbOnhnfYBQZNJjNbuyY2eJG8fkDE3bbG4ep6MHUAsgYxmE3nVs6VsBWJSGccsOlFPmLIViMzLOB7pCVO2AtHJMohH7Fh6zqitQK7m0rJvAVYgGcEpe//PLdDz65sM4pF9N7ICcXDKIB5Nv6j7tD0NoSdM2QrU9Gg0ewE1LqBhHR3BBdvj2vapnidjHxD/q6vd7Pvhr31AwcY8eXMTXAKECZZJFXuEq27aLgQK5uLMohCenGGuGewOxSjBvYBqeG6B+Nqiblggdjnc+ZXDy+FNFpFzw76O3UBAROuXh6FoiAcf5g9eTvUgzy0nWg6I8cXHRUpg5bOVBCo+KDpFajOf23GgPme7RSQ+lacIENUgJ6gg1k6HjgOlqnLqip4tEuhv0hNEMXUD0clyXE3p6pZA0S2nnvTlXwLJEZWlb7cTQH1+USgTN4VhAenm/wea1OCAOmqo6fE1WCb9WSKBah+rbUWPWAmE2Rvk0ApiB45eOyNAzU8xcTvj8KvkKEoOaIYeHNA3ZuygAvFMUO0AAAAASUVORK5CYII="
    }
}

// MARK: - XML Escaping

private func xmlEscape(_ s: String) -> String {
    SVG.escapeAttribute(s)
}
