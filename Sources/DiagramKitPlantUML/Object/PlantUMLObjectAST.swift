import Foundation

struct PlantUMLObjectAST: Sendable {
    var objects: [ObjectDecl] = []
    var relationships: [Relationship] = []
    var title: String?

    struct ObjectDecl: Sendable, Hashable {
        let id: String
        let label: String
        var attributes: [String]
    }

    struct Relationship: Sendable, Hashable {
        let left: String
        let right: String
        let arrow: Arrow
        let label: String?

        enum Arrow: String, Sendable, Hashable {
            case association
            case composition
            case aggregation
            case dependency
        }
    }
}
