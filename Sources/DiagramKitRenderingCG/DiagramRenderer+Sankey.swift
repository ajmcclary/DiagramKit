// Apple-only target gated by `#if canImport(CoreGraphics)`. On Linux this file is empty.
#if canImport(CoreGraphics)
import Foundation
import DiagramKitModel
import CoreGraphics
import CoreText
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension DiagramRenderer {

    func _drawSankey(_ positioned: PositionedGraph, in context: CGContext, bounds: CGRect) {
        guard case .sankey(let diagram) = positioned.content else { return }

        let padding = diagram.config.useMaxWidth ? 0.0 : 10.0
        let contentWidth = diagram.width + padding * 2
        let contentHeight = diagram.height + padding * 2

        _withFittedContext(context, bounds: bounds, contentWidth: contentWidth, contentHeight: contentHeight) { ctx in
            ctx.translateBy(x: padding, y: padding)

            let nodeColorMap = _cgSankeyColorMap(diagram)
            let defaultColor: (String) -> BMColor = { id in
                if let idx = diagram.nodes.firstIndex(where: { $0.id == id }) {
                    return BMColor(hex: sankeyTableau10[idx % sankeyTableau10.count])
                }
                return BMColor(hex: sankeyTableau10[0])
            }

            let halfWidth = diagram.width / 2
            let font = config.proportionalFont(size: 14)

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
                        ctx.setAlpha(0.5)
                        ctx.drawLinearGradient(gradient,
                                               start: CGPoint(x: link.path.sourceX, y: link.path.sourceY),
                                               end: CGPoint(x: link.path.targetX, y: link.path.targetY),
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
                let rect = CGRect(x: node.x0, y: node.y0,
                                  width: node.x1 - node.x0,
                                  height: node.y1 - node.y0)
                ctx.setFillColor(nodeColor.cgColor)
                ctx.fill(rect)
            }

            let centerLayer = _centralCGSankeyLayer(diagram)
            for node in diagram.nodes {
                let labelColor = BMColor(hex: "#27272A")
                let labelText: String
                if diagram.config.showValues {
                    let prefix = diagram.config.prefix
                    let suffix = diagram.config.suffix
                    let formatted = _cgSankeyFormatValue(max(0, node.value))
                    labelText = "\(node.id)\n\(prefix)\(formatted)\(suffix)"
                } else {
                    labelText = node.id
                }

                let midY = node.y0 + (node.y1 - node.y0) / 2

                switch diagram.config.labelStyle {
                case .legacy:
                    if node.x0 < halfWidth {
                        let labelX = node.x1 + 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: midY),
                                           context: ctx, contentHeight: diagram.height,
                                           color: labelColor, font: font, alignment: .left)
                    } else {
                        let labelX = node.x0 - 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: midY),
                                           context: ctx, contentHeight: diagram.height,
                                           color: labelColor, font: font, alignment: .right)
                    }
                case .outlined:
                    let isLeftOfCenter = node.layer < centerLayer
                    if isLeftOfCenter {
                        let labelX = node.x0 - 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: midY),
                                           context: ctx, contentHeight: diagram.height,
                                           color: labelColor, font: font, alignment: .right)
                    } else {
                        let labelX = node.x1 + 6
                        _drawTextInFlipped(labelText, at: CGPoint(x: labelX, y: midY),
                                           context: ctx, contentHeight: diagram.height,
                                           color: labelColor, font: font, alignment: .left)
                    }
                }
            }
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

private func _centralCGSankeyLayer(_ diagram: PositionedSankeyDiagram) -> Int {
    let maxNode = diagram.nodes.max(by: { $0.value < $1.value })
    return maxNode?.layer ?? 0
}

private func _cgSankeyFormatValue(_ v: Double) -> String {
    let rounded = (v * 100).rounded() / 100
    if !rounded.isFinite { return "0" }
    if rounded == rounded.rounded() { return String(Int(rounded)) }
    let str = String(format: "%.2f", rounded)
    if str.hasSuffix("0") {
        return String(format: "%.1f", rounded)
    }
    return str
}
#endif
