import Foundation
import DiagramKitCommon
import DiagramKitModel
import DiagramKitImport

/// Converts `PlantUMLClassAST` → `ClassDiagram` (the canonical
/// `DiagramKitModel.ClassDiagram` payload).
public struct PlantUMLClassMapper {

    public init() {}

    public func map(_ ast: PlantUMLClassAST) -> (graph: ClassDiagram, diagnostics: [DiagramDiagnostic]) {
        var classes: [ClassNode] = []
        var classMap: [String: ClassNode] = [:]
        var diagnostics: [DiagramDiagnostic] = []

        for decl in ast.classes {
            let displayLabel = decl.label ?? decl.name
            let annotations = annotations(for: decl)
            var attributes: [ClassMember] = []
            var methods: [ClassMember] = []
            for member in decl.members {
                let mapped = mapMember(member)
                switch member.kind {
                case .field: attributes.append(mapped)
                case .method: methods.append(mapped)
                }
            }
            let node = ClassNode(
                id: decl.name,
                label: displayLabel,
                attributes: attributes,
                methods: methods,
                annotations: annotations,
                parent: decl.packageName
            )
            classes.append(node)
            classMap[decl.name] = node
        }

        var relationships: [ClassRelationship] = []
        for rel in ast.relationships {
            let endpoint = endpoint(for: rel)
            let label = rel.label ?? ""
            relationships.append(ClassRelationship(
                id1: rel.leftId,
                id2: rel.rightId,
                relationTitle1: rel.leftCardinality ?? "",
                relationTitle2: rel.rightCardinality ?? "",
                title: label,
                text: label,
                style: [],
                relation: endpoint
            ))
        }

        var notes: [ClassNote] = []
        var noteMap: [String: ClassNote] = [:]
        for (idx, note) in ast.notes.enumerated() {
            let id = "plantumlNote\(idx)"
            let mapped = ClassNote(
                id: id,
                class_: note.attachedTo,
                text: note.text,
                index: idx,
                parent: nil
            )
            notes.append(mapped)
            noteMap[id] = mapped
        }

        for line in ast.unsupportedLines {
            diagnostics.append(.featureDropped(
                .diagramFamilyUnsupported,
                message: "PlantUML class line not yet supported: \(line)"
            ))
        }

        var namespaces: [ClassNamespace] = []
        var namespaceMap: [String: ClassNamespace] = [:]
        for pkg in ast.packages {
            let ns = ClassNamespace(
                id: pkg.name,
                label: pkg.displayName ?? pkg.name,
                domId: "",
                classIds: pkg.classIds,
                noteIds: [],
                children: [],
                parent: nil,
                explicit: true
            )
            namespaces.append(ns)
            namespaceMap[pkg.name] = ns
        }

        let model = ClassDiagram(
            classes: classes,
            classMap: classMap,
            relationships: relationships,
            namespaces: namespaces,
            namespaceMap: namespaceMap,
            notes: notes,
            noteMap: noteMap
        )
        return (model, diagnostics)
    }

    private func annotations(for decl: PlantUMLClassDecl) -> [String] {
        var result: [String] = []
        switch decl.kind {
        case .classDecl: break
        case .interfaceDecl: result.append("Interface")
        case .abstractDecl: result.append("Abstract")
        case .enumDecl: result.append("Enumeration")
        case .annotationDecl: result.append("Annotation")
        }
        if let stereotype = decl.stereotype, !stereotype.isEmpty {
            result.append(stereotype)
        }
        return result
    }

    private func mapMember(_ member: PlantUMLClassMember) -> ClassMember {
        let memberType: ClassMember.ClassMemberType = (member.kind == .method) ? .method : .attribute
        return ClassMember(
            id: member.identifier,
            visibility: member.visibility == .none ? "" : member.visibility.rawValue,
            classifier: "",
            memberType: memberType,
            parameters: member.parameters,
            returnType: member.typeAnnotation
        )
    }

    private func endpoint(for rel: PlantUMLClassRelationship) -> ClassRelationEndpoint {
        let type1 = endpointTypeCode(for: rel.leftEndpoint)
        let type2 = endpointTypeCode(for: rel.rightEndpoint)
        let lineType = (rel.lineStyle == .dotted)
            ? ClassLineType.dotted.rawValue
            : ClassLineType.solid.rawValue
        return ClassRelationEndpoint(type1: type1, type2: type2, lineType: lineType)
    }

    private func endpointTypeCode(for shape: PlantUMLEndpointShape) -> Int {
        switch shape {
        case .none: return ClassRelationType.none.rawValue
        case .inheritance: return ClassRelationType.inheritance.rawValue
        case .composition: return ClassRelationType.composition.rawValue
        case .aggregation: return ClassRelationType.aggregation.rawValue
        case .dependency: return ClassRelationType.dependency.rawValue
        }
    }
}
