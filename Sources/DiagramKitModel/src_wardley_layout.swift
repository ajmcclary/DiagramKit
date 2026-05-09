import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

private func projectX(_ value: Double, padding: Double, chartWidth: Double) -> Double {
    padding + (value / 100.0) * chartWidth
}

private func projectY(_ value: Double, height: Double, padding: Double, chartHeight: Double) -> Double {
    height - padding - (value / 100.0) * chartHeight
}

public func layoutWardleyMap(_ diagram: WardleyMapDiagram) -> PositionedWardleyMapDiagram {
    let config = diagram.config
    let width = diagram.size?.width ?? config.width
    let height = diagram.size?.height ?? config.height
    let padding = config.padding
    let chartWidth = width - 2 * padding
    let chartHeight = height - 2 * padding
    let nodeRadius = config.nodeRadius

    // Build node lookup by ID for coordinate resolution
    var nodeMap: [String: WardleyNode] = [:]
    for node in diagram.nodes {
        nodeMap[node.id] = node
    }

    // Resolve link endpoint IDs
    func resolveNodeId(_ name: String) -> String {
        if nodeMap[name] != nil { return name }
        if let match = diagram.nodes.first(where: { $0.label == name }) {
            return match.id
        }
        return name
    }

    // Project all nodes to pixel positions
    var positionedNodes: [PositionedWardleyNode] = []
    var nodePositions: [String: (x: Double, y: Double)] = [:]

    for node in diagram.nodes {
        let px = projectX(node.x, padding: padding, chartWidth: chartWidth)
        let py = projectY(node.y, height: height, padding: padding, chartHeight: chartHeight)
        let pn = PositionedWardleyNode(
            id: node.id,
            label: node.label,
            x: px,
            y: py,
            className: node.className,
            labelOffsetX: node.labelOffsetX,
            labelOffsetY: node.labelOffsetY,
            inPipeline: node.inPipeline,
            isPipelineParent: node.isPipelineParent,
            inertia: node.inertia,
            sourceStrategy: node.sourceStrategy
        )
        positionedNodes.append(pn)
        nodePositions[node.id] = (x: px, y: py)
    }

    // Compute pipeline boxes
    var pipelineBoxes: [PositionedWardleyPipelineBox] = []
    for pipeline in diagram.pipelines {
        let pipelineChildren = positionedNodes.filter { $0.inPipeline && pipeline.componentIds.contains($0.id) }
        guard !pipelineChildren.isEmpty else { continue }

        let sortedChildren = pipelineChildren.sorted { $0.x < $1.x }

        // Box padding
        let boxPadding: Double = 16
        let minX = (sortedChildren.first?.x ?? 0) - boxPadding
        let maxX = (sortedChildren.last?.x ?? 0) + boxPadding
        let childY = sortedChildren.first?.y ?? 0
        let boxHeight: Double = 100

        let boxX = minX
        let boxY = childY - boxHeight / 2
        let boxW = maxX - minX
        let boxH = boxHeight

        // Parent square repositioned: 2/3 above box, 1/3 inside
        let parentX = boxX + boxW / 2
        let parentY = boxY - (nodeRadius * 1.6) / 3

        // Update parent position in positioned nodes
        if let parentIdx = positionedNodes.firstIndex(where: { $0.id == pipeline.nodeId && $0.isPipelineParent }) {
            positionedNodes[parentIdx] = PositionedWardleyNode(
                id: positionedNodes[parentIdx].id,
                label: positionedNodes[parentIdx].label,
                x: parentX,
                y: parentY,
                className: positionedNodes[parentIdx].className,
                labelOffsetX: positionedNodes[parentIdx].labelOffsetX,
                labelOffsetY: positionedNodes[parentIdx].labelOffsetY,
                inPipeline: positionedNodes[parentIdx].inPipeline,
                isPipelineParent: true,
                inertia: positionedNodes[parentIdx].inertia,
                sourceStrategy: positionedNodes[parentIdx].sourceStrategy
            )
        }
        // Update position in nodePositions for the parent
        nodePositions[pipeline.nodeId] = (x: parentX, y: parentY)

        // Compute child links (dotted links between consecutive children)
        var childLinks: [PositionedWardleyPipelineChildLink] = []
        for j in 0..<(sortedChildren.count - 1) {
            let from = sortedChildren[j]
            let to = sortedChildren[j + 1]
            childLinks.append(PositionedWardleyPipelineChildLink(
                fromId: from.id,
                toId: to.id,
                x1: from.x,
                y1: from.y,
                x2: to.x,
                y2: to.y
            ))
        }

        pipelineBoxes.append(PositionedWardleyPipelineBox(
            nodeId: pipeline.nodeId,
            x: boxX,
            y: boxY,
            width: boxW,
            height: boxH,
            parentX: parentX,
            parentY: parentY,
            childLinks: childLinks
        ))
    }

    // Filter and position links after pipeline parent repositioning.
    var validLinks: [PositionedWardleyLink] = []
    for link in diagram.links {
        let resolvedSource = resolveNodeId(link.source)
        let resolvedTarget = resolveNodeId(link.target)

        guard let sourcePos = nodePositions[resolvedSource],
              let targetPos = nodePositions[resolvedTarget] else {
            continue
        }

        let isChildToParent = diagram.pipelines.contains { pipeline in
            let childIds = pipeline.componentIds
            return (childIds.contains(resolvedSource) && resolvedTarget == pipeline.nodeId) ||
                   (childIds.contains(resolvedTarget) && resolvedSource == pipeline.nodeId)
        }
        if isChildToParent { continue }

        let sourceNode = nodeMap[resolvedSource]
        let targetNode = nodeMap[resolvedTarget]

        var sourceX = sourcePos.x
        var sourceY = sourcePos.y
        var targetX = targetPos.x
        var targetY = targetPos.y

        let sxRadius = sourceNode?.isPipelineParent == true ? (nodeRadius * 1.6) / sqrt(2) : nodeRadius
        let txRadius = targetNode?.isPipelineParent == true ? (nodeRadius * 1.6) / sqrt(2) : nodeRadius

        let dx = targetX - sourceX
        let dy = targetY - sourceY
        let dist = max(sqrt(dx * dx + dy * dy), 1.0)

        sourceX += (dx / dist) * sxRadius
        sourceY += (dy / dist) * sxRadius
        targetX -= (dx / dist) * txRadius
        targetY -= (dy / dist) * txRadius

        let midX = (sourceX + targetX) / 2
        let midY = (sourceY + targetY) / 2
        let angle = atan2(dy, dx) * 180.0 / .pi
        let perpDx = -dy / dist * 8
        let perpDy = dx / dist * 8
        let labelX = midX + perpDx
        let labelY = midY + perpDy

        validLinks.append(PositionedWardleyLink(
            source: link.source,
            target: link.target,
            dashed: link.dashed,
            label: link.label,
            flow: link.flow,
            sourceX: sourceX,
            sourceY: sourceY,
            targetX: targetX,
            targetY: targetY,
            labelX: link.label != nil ? labelX : nil,
            labelY: link.label != nil ? labelY : nil,
            labelAngle: link.label != nil ? angle : nil
        ))
    }

    // Compute trend endpoints after pipeline parent repositioning.
    var positionedTrends: [PositionedWardleyTrend] = []
    for trend in diagram.trends {
        let resolvedNode = resolveNodeId(trend.nodeId)
        guard let nodePos = nodePositions[resolvedNode] else { continue }
        let targetPX = projectX(trend.targetX, padding: padding, chartWidth: chartWidth)
        let targetPY = nodePos.y

        let dx = targetPX - nodePos.x
        let dy = targetPY - nodePos.y
        let dist = max(sqrt(dx * dx + dy * dy), 1.0)

        let shortenedX = targetPX - (dx / dist) * (nodeRadius + 2)
        let shortenedY = targetPY - (dy / dist) * (nodeRadius + 2)

        positionedTrends.append(PositionedWardleyTrend(
            nodeId: trend.nodeId,
            originX: nodePos.x,
            originY: nodePos.y,
            targetX: shortenedX,
            targetY: shortenedY
        ))
    }

    // Compute annotation points
    var annotationPoints: [PositionedWardleyAnnotationPoint] = []
    for annotation in diagram.annotations {
        var points: [(x: Double, y: Double)] = []
        for coord in annotation.coordinates {
            let px = projectX(coord.x, padding: padding, chartWidth: chartWidth)
            let py = projectY(coord.y, height: height, padding: padding, chartHeight: chartHeight)
            points.append((x: px, y: py))
        }

        var connectingLines: [(x1: Double, y1: Double, x2: Double, y2: Double)] = []
        for i in 1..<points.count {
            connectingLines.append((x1: points[i - 1].x, y1: points[i - 1].y, x2: points[i].x, y2: points[i].y))
        }

        if let first = points.first {
            annotationPoints.append(PositionedWardleyAnnotationPoint(
                number: annotation.number,
                x: first.x,
                y: first.y,
                connectingLines: connectingLines
            ))
        }
    }

    // Compute annotation box
    var positionedAnnotationBox: PositionedWardleyAnnotationBox?
    if let box = diagram.annotationsBox {
        let sorted = annotationPoints.sorted { $0.number < $1.number }
        var entries: [PositionedWardleyAnnotationBoxEntry] = []
        let lineHeight: Double = 16
        let boxPadding: Double = 8

        let bx = projectX(box.x, padding: padding, chartWidth: chartWidth)
        let by = projectY(box.y, height: height, padding: padding, chartHeight: chartHeight)

        for (i, point) in sorted.enumerated() {
            if let annotation = diagram.annotations.first(where: { $0.number == point.number }),
               let text = annotation.text {
                entries.append(PositionedWardleyAnnotationBoxEntry(
                    number: point.number,
                    text: "\(point.number). \(text)",
                    x: bx + boxPadding,
                    y: by + boxPadding + Double(i) * lineHeight
                ))
            }
        }

        let boxWidth: Double = 200
        let boxHeight = Double(entries.count) * lineHeight + boxPadding * 2

        let clampedX = min(max(bx, padding), width - padding - boxWidth)
        let clampedY = min(max(by, padding), height - padding - boxHeight)

        positionedAnnotationBox = PositionedWardleyAnnotationBox(
            x: clampedX,
            y: clampedY,
            width: boxWidth,
            height: boxHeight,
            entries: entries
        )
    }

    // Compute positioned notes
    let positionedNotes: [PositionedWardleyNote] = diagram.notes.map { note in
        PositionedWardleyNote(
            text: note.text,
            x: projectX(note.x, padding: padding, chartWidth: chartWidth),
            y: projectY(note.y, height: height, padding: padding, chartHeight: chartHeight)
        )
    }

    // Compute positioned accelerators
    let positionedAccelerators: [PositionedWardleyAccelerator] = diagram.accelerators.map { acc in
        PositionedWardleyAccelerator(
            name: acc.name,
            x: projectX(acc.x, padding: padding, chartWidth: chartWidth),
            y: projectY(acc.y, height: height, padding: padding, chartHeight: chartHeight)
        )
    }

    // Compute positioned deaccelerators
    let positionedDeaccelerators: [PositionedWardleyDeaccelerator] = diagram.deaccelerators.map { dec in
        PositionedWardleyDeaccelerator(
            name: dec.name,
            x: projectX(dec.x, padding: padding, chartWidth: chartWidth),
            y: projectY(dec.y, height: height, padding: padding, chartHeight: chartHeight)
        )
    }

    // Compute stage positions
    let stages = diagram.axes.stages ?? ["Genesis", "Custom Built", "Product", "Commodity"]
    let boundaries = diagram.axes.stageBoundaries
    var positionedStages: [PositionedWardleyStage] = []

    let stageLineLabelY = height - padding / 2

    if let boundaries = boundaries, boundaries.count == stages.count {
        // Custom boundaries as 0-1 ratios
        var prevBoundary: Double = 0
        for i in 0..<stages.count {
            let boundary = boundaries[i]
            let startX = projectX(prevBoundary * 100, padding: padding, chartWidth: chartWidth)
            let endX = projectX(boundary * 100, padding: padding, chartWidth: chartWidth)
            positionedStages.append(PositionedWardleyStage(
                name: stages[i],
                startX: startX,
                endX: endX,
                centerX: (startX + endX) / 2,
                labelY: stageLineLabelY
            ))
            prevBoundary = boundary
        }
    } else {
        // Equal distribution across chartWidth
        let stageWidth = chartWidth / Double(stages.count)
        for i in 0..<stages.count {
            let startX = padding + Double(i) * stageWidth
            let endX = startX + stageWidth
            positionedStages.append(PositionedWardleyStage(
                name: stages[i],
                startX: startX,
                endX: endX,
                centerX: (startX + endX) / 2,
                labelY: stageLineLabelY
            ))
        }
    }

    // Compute grid lines
    var gridLines: [(x1: Double, y1: Double, x2: Double, y2: Double)] = []
    if config.showGrid {
        for pct in [25.0, 50.0, 75.0] {
            let gx = projectX(pct, padding: padding, chartWidth: chartWidth)
            gridLines.append((x1: gx, y1: height - padding, x2: gx, y2: padding))
            let gy = projectY(pct, height: height, padding: padding, chartHeight: chartHeight)
            gridLines.append((x1: padding, y1: gy, x2: width - padding, y2: gy))
        }
    }

    return PositionedWardleyMapDiagram(
        width: width,
        height: height,
        padding: padding,
        nodes: positionedNodes,
        validLinks: validLinks,
        trends: positionedTrends,
        pipelineBoxes: pipelineBoxes,
        annotationPoints: annotationPoints,
        annotationBox: positionedAnnotationBox,
        notes: positionedNotes,
        accelerators: positionedAccelerators,
        deaccelerators: positionedDeaccelerators,
        stages: positionedStages,
        axes: diagram.axes,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: config,
        theme: diagram.theme,
        showGrid: config.showGrid,
        gridLines: gridLines
    )
}
