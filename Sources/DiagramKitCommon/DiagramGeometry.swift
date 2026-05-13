// Phase 8: Interactivity Primitives — Slice 8A
// Portable geometry types for format-neutral spatial operations.

import Foundation

// MARK: - DiagramPoint

/// A language-neutral 2D point.
public struct DiagramPoint: Sendable, Hashable, CustomStringConvertible {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = DiagramPoint(x: 0, y: 0)

    public var description: String { "(\(x), \(y))" }
}

// MARK: - DiagramSize

/// A language-neutral 2D size.
public struct DiagramSize: Sendable, Hashable, CustomStringConvertible {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = DiagramSize(width: 0, height: 0)

    public var description: String { "\(width)×\(height)" }
}

// MARK: - DiagramRect

/// A language-neutral axis-aligned rectangle.
public struct DiagramRect: Sendable, Hashable, CustomStringConvertible {
    public var origin: DiagramPoint
    public var size: DiagramSize

    public init(origin: DiagramPoint, size: DiagramSize) {
        self.origin = origin
        self.size = size
    }

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.origin = DiagramPoint(x: x, y: y)
        self.size = DiagramSize(width: width, height: height)
    }

    public var x: Double { origin.x }
    public var y: Double { origin.y }
    public var width: Double { size.width }
    public var height: Double { size.height }

    public var minX: Double { origin.x }
    public var minY: Double { origin.y }
    public var maxX: Double { origin.x + size.width }
    public var maxY: Double { origin.y + size.height }
    public var midX: Double { origin.x + size.width / 2 }
    public var midY: Double { origin.y + size.height / 2 }

    // MARK: - Spatial operations

    /// Whether `point` lies inside this rectangle (inclusive on bottom-right
    /// edge for hit-testing tolerance).
    public func contains(_ point: DiagramPoint) -> Bool {
        point.x >= minX && point.x <= maxX
            && point.y >= minY && point.y <= maxY
    }

    /// Whether this rectangle intersects `other`.
    public func intersects(_ other: DiagramRect) -> Bool {
        !(maxX < other.minX || other.maxX < minX
            || maxY < other.minY || other.maxY < minY)
    }

    /// The intersection of this rectangle with `other`, or nil if they don't
    /// overlap.
    public func intersection(_ other: DiagramRect) -> DiagramRect? {
        guard intersects(other) else { return nil }
        let ix = Swift.max(minX, other.minX)
        let iy = Swift.max(minY, other.minY)
        let iw = Swift.min(maxX, other.maxX) - ix
        let ih = Swift.min(maxY, other.maxY) - iy
        return DiagramRect(x: ix, y: iy, width: iw, height: ih)
    }

    public static let zero = DiagramRect(x: 0, y: 0, width: 0, height: 0)

    public var description: String {
        "(\(x), \(y); \(width)×\(height))"
    }

    /// Smallest rectangle that contains every point in `points`, optionally
    /// expanded by `paddedBy` on all sides. Returns `.zero` for an empty
    /// input. Used by hit-target bounds across diagram families (edges,
    /// relationships) where each family carries its own point type — see
    /// `_PointLike` for the conformance convention.
    public static func bounding(
        points: [some _PointLike],
        paddedBy pad: Double = 0
    ) -> DiagramRect {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y
        for p in points.dropFirst() {
            if p.x < minX { minX = p.x }
            if p.y < minY { minY = p.y }
            if p.x > maxX { maxX = p.x }
            if p.y > maxY { maxY = p.y }
        }
        return DiagramRect(
            x: minX - pad,
            y: minY - pad,
            width: (maxX - minX) + pad * 2,
            height: (maxY - minY) + pad * 2
        )
    }
}

// MARK: - _PointLike

/// Underscore-prefixed SPI protocol that lets per-family point types
/// (`DiagramPoint` in this module, `ClassPoint` and `ErPoint` in
/// `DiagramKitModel`) participate in shared geometry helpers without
/// promising public API stability for the protocol itself.
public protocol _PointLike {
    var x: Double { get }
    var y: Double { get }
}

extension DiagramPoint: _PointLike {}

// MARK: - CoreGraphics bridging

#if canImport(CoreGraphics)
import CoreGraphics

extension DiagramPoint {
    /// Create a `DiagramPoint` from a CoreGraphics point.
    public init(_ point: CGPoint) {
        self.init(x: Double(point.x), y: Double(point.y))
    }

    /// The CoreGraphics point representation.
    public var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

extension DiagramRect {
    /// Create a `DiagramRect` from a CoreGraphics rectangle.
    public init(_ rect: CGRect) {
        self.init(
            x: Double(rect.origin.x), y: Double(rect.origin.y),
            width: Double(rect.size.width), height: Double(rect.size.height)
        )
    }

    /// The CoreGraphics rectangle representation.
    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
#endif
