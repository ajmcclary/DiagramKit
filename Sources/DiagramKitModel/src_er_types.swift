// Ported from original/src/er/types.ts
import Foundation

public typealias Entity = ErEntity
public typealias Attribute = ErAttribute
public typealias Relationship = ErRelationship
public typealias PositionedEntity = PositionedErEntity
public typealias PositionedRelationship = PositionedErRelationship

open class original_src_er_types {
    public init() {}

    public static func makeAttribute(
        type: String,
        name: String,
        keys: [String] = [],
        comment: String = ""
    ) -> ErAttribute {
        ErAttribute(type: type, name: name, keys: keys, comment: comment)
    }

    public static func makeEntity(
        key: String,
        nodeId: String? = nil,
        label: String,
        alias: String = "",
        attributes: [ErAttribute] = [],
        shape: String = "erBox",
        look: String = "default",
        cssClasses: String = "default"
    ) -> ErEntity {
        ErEntity(
            key: key,
            nodeId: nodeId,
            label: label,
            alias: alias,
            attributes: attributes,
            shape: shape,
            look: look,
            cssClasses: cssClasses
        )
    }

    public static func makeRelationship(
        entity1: String,
        entity2: String,
        entityAId: String,
        entityBId: String,
        roleA: String,
        relSpec: ErRelSpec
    ) -> ErRelationship {
        ErRelationship(
            entity1: entity1,
            entity2: entity2,
            entityAId: entityAId,
            entityBId: entityBId,
            roleA: roleA,
            relSpec: relSpec
        )
    }

    public static func makeDiagram(
        entities: [ErEntity] = [],
        relationships: [ErRelationship] = [],
        classes: [String: ErEntityClass] = [:],
        direction: ErDirection = .tb
    ) -> ErDiagram {
        ErDiagram(entities: entities, relationships: relationships, classes: classes, direction: direction)
    }
}
