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

private struct _RElkLabel {
    var text: String
    var width: Double
    var height: Double
    var x: Double?
    var y: Double?
}

private struct _RElkPoint {
    var x: Double
    var y: Double
}

private struct _RElkSection {
    var startPoint: _RElkPoint
    var endPoint: _RElkPoint
    var bendPoints: [_RElkPoint]?
}

private struct _RElkEdge {
    var id: String
    var sources: [String]
    var targets: [String]
    var labels: [_RElkLabel]?
    var sections: [_RElkSection]?
}

private struct _RElkNode {
    var id: String
    var width: Double?
    var height: Double?
    var x: Double?
    var y: Double?
    var layoutOptions: [String: String]?
    var children: [_RElkNode]?
    var edges: [_RElkEdge]?
}

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
) -> (elkGraph: _RElkNode, nodeSizes: NodeSizeMap) {
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

    var children: [_RElkNode] = []
    for node in allNodes {
        let size = nodeSizes[node.id] ?? (RQL.minWidth, RQL.minHeight)
        children.append(_RElkNode(
            id: node.id,
            width: size.width,
            height: size.height,
            x: nil, y: nil,
            layoutOptions: nil,
            children: nil,
            edges: nil
        ))
    }

    var edges: [_RElkEdge] = []
    for (idx, rel) in diagram.relationships.enumerated() {
        let edgeId = "\(rel.sourceName)-\(rel.destinationName)-\(idx)"
        let labelText = "<<\(rel.type.rawValue)>>"
        let metrics = original_src_text_metrics.measureMultilineText(
            labelText,
            fontSize: original_src_styles.FONT_SIZES.edgeLabel,
            fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
        )
        let edge = _RElkEdge(
            id: edgeId,
            sources: [rel.sourceName],
            targets: [rel.destinationName],
            labels: [
                _RElkLabel(text: labelText, width: metrics.width + 8, height: metrics.height + 6, x: nil, y: nil)
            ],
            sections: nil
        )
        edges.append(edge)
    }

    let directionStr = _reqMapDirection(diagram.direction)
    let ns = diagram.config.nodeSpacing
    let ls = diagram.config.rankSpacing
    let pad = RQL.padding

    let elkGraph = _RElkNode(
        id: "root",
        width: nil, height: nil, x: nil, y: nil,
        layoutOptions: [
            "elk.algorithm": "layered",
            "elk.direction": directionStr,
            "elk.spacing.nodeNode": String(ns),
            "elk.layered.spacing.nodeNodeBetweenLayers": String(ls),
            "elk.padding": "[top=\(pad),left=\(pad),bottom=\(pad),right=\(pad)]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.edgeLabels.placement": "CENTER",
        ],
        children: children,
        edges: edges
    )

    return (elkGraph, nodeSizes)
}

private func _extractReqLayout(
    _ result: _RElkNode,
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
    for child in result.children ?? [] {
        let fallback = nodeSizes[child.id] ?? (RQL.minWidth, RQL.minHeight)
        let cw = child.width ?? fallback.width
        let ch = child.height ?? fallback.height
        let cx = child.x ?? 0
        let cy = child.y ?? 0

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
    let resultEdges = result.edges ?? []
    for (idx, elkEdge) in resultEdges.enumerated() {
        guard idx < diagram.relationships.count else { continue }
        let rel = diagram.relationships[idx]
        var path: [CGPoint] = []
        if let section = elkEdge.sections?.first {
            path.append(CGPoint(x: section.startPoint.x, y: section.startPoint.y))
            for bp in section.bendPoints ?? [] {
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
            if let label = elkEdge.labels?.first, let lx = label.x, let ly = label.y {
                return CGPoint(x: lx, y: ly)
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
        width: result.width ?? 800,
        height: result.height ?? 600,
        nodes: positionedNodes,
        edges: edges,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: config
    )
}

// MARK: - ELK bridge (same pattern as ER layout)

private func _anyToDouble(_ value: Any?) -> Double? {
    if let d = value as? Double { return d }
    if let i = value as? Int { return Double(i) }
    if let f = value as? Float { return Double(f) }
    if let n = value as? NSNumber { return n.doubleValue }
    return nil
}

private func _decodeRElkPoint(_ any: Any?) -> _RElkPoint? {
    guard let point = any as? [String: Any],
          let x = _anyToDouble(point["x"]),
          let y = _anyToDouble(point["y"]) else { return nil }
    return _RElkPoint(x: x, y: y)
}

private func _encodeRElkPoint(_ point: _RElkPoint) -> [String: Any] {
    ["x": point.x, "y": point.y]
}

private func _decodeRElkLabel(_ any: Any?) -> _RElkLabel? {
    guard let label = any as? [String: Any],
          let text = label["text"] as? String,
          let width = _anyToDouble(label["width"]),
          let height = _anyToDouble(label["height"]) else { return nil }
    return _RElkLabel(text: text, width: width, height: height, x: _anyToDouble(label["x"]), y: _anyToDouble(label["y"]))
}

private func _encodeRElkLabel(_ label: _RElkLabel) -> [String: Any] {
    var out: [String: Any] = ["text": label.text, "width": label.width, "height": label.height]
    if let x = label.x { out["x"] = x }
    if let y = label.y { out["y"] = y }
    return out
}

private func _decodeRElkSection(_ any: Any?) -> _RElkSection? {
    guard let section = any as? [String: Any],
          let startPoint = _decodeRElkPoint(section["startPoint"]),
          let endPoint = _decodeRElkPoint(section["endPoint"]) else { return nil }
    let bendPoints = (section["bendPoints"] as? [Any])?.compactMap { _decodeRElkPoint($0) }
    return _RElkSection(startPoint: startPoint, endPoint: endPoint, bendPoints: bendPoints)
}

private func _encodeRElkSection(_ section: _RElkSection) -> [String: Any] {
    var out: [String: Any] = ["startPoint": _encodeRElkPoint(section.startPoint), "endPoint": _encodeRElkPoint(section.endPoint)]
    if let bendPoints = section.bendPoints {
        out["bendPoints"] = bendPoints.map(_encodeRElkPoint)
    }
    return out
}

private func _decodeRElkEdge(_ any: Any?) -> _RElkEdge? {
    guard let edge = any as? [String: Any],
          let id = edge["id"] as? String,
          let sources = edge["sources"] as? [String],
          let targets = edge["targets"] as? [String] else { return nil }
    let labels = (edge["labels"] as? [Any])?.compactMap { _decodeRElkLabel($0) }
    let sections = (edge["sections"] as? [Any])?.compactMap { _decodeRElkSection($0) }
    return _RElkEdge(id: id, sources: sources, targets: targets, labels: labels, sections: sections)
}

private func _encodeRElkEdge(_ edge: _RElkEdge) -> [String: Any] {
    var out: [String: Any] = ["id": edge.id, "sources": edge.sources, "targets": edge.targets]
    if let labels = edge.labels { out["labels"] = labels.map(_encodeRElkLabel) }
    if let sections = edge.sections { out["sections"] = sections.map(_encodeRElkSection) }
    return out
}

private func _decodeRElkNode(_ any: Any?) -> _RElkNode? {
    guard let node = any as? [String: Any],
          let id = node["id"] as? String else { return nil }
    let children = (node["children"] as? [Any])?.compactMap { _decodeRElkNode($0) }
    let edges = (node["edges"] as? [Any])?.compactMap { _decodeRElkEdge($0) }
    return _RElkNode(id: id, width: _anyToDouble(node["width"]), height: _anyToDouble(node["height"]),
                     x: _anyToDouble(node["x"]), y: _anyToDouble(node["y"]),
                     layoutOptions: node["layoutOptions"] as? [String: String],
                     children: children, edges: edges)
}

private func _encodeRElkNode(_ node: _RElkNode) -> LayoutNode {
    var out: LayoutNode = ["id": node.id]
    if let w = node.width { out["width"] = w }
    if let h = node.height { out["height"] = h }
    if let x = node.x { out["x"] = x }
    if let y = node.y { out["y"] = y }
    if let lo = node.layoutOptions { out["layoutOptions"] = lo }
    if let children = node.children { out["children"] = children.map(_encodeRElkNode) }
    if let edges = node.edges { out["edges"] = edges.map(_encodeRElkEdge) }
    return out
}

private func _layoutEngineSync(_ graph: _RElkNode) throws -> _RElkNode {
    let laidOut = try layoutEngineSync(_encodeRElkNode(graph))
    return _decodeRElkNode(laidOut) ?? graph
}

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
    let result = try _layoutEngineSync(built.elkGraph)
    return _extractReqLayout(result, diagram, built.nodeSizes, diagram.config)
}
