import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

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

// MARK: - LayoutNode Conversion

extension ElkGraphNode {
    /// Convert a `LayoutNode` dictionary (from the ELK engine) into a typed `ElkGraphNode`.
    public init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.width = (dict["width"] as? Double) ?? 0
        self.height = (dict["height"] as? Double) ?? 0
        self.x = (dict["x"] as? Double) ?? 0
        self.y = (dict["y"] as? Double) ?? 0
        self.layoutOptions = (dict["layoutOptions"] as? [String: String]) ?? [:]
        self.labels = ((dict["labels"] as? [[String: Any]]) ?? []).map(ElkGraphLabel.init(from:))
        self.ports = ((dict["ports"] as? [[String: Any]]) ?? []).map { ElkGraphPort(id: $0["id"] as? String ?? "") }
        self.children = ((dict["children"] as? [[String: Any]]) ?? []).map(ElkGraphNode.init(from:))
        self.edges = ((dict["edges"] as? [[String: Any]]) ?? []).map(ElkGraphEdge.init(from:))
    }
}

extension ElkGraphEdge {
    public init(from dict: [String: Any]) {
        self.id = dict["id"] as? String ?? ""
        self.sources = (dict["sources"] as? [String]) ?? []
        self.targets = (dict["targets"] as? [String]) ?? []
        self.sections = ((dict["sections"] as? [[String: Any]]) ?? []).map(ElkEdgeSection.init(from:))
        self.labels = ((dict["labels"] as? [[String: Any]]) ?? []).map(ElkGraphLabel.init(from:))
    }
}

extension ElkEdgeSection {
    public init(from dict: [String: Any]) {
        let sp = (dict["startPoint"] as? [String: Any])
        self.startPoint = CGPoint(x: (sp?["x"] as? Double) ?? 0, y: (sp?["y"] as? Double) ?? 0)
        let ep = (dict["endPoint"] as? [String: Any])
        self.endPoint = CGPoint(x: (ep?["x"] as? Double) ?? 0, y: (ep?["y"] as? Double) ?? 0)
        self.bendPoints = ((dict["bendPoints"] as? [[String: Any]]) ?? []).map { bp in
            CGPoint(x: (bp["x"] as? Double) ?? 0, y: (bp["y"] as? Double) ?? 0)
        }
    }
}

extension ElkGraphLabel {
    public init(from dict: [String: Any]) {
        self.text = dict["text"] as? String ?? ""
        self.x = (dict["x"] as? Double) ?? 0
        self.y = (dict["y"] as? Double) ?? 0
        self.width = (dict["width"] as? Double) ?? 0
        self.height = (dict["height"] as? Double) ?? 0
        self.layoutOptions = (dict["layoutOptions"] as? [String: String]) ?? [:]
    }
}

// MARK: - LayoutNode encoders
//
// These encoders are the single bridge that crosses into the dictionary
// world consumed by `layoutEngineSync`. The output shape is byte-compatible
// with the literals previously inlined in `src_layout.swift`: empty
// collections are omitted so downstream code can rely on
// `node["children"] as? [LayoutNode]` returning nil rather than an empty
// array. Width/height are emitted only when set; the root node (which has
// neither) round-trips faithfully and gets its dimensions overwritten by
// `_layoutRecursively`.

extension ElkGraphNode {
    public func toDictionary() -> [String: Any] {
        var out: [String: Any] = ["id": id]
        if width != 0 { out["width"] = width }
        if height != 0 { out["height"] = height }
        if x != 0 { out["x"] = x }
        if y != 0 { out["y"] = y }
        if !layoutOptions.isEmpty { out["layoutOptions"] = layoutOptions }
        if !labels.isEmpty { out["labels"] = labels.map { $0.toDictionary() } }
        if !ports.isEmpty { out["ports"] = ports.map { ["id": $0.id] } }
        if !children.isEmpty { out["children"] = children.map { $0.toDictionary() } }
        if !edges.isEmpty { out["edges"] = edges.map { $0.toDictionary() } }
        return out
    }
}

extension ElkGraphEdge {
    public func toDictionary() -> [String: Any] {
        var out: [String: Any] = [
            "id": id,
            "sources": sources,
            "targets": targets
        ]
        if !labels.isEmpty { out["labels"] = labels.map { $0.toDictionary() } }
        if !sections.isEmpty { out["sections"] = sections.map { $0.toDictionary() } }
        return out
    }
}

extension ElkEdgeSection {
    public func toDictionary() -> [String: Any] {
        [
            "startPoint": ["x": startPoint.x, "y": startPoint.y],
            "endPoint": ["x": endPoint.x, "y": endPoint.y],
            "bendPoints": bendPoints.map { ["x": $0.x, "y": $0.y] }
        ]
    }
}

extension ElkGraphLabel {
    public func toDictionary() -> [String: Any] {
        var out: [String: Any] = ["text": text]
        if width != 0 { out["width"] = width }
        if height != 0 { out["height"] = height }
        if x != 0 { out["x"] = x }
        if y != 0 { out["y"] = y }
        if !layoutOptions.isEmpty { out["layoutOptions"] = layoutOptions }
        return out
    }
}
