import Foundation

func renderTreeViewSvg(_ positioned: PositionedTreeViewDiagram, diagramId: String, font: String) -> String {
    let theme = positioned.theme ?? .default
    let config = positioned.config

    var svg = ""

    let viewBoxW = positioned.viewBoxWidth
    let viewBoxH = positioned.viewBoxHeight
    var svgAttrs = "id=\"\(_xmlEscape(diagramId))\" viewBox=\"\(positioned.viewBoxX) \(positioned.viewBoxY) \(viewBoxW) \(viewBoxH)\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" role=\"graphics-document\""
    var svgStyle = ""
    if config.useMaxWidth {
        svgAttrs += " width=\"100%\""
        svgStyle = "max-width: \(viewBoxW)px"
    } else {
        svgAttrs += " width=\"\(viewBoxW)\""
    }
    if !svgStyle.isEmpty {
        svg += "<svg \(svgAttrs) style=\"\(svgStyle)\">"
    } else {
        svg += "<svg \(svgAttrs)>"
    }

    if let accTitle = positioned.accTitle, !accTitle.isEmpty {
        svg += "<title>\(_xmlEscape(accTitle))</title>"
    }
    if let accDescr = positioned.accDescr, !accDescr.isEmpty {
        svg += "<desc>\(_xmlEscape(accDescr))</desc>"
    }

    svg += "<style>"
    svg += ".treeView-node-label{font-size:\(theme.labelFontSize);fill:\(theme.labelColor)}"
    svg += ".treeView-node-dir{font-weight:bold}"
    svg += ".treeView-node-line{stroke:\(theme.lineColor)}"
    svg += ".treeView-node-icon{fill:\(theme.iconColor)}"
    svg += ".treeView-node-description{font-size:\(theme.labelFontSize);fill:\(theme.descriptionColor);font-style:italic}"
    svg += ".treeView-highlight-bg{fill:\(theme.highlightBg);stroke:\(theme.highlightStroke);stroke-width:1}"
    svg += "</style>"

    if config.showIcons, !positioned.iconDefs.isEmpty {
        svg += "<defs>"
        for iconId in positioned.iconDefs {
            let path = getIconPath(iconId: iconId)
            svg += "<symbol id=\"tv-icon-\(_xmlEscape(diagramId))-\(_xmlEscape(iconId))\" viewBox=\"0 0 24 24\">"
            svg += "<path d=\"\(_xmlEscape(path))\"/>"
            svg += "</symbol>"
        }
        svg += "</defs>"
    }

    svg += "<g class=\"tree-view\">"

    for posNode in positioned.nodes {
        svg += "<g>"

        if let highlightRect = positioned.highlightRects.first(where: { $0.nodeId == posNode.id }) {
            svg += "<rect class=\"treeView-highlight-bg\" x=\"\(highlightRect.x)\" y=\"\(highlightRect.y)\" width=\"\(highlightRect.width)\" height=\"\(highlightRect.height)\" rx=\"\(highlightRect.rx)\"/>"
        }

        if let iconX = posNode.iconX, let iconY = posNode.iconY, let iconId = posNode.iconId, iconId != "none" {
            svg += "<use xlink:href=\"#tv-icon-\(_xmlEscape(diagramId))-\(_xmlEscape(iconId))\" x=\"\(iconX)\" y=\"\(iconY)\" width=\"\(ICON_SIZE)\" height=\"\(ICON_SIZE)\" class=\"treeView-node-icon\"/>"
        }

        var labelClasses = "treeView-node-label"
        if posNode.nodeType == .directory {
            labelClasses += " treeView-node-dir"
        }
        if let cssClass = posNode.cssClass, !cssClass.isEmpty {
            labelClasses += " \(_xmlEscape(cssClass))"
        }
        svg += "<text class=\"\(labelClasses)\" x=\"\(posNode.labelX)\" y=\"\(posNode.labelY)\" dominant-baseline=\"middle\">\(_xmlEscape(posNode.name))</text>"

        if let desc = posNode.description, !desc.isEmpty, let descX = posNode.descriptionX, let descY = posNode.descriptionY {
            svg += "<text class=\"treeView-node-description\" x=\"\(descX)\" y=\"\(descY)\" dominant-baseline=\"middle\">\(_xmlEscape(desc))</text>"
        }

        svg += "</g>"
    }

    for line in positioned.connectorLines {
        svg += "<line class=\"treeView-node-line\" x1=\"\(line.x1)\" y1=\"\(line.y1)\" x2=\"\(line.x2)\" y2=\"\(line.y2)\" stroke-width=\"\(config.lineThickness)\"/>"
    }

    svg += "</g>"
    svg += "</svg>"

    return svg
}

private func _xmlEscape(_ value: String) -> String {
    SVG.escapeAttribute(value)
}
