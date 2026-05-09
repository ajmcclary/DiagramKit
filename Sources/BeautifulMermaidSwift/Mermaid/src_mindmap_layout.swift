import Foundation

private let TIDY_TREE_GAP: Double = 20
private let TIDY_TREE_INTERSECTION_SHIFT: Double = 30
private let LAYOUT_DATA_NODE_SPACING: Double = 50
private let LAYOUT_DATA_RANK_SPACING: Double = 50

func layoutMindmap(_ diagram: MindmapDiagram) throws -> PositionedMindmapDiagram {
    let resolvedLayout = diagram.config.resolvedLayout

    if resolvedLayout == "cose-bilkent" {
        throw BeautifulMermaidError.notYetImplemented(
            "Mindmap cose-bilkent layout: Mermaid's default mindmap layout is cose-bilkent; " +
            "the native Swift renderer currently uses tidy-tree. " +
            "Set config.layout: tidy-tree for native rendering, " +
            "or config.mindmap.layoutAlgorithm: tidy-tree to change the default."
        )
    }
    if resolvedLayout != "tidy-tree" {
        throw BeautifulMermaidError.notYetImplemented("Mindmap \(resolvedLayout) layout")
    }

    guard diagram.root != nil else {
        return .empty
    }

    let (baseNodes, baseEdges) = generateMindmapLayoutData(diagram)

    var positionedNodes = baseNodes
    var positionedEdges = baseEdges

    let fontSize = diagram.config.fontSize ?? diagram.theme.fontSize
    let fontFamily = diagram.theme.fontFamily

    for i in 0..<positionedNodes.count {
        var n = positionedNodes[i]
        let textSize = _measureMindmapLabelSize(text: n.descr, fontSize: fontSize, fontFamily: fontFamily)
        let padding = _nodePadding(for: n.type, config: diagram.config)

        let textW = textSize.width
        let textH = textSize.height

        switch n.type {
        case .circle:
            let diameter = max(textW, textH) + padding * 2 + 20
            n.width = diameter
            n.height = diameter
        case .rect:
            n.width = textW + padding * 2
            n.height = textH + padding * 2
        case .roundedRect:
            n.width = textW + 30
            n.height = textH + 30
        case .hexagon:
            n.width = textW + padding * 2
            n.height = textH + padding * 2
        case .default:
            n.width = textW + padding * 2
            n.height = textH + padding * 2 + 10
        case .cloud, .bang:
            n.width = textW + padding * 2 + 30
            n.height = textH + padding * 2 + 30
        }

        n.width = max(n.width, 30)
        n.height = max(n.height, 20)

        if n.icon != nil {
            if n.type == .circle {
                n.width += 50
                n.height += 50
            } else {
                n.width += 50
                n.height = max(n.height, 60)
            }
        }

        positionedNodes[i] = n
    }

    let tidytreeNode = _makeTidyTreeNode(nodes: positionedNodes, edges: positionedEdges)
    _ = _tidyTreeLayout(node: tidytreeNode, gap: TIDY_TREE_GAP)

    for i in 0..<positionedNodes.count {
        let node = positionedNodes[i]
        if node.isRoot {
            positionedNodes[i].x = 0
            positionedNodes[i].y = 0
        }
    }

    if let rt = tidytreeNode {
        _applyTidyTreePositions(node: rt, rootX: 0, rootY: 0, nodes: &positionedNodes)

        for i in 0..<positionedEdges.count {
            let edge = positionedEdges[i]
            let parentNode = positionedNodes.first(where: { $0.id == edge.parentId })
            let childNode = positionedNodes.first(where: { $0.id == edge.childId })

            if let p = parentNode, let c = childNode {
                let points = _computeEdgePath(parent: p, child: c, intersectionShift: TIDY_TREE_INTERSECTION_SHIFT)
                positionedEdges[i].points = points
                positionedEdges[i].path = _svgPathForPoints(points)
            }
        }
    }

    var minX: Double = 0
    var minY: Double = 0
    var maxX: Double = 0
    var maxY: Double = 0

    for node in positionedNodes {
        minX = min(minX, node.x - node.width / 2)
        minY = min(minY, node.y - node.height / 2)
        maxX = max(maxX, node.x + node.width / 2)
        maxY = max(maxY, node.y + node.height / 2)
    }

    let padding = diagram.config.padding

    let viewportW = maxX - minX + padding * 2 + 40
    let viewportH = maxY - minY + padding * 2 + 40

    let offsetX = -minX + padding + 20
    let offsetY = -minY + padding + 20

    for i in 0..<positionedNodes.count {
        positionedNodes[i].x += offsetX
        positionedNodes[i].y += offsetY
    }

    for i in 0..<positionedEdges.count {
        let edge = positionedEdges[i]
        let shiftedPoints = edge.points.map { CGPoint(x: $0.x + offsetX, y: $0.y + offsetY) }
        positionedEdges[i].points = shiftedPoints
        positionedEdges[i].path = _svgPathForPoints(shiftedPoints)
    }

    let rootNode = positionedNodes.first

    return PositionedMindmapDiagram(
        width: viewportW,
        height: viewportH,
        nodes: positionedNodes,
        edges: positionedEdges,
        rootNode: rootNode,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: diagram.config,
        theme: diagram.theme
    )
}

private func _nodePadding(for type: MindmapNodeType, config: MindmapConfig) -> Double {
    switch type {
    case .rect, .roundedRect, .hexagon: return config.padding * 2
    case .circle: return 10
    default: return config.padding
    }
}

private func _measureMindmapLabelSize(text: String, fontSize: Double, fontFamily: String) -> (width: Double, height: Double) {
    let normalized = text
        .replacingOccurrences(of: "<br/>", with: "\n")
        .replacingOccurrences(of: "<br>", with: "\n")
    let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.count > 1 else {
        return _measureTextSize(text: normalized, fontSize: fontSize, fontFamily: fontFamily)
    }

    let widths = lines.map { _measureTextSize(text: $0, fontSize: fontSize, fontFamily: fontFamily).width }
    return (
        width: widths.max() ?? 0,
        height: Double(lines.count) * fontSize * 1.3
    )
}

private func _measureTextSize(text: String, fontSize: Double, fontFamily: String) -> (width: Double, height: Double) {
    let nsString = text as NSString
    let font = BMFont(name: fontFamily, size: CGFloat(fontSize)) ?? BMFont.systemFont(ofSize: CGFloat(fontSize))

    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let size = nsString.boundingRect(with: CGSize(width: 1000, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
    return (Double(size.width), Double(size.height))
}
private final class _TidyTreeNodeRef {
    var id: Int
    var width: Double
    var height: Double
    var x: Double
    var y: Double
    var children: [_TidyTreeNodeRef]
    var isLeftTree: Bool

    init(id: Int, width: Double, height: Double, x: Double = 0, y: Double = 0, isLeftTree: Bool = false) {
        self.id = id
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.children = []
        self.isLeftTree = isLeftTree
    }
}

private func _makeTidyTreeNode(nodes: [PositionedMindmapNode], edges: [PositionedMindmapEdge]) -> _TidyTreeNodeRef? {
    guard let rootNode = nodes.first(where: { $0.isRoot }) else { return nil }
    let root = _TidyTreeNodeRef(id: rootNode.id, width: rootNode.width, height: rootNode.height)

    let childMap: [Int: [Int]] = {
        var map: [Int: [Int]] = [:]
        for edge in edges {
            map[edge.parentId, default: []].append(edge.childId)
        }
        return map
    }()

    var leftChildren: [Int] = []
    var rightChildren: [Int] = []

    let childrenIds = childMap[rootNode.id] ?? []
    for (idx, childId) in childrenIds.enumerated() {
        if idx % 2 == 0 {
            leftChildren.append(childId)
        } else {
            rightChildren.append(childId)
        }
    }

    func buildSubtree(parentRef: _TidyTreeNodeRef, childIds: [Int], isLeft: Bool) {
        for childId in childIds {
            guard let childNode = nodes.first(where: { $0.id == childId }) else { continue }
            let child = _TidyTreeNodeRef(id: childNode.id, width: childNode.width, height: childNode.height, isLeftTree: isLeft)
            parentRef.children.append(child)
            let grandchildIds = childMap[childId] ?? []
            buildSubtree(parentRef: child, childIds: grandchildIds, isLeft: isLeft)
        }
    }

    buildSubtree(parentRef: root, childIds: leftChildren, isLeft: true)
    buildSubtree(parentRef: root, childIds: rightChildren, isLeft: false)

    return root
}

private func _tidyTreeLayout(node: _TidyTreeNodeRef?, gap: Double) -> (left: [_TidyTreeNodeRef], right: [_TidyTreeNodeRef])? {
    guard let root = node else { return nil }

    var leftChildren: [_TidyTreeNodeRef] = []
    var rightChildren: [_TidyTreeNodeRef] = []

    for child in root.children {
        if child.isLeftTree {
            leftChildren.append(child)
        } else {
            rightChildren.append(child)
        }
    }

    _layoutRootSide(children: leftChildren, root: root, gap: gap, isLeft: true)
    _layoutRootSide(children: rightChildren, root: root, gap: gap, isLeft: false)

    return (leftChildren, rightChildren)
}

private func _layoutRootSide(children: [_TidyTreeNodeRef], root: _TidyTreeNodeRef, gap: Double, isLeft: Bool) {
    guard !children.isEmpty else { return }

    let totalHeight = _subtreeStackHeight(children, gap: gap)
    var cursorY = -totalHeight / 2

    for child in children {
        let childHeight = _subtreeHeight(child, gap: gap)
        _layoutSubtree(
            child,
            parent: root,
            centerY: cursorY + childHeight / 2,
            gap: gap,
            isLeft: isLeft
        )
        cursorY += childHeight + gap
    }
}

private func _layoutSubtree(
    _ node: _TidyTreeNodeRef,
    parent: _TidyTreeNodeRef,
    centerY: Double,
    gap: Double,
    isLeft: Bool
) {
    let direction: Double = isLeft ? -1 : 1
    node.x = parent.x + direction * (parent.width / 2 + gap + node.width / 2)
    node.y = centerY

    guard !node.children.isEmpty else { return }

    let childrenHeight = _subtreeStackHeight(node.children, gap: gap)
    var cursorY = centerY - childrenHeight / 2

    for child in node.children {
        let childHeight = _subtreeHeight(child, gap: gap)
        _layoutSubtree(
            child,
            parent: node,
            centerY: cursorY + childHeight / 2,
            gap: gap,
            isLeft: isLeft
        )
        cursorY += childHeight + gap
    }
}

private func _subtreeStackHeight(_ nodes: [_TidyTreeNodeRef], gap: Double) -> Double {
    guard !nodes.isEmpty else { return 0 }
    return nodes.map { _subtreeHeight($0, gap: gap) }.reduce(0, +) + Double(nodes.count - 1) * gap
}

private func _subtreeHeight(_ node: _TidyTreeNodeRef, gap: Double) -> Double {
    guard !node.children.isEmpty else { return node.height }
    return max(node.height, _subtreeStackHeight(node.children, gap: gap))
}

private func _applyTidyTreePositions(node: _TidyTreeNodeRef, rootX: Double, rootY: Double, nodes: inout [PositionedMindmapNode]) {
    if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
        nodes[idx].x = node.x + rootX
        nodes[idx].y = node.y + rootY
    }

    for child in node.children {
        _applyTidyTreePositions(node: child, rootX: rootX, rootY: rootY, nodes: &nodes)
    }
}

private func _computeEdgePath(parent: PositionedMindmapNode, child: PositionedMindmapNode, intersectionShift: Double) -> [CGPoint] {
    let px = parent.x
    let py = parent.y
    let pw = parent.width

    let cx = child.x
    let cy = child.y
    let cw = child.width

    let isLeft = cx < px

    let startX: Double
    let endX: Double
    let startShift: Double
    let endShift: Double

    if isLeft {
        startX = px - pw / 2
        endX = cx + cw / 2
        startShift = -intersectionShift
        endShift = intersectionShift
    } else {
        startX = px + pw / 2
        endX = cx - cw / 2
        startShift = intersectionShift
        endShift = -intersectionShift
    }

    let startY = py
    let endY = cy

    let midX = (startX + endX) / 2

    let points: [CGPoint] = [
        CGPoint(x: startX, y: startY),
        CGPoint(x: startX + startShift, y: startY),
        CGPoint(x: midX, y: (startY + endY) / 2),
        CGPoint(x: endX + endShift, y: endY),
        CGPoint(x: endX, y: endY),
    ]

    return points
}

private func _svgPathForPoints(_ points: [CGPoint]) -> String {
    guard let first = points.first else { return "" }
    var path = "M\(first.x),\(first.y)"
    for i in 1..<points.count {
        let p = points[i]
        if i == 1 || i == points.count - 1 {
            path += " L\(p.x),\(p.y)"
        } else {
            let prev = points[i - 1]
            let cp1x = prev.x + (p.x - prev.x) * 0.25
            let cp1y = prev.y
            let cp2x = prev.x + (p.x - prev.x) * 0.75
            let cp2y = p.y
            path += " C\(cp1x),\(cp1y) \(cp2x),\(cp2y) \(p.x),\(p.y)"
        }
    }
    return path
}
