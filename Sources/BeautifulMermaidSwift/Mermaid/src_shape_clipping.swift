// Ported from original/src/shape-clipping.ts
import Foundation

open class original_src_shape_clipping {
    public init() {}

    public typealias Point = original_src_types.Point
    public typealias PositionedNode = original_src_types.PositionedNode

    public static func clipEdgeToShape(
        _ points: [Point],
        node: PositionedNode,
        isStart: Bool
    ) -> [Point] {
        if points.count < 2 {
            return points
        }

        switch node.shape {
        case .rectangle, .rounded, .stadium, .subroutine, .asymmetric,
             .text, .invisible, .fork, .join, .notchedRectangle, .taggedRectangle,
             .linedRectangle, .dividedRectangle, .windowPane, .stackedRectangle,
             .delay, .iconSquare, .iconCircle, .icon, .iconRounded, .imageSquare,
             .state, .choice, .note, .rectWithTitle, .labelRect, .anchor:
            return points
        case .diamond:
            return clipToDiamond(points: points, node: node, isStart: isStart)
        case .circle, .ellipse, .smallCircle, .filledCircle, .doublecircle,
             .framedCircle, .crossedCircle, .bang:
            return clipToCircle(points: points, node: node, isStart: isStart)
        case .hexagon, .notchedPentagon:
            return clipToHexagon(points: points, node: node, isStart: isStart)
        case .triangle, .flippedTriangle, .slopedRectangle, .flag, .lightningBolt, .bowTieRectangle:
            return clipToPolygon(points: points, node: node, isStart: isStart)
        default:
            return points
        }
    }

    private static func clipToDiamond(endpoint: Point, adjacent: Point, node: PositionedNode) -> Point {
        let cx = node.x + node.width / 2
        let cy = node.y + node.height / 2

        let top = Point(x: cx, y: node.y)
        let right = Point(x: node.x + node.width, y: cy)
        let bottom = Point(x: cx, y: node.y + node.height)
        let left = Point(x: node.x, y: cy)

        let dx = endpoint.x - adjacent.x
        let dy = endpoint.y - adjacent.y
        let isVertical = abs(dx) < abs(dy)

        if isVertical {
            let rayX = endpoint.x
            if dy > 0 {
                if rayX <= cx {
                    return intersectVerticalRayWithEdge(rayX: rayX, p1: left, p2: top) ?? top
                }
                return intersectVerticalRayWithEdge(rayX: rayX, p1: top, p2: right) ?? top
            }

            if rayX <= cx {
                return intersectVerticalRayWithEdge(rayX: rayX, p1: bottom, p2: left) ?? bottom
            }
            return intersectVerticalRayWithEdge(rayX: rayX, p1: right, p2: bottom) ?? bottom
        }

        let rayY = endpoint.y
        if dx > 0 {
            if rayY <= cy {
                return intersectHorizontalRayWithEdge(rayY: rayY, p1: top, p2: left) ?? left
            }
            return intersectHorizontalRayWithEdge(rayY: rayY, p1: left, p2: bottom) ?? left
        }

        if rayY <= cy {
            return intersectHorizontalRayWithEdge(rayY: rayY, p1: top, p2: right) ?? right
        }
        return intersectHorizontalRayWithEdge(rayY: rayY, p1: right, p2: bottom) ?? right
    }

    private static func intersectHorizontalRayWithEdge(rayY: Double, p1: Point, p2: Point) -> Point? {
        let dy = p2.y - p1.y
        if abs(dy) < 0.001 {
            return nil
        }

        let t = (rayY - p1.y) / dy
        if t < 0 || t > 1 {
            return nil
        }

        let x = p1.x + t * (p2.x - p1.x)
        return Point(x: x, y: rayY)
    }

    private static func intersectVerticalRayWithEdge(rayX: Double, p1: Point, p2: Point) -> Point? {
        let dx = p2.x - p1.x
        if abs(dx) < 0.001 {
            return nil
        }

        let t = (rayX - p1.x) / dx
        if t < 0 || t > 1 {
            return nil
        }

        let y = p1.y + t * (p2.y - p1.y)
        return Point(x: rayX, y: y)
    }

    private static func clipToDiamond(points: [Point], node: PositionedNode, isStart: Bool) -> [Point] {
        var result = points
        if isStart {
            result[0] = clipToDiamond(endpoint: points[0], adjacent: points[1], node: node)
        } else {
            let last = points.count - 1
            result[last] = clipToDiamond(endpoint: points[last], adjacent: points[last - 1], node: node)
        }
        return result
    }

    private static func clipToCircle(points: [Point], node: PositionedNode, isStart: Bool) -> [Point] {
        var result = points
        let cx = node.x + node.width / 2
        let cy = node.y + node.height / 2
        let r = min(node.width, node.height) / 2
        let idx = isStart ? 0 : (points.count - 1)
        let adj = isStart ? 1 : (points.count - 2)
        let dx = points[idx].x - points[adj].x
        let dy = points[idx].y - points[adj].y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0.001 else { return result }
        let nx = dx / len, ny = dy / len
        result[idx] = Point(x: cx + nx * r, y: cy + ny * r)
        return result
    }

    private static func clipToHexagon(points: [Point], node: PositionedNode, isStart: Bool) -> [Point] {
        var result = points
        let idx = isStart ? 0 : (points.count - 1)
        let adj = isStart ? 1 : (points.count - 2)
        let inset = node.height / 4
        let cx = node.x + node.width / 2, cy = node.y + node.height / 2
        let dx = result[idx].x - result[adj].x
        let dy = result[idx].y - result[adj].y
        let isVertical = abs(dx) < abs(dy)

        if isVertical {
            let rayX = result[idx].x
            if dy > 0 {
                result[idx] = intersectVerticalRayWithEdge(rayX: rayX, p1: Point(x: node.x, y: cy), p2: Point(x: node.x + inset, y: node.y)) ?? pointOnLine(from: result[adj], to: Point(x: cx, y: cy), atDistance: node.height / 2)
            } else {
                result[idx] = intersectVerticalRayWithEdge(rayX: rayX, p1: Point(x: node.x + inset, y: node.y + node.height), p2: Point(x: node.x, y: cy)) ?? pointOnLine(from: result[adj], to: Point(x: cx, y: cy), atDistance: node.height / 2)
            }
        } else {
            if dx > 0 {
                result[idx] = Point(x: node.x + node.width, y: cy)
            } else {
                result[idx] = Point(x: node.x, y: cy)
            }
        }
        return result
    }

    private static func clipToPolygon(points: [Point], node: PositionedNode, isStart: Bool) -> [Point] {
        var result = points
        let idx = isStart ? 0 : (points.count - 1)
        let adj = isStart ? 1 : (points.count - 2)
        let dx = result[idx].x - result[adj].x
        let dy = result[idx].y - result[adj].y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0.001 else { return result }
        let nx = dx / len, ny = dy / len
        result[idx] = Point(x: result[adj].x + nx * node.width * 0.5,
                             y: result[adj].y + ny * node.height * 0.5)
        return result
    }

    private static func pointOnLine(from: Point, to: Point, atDistance: Double) -> Point {
        let dx = to.x - from.x, dy = to.y - from.y
        let len = sqrt(dx * dx + dy * dy)
        guard len > 0.001 else { return to }
        let t = atDistance / len
        return Point(x: from.x + dx * t, y: from.y + dy * t)
    }
}
