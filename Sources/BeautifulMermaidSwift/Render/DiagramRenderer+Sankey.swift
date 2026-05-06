import Foundation
import CoreGraphics
import CoreText
#if targetEnvironment(macCatalyst)
import UIKit
#elseif canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {

    func _drawSankey(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .sankey(let diagram) = positioned.content else { return }

        _withFittedContext(context, bounds: bounds, contentWidth: diagram.width, contentHeight: diagram.height) { ctx in

            let ch = diagram.height
            ctx.saveGState()
            ctx.translateBy(x: 0, y: ch)
            ctx.scaleBy(x: 1, y: -1)

            let nodeColorMap = _cgSankeyColorMap(diagram)
            let defaultColor: (String) -> BMColor = { id in
                if let idx = diagram.nodes.firstIndex(where: { $0.id == id }) {
                    return BMColor(hex: sankeyTableau10[idx % sankeyTableau10.count])
                }
                return BMColor(hex: sankeyTableau10[0])
            }

            let halfWidth = diagram.width / 2
            let font = _sankeyCGFont(size: 14)

            for link in diagram.links {
                let sourceColor = nodeColorMap[link.sourceID] ?? defaultColor(link.sourceID)
                let targetColor = nodeColorMap[link.targetID] ?? defaultColor(link.targetID)

                let strokeColor: BMColor
                switch diagram.config.linkColor {
                case .source: strokeColor = sourceColor
                case .target: strokeColor = targetColor
                case .gradient:
                    ctx.saveGState()
                    let path = link.path.cgPath
                    ctx.addPath(path)
                    ctx.setLineWidth(CGFloat(max(1, link.width)))
                    ctx.replacePathWithStrokedPath()
                    ctx.clip()

                    let colors = [sourceColor.cgColor, targetColor.cgColor]
                    let locations: [CGFloat] = [0, 1]
                    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                                  colors: colors as CFArray,
                                                  locations: locations) {
                        ctx.drawLinearGradient(gradient,
                                               start: CGPoint(x: link.path.sourceX, y: ch - link.path.sourceY),
                                               end: CGPoint(x: link.path.targetX, y: ch - link.path.targetY),
                                               options: [])
                    }
                    ctx.restoreGState()
                    continue
                case .fixed(let color): strokeColor = BMColor(hex: color)
                }

                let path = link.path.cgPath
                ctx.addPath(path)
                ctx.setStrokeColor(strokeColor.withAlphaComponent(0.5).cgColor)
                ctx.setLineWidth(CGFloat(max(1, link.width)))
                ctx.strokePath()
            }

            for node in diagram.nodes {
                let nodeColor = nodeColorMap[node.id] ?? defaultColor(node.id)
                let rect = CGRect(x: node.x0, y: ch - node.y1,
                                  width: node.x1 - node.x0,
                                  height: node.y1 - node.y0)
                ctx.setFillColor(nodeColor.cgColor)
                ctx.fill(rect)
            }

            let centerLayer = _centralCGSankeyLayer(diagram)
            for node in diagram.nodes {
                let nodeColor = nodeColorMap[node.id] ?? defaultColor(node.id)
                let labelColor = isDarkColor(nodeColor) ? BMColor(hex: "#ffffff") : BMColor(hex: "#000000")
                let labelText: String
                if diagram.config.showValues {
                    let prefix = diagram.config.prefix
                    let suffix = diagram.config.suffix
                    let formatted = String(format: "%.2f", max(0, node.value))
                    labelText = "\(node.id)\n\(prefix)\(formatted)\(suffix)"
                } else {
                    labelText = node.id
                }

                let midY = node.y0 + (node.y1 - node.y0) / 2
                let textY = ch - midY

                switch diagram.config.labelStyle {
                case .legacy:
                    if node.x0 < halfWidth {
                        let labelX = node.x1 + 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: textY),
                                           context: ctx, contentHeight: ch,
                                           color: labelColor, font: font, alignment: .left)
                    } else {
                        let labelX = node.x0 - 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: textY),
                                           context: ctx, contentHeight: ch,
                                           color: labelColor, font: font, alignment: .right)
                    }
                case .outlined:
                    let isLeftOfCenter = node.layer < centerLayer
                    if isLeftOfCenter {
                        let labelX = node.x0 - 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: textY),
                                           context: ctx, contentHeight: ch,
                                           color: labelColor, font: font, alignment: .right)
                    } else {
                        let labelX = node.x1 + 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: textY),
                                           context: ctx, contentHeight: ch,
                                           color: labelColor, font: font, alignment: .left)
                    }
                }
            }

            ctx.restoreGState()
        }
    }
}

private func _cgSankeyColorMap(_ diagram: PositionedSankeyDiagram) -> [String: BMColor] {
    var map: [String: BMColor] = [:]
    for node in diagram.nodes {
        if let custom = diagram.config.nodeColors[node.id] {
            map[node.id] = BMColor(hex: custom)
        }
    }
    return map
}

private func isDarkColor(_ color: BMColor) -> Bool {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    let luminance = (0.299 * r + 0.587 * g + 0.114 * b)
    return luminance < 0.5
}

private func _centralCGSankeyLayer(_ diagram: PositionedSankeyDiagram) -> Int {
    let maxNode = diagram.nodes.max(by: { $0.value < $1.value })
    return maxNode?.layer ?? 0
}

private func _sankeyCGFont(size: CGFloat) -> BMFont {
    #if targetEnvironment(macCatalyst) || canImport(UIKit)
    return UIFont.systemFont(ofSize: size)
    #elseif canImport(AppKit)
    return NSFont.systemFont(ofSize: size)
    #endif
}
