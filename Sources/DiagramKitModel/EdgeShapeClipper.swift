import Foundation

// MARK: - Edge Shape Clipper

/// Clips edge endpoints to actual shape boundaries instead of bounding boxes.
/// Extracted from `src_layout.swift` to isolate the shape-aware clipping logic.

public func _clipEdgeToShape(
    points: [_PositionedPointPayload],
    node: _PositionedNodePayload,
    isStart: Bool
) -> [_PositionedPointPayload] {
    guard points.count >= 2 else { return points }

    let shape = node.shape
    // Rectangular shapes: bounding box is already correct
    if shape == "rectangle" || shape == "rounded" || shape == "stadium" ||
       shape == "subroutine" || shape == "state-start" || shape == "state-end" ||
       shape == "fork" || shape == "join" {
        return points
    }

    var result = points
    let cx = node.x + node.width / 2
    let cy = node.y + node.height / 2
    let halfW = node.width / 2
    let halfH = node.height / 2

    if isStart {
        let endpoint = points[0]
        let adjacent = points[1]
        if let clipped = _clipPoint(endpoint: endpoint, adjacent: adjacent, shape: shape, cx: cx, cy: cy, halfW: halfW, halfH: halfH) {
            result[0] = clipped
        }
    } else {
        let lastIdx = points.count - 1
        let endpoint = points[lastIdx]
        let adjacent = points[lastIdx - 1]
        if let clipped = _clipPoint(endpoint: endpoint, adjacent: adjacent, shape: shape, cx: cx, cy: cy, halfW: halfW, halfH: halfH) {
            result[lastIdx] = clipped
        }
    }

    return result
}

public func _clipPoint(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    shape: String,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    switch shape {
    case "diamond", "rhombus", "choice":
        return _clipToDiamond(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    case "circle", "doublecircle", "double-circle":
        return _clipToCircle(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    case "hexagon":
        return _clipToHexagon(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    default:
        return _clipToEllipseApprox(endpoint: endpoint, adjacent: adjacent, cx: cx, cy: cy, halfW: halfW, halfH: halfH)
    }
}

public func _clipToDiamond(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    let top    = (x: cx,        y: cy - halfH)
    let right  = (x: cx + halfW, y: cy)
    let bottom = (x: cx,        y: cy + halfH)
    let left   = (x: cx - halfW, y: cy)

    let dx = endpoint.x - adjacent.x
    let dy = endpoint.y - adjacent.y
    let isVertical = abs(dx) < abs(dy)

    if isVertical {
        let rayX = endpoint.x
        if dy > 0 {
            if rayX <= cx {
                return _intersectVerticalRay(rayX: rayX, p1x: left.x, p1y: left.y, p2x: top.x, p2y: top.y)
            } else {
                return _intersectVerticalRay(rayX: rayX, p1x: top.x, p1y: top.y, p2x: right.x, p2y: right.y)
            }
        } else {
            if rayX <= cx {
                return _intersectVerticalRay(rayX: rayX, p1x: bottom.x, p1y: bottom.y, p2x: left.x, p2y: left.y)
            } else {
                return _intersectVerticalRay(rayX: rayX, p1x: right.x, p1y: right.y, p2x: bottom.x, p2y: bottom.y)
            }
        }
    } else {
        let rayY = endpoint.y
        if dx > 0 {
            if rayY <= cy {
                return _intersectHorizontalRay(rayY: rayY, p1x: top.x, p1y: top.y, p2x: left.x, p2y: left.y)
            } else {
                return _intersectHorizontalRay(rayY: rayY, p1x: left.x, p1y: left.y, p2x: bottom.x, p2y: bottom.y)
            }
        } else {
            if rayY <= cy {
                return _intersectHorizontalRay(rayY: rayY, p1x: top.x, p1y: top.y, p2x: right.x, p2y: right.y)
            } else {
                return _intersectHorizontalRay(rayY: rayY, p1x: right.x, p1y: right.y, p2x: bottom.x, p2y: bottom.y)
            }
        }
    }
}

public func _clipToCircle(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    let radius = min(halfW, halfH)
    let dx = endpoint.x - cx
    let dy = endpoint.y - cy
    let dist = sqrt(dx * dx + dy * dy)
    guard dist > 0.001 else { return nil }
    let scale = radius / dist
    return _PositionedPointPayload(x: cx + dx * scale, y: cy + dy * scale)
}

public func _clipToHexagon(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    let inset = halfW * 0.25
    let vertices: [(x: Double, y: Double)] = [
        (cx - halfW, cy),
        (cx - halfW + inset, cy - halfH),
        (cx + halfW - inset, cy - halfH),
        (cx + halfW, cy),
        (cx + halfW - inset, cy + halfH),
        (cx - halfW + inset, cy + halfH),
    ]
    return _clipToPolygon(endpoint: endpoint, adjacent: adjacent, vertices: vertices)
}

public func _clipToEllipseApprox(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    cx: Double, cy: Double,
    halfW: Double, halfH: Double
) -> _PositionedPointPayload? {
    let dx = endpoint.x - cx
    let dy = endpoint.y - cy
    guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return nil }
    let normX = dx / halfW
    let normY = dy / halfH
    let dist = sqrt(normX * normX + normY * normY)
    guard dist > 0.001 else { return nil }
    let scale = 1.0 / dist
    return _PositionedPointPayload(x: cx + dx * scale, y: cy + dy * scale)
}

public func _clipToPolygon(
    endpoint: _PositionedPointPayload,
    adjacent: _PositionedPointPayload,
    vertices: [(x: Double, y: Double)]
) -> _PositionedPointPayload? {
    let n = vertices.count
    guard n >= 3 else { return nil }

    let ox = adjacent.x, oy = adjacent.y
    let dx = endpoint.x - adjacent.x, dy = endpoint.y - adjacent.y

    var bestT = Double.infinity
    var bestPoint: _PositionedPointPayload?

    for i in 0..<n {
        let j = (i + 1) % n
        let ex = vertices[j].x - vertices[i].x
        let ey = vertices[j].y - vertices[i].y

        let denom = dx * ey - dy * ex
        guard abs(denom) > 0.0001 else { continue }

        let t = ((vertices[i].x - ox) * ey - (vertices[i].y - oy) * ex) / denom
        let u = ((vertices[i].x - ox) * dy - (vertices[i].y - oy) * dx) / denom

        if t > 0 && u >= 0 && u <= 1 && t < bestT {
            bestT = t
            bestPoint = _PositionedPointPayload(x: ox + dx * t, y: oy + dy * t)
        }
    }

    return bestPoint
}

public func _intersectVerticalRay(
    rayX: Double, p1x: Double, p1y: Double, p2x: Double, p2y: Double
) -> _PositionedPointPayload? {
    let dx = p2x - p1x
    guard abs(dx) > 0.001 else { return nil }
    let t = (rayX - p1x) / dx
    guard t >= 0 && t <= 1 else { return nil }
    return _PositionedPointPayload(x: rayX, y: p1y + t * (p2y - p1y))
}

public func _intersectHorizontalRay(
    rayY: Double, p1x: Double, p1y: Double, p2x: Double, p2y: Double
) -> _PositionedPointPayload? {
    let dy = p2y - p1y
    guard abs(dy) > 0.001 else { return nil }
    let t = (rayY - p1y) / dy
    guard t >= 0 && t <= 1 else { return nil }
    return _PositionedPointPayload(x: p1x + t * (p2x - p1x), y: rayY)
}
