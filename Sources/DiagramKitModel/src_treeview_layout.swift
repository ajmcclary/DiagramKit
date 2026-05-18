import Foundation
import DiagramKitCommon
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(CoreText)
import CoreText
#endif
#if canImport(UIKit) || canImport(AppKit)
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
#endif

public let ICON_SIZE: Double = 14
public let ICON_GAP: Double = 4
public let DESC_GAP: Double = 16

public func layoutTreeViewDiagram(_ diagram: TreeViewDiagram) -> PositionedTreeViewDiagram {
    let config = diagram.config
    let theme = diagram.theme ?? .default
    let labelFontSize = _parseLabelFontSize(theme.labelFontSize)

    var totalHeight: Double = 0
    var totalWidth: Double = 0
    var positionedNodes: [PositionedTreeViewNode] = []
    var connectorLines: [TreeViewConnectorLine] = []
    var nodeStack: [(node: TreeViewNode, depth: Int)] = []

    func measureText(_ text: String, fontSize: Double) -> (width: Double, height: Double) {
#if canImport(CoreText)
        let font = _treeViewFont(size: CGFloat(fontSize))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attributes)
        return (Double(size.width), Double(size.height))
#else
        let width = Double(TextMetrics.shared.estimateTextWidth(
            text, fontSize: CGFloat(fontSize), fontWeight: 400))
        let height = fontSize * 1.2
        return (width, height)
#endif
    }

    func layoutNode(_ node: TreeViewNode, depth: Int) {
        let indent = Double(depth) * (config.rowIndent + config.paddingX)
        let showsIcon = config.showIcons && node.iconId != nil && node.iconId != "none"
        let iconOffset = showsIcon ? (ICON_SIZE + ICON_GAP) : 0.0
        let labelSize = measureText(node.name, fontSize: labelFontSize)
        let labelHeight = labelSize.height + config.paddingY * 2
        let labelWidth = labelSize.width
        let nodeWidth = labelWidth + config.paddingX * 2 + iconOffset
        let nodeHeight = max(labelHeight, ICON_SIZE + 2 * config.paddingY)

        let x = indent
        let y = totalHeight
        let labelX = x + config.paddingX + iconOffset
        let centerY = y + nodeHeight / 2
        let labelY = y + nodeHeight / 2
        let labelRightEdge = labelX + labelWidth

        var iconX: Double?
        var iconY: Double?
        if showsIcon {
            iconX = x + config.paddingX
            iconY = y + config.paddingY
        }

        let posNode = PositionedTreeViewNode(
            id: node.id,
            name: node.name,
            nodeType: node.nodeType,
            iconId: node.iconId,
            cssClass: node.cssClass,
            description: node.description,
            x: x, y: y,
            width: nodeWidth, height: nodeHeight,
            depth: depth,
            labelRightEdge: labelRightEdge,
            centerY: centerY,
            labelX: labelX, labelY: labelY,
            iconX: iconX, iconY: iconY,
            descriptionX: nil, descriptionY: nil
        )
        positionedNodes.append(posNode)
        nodeStack.append((node, depth))

        connectorLines.append(TreeViewConnectorLine(
            x1: indent - config.rowIndent,
            y1: centerY,
            x2: indent,
            y2: centerY
        ))

        totalWidth = max(totalWidth, indent + nodeWidth)
        totalHeight += nodeHeight
    }

    func processNode(_ node: TreeViewNode, depth: Int = 0) {
        layoutNode(node, depth: depth)
        guard _recursionGuard(depth: depth, location: "TreeView.processNode") else {
            return
        }
        for child in node.children {
            processNode(child, depth: depth + 1)
        }
        if !node.children.isEmpty {
            let parentIdx = positionedNodes.firstIndex(where: { $0.id == node.id })
            let lastChild = node.children.last!
            let lastChildPos = positionedNodes.first(where: { $0.id == lastChild.id })
            if let parentPos = parentIdx.flatMap({ positionedNodes[$0] }) as Optional,
               let childPos = lastChildPos {
                connectorLines.append(TreeViewConnectorLine(
                    x1: parentPos.x + config.paddingX,
                    y1: parentPos.y + parentPos.height,
                    x2: parentPos.x + config.paddingX,
                    y2: childPos.centerY + config.lineThickness / 2
                ))
            }
        }
    }

    processNode(diagram.root)

    var positionedNodesWithDesc = positionedNodes
    var descriptionX: Double?
    if positionedNodes.contains(where: { $0.description != nil && !$0.description!.isEmpty }) {
        let maxLabelRight = positionedNodes.map(\.labelRightEdge).max() ?? 0
        descriptionX = maxLabelRight + DESC_GAP

        for i in positionedNodes.indices {
            if let desc = positionedNodes[i].description, !desc.isEmpty {
                let descSize = measureText(desc, fontSize: labelFontSize)
                let descX = maxLabelRight + DESC_GAP
                positionedNodesWithDesc[i].descriptionX = descX
                positionedNodesWithDesc[i].descriptionY = positionedNodes[i].centerY
                totalWidth = max(totalWidth, descX + descSize.width + config.paddingX)
            }
        }
    }

    var highlightRects: [TreeViewHighlightRect] = []
    for posNode in positionedNodesWithDesc {
        if let cssClass = posNode.cssClass, cssClass.split(separator: " ").contains(where: { $0.lowercased() == "highlight" }) {
            let rectWidth = totalWidth - posNode.x + 8
            highlightRects.append(TreeViewHighlightRect(
                nodeId: posNode.id,
                x: posNode.x,
                y: posNode.y + 1,
                width: rectWidth,
                height: posNode.height - 2,
                rx: 3
            ))
            totalWidth = max(totalWidth, posNode.x + rectWidth + 2)
        }
    }

    let viewBoxX = -config.lineThickness / 2
    let viewBoxY: Double = 0
    let viewBoxWidth = totalWidth
    let viewBoxHeight = totalHeight

    var iconDefs: [String] = []
    if config.showIcons {
        var usedIcons = Set<String>()
        for node in diagram.nodes {
            if let iconId = node.iconId, iconId != "none" {
                usedIcons.insert(iconId)
            }
        }
        iconDefs = Array(usedIcons).sorted()
    }

    return PositionedTreeViewDiagram(
        width: viewBoxWidth, height: viewBoxHeight,
        nodes: positionedNodesWithDesc,
        connectorLines: connectorLines,
        highlightRects: highlightRects,
        descriptionX: descriptionX,
        viewBoxX: viewBoxX, viewBoxY: viewBoxY,
        viewBoxWidth: viewBoxWidth, viewBoxHeight: viewBoxHeight,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: config,
        theme: theme,
        iconDefs: iconDefs
    )
}

private func _parseLabelFontSize(_ value: String) -> Double {
    let cleaned = value.replacingOccurrences(of: "px", with: "").replacingOccurrences(of: "pt", with: "")
    return Double(cleaned) ?? 16
}

#if canImport(UIKit) || canImport(AppKit)
/// Resolve the label font through `DiagramFontResolver.shared` so layout
/// and the CG renderer (`DiagramRenderer+TreeView`) measure text with
/// the same font family. Previously this called `BMFont.systemFont(...)`
/// directly, which let the bundled-font determinism guarantee leak
/// out — labels could be measured in system Helvetica but rendered in
/// Inter, drifting layout widths from snapshot baselines.
private func _treeViewFont(size: CGFloat) -> BMFont {
    DiagramFontResolver.shared.proportionalFont(size: size, weight: .regular)
}
#endif
