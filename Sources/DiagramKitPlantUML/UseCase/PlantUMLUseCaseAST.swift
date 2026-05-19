import Foundation

struct PlantUMLUseCaseAST: Sendable {
    var nodes: [Node] = []
    var edges: [Edge] = []
    var title: String?

    struct Node: Sendable, Hashable {
        let id: String
        let display: String
        let kind: Kind

        enum Kind: String, Sendable, Hashable {
            case actor
            case useCase
        }
    }

    struct Edge: Sendable, Hashable {
        let source: String
        let target: String
        let label: String?
    }
}
