import Foundation
import DiagramKitCommon

private enum RQL {
    static let padding: Double = 40
    static let stereotypeHeight: Double = 18
    static let nameHeight: Double = 20
    static let rowHeight: Double = 18
    static let dividerHeight: Double = 6
    static let minWidth: Double = 180
    static let minHeight: Double = 80
    static let nodeSpacing: Double = 50
    static let rankSpacing: Double = 50
    static let boxPadX: Double = 14
    static let boxPadY: Double = 8
    static let headerHeight: Double = 44
}

private typealias NodeSizeMap = [String: (width: Double, height: Double)]

// ELK adapter types live in ElkModels.swift (ElkGraphNode / ElkGraphEdge /
// ElkGraphLabel / ElkEdgeSection). The local _RElkNode/_RElkEdge/... structs
// that used to wrap them here were deleted in Phase 1 (audit A1).

private func _reqMapDirection(_ dir: RequirementDirection) -> String {
    switch dir {
    case .TB: return "DOWN"
    case .BT: return "UP"
    case .LR: return "RIGHT"
    case .RL: return "LEFT"
    }
}

private func _estimateReqNodeSize(
    _ node: RequirementNode
) -> (width: Double, height: Double) {
    let stereotypeText = "<<\(node.type.rawValue)>>"
    let nameText = node.name
    var maxRowWidth = max(
        original_src_styles.estimateTextWidth(stereotypeText, 11, 400),
        original_src_styles.estimateTextWidth(nameText, 13, 700)
    )

    var bodyRowCount = 0
    if !node.requirementId.isEmpty {
        let w = original_src_styles.estimateTextWidth("ID: \(node.requirementId)", 11, 400)
        maxRowWidth = max(maxRowWidth, w)
        bodyRowCount += 1
    }
    if !node.text.isEmpty {
        let w = original_src_styles.estimateTextWidth("Text: \(node.text)", 11, 400)
        maxRowWidth = max(maxRowWidth, w)
        bodyRowCount += 1
    }
    if let r = node.risk {
        let w = original_src_styles.estimateTextWidth("Risk: \(r.rawValue)", 11, 400)
        maxRowWidth = max(maxRowWidth, w)
        bodyRowCount += 1
    }
    if let v = node.verifyMethod {
        let w = original_src_styles.estimateTextWidth("Verification: \(v.rawValue)", 11, 400)
        maxRowWidth = max(maxRowWidth, w)
        bodyRowCount += 1
    }

    let width = max(RQL.minWidth, maxRowWidth + RQL.boxPadX * 2)
    let hasBody = bodyRowCount > 0
    let height = RQL.headerHeight + (hasBody ? RQL.dividerHeight + Double(bodyRowCount) * RQL.rowHeight : 0) + RQL.boxPadY * 2
    return (width, max(height, RQL.minHeight))
}

private func _estimateElNodeSize(
    _ node: ElementNode
) -> (width: Double, height: Double) {
    let stereotypeText = "<<Element>>"
    let nameText = node.name
    var maxRowWidth = max(
        original_src_styles.estimateTextWidth(stereotypeText, 11, 400),
        original_src_styles.estimateTextWidth(nameText, 13, 700)
    )

    var bodyRowCount = 0
    if !node.type.isEmpty {
        let w = original_src_styles.estimateTextWidth("Type: \(node.type)", 11, 400)
        maxRowWidth = max(maxRowWidth, w)
        bodyRowCount += 1
    }
    if !node.docRef.isEmpty {
        let w = original_src_styles.estimateTextWidth("Doc Ref: \(node.docRef)", 11, 400)
        maxRowWidth = max(maxRowWidth, w)
        bodyRowCount += 1
    }

    let width = max(RQL.minWidth, maxRowWidth + RQL.boxPadX * 2)
    let hasBody = bodyRowCount > 0
    let height = RQL.headerHeight + (hasBody ? RQL.dividerHeight + Double(bodyRowCount) * RQL.rowHeight : 0) + RQL.boxPadY * 2
    return (width, max(height, RQL.minHeight))
}

private func _buildReqElkGraph(
    _ diagram: RequirementDiagram,
    _ options: RenderOptions
) -> (elkGraph: ElkGraphNode, nodeSizes: NodeSizeMap) {
    _ = options
    var nodeSizes: NodeSizeMap = [:]
    var allNodes: [(id: String, isRequirement: Bool, colorIndex: Int)] = []

    // Requirements first (colorIndex 0..N-1)
    for (idx, req) in diagram.requirements.enumerated() {
        let size = _estimateReqNodeSize(req)
        nodeSizes[req.name] = size
        allNodes.append((id: req.name, isRequirement: true, colorIndex: idx))
    }

    // Then elements (colorIndex N..N+M-1)
    for (idx, el) in diagram.elements.enumerated() {
        let size = _estimateElNodeSize(el)
        nodeSizes[el.name] = size
        allNodes.append((id: el.name, isRequirement: false, colorIndex: diagram.requirements.count + idx))
    }

    var children: [ElkGraphNode] = []
    for node in allNodes {
        let size = nodeSizes[node.id] ?? (RQL.minWidth, RQL.minHeight)
        children.append(ElkGraphNode(id: node.id, width: size.width, height: size.height))
    }

    var edges: [ElkGraphEdge] = []
    for (idx, rel) in diagram.relationships.enumerated() {
        let edgeId = "\(rel.sourceName)-\(rel.destinationName)-\(idx)"
        let labelText = "<<\(rel.type.rawValue)>>"
        let metrics = original_src_text_metrics.measureMultilineText(
            labelText,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
        )
        edges.append(ElkGraphEdge(
            id: edgeId,
            sources: [rel.sourceName],
            targets: [rel.destinationName],
            labels: [
                ElkGraphLabel(text: labelText, width: metrics.width + 8, height: metrics.height + 6)
            ]
        ))
    }

    let directionStr = _reqMapDirection(diagram.direction)
    let ns = diagram.config.nodeSpacing
    let ls = diagram.config.rankSpacing
    let pad = RQL.padding

    let elkGraph = ElkGraphNode(
        id: "root",
        children: children,
        edges: edges,
        layoutOptions: [
            "elk.algorithm": "layered",
            "elk.direction": directionStr,
            "elk.spacing.nodeNode": String(ns),
            "elk.layered.spacing.nodeNodeBetweenLayers": String(ls),
            "elk.padding": "[top=\(pad),left=\(pad),bottom=\(pad),right=\(pad)]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.edgeLabels.placement": "CENTER"
        ]
    )

    return (elkGraph, nodeSizes)
}

private func _extractReqLayout(
    _ result: ElkGraphNode,
    _ diagram: RequirementDiagram,
    _ nodeSizes: NodeSizeMap,
    _ config: RequirementDiagramConfig
) -> PositionedRequirementDiagram {
    let reqLookup = Dictionary(diagram.requirements.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    let elLookup = Dictionary(diagram.elements.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

    var allColorIndex: [String: Int] = [:]
    for (idx, req) in diagram.requirements.enumerated() { allColorIndex[req.name] = idx }
    for (idx, el) in diagram.elements.enumerated() { allColorIndex[el.name] = diagram.requirements.count + idx }

    var positionedNodes: [PositionedRequirementNode] = []
    for child in result.children {
        let fallback = nodeSizes[child.id] ?? (RQL.minWidth, RQL.minHeight)
        let cw = child.width != 0 ? child.width : fallback.width
        let ch = child.height != 0 ? child.height : fallback.height
        let cx = child.x
        let cy = child.y

        if let req = reqLookup[child.id] {
            positionedNodes.append(PositionedRequirementNode(
                id: child.id,
                isRequirement: true,
                requirementType: req.type,
                requirementId: req.requirementId.isEmpty ? nil : req.requirementId,
                text: req.text.isEmpty ? nil : req.text,
                risk: req.risk,
                verifyMethod: req.verifyMethod,
                elementType: nil,
                docRef: nil,
                cssStyles: req.cssStyles,
                classes: req.classes,
                x: cx, y: cy,
                width: cw, height: ch,
                colorIndex: allColorIndex[child.id] ?? 0
            ))
        } else if let el = elLookup[child.id] {
            positionedNodes.append(PositionedRequirementNode(
                id: child.id,
                isRequirement: false,
                requirementType: nil,
                requirementId: nil,
                text: nil,
                risk: nil,
                verifyMethod: nil,
                elementType: el.type.isEmpty ? nil : el.type,
                docRef: el.docRef.isEmpty ? nil : el.docRef,
                cssStyles: el.cssStyles,
                classes: el.classes,
                x: cx, y: cy,
                width: cw, height: ch,
                colorIndex: allColorIndex[child.id] ?? 0
            ))
        }
    }

    var edges: [PositionedRequirementEdge] = []
    for (idx, elkEdge) in result.edges.enumerated() {
        guard idx < diagram.relationships.count else { continue }
        let rel = diagram.relationships[idx]
        var path: [CGPoint] = []
        if let section = elkEdge.sections.first {
            path.append(CGPoint(x: section.startPoint.x, y: section.startPoint.y))
            for bp in section.bendPoints {
                path.append(CGPoint(x: bp.x, y: bp.y))
            }
            path.append(CGPoint(x: section.endPoint.x, y: section.endPoint.y))
        }
        let labelText = "<<\(rel.type.rawValue)>>"
        let isDashed = rel.type != .contains
        let startMarker = rel.type == .contains ? "requirement_contains" : nil
        let endMarker = rel.type != .contains ? "requirement_arrow" : nil

        // Compute label midpoint
        let labelPosition: CGPoint? = {
            if let label = elkEdge.labels.first, label.x != 0 || label.y != 0 {
                return CGPoint(x: label.x, y: label.y)
            }
            if path.count >= 2 {
                // Midpoint of path
                var totalLen: CGFloat = 0
                for i in 1..<path.count {
                    let dx = path[i].x - path[i-1].x
                    let dy = path[i].y - path[i-1].y
                    totalLen += sqrt(dx*dx + dy*dy)
                }
                if totalLen > 0 {
                    let half = totalLen / 2
                    var walked: CGFloat = 0
                    for i in 1..<path.count {
                        let dx = path[i].x - path[i-1].x
                        let dy = path[i].y - path[i-1].y
                        let segLen = sqrt(dx*dx + dy*dy)
                        if walked + segLen >= half {
                            let t = segLen > 0 ? (half - walked) / segLen : 0
                            return CGPoint(x: path[i-1].x + dx * t, y: path[i-1].y + dy * t)
                        }
                        walked += segLen
                    }
                }
                return path[path.count / 2]
            }
            return nil
        }()

        edges.append(PositionedRequirementEdge(
            id: elkEdge.id,
            relationshipType: rel.type,
            sourceId: rel.sourceName,
            destinationId: rel.destinationName,
            path: path,
            labelPosition: labelPosition,
            labelText: labelText,
            isDashed: isDashed,
            startMarker: startMarker,
            endMarker: endMarker
        ))
    }

    return PositionedRequirementDiagram(
        width: result.width != 0 ? result.width : 800,
        height: result.height != 0 ? result.height : 600,
        nodes: positionedNodes,
        edges: edges,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: config
    )
}

// ELK bridge: typed ElkGraphNode is converted to dict only at the
// layoutEngineSync(...) call boundary; the laidOut dict is parsed back via
// ElkGraphNode(from:). Encoder/decoder helpers removed in Phase 1.

public func layoutRequirementDiagram(
    _ diagram: RequirementDiagram,
    options: RenderOptions = RenderOptions()
) throws -> PositionedRequirementDiagram {
    if diagram.requirements.isEmpty && diagram.elements.isEmpty {
        return PositionedRequirementDiagram(
            width: 0, height: 0, nodes: [], edges: [],
            diagramTitle: diagram.diagramTitle,
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr,
            config: diagram.config
        )
    }
    let built = _buildReqElkGraph(diagram, options)
    let rawResult = try layoutEngineSync(built.elkGraph.toDictionary())
    let result = ElkGraphNode(from: rawResult)
    return _extractReqLayout(result, diagram, built.nodeSizes, diagram.config)
}
