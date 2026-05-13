// Ported from original/src/er/layout.ts
import Foundation
import DiagramKitCommon

private enum ER {
    static let padding: Double = 40
    static let boxPadX: Double = 14
    static let headerHeight: Double = 34
    static let rowHeight: Double = 22
    static let minWidth: Double = 140
    static let attrFontSize: Double = 11
    static let attrFontWeight: Int = 400
    static let nodeSpacing: Double = 70
    static let layerSpacing: Double = 90
}

private typealias EntitySizeMap = [String: (width: Double, height: Double)]

// ELK adapter types live in ElkModels.swift (ElkGraphNode / ElkGraphEdge /
// ElkGraphLabel / ElkEdgeSection). The local _ElkNode/_ElkEdge/... structs
// that used to wrap them here were deleted in Phase 1 (audit A1).

private func _mapDirection(_ dir: ErDirection) -> String {
    switch dir {
    case .tb: return "DOWN"
    case .bt: return "UP"
    case .lr: return "RIGHT"
    case .rl: return "LEFT"
    }
}

private func _buildErElkGraph(
    _ diagram: ErDiagram,
    _ options: RenderOptions,
    _ config: ErDiagramConfig?
) -> (elkGraph: ElkGraphNode, entitySizes: EntitySizeMap) {
    _ = options
    var entitySizes: EntitySizeMap = [:]

    let padX = config?.entityPadding ?? ER.boxPadX
    let minW = config?.minEntityWidth ?? ER.minWidth
    let minH = config?.minEntityHeight
    let hdrH = ER.headerHeight
    let rowH = ER.rowHeight

    // Use nodeId for entity identity in the layout graph
    for entity in diagram.entities {
        let headerTextWidth = original_src_styles.estimateTextWidth(
            entity.label,
            original_src_styles.FONT_SIZES.nodeLabel,
            original_src_styles.FONT_WEIGHTS.nodeLabel
        )

        var maxAttrWidth = 0.0
        for attr in entity.attributes {
            let keyPart = attr.keys.isEmpty ? "" : "  " + attr.keys.joined(separator: ",")
            let commentPart = attr.comment.isEmpty ? "" : "  \"\(attr.comment)\""
            let attrText = "\(attr.type)  \(attr.name)\(keyPart)\(commentPart)"
            let width = original_src_styles.estimateMonoTextWidth(attrText, ER.attrFontSize)
            maxAttrWidth = max(maxAttrWidth, width)
        }

        let width = max(minW, headerTextWidth + padX * 2, maxAttrWidth + padX * 2)
        let attrCount = max(entity.attributes.count, entity.attributes.isEmpty ? 0 : 1)
        let bodyHeight = Double(attrCount) * rowH + (entity.attributes.isEmpty ? 0 : 0)
        let height: Double
        if entity.attributes.isEmpty {
            height = hdrH
        } else {
            height = hdrH + bodyHeight
        }
        entitySizes[entity.nodeId] = (width, max(height, minH ?? height))
    }

    var children: [ElkGraphNode] = []
    for entity in diagram.entities {
        let size = entitySizes[entity.nodeId] ?? (minW, hdrH + rowH)
        children.append(ElkGraphNode(id: entity.nodeId, width: size.width, height: size.height))
    }

    var edges: [ElkGraphEdge] = []
    for (idx, rel) in diagram.relationships.enumerated() {
        var labels: [ElkGraphLabel] = []
        if !rel.roleA.isEmpty {
            let metrics = original_src_text_metrics.measureMultilineText(
                rel.roleA,
                fontSize: original_src_styles.FONT_SIZES.edgeLabel,
                fontWeight: original_src_styles.FONT_WEIGHTS.edgeLabel
            )
            labels.append(ElkGraphLabel(
                text: rel.roleA,
                width: metrics.width + 8,
                height: metrics.height + 6
            ))
        }
        edges.append(ElkGraphEdge(
            id: "e\(idx)",
            sources: [rel.entityAId],
            targets: [rel.entityBId],
            labels: labels
        ))
    }

    let directionStr = _mapDirection(config?.layoutDirection ?? diagram.direction)
    let ns = config?.nodeSpacing ?? ER.nodeSpacing
    let ls = config?.rankSpacing ?? ER.layerSpacing
    let pad = config?.diagramPadding ?? ER.padding

    let elkGraph = ElkGraphNode(
        id: "root",
        children: children,
        edges: edges,
        layoutOptions: [
            "elk.algorithm": "layered",
            "elk.direction": directionStr,
            "elk.spacing.nodeNode": String(ns),
            "elk.layered.spacing.nodeNodeBetweenLayers": String(ls),
            "elk.padding": "[top=\(pad),left=\(pad),bottom=\(pad),right=\(pad)]",
            "elk.edgeRouting": "ORTHOGONAL",
            "elk.edgeLabels.placement": "CENTER"
        ]
    )

    return (elkGraph, entitySizes)
}

private func _extractErLayout(
    _ result: ElkGraphNode,
    _ diagram: ErDiagram,
    _ entitySizes: EntitySizeMap,
    _ config: ErDiagramConfig?
) -> PositionedErDiagram {
    let entityLookup = Dictionary(diagram.entities.map { ($0.nodeId, $0) }, uniquingKeysWith: { _, last in last })

    var positionedEntities: [PositionedErEntity] = []
    for child in result.children {
        guard let entity = entityLookup[child.id] else { continue }
        let fallback = entitySizes[entity.nodeId] ?? (ER.minWidth, ER.headerHeight + ER.rowHeight)
        positionedEntities.append(
            PositionedErEntity(
                id: entity.key,
                nodeId: entity.nodeId,
                label: entity.label,
                attributes: entity.attributes,
                x: child.x,
                y: child.y,
                width: child.width != 0 ? child.width : fallback.width,
                height: child.height != 0 ? child.height : fallback.height,
                headerHeight: ER.headerHeight,
                rowHeight: ER.rowHeight,
                cssClasses: entity.cssClasses,
                cssStyles: entity.cssStyles,
                cssCompiledStyles: entity.cssCompiledStyles,
                look: entity.look,
                alias: entity.alias,
                labelType: entity.labelType
            )
        )
    }

    var relationships: [PositionedErRelationship] = []
    for (idx, elkEdge) in result.edges.enumerated() {
        guard idx < diagram.relationships.count else { continue }
        let rel = diagram.relationships[idx]
        var points: [ErPoint] = []
        if let section = elkEdge.sections.first {
            points.append(ErPoint(x: section.startPoint.x, y: section.startPoint.y))
            for bp in section.bendPoints {
                points.append(ErPoint(x: bp.x, y: bp.y))
            }
            points.append(ErPoint(x: section.endPoint.x, y: section.endPoint.y))
        }
        relationships.append(
            PositionedErRelationship(
                entity1: rel.entity1,
                entity2: rel.entity2,
                entityAId: rel.entityAId,
                entityBId: rel.entityBId,
                cardinality1: rel.cardinality1,
                cardinality2: rel.cardinality2,
                label: rel.roleA,
                identifying: rel.identifying,
                points: points,
                relSpec: rel.relSpec
            )
        )
    }

    return PositionedErDiagram(
        width: result.width != 0 ? result.width : 600,
        height: result.height != 0 ? result.height : 400,
        entities: positionedEntities,
        relationships: relationships,
        accTitle: diagram.accTitle,
        accDescr: diagram.accDescr,
        diagramTitle: diagram.diagramTitle,
        config: config
    )
}

// Encoder/decoder helpers removed in Phase 1: ElkGraphNode.toDictionary()
// and ElkGraphNode(from:) replace them.

public func layoutErDiagramSync(
    _ diagram: ErDiagram,
    options: RenderOptions = RenderOptions(),
    config: ErDiagramConfig? = nil
) throws -> PositionedErDiagram {
    try _layoutErDiagramSyncEntry(diagram, options: options, config: config)
}

private func _layoutErDiagramSyncEntry(
    _ diagram: ErDiagram,
    options: RenderOptions,
    config: ErDiagramConfig?
) throws -> PositionedErDiagram {
    let effectiveConfig = config ?? diagram.config
    if diagram.entities.isEmpty {
        return PositionedErDiagram(
            width: 0,
            height: 0,
            entities: [],
            relationships: [],
            accTitle: diagram.accTitle,
            accDescr: diagram.accDescr,
            diagramTitle: diagram.diagramTitle,
            config: effectiveConfig
        )
    }

    let built = _buildErElkGraph(diagram, options, effectiveConfig)
    let rawResult = try layoutEngineSync(built.elkGraph.toDictionary())
    let result = ElkGraphNode(from: rawResult)
    return _extractErLayout(result, diagram, built.entitySizes, effectiveConfig)
}

final class original_src_er_layout {
    public init() {}

    public static func layoutErDiagramSync(
        _ diagram: ErDiagram,
        options: RenderOptions = RenderOptions()
    ) throws -> PositionedErDiagram {
        try _layoutErDiagramSyncEntry(diagram, options: options, config: nil)
    }

    public static func layoutErDiagramSync(
        _ diagram: ErDiagram,
        options: RenderOptions = RenderOptions(),
        config: ErDiagramConfig? = nil
    ) throws -> PositionedErDiagram {
        try _layoutErDiagramSyncEntry(diagram, options: options, config: config)
    }
}
