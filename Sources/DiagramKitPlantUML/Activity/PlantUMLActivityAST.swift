import Foundation

struct PlantUMLActivityAST: Sendable {
    var nodes: [Node] = []
    var edges: [Edge] = []
    var partitions: [Partition] = []
    var title: String?

    struct Node: Sendable, Hashable {
        let id: String
        let label: String
        let shape: NodeShape

        enum NodeShape: String, Sendable, Hashable {
            case startTerminator
            case stopTerminator
            case action
            case decision
        }
    }

    struct Edge: Sendable, Hashable {
        let source: String
        let target: String
        let label: String?
    }

    struct Partition: Sendable, Hashable {
        let id: String
        let label: String
        let memberNodeIDs: [String]
    }
}
