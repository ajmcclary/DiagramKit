import Foundation

// MARK: - Edge Path Midpoint

/// Compute the midpoint along the edge's polyline path.
/// Extracted from `src_layout.swift`.
func _edgePathMidpoint(
    _ points: [_PositionedPointPayload],
    direction: original_src_types.Direction = .TD
) -> _PositionedPointPayload {
    guard points.count >= 2 else {
        return points.first ?? _PositionedPointPayload(x: 0, y: 0)
    }

    // For edges with bends, prefer the longest segment aligned with the flow direction.
    let isVerticalFlow = direction == .TD || direction == .TB || direction == .BT

    if points.count >= 3 {
        var bestIdx = -1
        var bestLen: Double = 0
        for i in 1..<points.count {
            let dx = points[i].x - points[i-1].x
            let dy = points[i].y - points[i-1].y
            let segLen = sqrt(dx * dx + dy * dy)
            let isFlowAligned = isVerticalFlow ? (abs(dy) > abs(dx)) : (abs(dx) > abs(dy))
            if isFlowAligned && segLen > bestLen {
                bestLen = segLen
                bestIdx = i
            }
        }
        if bestIdx > 0 {
            return _PositionedPointPayload(
                x: (points[bestIdx - 1].x + points[bestIdx].x) / 2,
                y: (points[bestIdx - 1].y + points[bestIdx].y) / 2
            )
        }
    }

    // Fallback: total path distance midpoint
    var totalLen: Double = 0
    for i in 1..<points.count {
        let dx = points[i].x - points[i-1].x
        let dy = points[i].y - points[i-1].y
        totalLen += sqrt(dx * dx + dy * dy)
    }
    let halfLen = totalLen / 2
    var accumulated: Double = 0
    for i in 1..<points.count {
        let dx = points[i].x - points[i-1].x
        let dy = points[i].y - points[i-1].y
        let segLen = sqrt(dx * dx + dy * dy)
        if accumulated + segLen >= halfLen {
            let remaining = halfLen - accumulated
            let t = segLen > 0 ? remaining / segLen : 0.5
            return _PositionedPointPayload(
                x: points[i-1].x + dx * t,
                y: points[i-1].y + dy * t
            )
        }
        accumulated += segLen
    }
    return _PositionedPointPayload(
        x: (points[0].x + points[points.count - 1].x) / 2,
        y: (points[0].y + points[points.count - 1].y) / 2
    )
}
