// Ported from original/src/class/types.ts
import Foundation

public typealias ClassDiagramModel = ClassDiagram
public typealias ClassNodeModel = ClassNode
public typealias ClassMemberModel = ClassMember
public typealias ClassRelationshipModel = ClassRelationship
public typealias ClassNamespaceModel = ClassNamespace
public typealias PositionedClassDiagramModel = PositionedClassDiagram
public typealias PositionedClassNodeModel = PositionedClassNode
public typealias PositionedClassRelationshipModel = PositionedClassRelationship
public typealias ClassRelationshipType = RelationshipType

open class original_src_class_types {
    public init() {}

    public static func makeMember(
        visibility: String = "",
        name: String,
        type: String? = nil,
        isStatic: Bool = false,
        isAbstract: Bool = false,
        isMethod: Bool = false,
        params: String? = nil
    ) -> ClassMember {
        // Build the text based on old API
        let classifier = isAbstract ? "*" : (isStatic ? "$" : "")
        let memberType: ClassMember.ClassMemberType = isMethod ? .method : .attribute
        let text: String = {
            let vis = visibility.isEmpty ? "" : "\(visibility) "
            let genName = parseGenericTypes(name)
            let genType = type.map { parseGenericTypes($0) } ?? ""
            if isMethod {
                let genParams = params.map { parseGenericTypes($0) } ?? ""
                return "\(vis)\(genName)(\(genParams))\(genType.isEmpty ? "" : " : \(genType)")"
            }
            return "\(vis)\(genName)\(genType.isEmpty ? "" : " \(genType)")"
        }()
        let cssStyle = isAbstract ? "font-style:italic;" : (isStatic ? "text-decoration:underline;" : "")

        return ClassMember(
            id: name,
            visibility: visibility,
            classifier: classifier,
            memberType: memberType,
            parameters: params ?? "",
            returnType: type ?? "",
            text: text,
            cssStyle: cssStyle
        )
    }

    public static func makeNode(
        id: String,
        label: String,
        attributes: [ClassMember] = [],
        methods: [ClassMember] = [],
        annotation: String? = nil
    ) -> ClassNode {
        let annotations = annotation.map { [$0] } ?? []
        return ClassNode(
            id: id, label: label,
            attributes: attributes, methods: methods,
            annotations: annotations
        )
    }

    public static func makeRelationship(
        from: String,
        to: String,
        type: RelationshipType,
        markerAt: String,
        label: String? = nil,
        fromCardinality: String? = nil,
        toCardinality: String? = nil
    ) -> ClassRelationship {
        // Convert old-style type+markerAt to new two-ended model
        let isInheritance = type.lowercased() == "inheritance" || type.lowercased() == "realization"
        let isComposition = type.lowercased() == "composition"
        let isAggregation = type.lowercased() == "aggregation"
        let isDependency = type.lowercased() == "dependency" || type.lowercased() == "association"
        let isDashed = type.lowercased() == "dependency" || type.lowercased() == "realization"

        let relType: Int
        switch true {
        case isInheritance: relType = ClassRelationType.inheritance.rawValue
        case isComposition: relType = ClassRelationType.composition.rawValue
        case isAggregation: relType = ClassRelationType.aggregation.rawValue
        case isDependency: relType = ClassRelationType.dependency.rawValue
        default: relType = ClassRelationType.none.rawValue
        }

        let type1 = (markerAt == "from") ? relType : ClassRelationType.none.rawValue
        let type2 = (markerAt == "to") ? relType : ClassRelationType.none.rawValue

        return ClassRelationship(
            id1: from,
            id2: to,
            relationTitle1: fromCardinality ?? "",
            relationTitle2: toCardinality ?? "",
            title: label ?? "",
            text: "",
            style: [],
            relation: ClassRelationEndpoint(
                type1: type1,
                type2: type2,
                lineType: isDashed ? ClassLineType.dotted.rawValue : ClassLineType.solid.rawValue
            )
        )
    }

    public static func toAsciiDiagram(_ diagram: ClassDiagram) -> AsciiClassDiagram {
        AsciiClassDiagram(
            classes: diagram.classes.map { node in
                AsciiClassNode(
                    id: node.id,
                    label: node.label,
                    annotation: node.annotations.first,
                    attributes: node.attributes.map {
                        AsciiClassMember(
                            visibility: $0.visibility.isEmpty ? nil : $0.visibility,
                            name: $0.memberType == .method ? "\($0.id)(\($0.parameters))" : $0.id,
                            type: $0.returnType.isEmpty ? nil : $0.returnType
                        )
                    },
                    methods: node.methods.map {
                        AsciiClassMember(
                            visibility: $0.visibility.isEmpty ? nil : $0.visibility,
                            name: $0.memberType == .method ? "\($0.id)(\($0.parameters))" : $0.id,
                            type: $0.returnType.isEmpty ? nil : $0.returnType
                        )
                    }
                )
            },
            relationships: diagram.relationships.compactMap { rel in
                // Convert from two-ended to old-style type for ASCII
                let relTypeFrom = rel.relation.type1 != ClassRelationType.none.rawValue ? rel.relation.type1 : rel.relation.type2
                let typeStr: String = {
                    switch relTypeFrom {
                    case ClassRelationType.inheritance.rawValue: return "inheritance"
                    case ClassRelationType.composition.rawValue: return "composition"
                    case ClassRelationType.aggregation.rawValue: return "aggregation"
                    case ClassRelationType.dependency.rawValue: return "dependency"
                    default: return "association"
                    }
                }()

                let markerAt = rel.relation.type1 != ClassRelationType.none.rawValue ? "from" : "to"

                guard let relType = AsciiClassRelationshipType(rawValue: typeStr) else { return nil }

                // If dotted and type is general, map to realization or dependency
                let finalType: AsciiClassRelationshipType = {
                    if rel.relation.lineType == ClassLineType.dotted.rawValue && relType == .association {
                        return .dependency
                    }
                    return relType
                }()

                return AsciiClassRelationship(
                    from: rel.id1,
                    to: rel.id2,
                    type: finalType,
                    markerAt: markerAt,
                    label: rel.title.isEmpty ? nil : rel.title
                )
            }
        )
    }

    // Export inventory from TypeScript source:
    // - export interface ClassDiagram
    // - export interface ClassNode
    // - export interface ClassMember
    // - export type RelationshipType
    // - export interface ClassRelationship
    // - export interface ClassNamespace
    // - export interface PositionedClassDiagram
    // - export interface PositionedClassNode
    // - export interface PositionedClassRelationship
}
