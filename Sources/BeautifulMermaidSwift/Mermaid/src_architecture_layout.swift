import Foundation

public func layoutArchitectureDiagram(_ diagram: ArchitectureDiagram) -> PositionedArchitectureDiagram {
    let config = diagram.config
    let iconSize = config.iconSize
    let padding = config.padding
    let fontSize = config.fontSize
    let gap = iconSize * 1.5

    guard !diagram.services.isEmpty || !diagram.junctions.isEmpty else {
        return PositionedArchitectureDiagram(
            width: 0,
            height: 0,
            config: config,
            theme: diagram.theme
        )
    }

    var services: [PositionedArchitectureService] = []
    var junctions: [PositionedArchitectureJunction] = []
    var positionedEdges: [PositionedArchitectureEdge] = []

    let nodeSize = iconSize + fontSize + 8

    let allNodeIds = diagram.services.map(\.id) + diagram.junctions.map(\.id)
    let spatialMaps = _buildSpatialMaps(nodeIds: allNodeIds, edges: diagram.edges)
    var nodePositions: [String: (x: Double, y: Double)] = [:]
    var currentY: Double = padding

    for map in spatialMaps {
        let items = allNodeIds.filter { map[$0] != nil }
        guard !items.isEmpty else { continue }

        let xs = map.values.map(\.x)
        let ys = map.values.map(\.y)
        let minX = xs.min() ?? 0
        let maxY = ys.max() ?? 0
        let minY = ys.min() ?? 0
        let rows = max(1, maxY - minY + 1)
        let cell = nodeSize + gap

        for itemId in items {
            guard let grid = map[itemId] else { continue }
            let x = padding + Double(grid.x - minX) * cell + nodeSize / 2
            let y = currentY + Double(maxY - grid.y) * cell + nodeSize / 2
            nodePositions[itemId] = (x: x, y: y)
        }

        currentY += Double(rows) * cell + gap
    }

    for nodeId in allNodeIds {
        if nodePositions[nodeId] == nil {
            nodePositions[nodeId] = (x: 0, y: 0)
        }
    }

    for service in diagram.services {
        let pos = nodePositions[service.id] ?? (x: 0, y: 0)
        services.append(PositionedArchitectureService(
            id: service.id,
            icon: service.icon,
            iconText: service.iconText,
            title: service.title,
            parentGroupId: service.parentGroupId,
            x: pos.x,
            y: pos.y,
            width: nodeSize,
            height: nodeSize
        ))
    }

    for junction in diagram.junctions {
        let pos = nodePositions[junction.id] ?? (x: 0, y: 0)
        junctions.append(PositionedArchitectureJunction(
            id: junction.id,
            parentGroupId: junction.parentGroupId,
            x: pos.x,
            y: pos.y,
            width: nodeSize,
            height: nodeSize
        ))
    }

    var edgeIndex = 0
    for edge in diagram.edges {
        let lhsPos = nodePositions[edge.lhsId] ?? (x: 0, y: 0)
        let rhsPos = nodePositions[edge.rhsId] ?? (x: 0, y: 0)

        let halfW = nodeSize / 2
        let (startX, startY) = _portOffset(
            nodeX: lhsPos.x,
            nodeY: lhsPos.y,
            direction: edge.lhsDirection,
            halfSize: halfW,
            hasGroupBoundary: edge.lhsGroupBoundary,
            padding: padding
        )
        let (endX, endY) = _portOffset(
            nodeX: rhsPos.x,
            nodeY: rhsPos.y,
            direction: edge.rhsDirection,
            halfSize: halfW,
            hasGroupBoundary: edge.rhsGroupBoundary,
            padding: padding
        )

        let isXY = _isXYEdge(lhsDir: edge.lhsDirection, rhsDir: edge.rhsDirection)
        let midX: Double
        let midY: Double
        if isXY {
            if (edge.lhsDirection == .L || edge.lhsDirection == .R) && (edge.rhsDirection == .T || edge.rhsDirection == .B) {
                midX = endX
                midY = startY
            } else {
                midX = startX
                midY = endY
            }
        } else {
            midX = (startX + endX) / 2
            midY = (startY + endY) / 2
        }

        let edgeId = "L_\(edge.lhsId)_\(edge.rhsId)_\(edgeIndex)"
        positionedEdges.append(PositionedArchitectureEdge(
            id: edgeId,
            lhsId: edge.lhsId,
            rhsId: edge.rhsId,
            lhsDirection: edge.lhsDirection,
            rhsDirection: edge.rhsDirection,
            sourceArrow: edge.sourceArrow,
            targetArrow: edge.targetArrow,
            lhsGroupBoundary: edge.lhsGroupBoundary,
            rhsGroupBoundary: edge.rhsGroupBoundary,
            label: edge.label,
            startX: startX,
            startY: startY,
            midX: midX,
            midY: midY,
            endX: endX,
            endY: endY
        ))
        edgeIndex += 1
    }

    let childGroupsByParent = Dictionary(grouping: diagram.groups, by: { $0.parentGroupId ?? "" })
    var groupBoundsCache: [String: _ArchitectureBounds] = [:]

    func groupBounds(for group: ArchitectureGroup) -> _ArchitectureBounds {
        if let cached = groupBoundsCache[group.id] {
            return cached
        }

        var contentBounds: _ArchitectureBounds?
        for service in services where service.parentGroupId == group.id {
            contentBounds = _unionBounds(
                contentBounds,
                _ArchitectureBounds(
                    x: service.x - service.width / 2,
                    y: service.y - service.height / 2,
                    width: service.width,
                    height: service.height
                )
            )
        }
        for junction in junctions where junction.parentGroupId == group.id {
            contentBounds = _unionBounds(
                contentBounds,
                _ArchitectureBounds(
                    x: junction.x - junction.width / 2,
                    y: junction.y - junction.height / 2,
                    width: junction.width,
                    height: junction.height
                )
            )
        }
        for child in childGroupsByParent[group.id] ?? [] {
            contentBounds = _unionBounds(contentBounds, groupBounds(for: child))
        }

        let result: _ArchitectureBounds
        if let bounds = contentBounds {
            result = bounds.insetBy(dx: -padding / 2, dy: -padding / 2)
        } else {
            result = _ArchitectureBounds(x: padding, y: padding, width: nodeSize * 2, height: nodeSize * 2)
        }
        groupBoundsCache[group.id] = result
        return result
    }

    let positionedGroups = diagram.groups.map { group in
        let bounds = groupBounds(for: group)
        return PositionedArchitectureGroup(
            id: group.id,
            icon: group.icon,
            title: group.title,
            parentGroupId: group.parentGroupId,
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height
        )
    }

    var diagramBounds: _ArchitectureBounds?
    for service in services {
        diagramBounds = _unionBounds(diagramBounds, _ArchitectureBounds(
            x: service.x - service.width / 2,
            y: service.y - service.height / 2,
            width: service.width,
            height: service.height
        ))
    }
    for junction in junctions {
        diagramBounds = _unionBounds(diagramBounds, _ArchitectureBounds(
            x: junction.x - junction.width / 2,
            y: junction.y - junction.height / 2,
            width: junction.width,
            height: junction.height
        ))
    }
    for group in positionedGroups {
        diagramBounds = _unionBounds(diagramBounds, _ArchitectureBounds(
            x: group.x,
            y: group.y,
            width: group.width,
            height: group.height
        ))
    }
    for edge in positionedEdges {
        for point in [(edge.startX, edge.startY), (edge.midX, edge.midY), (edge.endX, edge.endY)] {
            diagramBounds = _unionBounds(diagramBounds, _ArchitectureBounds(x: point.0, y: point.1, width: 0, height: 0))
        }
    }

    let maxX = (diagramBounds?.maxX ?? 0) + padding
    let maxY = (diagramBounds?.maxY ?? 0) + padding

    return PositionedArchitectureDiagram(
        width: maxX,
        height: maxY,
        services: services,
        junctions: junctions,
        groups: positionedGroups,
        edges: positionedEdges,
        diagramTitle: diagram.diagramTitle,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        config: config,
        theme: diagram.theme
    )
}

private struct _ArchitectureGridPosition: Hashable {
    var x: Int
    var y: Int
}

private struct _ArchitectureDirectionalNeighbor {
    var id: String
    var delta: _ArchitectureGridPosition
}

private struct _ArchitectureBounds {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var maxX: Double { x + width }
    var maxY: Double { y + height }

    func insetBy(dx: Double, dy: Double) -> _ArchitectureBounds {
        _ArchitectureBounds(
            x: x + dx,
            y: y + dy,
            width: width - 2 * dx,
            height: height - 2 * dy
        )
    }
}

private func _unionBounds(_ lhs: _ArchitectureBounds?, _ rhs: _ArchitectureBounds) -> _ArchitectureBounds {
    guard let lhs else { return rhs }
    let minX = min(lhs.x, rhs.x)
    let minY = min(lhs.y, rhs.y)
    let maxX = max(lhs.maxX, rhs.maxX)
    let maxY = max(lhs.maxY, rhs.maxY)
    return _ArchitectureBounds(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
}

private func _buildSpatialMaps(nodeIds: [String], edges: [ArchitectureEdge]) -> [[String: _ArchitectureGridPosition]] {
    let nodeSet = Set(nodeIds)
    var adjacency: [String: [_ArchitectureDirectionalNeighbor]] = [:]
    for edge in edges {
        guard nodeSet.contains(edge.lhsId), nodeSet.contains(edge.rhsId),
              let delta = _directionDelta(source: edge.lhsDirection, target: edge.rhsDirection)
        else { continue }
        adjacency[edge.lhsId, default: []].append(_ArchitectureDirectionalNeighbor(id: edge.rhsId, delta: delta))
        adjacency[edge.rhsId, default: []].append(_ArchitectureDirectionalNeighbor(
            id: edge.lhsId,
            delta: _ArchitectureGridPosition(x: -delta.x, y: -delta.y)
        ))
    }

    var maps: [[String: _ArchitectureGridPosition]] = []
    var visited: Set<String> = []

    for nodeId in nodeIds where !visited.contains(nodeId) {
        var map: [String: _ArchitectureGridPosition] = [nodeId: _ArchitectureGridPosition(x: 0, y: 0)]
        var occupied: Set<_ArchitectureGridPosition> = [_ArchitectureGridPosition(x: 0, y: 0)]
        var queue = [nodeId]
        visited.insert(nodeId)

        while !queue.isEmpty {
            let current = queue.removeFirst()
            guard let currentPosition = map[current] else { continue }
            for neighbor in adjacency[current] ?? [] where !visited.contains(neighbor.id) {
                let desired = _ArchitectureGridPosition(
                    x: currentPosition.x + neighbor.delta.x,
                    y: currentPosition.y + neighbor.delta.y
                )
                let position = _firstUnoccupiedPosition(startingAt: desired, occupied: occupied)
                map[neighbor.id] = position
                occupied.insert(position)
                visited.insert(neighbor.id)
                queue.append(neighbor.id)
            }
        }

        maps.append(map)
    }

    return maps
}

private func _firstUnoccupiedPosition(
    startingAt desired: _ArchitectureGridPosition,
    occupied: Set<_ArchitectureGridPosition>
) -> _ArchitectureGridPosition {
    guard occupied.contains(desired) else { return desired }
    var candidate = desired
    while occupied.contains(candidate) {
        candidate.x += 1
    }
    return candidate
}

private func _directionDelta(
    source: ArchitectureDirection,
    target: ArchitectureDirection
) -> _ArchitectureGridPosition? {
    if source == target {
        return nil
    }

    switch (source, target) {
    case (.L, .T): return _ArchitectureGridPosition(x: -1, y: 1)
    case (.L, .R): return _ArchitectureGridPosition(x: -1, y: 0)
    case (.L, .B): return _ArchitectureGridPosition(x: -1, y: -1)
    case (.R, .T): return _ArchitectureGridPosition(x: 1, y: 1)
    case (.R, .L): return _ArchitectureGridPosition(x: 1, y: 0)
    case (.R, .B): return _ArchitectureGridPosition(x: 1, y: -1)
    case (.T, .L): return _ArchitectureGridPosition(x: 1, y: 1)
    case (.T, .R): return _ArchitectureGridPosition(x: -1, y: 1)
    case (.T, .B): return _ArchitectureGridPosition(x: 0, y: 1)
    case (.B, .L): return _ArchitectureGridPosition(x: 1, y: -1)
    case (.B, .R): return _ArchitectureGridPosition(x: -1, y: -1)
    case (.B, .T): return _ArchitectureGridPosition(x: 0, y: -1)
    default: return nil
    }
}

private func _portOffset(
    nodeX: Double,
    nodeY: Double,
    direction: ArchitectureDirection,
    halfSize: Double,
    hasGroupBoundary: Bool,
    padding: Double
) -> (Double, Double) {
    let offset = hasGroupBoundary ? (halfSize + padding + 4) : halfSize
    switch direction {
    case .L: return (nodeX - offset, nodeY)
    case .R: return (nodeX + offset, nodeY)
    case .T: return (nodeX, nodeY - offset)
    case .B: return (nodeX, nodeY + offset)
    }
}

private func _isXYEdge(lhsDir: ArchitectureDirection, rhsDir: ArchitectureDirection) -> Bool {
    let h: Set<ArchitectureDirection> = [.L, .R]
    let v: Set<ArchitectureDirection> = [.T, .B]
    return (h.contains(lhsDir) && v.contains(rhsDir)) || (v.contains(lhsDir) && h.contains(rhsDir))
}
