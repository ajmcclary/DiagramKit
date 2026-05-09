import Foundation
import CoreGraphics

// MARK: - Typed ELK Adapter Models

/// Typed models for ELK layout engine communication.
/// Replaces the `[String: Any]` dictionaries currently used as `_ElkNode`
/// in `src_layout.swift`. These models provide compile-time safety and
/// reduce the risk of silently-defaulted structural errors.

public struct ElkGraphNode: Sendable {
    public var id: String
    public var children: [ElkGraphNode]
    public var edges: [ElkGraphEdge]
    public var ports: [ElkGraphPort]
    public var layoutOptions: [String: String]
    public var labels: [ElkGraphLabel]
    public var width: Double
    public var height: Double
    public var x: Double
    public var y: Double

    public init(
        id: String,
        children: [ElkGraphNode] = [],
        edges: [ElkGraphEdge] = [],
        ports: [ElkGraphPort] = [],
        layoutOptions: [String: String] = [:],
        labels: [ElkGraphLabel] = [],
        width: Double = 0,
        height: Double = 0,
        x: Double = 0,
        y: Double = 0
    ) {
        self.id = id
        self.children = children
        self.edges = edges
        self.ports = ports
        self.layoutOptions = layoutOptions
        self.labels = labels
        self.width = width
        self.height = height
        self.x = x
        self.y = y
    }
}

public struct ElkGraphEdge: Sendable {
    public var id: String
    public var sources: [String]
    public var targets: [String]
    public var sections: [ElkEdgeSection]
    public var labels: [ElkGraphLabel]

    public init(
        id: String,
        sources: [String] = [],
        targets: [String] = [],
        sections: [ElkEdgeSection] = [],
        labels: [ElkGraphLabel] = []
    ) {
        self.id = id
        self.sources = sources
        self.targets = targets
        self.sections = sections
        self.labels = labels
    }
}

public struct ElkEdgeSection: Sendable {
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var bendPoints: [CGPoint]

    public init(
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        bendPoints: [CGPoint] = []
    ) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.bendPoints = bendPoints
    }
}

public struct ElkGraphLabel: Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var layoutOptions: [String: String]

    public init(
        text: String = "",
        x: Double = 0,
        y: Double = 0,
        width: Double = 0,
        height: Double = 0,
        layoutOptions: [String: String] = [:]
    ) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.layoutOptions = layoutOptions
    }
}

public struct ElkGraphPort: Sendable {
    public var id: String

    public init(id: String) {
        self.id = id
    }
}
