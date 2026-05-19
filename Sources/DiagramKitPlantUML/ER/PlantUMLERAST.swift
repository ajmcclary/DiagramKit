import Foundation

struct PlantUMLERAST: Sendable {
    var entities: [Entity] = []
    var relationships: [Relationship] = []
    var title: String?

    struct Entity: Sendable, Hashable {
        let id: String
        var attributes: [Attribute] = []
    }

    struct Attribute: Sendable, Hashable {
        let name: String
        let type: String?
        let isPrimaryKey: Bool
    }

    struct Relationship: Sendable, Hashable {
        let left: String
        let right: String
        let leftCardinality: Cardinality
        let rightCardinality: Cardinality
        let identifying: Bool
        let label: String?

        enum Cardinality: String, Sendable, Hashable {
            case exactlyOne
            case zeroOrOne
            case oneOrMany
            case zeroOrMany
        }
    }
}
