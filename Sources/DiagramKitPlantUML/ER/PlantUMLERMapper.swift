import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLERMapper {

    func map(_ ast: PlantUMLERAST) -> (ErDiagram, [DiagramDiagnostic]) {
        var entities: [ErEntity] = []
        for entity in ast.entities {
            var attrs: [ErAttribute] = []
            for attr in entity.attributes {
                let keys: [String] = attr.isPrimaryKey ? ["PK"] : []
                attrs.append(.init(
                    type: attr.type ?? "",
                    name: attr.name,
                    keys: keys
                ))
            }
            entities.append(ErEntity(
                key: entity.id,
                label: entity.id,
                attributes: attrs
            ))
        }

        var relationships: [ErRelationship] = []
        for rel in ast.relationships {
            let cardA = mermaidCard(rel.rightCardinality)
            let cardB = mermaidCard(rel.leftCardinality)
            let relType: ErIdentification = rel.identifying ? .identifying : .nonIdentifying
            relationships.append(.init(
                entity1: rel.left,
                entity2: rel.right,
                entityAId: "entity-\(rel.left)-0",
                entityBId: "entity-\(rel.right)-0",
                roleA: rel.label ?? "",
                relSpec: .init(cardA: cardA, cardB: cardB, relType: relType)
            ))
        }

        let diagram = ErDiagram(
            entities: entities,
            relationships: relationships,
            diagramTitle: ast.title
        )
        return (diagram, [])
    }

    private func mermaidCard(_ c: PlantUMLERAST.Relationship.Cardinality) -> ErCardinality {
        switch c {
        case .exactlyOne: return .onlyOne
        case .zeroOrOne:  return .zeroOrOne
        case .oneOrMany:  return .oneOrMore
        case .zeroOrMany: return .zeroOrMore
        }
    }
}
