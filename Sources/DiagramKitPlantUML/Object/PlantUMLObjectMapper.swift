import Foundation
import DiagramKitCommon
import DiagramKitModel

struct PlantUMLObjectMapper {

    func map(_ ast: PlantUMLObjectAST) -> (ClassDiagram, [DiagramDiagnostic]) {
        var diagnostics: [DiagramDiagnostic] = []
        var classes: [ClassNode] = []
        var classMap: [String: ClassNode] = [:]

        for obj in ast.objects {
            let attrs: [ClassMember] = obj.attributes.map { line in
                ClassMember(id: line)
            }
            let node = ClassNode(
                id: obj.id,
                label: obj.label,
                attributes: attrs
            )
            classes.append(node)
            classMap[obj.id] = node
            diagnostics.append(.lossyTransform(
                .shapeDowngrade,
                message: "PlantUML object '\(obj.id)' projected as classDiagram class; object-instance distinction dropped"
            ))
        }

        var relationships: [ClassRelationship] = []
        for rel in ast.relationships {
            let endpoint = endpoint(for: rel.arrow)
            let label = rel.label ?? ""
            relationships.append(ClassRelationship(
                id1: rel.left,
                id2: rel.right,
                relationTitle1: "",
                relationTitle2: "",
                title: label,
                text: label,
                style: [],
                relation: endpoint
            ))
        }

        let model = ClassDiagram(
            classes: classes,
            classMap: classMap,
            relationships: relationships,
            diagramTitle: ast.title
        )
        return (model, diagnostics)
    }

    private func endpoint(for arrow: PlantUMLObjectAST.Relationship.Arrow) -> ClassRelationEndpoint {
        let lineType = (arrow == .dependency) ? ClassLineType.dotted.rawValue : ClassLineType.solid.rawValue
        let type2: Int
        switch arrow {
        case .association: type2 = ClassRelationType.none.rawValue
        case .composition: type2 = ClassRelationType.composition.rawValue
        case .aggregation: type2 = ClassRelationType.aggregation.rawValue
        case .dependency:  type2 = ClassRelationType.dependency.rawValue
        }
        return ClassRelationEndpoint(
            type1: ClassRelationType.none.rawValue,
            type2: type2,
            lineType: lineType
        )
    }
}
