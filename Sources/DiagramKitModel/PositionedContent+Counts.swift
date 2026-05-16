//
//  PositionedContent+Counts.swift
//  DiagramKitModel
//
//  Public scene-graph cardinality readouts used by UI clients (e.g.
//  DiagramPlayground's inspector and toolbar). Covers the families
//  whose case payload directly carries node / edge arrays; other
//  families return 0 until a per-family pattern is added.
//

import Foundation

public extension PositionedContent {
    /// Number of primary nodes / actors / classes / entities in the
    /// positioned content. Returns 0 for families whose layout isn't
    /// expressed as node-and-edge tuples.
    var nodeCount: Int {
        switch self {
        case let .flowchart(nodes, _, _),
             let .stateDiagram(nodes, _, _):
            return nodes.count
        case let .sequenceDiagram(actors, _, _, _, _, _, _, _, _, _, _, _):
            return actors.count
        case let .classDiagram(classes, _, _, _, _, _, _):
            return classes.count
        case let .erDiagram(entities, _, _, _, _, _):
            return entities.count
        default:
            return 0
        }
    }

    /// Number of edges / relationships / messages connecting nodes.
    /// Returns 0 for families without explicit edges (pie, gantt, …).
    var edgeCount: Int {
        switch self {
        case let .flowchart(_, edges, _),
             let .stateDiagram(_, edges, _):
            return edges.count
        case let .sequenceDiagram(_, messages, _, _, _, _, _, _, _, _, _, _):
            return messages.count
        case let .classDiagram(_, relationships, _, _, _, _, _):
            return relationships.count
        case let .erDiagram(_, relationships, _, _, _, _):
            return relationships.count
        default:
            return 0
        }
    }
}

public extension PositionedGraph {
    /// Convenience pass-through to ``PositionedContent/nodeCount``.
    var nodeCount: Int { content.nodeCount }

    /// Convenience pass-through to ``PositionedContent/edgeCount``.
    var edgeCount: Int { content.edgeCount }
}
