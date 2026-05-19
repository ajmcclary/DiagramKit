import Foundation

struct PlantUMLComponentAST: Sendable {
    var components: [Component] = []
    var edges: [Edge] = []
    var title: String?

    struct Component: Sendable, Hashable {
        let id: String
        let label: String
        let kind: Kind

        enum Kind: String, Sendable, Hashable {
            case component
            case interface
        }
    }

    struct Edge: Sendable, Hashable {
        let source: String
        let target: String
        let label: String?
    }
}
